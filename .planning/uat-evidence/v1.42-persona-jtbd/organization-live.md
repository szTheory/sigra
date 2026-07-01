---
surface: organization-live
ledger_cell: organization-live
rubric_version: "1.0"
disposition: actionable
verdicts:
  platform_admin:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
  support_investigator:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
  org_admin:
    earning_its_place: tighten
    ia_muddy: tighten
    redundant_coherent_surprising: tighten
findings:
  - element: "<p class='sg-section-copy'> empty-state (organization_live.ex:95)"
    lens: org_admin
    question: earning_its_place
    refutation: "The Members section renders bare <p class='sg-section-copy'>No members yet — invite members to populate this organization.</p> (organization_live.ex:95) instead of the canonical <.empty_state> component (components.ex:410). This plain paragraph is visually flat compared to the structured empty_state used on peer surfaces; it does not earn its place as a quality-coherent component for the org-admin lens."
    disposition_action: tighten
  - element: "<p class='sg-section-copy'> no-invite-action empty-state (organization_live.ex:95-96)"
    lens: org_admin
    question: ia_muddy
    refutation: "The 'No members yet' empty-state paragraph (organization_live.ex:95) is a dead-end for the org-admin: it tells them to invite members but provides no invite affordance (no button, no link). The next action is not obvious. The support-investigator sees the same dead-end but from a read-only posture; the org-admin posture expects a path to act."
    disposition_action: tighten
  - element: "<p class='sg-section-copy'> Pending invitations empty-state (organization_live.ex:117)"
    lens: org_admin
    question: redundant_coherent_surprising
    refutation: "The Pending invitations section uses a bare <p class='sg-section-copy'>No pending invitations.</p> (organization_live.ex:117) — the same structural divergence from <.empty_state> as the Members section (organization_live.ex:95). The org-admin would be surprised to see inconsistent empty-state treatment between the two peer sections on the same page, both of which should use the canonical component."
    disposition_action: tighten
  - element: "<.notice> bare 'All clear' copy (organization_live.ex:69)"
    lens: org_admin
    question: earning_its_place
    refutation: "Same finding as index-live: the notice renders bare 'All clear' (organization_live.ex:69) on zero-risk state. For the org-admin triage posture, this positive confirmation adds noise without action affordance. Copy should be tightened to 'No members need review' to parallel the risk branch copy."
    disposition_action: tighten
---

# organization-live: Persona-JTBD Panel Review

**Surface:** Organization Admin Overview (`/admin/organizations/:slug`)
**Ledger cell:** `organization-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/organization_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — multiple `tighten` verdicts from the org-admin lens, all remediable in-place (bare `<p>` → `<.empty_state>` swap; "All clear" copy tighten; no-invite dead-end improved with a note or deferred via waiver).

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

NONE — searched for: elements on the org-scoped overview that are only meaningful to the org-admin and irrelevant to the platform-admin who may arrive here via org pivot from a user-detail page. The task_card grid ("Support members", "Investigate organization events") earns its place for both postures. The Members/Pending invitations tail sections provide scoped context that is useful to the platform-admin reviewing org health. No element fails the earning-its-place test for the platform-admin lens.

### Is the IA muddy?

NONE — searched for: inverted hierarchy between the scope ribbon and task cards; primary action buried below secondary evidence; breadcrumb mismatch. The header + task_card grid compose the front-door archetype correctly; the Members/Invitations tail follows below. `scope_ribbon` is intentionally omitted on Overview pages (organization_live.ex:60 comment: "scope_ribbon intentionally omitted on Overview: topbar sg-scope-pill is sufficient (UI-SPEC L152)") — this is documented as an accepted asymmetry, not an IA failure. No hierarchy violation found.

### Redundant / coherent / least-surprising?

NONE — searched for: same count or status rendered twice within this page; vocabulary drift between this surface and the global overview (`index_live.ex`). The org overview does not replicate the "Total users" stat from the global overview; it shows org-specific member/invitation state. No redundancy or coherence failure found for the platform-admin lens.

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements that are not useful to a support investigator who arrives at the org overview via a user-detail pivot link (e.g., "Open organization-scoped view for Acme"). The task_card grid and member roster provide enough context for the investigator to pivot into org-scoped user search or audit. No element fails the earning-its-place test for the support-investigator lens.

### Is the IA muddy?

NONE — searched for: next-action ambiguity for an investigator who arrives here via pivot from `/admin/users/:id`; competing navigation elements. The "Support members" / "Investigate organization events" task cards provide clear pivots. The Members section gives an immediate member-roster scan. No IA muddiness found.

### Redundant / coherent / least-surprising?

NONE — searched for: information duplicated between the org overview and the user-detail page the investigator came from; vocabulary drift between the org overview and the global audit page. No redundancy or coherence failure found for the support-investigator lens.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

**Finding 1 — bare `<p class="sg-section-copy">` Members empty-state (`organization_live.ex:95`):**

Verdict: `tighten`

The Members section renders a bare `<p class="sg-section-copy">No members yet — invite members to populate this organization.</p>` (organization_live.ex:95) when the member list is empty. The canonical empty-state component `<.empty_state>` (components.ex:410) provides a structured, visually-coherent treatment with title and optional action slot. The plain paragraph does not earn its place as a quality component — it is a structural regression relative to peer surfaces that correctly use `<.empty_state>`.

**Finding 2 — bare "All clear" copy (`organization_live.ex:69`):**

Verdict: `tighten`

The notice renders `All clear` (organization_live.ex:69) on zero-risk state, identical to the global overview finding. For the org-admin triage posture, this is noise without action. Copy should be tightened to "No members need review" to parallel the risk branch at organization_live.ex:67.

### Is the IA muddy?

**Finding — Members empty-state dead-end (`organization_live.ex:95-96`):**

Verdict: `tighten`

The "No members yet — invite members to populate this organization." message (organization_live.ex:95) prompts an action ("invite members") but provides no affordance to take that action. The org-admin posture expects to be able to act. The next step — invite a member — is not obvious from the rendered page. This is an IA hierarchy failure: the instruction is present but the path to fulfil it is absent. Waiver-track note: an in-place invite flow is not part of this phase scope (D-06 forbids net-new surfaces); the remediation is either a link to an existing invite route (if one exists) or a documented waiver that invite-CTA is deferred.

### Redundant / coherent / least-surprising?

**Finding — Pending invitations bare `<p>` empty-state diverges from Members empty-state pattern (`organization_live.ex:117`):**

Verdict: `tighten`

The Pending invitations section uses `<p class="sg-section-copy">No pending invitations.</p>` (organization_live.ex:117) — a second bare paragraph diverging from the `<.empty_state>` component contract. An org-admin who observes inconsistent empty-state treatment between the two peer sections on the same page (Members at :95, Invitations at :117) would be surprised. Both sections should use the canonical component for coherent cross-surface treatment.
