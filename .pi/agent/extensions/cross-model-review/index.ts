import { spawn } from "node:child_process";

import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Cross-model review for pi.
 *
 * The point of a review pass is independence, and a reviewer from the same
 * model family as the author is not independent - it shares the blind spots
 * that produced the bug. jcode's `swarm` cannot currently deliver this: probes
 * on 2026-08-28 showed its `model` pin being ignored, with every "cross-model"
 * worker silently running the coordinator's own model.
 *
 * pi can, because its `openai-codex` provider is separately authenticated and
 * verified working. This tool shells out to a fresh, sessionless `pi --print`
 * pinned to an OpenAI model, so the reviewer genuinely is a different family
 * and cannot inherit this session's context or its conclusions.
 *
 * Deliberately read-only: `--tools read,grep,find,bash` lets the reviewer
 * inspect the repo itself rather than trusting a pasted diff, and the guards
 * extension still applies to any bash it runs.
 */

const REVIEW_MODEL = "openai-codex/gpt-5.6-luna";
const TIMEOUT_MS = 10 * 60 * 1000;

const SYSTEM = `You are performing an INDEPENDENT cross-model code review.
You were invoked precisely because you are a different model family from the
author, so do not defer to their reasoning. Read the actual code before
judging: do not trust a description of it.

Report only real problems: correctness bugs, security holes, data loss, race
conditions, broken edge cases, and incorrect error handling. No style nits, no
praise, no summary of what the code does.

For each finding give: severity (critical/high/medium/low), file:line, what
breaks, and the concrete input or sequence that triggers it. Order by severity.
If you find nothing real, say exactly that in one line rather than padding.
Say plainly when you think the author is wrong.`;

function runReview(
  prompt: string,
  cwd: string,
  signal: AbortSignal,
  onUpdate?: (u: { content: { type: "text"; text: string }[] }) => void,
): Promise<{ ok: boolean; text: string }> {
  return new Promise((resolve) => {
    const child = spawn(
      "pi",
      [
        "--print",
        "--no-session",
        "--model", REVIEW_MODEL,
        "--thinking", "high",
        "--tools", "read,grep,find,bash",
        "--append-system-prompt", SYSTEM,
        "--",
        prompt,
      ],
      { cwd, stdio: ["ignore", "pipe", "pipe"] },
      // stdin MUST be ignored: pi waits on an open stdin and appears to hang.
    );

    let out = "";
    let err = "";
    const timer = setTimeout(() => child.kill("SIGTERM"), TIMEOUT_MS);
    const onAbort = () => child.kill("SIGTERM");
    signal.addEventListener("abort", onAbort, { once: true });

    child.stdout.on("data", (d) => {
      const s = String(d);
      out += s;
      onUpdate?.({ content: [{ type: "text", text: s }] });
    });
    child.stderr.on("data", (d) => (err += String(d)));

    child.on("error", (e) => {
      clearTimeout(timer);
      signal.removeEventListener("abort", onAbort);
      resolve({ ok: false, text: `Failed to start reviewer: ${e.message}` });
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      signal.removeEventListener("abort", onAbort);
      const text = out.trim();
      if (code === 0 && text) return resolve({ ok: true, text });
      resolve({
        ok: false,
        text:
          `Cross-model review did not produce a verdict (exit ${code}).\n` +
          `Do NOT substitute your own review as if it were the second opinion.\n` +
          (err.trim() || text || "(no output)"),
      });
    });
  });
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "cross_model_review",
    label: "Cross-model review",
    description:
      `Get an independent code review from ${REVIEW_MODEL}, a different model ` +
      `family than this session. Use before opening a PR, on a security- or ` +
      `data-sensitive diff, or when asked for a second opinion. The reviewer ` +
      `reads the repo itself, so pass a target (a git ref range, a PR, or ` +
      `specific paths) plus the context it needs, not a pasted diff.`,
    promptSnippet:
      "Independent review from a different model family (read-only)",
    promptGuidelines: [
      "Use cross_model_review before opening a PR and on any security- or data-sensitive change; a same-family review is not an independent one.",
      "Run cross_model_review at most once per diff - a second pass on the same change costs the same and returns the same signal.",
      "Verify each cross_model_review finding against the real code before acting: cross-model reviewers hallucinate too, and you are the filter.",
    ],
    parameters: Type.Object({
      target: Type.String({
        description:
          "What to review, e.g. 'git diff main...HEAD', 'the changes in src/auth/', or 'commits abc123..def456'.",
      }),
      context: Type.Optional(
        Type.String({
          description:
            "Background the reviewer cannot infer: intent of the change, invariants that must hold, specific worries to probe.",
        }),
      ),
    }),

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const prompt = [
        `Review target: ${params.target}`,
        params.context ? `\nContext from the author:\n${params.context}` : "",
        `\nInspect the repository at ${ctx.cwd} directly to see the code.`,
      ].join("");

      onUpdate?.({
        content: [
          { type: "text", text: `Asking ${REVIEW_MODEL} for an independent review...\n` },
        ],
      });

      const { ok, text } = await runReview(prompt, ctx.cwd, signal, onUpdate);

      return {
        content: [{ type: "text", text: `[reviewer: ${REVIEW_MODEL}]\n\n${text}` }],
        isError: !ok,
        details: { model: REVIEW_MODEL, target: params.target },
      };
    },
  });
}
