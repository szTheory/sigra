---
surface: users-index-live
ledger_cell: users-index-live
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
    redundant_coherent_surprising: keep
  org_admin:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
findings:
  - element: "<.summary_chip id='users-metric-total' label='Total users'> (users_index_live.ex:185-191)"
    lens: platform_admin
    question: redundant_coherent_surprising
    refutation: "The User health strip on users-index-live shows 'Total users' (users_index_live.ex:185-191) — the same metric with the same label already shown on index-live.ex:85-91 'User snapshot' strip. A platform admin arriving at /admin/users from the global overview has just seen this count. Repeating it on the list page is not surprising per se, but the duplication is redundant given the investigator/triage workflow."
    disposition_action: tighten
---

# users-index-live: Persona-JTBD Panel Review

**Surface:** Admin Users Index (`/admin/users`)
**Ledger cell:** `users-index-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/users_index_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — one `tighten` verdict (Total-users duplication cross-page), remediable in-place or by documented waiver (if keeping the Users Health strip metric is intentional for the list-page posture).

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

NONE — searched for: elements present on the users-index page that do not earn their place for the platform-admin who arrives here from the global overview task card "Find a user". The search/filter form earns its place as the primary action. The applied-chips pattern inside the GET form (users_index_live.ex:107-114) is a CANONICAL design decision (documented in Phase 201) — chips inside the form means they participate in GET submission and can be cleared individually via remove_href links; this is correct and earns its place. The quick-filter chips inside the form (users_index_live.ex:116-118) are similarly canonical and intentional. The User health stat strip (users_index_live.ex:182-213) earns its place for health-monitoring, though see Q3 for redundancy.

### Is the IA muddy?

NONE — searched for: inverted hierarchy between the search/filter panel and the results list; primary action buried below secondary evidence; scope_ribbon placement above/below header. The scope_ribbon renders correctly after the header (users_index_live.ex:83) and before the search form — this is the canonical position on list pages. The search/filter form is correctly the first-after-ribbon section. The "User health" stat strip is below the results list — this is the correct secondary position. No IA hierarchy violation found.

### Redundant / coherent / least-surprising?

**Finding — "Total users" stat duplicated cross-page with index-live (`users_index_live.ex:185-191`):**

Verdict: `tighten`

The User health strip shows `<.summary_chip label="Total users">` (users_index_live.ex:185-191) with the same value as the Global Overview's "User snapshot" strip (index_live.ex:85-91). A platform admin who navigates from `/admin` to `/admin/users` has just seen this count. The per-page utility of a "Total users" count on the list page is marginal — it does not help the user scan or filter. The "Locked users" and "Deletion scheduled" chips on the same strip are differentiated and do earn their place as health indicators.

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements on the users index that do not earn their place for a support investigator arriving here to find a specific user. The search box (text input for email/id/name) is the primary tool for this lens — it earns its place immediately. The quick-filter chips (confirmed, mfa, passkeys, locked, deleted, needs_review) earn their place as scoped investigation pivots. The "More filters" disclosure (users_index_live.ex:121-128) is correctly secondary behind a `phx-click="toggle_filters"` disclosure — this is documented as acceptable divergence (D-05/D-06 in the context). No element fails the earning-its-place test for the support-investigator lens.

### Is the IA muddy?

NONE — searched for: primary-action ambiguity for an investigator trying to find a specific user; next-step obscured by secondary elements. The search form is prominently first after the scope_ribbon; the results table with "Open user" buttons is the clear next step. The pagination nav at the bottom follows the results — correct hierarchy. No IA muddiness found.

### Redundant / coherent / least-surprising?

NONE — searched for: same search result rendered twice on the page; vocabulary drift between the chip labels here ("Needs review", "Deletion scheduled") and the user-show detail page status pills. The chip label "Deletion scheduled" (users_index_live.ex:533) matches the status_pill label on user_show_live.ex:status_pills which returns {"Deletion scheduled", "warn"}. Vocabulary is consistent. No redundancy or coherence failure found.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements on the org-scoped `/admin/organizations/:slug/users` variant that do not earn their place for the org-admin posture. The scope_ribbon copy "Organization-scoped user operations for {name}" (users_index_live.ex:437-438) correctly anchors the org-admin's bounded context. The search form, filter chips, and results table all earn their place. The "Organization" filter field in "More filters" (users_index_live.ex:131-137) is still present on the org-scoped variant — this is the only element that might not earn its place (org-admin is already scoped; cross-org search is unavailable). However, the field is a generated form element that is harmless if the backend ignores it for org-scoped queries — this is a marginal concern, not a clear `tighten`.

### Is the IA muddy?

NONE — searched for: scope_ribbon or breadcrumb confusion for an org-admin who is already tenant-bounded; next-action ambiguity when the member search yields no results. The scope_ribbon correctly names the org-scoped context. The empty_state for no results (users_index_live.ex:300-309) provides "Clear all filters" as the next action. No IA muddiness found for the org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary drift between the org-scoped users page and the org-scoped overview page (organization_live.ex); duplicate metric display for the org-admin. The User health stat strip on the org-scoped variant still shows "Total users" — but this count is org-scoped, which is useful context for the org-admin. No redundancy failure found for this lens.
