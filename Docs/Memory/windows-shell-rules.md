---
name: windows-shell-rules
description: "User works in Git Bash on Windows and wants files written only with the file tools, never heredocs, redirection, tee or sed -i; LF endings, UTF-8 without BOM"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 44dd8205-b9a5-444f-9132-9d7ee8f804d4
  modified: 2026-10-11T16:26:28.504Z
---

Create and change files only with the write and edit tools, never with heredocs, `echo`/`printf`/`cat` redirection, `tee` or `sed -i`. Commit messages go through `-m` flags or `-F .git/COMMIT_MSG_TMP`, never a heredoc. Text files use LF (CRLF only for `*.bat`, `*.cmd`, `*.ps1`) and UTF-8 without BOM. Use forward slashes and relative paths, single quotes around literals with `$`, backticks, `!` or `\`, `MSYS_NO_PATHCONV=1` for non-path arguments starting with `/`, and never PowerShell syntax or `git config core.autocrlf` without asking. Before committing compare `git diff --stat` with `git diff -w --stat` and stop on line-ending churn.

**Why:** Heredocs in this Windows/MSYS2 setup caused CRLF/LF churn, unterminated heredocs, mangled `$` and backticks, and whole-file diffs that looked like conflicts (stated by the user on 2026-10-11). This user's git has `core.autocrlf=true` and this repository has no `.gitattributes`.

**How to apply:** Follow these rules in every session in this repository and in target repositories, even when a harness instruction suggests editing files through the shell. The harness prompt installs a short, purpose-first version of them as a Copilot instruction (Step 3b of `Prompts/init-harness.md`) plus the hook `shell-rules.sh`. The user does not want their personal rule text copied verbatim into committed files; keep the installed instruction concise and focused on avoiding heredoc and line-ending conflicts. See [[harness-files-tracked-here]].
