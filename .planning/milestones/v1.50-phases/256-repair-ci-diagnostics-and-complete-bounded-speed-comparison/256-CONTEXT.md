# Phase 256: Repair CI diagnostics and complete bounded speed comparison — Context

**Gathered:** 2026-11-04
**Status:** Ready for planning
**Source:** Approved successor scope from `256-SCOPE.md` (PRD express path)

<domain>
## Phase Boundary

Use one separate phase to apply and source-check the local diagnostics-capture
repair, run one bounded candidate preparation on the existing PR #368 branch,
and, only if independent preparation verification passes, complete the already
approved 20-pair repaired-control comparison. Keep Phase 255.1's spent attempts
and terminal records immutable. Phase 256 is the sole forward route for
CISPEED-01/02.

</domain>

<decisions>
## Implementation Decisions

### Scope and authority
- The user authorizes project CI within this phase without per-run approval.
- Never reopen Plan10, add Plan11, or route to `$gsd-execute-phase 255.1`.
- Update only the existing evidence PR #368 source branch; no replacement PR,
  merge, release, branch-rule mutation, explicit cache seed, or scope renewal.
- Keep the one candidate preparation capped at 514 request attempts, one source
  mutation, one workload, 45 minutes, 280 runner timeout-job minutes, and a
  2,700-second hard outer timeout. Do not retry or rerun it.
- Continue automatically to measurement only after an independent
  `PREP-VERIFY` passes. Use the original forty PR families/twenty pairs, 24,000
  request attempts, 82 semantic mutations, one 48-hour window, one
  independently diagnosed infrastructure retry maximum, and no product retry,
  replacement family, or renewal. No extra approval prompt is inserted between
  preparation and measurement.

### Correctness and evidence
- Before publication, check the actual candidate commit with
  `scripts/ci/ci-playwright-environment-check.py` and the reviewed helper hash;
  confirm selected prerequisite repairs are present and keep the shared
  environment repair separate from the candidate's combined-Mix treatment.
- Capture the structured OS-dependency report and apt logs from both supported
  locations, bind metadata to the selected report, and reject unsafe
  workspace-symlink paths.
- Preserve the fixed 20-pair schedule, balanced order, cache/image comparability
  requirements, common repaired-control changes, instrumentation, median/p95
  method, and acceptance thresholds from the approved Phase 255.1 contract.
- Report every failure, cancellation, setup/installation cost, request and
  runner cost. Local reproduction and successful preparation do not count as
  speed samples.
- Leave CISPEED-01/02 open unless the measured result is `pass` and the
  independent phase verifier passes.

### Routing
- Phase 255.1 is terminal halted/blocked history. Phase 256 depends on Phase
  255, not on the blocked Phase 255.1 plans, so a malformed or spent old plan
  cannot hold this successor hostage.
- The fixed total external ceiling is 24,514 request attempts, 83 semantic
  mutations, and at most 42 workflow workloads. The hard end-to-end deadline is
  48 hours 45 minutes from the first hosted request, including the 45-minute
  preparation window; the measurement clock remains 48 hours from the first
  primary family's workflow creation.
- Stop on the first hard cap, source/base/rules drift, missing proof, unresolved
  failure cause, or GitHub 403/429. Use one 60-second watcher per run and honor
  the existing rate-limit stop rules.

### the agent's Discretion
- Plan decomposition, local regression details, durable receipt paths, and the
  exact source-derived job/runner ceilings, provided the approved contract and
  the hard totals above are preserved. If the production proposal cannot
  calculate and verify exact runner/job ceilings, stop before collection.

</decisions>

<canonical_refs>
## Canonical References

### Current scope and workflow
- `.planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-SCOPE.md` — phase limits, decision, and acceptance.
- `AGENTS.md` — CI rate limits, evidence preservation, Phase 255.1 recovery, and forward routing.
- `.planning/REQUIREMENTS.md` — unchanged CISPEED-01/02 acceptance definitions.
- `.planning/ROADMAP.md` — milestone and phase dependencies.

### Prior comparison and terminal evidence
- `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/255.1-CONTEXT.md` — approved repaired-control method.
- `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/255.1-07-PLAN.md` — existing measurement contract and fixed schedule.
- `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/255.1-10-SUMMARY.md` — terminal failed candidate outcome.
- `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/255.1-RECOVERY-RESET.md` — cause of the phase routing loop and current halt.
- `.planning/execution/255.1/diagnostics/next-scope-proposal-20261104/SCOPE-PROPOSAL.md` — predecessor candidate-only proposal.
- `.planning/execution/255.1/write-ahead-preservation/phase2551-before-terminal-route-refresh-20261104T151911Z/PRESERVATION-REF.json` — pre-route-refresh recovery copy.
- `.planning/execution/255.2/write-ahead-preservation/phase256-route-transition-20261104T161058Z/PRESERVATION-REF.json` — pre-Phase-256 route snapshot.

</canonical_refs>

<specifics>
## Specific Ideas

Treat preparation and speed acceptance as distinct evidence stages inside the
same authorized scope. A failed preparation ends the scope with diagnostics;
a passed preparation allows the fixed measurement plan to proceed without a
new user prompt.

</specifics>

<deferred>
## Deferred Ideas

No changes to the comparison method, new cache strategy, new dependency,
replacement source branch, merge, release, or expanded sample count.

</deferred>

---

*Phase: 256-repair-ci-diagnostics-and-complete-bounded-speed-comparison*
*Context gathered: 2026-11-04 from the recorded scope and user's explicit CI authorization*
