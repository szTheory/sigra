# Phase 236: Closeout Evidence Reconciliation - Context

**Gathered:** 2026-08-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the v1.47 CI-EFFICIENCY milestone's remaining *evidence bookkeeping* gaps: reconcile requirement-completion metadata and stale traceability records, bring the four completed phases into the repository's authoritative Nyquist lifecycle, then re-run the milestone audit. This phase relies on the already-passing runtime, integration, flow, and terminal-evidence results from Phases 230–235. It must not change CI topology, product behavior, required-check policy, or manufacture new run evidence.
</domain>

<decisions>
## Implementation Decisions

### Audit-gap reconciliation
- **D-01:** Repair only the four missing SUMMARY completion declarations identified by the v1.47 audit: `GATE-01`, `GATE-04`, `TEST-02`, and `TEST-03`. Add each ID to the appropriate existing phase SUMMARY frontmatter; do not rewrite historical execution narratives or treat the metadata repair as a new runtime proof claim.
- **D-02:** Reconcile `REQUIREMENTS.md` traceability statuses for `TEST-01..03` and `DX-01..04/DX-06` against their checked requirement rows, completed phase verifications, and existing deterministic contracts. Completion must remain supported by all audit sources; a checkbox alone is never sufficient.

### Validation lifecycle
- **D-03:** Run the established deterministic Nyquist validation workflow for Phases 230, 231, 232, and 234 and update their existing validation artifacts to the workflow's canonical `validated` lifecycle state only when the automated validation evidence passes. Do not create substitute approval prose or waive a failed validation.
- **D-04:** Preserve Phase 233 and Phase 235 as already Nyquist-compliant. Preserve all completed Phase 230–235 verification artifacts and protected receipts byte-for-byte except where a validator's canonical lifecycle update explicitly requires an artifact change.

### Honest terminal closeout
- **D-05:** Re-run the v1.47 milestone audit after reconciliation. Mark the milestone ready to close only if the audit reports all requirements satisfied and the Nyquist classification is compliant; otherwise retain the audit's exact remaining diagnostics and stop rather than relabeling them passed.
- **D-06:** Keep operational/debt items separate from the evidence-closeout gate: Phase 231 Pages-source repository administration, Phase 232 edge-semantics assumptions, Phase 233 `Code.require_file/1` warnings, and Phase 235's non-authoritative historical verifier are recorded debt, not acceptance blockers unless the renewed audit proves otherwise.

### the agent's Discretion
- Choose the smallest set of existing SUMMARY files that truthfully provides each missing requirement declaration, following the repository's current frontmatter shape.
- Choose the validation and audit command order, provided evidence is deterministic, phase-scoped, and the final milestone audit is fresh.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and audit authority
- `.planning/ROADMAP.md` — Phase 236 registration and its dependency on Phase 235.
- `.planning/v1.47-v1.47-MILESTONE-AUDIT.md` — authoritative gap list, three-source completion rule, Nyquist classifications, and closure path.
- `.planning/REQUIREMENTS.md` — checked requirement statements and the stale traceability rows to reconcile.
- `.planning/METHODOLOGY.md` — decisive defaulting and truth-claim escalation rules.

### Completed evidence to preserve
- `.planning/phases/230-tier-1-critical-path-reclamation/230-VERIFICATION.md` — verified FAST-02..FAST-07 evidence.
- `.planning/phases/231-gate-honesty-nightly-revival/231-VERIFICATION.md` — verified GATE-01/GATE-04 evidence that is missing only summary metadata.
- `.planning/phases/233-library-suite-economics/233-VERIFICATION.md` — verified TEST-02/TEST-03 evidence that is missing only summary metadata.
- `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VERIFICATION.md` and `234-VALIDATION.md` — DX evidence and the existing noncanonical validation state.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-VERIFICATION.md` — terminal FAST-01/GATE-05 evidence; no remeasurement is in scope.

### Workflow state
- `.planning/STATE.md` — active milestone state and resume metadata.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/v1.47-v1.47-MILESTONE-AUDIT.md` already provides a machine-checkable, requirement-by-requirement reconciliation target: exactly four missing SUMMARY declarations and stale traceability rows.
- Existing phase SUMMARY frontmatter uses `requirements-completed: [...]`; Phase 233 Plan 01 is the in-repository established shape.
- Existing `*-VALIDATION.md` artifacts and the `$gsd-validate-phase` workflow are the canonical Nyquist lifecycle seam; no new validation framework is needed.

### Established Patterns
- Runtime claims are closed by named CI receipts and deterministic contracts, not by source inspection or status prose.
- Metadata reconciliation must retain historical evidence rather than normalize it away; Phase 235 keeps prior FAST-01 misses alongside the authoritative protected pass.
- A milestone audit distinguishes documented technical debt from a requirement or integration failure.

### Integration Points
- Existing Phase 231 and Phase 233 SUMMARY frontmatter feeds the audit's three-source requirement check.
- `REQUIREMENTS.md`, per-phase VERIFICATION/VALIDATION artifacts, and the milestone audit must agree for v1.47 closure.
</code_context>

<specifics>
## Specific Ideas

- User delegated implementation choices and approved the narrow reconciliation recommendation: stay focused on closeout evidence rather than adjacent CI repairs.
- The audited product/CI outcome is already strong: Phase 235 retains a protected 15-run FAST-01 population with a 486-second p50 and a 93-row GATE-05 ownership ledger. Phase 236 must cite, not replace, that proof.
</specifics>

<deferred>
## Deferred Ideas

- `.planning/todos/pending/2026-08-01-phase-234-github-evidence-residual.md` and `.planning/todos/pending/2026-08-01-phase-234-pr-evidence-blocked.md` — resolved Phase 234 diagnostic history, not Phase 236 implementation scope.
- `2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — a required-check/DAG policy change explicitly deferred by Phase 231.
- `2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` — one-off network reliability work; no retry policy is introduced in this closeout phase.
- The Phase 231, 232, 233, and 235 tech-debt items named in the milestone audit remain separately tracked unless the renewed audit changes their status.
</deferred>

---

*Phase: 236-closeout-evidence-reconciliation*
*Context gathered: 2026-08-04*
