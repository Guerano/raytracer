# Handoff

Resume point for the next session. Overwritten at the end of every session.

## State — 2026-09-27

- **M0 (Bootstrap)**: done, PR [#2](https://github.com/Guerano/raytracer/pull/2) awaiting the
  user's review and merge. Issue #1 criteria all ticked. Board: #1 *In progress*.
- GitHub: public repo `Guerano/raytracer`, default branch `main`, merge commits only; `main`
  protected (4 required checks: Windows MSVC, Linux gcc, Linux clang, Lint; strict; admins
  included; conversation resolution required). Project board "raytracer" (Todo / In progress /
  In review / Done), linked to the repo.
- Workspace junctions and `.claude/settings.json` currently point to / come from **`M0/`**, not
  `main/` (agents are not merged yet).

## Decisions this session

See `PLAN.md` (Agents, Milestone workflow). Highlights: spec session before each milestone
(`/grilling` → `plan/specs/Mx.md`); agents read-only on git/GitHub, orchestrator commits with the
agent as `--author`; reviewer isolated, findings triaged, Prove-It fix loop; guard hook registered at
settings level because frontmatter hooks do not fire (anthropics/claude-code#95650).

## Next actions

1. User: review PR #2, mark ready (or ask the orchestrator), merge.
2. After merge: `git -C main pull`; `main/scripts/setup-workspace.ps1` (defaults to `main`);
   `git -C main worktree remove ../M0`; `git -C main branch -d feature/M0`; issue #1 → *Done*.
3. Cleanup (user, deletions): worktree `dryrun/` + branch `dryrun/M0` (throwaway, never pushed);
   folder `plan.old/`.
4. New session: spec session for **M1** (math core: Vec3, Ray, PNG output, gradient image).

## Verification commands

```powershell
./scripts/test.ps1; ./scripts/lint.ps1                      # in a worktree
pwsh -NoProfile -File .claude/hooks/agent-guard.tests.ps1   # 43/43 expected
```

## Open risks

- Guard hook is heuristic on shell commands; git-write rules were verified by table tests, not
  live (the developer refused the trap by prompt before reaching the hook).
- Haiku followed a contradicting instruction before the prompts were hardened; the hardened
  prompt is not re-tested with Haiku yet.
- Workspace `.claude/settings.json` is a copy: re-run `setup-workspace.ps1` after changing the
  repo's `.claude/settings.json`.
