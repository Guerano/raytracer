# Configures and builds a preset. Usage: ./scripts/build.ps1 [-Preset windows-msvc-debug]
param([string]$Preset = 'windows-msvc-debug')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/dev-shell.ps1"

Push-Location (Split-Path $PSScriptRoot)
try {
    cmake --preset $Preset
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    cmake --build --preset $Preset
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
} finally { Pop-Location }
