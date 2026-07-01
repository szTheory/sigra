---
surface: branding-live
ledger_cell: branding-live
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
  - element: "<.scope_ribbon copy='Global auth/email profile' /> hardcoded literal (branding_live.ex:106)"
    lens: platform_admin
    question: redundant_coherent_surprising
    refutation: "Every other admin page that renders a scope_ribbon uses a `scope_copy/1` private function to compute the copy dynamically (e.g., users_index_live.ex:435-440, user_show_live.ex:325-328, audit_index_live.ex:220-223). branding_live.ex:106 is the ONLY page that hardcodes the ribbon copy as a string literal: copy='Global auth/email profile'. This diverges from the computed `scope_copy/1` helper pattern used consistently across all sibling pages. NEW-2: branding has no `scope_copy/1` helper — the fix must add a context-appropriate one. The org-admin lens does not reach this page (branding is platform-admin-only), so the literal is functionally correct today — but it is architecturally inconsistent and would surprise a developer reading sibling pages."
    disposition_action: tighten
---

# branding-live: Persona-JTBD Panel Review

**Surface:** Admin Auth Branding (`/admin/auth-branding`)
**Ledger cell:** `branding-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/branding_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — one `tighten` verdict: hardcoded scope_ribbon literal diverges from the computed `scope_copy/1` pattern. Remediable in-place by adding a `scope_copy/1` private function to branding_live.ex and updating the scope_ribbon call (NEW-2 from RESEARCH context).

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

NONE — searched for: elements on the branding workbench that do not earn their place for a platform admin customizing auth/email branding. The tab navigation (Light / Dark / Details panels) earns its place by organizing the token editing surface without overwhelming the operator. The preview section earns its place as live feedback. The "Brand tokens" section heading and "Source:" provenance label (branding_live.ex:116-117) earn their place — the provenance tells the admin whether they're editing a saved admin profile or config defaults. The "Restore defaults" dialog trigger earns its place as the safe-escape affordance. No element fails earning-its-place for the platform-admin lens.

### Is the IA muddy?

NONE — searched for: inverted hierarchy between the scope_ribbon and the workbench content; primary action (save) buried below secondary evidence (token grid). The scope_ribbon renders after the header (branding_live.ex:106, after header closes at :104) — this is the same after-header position as audit-index-live, not the before-header position of user_show_live. The branding page is a workbench (not a detail/entity page), so the after-header scope_ribbon position is arguably appropriate for workbench archetype. No IA hierarchy violation found.

### Redundant / coherent / least-surprising?

**Finding — `<.scope_ribbon copy="Global auth/email profile" />` hardcoded literal (`branding_live.ex:106`):**

Verdict: `tighten`

Every other admin page that renders a `<.scope_ribbon>` uses a `scope_copy/1` private function:
- `users_index_live.ex:83`: `<.scope_ribbon copy={scope_copy(@admin_scope)} />`
- `user_show_live.ex:44`: `<.scope_ribbon copy={scope_copy(@admin_scope)} />`
- `audit_index_live.ex:56`: `<.scope_ribbon copy={scope_copy(@admin_scope)} />`
- `user_sessions_live.ex:104`: `<.scope_ribbon copy={scope_copy(@admin_scope)} />`
- `audit_user_live.ex:67`: `<.scope_ribbon copy={scope_copy(@admin_scope)} />`

`branding_live.ex:106` is the sole exception: `<.scope_ribbon copy="Global auth/email profile" />` — a hardcoded string literal. This diverges from the computed `scope_copy/1` pattern. The branding page is currently platform-admin-only (no org-scoped variant), so the literal is functionally correct. However, the architectural inconsistency is a `tighten`: a developer reading sibling pages would be surprised to find one page using a bare string literal.

NEW-2 (from RESEARCH): branding has NO `scope_copy/1` helper — the remediation must add one. Since branding is always global-scope (no org-scoped variant), the `scope_copy/1` would return a static string ("Global auth/email profile" or equivalent), but using the function form maintains the pattern consistency with all sibling pages.

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements on the branding workbench that are not relevant to a support investigator who might land here accidentally or during a cross-workflow navigation. The branding page is a specialized workbench — a support investigator would typically not visit it during a support session. However, the page still needs to be coherent and not distracting if the investigator does encounter it. All elements earn their place as a branding customizer. No earning-its-place failure for this lens.

### Is the IA muddy?

NONE — searched for: IA hierarchy confusion on the branding workbench that would disorient a support investigator; unclear next-step for someone who navigated here accidentally. The page header "Auth forms and emails" and kicker "Branding" (branding_live.ex:99-100) are clear. The breadcrumbs (if rendered) would provide escape. The page is self-contained. No IA muddiness found for support-investigator lens.

### Redundant / coherent / least-surprising?

NONE — searched for: branding-specific vocabulary drift relative to other admin pages; duplicate information presented within the branding workbench itself. The branding workbench is a unique surface with no structural peer (it is not a list, detail, or audit page), so cross-page coherence expectations are lower. The scope_ribbon literal finding is a platform-admin concern (Q3 above). No additional redundancy or coherence failure found for support-investigator lens.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements that would be visible to an org-admin who attempts to access `/admin/auth-branding`. By design, the branding route is platform-admin-only — an org-admin navigating to `/admin/auth-branding` should receive a 403 or be redirected. The page itself is never rendered for the org-admin lens. No earning-its-place failure attributable to the surface for this lens (correct 403 gate per CONTEXT.md D-14: "org-admin kill on Overview/Branding categorized as correct 403 gate, not surface flaw").

### Is the IA muddy?

NONE — searched for: IA hierarchy failures visible to an org-admin who might reach this URL through a stale bookmark. If the org-admin is correctly rejected at the route level, no page IA is exposed. The 403 response is the correct boundary. No IA muddiness for org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary or layout on the branding page that would confuse an org-admin if they could somehow see it. The org-admin does not reach this surface through correct auth boundaries. No redundancy or coherence failure for org-admin lens.
