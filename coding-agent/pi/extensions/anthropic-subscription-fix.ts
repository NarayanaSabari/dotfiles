import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const REPLACEMENTS: [string, string][] = [
  [
    "operating inside pi, a coding agent harness. You help users by",
    "You help users by",
  ],
  [
    "Pi documentation (read only when the user asks about pi itself, its SDK, extensions, themes, skills, or TUI):",
    "Claude Code documentation (read only when the user asks about Claude Code, its SDK, extensions or skills):",
  ],
  ["pi packages (docs/packages.md)", "Claude Code packages (docs/packages.md)"],
  ["When working on pi topics", "When working on Claude Code topics"],
  ["Always read pi .md files", "Always read Claude Code .md files"],
];

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", (event, ctx) => {
    if (ctx.model?.provider !== "anthropic") return;

    let systemPrompt = event.systemPrompt;
    let changed = false;

    for (const [target, replacement] of REPLACEMENTS) {
      if (systemPrompt.includes(target)) {
        systemPrompt = systemPrompt.replace(target, replacement);
        changed = true;
      }
    }

    if (changed) {
      return { systemPrompt };
    }
  });
}
