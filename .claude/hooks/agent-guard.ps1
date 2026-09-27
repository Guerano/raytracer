# PreToolUse guard for the project subagents. Reads the hook payload on stdin and exits 2
# (blocking the call, reason on stderr) when the tool call breaks the calling agent's rules.
# Heuristic defense in depth: the agent prompts state the same rules.
#
# Registered once in the workspace settings (.claude/settings.json), not in agent frontmatter:
# frontmatter hooks never fire on Windows (anthropics/claude-code#95650). The role comes from the
# payload's agent_type; calls from the main session or other agents are always allowed.
# -Role overrides agent_type (used by agent-guard.tests.ps1).
param([string]$Role)

$roles = 'test-writer', 'developer', 'reviewer'
$raw = [Console]::In.ReadToEnd()
if (-not $Role -and $raw -match '"agent_type"\s*:\s*"([^"]+)"') { $Role = $Matches[1] }
if ($Role -notin $roles) { exit 0 }

# Fail closed for our agents: any unexpected error (unreadable payload, bug) blocks the call.
$ErrorActionPreference = 'Stop'
trap {
    [Console]::Error.WriteLine("Blocked by agent-guard ($Role): guard failed, call denied: $_")
    exit 2
}

$payload = $raw | ConvertFrom-Json
$tool = $payload.tool_name
$toolInput = $payload.tool_input

function Deny([string]$reason) {
    [Console]::Error.WriteLine("Blocked by agent-guard ($Role): $reason")
    exit 2
}

function Normalize([string]$path) {
    if (-not $path) { $path = $payload.cwd }
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $payload.cwd $path }
    return ($path -replace '\\', '/').TrimEnd('/')
}

function Test-Segment([string]$path, [string]$segments) {
    return $path -match "(?i)(^|/)($segments)(/|$)"
}

$implementation = 'src|app'
$command = [string]$toolInput.command
# Prefix matching 'git <subcommand>' with global options in between, e.g. 'git -C M1 diff'.
$git = '(?i)\bgit\b[^|;&\n]*?\s'

# Shared by every role: git is read-only for agents; the orchestrator reviews, commits and pushes.
$gitWrite = 'add|commit|push|reset|clean|stash|checkout|switch|restore|merge|rebase|cherry-pick|' +
    'revert|rm|mv|tag|am|apply|worktree|branch\s+-[dDmMcC]'
if (($tool -in 'Bash', 'PowerShell') -and $command -match "${git}($gitWrite)\b") {
    Deny 'git is read-only for agents; the orchestrator commits.'
}
# Likewise GitHub: agents read issues and PRs, the orchestrator publishes.
if (($tool -in 'Bash', 'PowerShell') -and
    ($command -match '(?i)\bgh\s+(pr|issue|project|release|repo|label)\s+(?!view\b|list\b|diff\b|checks\b|status\b)\w' -or
     $command -match '(?i)\bgh\s+api\b.*(-X|--method)\s*(POST|PUT|PATCH|DELETE)|\bgh\s+api\b.*\s(-f|-F|--field|--raw-field|--input)\b')) {
    Deny 'GitHub is read-only for agents; the orchestrator publishes.'
}

switch ($Role) {
    'test-writer' {
        switch -Regex ($tool) {
            '^(Read|Glob)$' {
                $path = Normalize ($toolInput.file_path ?? $toolInput.path)
                if (Test-Segment $path $implementation) { Deny 'tests are written from headers only; src/ and app/ are off limits.' }
            }
            '^Grep$' {
                $path = Normalize $toolInput.path
                if ((Test-Segment $path $implementation) -or (Test-Path "$path/src") -or (Test-Path "$path/app")) {
                    Deny 'scope Grep to include/ or tests/ (src/ and app/ are off limits).'
                }
            }
            '^(Edit|Write)$' {
                $path = Normalize $toolInput.file_path
                if (-not (Test-Segment $path 'tests')) { Deny 'you only write under tests/.' }
            }
            '^(Bash|PowerShell)$' {
                if ($command -match '(?i)(^|[\s"''=/\\])(src|app)([/\\"''\s]|$)') {
                    Deny 'commands must not touch src/ or app/.'
                }
                if ($command -match "${git}(diff|show|blame|grep|cat-file|log\s+.*(-p|--patch))\b" -and
                    $command -notmatch '\s--\s+\S*(tests|include)') {
                    Deny 'git content commands must be restricted with "-- tests/" or "-- include/".'
                }
                if ($command -match '(?i)\b(rg|findstr)\b|\bgrep\s+(.*\s)?-\w*[rR]|-Recurse') {
                    Deny 'no recursive search from the shell; use Grep scoped to include/ or tests/.'
                }
            }
        }
    }
    'developer' {
        if ($tool -in 'Edit', 'Write') {
            $path = Normalize $toolInput.file_path
            if (Test-Segment $path 'tests|include') {
                Deny 'tests/ and include/ are not yours; escalate to the orchestrator instead.'
            }
        }
    }
    'reviewer' {
        if ($tool -in 'Edit', 'Write') { Deny 'the reviewer is read-only.' }
        if ($tool -in 'Bash', 'PowerShell') {
            if ($command -match '(?i)\b(Remove-Item|Set-Content|Add-Content|Out-File|New-Item|Move-Item|Copy-Item|rm|mv|cp)\b' -or
                $command -match '(?<![0-9&])>(?!\s*(&|/dev/null|\$null))') {
                Deny 'the reviewer is read-only.'
            }
        }
    }
}

exit 0
