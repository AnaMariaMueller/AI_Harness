---
name: harness-files-tracked-here
description: In AI_Harness, CLAUDE.md, .claude/ and init-harness.md are intentionally committed, unlike in harness target repos
metadata:
  type: project
---

In the `AI_Harness` repository, `CLAUDE.md`, `.claude/`, `CLAUDE.local.md` and `Prompts/init-harness.md` are allowed and expected to be committed to git (stated by the user on 2026-10-08).

**Why:** This repo is the *source* of the harness initialization prompt, not a target of it. The prompt's own rules (global excludes, hiding, neutral wording) apply to repositories the prompt is run against, and the user's global `~/.gitignore_global` ignores these paths everywhere.

**How to apply:** Keep the negation lines in the repo `.gitignore` (`!CLAUDE.md`, `!.claude/`, `!init-harness.md`, `!CLAUDE.local.md`). Do not treat these files as secret or untrackable here, and do not run the harness prompt against this repository.
