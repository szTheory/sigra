# Phase 106: Replay verification closeout - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn Phase 104's already-produced replay commands and proof bundle into authoritative verification for `WH-05`, then reconcile only the active planning truth that would otherwise remain inconsistent with that closeout.

This phase is a verification/documentation closeout phase, not a new webhook product phase. It does not redesign replay behavior, regenerate the replay feature from scratch, broaden webhook scope, or normalize unrelated historical milestone artifacts.

</domain>

<decisions>
## Implementation Decisions

### Closeout scope
- **D-106-01 — Phase 106 is a bounded verification closeout, not a broad planning-cleanup phase.** The main deliverable is `104-VERIFICATION.md`, written from the authoritative Phase 104 command history and replay proof bundle.
- **D-106-02 — Reconcile only the active truth set if it contradicts the new verification.** After `104-VERIFICATION.md` lands, update only the current planning surfaces that make present-tense claims about `WH-05`, such as `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and directly relevant current audit notes.
- **D-106-03 — Do not use Phase 106 for broad historical normalization.** Archived or non-authoritative artifacts should be left alone unless they still directly drive current milestone understanding.

### Authoritative truth policy
- **D-106-04 — `104-VERIFICATION.md` becomes the authoritative closeout artifact for `WH-05`.** Summary files and proof bundles remain important evidence inputs, but they are not sufficient on their own once the audit explicitly requires per-phase verification.
- **D-106-05 — Preserve implementation-vs-closeout honesty.** Planning artifacts should continue to make clear that `WH-05` was implemented in Phase 104 and verified/closed out in Phase 106.
- **D-106-06 — Keep the active truth set coherent after closeout.** `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and any live milestone audit note should not disagree about the present status of `WH-05`.

### Evidence freshness
- **D-106-07 — Default to lightweight refresh, not blind attestation and not automatic full rerun.** Phase 106 should verify the existing replay proof bundle and rerun a narrow CI-shaped smoke subset against current HEAD before writing `104-VERIFICATION.md`.
- **D-106-08 — Treat the 2026-05-07 replay proof bundle as immutable historical evidence.** Verify the presence and coherence of `.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md`, `manifest.json`, and referenced screenshots instead of regenerating the bundle by default.
- **D-106-09 — Escalate to a full rerun only when the evidence may have gone stale.** If replay-relevant code, docs, templates, or proof inputs changed after the recorded proof run on 2026-05-07, or if artifact integrity cannot be confirmed, rerun the full replay verification lane before filing `104-VERIFICATION.md`.

### User preference carried forward
- **D-106-10 — Shift routine closeout decisions left within GSD by default.** Downstream planning should treat bounded reconciliation, lightweight refresh, and authoritative-verification-first as locked defaults unless a major contract, security, semver, or generated-host boundary would change.

### the agent's Discretion
- Exact command subset for the lightweight refresh, as long as it includes one current-head compile signal, one replay-focused smoke lane, and explicit proof-bundle integrity checks.
- Exact wording for superseding or clarifying any live milestone-audit note, provided it does not imply `WH-06` is complete.
- Exact formatting of `104-VERIFICATION.md`, provided it clearly separates historical proof evidence from any fresh closeout confirmation run during Phase 106.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone truth
- `.planning/PROJECT.md` — current milestone framing, shipped webhook status, and the already-complete `WH-05` claim that must stay coherent with active planning truth
- `.planning/ROADMAP.md` — Phase 106 goal, success criteria, and explicit requirement that `104-VERIFICATION.md` become authoritative
- `.planning/REQUIREMENTS.md` — current `WH-05` traceability state and requirement-level completion language
- `.planning/STATE.md` — current session continuity note, which presently still points at Phase 105 as next work
- `.planning/v1.23-MILESTONE-AUDIT.md` — the exact audit blocker and the distinction between implemented replay behavior and missing authoritative verification

### Replay implementation and evidence inputs
- `.planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md` — locked replay behavior and proof expectations from the implementation phase
- `.planning/phases/104-failed-delivery-replay-controls/104-04-SUMMARY.md` — recorded green commands and proof-bundle publication for the final replay plan
- `.planning/phases/104-failed-delivery-replay-controls/104-VALIDATION.md` — replay validation contract and focused test lanes
- `.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md` — human-readable replay proof bundle with lineage and receiver-verification details
- `.planning/uat-evidence/v1.23/webhook-delivery-replay/manifest.json` — machine-readable replay proof bundle keyed by source/replay/root delivery IDs

### Prior closeout policy and precedent
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-CONTEXT.md` — moderate reconciliation strictness and active-truth-set precedent
- `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-03-SUMMARY.md` — example of bounded reconciliation after webhook proof repair
- `.planning/phases/26-retroactive-v1-1-verification-closeout/26-CONTEXT.md` — broader retroactive closeout precedent that should NOT be repeated here unless current truth depends on it
- `.planning/phases/98-reliable-delivery-pipeline/98-VERIFICATION.md` — repaired-form verification precedent for citing durable evidence plus concrete commands
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md` — verification precedent for generated-host proof backed by durable artifacts

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `104-04-SUMMARY.md`: already contains the authoritative command list and evidence references needed to seed `104-VERIFICATION.md`.
- `.planning/uat-evidence/v1.23/webhook-delivery-replay/`: already contains the durable replay proof bundle that Phase 106 should verify and cite, not replace by default.
- Existing verification patterns in `98-VERIFICATION.md` and `99-VERIFICATION.md`: provide the idiomatic file shape for repaired-form, evidence-backed closeout in this repo.

### Established Patterns
- Sigra treats `VERIFICATION.md` as the authoritative requirement-closeout artifact when milestone audits evaluate phase truth.
- Phase 102 established that the active truth set should be reconciled without turning every closeout into historical archaeology.
- Generated-host/browser proof is valid as durable evidence, but current-head verification should still cite concrete executable commands.

### Integration Points
- Create `.planning/phases/104-failed-delivery-replay-controls/104-VERIFICATION.md`.
- Reconcile active planning truth in `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, and only directly relevant current milestone notes if they contradict the new verification.
- Use the replay evidence bundle and any lightweight refresh results to support `WH-05` without implying `WH-06` is complete.

</code_context>

<specifics>
## Specific Ideas

- The coherent Phase 106 story should read as:
  - replay behavior was built and proven in Phase 104
  - the durable replay proof bundle was recorded on 2026-05-07
  - Phase 106 converts that recorded evidence into authoritative verification
  - active planning truth is reconciled immediately after that verification lands
- Freshness policy should be explicit:
  - verify historical proof bundle integrity
  - rerun a narrow CI-shaped smoke subset on current HEAD
  - escalate to full replay rerun only if replay-relevant files changed after 2026-05-07 or artifact integrity fails
- Maintain least surprise for maintainers:
  - no summary-only closeout
  - no broad archive cleanup
  - no accidental claim that v1.23 is finished while `WH-06` remains open

</specifics>

<deferred>
## Deferred Ideas

- Broad historical normalization of archived milestone artifacts
- Full replay proof regeneration on every closeout by default
- Combining Phase 106 replay closeout with unrelated Phase 105 or Phase 107 planning hygiene

</deferred>

---

*Phase: 106-replay-verification-closeout*
*Context gathered: 2026-05-07*
