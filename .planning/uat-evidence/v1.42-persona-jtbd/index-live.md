---
surface: index-live
ledger_cell: index-live
rubric_version: "1.0"
disposition: actionable
verdicts:
  platform_admin:
    earning_its_place: tighten
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
  - element: "<.notice> tone=:ok bare 'All clear' copy (index_live.ex:52)"
    lens: platform_admin
    question: earning_its_place
    refutation: "On zero-risk state the notice renders 'All clear' — a positive confirmation with no action affordance. The platform admin triage posture only needs to see exception states; an 'all good' signal adds noise without enabling action."
    disposition_action: tighten
  - element: "<.summary_chip id='overview-metric-total-users'> (index_live.ex:85-91)"
    lens: platform_admin
    question: redundant_coherent_surprising
    refutation: "The Global Overview stat strip repeats 'Total users' with the same label and value as the User health strip on users-index-live.ex:185-191. The platform admin triage posture does not need the same count on two different pages."
    disposition_action: tighten
---

# index-live: Persona-JTBD Panel Review

**Surface:** Global Admin Overview (`/admin`)
**Ledger cell:** `index-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/index_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable` (gets a Wave-2 diff or documented waiver); all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase (external dep) — none expected here.

This surface: `actionable` — two `tighten` verdicts from the platform-admin lens, both remediable in-place.

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

**Finding — `<.notice>` bare "All clear" copy (`index_live.ex:52`):**

Verdict: `tighten`

The notice component renders with `tone={:ok}` and the literal text "All clear" when `@needs_review == 0` (`index_live.ex:51-53`). For the platform-admin triage posture, this is a positive-confirmation signal with zero action affordance. The operator's posture is "what needs attention?" — an explicit "nothing to do" is marginally useful, but the bare string "All clear" is insufficiently informative (no count, no scope context). The notice component itself is structurally correct (the `<.notice>` component is the right choice per design contract); only the copy needs tightening to be more informative (e.g., "No users need review" to parallel the risk copy on `index_live.ex:49-51`).

### Is the IA muddy?

NONE — searched for: inverted hierarchy between the scope ribbon and stat strip; primary action buried below secondary evidence; breadcrumb or scope-ribbon mismatch; navigation links competing with content for attention. The three task_card grid follows general→specific (triage cards → snapshot metrics); the stat strip at the bottom is correctly subordinate; no scope_ribbon is present (intentionally omitted on Overview pages per `organization_live.ex:60` comment, acceptable here). No IA hierarchy violation found.

### Redundant / coherent / least-surprising?

**Finding — `<.summary_chip id="overview-metric-total-users">` duplicates Users Index stat strip (`index_live.ex:85-91`):**

Verdict: `tighten`

The Global Overview renders `<.summary_chip label="Total users" value={total_users}>` in its "User snapshot" strip (`index_live.ex:85-91`). The exact same metric — same label, same value, same icon "users" — appears in the "User health" strip on `users_index_live.ex:185-191` (`<.summary_chip id="users-metric-total" label="Total users">`). The platform-admin triage posture arrives at `/admin` before navigating to `/admin/users`; showing "Total users" on both pages as a primary stat is redundant. The overview's purpose is directional triage, not metric replication.

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements present only for the platform-admin triage posture that are not useful to the support-investigator who arrives here as an orientation point between investigations. The task_card grid ("Find a user", "Investigate an event", "Review risky users") earns its place as navigation pivots for the investigator posture as well — they provide fast re-entry to the primary investigator workflows. The stat strip provides ambient context. No element fails the earning-its-place test for this lens.

### Is the IA muddy?

NONE — searched for: next-action ambiguity for a support investigator who lands on `/admin` between investigations; competing navigation links at equal visual weight to task cards. The three task_card components provide clear next-step destinations; their visual weight is distinct from the stat strip below. No IA muddiness found.

### Redundant / coherent / least-surprising?

NONE — searched for: the same metric appearing twice within this single page for the investigator lens; vocabulary drift between the overview copy and the user-detail surface copy. The page uses consistent admin vocabulary. No redundancy or coherence failure found for this lens.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements on this global `/admin` surface that would be visible to an org-admin who should be redirected to `/admin/organizations/:slug`. By design, the org-admin lens does not reach `/admin` directly — they are redirected to the org-scoped overview. This surface is the platform-admin entry point; the org-admin lens is out-of-scope for `/admin`. The surface correctly gate-keeps org-admin access via the admin scope middleware. No earning-its-place failure for this lens (lens is inapplicable for a correctly functioning auth boundary).

### Is the IA muddy?

NONE — searched for: IA hierarchy failures visible to an org-admin who might land here through a direct URL (e.g., bookmark). If an org-admin somehow reaches `/admin`, the scope middleware redirects them; the page content is never rendered for this persona in normal operation. No IA muddiness attributable to this surface for the org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary or layout divergence that would surprise an org-admin if they compared this surface to the org-scoped `/admin/organizations/:slug` overview. The org-admin does not reach this surface; redundancy between the two overview pages is addressed under the platform-admin lens. No finding for org-admin lens.
