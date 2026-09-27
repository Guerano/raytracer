---
name: milestone
description: Runs one raytracer milestone end to end from its approved spec (contract, test-writer, developer, reviewer, PR). Invoke as /milestone M<n>.
argument-hint: M<n>
disable-model-invocation: true
---

# /milestone $ARGUMENTS

You are the orchestrator. The workspace root is `Raytracer/`; `plan/PLAN.md` holds the milestone
table and the workflow rationale. Only one milestone is active at a time. Agents never touch git or
GitHub in write mode: you review each diff, commit, push and publish.

Commits of an agent's work carry the agent as author, so `git log`/`blame` show who wrote what:
`git commit --author "<agent> (<Model>) <<agent>@agents.raytracer>"`, e.g.
`--author "test-writer (Haiku) <test-writer@agents.raytracer>"`. Your own commits (headers)
keep the default author.

## 0. Preconditions

- The spec `plan/specs/$ARGUMENTS.md` exists and is pushed. It is written in a **separate, earlier
  session** (grilling with the user). If it is missing, stop: do not write it here.
- `git -C main pull`; `git -C main worktree list` shows no other `M*` worktree (else stop and ask).
- Read the spec and `main/CLAUDE.md`.
- `git -C main worktree add -b feature/$ARGUMENTS ../$ARGUMENTS`.

## 1. Contract (with the user)

- Derive the `include/rt/` headers from the spec: declarations and doc comments precise enough for
  the test-writer to choose test cases from them alone (behaviour, preconditions, exceptions, edge
  cases). Iterate with the user until they approve.
- Create the parent issue `$ARGUMENTS: <title>` (summary, acceptance criteria, link to the spec,
  header list) and one sub-issue per delegated task (tests, implementation). Add them to the
  project board; parent to *In progress*.
- Commit the headers: `feat(<scope>): define <what> interface (#<parent>)`.

## 2. Tests — `test-writer` agent

Delegate with: worktree absolute path, spec path, headers to cover. Then review its diff
(`git -C $ARGUMENTS diff`): only `tests/`, suite compiles (link errors or red tests expected), and
its coverage map leaves no documented behaviour untested without a reason.
Commit: `test(<scope>): <what> (#<sub-issue>)`.

## 3. Implementation — `developer` agent

Delegate with: worktree absolute path, spec path, scope. Review its diff: only `src/` and `app/`.
Run `./scripts/test.ps1` and `./scripts/lint.ps1` yourself: numbers, not trust. Commit:
`feat(<scope>): <what> (#<sub-issue>)`.
For each escalation: decide whether the test, the header or the implementation is wrong; a test
fix goes to test-writer (resume it with SendMessage), a header change goes to the user first.

## 4. Draft PR and review

- Push `feature/$ARGUMENTS`; open a **draft** PR closing the parent issue and sub-issues. Body:
  **Changes** / **Not touched** (noticed-but-not-touching items, out-of-scope) / **Points of
  attention** (design choices, escalations, trade-offs).
- Run the `reviewer` agent with **only** worktree path, spec path, parent issue and PR number:
  never the agents' reports or your own summary (it would bias the review toward agreement).
- Triage each finding: **valid** (goes to the fix loop), **trade-off** (kept, justified in the
  comment, listed for the user), **contract misread** or **noise** (not fixed, reason stated).
- Post the result as **one** PR review: summary as the body, each finding as an inline comment
  (`gh api repos/{owner}/{repo}/pulls/<pr>/reviews` with `event=COMMENT` and a `comments` array
  of `{path, line, side: "RIGHT", body: "**<severity>** (<owner>) [<triage>] <body>"}`).

## 5. Fix loop

Every **valid** finding is fixed, by its owner, resumed **with its context** (SendMessage to its
agent id):
- **Defect in the implementation** — Prove-It: first the test-writer gets the defect *scenario*
  (behaviour, not code) and writes a test that fails; commit it. Then the developer makes it pass.
- **Test or other finding** — straight to its owner.

Review each diff, commit (`fix(<scope>): ...`), push, re-run the reviewer on the new commits. At
most **2 rounds** per agent, then stop and escalate to the user. Wait for green CI.

## 6. Hand-off

Mark the PR ready, move the parent issue to *In review*, and tell the user: PR link, CI status,
review rounds, trade-offs and what deserves their attention. **Never merge**: the user reviews and
merges.

## 7. After the user merged

`git -C main pull`, `git -C main worktree remove ../$ARGUMENTS`,
`git -C main branch -d feature/$ARGUMENTS`, issues to *Done*. Record decisions worth keeping in
`plan/PLAN.md` or the spec (`docs(plan): ...`, pushed directly).

## End of every session

Whatever step the session stops at, overwrite `plan/HANDOFF.md` and push it: current milestone and
step, decisions taken, next action, verification commands, open risks and questions. A fresh
session must be able to resume from it alone.

## Budget rules

At most 3 subagents in flight. Give agents minimal prompts: paths, issue numbers, scope. Never
paste file contents they can read themselves.
