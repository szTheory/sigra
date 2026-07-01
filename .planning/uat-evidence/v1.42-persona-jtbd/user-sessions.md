---
surface: user-sessions
ledger_cell: user-sessions
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
  - element: "<h1 class='sg-page-title'>Sessions</h1> (user_sessions_live.ex:108)"
    lens: platform_admin
    question: redundant_coherent_surprising
    refutation: "The H1 on user-sessions is the literal string 'Sessions' (user_sessions_live.ex:108), not the user's name. Sibling entity-detail pages use the entity name as H1: user-show-live.ex:48 uses '{@detail.display_name || @detail.user.email}', and audit-user-live.ex:71 uses the same pattern. The sessions page diverges from its siblings by using a page-type label ('Sessions') as the H1 instead of the entity name. A platform admin who navigates from user-show to sessions encounters an H1 shift from entity-name to page-type, which is surprising given the sibling convention."
    disposition_action: tighten
  - element: "revoke copy 'They can sign in again.' (user_sessions_live.ex:205, :209)"
    lens: support_investigator
    question: redundant_coherent_surprising
    refutation: "The revoke-session copy (user_sessions_live.ex:205) and revoke-all-sessions copy (:209) both end with 'They can sign in again.' This phrase may undermine the security-remediation posture: a support investigator revoking a session because of suspected compromise would not want copy that suggests the action is trivially reversible. The copy/IA concern is valid — the revoke action should read as a definitive security action, not a mild interruption. NOTE per D-08: this is a COPY/IA finding only — do NOT ratchet user-sessions to Tier-2 (that is Phase 210). The finding is remediable by tightening the copy to omit the reassurance clause."
    disposition_action: tighten
---

# user-sessions: Persona-JTBD Panel Review

**Surface:** Admin User Sessions (`/admin/users/:id/sessions`)
**Ledger cell:** `user-sessions`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/user_sessions_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — two `tighten` verdicts (H1 hierarchy divergence; revoke copy security-posture concern). Both are copy/IA only — no Tier-2 ratchet in this phase (Phase 210 owns the tier elevation per D-08).

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

NONE — searched for: elements on the sessions page that do not earn their place for a platform admin who navigated here via the "Manage sessions" link on user-show. The sessions table (user_sessions_live.ex:125-157) with per-row "Revoke session" buttons earns its place as the primary action surface. The "Revoke all sessions" header button (:115-121) earns its place as the bulk-action affordance. The confirm dialog (`:165-194`) earns its place as the destructive-action gate. No element fails earning-its-place for the platform-admin lens.

### Is the IA muddy?

NONE — searched for: next-action ambiguity on a dedicated session-management page; scope_ribbon/header hierarchy inversion. The scope_ribbon renders before the header (user_sessions_live.ex:104), consistent with user_show_live.ex:44 (scope before header). The H1 "Sessions" is followed by a session count paragraph (`:109`) — this is correct sub-heading hierarchy. The confirm dialog appears conditionally on phx-click events (`:165`) — correct modal overlay IA. No IA muddiness found.

### Redundant / coherent / least-surprising?

**Finding — H1 "Sessions" diverges from sibling entity-name H1 pattern (`user_sessions_live.ex:108`):**

Verdict: `tighten`

Sibling detail pages use the entity's identity name as the H1:
- `user_show_live.ex:48`: `<h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>`
- `audit_user_live.ex:71`: `<h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>`

`user_sessions_live.ex:108` uses `<h1 class="sg-page-title">Sessions</h1>` — a page-type label, not the entity name. This is a cross-page convention violation that would surprise a platform admin navigating between user detail, sessions, and audit pages. The kicker "User" (`:107`) is also terse (same finding as user-show-live). Tighten: the H1 should be the user's name/email (matching siblings); "Sessions" is then implicit in the breadcrumb/page context.

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements on the sessions page that do not earn their place for a support investigator reviewing and revoking sessions. Every element on the page — scope_ribbon, header, sessions table, per-row revoke buttons, bulk-revoke button, confirm dialog — directly serves the investigator's session-management job. No element fails earning-its-place for the support-investigator lens.

### Is the IA muddy?

NONE — searched for: primary-action ambiguity for an investigator who needs to revoke a specific session; confirm dialog flow breaking expected focus management. The per-row "Revoke session" buttons are the primary actions (user_sessions_live.ex:148-151). The confirm dialog (`:165-194`) correctly gates the destructive action with a cancel-first dialog. The `ConfirmDialog` phx-hook manages focus trap and restoration. No IA muddiness found.

### Redundant / coherent / least-surprising?

**Finding — revoke copy "They can sign in again." undermines security-remediation posture (`user_sessions_live.ex:205, :209`):**

Verdict: `tighten`

The `revoke_session_copy/1` function (user_sessions_live.ex:204-206) returns "The user will be signed out of this session immediately. They can sign in again." The `revoke_all_sessions_copy/1` (`:208-210`) ends identically with "They can sign in again."

The phrase "They can sign in again" is a reassurance clause that contradicts the security-remediation posture of a support investigator revoking sessions. When the investigator is revoking because of suspected compromise (e.g., a leaked session), this copy is semantically misaligned — it minimizes the action's gravity. The copy/IA concern is real.

**D-08 note:** This is a COPY/IA finding only. Do NOT use this finding to justify ratcheting user-sessions to Tier-2 — its Tier-2 elevation is Phase 210. Remediation: remove the reassurance clause "They can sign in again." from both copy functions, leaving the factual consequence statement intact.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements on the org-scoped session-management page that do not earn their place for an org-admin managing a member's sessions. The scope_ribbon correctly names the org context. The session table and revoke controls earn their place. No element fails earning-its-place for the org-admin lens.

### Is the IA muddy?

NONE — searched for: scope confusion for an org-admin on a tenant-scoped sessions page; breadcrumb mismatch. The breadcrumbs (user_sessions_live.ex:257-269) correctly use org-scoped paths in :organization mode. The "Overview" breadcrumb links to the org overview (`:271-274`). No IA muddiness found for org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary or layout divergence between the org-scoped sessions page and the global sessions page that would surprise the org-admin; copy that references platform-admin concepts not available to the org-admin. Both variants share identical markup with only scope_copy and paths differing. The "Revoke session" / "Revoke all sessions" copy is scope-neutral. No redundancy or coherence failure found for org-admin lens.

---

## Resolution Notes (Plan 209-04)

**Resolved:** 2026-07-01 — All actionable verdicts remediated in `lib/sigra/admin/live/user_sessions_live.ex`. Copy/IA ONLY — no Tier-2 ratchet (D-08).

### Platform Admin Q3 (redundant_coherent_surprising): H1 entity-name pattern — RESOLVED
**Diff ref:** `<h1 class="sg-page-title">Sessions</h1>` removed. The literal page-type label is gone; the H1 now renders `{@detail.display_name || @detail.user.email}` — the entity-name pattern matching `user_show_live.ex:48` and `audit_user_live.ex:71`. The kicker `<p class="sg-page-kicker">` changed from `"User"` to `"Sessions"`, so the page type is still named in the kicker. The page_title assign (`"#{...} sessions"`) is unchanged so browser tab/breadcrumb context is preserved.

### Support Investigator Q3 (redundant_coherent_surprising): Revoke-confirm copy — RESOLVED
**Diff ref:** Both `revoke_session_copy/1` and `revoke_all_sessions_copy/1` rewritten. The reassurance clause "They can sign in again." was removed. The replacement conveys: (1) factual consequence (signed out immediately) and (2) reversibility framed as a security-remediation action ("must sign in again with verified credentials to re-establish access") rather than a trivial re-entry. This preserves the security-remediation posture per T-209-04-01 threat model: consequence + reversibility without minimizing the action. ConfirmDialog hook, `data-sg-confirm-cancel` focus, and the 7 APG gates are unchanged — copy string only.
