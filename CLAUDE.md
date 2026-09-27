# Raytracer

C++20 raytracer, built as a training ground for agentic development. The plan (milestones, workflow,
decisions) lives on the orphan branch `plan`, checked out in the `plan/` worktree next to this one.

## Workspace

The Claude session runs in the parent directory `Raytracer/`, not in this repository:

- `main/` — always on `main`, never edited directly.
- `Mx/` — worktree on `feature/Mx`, the single active milestone. All work happens there.
- `plan/` — orphan branch `plan`; commit and push directly (`docs(plan): ...`).
  `plan/specs/Mx.md` is the milestone spec, written in a grilling session before `/milestone Mx`.
  `plan/HANDOFF.md` is the resume point: read it first, overwrite and push it at the end of every
  session.
- `.cache/fetchcontent/` — shared FetchContent cache.

`scripts/setup-workspace.ps1` recreates the top-level files and junctions.

## Build and test

Run from a milestone worktree. Presets need the MSVC environment (the scripts load it).

```powershell
./scripts/build.ps1            # configure + build (preset: windows-msvc-debug)
./scripts/test.ps1             # ctest --preset
./scripts/lint.ps1             # clang-format --dry-run + clang-tidy
```

## Code style

- Types, concepts, enums, enum values: `PascalCase`.
- Functions, methods, variables, parameters: `camelCase`.
- Members `m_camelCase`, static members `s_camelCase`, constants `kPascalCase`.
- Namespaces lowercase (`rt::geometry`), macros `RT_UPPER_CASE`.
- Files `PascalCase.hpp` / `PascalCase.cpp`, directories lowercase.
- `#pragma once`, west const (`const T&`), `double` everywhere, errors as exceptions.
- Include order: project, third-party, std, separated by a blank line.
- clang-format and clang-tidy are the authority; CI fails on any diff or warning.

## Layout and ownership

| Path | Content | Owner |
|---|---|---|
| `include/rt/` | public headers — the interface contract | orchestrator + user |
| `src/`, `app/` | implementation, CLI | developer agent |
| `tests/unit/` | Catch2 tests, mirrors `include/rt/` | test-writer agent |
| `.claude/` | agents, skills, settings | orchestrator + user, via PR |

An agent never edits outside its paths; it escalates instead.

## Git

- Conventional Commits in English, referencing the sub-issue: `feat(math): add Vec3 (#12)`.
- One milestone = one branch `feature/Mx` = one PR. Merge commits, no squash. Only the user merges.
- Git and GitHub are read-only for agents (enforced by `.claude/hooks/agent-guard.ps1`): the
  orchestrator reviews each agent's diff, commits, pushes and publishes.
- An agent's work is committed with the agent as author:
  `--author "test-writer (Haiku) <test-writer@agents.raytracer>"`.
