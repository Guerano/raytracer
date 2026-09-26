#!/usr/bin/env bash
# CI lint: clang-format check and clang-tidy on every tracked C++ file.
# Usage: scripts/lint.sh <build-dir-with-compile_commands>
set -euo pipefail

cd "$(dirname "$0")/.."
buildDir="${1:?usage: lint.sh <build-dir>}"
clangFormat="${CLANG_FORMAT:-clang-format}"
clangTidy="${CLANG_TIDY:-clang-tidy}"

mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.hpp' '*.cpp')
mapfile -t sources < <(git ls-files --cached --others --exclude-standard '*.cpp')

status=0
"$clangFormat" --dry-run --Werror "${files[@]}" || status=1
"$clangTidy" -p "$buildDir" --quiet "${sources[@]}" || status=1
exit "$status"
