# Phase 107: Webhook policy operator truth - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Finish `WH-06` by making blocked webhook destination policy truth visible to operators in the existing admin webhook delivery surfaces, then reconcile the remaining Phase 105 verification/validation evidence so the active milestone truth is coherent.

This is a bounded operator-truth and evidence-closeout phase. It does not redesign the webhook contract, retry model, replay semantics, admin information architecture, or generated-host ownership boundary established in earlier phases.

**Explicitly in scope:**
- rendering truthful blocked-policy reason/detail in the shared admin delivery detail page
- rendering enough blocked-policy truth in the failures inbox to distinguish policy denial from generic terminal or transport failures at a glance
- proving the denied-path operator workflow in tests and generated-host/browser evidence
- writing the authoritative Phase 105 verification closeout and reconciling the active Nyquist/validation truth it drives

**Explicitly out of scope:**
- new webhook policy semantics, richer policy DSLs, or new runtime enforcement seams
- replay redesign, retry redesign, or transport contract changes
- dashboard-heavy observability, endpoint-health rollups, or a general incident-management surface
- raw payload/header inspection UI, proof bundles beyond what is needed to close `WH-06`, or broad delivery forensics expansion
- historical planning archaeology beyond the active truth set that Phase 107 directly corrects

</domain>

<decisions>
## Implementation Decisions

### Delivery detail presentation
- **D-107-01 — Keep the shared delivery detail page as the authority surface for policy truth.** Blocked-policy explanation belongs on the existing delivery detail page, not in a new policy tab, modal, or separate workflow.
- **D-107-02 — Add a dedicated conditional policy section, separate from replay and attempt history.** When a delivery is blocked by local webhook policy, render a sibling card or section such as `Endpoint policy result` / `Blocked by local webhook policy` that appears only for `local_policy_error`.
- **D-107-03 — Show both stable reason and operator-readable detail.** The detail surface must expose the canonical reason code already persisted in delivery truth (for example `policy_denied` or `blocked_private_ip`) plus the stored explanatory detail string, so operators can see both the machine-stable outcome and the human explanation.
- **D-107-04 — Do not conflate policy denial with transport or replay state.** The policy section should sit adjacent to the status/replay surfaces, but it must not be merged into replay copy, attempt numbering, or generic terminal-state wording.

### Failures inbox presentation
- **D-107-05 — Keep the failures inbox delivery-row oriented and incident-fast.** Phase 107 should preserve the current summary-row-first failures surface rather than turning it into a subscription dashboard or policy workbench.
- **D-107-06 — Show compact inline policy truth on blocked rows.** When a row represents a local policy denial, the inbox should surface a concise blocked-policy signal plus one-line reason/detail summary directly in the row, not only behind `Open delivery`.
- **D-107-07 — Prefer compact badges and factual copy over new controls.** The row-level treatment should help operators distinguish `blocked by local policy` from retryable receiver failure at a glance without adding policy-specific actions, tabs, or new queue concepts in this phase.
- **D-107-08 — Do not expand scope with new inbox taxonomy unless needed to tell the truth.** Existing retrying/dead-lettered filters remain the base posture; richer blocked/disabled rollups or extra queue states are deferred unless the active implementation absolutely requires a minimal additional distinction.

### Proof surface and verification
- **D-107-09 — Close the gap at the operator surface, not only in read models.** The missing proof is that LiveViews actually render blocked-policy truth; query-layer truth alone is not sufficient for `WH-06`.
- **D-107-10 — Verify both surfaces with focused executable coverage.** Phase 107 should add or extend tests so blocked deliveries explicitly render policy reason/detail in both the shared delivery detail page and the failures inbox/operator path.
- **D-107-11 — Require one generated-host or browser proof of the denied-path workflow.** The proof should demonstrate: a destination is denied by policy, the delivery lands with truthful persisted local-policy failure state, the operator opens the failures/detail surfaces, and the denial reason/detail is visible end to end.
- **D-107-12 — Keep proof bounded to current persisted truth.** Phase 107 should not invent a new raw-payload evidence drawer, new delivery-proof schema, or broader observability artifact just to satisfy this closeout. It should prove the already-implemented policy truth reaches the operator faithfully.

### Reconciliation scope
- **D-107-13 — Reconcile only the active `WH-06` truth set.** Phase 107 should write the missing `105-VERIFICATION.md`, update `105-VALIDATION.md` to reflect the actual current Nyquist/proof state, and adjust any directly active milestone truth that would otherwise contradict the closeout.
- **D-107-14 — Keep closeout honesty explicit.** Planning and verification artifacts should continue to distinguish Phase 105 implementation from Phase 107 operator-truth/evidence closure, rather than implying Phase 105 was always fully closed.
- **D-107-15 — Avoid broad historical normalization.** Archived or non-authoritative files remain untouched unless they still drive current understanding of `WH-06`.

### Product/DX posture
- **D-107-16 — Optimize for least surprise and trustworthy operator language.** UI copy should describe what happened on Sigra’s side in plain terms such as `blocked by local webhook policy`, not vague generic failure language and not claims about downstream business processing.
- **D-107-17 — Keep Sigra narrow and honest.** Phase 107 should strengthen Sigra’s `delivery truth` surface rather than drifting toward a broad webhook observability platform.
- **D-107-18 — Shift routine recommendation-making left within GSD for this product line.** Downstream research, planning, and execution should default to decisive list/detail LiveView patterns, stable operator truth, bounded evidence, and generated-host-thin ownership unless a choice would materially alter the security model, public webhook contract, semver surface, or generated-host contract.

### the agent's Discretion
- Exact heading copy, badge wording, and section placement for blocked-policy truth, provided delivery detail remains the authority surface and row-level failures copy stays compact
- Exact reason-label formatting for stable reason codes, provided the canonical persisted value remains visible or faithfully represented
- Exact test decomposition across admin query tests, LiveView tests, and generated-host/browser proof, provided both operator surfaces are covered
- Exact set of active truth documents touched beyond `105-VERIFICATION.md` and `105-VALIDATION.md`, provided reconciliation stays bounded to files that still drive current `WH-06` understanding

</decisions>

<specifics>
## Specific Ideas

- Recommended UX shape:
  - failures inbox row shows a compact blocked-policy signal plus a one-line reason/detail summary
  - delivery detail page shows a dedicated conditional policy section with reason and detail
  - replay and attempt-history sections remain separate so operators do not confuse transport retry/replay mechanics with local policy denial
- Recommended tone:
  - tell the operator exactly what Sigra blocked and why
  - avoid implying that an HTTP `2xx` or a visible delivery row means the downstream business action completed
  - keep copy short, factual, and actionable
- External lessons carried into these defaults:
  - Stripe and GitHub are strong on detail-page truth and delivery-attempt evidence
  - Svix is strong on explicit retry/security/documentation guidance
  - Hookdeck is strong on positioning around operator trust and recovery, but broader observability/platform ambitions are intentionally out of scope for Sigra in this phase
- Future-direction ideas explicitly deferred:
  - richer blocked/disabled queue filters and endpoint-health rollups
  - raw payload/header proof drawers
  - broader reconciliation APIs, retention windows, or CLI recovery tooling beyond what current milestone proof requires

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active milestone truth
- `.planning/PROJECT.md` — current milestone framing, DX/product-trust posture, and the preference to shift routine decisions left within GSD
- `.planning/ROADMAP.md` — Phase 107 goal, success criteria, and the bounded `WH-06` closeout target
- `.planning/REQUIREMENTS.md` — active `WH-06` requirement and milestone status
- `.planning/STATE.md` — current milestone continuity and phase handoff
- `.planning/v1.23-MILESTONE-AUDIT.md` — exact operator-truth blocker and missing verification/validation artifacts

### Prior webhook decisions that stay locked
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` — list/detail admin idiom, delivery-history posture, and host-boundary guidance
- `.planning/phases/104-failed-delivery-replay-controls/104-CONTEXT.md` — replay/detail/failures authority split and lineage truth that must not be disturbed
- `.planning/phases/106-replay-verification-closeout/106-CONTEXT.md` — bounded closeout and active-truth reconciliation precedent
- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-01-SUMMARY.md` — endpoint policy engine and truthful local denial persistence
- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-02-SUMMARY.md` — admin read-model contract for policy truth and generated-host callback seam
- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-03-SUMMARY.md` — docs/proof scope and current Phase 105 evidence posture
- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md` — current draft Nyquist/verification state to reconcile

### Current code surfaces
- `lib/sigra/admin/webhooks/detail.ex` — delivery detail read model, including normalized policy payload
- `lib/sigra/admin/webhooks/failures.ex` — failures inbox query contract and row-level policy metadata
- `lib/sigra/admin/live/webhook_delivery_show_live.ex` — shared delivery detail LiveView that must become policy-truthful
- `lib/sigra/admin/live/webhook_delivery_failures_live.ex` — failures inbox LiveView that must surface blocked-policy truth compactly
- `test/sigra/admin/webhooks_test.exs` — existing query-layer truth assertions for blocked-policy metadata
- `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` — generated-host delivery-detail behavior and replay/detail idiom

### Existing docs and operator contract
- `guides/flows/webhooks.md` — published webhook delivery contract, local policy failure wording, and operator-facing expectations
- `guides/recipes/deployment.md` — deployment-specific policy and allowlisting guidance
- `guides/recipes/webhook-verification.md` — receiver-verification boundary and blocked-delivery expectations
- `priv/templates/sigra.install/admin/webhook_receiver_setup.md` — generated-host operator/setup guidance that already references blocked-delivery truth

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Admin.Webhooks.Detail.load_delivery!/3` already exposes a normalized `policy` payload with `blocked?`, `reason`, and `detail`, so Phase 107 does not need a new query contract.
- `Sigra.Admin.Webhooks.Failures.list_deliveries/3` already attaches `policy_reason` and `policy_detail` to inbox rows, so the failures gap is presentation, not data access.
- Existing delivery detail and failures LiveViews already provide the routed operator surfaces that should absorb the missing truth without a new navigation model.
- Existing admin query tests already lock persisted blocked-policy truth and can be extended upward into LiveView/operator assertions.

### Established Patterns
- Sigra prefers URL-driven list/detail LiveView flows over dashboard-heavy or modal-heavy admin UX.
- High-trust operator actions and richer truth live on detail pages; lists stay compact and fast to scan.
- Generated hosts own shell/routing/branding seams, while library-owned runtime semantics and persisted truth remain centralized in Sigra.
- Stable machine truth plus short human explanation is preferred over vague human-only copy.

### Integration Points
- Delivery detail LiveView rendering for conditional blocked-policy sections
- Failures inbox row rendering for compact blocked-policy summary treatment
- Focused admin/generator/browser proof that the denied path is visible end to end
- Phase 105 verification/validation artifacts and any directly active milestone-truth files they drive

</code_context>

<deferred>
## Deferred Ideas

- Broader webhook observability or endpoint-health dashboards
- New blocked/disabled queue taxonomies beyond what this phase minimally needs to tell the truth
- Raw payload/header/request/response forensic drawers in the admin UI
- General reconciliation APIs, CLI recovery tooling, or long-window delivery-history repair surfaces
- Policy-contract redesign, richer rule DSLs, or new host/runtime policy seams

</deferred>

---

*Phase: 107-webhook-policy-operator-truth*
*Context gathered: 2026-05-07*
