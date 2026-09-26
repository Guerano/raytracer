# Builds a preset then runs its tests. Usage: ./scripts/test.ps1 [-Preset windows-msvc-debug]
param([string]$Preset = 'windows-msvc-debug')
$ErrorActionPreference = 'Stop'

& "$PSScriptRoot/build.ps1" -Preset $Preset
if ($LASTEXITCODE) { exit $LASTEXITCODE }

Push-Location (Split-Path $PSScriptRoot)
try {
    ctest --preset $Preset
    exit $LASTEXITCODE
} finally { Pop-Location }
