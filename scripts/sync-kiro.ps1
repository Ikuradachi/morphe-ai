[CmdletBinding()]
param(
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptRoot
$kiroRoot = Join-Path $repoRoot '.kiro'
$skillsRoot = Join-Path $repoRoot '.agents\skills'
$projectReferences = Join-Path $skillsRoot 'morphe-project\references'
$agentsPath = Join-Path $repoRoot 'AGENTS.md'
$script:changed = 0
$script:drift = 0
$script:review = 0

function Get-RelativeUnixPath {
    param(
        [Parameter(Mandatory)] [string] $Base,
        [Parameter(Mandatory)] [string] $Path
    )

    return [IO.Path]::GetRelativePath($Base, $Path).Replace('\', '/')
}

function Get-FileSha256 {
    param([Parameter(Mandatory)] [string] $Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Sync-FileExact {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Destination
    )

    $different = -not (Test-Path -LiteralPath $Destination -PathType Leaf)
    if (-not $different) {
        $different = (Get-FileSha256 $Source) -ne (Get-FileSha256 $Destination)
    }

    if (-not $different) {
        return
    }

    $display = Get-RelativeUnixPath $repoRoot $Destination
    $script:drift++
    if ($Check) {
        Write-Host "DRIFT  $display"
        return
    }

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    $script:changed++
    Write-Host "SYNCED $display"
}

function Write-TextIfChanged {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Content
    )

    $existing = if (Test-Path -LiteralPath $Path) {
        [IO.File]::ReadAllText($Path)
    } else {
        $null
    }

    if ($existing -eq $Content) {
        return
    }

    $display = Get-RelativeUnixPath $repoRoot $Path
    $script:drift++
    if ($Check) {
        Write-Host "DRIFT  $display"
        return
    }

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    $script:changed++
    Write-Host "SYNCED $display"
}

function Replace-MarkedBlock {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Body
    )

    $start = "<!-- sync-kiro:${Name}:start -->"
    $end = "<!-- sync-kiro:${Name}:end -->"
    $pattern = [regex]::Escape($start) + '.*?' + [regex]::Escape($end)
    if (-not [regex]::IsMatch($Text, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw "Missing AGENTS.md sync markers for '$Name'."
    }

    $replacement = $start + "`n" + $Body.TrimEnd() + "`n" + $end
    return [regex]::Replace(
        $Text,
        $pattern,
        [Text.RegularExpressions.MatchEvaluator] { param($match) $replacement },
        [Text.RegularExpressions.RegexOptions]::Singleline
    )
}

function Get-LegacyDescription {
    param([Parameter(Mandatory)] [string] $SkillPath)

    $text = [IO.File]::ReadAllText($SkillPath)
    $match = [regex]::Match($text, '(?ms)\A---\s*.*?^description:\s*(?<description>[^\r\n]+)')
    if (-not $match.Success) {
        return 'Use preserved Kiro guidance for this migrated Morphe skill.'
    }

    $description = $match.Groups['description'].Value.Trim()
    if ($description -in @('>', '|')) {
        return 'Use preserved Kiro guidance for this migrated Morphe skill.'
    }
    return $description
}

function New-CanonicalSkillText {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $LegacySkillPath
    )

    $legacyDescription = Get-LegacyDescription $LegacySkillPath
    $description = "$legacyDescription Use when a Morphe task matches this domain or tool."
    $yamlDescription = $description | ConvertTo-Json -Compress

    return @"
---
name: $Name
description: $yamlDescription
---

# $Name

## Purpose

Apply preserved Kiro knowledge for $Name through a runtime-independent skill.

## Triggers

$legacyDescription

## Inputs

User request, relevant Morphe workspace state, and domain-specific files or parameters.

## Outputs

Requested analysis, command, artifact, or evidence-backed result.

## Instructions

Read [Kiro reference](references/kiro-skill.md) completely before acting. Treat its YAML frontmatter as archived metadata. Follow its Markdown body and linked support files. Map Kiro-specific tool labels to equivalent runtime capabilities. Preserve Smali verification, fingerprint stability, repository safety, exact code templates, and failure handling.
"@
}

function Protect-McpArguments {
    param([object[]] $Arguments)

    $result = [Collections.Generic.List[object]]::new()
    $redactNext = $false
    foreach ($argumentValue in $Arguments) {
        $argument = [string] $argumentValue
        if ($redactNext) {
            $result.Add('<redacted: configure globally>')
            $redactNext = $false
            continue
        }
        if ($argument -match '(?i)^--?(token|secret|password|pass|api[-_]?key|credential)s?$') {
            $result.Add($argument)
            $redactNext = $true
            continue
        }
        $argument = $argument -replace '(?i)((token|secret|password|pass|api[-_]?key|credential)s?=)[^&\s]+', '$1<redacted>'
        $argument = $argument -replace '(?i)(https?://[^/:@\s]+:)[^@/\s]+@', '$1<redacted>@'
        $result.Add($argument)
    }
    return $result.ToArray()
}

function Get-McpMarkdown {
    $mcpPath = Join-Path $kiroRoot 'settings\mcp.json'
    if (-not (Test-Path -LiteralPath $mcpPath -PathType Leaf)) {
        return @'
`.kiro/settings/mcp.json` is absent. No MCP server commands, arguments, or environment variables are discoverable. Copyable empty configuration:

```json
{
  "mcpServers": {}
}
```
'@
    }

    $source = Get-Content -Raw -LiteralPath $mcpPath | ConvertFrom-Json -AsHashtable
    $sourceServers = if ($source.ContainsKey('mcpServers')) { $source['mcpServers'] } else { @{} }
    $safeServers = [ordered]@{}
    foreach ($serverName in ($sourceServers.Keys | Sort-Object)) {
        $server = $sourceServers[$serverName]
        $safeServer = [ordered]@{}
        if ($server.ContainsKey('command')) {
            $safeServer['command'] = [string] $server['command']
        }
        if ($server.ContainsKey('args')) {
            $safeServer['args'] = @(Protect-McpArguments @($server['args']))
        }
        if ($server.ContainsKey('env')) {
            $safeEnvironment = [ordered]@{}
            foreach ($variableName in ($server['env'].Keys | Sort-Object)) {
                $safeEnvironment[$variableName] = '${' + $variableName + '}'
            }
            $safeServer['env'] = $safeEnvironment
        }
        $safeServers[$serverName] = $safeServer
    }

    $safeConfig = [ordered]@{ mcpServers = $safeServers }
    $json = $safeConfig | ConvertTo-Json -Depth 20
    $fence = '```'
    return ".kiro/settings/mcp.json exists. Values below preserve commands and safe arguments; environment values are variable placeholders, never copied secrets.`n`n${fence}json`n$json`n$fence"
}

if (-not (Test-Path -LiteralPath $kiroRoot -PathType Container)) {
    throw "Missing legacy source: $kiroRoot"
}
if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
    throw "Missing universal entrypoint: $agentsPath"
}

$sourceMarkdown = @(
    Get-ChildItem (Join-Path $kiroRoot 'steering'), (Join-Path $kiroRoot 'prompts') -Recurse -File -Filter '*.md' |
        Sort-Object FullName
)
$expectedReferencePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($sourceFile in $sourceMarkdown) {
    $relative = Get-RelativeUnixPath $kiroRoot $sourceFile.FullName
    $destination = Join-Path $projectReferences ($relative.Replace('/', '\'))
    [void] $expectedReferencePaths.Add([IO.Path]::GetFullPath($destination))
    Sync-FileExact $sourceFile.FullName $destination
}

foreach ($referenceGroup in @('steering', 'prompts')) {
    $referencePath = Join-Path $projectReferences $referenceGroup
    if (-not (Test-Path -LiteralPath $referencePath -PathType Container)) {
        continue
    }
    foreach ($existingReference in Get-ChildItem $referencePath -Recurse -File -Filter '*.md') {
        if (-not $expectedReferencePaths.Contains([IO.Path]::GetFullPath($existingReference.FullName))) {
            Write-Warning "STALE  $(Get-RelativeUnixPath $repoRoot $existingReference.FullName)"
            $script:review++
        }
    }
}

$kiroSkillsPath = Join-Path $kiroRoot 'skills'
foreach ($legacySkillDirectory in Get-ChildItem $kiroSkillsPath -Directory | Sort-Object Name) {
    $name = $legacySkillDirectory.Name
    $legacySkill = Join-Path $legacySkillDirectory.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $legacySkill -PathType Leaf)) {
        Write-Warning "Legacy skill lacks SKILL.md: $name"
        $script:review++
        continue
    }

    $canonicalDirectory = Join-Path $skillsRoot $name
    Sync-FileExact $legacySkill (Join-Path $canonicalDirectory 'references\kiro-skill.md')

    foreach ($supportFile in Get-ChildItem $legacySkillDirectory.FullName -Recurse -File | Where-Object Name -ne 'SKILL.md') {
        $supportRelative = [IO.Path]::GetRelativePath($legacySkillDirectory.FullName, $supportFile.FullName)
        Sync-FileExact $supportFile.FullName (Join-Path $canonicalDirectory "references\$supportRelative")
    }

    $canonicalSkill = Join-Path $canonicalDirectory 'SKILL.md'
    if (-not (Test-Path -LiteralPath $canonicalSkill -PathType Leaf)) {
        Write-TextIfChanged $canonicalSkill (New-CanonicalSkillText $name $legacySkill)
    }
}

$legacyJadxScript = Join-Path $kiroRoot 'jadx-decompile'
if (Test-Path -LiteralPath $legacyJadxScript -PathType Leaf) {
    Sync-FileExact $legacyJadxScript (Join-Path $skillsRoot 'jadx\scripts\jadx-decompile')
}

$sourceIndex = $sourceMarkdown | ForEach-Object {
    $relative = Get-RelativeUnixPath $kiroRoot $_.FullName
    "- .agents/skills/morphe-project/references/$relative"
}
$skillIndex = Get-ChildItem $skillsRoot -Directory | Sort-Object Name | ForEach-Object {
    "- ``$($_.Name)``"
}

$agents = [IO.File]::ReadAllText($agentsPath)
$agents = Replace-MarkedBlock $agents 'source-index' ($sourceIndex -join "`n")
$agents = Replace-MarkedBlock $agents 'skill-index' ($skillIndex -join "`n")
$agents = Replace-MarkedBlock $agents 'mcp' (Get-McpMarkdown)
Write-TextIfChanged $agentsPath $agents

$hashFailures = 0
if (-not $Check) {
    foreach ($sourceFile in $sourceMarkdown) {
        $relative = Get-RelativeUnixPath $kiroRoot $sourceFile.FullName
        $destination = Join-Path $projectReferences ($relative.Replace('/', '\'))
        if ((Get-FileSha256 $sourceFile.FullName) -ne (Get-FileSha256 $destination)) {
            Write-Error "Hash mismatch: $relative"
            $hashFailures++
        }
    }
}

Write-Host ""
Write-Host "Kiro Markdown: $($sourceMarkdown.Count)"
Write-Host "Kiro skills: $((Get-ChildItem $kiroSkillsPath -Directory).Count)"
Write-Host "Changed: $script:changed"
Write-Host "Drift: $script:drift"
Write-Host "Manual review: $script:review"

if ($hashFailures -gt 0) {
    exit 2
}
if ($Check -and ($script:drift -gt 0 -or $script:review -gt 0)) {
    exit 1
}
if ($script:review -gt 0) {
    Write-Warning 'Sync completed without deletion. Review stale or malformed legacy items manually.'
}
