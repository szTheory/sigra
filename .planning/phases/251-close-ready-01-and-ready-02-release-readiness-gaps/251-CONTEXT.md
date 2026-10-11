# Phase 251: Close READY-01 and READY-02 Release Readiness Gaps - Context

**Gathered:** 2026-10-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Refresh and reconcile the evidence for the two still-unsatisfied Phase 247 release-readiness requirements. READY-01 may pass only if one exact candidate/source/base/main tuple is joined to its matching CI, readiness, dry-run, and contemporaneous approval record. READY-02 may pass only if a fresh inventory accounts for every open PR and inherited checkout change, with a recorded disposition and recoverable preservation identity for each applicable item. If the required historical approval cannot be recovered, or either evidence join remains incomplete, record the gap and leave that owner requirement unsatisfied. Keep READY-01/02 owned by Phase 247 and keep v1.49 incomplete unless the canonical owner verification proves both requirements.

This is an evidence-refresh and verification phase. Use read-only source/API observations and deterministic checks; do not dispatch a workflow, merge a PR, publish a package, create a release, or change a release candidate. Do not treat the Phase 250 accepted exceptions as milestone acceptance. The longer-term CI/CD reliability and performance work remains a separate follow-up after v1.49.
</domain>

<decisions>
## Implementation Decisions

### READY-01 exact evidence and approval
- **D-01:** Evaluate READY-01 against a single complete candidate tuple: candidate SHA, reviewed base SHA, protected-main SHA, exact-source CI result, readiness record, and authenticated non-publishing dry-run. Bind every item to the same source identity; do not combine records from different candidate tuples. Evidence: `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json`, `247-10-REBIND-PROPOSAL.json`, and `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json` and `250-247-TUPLE-DECISION-PACKET.json` show mismatched identities and no eligible tuple. If this assumption is wrong, a mixed evidence set could falsely mark the 1.6.0 candidate ready.
- **D-02:** Preserve the original approval bar. Only a contemporaneous approval that names or cryptographically binds the exact candidate/source/CI/readiness/dry-run record can satisfy READY-01. The user confirmed this rule for Phase 251. A broad authorization, later approval, or this Phase 251 scope approval cannot be substituted for missing historical candidate approval. If the exact approval cannot be recovered, record `authorization_pending` and leave READY-01 unsatisfied. Evidence: `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json` and `250-247-TUPLE-DECISION-PACKET.json`; the existing reconciliation reports no eligible candidate. If this assumption is wrong, the phase would change the milestone's public readiness/truth contract.

### READY-02 current inventory and preservation
- **D-03:** Refresh the open-PR and inherited-work populations at evidence capture time. Give every observed item one explicit release-blocking, release-relevant, or separate-follow-up disposition. For inherited work, retain a recoverable preservation identity and record where it can be read back. Do not use an old inventory as proof of current completeness. Evidence: `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md`, `247-VALIDATION.md`, and the READY-02 blockers in `250-247-RECONCILIATION.json` report that fresh PR dispositions and preservation joins are missing. If this assumption is wrong, current work could be lost or silently included in release work.
- **D-04:** Keep original ownership and verdicts authoritative: Phase 247 owns READY-01/02. Phase 251 may refresh the owner evidence and verifier, but must not claim the requirements as newly implemented, mark unchecked requirements satisfied without their full acceptance evidence, or use Phase 250's phase-only exception as a pass. If proof remains unavailable, preserve `gaps_found` and the incomplete milestone status.

### Verification and scope
- **D-05:** Prefer read-only live inventory, exact-source artifact checks, and deterministic tests over manual UAT. Record capture time, exact identities, source paths, and hashes for evidence; label historical snapshots as historical. No new workflow dispatch, merge, publish, release, or candidate mutation is in scope, as confirmed by the user.
- **D-06:** Keep CI/CD timeout, reliability, and release-lane follow-up ideas outside Phase 251. The user's earlier instruction places that optimization work after the current milestone. Phase 251 only determines whether READY-01/02 can be proven from the required evidence.

### the agent's Discretion
- Choose the smallest deterministic verifier and evidence-ledger updates that preserve Phase 247 ownership and existing schemas.
- Refresh external read-only observations when planning/execution needs current facts; do not transplant live values into historical source records.
- If evidence is absent or a live read is unavailable, record the precise blocker and stop the affected requirement at unsatisfied.

### Folded Todos
None. The matching release-lane CI/CD items remain separate follow-up work per the user's prior instruction.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirement contract
- `.planning/ROADMAP.md` — v1.49 goal, Phase 247 ownership, Phase 250 closeout, and Phase 251 placement.
- `.planning/REQUIREMENTS.md` — exact READY-01/02 acceptance and original ownership.
- `.planning/PROJECT.md` — verification defaults, milestone goal, and no repeated approvals for already-authorized in-scope work.
- `.planning/METHODOLOGY.md` — automation-first verification, immutable source identity, decisive defaults, and write-ahead preservation.
- `.planning/VERIFICATION-POLICY.md` — deterministic evidence and exact-SHA requirements.
- `.planning/STATE.md` — current route and unresolved milestone state; refresh before execution.
- `.planning/v1.49-MILESTONE-AUDIT.md` — current 7/9 milestone verdict, Phase 250-only exception boundary, validation classifications, and next route.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-CONTEXT.md` — original readiness decisions and Phase 247 boundary.
- `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CONTEXT.md` — source-identity, owner, and fail-closed verification decisions.

### READY-01 source evidence
- `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` — saved readiness tuple.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-10-REBIND-PROPOSAL.json` — later proposed source tuple; do not treat as approval.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json` and `247-CANDIDATE-DIFF-BASELINE.json` — exact dry-run and diff baseline records.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md` and `247-VALIDATION.md` — canonical owner verdict and test/coverage record.
- `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json` and `250-247-TUPLE-DECISION-PACKET.json` — source-bound mismatch details and current eligibility result.

### READY-02 inventory, preservation, and current audit
- `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md`, plan summaries, and preservation records — original inventory and owner gaps.
- `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-PRESERVATION.json` and `249-12-SUMMARY.md` — examples of recoverable preservation identities and completed disposition formats; do not copy their historical inventory as current.
- `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-13-CLOSEOUT-AUDIT.md` — the phase-only exception record.
- `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs` and `verify-v149-traceability.test.mjs` — source-derived fail-closed milestone checks and regression tests.

No product UI, application API, or visual-design contract applies to this evidence phase.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 247's readiness ledger, reconciliation, tuple packet, owner verifier, and validation map already expose exact evidence identities and structured blockers; refresh and extend these narrowly instead of creating a parallel source of truth.
- Phase 250's source-derived audit checker recomputes owner and milestone status, binds accepted exceptions to their amendment, and now discovers current validation files dynamically. Keep its Phase 250 exception semantics separate from Phase 251 owner acceptance.
- Phase 249's preservation ledger and closeout validator provide examples for recoverable preservation refs, current inventory records, and exact disposition joins.

### Established Patterns
- Bind evidence to full SHAs, workflow/run/attempt IDs, timestamps, source paths, and artifact digests. A newer markdown value cannot approve or rebind an older tuple.
- Fail closed on missing approval, incomplete inventory, unreadable preservation refs, or mismatched source identity. Do not convert an absent record into a pass.
- Preserve the previous bytes and exact path/status before rewriting dirty `.planning/` records; verify read-back before updating state, handoff, or audit files.
- Mark requirement completion only from the original owner verifier's complete acceptance evidence; Phase 250's exception is phase-only.

### Integration Points
- Phase 251 evidence updates feed the Phase 247 owner verification for READY-01/02, then `.planning/REQUIREMENTS.md` and `.planning/v1.49-MILESTONE-AUDIT.md` only if the canonical owner verdict changes.
- Phase 248 AUTO and Phase 249 REL reports remain independently satisfied and unchanged by this phase.
- The current next route is Phase 251 planning after this context is committed; CI/CD optimization remains after v1.49.
</code_context>

<specifics>
## Specific Ideas

- Treat the exact READY-01 approval as a historic record to recover, never as a new approval to request or infer. The user's current answers define Phase 251's acceptance rule; they do not approve a candidate, merge, or release.
- For READY-02, make the inventory complete and reviewable before calling anything dispositioned; bind each preservation reference to bytes that can actually be read back.
- If either requirement cannot meet its original evidence bar, state what is missing in plain terms and keep the requirement unsatisfied.
</specifics>

<deferred>
## Deferred Ideas

- CI/CD timeout, reliability, and release-lane optimization after v1.49, as requested by the user.
- Any broad release workflow redesign, new canary, package publish, release, merge, or product change.

### Reviewed Todos (not folded)
- `.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` and `.planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` — release-lane CI/CD improvements are deferred beyond this milestone per the user's instruction.
- Other broad keyword matches from `todo.match-phase 251` are unrelated or historical and were not folded into this evidence-only phase.
</deferred>
