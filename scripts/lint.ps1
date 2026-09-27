# Checks formatting and runs clang-tidy on every tracked C++ file.
# Usage: ./scripts/lint.ps1 [-Fix] [-Preset windows-msvc-debug]
#   -Fix  rewrite files with clang-format instead of only reporting differences.
param([switch]$Fix, [string]$Preset = 'windows-msvc-debug')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/dev-shell.ps1"

Push-Location (Split-Path $PSScriptRoot)
try {
    $files = git ls-files --cached --others --exclude-standard '*.hpp' '*.cpp'
    $failed = $false

    if ($Fix) {
        clang-format -i $files
    } else {
        clang-format --dry-run --Werror $files
        if ($LASTEXITCODE) { $failed = $true }
    }

    if (-not (Test-Path "build/$Preset/compile_commands.json")) {
        cmake --preset $Preset | Out-Null
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }
    $sources = $files | Where-Object { $_ -like '*.cpp' }
    clang-tidy -p "build/$Preset" --quiet $sources
    if ($LASTEXITCODE) { $failed = $true }

    if ($failed) { exit 1 }
} finally { Pop-Location }
