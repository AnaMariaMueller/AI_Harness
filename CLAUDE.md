# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

`AI_Harness` holds the prompt that sets up an AI coding harness inside other git repositories. There is no application code, no build system, and no test suite. The repository has no commits yet.

The single meaningful file is `Prompts/init-harness.md`. It is an executable, step-by-step prompt (Steps 0 to 13) that, when run in a target repository, configures Claude Code and GitHub Copilot side by side:

- Git-ignores all harness files globally (`.claude/`, `CLAUDE.md`, `CLAUDE.local.md`, `init-harness.md`) via `core.excludesfile`.
- Writes user-level and project-level `settings.json` (thinking summaries on, attribution off, in-repo auto memory, connectors and MCP disabled).
- Makes `AGENTS.md` the committed, tool-neutral source of truth, with managed blocks: `harness-rules`, `project-overview`, `harness-customizations`.
- Keeps `CLAUDE.md` as a git-ignored local file that imports `AGENTS.md` and lists generated wrappers (managed block `harness-local`).
- Stores persistent memory in `Docs/Memory` inside the target repo and migrates any existing memory from `~/.claude/projects/<slug>/memory/`.
- Registers a private Azure DevOps plugin marketplace (`esaf`) in the committed `.github/copilot/settings.json` and the VS Code user settings, checks that a fixed plugin list is installed under `~/.copilot/installed-plugins` (never running the Copilot CLI; missing plugins are reported with instructions to install them from the VS Code Extensions view using the `@agentPlugins` filter, and no installed plugin is ever disabled), and generates `.claude/agents`, `.claude/rules`, `.claude/skills` wrappers from `.github/` customizations and installed plugins. Wrappers carry a `<!-- GENERATED from ... -->` marker and are regenerated on every run.
- Installs a `PreToolUse` Bash hook (`.claude/hooks/no-ai-attribution.sh`) that blocks `git commit` when the message or staged additions match `claude|anthropic` or contain `co-authored-by` / `generated with`.
- Hides `.claude` and `CLAUDE.md` (Windows `attrib +h`, or `.hidden` on Linux/macOS) and scrubs AI/vendor mentions from committed files and file names.

## Project memory

Persistent memory for this repository lives in `Docs/Memory` (index `MEMORY.md`, one fact per file) and is committed. `.claude/settings.json` sets `autoMemoryDirectory` to that folder. Never store memory for this project in a user-level or external folder; if one appears there, move it into `Docs/Memory` and delete the external copy.

## Conventions to respect when editing the prompt

- **Idempotent, check-then-apply.** Every step must report "already ok" when the desired state exists and produce no changes on a second run. Keep new steps in that style.
- **Never commits.** The prompt only edits the working tree and reports a table of changed files split into "tracked (review and commit yourself)" and "local, git-ignored".
- **Neutral wording in committed output.** Anything the prompt writes to a tracked file (`AGENTS.md`, `.github/copilot/settings.json`, `Docs/Memory`) must not match the case-insensitive pattern `claude|anthropic`. Vendor names are allowed only in git-ignored files such as `CLAUDE.md` and `.claude/`.
- **Harness files are tracked in this repo.** The prompt tells *target* repositories to keep `init-harness.md`, `CLAUDE.md` and `.claude/` out of git via the global excludes file. This repository is the source of the prompt, so those paths are deliberately committed here. The repo `.gitignore` un-ignores them (`!CLAUDE.md`, `!.claude/`, `!init-harness.md`, `!CLAUDE.local.md`) to override the global excludes; keep those lines.
- **JSON and markdown edits are merges.** Settings files are merged key by key; markdown with managed blocks is replaced only between the `<!-- name:begin -->` / `<!-- name:end -->` markers.
- **Shell assumptions.** Git Bash on Windows or POSIX elsewhere, forward slashes, and a fallback path for `claude` (VS Code extension native binary) when it is not on PATH. The Copilot CLI is never used; plugin state comes from the file system.
- **Delegation guidance is part of the spec.** Steps are tagged "delegate: mechanical" or similar; the prompt expects mechanical steps to run on the smallest available model and judgment calls to stay with the most capable one.
- **Parameters live at the top of the prompt.** Marketplace URL and name, plugin list, plugin install root, memory dir, and the forbidden/trailer patterns are defined once under `## Parameters`. Change them there, not inline in steps.

## Note on this file

The prompt's Step 5 expects `CLAUDE.md` in a target repo to be a generated, git-ignored local file with a `harness-local` managed block. This repository is the source of the prompt, not a target, so this file is plain, committed documentation. Do not run the harness prompt against this repository; it would git-ignore and hide the very files this repo exists to track.
