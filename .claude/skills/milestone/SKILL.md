---
name: milestone
description: Runs one raytracer milestone end to end (worktree, contract, test-writer, developer, reviewer, draft PR). Invoke as /milestone M<n>.
argument-hint: M<n>
disable-model-invocation: true
---

# /milestone $ARGUMENTS

You are the orchestrator. The workspace root is `Raytracer/`; `plan/PLAN.md` holds the milestone
table and the workflow rationale. Only one milestone is active at a time.

## 0. Preconditions

- `git -C main pull`, `git -C main worktree list`: no other `M*` worktree may exist. If one does,
  stop and ask.
- Read the milestone row in `plan/PLAN.md` and `main/CLAUDE.md`.
- Create the worktree: `git -C main worktree add -b feature/$ARGUMENTS ../$ARGUMENTS`.

## 1. Contract (with the user)

- Draft the `include/rt/` headers for the milestone: declarations and doc comments only, the
  behaviour each test must pin down. Iterate with the user until they approve.
- Create the parent issue `$ARGUMENTS: <title>` (spec, acceptance criteria, interface contract =
  header list) and one sub-issue per delegated task (tests, implementation). Add them to the
  project board; parent to *In progress*.
- Commit the headers in the worktree: `feat(<scope>): define <what> interface (#<parent>)`.

## 2. Tests — `test-writer` agent

Delegate with: worktree absolute path, sub-issue number, headers to cover, behaviours from the
spec, co-author line. Check its report: files only under `tests/`, suite compiles (link errors or
red tests expected), commit present.

## 3. Implementation — `developer` agent

Delegate with: worktree absolute path, sub-issue number, scope, co-author line. Check its report.
If it escalates a test, send the issue to test-writer (resume it with SendMessage), then back.

## 4. Verification and draft PR

- Run `./scripts/test.ps1` and `./scripts/lint.ps1` yourself in the worktree. Numbers, not trust.
- Push `feature/$ARGUMENTS`, open a **draft** PR closing the parent issue and sub-issues.
- Run the `reviewer` agent (worktree path, parent issue); post its report as a PR comment.

## 5. Fix loop

For each blocker/major finding, resume the owning agent **with its context** (SendMessage to its
agent id). At most **2 rounds** per agent; after that, stop and escalate to the user. Re-run tests,
lint, push; wait for green CI.

## 6. Hand-off

Mark the PR ready, move the parent issue to *In review*, and tell the user: PR link, CI status,
review verdict, what deserves their attention. **Never merge**: the user reviews and merges.

## 7. After the user merged

`git -C main pull`, `git -C main worktree remove ../$ARGUMENTS`,
`git -C main branch -d feature/$ARGUMENTS`, issues to *Done*. Note decisions worth keeping in
`plan/PLAN.md` (`docs(plan): ...`, pushed directly).

## Budget rules

At most 3 subagents in flight. Give agents minimal prompts: paths, issue numbers, scope. Never
paste file contents they can read themselves.
