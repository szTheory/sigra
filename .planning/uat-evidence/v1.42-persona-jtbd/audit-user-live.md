---
surface: audit-user-live
ledger_cell: audit-user-live
rubric_version: "1.0"
disposition: actionable
verdicts:
  platform_admin:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: tighten
  support_investigator:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: tighten
  org_admin:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
findings:
  - element: "<.applied_chip> cluster outside <form> (audit_user_live.ex:163-172)"
    lens: platform_admin
    question: redundant_coherent_surprising
    refutation: "Applied filter chips on audit-user-live render OUTSIDE the filter form (audit_user_live.ex:163-172, after form closes at :161). On users-index-live.ex:107-114, chips render INSIDE the GET form. This cross-page asymmetry in chip placement violates the 'same job → same component' principle and would surprise an operator who has used both the users-index and per-user-audit pages."
    disposition_action: tighten
    resolution: "WAIVER (Phase 209-05 Task 1) — Post-form chip position is the DEFINED Audit Explorer Archetype pattern per admin-design-contract.md (Audit Explorer Archetype, position [3]: 'Navigation-only <a> tags, post-form'). The applied_chip component contract itself cites 'audit_user_live.ex applied-chip cluster (post-form, contiguous with filter panel — see Audit Explorer Archetype for elevated composition)'. The List Archetype uses chips-inside-form; the Audit Explorer Archetype uses chips post-form. These are different archetypes with different intentional composition rules. No DOM change — this is the defined per-archetype pattern."
  - element: "Absent 'Effective user' filter field (not present in audit_user_live.ex filter form)"
    lens: support_investigator
    question: redundant_coherent_surprising
    refutation: "The global audit explorer (audit_index_live.ex:91-93) includes an 'Effective user' filter field in its More-filters disclosure. The per-user audit page (audit_user_live.ex) does NOT include this field. For a support investigator who uses both pages, the absence of 'Effective user' on the per-user audit is asymmetric. HOWEVER: this asymmetry is DEFENSIBLE — the per-user audit is already subject-scoped to a specific user, so filtering by 'effective_user' within that scope is redundant (you are already on that user's page). This is a documented intentional asymmetry → waiver-track, NOT a kill or unresolved tighten."
    disposition_action: tighten
    resolution: "WAIVER (Phase 209-05 Task 1) — Defensible intentional asymmetry per admin-design-contract.md D-09: 'Index @chip_keys is 6-key (incl. actor/effective_user); per-user is 5-key (excl. effective_user). Per-user has breadcrumbs, display_name identity header, return_to plumbing ... Index has scope ribbon and Effective-user filter field. These differences stay per-page.' The per-user audit page is subject-scoped at the route level (/admin/users/:id/audit); the effective_user field is redundant because the page subject IS the effective user. No code change needed — this asymmetry is documented as legitimate per-page divergence (D-09)."
---

# audit-user-live: Persona-JTBD Panel Review

**Surface:** Per-User Admin Audit Explorer (`/admin/users/:id/audit`)
**Ledger cell:** `audit-user-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/audit_user_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — two findings:
1. Chips-outside-form asymmetry (`tighten`) — remediable in-place.
2. "Effective user" absent — **waiver-track** (documented defensible asymmetry per D-05/D-07): per-user audit is already subject-scoped; filtering by effective_user is redundant in that context. Recorded as a `tighten` verdict to acknowledge the asymmetry, but resolved via written waiver rather than a code fix.

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

NONE — searched for: elements on the per-user audit page that do not earn their place for a platform admin who has navigated here via the user-detail "View full audit" link. The filter form with Failures/Impersonation quick chips earns its place. The "Export CSV" link earns its place as evidence export. The breadcrumbs (audit_user_live.ex:258-269) earn their place as scope navigation. No element fails earning-its-place for the platform-admin lens.

### Is the IA muddy?

NONE — searched for: scope confusion between the per-user audit and the global audit; inverted hierarchy between filter form and results. The scope_ribbon renders before the header (audit_user_live.ex:67), consistent with user_show_live.ex:44. The H1 is the user's identity name (audit_user_live.ex:71) — consistent with sibling pattern and distinct from the audit-index H1 ("Audit"). The filter form precedes the results — correct hierarchy. No IA muddiness found.

### Redundant / coherent / least-surprising?

**Finding — `<.applied_chip>` cluster outside `<form>` (`audit_user_live.ex:163-172`):**

Verdict: `tighten`

Applied filter chips on audit-user-live render in a standalone `<div class="sg-cluster sg-cluster--start">` at lines 163-172, outside the filter `<form>` (form ends at :161). This is the same structural asymmetry as audit-index-live (chips outside form), but now comparing against users-index-live where chips are inside the form. A platform admin who uses users-index and per-user-audit sees the same chip UI placed differently relative to the form boundary on each page. Remediation: move the applied-chip cluster inside the form (consistent with users-index pattern).

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements on the per-user audit page that are extraneous to the support-investigator posture. The "Failures" and "Impersonation" quick chips serve the investigator's most common event-type filters. The "Actor" filter (audit_user_live.ex:133-136) earns its place — the investigator may want to distinguish which admin actor performed actions on this user. The "Export CSV" link earns its place for evidence preservation. No element fails earning-its-place for the support-investigator lens.

### Is the IA muddy?

NONE — searched for: next-action ambiguity for a support investigator reviewing a specific user's audit trail; primary filter fields buried. The quick-filter chips are immediately visible. The `<details>` disclosure (audit_user_live.ex:105) correctly gates verbose filters. The breadcrumbs provide clear return navigation. No IA muddiness found.

### Redundant / coherent / least-surprising?

**Finding — "Effective user" filter absent from per-user audit vs present on global audit (`audit_index_live.ex:91-93`):**

Verdict: `tighten` (waiver-track)

The global audit explorer includes an "Effective user" filter field (audit_index_live.ex:91-93: `<span class="sg-field-label">Effective user</span>`). The per-user audit page (audit_user_live.ex) does not include this field — the `@chip_keys` list at audit_user_live.ex:383 is `~w(actor action_prefix outcome from to)` (no `effective_user`). A support investigator who uses both pages may notice this asymmetry.

**Waiver rationale (D-05/D-07):** The per-user audit page is already subject-scoped to a specific user (`/admin/users/:id/audit` — events are pre-filtered to this user's context). Adding an "Effective user" filter within that scope would be redundant: the effective user is already the page's subject. The absence is a **documented intentional asymmetry** — the per-user audit is subject-scoped at the route level, not the filter level. This finding is resolved via written waiver, not a code fix.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements on the org-scoped per-user audit page that are extraneous for an org-admin. The scope_ribbon anchors the org context. The filter form and results are org-scoped at the data layer. No element fails earning-its-place for the org-admin lens.

### Is the IA muddy?

NONE — searched for: scope confusion for an org-admin reviewing a member's audit trail; breadcrumb mismatch. The breadcrumbs use org-scoped paths (audit_user_live.ex:258-269 via `overview_path/1` and `user_detail_path/3` which resolve org-scoped paths). No IA muddiness found for org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary or layout divergence between the org-scoped per-user audit and the global per-user audit; elements that reference platform-admin concepts. Both variants share identical markup; scope_copy and paths differ only. The "Actor" filter is relevant to org-admin who may want to distinguish support-admin actions from user self-actions. No redundancy or coherence failure found for org-admin lens.
