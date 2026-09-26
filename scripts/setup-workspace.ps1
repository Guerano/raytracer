# Recreates the non-versioned workspace around the repository:
#   Raytracer/CLAUDE.md            "@main/CLAUDE.md"
#   Raytracer/.claude/agents       junction -> <Source>/.claude/agents
#   Raytracer/.claude/skills       junction -> <Source>/.claude/skills
#   Raytracer/.cache/fetchcontent  shared FetchContent sources
# Usage: main/scripts/setup-workspace.ps1 [-Source main]
#   -Source  checkout the junctions point to (e.g. M0 while agents are not merged yet).
param([string]$Source = 'main')
$ErrorActionPreference = 'Stop'

$root = Split-Path (Split-Path $PSScriptRoot)
$sourceDir = Join-Path $root $Source
if (-not (Test-Path (Join-Path $sourceDir '.git'))) { throw "No checkout at $sourceDir" }

Set-Content -NoNewline -Path (Join-Path $root 'CLAUDE.md') -Value "@main/CLAUDE.md`n"
New-Item -ItemType Directory -Force (Join-Path $root '.claude'), (Join-Path $root '.cache/fetchcontent') | Out-Null

foreach ($name in 'agents', 'skills') {
    $link = Join-Path $root ".claude/$name"
    $target = Join-Path $sourceDir ".claude/$name"
    New-Item -ItemType Directory -Force $target | Out-Null
    $existing = Get-Item $link -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -ne 'Junction') { throw "$link exists and is not a junction" }
        # Removing a junction deletes the link only, never the target's content.
        $existing.Delete()
    }
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Host "$link -> $target"
}

$localSettings = Join-Path $root '.claude/settings.local.json'
if (-not (Test-Path $localSettings)) { Set-Content -Path $localSettings -Value "{}`n" }
