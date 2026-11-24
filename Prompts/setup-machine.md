# Set up this machine for Claude Code and the ESAF AI Toolkit
Last updated: 2026-11-24 01:00
You are setting up the current user's machine once. Run this prompt from a clone of the
AI_Harness repository (call its root HARNESS). Follow the steps in order. Every step is
**check, then apply**: if the desired state already exists, do nothing and report "already ok".
Running this prompt again must produce no changes. Do not commit anything. Do not ask questions
unless a step says "ask".

Afterwards, run `Prompts/init-harness.md` in each repository whose `.github/` customizations need
wrappers.

## Parameters
- MARKETPLACE_URL: https://dev.azure.com/trumagroup/TrumaAutomationFramework/_git/ESAF_AI_Toolkit
- MARKETPLACE_CLONE: `~/.vscode/agent-plugins/dev.azure.com/trumagroup/TrumaAutomationFramework/_git/ESAF_AI_Toolkit`
  (the clone of the marketplace repository that VS Code's Extensions view keeps per user)

## Working rules for this prompt
- Create and change files only with the file tools, as UTF-8 without BOM with LF line endings;
  merge JSON keys and keep everything else. Shell scripts additionally get `chmod +x`.
- Once the hook of Step 3 is active it blocks shell commands that break the `shell-commands` rule
  of `esaf-core`, including yours. Test a hook from a script file written with the file tool,
  never with an inline command that contains the text it blocks.
- Never take a screenshot.

## Step 1. Global git excludes
Local Claude Code files never reach a repository.
- If `git config --global core.excludesfile` is unset, set it to `~/.gitignore_global`.
- Ensure the file contains each of these lines exactly once (append only missing ones):
  `.claude/`, `CLAUDE.md`, `CLAUDE.local.md`, `init-harness.md`
- Verify in any repository with one call per path: `git check-ignore -q .claude/settings.json`,
  `CLAUDE.md`, `CLAUDE.local.md`, `init-harness.md`.

## Step 2. User settings (`~/.claude/settings.json`)
Merge these keys (create the file if missing):
```json
{
  "showThinkingSummaries": true,
  "attribution": { "commit": "", "pr": "", "sessionUrl": false }
}
```

## Step 3. Commit and shell hooks at user level
The hooks apply to every repository and workspace of this user.
- Copy `HARNESS/Hooks/no-ai-attribution.sh` and `HARNESS/Hooks/shell-rules.sh` to `~/.claude/hooks/`
  (overwrite when different; LF; `chmod +x`).
  - `no-ai-attribution.sh` blocks a `git commit` whose command or message names an assistant or
    vendor or carries a `co-authored-by` / `generated with` trailer, and one whose staged
    additions name an assistant or vendor. It finds the repository from `git -C <dir> commit`,
    `cd <dir> && git commit` or the current folder, and in a workspace root checks every clone
    below it.
  - `shell-rules.sh` blocks unquoted heredocs, redirection into a file (only `/dev/null`, `$null`
    and `&N` pass), `tee`, `sed -i`, `Out-File`/`Set-Content`/`Add-Content` and `git config` of
    `core.autocrlf` or `core.eol`.
- `~/.claude/hooks/no-ai-attribution.allow` lists repositories whose content names an assistant or
  vendor on purpose (origin URL or absolute path, one per line); their staged additions are not
  checked, their commit messages still are. Create it from `HARNESS/Hooks/no-ai-attribution.allow`
  when missing; otherwise append only missing lines and keep the user's own.
- Merge into `~/.claude/settings.json`; do not add an entry that already exists, keep other hooks:
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/hooks/no-ai-attribution.sh\"" } ] },
      { "matcher": "Bash|PowerShell",
        "hooks": [ { "type": "command", "command": "bash \"$HOME/.claude/hooks/shell-rules.sh\"" } ] }
    ]
  }
}
```
- Earlier harness versions registered the same hooks per repository
  (`"$CLAUDE_PROJECT_DIR"/.claude/hooks/no-ai-attribution.sh` or `shell-rules.sh` in a local
  `.claude/settings.json`). Find them in the repositories and workspaces the user names, report
  them as duplicates and **ask** before removing the entry and the local script.

## Step 4. ESAF AI Toolkit plugins
- MARKETPLACE_CLONE must exist. If it does not, report "needs attention" with these instructions and
  continue with Step 5:
  1. In VS Code, add MARKETPLACE_URL to the user setting `chat.plugins.marketplaces`.
  2. Open the Extensions view (`Ctrl+Shift+X`), type `@agentPlugins` and install the plugins of the
     `esaf` marketplace. This creates the clone.
  3. Run this step again.
- Run `pwsh -NoProfile -File HARNESS/Scripts/Update-EsafPlugins.ps1`. It fast-forwards the clone,
  installs or updates every marketplace plugin in the GitHub Copilot CLI, and regenerates the
  user-level wrappers (`~/.claude/agents`, `rules`, `skills`, `commands`). A non-zero exit is
  "needs attention" with its output.
- The same script runs after every publish of the toolkit (a pull request completed into its
  `master`). It is never scheduled.

## Step 5. Connectors and MCP servers, per repository or workspace
- **Ask** the user which repositories and workspaces to configure, and for each one whether
  connectors and MCP servers are off (default) or on.
- Off: merge `{ "disableClaudeAiConnectors": true, "enableAllProjectMcpServers": false }` into the
  folder's `.claude/settings.json` (a workspace: the workspace root's; a repository inside a
  workspace is configured through its workspace). On: remove those two keys if present.
- Never create an `.mcp.json`. Report an untracked one; do not delete it.

## Step 6. Report
Print one table with a row per step: `step | status (already ok / applied / needs attention) | details`.
List every file created or changed. End with these checks: both hook scripts exist and
`test -x` succeeds; `~/.claude/settings.json` is valid JSON and lists both hooks exactly once;
the four paths of Step 1 are ignored; the update script exited with 0; every file this run created
or changed has no CR (`tr -cd '\r' < <file> | wc -c` prints `0`; `grep -c $'\r'` is unreliable in
Git Bash) and no BOM (`head -c 3 <file> | od -An -c` does not show `357 273 277`).
