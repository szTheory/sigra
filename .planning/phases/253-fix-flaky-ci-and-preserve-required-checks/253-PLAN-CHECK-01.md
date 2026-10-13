## ISSUES FOUND

**Phase:** 253 — Fix Flaky CI and Preserve Required Checks  
**Plans checked:** 8  
**Issues:** 1 blocker, 0 warnings, 0 info

### Blockers — these properties must hold

**1. [research_resolution] RESEARCH.md has no unresolved open questions before planning proceeds**

- Plan: Phase-level
- Evidence: [253-RESEARCH.md](253-RESEARCH.md) has an unsuffixed `## Open Questions` section with three unanswered questions: the cause of the current admin registration failure, actual hosted browser/example-app dependency versions, and whether records/reports survive hosted dispatch and pull_request runs with correct identity. Plans 253-02, 253-07 and 253-08 schedule work to determine these during execution, but the research-resolution gate requires these research questions to be resolved before planning proceeds.
- Example fix (non-binding): Record the chosen bounded investigation and conditional outcomes as resolved research decisions, including that an unknown registration cause remains an open CIREL-01 gap.

### Coverage and plan summary

| Requirement | Plans | Status |
|---|---|---|
| CIREL-01 | 01, 02, 08 | Covered conditionally; an unproved registration cause remains open and cannot count as phase acceptance |
| CIREL-02 | 03–08 | Covered through unit-gate ownership, body/manifest parity, five producer records and reports, hosted canary, and production PR evidence |

| Plan | Tasks | Wave | Review |
|---|---:|---:|---|
| 01 | 2 | 1 | Complete task fields; preserves legacy replay and adds bounded diagnosis |
| 02 | 3 | 1 | Complete task fields; reproduction, controls, and conditional fix/gap path are explicit |
| 03 | 2 | 1 | Complete task fields; unit lane is added across needs/result/verdict ownership |
| 04 | 2 | 1 | Complete task fields; workflow body/aggregate mismatch and parity controls are covered |
| 05 | 2 | 1 | Complete task fields; exact five-seam/native-report validation is specified |
| 06 | 2 | 2 | Depends on 03/04/05; wires all producers into the existing aggregate |
| 07 | 2 | 3 | Depends on 06; six hosted scenarios and separate verification fit the stated ceilings |
| 08 | 2 | 4 | Depends on 02/07; separates production PR proof and honest completion status |

The declared dependencies are acyclic and the wave numbers are consistent. Same-wave plans have no shared modified files. Task counts are within the stated scope thresholds. The supplied path probe is `not_applicable` for these Bash/Node/Python command forms; its supplemental literal-target check reports existing targets or declared pending creation. All 17 runnable commands have non-placeholder failing directions. No scope reduction or contradiction of the 24 locked decisions was found. The exact-version package audit supports the planned lockfile restore; no new dependency is proposed. The research responsibility map matches the planned CI, browser, and hosted-verification tiers. `AGENTS.md` and `test/example/AGENTS.md` constraints are reflected in the plans, including no sleeps/retries, scoped traces, and existing ownership patterns.

### Structured Issues

```yaml
issues:
  - plan: null
    dimension: research_resolution
    severity: blocker
    required_property: "Phase research contains no unresolved open questions before planning proceeds"
    description: "253-RESEARCH.md has an unsuffixed ## Open Questions section with three unanswered questions: the current registration failure cause, actual hosted browser/example-app dependency versions, and hosted record/report identity behavior on dispatch and pull_request. Plans schedule these for execution but the research-resolution gate requires resolution before planning proceeds."
    fix_hint: "Record the selected bounded investigation and conditional outcomes as resolved research decisions, including that an unknown registration cause remains an open CIREL-01 gap."
```

### Recommendation

1 blocker requires revision. Other reviewed dimensions pass; the open-question blocker is the only issue identified.
