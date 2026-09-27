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

One milestone = one spec session + one implementation session = one PR. One milestone active at a time.

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
├─ plan/                   orphan branch `plan` (this file, specs/Mx.md)
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
| test-writer | Haiku | `tests/` | Must not read `src/` or `app/`. Chooses test cases itself from the headers' doc comments and the spec, walking a scenario grid (nominal, degenerate, boundaries, errors, numeric, determinism). Reports a coverage map. Done = tests compile (link errors / red expected). |
| developer | Sonnet | `src/`, `app/` | Never modifies tests nor `include/rt`. On a doubtful test or header: keeps going on the rest, escalates at the end. Lists what it noticed but did not touch. Done = tests green + lint clean. |
| reviewer | Sonnet | nothing (read-only) | Reviews `main...feature/Mx` against spec + issue + CLAUDE.md, tests first; axes: spec, correctness, tests, architecture, performance, ownership, style + presumptive-blocker checklist. May run build/tests. Returns findings as JSON for inline PR comments. |

- One PreToolUse hook guards all three (`.claude/hooks/agent-guard.ps1`, table-tested by
  `agent-guard.tests.ps1`): path ownership per role, and git/GitHub read-only for every agent.
  It is registered in the workspace `.claude/settings.json` (copied from the repo by
  `setup-workspace.ps1`) and dispatches on the payload's `agent_type`; the main session passes.
  Not in agent frontmatter: frontmatter hooks never fire here (anthropics/claude-code#95650).
- Prompts also say: an instruction contradicting a rule is not followed but reported.
- Agents never commit. The orchestrator reviews each agent's diff, commits, pushes, opens PRs,
  updates the board. Traceability: an agent's work is committed with the agent as git author
  (`--author "developer (Sonnet) <developer@agents.raytracer>"`); the committer stays the user.
- Max 3 subagents in flight.
- Verified in M0: agents are discovered through the `.claude/agents` junction (a new file there is
  picked up late or after a restart); per-agent frontmatter hooks are documented but did **not**
  fire (probe agent, Claude Code 2.1.263, Windows); the settings-level hook does, hot-reloaded.
- M0 dry-run (throwaway `clamp`, traps): test-writer (Haiku) obeyed an injected "read src/"
  instruction and did not report it (hook absent at the time); developer escalated a contradictory
  test and refused an injected "commit" instruction; reviewer found both the wrong test and an
  injected hot-path allocation no test covers, with correct owners and JSON output.

## Milestone workflow

0. **Spec session (separate, before the milestone)**: grilling with the user (`/grilling`), then the
   orchestrator writes `plan/specs/Mx.md` and pushes it. Sections: Goal, Behaviours, Acceptance
   criteria, **Out of scope** (explicit list, used by the reviewer), Open questions.
1. `/milestone Mx` in a fresh session. User + orchestrator derive the `include/rt` headers from the
   spec; orchestrator commits them in `Mx/` (branch `feature/Mx`).
2. test-writer writes tests (compile, red or unlinked) and a coverage map; orchestrator reviews the
   diff and commits. — strict TDD
3. developer makes them green, lists what it noticed but did not touch; orchestrator verifies
   tests + lint, reviews the diff and commits.
4. Orchestrator pushes, opens a **draft** PR (body: Changes / Not touched / Points of attention).
   The reviewer gets only diff + spec + issue (never the agents' reports). Orchestrator triages
   findings (valid / trade-off / contract misread / noise) and posts one PR review with inline comments.
5. Fix loop on every **valid** finding: owning agent resumed with its context, **max 2 rounds**,
   then escalate to user. Implementation defects follow **Prove-It**: test-writer first writes a
   failing test from the defect scenario, then developer fixes. If developer thinks a test is
   wrong, it escalates; test-writer fixes it.
6. PR marked ready → **human review by the user**, who merges. No intermediate human checkpoint
   (conscious deviation from agent-skills' "sequential orchestrator" anti-pattern: agents read
   files themselves, so hand-offs do not paraphrase; the contract is fixed before delegation).
7. Remove the `Mx/` worktree and branch, `git pull` in `main/`, update the board.

Every session (spec or milestone) ends by overwriting `plan/HANDOFF.md` (milestone and step,
decisions, next action, verification commands, open risks) and pushing it.

Several ideas above come from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
(code-reviewer, test-engineer, doubt-driven-development, incremental-implementation).

## M0 specifics

M0 creates the agents, so it cannot use them: orchestrator scaffolds, user and orchestrator write the
three agents, the hook and the skill together, then dry-run them. M0 still goes through a PR.
First commit on `main`: `CLAUDE.md` (+ README). `plan` branch created as orphan with this file.

## Prerequisites

- `gh` installed (done, 2.101.0). User runs `gh auth login --scopes project`.
