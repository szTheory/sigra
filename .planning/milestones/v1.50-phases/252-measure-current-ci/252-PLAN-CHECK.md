## ISSUES FOUND

**Phase:** 252 — Measure Current CI  
**Plans checked:** 6  
**Issues:** 5 blocker(s), 1 warning(s), 0 info

### Coverage Summary

| Requirement | Plans | Status |
|---|---|---|
| CIMEAS-01 | 252-01, 252-02, 252-05, 252-06 | Claimed and addressed, subject to findings below |
| CIMEAS-02 | 252-01, 252-02, 252-03, 252-04, 252-05, 252-06 | Claimed and addressed, subject to findings below |

The plans cover the three event populations, literal outcomes and attempts, source-bound replay, ranked wait and runner costs, test timing, failure diagnostics, and the fixed 20-pair comparison method. The supplied probes report all 15 verify commands as `not_applicable` for path resolution and all 15 failing-direction checks as `ok`; these verdicts are carried through unchanged. They do not validate live acquisition behavior or the source targets. Plan structures are reported valid and all 21 decision references pass; neither resolves the semantic blockers below.

### Blockers — these properties must hold

**1. [budget_and_rate_controls] Every live GitHub acquisition, including preflight and tracer work, obeys the shared request, time, retry, and rate-limit bounds.**
- Plan: 252-01
- Task: 1
- Evidence: The first action creates `252-EVIDENCE-PREFLIGHT.json` by querying the live ruleset and checking access to run records, attempt jobs, check runs, and artifact metadata. It records request count, but does not require that these requests use Plan 02's 600-request/60-minute budget, core-rate stop, one-retry rule, or interruption ledger. Plan 02 adds those controls later, so the initial live calls can exceed the approved limits before the bounded collector exists.
- Example fix (non-binding): Specify a bounded, rate-aware read-only preflight for every API call, with durable incomplete diagnostics and the same stop/retry rules as the later collector.

**2. [context_compliance] Missing hosted inputs leave measurements unknown while independent offline implementation continues.**
- Plan: 252-01
- Task: 1
- Evidence: The action says “Stop before implementation if a required source capability is blocked.” The approved context says to retain a concrete diagnostic and proceed with independent work when a required source is unavailable. Since Plans 02–06 depend transitively on Plan 01, this stop prevents the formatter, browser-report, workflow-contract, replay, and report work from proceeding even though those tasks can be developed and checked offline. The final baseline must remain unpassed when required hosted measurements are missing.
- Example fix (non-binding): Let a blocked preflight produce a durable blocked/unknown input and allow independent offline tasks to proceed; keep the baseline acceptance nonzero until required measurements exist.

**3. [context_compliance] The required-result endpoint is derived from currently effective enforced checks, while a ruleset ID is recorded as observed provenance.**
- Plan: 252-01
- Task: 1
- Evidence: The preflight requires the live `ruleset 14941512`, and its acceptance requires those ruleset identities and exact context names. This treats the discovery-time ruleset ID as a prerequisite identity. The locked decision requires re-reading effective required rules and treating a changed rule as a diagnostic; it does not lock the historical ruleset ID itself. A ruleset replacement or equivalent branch-protection configuration could preserve the enforced checks while making this preflight block incorrectly.
- Example fix (non-binding): Resolve and save the effective required contexts from the current enforcement source(s), compare the enforced endpoint to the approved measurement contract, and retain the ruleset ID as provenance rather than a fixed identity requirement.

**4. [security_and_artifact_provenance] Artifact and log download redirects are validated before they are followed, and signed URLs are never persisted.**
- Plan: 252-02
- Task: 3
- Evidence: The action validates artifact ID, producing run, SHA, expiry, digest, archive bounds and retained request metadata, and says to strip signed redirect URL material. It does not specify validation of redirect destinations before following them. The research and coverage contract explicitly require validated download redirects. Without that behavior, the external download boundary is incomplete.
- Example fix (non-binding): Define and test an allowlisted HTTPS redirect policy for the GitHub artifact download flow, while counting downloads against the budget and excluding signed URLs from retained data.

**5. [context_compliance] Instrumentation overhead is measured or disclosed for both ExUnit and Playwright timing paths.**
- Plan: 252-03, 252-04, 252-05, 252-06
- Task: 252-03 Task 2; no Playwright task
- Evidence: Plan 03 explicitly runs five paired measurements of the ExUnit formatter and stores `instrumentation_overhead_us`. Plans 04–05 add Playwright's JSON reporter and retain those timings, but define no corresponding reporter-overhead measurement or disclosure. Plan 06 reports the ExUnit observations while requiring the same instrumentation in later conditions. The locked D-13 decision requires accounting for the instrumentation overhead; the planned evidence covers only one of the two instrumented runners.
- Example fix (non-binding): Add a reproducible overhead observation or an explicit supported bound/disclosure for the Playwright reporter path, and include both runner paths in the baseline and comparison contract.

### Warning — should hold

**1. [key_links_planned] Runtime metadata identifies the actual toolchain that produced each measurement, or records it as unknown.**
- Plan: 252-05
- Task: 1
- Evidence: The metadata action lists pinned Erlang/Elixir/Node/Playwright versions and allows missing values to be null, but it does not explicitly capture the actual runtime versions from the producing job. A configured pin describes intended setup; it does not by itself establish the runtime that emitted a timing artifact. This can weaken source-backed interpretation of test costs.
- Example fix (non-binding): Record version output from each relevant runner/job, separately from configured pins, and retain null when a runtime value cannot be read.

### Advisory checks

- No broken or circular plan dependencies found: waves order 252-01 → 252-02/03/04 → 252-05 → 252-06.
- Task counts are 2, 3, 2, 2, 3, and 3; no plan exceeds the five-task blocker threshold.
- Existing five browser seams, zero retries, single `mix ci` owner, per-invocation report paths, no-new-dependency constraint, p95 nearest-rank rule, 20 matched pairs/40 families, 48-hour window, unknown-versus-pass handling, and failure-signature limits are represented in executable plan content.
- No task adds the deferred optimization, gate-repair, product, dependency-upgrade, or release-proof work.
- No same-wave undeclared shared mutable resource dependency was identified.
- Dimension 7c skipped: no Architectural Responsibility Map found in RESEARCH.md. Dimension 10 skipped: no project `.agents/skills/` or `.codex/skills/` directories found; root `AGENTS.md` was read and no plan contradiction found beyond the findings above. Dimension 11 passed: research open questions are resolved. Dimension 12 checked against PATTERNS.md; tasks generally cite the existing seams, with no additional blocker identified.

### Structured Issues

```yaml
issues:
  - plan: "252-01"
    dimension: "budget_and_rate_controls"
    severity: "blocker"
    required_property: "Every live GitHub acquisition, including preflight and tracer work, obeys the shared request, time, retry, and rate-limit bounds"
    description: "Task 1 performs live ruleset, run, job, check-run, and artifact-metadata requests before Plan 02's 600-request/60-minute, core-rate, retry, and interruption controls are planned."
    task: 1
    fix_hint: "Bound and rate-control preflight API calls with durable interruption diagnostics."
  - plan: "252-01"
    dimension: "context_compliance"
    severity: "blocker"
    required_property: "Missing hosted inputs leave measurements unknown while independent offline implementation continues"
    description: "Task 1 says to stop before implementation if a required source capability is blocked, contradicting the approved context's instruction to proceed with independent work and retain missing measurements as unknown."
    task: 1
    fix_hint: "Allow offline-independent tasks to proceed after a blocked preflight while keeping baseline acceptance nonzero."
  - plan: "252-01"
    dimension: "context_compliance"
    severity: "blocker"
    required_property: "Required-result measurement follows currently effective enforced checks rather than a discovery-time ruleset identifier"
    description: "Task 1 requires ruleset 14941512 as a prerequisite identity, although the locked decision requires current effective rules and does not lock that historical ID."
    task: 1
    fix_hint: "Treat the ruleset ID as provenance and derive the enforced endpoint from current effective rules."
  - plan: "252-02"
    dimension: "security_and_artifact_provenance"
    severity: "blocker"
    required_property: "Artifact and log download redirects are validated before they are followed, and signed URLs are never persisted"
    description: "Task 3 strips signed redirect URL material from retained metadata but does not plan validation of redirect destinations before following them, despite the research and API coverage contract requiring validated redirects."
    task: 3
    fix_hint: "Specify and fixture-test the allowed HTTPS redirect destinations for artifact downloads."
  - plan: "252-03"
    dimension: "context_compliance"
    severity: "blocker"
    required_property: "Instrumentation overhead is measured or disclosed for both ExUnit and Playwright timing paths"
    description: "Task 2 measures formatter overhead for ExUnit only; no Playwright plan measures or discloses reporter overhead, although both timing paths are added and D-13 requires accounting for instrumentation overhead."
    task: 2
    fix_hint: "Add a reproducible Playwright overhead observation or explicit bound/disclosure to its timing contract."
  - plan: "252-05"
    dimension: "key_links_planned"
    severity: "warning"
    required_property: "Runtime metadata identifies the actual toolchain that produced each measurement, or records it as unknown"
    description: "Task 1 lists pinned toolchain versions but does not explicitly capture actual runtime versions from the producing job."
    task: 1
    fix_hint: "Record runtime version output separately from configured pins, preserving null when unavailable."
```

### Recommendation

5 blockers and 1 warning require revision before execution. The report is advisory to the planner; each fix hint is one example route to the required property.

### Reviewed plan hashes

| Plan | SHA-256 |
|---|---|
| 252-01 | `e51a65264f1898dd82ef460f749fb008b63d5b4112e5c3efa4c5241771e3ba3a` |
| 252-02 | `a6ba87f9317211bd71a87b495551e3375cceda6d555a0630f784023b8d01d471` |
| 252-03 | `3c155bf5eb6d79f67420621efd8b819447a4b2ad21f88ba9f41079b165fda367` |
| 252-04 | `cd192e8bda9bd69fb46f55b1a132fb7ae8a6c10cbeb510e2a698840d53d79414` |
| 252-05 | `769c68bee8acb21bbdaacd4566584d3f08400cce2dcf8fa9ebeb7a11f9882357` |
| 252-06 | `b0fabc61c3588bee8bfa93a0cbf899ab5f8a6015ad1266c728baa648c2cd7b6e` |
