import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

/**
 * Blocking safety guards for pi's `bash` tool.
 *
 * pi shipped no guards while jcode and Claude Code both had them, so the same
 * `git reset --hard` that jcode refuses used to run unchallenged here. Rather
 * than maintain a third copy of that logic in TypeScript, this delegates to the
 * exact shell guards jcode already uses, so all three harnesses enforce one
 * ruleset and a fix to the shell script fixes every harness at once.
 *
 * Contract of those scripts (see coding-agent/jcode/hooks/):
 *   stdin                  = raw tool input JSON, e.g. {"command":"git push"}
 *   JCODE_HOOK_TOOL_NAME   = tool name, they no-op unless it is "bash"
 *   JCODE_HOOK_CWD         = directory the command will run in
 *   exit 0 = allow, exit 2 = block, stderr = the reason shown to the model
 */

const GUARD_DIR = join(homedir(), "dotfiles", "coding-agent", "jcode", "hooks");

/** Order matters: identity is checked before destructiveness, as in pre-tool.sh. */
const GUARDS = ["git-identity-guard.sh", "git-guardrails.sh"] as const;

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (!command) return;

    for (const guard of GUARDS) {
      const script = join(GUARD_DIR, guard);
      if (!existsSync(script)) continue;

      const result = spawnSync(script, {
        input: JSON.stringify({ command }),
        env: {
          ...process.env,
          JCODE_HOOK_TOOL_NAME: "bash",
          JCODE_HOOK_CWD: ctx.cwd,
        },
        encoding: "utf8",
        timeout: 5000,
      });

      // A broken or missing guard must not silently disable enforcement, but it
      // also must not wedge the agent: report it and keep going.
      if (result.error) {
        console.error(`[guards] ${guard} failed to run: ${result.error.message}`);
        continue;
      }

      if (result.status === 2) {
        const reason =
          (result.stderr || "").trim() || `blocked by ${guard}`;
        return { block: true, reason };
      }
    }
  });
}
