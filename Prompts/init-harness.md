
# Initialize the AI harness in this repository
You are setting up Claude Code in the git repository of the current working directory.
Follow the steps in order. Every step is **check, then apply**: if the desired state already
exists, do nothing and report "already ok". Running this prompt again must produce no changes.
Do not commit anything. Do not ask questions unless a step says "ask".
## Parameters
- MARKETPLACE_URL: https://dev.azure.com/trumagroup/TrumaAutomationFramework/_git/ESAF_AI_Toolkit
- MARKETPLACE_NAME: esaf (the `name` field of the marketplace manifest; read it from the manifest if it differs)
- PLUGINS: esaf-core, atlassian-cloud, esaf-next, inetx-system, istqb-test-strategy, firmware-review, tools-ni, tools-linworks
- PLUGIN_INSTALL_ROOT: `~/.vscode/agent-plugins/dev.azure.com/trumagroup/TrumaAutomationFramework/_git/ESAF_AI_Toolkit/plugins`
  (the clone of the marketplace repository that VS Code's Extensions view keeps per user; a plugin lives at
  `PLUGIN_INSTALL_ROOT/<plugin>/`. The Copilot CLI's own store `~/.copilot/installed-plugins/<MARKETPLACE_NAME>/<plugin>/`
  is not used by VS Code and stays empty on a VS Code-only machine.)
- MEMORY_DIR (relative to repo root): Docs/Memory
- FORBIDDEN_PATTERN (case-insensitive regex, applied to committed content and commit messages): `claude|anthropic`
- TRAILER_PATTERN (additionally blocked in commit messages): `co-authored-by|generated with`
## Working rules for this prompt
- Delegate whenever it makes sense: judge the complexity of each task and prefer a subagent on
  a lighter model when the task is well scoped and the lighter model can complete it reliably.
  Mechanical work (inventories, scans, generating files from an exact spec) suits the smallest
  available model; prose rewriting suits a mid-tier model; orchestration, design and judgment
  calls stay with the most capable model. Doing a task yourself is fine when it is complex,
  ambiguous or too small to be worth handing over. Run independent subagents in parallel.
- Never write "Claude", "Anthropic" or any model name into a file that git tracks. Committed
  files use neutral wording: "the assistant", "the AI harness", "the local wrapper folder".
  This prompt file itself (`init-harness.md`) names the harness paths and must never be
  committed; Step 1 keeps it out of git.
- When editing JSON settings, merge keys and keep everything else untouched. When editing
  markdown that has managed blocks, replace only the text between the markers.
- Shell is Git Bash on Windows or a POSIX shell elsewhere; use forward slashes.
- Command line tools: `claude` may be missing from the Git Bash PATH; fall back to the binary of
  the VS Code extension (`~/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude.exe`).
  If it cannot be found, report it in the step that needs it. Never run the GitHub Copilot CLI
  (`copilot`): plugin state is read from the file system, and missing plugins are installed by
  the user in VS Code (Step 8c).
- Never take a screenshot (screen, window, browser, app) without the user's explicit consent for
  that specific screenshot. This applies to you and to every subagent you launch.
## Step 0. Inventory (delegate: mechanical)
- `git rev-parse --show-toplevel` must succeed; stop otherwise. Call the result REPO.
- Record what exists: `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, `.claude/`,
  `.github/copilot-instructions.md`, `.github/copilot/settings.json`,
  `.github/instructions/*.instructions.md`, `.github/prompts/*.prompt.md`,
  `.github/agents/*.agent.md`, `.github/chatmodes/*.chatmode.md`, `MEMORY_DIR`,
  `~/.claude/settings.json`, `~/.copilot/settings.json` (read only; keys `extraKnownMarketplaces`
  and `enabledPlugins`), the VS Code user settings (`%APPDATA%/Code/User/settings.json`, key
  `chat.plugins.marketplaces`), output of `git config --global core.excludesfile`, and the
  folders under `PLUGIN_INSTALL_ROOT/` that contain a `plugin.json` (these
  are the installed plugins; no CLI is involved).
- Tracked harness files at any depth:
  `git ls-files | grep -E '(^|/)(\.claude/|CLAUDE\.md$|CLAUDE\.local\.md$)'`. If any are listed,
  run `git rm --cached` on each one (the global excludes of Step 1 keep them ignored afterwards)
  and report it. Nested `.claude` folders and `CLAUDE.md` files found here are also targets of Step 11.
## Step 1. Git-ignore the harness in every repository of this user
- If `core.excludesfile` is unset, set it: `git config --global core.excludesfile ~/.gitignore_global`.
- Ensure the file exists and contains each of these lines exactly once (append only missing ones):
  `.claude/`, `CLAUDE.md`, `CLAUDE.local.md`, `init-harness.md`
- Verify with one call per path (`git check-ignore -q` accepts a single pathname):
  `.claude/settings.json`, `CLAUDE.md`, `CLAUDE.local.md`, `init-harness.md`.
- Do not add these lines to the repository's own `.gitignore` (that would be a mention in a committed file).
## Step 2. User-level settings (`~/.claude/settings.json`)
Merge these keys (create the file if missing):
```json
{
  "showThinkingSummaries": true,
  "attribution": { "commit": "", "pr": "", "sessionUrl": false }
}
```
## Step 3. Shared rules in `AGENTS.md` (committed, tool-neutral)
Create `AGENTS.md` at REPO if missing. Ensure it contains a managed block delimited by
`<!-- harness-rules:begin -->` and `<!-- harness-rules:end -->`. Replace the block if present,
append it otherwise. Block content:
```markdown
<!-- harness-rules:begin -->
## Rules for AI assistants
### No AI attribution
- Never add `Co-Authored-By` trailers, "Generated with ..." lines, session links, or any
  assistant, model or vendor name to commit messages, pull request descriptions, changelogs,
  source files, comments or documentation.
- Commit messages describe the change only.
### Assistant customizations: Copilot first, wrappers second
- The source of truth for assistant behaviour is `.github/`:
  `copilot-instructions.md`, `instructions/*.instructions.md`, `prompts/*.prompt.md`,
  `agents/*.agent.md`, and the GitHub Copilot plugins enabled in `copilot/settings.json`.
- When asked to create or modify an agent, instruction, prompt or rule: first create or modify
  the GitHub Copilot customization under `.github/`, then regenerate the local, git-ignored
  wrapper folder from it (run the harness initialization prompt, wrapper step). Never put
  behaviour only in a wrapper.
- Shared, cross-project behaviour belongs in a plugin of the team's plugin marketplace, not in
  this repository. Never copy plugin files into the repository; enable the plugin instead.
- Wrappers are generated files; do not edit them by hand.
### Project knowledge stays in the repository
- Persistent memory lives in `Docs/Memory` (index file `MEMORY.md`, one fact per file).
- Do not store project-specific notes in user-level or external folders.
- Memory files use neutral wording and never name an assistant or vendor.
### Delegation
- Judge the complexity of each task and delegate whenever it makes sense: prefer the least
  capable model that can complete the task reliably, regardless of which assistant or vendor
  provides the models.
- Mechanical tasks (scans, inventories, generating files from a spec, running tests) suit the
  smallest available model. Prose rewriting and moderate refactors suit a mid-tier model.
  Design, ambiguity and review stay with the most capable model.
- The model that receives the request decides. It may carry out a task itself when the task is
  complex, ambiguous or too small to be worth handing over.
### Connectors
- This repository uses no connectors or MCP servers. Do not add an `.mcp.json`.
### Screenshots
- Never take a screenshot of the screen, a window, a browser or an application without the
  user's explicit consent for that specific screenshot. Ask first, every time; a previous
  consent does not carry over.
<!-- harness-rules:end -->
```
## Step 4. Project overview via `/init`, stored in `AGENTS.md`
- If `AGENTS.md` has no block delimited by `<!-- project-overview:begin -->` /
  `<!-- project-overview:end -->`, run `/init`. It writes `CLAUDE.md`. Move the project
  knowledge it produced (build and test commands, layout, conventions) into that block in
  `AGENTS.md`, in neutral wording with no FORBIDDEN_PATTERN hits.
- If the block exists, run `/init` and merge only genuinely new facts into the block.
- `CLAUDE.md` is rewritten in Step 5; do not leave `/init` output in it.
## Step 5. Local `CLAUDE.md` (git-ignored)
Ensure `CLAUDE.md` at REPO contains a managed block between `<!-- harness-local:begin -->` and
`<!-- harness-local:end -->` (keep any other text). The wrapper list at the end is generated
in Step 10c.
```markdown
<!-- harness-local:begin -->
@AGENTS.md
@.github/copilot-instructions.md   <- include this line only if the file exists
Local notes for Claude Code (this file is git-ignored):
- Wrappers under `.claude/agents`, `.claude/rules`, `.claude/skills` are generated from `.github/`
  and from the GitHub Copilot plugins enabled in `.github/copilot/settings.json` (installed under
  `~/.vscode/agent-plugins`). To change behaviour, edit the `.github/` source or update the
  plugin, then regenerate (harness init prompt, Step 10).
- Auto memory is stored in `Docs/Memory` inside the repository (see `.claude/settings.json`).
- No connectors or MCP servers in this repository.
Generated wrappers (source -> wrapper):
<list from Step 10c>
<!-- harness-local:end -->
```
## Step 6. Memory folder in the repository
- Create `REPO/MEMORY_DIR/MEMORY.md` if missing, with the header `# Project memory index`
  and one line explaining: "One file per fact; this index holds one pointer line per file."
  No other content.
- Migrate: the default memory folder is `~/.claude/projects/<slug>/memory/`, where `<slug>` is
  the absolute REPO path with every character that is not a letter or digit replaced by `-`.
  If it exists and has files, move them into `MEMORY_DIR` (skip files with identical content
  already present), append their index lines to `MEMORY.md`, and remove them from the user
  folder. Report what moved.
- Ensure nothing under `MEMORY_DIR` matches FORBIDDEN_PATTERN; rewrite with neutral wording if it does.
## Step 7. Project-local settings (`REPO/.claude/settings.json`, git-ignored)
Merge these keys (absolute path for the memory dir, computed from REPO):
```json
{
  "showThinkingSummaries": true,
  "autoMemoryDirectory": "<REPO absolute path>/Docs/Memory",
  "disableClaudeAiConnectors": true,
  "enableAllProjectMcpServers": false
}
```
Do not create `.mcp.json`. If one exists and is untracked, report it; do not delete it.
## Step 8. GitHub Copilot plugin marketplace and plugins
The marketplace follows the Agent Plugins layout (`.github/plugin/marketplace.json`, plugin
content under `com.github.copilot/` and `skills/`). The `claude plugin` commands do not read
that layout, so the plugins are installed by the user through VS Code's Extensions view and
reach the harness through the wrappers of Step 10. Do not run `claude plugin marketplace add`
for MARKETPLACE_URL and do not run the Copilot CLI; this step only edits settings files, reads
PLUGIN_INSTALL_ROOT and reports.
### 8a. Recommend the plugins in the repository (committed, `.github/copilot/settings.json`)
Merge these keys (create the file if missing). GitHub Copilot offers the listed plugins to
everyone who opens the repository; the file contains no credentials and no vendor name.
```json
{
  "extraKnownMarketplaces": {
    "<MARKETPLACE_NAME>": { "source": { "source": "git", "url": "<MARKETPLACE_URL>" } }
  },
  "enabledPlugins": { "<plugin>@<MARKETPLACE_NAME>": true, "...": true }
}
```
One `enabledPlugins` entry per plugin in PLUGINS, always `true`. Keep entries that are already
there unchanged. Never disable a plugin in this file: never write `false` for any entry and never
remove an entry. A plugin that is installed under PLUGIN_INSTALL_ROOT but missing from PLUGINS
keeps whatever entry it has (or none) and is reported in Step 8c.
### 8b. Register the marketplace on this machine
- `~/.copilot/settings.json` is read, never written: if MARKETPLACE_URL is missing from its
  `extraKnownMarketplaces`, report it as information only. VS Code finds the marketplace through
  `chat.plugins.marketplaces` (next bullet) and through the repository's
  `.github/copilot/settings.json` (Step 8a). Do not run the Copilot CLI to register it.
- VS Code: ensure the user settings (`%APPDATA%/Code/User/settings.json`; `~/Library/Application
  Support/Code/User/settings.json` on macOS; `~/.config/Code/User/settings.json` on Linux)
  contain MARKETPLACE_URL in the array `chat.plugins.marketplaces`. Merge; create the file if
  missing. If the file contains comments, do not rewrite it: report the exact snippet for the
  user to paste instead.
### 8c. Check the installed plugins (report only; the user installs them in VS Code)
- A plugin is installed when `PLUGIN_INSTALL_ROOT/<plugin>/plugin.json`
  exists. Compare the installed set with PLUGINS. Never install, update, remove or disable a
  plugin yourself, and never run the Copilot CLI.
- If no plugin of PLUGINS is installed (fresh machine) or at least one plugin of PLUGINS is
  missing (the plugin set changed since the last run), report "needs attention" with these
  instructions for the user, and continue with the plugins that are installed:
  1. In VS Code, open the Extensions view (`Ctrl+Shift+X`) and type `@agentPlugins` in the
     search box.
  2. Install each missing plugin of PLUGINS from the `<MARKETPLACE_NAME>` marketplace (name
     the missing plugins in the report).
  3. Run this prompt again so the wrappers of Step 10 are generated.
  A plugin the marketplace does not offer is reported, not treated as an error.
- A plugin installed under `PLUGIN_INSTALL_ROOT/` that is not in PLUGINS is
  reported and left as it is; its entry in `.github/copilot/settings.json`, if any, stays
  enabled (Step 8a).
### 8d. Project facts the plugins need (report only)
Each installed plugin's `README.md` has a section "Facts to add to AGENTS.md" naming a heading
(for example `## Azure DevOps facts`). For every such heading missing from `AGENTS.md`, report it
and tell the user to run `/setup-esaf-toolkit` in Copilot chat (or copy the section from the
plugin README) and fill in the values. Do not write these sections yourself; their values are
project facts only the user knows.
## Step 9. Commit guard hook (local)
- Ensure `REPO/.claude/hooks/no-ai-attribution.sh` exists with exactly this content (overwrite if different):
```bash
#!/usr/bin/env bash
# Blocks git commits whose message or staged additions mention an AI assistant or vendor.
pattern='claude|anthropic'
trailer='co-authored-by|generated with'
input=$(cat)
command=$(printf '%s' "$input" | sed -n 's/.*"command":"\(.*\)".*/\1/p')
case "$command" in *"git commit"*) ;; *) exit 0 ;; esac
if printf '%s' "$command" | grep -qiE "$pattern|$trailer"; then
  echo "Blocked: the commit command or message matches '$pattern|$trailer'." >&2; exit 2
fi
if git diff --cached --diff-filter=AM | grep -E '^\+' | grep -v '^\+\+\+' | grep -qiE "$pattern"; then
  echo "Blocked: staged additions match '$pattern'. Run: git diff --cached | grep -niE '$pattern'" >&2; exit 2
fi
exit 0
```
- Make it executable (`chmod +x`). Merge into `REPO/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [ { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/no-ai-attribution.sh" } ]
      }
    ]
  }
}
```
If an identical hook entry already exists, do not add a second one.
- Note: once this hook is active it also blocks your own shell commands whose text contains
  `git commit` together with a forbidden word (for example a test of the hook). Test the hook
  from a script file instead of an inline command.
## Step 10. Wire every GitHub Copilot customization and plugin (delegate: mechanical, with this spec)
This step covers **all** customizations found in Step 0, whether they existed before this prompt
was first run or were added later, and the content of every plugin enabled in
`.github/copilot/settings.json` that is installed under PLUGIN_INSTALL_ROOT. A customization is
wired when (a) it has a wrapper under `.claude/`, (b) it is listed in the inventory block of
`AGENTS.md`, and (c) it is listed in the local block of `CLAUDE.md`. Check all three for each
file; a missing piece is "applied", a present and identical piece is "already ok".
### 10a. Wrappers
Generate wrappers into `REPO/.claude/`. Every wrapper carries a marker line directly after its
frontmatter: `<!-- GENERATED from <source>. Edit the source, then regenerate. -->` for
repository sources, `<!-- GENERATED from plugin <plugin>@<MARKETPLACE_NAME> (<path inside the
plugin>). Update the plugin, then regenerate. -->` for plugin sources. Regenerate all wrappers on
every run (overwrite; normalize line endings to LF). Delete any file in `.claude/agents`,
`.claude/rules`, `.claude/skills` that carries the GENERATED marker but was not regenerated in
this run (its source is gone, or its plugin is no longer installed or no longer listed in
`enabledPlugins`); a skill folder is deleted as a whole.
Never touch files without the marker; report them if they block a wrapper.
| Source | Wrapper | Frontmatter mapping |
|---|---|---|
| `.github/copilot-instructions.md` | imported from `CLAUDE.md` (Step 5), no wrapper file | n/a |
| `.github/instructions/<n>.instructions.md` and plugin `com.github.copilot/rules/<n>.instructions.md` | `.claude/rules/<n>.md` | `applyTo` -> `paths` (same globs, as a YAML list; `**` when absent); body copied |
| `.github/agents/<n>.agent.md`, `.github/chatmodes/<n>.chatmode.md` and plugin `com.github.copilot/agents/<n>.agent.md` | `.claude/agents/<n>.md` | `name` copied (file stem when absent), `description` copied; `model` omitted (inherit); `tools` omitted unless the source lists only read-only tools (`codebase`, `search`, `fetch`, `usages`), then `tools: Read, Grep, Glob, WebFetch`; body copied |
| `.github/prompts/<n>.prompt.md` and plugin `com.github.copilot/commands/<n>.md` | `.claude/skills/<n>/SKILL.md` | `name: <n>`, `description` copied (or first body line), `disable-model-invocation: true`; body copied, `${input:...}` placeholders replaced with `$ARGUMENTS` |
| plugin `skills/<n>/` (folder with `SKILL.md`, `references/`, `scripts/`) | `.claude/skills/<n>/` (whole folder copied, relative paths stay valid) | `SKILL.md` keeps its own frontmatter (`name`, `description`); marker inserted after it |
Copilot tool names in the body (`#codebase`, `#fetch`, ...) are left as they are.
Name collisions: the repository's own customization wins over a plugin item of the same name,
and the first enabled plugin wins over a later one; every collision is reported. A plugin listed
in `enabledPlugins` but not installed is reported (Step 8c tells the user how to install it).
### 10b. Inventory block in `AGENTS.md` (committed, tool-neutral)
Ensure `AGENTS.md` has a managed block between `<!-- harness-customizations:begin -->` and
`<!-- harness-customizations:end -->`, regenerated on every run from the files actually present:
```markdown
<!-- harness-customizations:begin -->
## Available assistant customizations
Source of truth: `.github/` and the plugins enabled in `.github/copilot/settings.json`. Each entry has a generated local wrapper of the same name.
| Kind | Source | Wrapper name | Purpose |
|---|---|---|---|
| agent | `.github/agents/<n>.agent.md` | `<n>` | <description from frontmatter> |
| instruction | `.github/instructions/<n>.instructions.md` | rule `<n>` (applies to: <applyTo>) | <description> |
| plugin | `<plugin>@<MARKETPLACE_NAME>` <version> | wrappers of its agents, commands, rules and skills | <description from plugin.json> |
| prompt | `.github/prompts/<n>.prompt.md` | skill `/<n>` | <description> |
| repository instructions | `.github/copilot-instructions.md` | imported by the local instructions file | always on |
<!-- harness-customizations:end -->
```
Rows are sorted by kind then name; one row per plugin (its items are listed in the plugin's own
README, not here). If no customizations exist, the block contains the heading and the sentence
"None yet. Add them under `.github/` and regenerate."
### 10c. Wrapper list in the local `CLAUDE.md`
Inside the `harness-local` block of Step 5, replace `<list from Step 10c>` with one line per
repository wrapper and one line per plugin:
```markdown
- .github/agents/<n>.agent.md -> .claude/agents/<n>.md   (subagent `<n>`)
- .github/instructions/<n>.instructions.md -> .claude/rules/<n>.md
- .github/prompts/<n>.prompt.md -> .claude/skills/<n>/SKILL.md   (skill `/<n>`)
- plugin <plugin>@<MARKETPLACE_NAME> -> agents: <n>, <n>; rules: <n>; skills: /<command>, <skill>
```
Regenerate this list on every run so removed sources disappear from it. If there are no
wrappers, the single line is `- none`. `CLAUDE.md` is hidden after Step 11; clear the hidden
attribute before rewriting it and set it again afterwards.
## Step 11. Hide the harness folder and files
Run this after Steps 5, 7, 9 and 10 so every file exists. Targets at REPO: `.claude` (the folder
itself), `CLAUDE.md`, and `CLAUDE.local.md` if present, plus any nested `.claude` folder or
`CLAUDE.md` file that exists in the working tree (Step 0 lists the ones that were tracked).
- Windows (Git Bash): `attrib` takes one target per call. For each target,
  `attrib "<target>" | grep -q ' H '` is "already ok"; otherwise run `attrib +h "<target>"`.
  For the folder use `attrib +h .claude` only; do not recurse into its contents.
- Linux and macOS: the folder is already hidden by its leading dot. Hide the files by creating
  or updating a `.hidden` file in REPO that lists `CLAUDE.md` and `CLAUDE.local.md`, one per
  line, adding only missing lines. Add `.hidden` to the global excludes file of Step 1 the same way.
- Note: some editors and tools refuse to overwrite a hidden file. If a later edit of `CLAUDE.md`
  fails for that reason, clear the attribute, edit, and set it again.
## Step 12. Remove AI mentions from committed files (delegate: scan is mechanical, rewrite is prose)
- `git ls-files -z | xargs -0 grep -IliE "FORBIDDEN_PATTERN"` (text files only).
- For each hit: rewrite the offending lines in the working tree with neutral wording
  ("the AI assistant", "an AI-assisted session"), delete `Co-Authored-By` trailer lines that
  name an assistant, keep the meaning and formatting of everything else. Do not rewrite git history.
- File and folder names: `git ls-files | grep -iE "FORBIDDEN_PATTERN"`. For each hit, rename
  the file or folder with `git mv` to a neutral name (for example `Prompt05_ClaudeOpus.md` ->
  `Prompt05_AiAssistant.md`), update references to the old name in tracked files, and report
  the rename. If the file is already deleted in the working tree, run `git rm` instead.
- Also run `git log --all -i -E --grep="FORBIDDEN_PATTERN" --format='%h %s' | head -50` and
  only **report** past commit messages that match.
## Step 13. Report
Print one table with a row per step: `step | status (already ok / applied / needs attention) | details`.
For Step 8 list the plugins installed, the plugins missing (with the `@agentPlugins` install
instructions of Step 8c), the plugins installed but not in PLUGINS (left enabled), and the facts
headings missing from `AGENTS.md`. List every file created or changed, separated into "tracked
(review and commit yourself)" and "local, git-ignored" (user-level files such as the VS Code user
settings count as local). End with the result of a final check:
`git ls-files -z | xargs -0 grep -IliE "FORBIDDEN_PATTERN"` and
`git ls-files | grep -iE "FORBIDDEN_PATTERN"` must both print nothing,
`git check-ignore -q .claude/settings.json` and `git check-ignore -q CLAUDE.md` must each succeed,
`PLUGIN_INSTALL_ROOT/<plugin>/plugin.json` must exist for every plugin of
PLUGINS (or Step 8c reports which are missing and how to install them), and on
Windows `attrib .claude` and `attrib CLAUDE.md` (one target per call) must each show `H`.
