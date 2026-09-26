# Raytracer — Project Plan

Training project for agentic AI development in a professional setting.
Constraint: Claude Pro subscription — keep sessions short, contexts fresh, subagents cheap.

This file lives on the orphan branch `plan` (worktree `Raytracer/plan/`). It never merges with code,
so decisions are committed and pushed directly (`docs(plan): ...`), without PR.

## Goals

- Primary: practice **steering** agents (splitting work, writing specs, delegating, reviewing diffs)
  and a **full professional workflow** (issues, PRs, CI, reviews, tests).
- Build and use **dedicated subagents** designed together (max 3 running at once).
- Debugging/perf practice comes late (M6).

## Product

C++20 raytracer, loosely inspired by *Ray Tracing in One Weekend* (not a strict follow-along).

| Milestone | Content |
|---|---|
| M0 | Bootstrap: CMake presets, Catch2, clang-format/tidy, CI, CLAUDE.md, agents, hook, `/milestone` skill |
| M1 | Math core: Vec3, Ray, PNG output, gradient image |
| M2 | Geometry: sphere, object list, simple camera, antialiasing |
| M3 | Materials: diffuse, metal, dielectric |
| M4 | Camera: FOV, lookFrom/lookAt, defocus blur |
| M5 | JSON scene: loading, validation, explicit errors, CLI |
| M6 | Multithreading: tile rendering, deterministic per-pixel RNG, benchmark |
| M7 | Non-regression: reference images + RMSE tolerance in CI |

One milestone = one session = one PR. One milestone active at a time.

- Numeric type: `double`. Errors: exceptions.
- Dependencies: Catch2 v3, nlohmann/json (FetchContent, shared cache), stb_image_write (PNG).
- Render tests: fixed seed, low resolution, RMSE tolerance vs reference image.

## Code style

- Naming ("modern mixed"):
  - Types, concepts, enums, enum values: `PascalCase` (`MaterialKind::Lambertian`)
  - Functions, methods, variables, parameters: `camelCase`
  - Members `m_camelCase`, static members `s_camelCase`, constants `kPascalCase`
  - Namespaces lowercase (`rt::geometry`), macros `RT_UPPER_CASE`
  - Files `PascalCase.hpp` / `PascalCase.cpp`, directories lowercase
- Formatting (clang-format): attached braces, 4-space indent, 100 columns, `T*` / `T&` bound to type.
- `#pragma once`, west const (`const T&`).
- Include order: project, third-party, std (blank line between groups).
- clang-tidy enforces naming via `readability-identifier-naming`.

## Tooling

- CMake presets + Ninja + MSVC (VS 2022) locally. Tests via Catch2 `catch_discover_tests` + `ctest --preset`.
- Scripts: PowerShell `.ps1` locally, bash `.sh` for Linux CI.
- GitHub public repo `raytracer`:
  - `main` protected: green CI required, merge commits (no squash). Only the user merges.
  - Conventional Commits, referencing the sub-issue (`feat(math): add Vec3 (#12)`).
- CI (GitHub Actions): Windows MSVC build+test; Linux GCC/Clang build+test; lint job (clang-format, clang-tidy).
- Tracking: GitHub Projects kanban (Todo / In progress / In review / Done).
  One parent issue per milestone (spec + acceptance criteria + interface contract), one sub-issue per delegated task.

## Workspace layout

```
Raytracer/                 not versioned — Claude session runs here
├─ CLAUDE.md               contains only "@main/CLAUDE.md"
├─ .claude/
│  ├─ agents -> main/.claude/agents   (junction)
│  ├─ skills -> main/.claude/skills   (junction)
│  └─ settings.local.json
├─ .cache/fetchcontent/    shared FetchContent cache
├─ plan/                   orphan branch `plan` (this file)
├─ main/                   always on `main`
└─ Mx/                     worktree on feature/Mx — the single worktree of the active milestone
```

Junctions and top-level files are recreated by `main/scripts/setup-workspace.ps1`.
Junction discovery by Claude Code must be verified in M0 (fallback: copies).

Repository layout:

```
main/
├─ CMakeLists.txt, CMakePresets.json, CLAUDE.md, README.md (links to `plan` branch)
├─ .clang-format, .clang-tidy, .gitignore
├─ .claude/ agents/, skills/milestone/, settings.json
├─ .github/workflows/ci.yml
├─ include/rt/   math/ geometry/ material/ camera/ scene/ render/   <- interface contract
├─ src/          same tree, .cpp                                    <- developer
├─ app/main.cpp  CLI                                                <- developer
├─ tests/        unit/ (mirrors include/rt), golden/ (M7)           <- test writer
├─ scenes/       example JSON scenes
└─ scripts/      .ps1 (local), .sh (Linux CI)
```

## Agents

Defined in `main/.claude/agents/`, versioned. Agent changes go through a PR.

| Agent | Model | Writes | Rules |
|---|---|---|---|
| test-writer | Haiku | `tests/` | Must not read `src/` or `app/` (PreToolUse hook in its frontmatter + prompt). Tests must compile against headers. |
| developer | Sonnet | `src/`, `app/` | May read tests, never modifies them nor `include/rt` — escalates instead. |
| reviewer | Sonnet | nothing (read-only) | Reviews `main...feature/Mx` against the issue and CLAUDE.md. |

- test-writer and developer commit their own paths in the milestone worktree; on `index.lock` failure, wait 5 s and retry.
- No agent ever pushes. The orchestrator (main session) pushes, opens PRs, updates the board.
- Max 3 subagents in flight.
- Per-agent hook support must be verified in M0.

## Milestone workflow (`/milestone Mx`)

1. User + orchestrator define the `include/rt` headers; orchestrator commits them in `Mx/` (branch `feature/Mx`).
2. test-writer writes tests (compile, red or unlinked) and commits. — strict TDD
3. developer makes them green and commits.
4. Orchestrator runs ctest, pushes, opens a **draft** PR; reviewer report posted as a PR comment.
5. Fix loop: responsible agent resumed with its context, **max 2 rounds**, then escalate to user.
   If developer thinks a test is wrong, it escalates; test-writer fixes it.
6. PR marked ready → **human review by the user**, who merges.
7. Remove the `Mx/` worktree and branch, `git pull` in `main/`, update the board.

## M0 specifics

M0 creates the agents, so it cannot use them: orchestrator scaffolds, user and orchestrator write the
three agents, the hook and the skill together, then dry-run them. M0 still goes through a PR.
First commit on `main`: `CLAUDE.md` (+ README). `plan` branch created as orphan with this file.

## Prerequisites

- `gh` installed (done, 2.101.0). User runs `gh auth login --scopes project`.
