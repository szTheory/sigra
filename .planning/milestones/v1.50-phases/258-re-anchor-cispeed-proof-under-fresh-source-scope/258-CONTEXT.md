# Phase 258: Re-anchor CISPEED proof under a fresh source scope — Context

**Gathered:** 2026-11-06  
**Status:** Ready for execution

<domain>
## Phase Boundary

Keep Phase257 as terminal history. Reuse its Phase256 candidate/control source pair only after the production reader proves the exact source identities and treatment. Build Phase258-specific production proposal, authorization, one-shot claim, bounded runner, and independent verification paths. No hosted action occurs before one explicit approval of the complete exact proposal.

</domain>

<decisions>
## Implementation Decisions

- **D-01 — Phase257 stays immutable and terminal.** Do not rerun Plan09, its finalizer, old authorization, or consumed claim. Preserve the missing helper SHA as unavailable.
- **D-02 — Unknown workload remains unknown.** Phase256 records 11 requests and zero workloads. Phase257 records one successful `/rate_limit` GET, zero mutations and runner minutes, but `OUTER-PROCESS.spent.workloads` is null. Reserve up to one prior workload and 280 runner minutes in new-scope arithmetic.
- **D-03 — Reuse the exact source pair where proven.** Phase256's control `37f1b551…` and candidate `5effabe7…` remain in the retained clean object store. The production source reader replays `SOURCE-CHECK.json` successfully and verifies the approved treatment. A new Phase258 receipt binds these exact sources to the current controller hash; it does not claim the old `b9f9…` helper bytes were recovered.
- **D-04 — Preserve experiment semantics.** Keep the approved 20 pairs / 40 families, source treatment, seed, ordering, cost accounting, statistical method, and thresholds. CISPEED-01/02 stay open through preparation and planning.
- **D-05 — Count every predecessor request.** The source-bound chain is 12 GETs; read-only forensics add 143, totaling 155. A fresh 503-request preparation scope plus the fixed 24,000-request comparison yields 24,658 lifetime requests, 144 above the former 24,514 cap. The unknown previous workload plus a new maximum 42 workloads yields a possible lifetime maximum of 43, one above the former cap.
- **D-06 — Exact approval follows a concrete proposal.** Phase258's local proposal must present source hashes, complete spend, fixed windows, all ceilings and the increase. It creates no claim or authorization. Only explicit approval of those exact bytes allows Plan258-03 to issue the authorization and start the single invocation.
- **D-07 — No per-command approval inside the approved scope.** Once the exact proposal is approved, execute its bounded local checks and approved CI automatically. Keep the recorded hard timeout, caps, zero retries/reruns/renewals and no-merge/no-release boundary.
- **D-08 — Fix the timestamp defect permanently.** The valid first request intent may be after its persisted reservation but must remain before the fixed deadline. Reject a backwards clock before ledger or transport activity. The focused production regression passes.

### the agent's Discretion

- Use the smallest Phase258-specific production adapter that can independently verify the source pair, predecessor accounting, exact approval, and one-use claim.
- Preserve write-ahead planning bytes before route or plan edits, then refresh all active route copies from live `phase-plan-index.ready_plans`.
- Stop before I/O if any source hash, predecessor record, deadline, or finite cap cannot be proven.

</decisions>

<specifics>
The original halt was caused by a 769-microsecond gap between the persisted request reservation and its first GET intent. The production validator now accepts reservation ≤ intent < fixed deadline. The separate unresolved fact is that the controller file bound to the old consumed attempt is unavailable; its old one-shot scope cannot be replayed.
</specifics>

<canonical_refs>
## Canonical References

### Project rules

- `AGENTS.md` — write-ahead preservation, bounded CI, no retries/renewals, user approval boundary, and route rules.
- `.planning/REQUIREMENTS.md` — CISPEED-01/02 result definitions.
- `.planning/phases/258-re-anchor-cispeed-proof-under-fresh-source-scope/258-SCOPE.md` — source, limits, and phase boundary.

### Predecessor evidence

- `.planning/execution/256/source-recovery-01/SOURCE-CHECK.json` and `.planning/execution/256/objects.git/` — exact reusable pair and source closure.
- `.planning/execution/257/local-recovery-18/COUNTER-RECONCILIATION.json` — 155 transport GETs total.
- `.planning/execution/257/generations/02/PREDECESSOR-RECONCILIATION.json` — production result; 12 source-bound requests, workload unknown.
- `.planning/execution/257/preparation/OUTER-PROCESS.json` — single GET, zero mutations, zero runner minutes, workload null.
- `.planning/debug/phase257-local/CLOCK-ANCHOR-MAINTENANCE-20261105.json` — validator repair and focused regression evidence.

</canonical_refs>
