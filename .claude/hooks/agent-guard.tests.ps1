# Table-driven check of agent-guard.ps1: feeds synthetic PreToolUse payloads and compares exit codes.
# Usage: pwsh -NoProfile -File .claude/hooks/agent-guard.tests.ps1
$guard = Join-Path $PSScriptRoot 'agent-guard.ps1'
$root = (Split-Path (Split-Path (Split-Path $PSScriptRoot))) -replace '\\', '/'
$worktree = "$root/M1"

# Role, tool, tool_input, expected exit code (0 allowed, 2 blocked).
$cases = @(
    @('test-writer', 'Read', @{ file_path = "$worktree/src/Version.cpp" }, 2),
    @('test-writer', 'Read', @{ file_path = "$worktree/include/rt/Version.hpp" }, 0),
    @('test-writer', 'Grep', @{ pattern = 'x'; path = "$worktree/tests" }, 0),
    @('test-writer', 'Grep', @{ pattern = 'x'; path = "$worktree/src" }, 2),
    @('test-writer', 'Write', @{ file_path = "$worktree/tests/unit/A.cpp" }, 0),
    @('test-writer', 'Write', @{ file_path = "$worktree/src/A.cpp" }, 2),
    @('test-writer', 'Edit', @{ file_path = "$worktree/include/rt/Version.hpp" }, 2),
    @('test-writer', 'Bash', @{ command = "cat $worktree/app/main.cpp" }, 2),
    @('test-writer', 'Bash', @{ command = "git -C $worktree diff main" }, 2),
    @('test-writer', 'Bash', @{ command = "git -C $worktree diff main -- tests/" }, 0),
    @('test-writer', 'Bash', @{ command = 'grep -rn Vec3 .' }, 2),
    @('test-writer', 'PowerShell', @{ command = './scripts/test.ps1' }, 0),
    @('test-writer', 'Read', @{ file_path = "$root/plan/specs/M1.md" }, 0),
    @('test-writer', 'Bash', @{ command = "git -C $worktree status --short" }, 0),
    @('test-writer', 'Bash', @{ command = 'git log --oneline -5' }, 0),
    @('test-writer', 'Bash', @{ command = 'git add tests/unit/math/Vec3Tests.cpp' }, 2),
    @('test-writer', 'Bash', @{ command = "git -C $worktree commit -m x" }, 2),
    @('test-writer', 'Bash', @{ command = "git -C $worktree push origin feature/M1" }, 2),
    @('developer', 'Edit', @{ file_path = "$worktree/tests/unit/A.cpp" }, 2),
    @('developer', 'Write', @{ file_path = "$worktree/include/rt/math/Vec3.hpp" }, 2),
    @('developer', 'Edit', @{ file_path = "$worktree/src/math/Vec3.cpp" }, 0),
    @('developer', 'Bash', @{ command = "git -C $worktree diff -- src/" }, 0),
    @('developer', 'Bash', @{ command = 'git add src/math/Vec3.cpp' }, 2),
    @('developer', 'PowerShell', @{ command = 'git stash push -m wip' }, 2),
    @('developer', 'Bash', @{ command = 'git reset --hard HEAD~1' }, 2),
    @('developer', 'Bash', @{ command = 'git checkout -- tests/' }, 2),
    @('reviewer', 'Bash', @{ command = "git -C $worktree diff main...HEAD" }, 0),
    @('reviewer', 'Bash', @{ command = "git -C $worktree diff main...HEAD 2>&1 | head -50" }, 0),
    @('reviewer', 'PowerShell', @{ command = './scripts/test.ps1' }, 0),
    @('reviewer', 'Bash', @{ command = 'gh issue view 12' }, 0),
    @('reviewer', 'Bash', @{ command = 'gh pr diff 3' }, 0),
    @('reviewer', 'Bash', @{ command = 'gh pr comment 3 --body x' }, 2),
    @('reviewer', 'Bash', @{ command = 'gh api repos/o/r/pulls/3/comments' }, 0),
    @('reviewer', 'Bash', @{ command = 'gh api repos/o/r/pulls/3/reviews -X POST' }, 2),
    @('developer', 'Bash', @{ command = 'gh issue close 12' }, 2),
    @('reviewer', 'Bash', @{ command = 'git diff > out.txt' }, 2),
    @('reviewer', 'Bash', @{ command = 'git commit -m x' }, 2),
    @('reviewer', 'Write', @{ file_path = "$worktree/review.md" }, 2)
)

$failures = 0
foreach ($case in $cases) {
    $role, $tool, $toolInput, $expected = $case
    $payload = @{ tool_name = $tool; tool_input = $toolInput; cwd = $root } | ConvertTo-Json -Compress
    $stderr = $payload | pwsh -NoProfile -File $guard -Role $role 2>&1
    if ($LASTEXITCODE -ne $expected) {
        $failures++
        Write-Host "FAIL [$role] $tool $($toolInput | ConvertTo-Json -Compress): got $LASTEXITCODE, want $expected $stderr"
    }
}
Write-Host "$($cases.Count - $failures)/$($cases.Count) passed"
exit [int]($failures -gt 0)
