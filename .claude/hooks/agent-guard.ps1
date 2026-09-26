# PreToolUse guard shared by the project subagents. Reads the hook payload on stdin and exits 2
# (blocking the call, reason on stderr) when the tool call breaks the role's path ownership.
# Heuristic defense in depth: the agent prompts state the same rules.
# Usage (agent frontmatter): pwsh -NoProfile -File <this> -Role test-writer|developer|reviewer
param([Parameter(Mandatory)][ValidateSet('test-writer', 'developer', 'reviewer')][string]$Role)

$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
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

# Rules shared by every role: the orchestrator alone pushes, and commits stage explicit paths.
if ($tool -in 'Bash', 'PowerShell') {
    if ($command -match "${git}push\b") { Deny 'only the orchestrator pushes.' }
    if ($command -match "${git}add\s+(.*\s)?(-A|--all|\.)(\s|$)") {
        Deny 'stage explicit paths you own, never -A or .'
    }
    if ($command -match "${git}commit\s+(.*\s)?(-a|--all|-am)(\s|$)") {
        Deny 'stage explicit paths with git add, never commit -a.'
    }
    if ($command -match "${git}(reset\s+--hard|clean|stash|checkout\s+--|restore)\b") {
        Deny 'destructive git commands are reserved to the orchestrator.'
    }
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
        if (($tool -in 'Bash', 'PowerShell') -and $command -match "${git}add\b.*(tests|include)") {
            Deny 'commit only src/ and app/.'
        }
    }
    'reviewer' {
        if ($tool -in 'Edit', 'Write') { Deny 'the reviewer is read-only.' }
        if ($tool -in 'Bash', 'PowerShell') {
            if ($command -match "${git}(add|commit|checkout|switch|merge|rebase|cherry-pick|rm|mv|tag|branch\s+-[dDmM])\b") {
                Deny 'the reviewer is read-only.'
            }
            if ($command -match '(?i)\b(Remove-Item|Set-Content|Add-Content|Out-File|New-Item|Move-Item|Copy-Item|rm|mv|cp)\b' -or
                $command -match '(?<![0-9&])>(?!\s*(&|/dev/null|\$null))') {
                Deny 'the reviewer is read-only.'
            }
        }
    }
}

exit 0
