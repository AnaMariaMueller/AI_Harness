#Requires -Version 7
<#
.SYNOPSIS
    Brings this PC up to the published ESAF toolkit: updates the VS Code marketplace clone, installs
    or updates every marketplace plugin in the GitHub Copilot CLI, and regenerates the user-level
    Claude Code wrappers of all plugins.

.DESCRIPTION
    Run it after every publish of the ESAF AI Toolkit (a pull request completed into master), or
    any time the wrappers look out of date. No scheduled task is involved.

    1. Marketplace clone (the folder VS Code's Extensions view keeps under ~/.vscode/agent-plugins):
       fetch and fast-forward to origin/<Branch>. A clone with local changes or a non-fast-forward
       history stops the script; nothing is reset or discarded.
    2. Copilot CLI: registers the marketplace if missing, then installs every plugin listed in
       .github/plugin/marketplace.json that is not installed and updates every installed one whose
       version differs from the manifest.
    3. Claude Code wrappers, from the marketplace clone, for every plugin of the manifest:
         skills    -> ~/.claude/skills/<skill>/SKILL.md   (pointer to the plugin's SKILL.md)
         agents    -> ~/.claude/agents/<agent>.md         (subagent, pointer to the agent file)
         commands  -> ~/.claude/commands/<command>.md     (slash command, pointer to the command)
         rules     -> ~/.claude/rules/esaf-<rule>.md      (copy of the rule body, applyTo -> paths)
       Every generated file carries the marker 'esaf-claude-wrapper'. Files without it are never
       touched; generated files whose source has disappeared are removed.

.PARAMETER MarketplaceClone
    The VS Code clone of the marketplace repository.

.PARAMETER Marketplace
    Marketplace name (the "name" of .github/plugin/marketplace.json). Default: esaf.

.PARAMETER Branch
    Published branch of the marketplace repository. Default: master.

.PARAMETER SkipPull
    Do not fetch or fast-forward the clone.

.PARAMETER SkipCopilot
    Do not install or update plugins in the Copilot CLI.

.PARAMETER SkipWrappers
    Do not regenerate the Claude Code wrappers.

.EXAMPLE
    pwsh -File Scripts/Update-EsafPlugins.ps1
.EXAMPLE
    pwsh -File Scripts/Update-EsafPlugins.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$MarketplaceClone = (Join-Path $HOME '.vscode/agent-plugins/dev.azure.com/trumagroup/TrumaAutomationFramework/_git/ESAF_AI_Toolkit'),
    [string]$Marketplace = 'esaf',
    [string]$Branch = 'master',
    [switch]$SkipPull,
    [switch]$SkipCopilot,
    [switch]$SkipWrappers
)

$ErrorActionPreference = 'Stop'
$Failures = [System.Collections.Generic.List[string]]::new()

function ConvertTo-Fwd([string]$Path) { $Path -replace '\\', '/' }

if (-not (Test-Path -LiteralPath (Join-Path $MarketplaceClone '.git'))) {
    throw "No marketplace clone at $MarketplaceClone. Add the marketplace in VS Code (Extensions view, @agentPlugins) first."
}

# ---------------------------------------------------------------- 1. marketplace clone
Write-Host "== Marketplace clone: $(ConvertTo-Fwd $MarketplaceClone)"
$before = (git -C $MarketplaceClone rev-parse --short HEAD).Trim()
if ($SkipPull) {
    Write-Host "skip  pull (-SkipPull); clone at $before"
} else {
    $dirty = git -C $MarketplaceClone status --porcelain
    if ($dirty) { throw "The marketplace clone has local changes; resolve them first:`n$($dirty -join "`n")" }
    git -C $MarketplaceClone fetch --quiet origin $Branch
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed in $MarketplaceClone (exit $LASTEXITCODE)." }
    $remote = (git -C $MarketplaceClone rev-parse --short "origin/$Branch").Trim()
    if ($remote -eq $before) {
        Write-Host "ok    already at origin/$Branch ($before)"
    } elseif ($PSCmdlet.ShouldProcess($MarketplaceClone, "Fast-forward $before -> $remote")) {
        git -C $MarketplaceClone checkout --quiet $Branch
        git -C $MarketplaceClone merge --ff-only --quiet "origin/$Branch"
        if ($LASTEXITCODE -ne 0) { throw "Fast-forward to origin/$Branch failed; the clone's history diverged. Nothing was reset." }
        Write-Host "done  $before -> $remote"
    }
}

$manifestPath = Join-Path $MarketplaceClone '.github/plugin/marketplace.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.name -ne $Marketplace) {
    Write-Warning "Marketplace manifest is named '$($manifest.name)', not '$Marketplace'; using '$($manifest.name)'."
    $Marketplace = $manifest.name
}
$Plugins = foreach ($p in $manifest.plugins) {
    [pscustomobject]@{
        Name    = $p.name
        Version = $p.version
        Dir     = [IO.Path]::GetFullPath((Join-Path $MarketplaceClone ($p.source -replace '^\./', '')))
    }
}
Write-Host "      marketplace $Marketplace v$($manifest.metadata.version): $($Plugins.Count) plugins"

# ---------------------------------------------------------------- 2. Copilot CLI
Write-Host "== Copilot CLI"
if ($SkipCopilot) {
    Write-Host "skip  (-SkipCopilot)"
} elseif (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    $Failures.Add('copilot CLI not found on PATH; plugins were not installed or updated there.')
    Write-Warning $Failures[-1]
} else {
    $marketplaces = (copilot plugin marketplace list 2>&1) -join "`n"
    if ($marketplaces -notmatch "(?m)^\s*\S+\s+$([regex]::Escape($Marketplace))\s+\(") {
        $url = (git -C $MarketplaceClone remote get-url origin).Trim()
        if ($PSCmdlet.ShouldProcess("copilot marketplace $Marketplace", "Register $url")) {
            copilot plugin marketplace add $url
            if ($LASTEXITCODE -ne 0) { throw "copilot plugin marketplace add failed (exit $LASTEXITCODE)." }
        }
    }
    $installed = @{}
    foreach ($m in [regex]::Matches(((copilot plugin list 2>&1) -join "`n"), "(?m)^\s*\S+\s+([\w.-]+)@$([regex]::Escape($Marketplace))\s+\(v([^)]+)\)")) {
        $installed[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    foreach ($p in $Plugins) {
        $id = "$($p.Name)@$Marketplace"
        if (-not $installed.ContainsKey($p.Name)) { $verb = 'install' }
        elseif ($installed[$p.Name] -ne $p.Version) { $verb = 'update' }
        else { Write-Host "ok    $id v$($p.Version)"; continue }
        $from = if ($verb -eq 'update') { "v$($installed[$p.Name]) -> " } else { '' }
        if ($PSCmdlet.ShouldProcess($id, "copilot plugin $verb (${from}v$($p.Version))")) {
            $out = copilot plugin $verb $id 2>&1
            if ($LASTEXITCODE -ne 0) {
                $Failures.Add("copilot plugin $verb $id failed (exit $LASTEXITCODE): $($out -join ' ')")
                Write-Warning $Failures[-1]
            } else {
                Write-Host "done  $verb $id ${from}v$($p.Version)"
            }
        }
    }
    $extra = $installed.Keys | Where-Object { $_ -notin $Plugins.Name }
    foreach ($e in $extra) { Write-Host "note  $e@$Marketplace is installed but no longer in the marketplace; left as it is." }
}

# ---------------------------------------------------------------- 3. Claude Code wrappers
Write-Host "== Claude Code wrappers"
if ($SkipWrappers) { Write-Host "skip  (-SkipWrappers)"; if ($Failures.Count) { exit 1 }; return }

$Marker = 'esaf-claude-wrapper'
$ClaudeRoot = Join-Path $HOME '.claude'
$Dirs = @{
    skills   = Join-Path $ClaudeRoot 'skills'
    agents   = Join-Path $ClaudeRoot 'agents'
    commands = Join-Path $ClaudeRoot 'commands'
    rules    = Join-Path $ClaudeRoot 'rules'
}
$ThisScript = ConvertTo-Fwd $PSCommandPath

function Read-Frontmatter([string]$Path) {
    $text = (Get-Content -LiteralPath $Path -Raw) -replace "`r`n", "`n"
    $meta = [ordered]@{}
    $body = $text
    if ($text -match '(?s)^---\n(.*?)\n---\n?(.*)$') {
        $body = $Matches[2]
        foreach ($line in $Matches[1] -split "`n") {
            if ($line -match '^([A-Za-z][\w-]*):\s*(.*)$') {
                $k = $Matches[1]
                $v = $Matches[2].Trim()
                if ($v -match '^"(.*)"$') { $v = $Matches[1] -replace '\\"', '"' }
                elseif ($v -match "^'(.*)'$") { $v = $Matches[1] -replace "''", "'" }
                $meta[$k] = $v
            }
        }
    }
    [pscustomobject]@{ Meta = $meta; Body = $body }
}

function Format-Yaml([string]$Value) { "'" + ($Value -replace "'", "''") + "'" }

# Copilot tool names -> Claude Code tool names (an agent's tool list restricts the subagent).
$ToolMap = @{
    search        = 'Read', 'Grep', 'Glob'
    codebase      = 'Read', 'Grep', 'Glob'
    usages        = 'Grep', 'Glob'
    findTestFiles = 'Glob', 'Grep'
    problems      = 'Read'
    edit          = 'Edit', 'Write'
    runCommands   = 'Bash', 'PowerShell'
    fetch         = 'WebFetch'
    agent         = 'Agent'
}
function Convert-Tools([string]$Value) {
    if (-not $Value) { return $null }
    $names = [regex]::Matches($Value, '[A-Za-z]+') | ForEach-Object { $_.Value }
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($n in @('Read', 'Skill') + ($names | ForEach-Object { $ToolMap[$_] })) {
        if ($n -and -not $out.Contains($n)) { $out.Add($n) }
    }
    $out -join ', '
}

$Expected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$Written = 0

function Write-Wrapper([string]$Path, [string]$Content) {
    $Content = ($Content -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    [void]$Expected.Add([IO.Path]::GetFullPath($Path))
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw
        if ($existing -notmatch [regex]::Escape($Marker)) {
            Write-Warning "Skipped $Path : exists and was not generated by this script."
            return
        }
        if ($existing -eq $Content) { return }
    }
    if ($PSCmdlet.ShouldProcess($Path, 'Write wrapper')) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
        [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
        $script:Written++
    }
}

$Mapping = @'
How this maps to Claude Code: the plugin was written for GitHub Copilot. Its skills are Claude
skills of the same name, its agents are Claude subagents of the same name, its commands are slash
commands of the same name, and its rules are loaded from ~/.claude/rules (files `esaf-<rule>.md`).
Copilot tool names map to Claude Code tools: search/codebase/usages -> Read, Grep, Glob;
edit -> Edit, Write; runCommands -> Bash or PowerShell; fetch -> WebFetch; agent -> Agent.
"Select an agent as the top-level agent" means: read that agent's file and act as it in this
session. Paths relative to the source file resolve against the folder of that file.
'@

foreach ($p in $Plugins) {
    if (-not (Test-Path -LiteralPath (Join-Path $p.Dir 'plugin.json'))) {
        $Failures.Add("Plugin $($p.Name): no plugin.json under $(ConvertTo-Fwd $p.Dir); no wrappers written.")
        Write-Warning $Failures[-1]
        continue
    }
    $plugin = $p.Name
    $pluginDir = $p.Dir
    $version = (Get-Content (Join-Path $pluginDir 'plugin.json') -Raw | ConvertFrom-Json).version
    $origin = "Generated by $ThisScript from the Copilot plugin $plugin@$Marketplace v$version. Do not edit; rerun the script."
    $cg = Join-Path $pluginDir 'com.github.copilot'

    # Skills
    foreach ($skill in Get-ChildItem -Path (Join-Path $pluginDir 'skills/*/SKILL.md') -ErrorAction SilentlyContinue) {
        $fm = Read-Frontmatter $skill.FullName
        $name = $fm.Meta.name ?? $skill.Directory.Name
        $src = ConvertTo-Fwd $skill.FullName
        $dir = ConvertTo-Fwd $skill.Directory.FullName
        Write-Wrapper (Join-Path $Dirs.skills "$name/SKILL.md") @"
---
name: $name
description: $(Format-Yaml $fm.Meta.description)
---

<!-- $Marker | $origin -->

# $name (ESAF plugin $plugin)

Before doing anything else, read ``$src`` in full and follow it as the instructions of this skill.
Its ``references/``, ``scripts/`` and other relative paths resolve against ``$dir``.

$Mapping
"@
    }

    # Agents
    foreach ($agent in Get-ChildItem -Path (Join-Path $cg 'agents/*.agent.md') -ErrorAction SilentlyContinue) {
        $fm = Read-Frontmatter $agent.FullName
        $name = $agent.Name -replace '\.agent\.md$', ''
        $tools = Convert-Tools $fm.Meta.tools
        $toolsLine = if ($tools) { "`ntools: $tools" } else { '' }
        $src = ConvertTo-Fwd $agent.FullName
        Write-Wrapper (Join-Path $Dirs.agents "$name.md") @"
---
name: $name
description: $(Format-Yaml $fm.Meta.description)$toolsLine
---

<!-- $Marker | $origin -->

You are the ``$name`` agent of the ESAF plugin ``$plugin``. Before anything else, read
``$src`` in full and follow it as your instructions, including the rules and skills it tells you
to read. Plugin folder: ``$(ConvertTo-Fwd $pluginDir)``.

$Mapping
A subagent cannot start further subagents: where the instructions delegate to another agent and no
Agent tool is available, apply that agent's instructions inline or hand the step back to the caller.
"@
    }

    # Commands
    foreach ($cmd in Get-ChildItem -Path (Join-Path $cg 'commands/*.md') -ErrorAction SilentlyContinue) {
        $fm = Read-Frontmatter $cmd.FullName
        $name = $cmd.BaseName
        $src = ConvertTo-Fwd $cmd.FullName
        $agentNote = ''
        if ($fm.Meta.agent) {
            $agentFile = ConvertTo-Fwd (Join-Path $cg "agents/$($fm.Meta.agent).agent.md")
            $agentNote = "`nThis command runs as the ``$($fm.Meta.agent)`` agent: first read ``$agentFile`` and act as that agent in this top-level session (do not start it as a subagent unless the command says so)."
        }
        Write-Wrapper (Join-Path $Dirs.commands "$name.md") @"
---
description: $(Format-Yaml $fm.Meta.description)
argument-hint: '[request]'
---

<!-- $Marker | $origin -->

Run the ESAF command ``/$name`` (plugin ``$plugin``). Read ``$src`` in full and follow it.$agentNote

User input for this command: `$ARGUMENTS

$Mapping
"@
    }

    # Rules (body copied: they must be in context)
    foreach ($rule in Get-ChildItem -Path (Join-Path $cg 'rules/*.instructions.md') -ErrorAction SilentlyContinue) {
        $fm = Read-Frontmatter $rule.FullName
        $name = $rule.Name -replace '\.instructions\.md$', ''
        $paths = @(($fm.Meta.applyTo ?? '**') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $pathsBlock = if ($paths.Count -eq 0 -or $paths -contains '**') { '' } else {
            "`npaths:`n" + (($paths | ForEach-Object { "  - $(Format-Yaml $_)" }) -join "`n")
        }
        Write-Wrapper (Join-Path $Dirs.rules "esaf-$name.md") @"
---
description: $(Format-Yaml $fm.Meta.description)$pathsBlock
---

<!-- $Marker | $origin Source: $(ConvertTo-Fwd $rule.FullName) -->

$($fm.Body.TrimStart("`n"))
"@
    }
}

# Remove stale generated wrappers (marker present, source gone or plugin no longer published).
$removed = 0
$candidates = @(
    Get-ChildItem -Path (Join-Path $Dirs.skills '*/SKILL.md') -ErrorAction SilentlyContinue
    Get-ChildItem -Path (Join-Path $Dirs.agents '*.md'), (Join-Path $Dirs.commands '*.md'), (Join-Path $Dirs.rules '*.md') -ErrorAction SilentlyContinue
)
foreach ($f in $candidates) {
    if ($Expected.Contains($f.FullName)) { continue }
    if ((Get-Content -LiteralPath $f.FullName -Raw) -notmatch [regex]::Escape($Marker)) { continue }
    if ($PSCmdlet.ShouldProcess($f.FullName, 'Remove stale wrapper')) {
        Remove-Item -LiteralPath $f.FullName
        if ($f.Name -eq 'SKILL.md' -and -not (Get-ChildItem -LiteralPath $f.DirectoryName -Force)) {
            Remove-Item -LiteralPath $f.DirectoryName
        }
        $removed++
    }
}
Write-Host "done  $($Expected.Count) wrappers expected, $Written written, $removed removed"

if ($Failures.Count) {
    Write-Host "== $($Failures.Count) problem(s):"
    $Failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
