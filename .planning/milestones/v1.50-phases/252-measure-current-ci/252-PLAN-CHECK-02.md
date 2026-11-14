## ISSUES FOUND

**Phase:** 252 — Measure Current CI  
**Plans checked:** 6  
**Status:** 1 blocker, 0 warnings, 0 info

### Coverage summary

| Requirement | Plans | Status |
|---|---|---|
| CIMEAS-01 | 252-01, 252-02, 252-05, 252-06 | Covered |
| CIMEAS-02 | 252-01, 252-02, 252-03, 252-04, 252-05, 252-06 | Covered |

The tasks cover separate PR/main/nightly populations, source-bound required-result waits and reruns, actual job/step/test and setup/cache costs, a bounded current failure shortlist, offline replay, and the fixed later comparison contract. The comparison retains 20 pairs/40 primary families, the 48-hour window, matched workload/runner/cache conditions, nearest-rank p95 (19th of 20), and honest miss/unknown/insufficient-data outcomes. It does not claim the later target has passed.

Plan structures and decision references were reported valid: 15 automated commands have complete structure and stated failing directions, and the decision-coverage probe reports 21/21. The path probe reports `not_applicable` for all 15 commands; I therefore checked targets against the plans directly. Existing targets are referenced as inputs, while new scripts, tests, reports, and evidence files are assigned to creating tasks and their dependencies. No same-wave file overlap or undeclared shared mutable-resource dependency was found. The responsibility map exists in RESEARCH.md and the task tiers align with it. The plans preserve the `mix ci` owner, five browser seams, zero browser retries, existing required check names, offline replay, and Phase 252 scope.

### Blockers — these properties must hold

**1. [research_resolution] Every research open question is resolved before execution proceeds.**
- Evidence: `252-RESEARCH.md` still has an `## Open Questions` section without a `(RESOLVED)` suffix or per-question `RESOLVED` markers. It labels three items unclear: historical artifact/log retention, the authoritative completion timestamp for aggregator-backed required contexts, and whether the request budget can cover selected logs/artifacts. Plans include conservative unknown/error behavior and bounded acquisition, but the research artifact itself still presents these implementation questions as open, so the required pre-planning research-resolution gate is not met.
- Example fix (non-binding): Record the chosen fallback for each question in RESEARCH.md and mark the section/questions resolved; unavailable historical data may remain explicitly unknown at runtime.

### Initial review findings and dispositions

| Initial finding | Disposition | Evidence in revised plans |
|---|---|---|
| Plan 01 preflight/tracer API calls were outside the shared budget and rate guard | Resolved | Plan 01 Task 1 builds and tests the shared GET guard before its first request, including rate-limit/preflight/tracer requests; 600-request/60-minute, core-250, retry and interruption ledger behavior are explicit. Plan 02 extends the guard to pages/downloads. |
| A blocked hosted source stopped independent offline work | Resolved | Plan 01 Task 1 and Plan 06 Task 1 retain hosted gaps as unknown and continue independent hermetic work; final baseline validation remains nonzero when essential measurements are absent. |
| Discovery ruleset ID was treated as a fixed identity | Resolved | Plan 01 derives current effective enforced names and retains observed rule IDs only as provenance; replacement of historical ID 14941512 with equivalent enforcement does not block. |
| Artifact/log redirects were not validated before following | Resolved | Plan 02 Task 3 disables automatic following, validates the exact HTTPS host/path/port policy before each hop, counts each hop, tests rejected locations, and prevents signed URLs from persistence. |
| Playwright instrumentation overhead was absent | Resolved | Plan 04 Task 2 requires a paired measured observation or explicit `unmeasured`/null reason; Plans 05–06 carry it through and forbid zero substitution or target adjustment. ExUnit overhead is measured separately in Plan 03. |
| Actual runtime versions were not distinguished from configured pins | Resolved | Plan 05 Tasks 1–2 record actual producing-job version output separately from pins and preserve null plus a reason when unavailable; Plan 06 reports the distinction. |

### Structured issues

```yaml
issues:
  - plan: null
    dimension: research_resolution
    severity: blocker
    required_property: "Every research open question is resolved before execution proceeds"
    description: "252-RESEARCH.md retains an unmarked ## Open Questions section with three questions described as unclear: artifact/log retention, required-context completion timestamps, and request-budget sufficiency. The plans provide conservative fallback behavior, but the upstream research artifact does not record those questions as resolved."
    fix_hint: "Record the chosen fallback for each question in RESEARCH.md and mark the section/questions resolved; runtime data can still remain explicitly unknown when unavailable."
```

### Advisory checks

- **Path probe:** `not_applicable` for all 15 commands, as supplied. The plans name targets and creation tasks; this report does not claim the probe verified executable paths.
- **Failing-direction probe:** `ok` for all 15 commands, as supplied.
- **Smart-zone estimates:** Plans 03, 04, 05 and 06 report low confidence; treat those token figures as uncalibrated. Task counts are 2, 3, 2, 2, 3 and 3 respectively, with no plan at the checker’s 4-task warning threshold.
- **Architectural Responsibility Map:** Present in RESEARCH.md; no tier mismatch found.
- **AGENTS.md:** No plan contradicts the scoped project instructions. Planned hosted collection uses explicit GETs and the required 60-second single-owner watcher; no implementation or CI run is part of this review.

### Recommendation

1 blocker requires resolution before execution. The six findings from the initial report are resolved in the revised executable plan content; this new report does not modify the plans or prior audit.

### Exact reviewed plan hashes

| Plan | SHA-256 |
|---|---|
| 252-01 | `286b0b0035fdf16458113d21181ad068be18ffd4c1dd865c8ac16818cd86c7c6` |
| 252-02 | `1d801f7c6f953d121c78bbbc5f54c03f69bd87b2b3d8058e3feb0731c2817015` |
| 252-03 | `3c155bf5eb6d79f67420621efd8b819447a4b2ad21f88ba9f41079b165fda367` |
| 252-04 | `f7a8d1c5b4a5a86f206b53d4117d03119787b42b04b0b959e888f69efe5de76d` |
| 252-05 | `93558bdf70ef52be1eaeeac4c7610ba7e9f7417c410c5eddc51fafa64075d00f` |
| 252-06 | `b3652a1ec0aad31b583e0b38b15353b58697783a61e1ff786032d3177ae223ff` |

Reviewed revision: `8dd04f60cfdb8fc5cb7da50f62bbba5127065138` (the submitted revised-plan commit).
