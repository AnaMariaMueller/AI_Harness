# Project memory index
One file per fact; this index holds one pointer line per file.

- [Harness files tracked here](harness-files-tracked-here.md) — CLAUDE.md, .claude/ and init-harness.md are committed on purpose; repo .gitignore un-ignores them
- [Memory lives in the repo](memory-lives-in-repo.md) — project memory goes in Docs/Memory, never in a user-level or external folder
- [Windows shell rules](windows-shell-rules.md) — files only via write/edit tools, no heredocs/redirection/tee/sed -i, LF endings, UTF-8 without BOM, check diff -w before committing
