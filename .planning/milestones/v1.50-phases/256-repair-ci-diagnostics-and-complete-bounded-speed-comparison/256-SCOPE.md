# Phase 256 scope: repair CI diagnostics and finish the speed comparison

## Why Phase 256 exists

Phase 255.1 has no runnable plans. Its final candidate run is halted, Plan07 is
blocked by that run, and its mutation/workload allowance is exhausted. The
active handoff kept pointing back into that closed phase. Phase 256 is the
forward route. It does not reopen Plan10, add Plan11, or count the failed run
as evidence of a speed result.

The failed candidate stopped in `ci-playwright-os-deps.py`. Its artifact omitted
the helper's structured report and apt logs, so the hosted cause is still
unknown. A local workflow change now captures those files from both the current
runner-temp path and the historical workspace path; its focused regression has
passed. The exact helper and Chromium-only reproduction passed locally on
Ubuntu 24.04.4, which does not prove the hosted Ubuntu 24.04.5 failure's cause.

## User decision and approval boundary

On 2026-11-04 the user authorized choosing a separate scope, confirmed that
project CI may run without per-run approval, and required a timeout. On
2026-11-05 the user reaffirmed that in-scope development and CI may proceed
without repeated approvals, said CI can run under a finite timeout, and
explicitly allowed choosing a new scope when recovery requires it. The
generation02 proposal expired unused while the required local production-path
repairs and review were underway. This amendment authorizes exactly one further
source-bound proposal rebind (generation02 to generation03) before any
authorization claim or hosted request, only while all request, mutation,
workload, runner, sample, and invocation-spend counters remain zero. Preserve
generation02 and the existing generation01-to-generation02 supersession record
byte-for-byte. The rebind uses the same single unspent preparation allowance and
all existing request, mutation, workload, runner, and elapsed-time ceilings; it
does not reset or renew any resource counter. No additional rebind is allowed.
The user has not authorized a merge, release, branch-rule change, cache seeding,
extra sample, or measurement-window renewal.

## Work and hard limits

1. Finish local source review and deterministic checks for the diagnostics
   capture fix. Before publishing, run
   `scripts/ci/ci-playwright-environment-check.py` against the exact candidate
   commit with the reviewed helper hash. Verify the selected prerequisite
   repairs are present. Keep the shared environment repair separate from the
   candidate's combined-Mix treatment.
2. Update only the existing evidence PR #368 branch, once, with the reviewed
   diagnostics fix and regression. Do not open a replacement PR or merge.
3. Run one candidate-only preparation workload, capped at 514 HTTP request
   attempts, one branch mutation, one workflow workload, 45 minutes from its
   first request, 280 runner timeout-job minutes, and a 2,700-second outer
   timeout. The one additional prelaunch proposal rebind above is permitted
   only before any stage authorization claim or hosted request, and cannot
   increase the single candidate invocation or reset cumulative counters. Once
   the invocation is claimed or any request begins, no retry, rerun, renewal,
   replacement run, or acceptance sample is allowed. Inspect the helper report
   and apt logs if it fails. A failed preparation is a terminal result for this
   scope.
4. Only if an independent `PREP-VERIFY` passes, continue automatically under
   the same user authorization to the already fixed measurement contract:
   forty original PR families (twenty pairs), at most 24,000 request attempts,
   82 semantic mutations, a single 48-hour measurement window, at most 600
   requests and 60 minutes per family, and at most one independently diagnosed
   infrastructure retry in its original family. No product retries, substitute
   families, outlier removal, or window renewal. Preserve the balanced order,
   common repaired changes, cache/image comparability rules, instrumentation,
   percentile method, and acceptance thresholds from the approved Phase 255.1
   contract.

The combined ceilings are 24,514 HTTP request attempts, 83 semantic mutations,
and at most 42 workflow workloads (one candidate preparation, forty primary
measurement families, and the one permitted infrastructure retry). The
preparation outer timeout is 2,700 seconds. The complete hosted scope ends no
later than 48 hours and 45 minutes after its first hosted request; the
measurement window itself remains exactly 48 hours from the first primary
family's workflow creation. Keep the original source-derived job timeouts and
runner-cost calculation; do not enlarge them. The measurement proposal must
calculate and independently verify the exact job/runner ceilings before any
measurement request. Stop earlier on any exhausted cap, 403/429 rate limit,
source/base/rules drift, missing proof, or unresolved cause.

## Acceptance

- The candidate preparation is either independently proved ready, or its exact
  failure cause is retained with the new report/log capture and no performance
  claim.
- If and only if preparation passes, the fixed comparison produces a replayable
  result from all observations: twenty actual equivalent successful pairs,
  candidate ordinary median at most 0.8 of repaired-control median, candidate
  nearest-rank p95 no higher than control, and actual runner cost no higher than
  control. If the fixed window or evidence cannot establish those conditions,
  report `insufficient_data` or `miss` honestly.
- CISPEED-01/02 remain open unless the comparison result is `pass` and the
  independent phase verifier passes.
- Phase 255.1 remains preserved as halted/blocked history. Phase 256 is the
  only forward route for this objective; never route back to
  `$gsd-execute-phase 255.1`.

## Evidence carried forward

- Phase 255.1 terminal result: `255.1-10-SUMMARY.md`.
- Recovery diagnosis and route rule: `255.1-RECOVERY-RESET.md` and
  `255.1-LEARNINGS.md`.
- Exact capture-gap diagnosis: `CANDIDATE-FAILURE-DIAGNOSTIC.json` and its
  addendum under `.planning/execution/255.1/protected-delivery-scope/`.
- Prior one-attempt scope (predecessor only):
  `.planning/execution/255.1/diagnostics/next-scope-proposal-20261104/SCOPE-PROPOSAL.md`.
- Dirty route bytes before creating Phase 256 are recoverable at
  `.planning/execution/255.2/write-ahead-preservation/phase256-route-transition-20261104T161058Z/PRESERVATION-REF.json`.
