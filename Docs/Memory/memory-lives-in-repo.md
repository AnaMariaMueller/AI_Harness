---
name: memory-lives-in-repo
description: Project memory for AI_Harness must be saved under Docs/Memory inside the repo, not in any folder outside it
metadata:
  type: feedback
---

All persistent memory for this project is stored in `Docs/Memory` inside the repository (index `MEMORY.md`, one fact per file). Nothing project-related goes into user-level or external folders such as `~/.claude/projects/<slug>/memory/` (user instruction, 2026-10-08).

**Why:** Memory is project knowledge and should travel with the repository and be visible in git, in line with the rule set in the harness prompt (`Docs/Memory`, "Project knowledge stays in the repository").

**How to apply:** `.claude/settings.json` sets `autoMemoryDirectory` to this folder, so write new memories there directly. If a memory ever lands in the user-level folder, move it into `Docs/Memory`, add its index line, and delete the external copy. See [[harness-files-tracked-here]].
