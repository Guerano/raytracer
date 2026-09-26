# Dot-source this script to load the MSVC x64 environment (cl, cmake, ninja, clang-format/tidy).
# No-op when the environment is already loaded.

if (Get-Command cl.exe -ErrorAction SilentlyContinue) { return }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw 'Visual Studio with the C++ toolset was not found.' }

$env:PATH = "$(Split-Path $vswhere);$env:PATH"  # VsDevCmd calls vswhere itself
Import-Module (Join-Path $vsPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null

$llvmBin = Join-Path $vsPath 'VC\Tools\Llvm\x64\bin'
if ((Test-Path $llvmBin) -and -not (Get-Command clang-format.exe -ErrorAction SilentlyContinue)) {
    $env:PATH = "$llvmBin;$env:PATH"
}
