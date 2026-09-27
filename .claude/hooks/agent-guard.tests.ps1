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

# Callers the guard must leave alone: the main session (no agent_type) and other agents.
$cases += , @('', 'Read', @{ file_path = "$worktree/src/Version.cpp" }, 0)
$cases += , @('', 'Bash', @{ command = 'git push origin feature/M1' }, 0)
$cases += , @('Explore', 'Read', @{ file_path = "$worktree/src/Version.cpp" }, 0)

$failures = 0
foreach ($case in $cases) {
    $role, $tool, $toolInput, $expected = $case
    # The role travels in agent_type, as in real subagent payloads.
    $fields = @{ tool_name = $tool; tool_input = $toolInput; cwd = $root }
    if ($role) { $fields.agent_type = $role; $fields.agent_id = 'test' }
    $stderr = $fields | ConvertTo-Json -Compress | pwsh -NoProfile -File $guard 2>&1
    if ($LASTEXITCODE -ne $expected) {
        $failures++
        Write-Host "FAIL [$role] $tool $($toolInput | ConvertTo-Json -Compress): got $LASTEXITCODE, want $expected $stderr"
    }
}

# Unreadable payloads: fail closed for our agents, stay open for the main session.
$rawCases = @(
    @('{"agent_type":"test-writer","tool_name":"Read","tool_input":{"file_path":"C:\Users\x"}}', 2),
    @('{"tool_name":"Read","tool_input":{"file_path":"C:\Users\x"}}', 0)
)
foreach ($rawCase in $rawCases) {
    $raw, $expected = $rawCase
    $raw | pwsh -NoProfile -File $guard 2>&1 | Out-Null
    if ($LASTEXITCODE -ne $expected) {
        $failures++
        Write-Host "FAIL raw payload ${raw}: got $LASTEXITCODE, want $expected"
    }
}
$total = $cases.Count + $rawCases.Count

Write-Host "$($total - $failures)/$total passed"
exit [int]($failures -gt 0)
