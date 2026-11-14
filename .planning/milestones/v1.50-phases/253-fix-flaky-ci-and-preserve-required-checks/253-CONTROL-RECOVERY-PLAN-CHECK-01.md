## ISSUES FOUND

**Phase:** 253 — Fix Flaky CI and Preserve Required Checks  
**Plans checked:** 10 (253-26 through 253-35)  
**Issues:** 1 blocker, 0 warnings, 0 info

### Blockers — these properties must hold

**1. [task_completeness] Offline control tests must execute the same exported control primitives used by the Playwright spec**
- Plan: 253-26
- Task: 2
- Evidence: The task requires `registrationControls.ts` exports to be exercised by the `.mjs` Node tests through Page-method spies, and its verifier runs those tests with `node --test` (plan lines 82–87). The repository's CI toolchain runs Node 20 (for example, `.github/workflows/ci.yml` line 443). The plan names no TypeScript loader, transpilation step, or other Node 20-compatible way for that `.mjs` test to import and invoke the TypeScript exports. As written, the required offline executable contract is not shown to be runnable; source-text checks would not satisfy the task's same-export requirement.
- Required property: The offline regression test can invoke and fail on the actual control implementation that the Playwright spec imports, using the project’s pinned Node 20 test command.
- Example fix (non-binding): Put the shared primitives in a module both runtimes can execute directly, or name and verify an already-pinned Node 20-compatible TypeScript loading path.

### Coverage and plan summary

| Requirement | Plans | Status |
|-------------|-------|--------|
| CIREL-01 | 26–30, 34–35 | Covered in planned work; native cause/repeats and final acceptance remain conditional on strict proof |
| CIREL-02 | 30–35 | Covered in planned work; hosted scenarios, verifier, and both real PR families are explicitly required |

| Plan | Tasks | Files modified | Wave | Status |
|------|-------|---------------|------|--------|
| 26 | 2 | 5 | 1 | Valid structure; one blocker above |
| 27 | 2 | 4 | 2 | Valid |
| 28 | 2 | 1 | 3 | Valid |
| 29 | 3 | 6 | 4 | Valid |
| 30 | 2 | 6 | 5 | Valid |
| 31 | 2 | 3 | 6 | Valid |
| 32 | 2 | 7 | 6 | Valid |
| 33 | 3 | 3 | 7 | Valid |
| 34 | 2 | 4 | 8 | Valid |
| 35 | 2 | 3 | 9 | Valid |

The dependency chain is acyclic and routes the new work through plans 26–35 without depending on halted historical plans. Same-wave plans 31 and 32 have disjoint declared file ownership. The native and hosted tasks preserve strict stop conditions; plan 35 requires accepted evidence before dispositions and leaves whole-phase verification unstarted. The budget arithmetic matches the stated caps: 243,044 ms carried, 3,295,533 ms maximum including conditional narrow ExUnit checks, 18 launched Playwright processes, 117 new canary requests plus three known historical reservations, and 120 production requests shared across both PR families.

The supplied path probe reports `not_applicable` with no severity or read error for these commands; it does not establish path resolution, and new targets are planned outputs. The supplied failing-direction probe reports `ok` for all 20 new plan tasks. Structural plan validation passed for all ten plans. Architectural tier matches the research map; no unresolved research questions section was found. Context decisions D-01 through D-24 are represented, including the stop on missing cause/order and the rule that the 121,252 ms dark command remains failed. No plan claims those historical failures are fixed by repairing controls.

### Structured Issues

```yaml
issues:
  - plan: "253-26"
    dimension: "task_completeness"
    severity: "blocker"
    required_property: "The offline regression test can invoke and fail on the actual control implementation that the Playwright spec imports, using the project’s pinned Node 20 test command."
    description: "Task 2 requires a Node .mjs test to execute exports from registrationControls.ts, but the project CI test runtime is Node 20 and the plan specifies no TypeScript loader or transpilation path. The required test command therefore has no planned runnable path to the same implementation; textual/source checks would not satisfy the stated contract."
    task: 2
    fix_hint: "Use a shared module directly executable by Node 20, or identify and verify an already-pinned Node 20-compatible TypeScript loading path."
```

### Recommendation

1 blocker requires revision before execution.
