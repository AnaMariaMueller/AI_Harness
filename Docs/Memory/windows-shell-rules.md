---
name: windows-shell-rules
description: "User works on Windows with Git Bash and PowerShell 7; files only via the file tools, heredoc only as quoted stdin, LF via .gitattributes, rules live in the esaf-core plugin rule shell-commands"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 44dd8205-b9a5-444f-9132-9d7ee8f804d4
  modified: 2026-10-21T05:41:37.988Z
---

Create and change files only with the write and edit tools, never with heredocs, `echo`/`printf`/`cat` redirection, `tee`, `sed -i`, `Out-File` or `Set-Content`. A heredoc is fine only as input to a command with a quoted delimiter (`git commit -F - <<'EOF'`). Git Bash is the default shell (git, searches, pipes); PowerShell 7 for `.ps1` scripts and Windows administration; one shell's syntax per command. Text files use LF (CRLF only for `*.bat`, `*.cmd`) and UTF-8 without BOM, fixed per repository by `.gitattributes` (`* text=auto eol=lf`). Never change `core.autocrlf` or `core.eol` without asking. Before committing compare `git diff --stat` with `git diff -w --stat` and stop on line-ending churn.

**Why:** Heredocs and shell writes caused CRLF/LF churn and whole-file diffs that looked like conflicts (user, 2026-10-11). Root cause found on 2026-10-21: Git for Windows sets `core.autocrlf=true` system-wide, so checkouts are CRLF while heredocs write LF; repos had no `.gitattributes`.

**How to apply:** The shared rule text lives in the always-on rule `shell-commands` of the `esaf-core` plugin (ESAF AI Toolkit, from esaf-core 1.12.0); the harness prompt no longer writes its own shell instruction, only `.gitattributes` and the hook `shell-rules.sh`. The user does not want their personal rule text copied verbatim into committed files; keep rule text concise. See [[harness-files-tracked-here]].
