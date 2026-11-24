# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

`AI_Harness` holds what connects Claude Code to the GitHub Copilot customizations of the user's
repositories and to the ESAF AI Toolkit plugins. There is no application code and no build system.

| File | What it does | When it runs |
|---|---|---|
| `Prompts/setup-machine.md` | One-time machine setup: global git excludes (`.claude/`, `CLAUDE.md`, `CLAUDE.local.md`, `init-harness.md`), user settings (thinking summaries, no attribution), the user-level hooks from `Hooks/`, the ESAF plugins via the update script, connectors and MCP per repository or workspace (asked) | Once per machine, and again when `Hooks/` changes |
| `Prompts/init-harness.md` | Wraps one repository's own `.github/` customizations (agents, chatmodes, instructions, prompts, `copilot-instructions.md`) as Claude Code agents, rules and skills, lists them in `CLAUDE.md` and in the `harness-customizations` block of `AGENTS.md`, and sets the memory folder declared in "Project memory facts" | In a repository, whenever its `.github/` customizations change |
| `Scripts/Update-EsafPlugins.ps1` | Fast-forwards the VS Code marketplace clone of the ESAF AI Toolkit, runs `copilot plugin install`/`update` for every marketplace plugin, regenerates the user-level wrappers (`~/.claude/agents`, `rules/esaf-*.md`, `skills`, `commands`) | After every toolkit publish (a PR completed into its `master`); never scheduled |
| `Hooks/no-ai-attribution.sh`, `Hooks/shell-rules.sh`, `Hooks/no-ai-attribution.allow` | Source of the user-level `PreToolUse` hooks: commit guard (message, trailers, staged additions; workspace-aware; allowlist by origin URL) and shell-rule guard (heredocs, redirection, `tee`, `sed -i`, PowerShell file writers, `core.autocrlf`/`core.eol`) | Copied to `~/.claude/hooks/` by `setup-machine.md` |

Two placement modes for repository wrappers (`init-harness.md` Step 0):
- **Repository mode**: the wrappers go into the repository's git-ignored `.claude/`, the list into
  its git-ignored `CLAUDE.md`.
- **Workspace mode**: when the repository's parent folder is not a git repository and holds a
  `CLAUDE.md` and a `.claude/`, the wrappers go into the workspace's `.claude/` (agent and skill
  descriptions start with `[<repo> repository]`, rule paths get the `<repo>/` prefix) and the list
  into a `harness-local:<repo>` block of the workspace `CLAUDE.md`. The clone itself holds no
  Claude Code files.

Rules that hold in every repository (no AI attribution, delegation, screenshots, shell commands,
`.gitattributes`, project memory) are not written by the harness: they are always-on rules of the
`esaf-core` and `dev-flow` plugins.

## Project memory

Persistent memory for this repository lives in `Docs/Memory` (index `MEMORY.md`, one fact per file) and is committed. `.claude/settings.json` sets `autoMemoryDirectory` to that folder. Never store memory for this project in a user-level or external folder; if one appears there, move it into `Docs/Memory` and delete the external copy.

## Conventions to respect when editing the prompts and scripts

- **Idempotent, check-then-apply.** Every step must report "already ok" when the desired state exists and produce no changes on a second run. The update script writes only changed wrappers and must report `0 written` on a second run.
- **Never commits.** The prompts only edit the working tree and report the changed files split into "tracked (review and commit yourself)" and "local".
- **Neutral wording in committed output of target repositories.** Anything a prompt writes to a tracked file of a target repository (the `AGENTS.md` block) must not match `claude|anthropic`. Vendor names are allowed in git-ignored files, in the workspace and at user level.
- **Harness files are tracked in this repo.** This repository is the source of the prompts, so `CLAUDE.md`, `.claude/` and the prompts are deliberately committed here; the repo `.gitignore` un-ignores them (`!CLAUDE.md`, `!.claude/`, `!init-harness.md`, `!CLAUDE.local.md`) against the global excludes. Keep those lines. Its origin URL is in `Hooks/no-ai-attribution.allow`, so the commit guard checks only its commit messages, not its staged content.
- **Hooks are tested from script files.** Once the hooks are active they block inline test commands that contain what they block. Write a test script with the file tool and pass paths without a vendor name in them (the scratch folder of a session can contain one).
- **Git for Windows tools.** GNU grep 3.0 of Git Bash aborts on `-i` combined with `-F` (fold case with `tr` instead), and in basic regex `\+` is a quantifier (use `grep -E` for a literal `+`). Count carriage returns with `tr -cd '\r' < <file> | wc -c`: `grep -c $'\r'` counts every line there and grep ignores CR.
- **JSON and markdown edits are merges.** Settings files are merged key by key; markdown with managed blocks is replaced only between the `<!-- name:begin -->` / `<!-- name:end -->` markers.
- **Shell rules.** The prompts and scripts obey the `shell-commands` rule of `esaf-core`: files only through the file tools, LF and UTF-8 without BOM, a heredoc only as quoted input to a command. This user's git has `core.autocrlf=true` (system-wide); the repo's `.gitattributes` overrides it with LF, but still check `git diff --stat` against `git diff -w --stat` before committing and never change `core.autocrlf` without asking.
- **Parameters live at the top of each prompt** (`## Parameters`). Change them there, not inline in steps.

## Note on this file

This repository is the source of the prompts, not a target: do not run `init-harness.md` or `setup-machine.md` against it as a target repository.
