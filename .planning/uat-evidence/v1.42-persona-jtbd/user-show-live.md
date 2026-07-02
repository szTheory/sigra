---
surface: user-show-live
ledger_cell: user-show-live
rubric_version: "1.0"
disposition: actionable
verdicts:
  platform_admin:
    earning_its_place: tighten
    ia_muddy: tighten
    redundant_coherent_surprising: tighten
  support_investigator:
    earning_its_place: tighten
    ia_muddy: tighten
    redundant_coherent_surprising: tighten
  org_admin:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
findings:
  - element: "<dl class='sg-summary-facts'> Sessions count (user_show_live.ex:54-58)"
    lens: platform_admin
    question: earning_its_place
    refutation: "The header summary-facts dl shows a 'Sessions' count (user_show_live.ex:54-58). The Sessions card immediately below (user_show_live.ex:80-116) shows the same count as a sub-heading copy 'N active sessions' (user_show_live.ex:84). The same session count appears in both the header dl and the Sessions card section — the header instance does not earn its additional place."
    disposition_action: tighten
  - element: "<p class='sg-page-kicker'> terse 'User' kicker (user_show_live.ex:47)"
    lens: platform_admin
    question: ia_muddy
    refutation: "The page kicker is the bare string 'User' (user_show_live.ex:47). Sibling pages use more informative kickers: 'User audit evidence' (audit_user_live.ex:70) and 'User operations' (users_index_live.ex:79). The terse 'User' kicker fails to anchor context for a platform admin who has navigated through users-index to this page."
    disposition_action: tighten
  - element: "<a class='sg-btn sg-btn--secondary sg-btn--sm' href={sessions_path...}> 'Manage sessions' (user_show_live.ex:86)"
    lens: platform_admin
    question: ia_muddy
    refutation: "The 'Manage sessions' link is an easily-missed secondary button rendered inline in the Sessions card header cluster (user_show_live.ex:86), visually competing with the h2/sub-heading. For a platform admin whose primary session-management workflow is revocation, this link is the gateway to the dedicated sessions page — it should be more prominent or the session-management entrypoint should be clearer."
    disposition_action: tighten
  - element: "4 separately-worded <.empty_state> copies (user_show_live.ex:115, :146, :182, :202)"
    lens: support_investigator
    question: earning_its_place
    refutation: "The page contains 4 <.empty_state> components with divergent copy across the Sessions (:115), Identities (:146), Organizations (:182), and Recent audit (:202) sections. Each empty-state copy is independently worded with no shared template. While 4 empty-states are legitimate (4 data sections), the investigator's cognitive load increases when each zero-state message uses a different phrasing register."
    disposition_action: tighten
  - element: "Sessions count in <dl class='sg-summary-facts'> vs Sessions card sub-heading (user_show_live.ex:57 vs :84)"
    lens: support_investigator
    question: redundant_coherent_surprising
    refutation: "The session count appears twice: once in the header summary-facts dl as 'Sessions: N' (user_show_live.ex:57) and again as 'N active sessions' in the Sessions card sub-heading paragraph (user_show_live.ex:84). The support investigator sees the same number twice within a single scroll on the same page. This is a clear same-count-rendered-twice redundancy."
    disposition_action: tighten
---

# user-show-live: Persona-JTBD Panel Review

**Surface:** Admin User Detail (`/admin/users/:id`)
**Ledger cell:** `user-show-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/user_show_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — multiple `tighten` verdicts from platform-admin and support-investigator lenses, all remediable in-place.

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

**Finding — `<dl class="sg-summary-facts">` Sessions count duplicates Sessions card sub-heading (`user_show_live.ex:54-58`):**

Verdict: `tighten`

The header `<dl class="sg-summary-facts">` renders a `<dt>Sessions</dt><dd>{length(@detail.sessions)}</dd>` (user_show_live.ex:54-58). The Sessions card directly below (user_show_live.ex:80-116) renders `<p class="sg-section-copy">{pluralize(length(@detail.sessions), "active session")}</p>` at line 84 as a sub-heading. Both communicate the same session count. The header dl instance does not earn its place beyond this duplication — the platform admin can read the session count once in the Sessions card where it contextually belongs.

### Is the IA muddy?

**Finding 1 — terse `<p class="sg-page-kicker">User</p>` kicker (`user_show_live.ex:47`):**

Verdict: `tighten`

The page kicker "User" (user_show_live.ex:47) is context-free. Sibling pages use descriptive kickers: "Audit evidence" (`audit_index_live.ex:53`), "User audit evidence" (`audit_user_live.ex:70`), "User operations" (`users_index_live.ex:79`). A platform admin who navigates from the users index to a user detail page would be better oriented by a kicker like "User detail" that names the scope of this page. The terse "User" is marginally informative.

**Finding 2 — "Manage sessions" secondary button easily missed (`user_show_live.ex:86`):**

Verdict: `tighten`

The "Manage sessions" link is a `sg-btn--secondary sg-btn--sm` rendered inline in the Sessions card header cluster (user_show_live.ex:86), competing visually with the section heading. The platform-admin's primary goal on a user detail page often includes session review and revocation. The gateway to the dedicated sessions page (`UserSessionsLive`) is easy to miss at the secondary-button scale. The link earns its place functionally but its placement/prominence is a tighten.

### Redundant / coherent / least-surprising?

NONE — searched for: same metric appearing twice in the header or across sections beyond the session count already noted under Q1; vocabulary drift between status pill labels here ("Confirmed"/"Unconfirmed"/"Locked"/"Deletion scheduled") and the users-index page status chips. The `status_pills/1` function (user_show_live.ex:332-341) returns "Confirmed" as a pill on the detail page, while the users-index strips the positive-confirmation pill (users_index_live.ex:status_pills drops the "Confirmed" positive case). This vocabulary/visibility asymmetry is notable but is a pre-existing design decision (Phase 201 stripped Confirmed from the index). It is not surprising once understood; it is correct (the detail page shows full identity state). No additional redundancy or coherence failure beyond Q1.

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

**Finding — 4 separately-worded `<.empty_state>` copies across 4 sections (`user_show_live.ex:115, :146, :182, :202`):**

Verdict: `tighten`

The page contains 4 `<.empty_state>` components:
- Sessions: "No active sessions" + "This user has no active sessions in the current scope." (`:115`)
- Identities: "No linked identities" + "This user signs in without a visible external identity provider." (`:146`)
- Organizations: "No organizations" + "This user has not joined any organizations." (`:182`)
- Recent audit: "No recent audit activity" + "No scoped events are currently tied to this user." (`:202`)

Each empty-state is independently worded with no shared phrasing pattern (contrast: "No active sessions in the current scope" vs "No scoped events are currently tied"). The support investigator reading 4 zero-state messages across one page encounters divergent phrasing register for structurally equivalent states (no data for a given section). Tighten by harmonizing the copy register (e.g., all use "No {noun}" title + "No {noun} are associated with this user in the current scope." body).

### Is the IA muddy?

**Finding — "Manage sessions" link easily missed (`user_show_live.ex:86`):**

Verdict: `tighten`

(Same finding as Platform Admin Q2.) For the support investigator, session management is often the primary action goal. The "Manage sessions" link is a small secondary button in the Sessions card header cluster. The investigator posture drives toward session revocation; having the gateway to the revocation page as an easily-missed secondary button makes the next action less obvious.

### Redundant / coherent / least-surprising?

**Finding — Sessions count duplicated (`user_show_live.ex:57` vs `:84`):**

Verdict: `tighten`

The session count appears in the header summary-facts dl (`:57`) and again as the Sessions card sub-heading paragraph (`:84`). For the support investigator who reads the header information carefully and then scans the Sessions card, the same number appears twice. This is the clearest same-count-rendered-twice redundancy on this page.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements on the org-scoped user detail page (`/admin/organizations/:slug/users/:id`) that do not earn their place for the org-admin posture. The scope_ribbon copy "Organization-scoped user operations for {name}" (user_show_live.ex:325-327) correctly anchors the org context. The page content (identity, sessions, security, organizations, recent-audit, danger-zone) is all relevant to an org-admin reviewing a member. No element fails earning-its-place for the org-admin lens.

### Is the IA muddy?

NONE — searched for: scope confusion for an org-admin who should only see org-scoped data; breadcrumb mismatch between org scope and global scope. The breadcrumbs (user_show_live.ex:255-261) correctly use org-scoped paths when admin_scope is :organization mode. No IA muddiness found for org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary or layout divergence between the org-scoped user detail and the global user detail that would surprise the org-admin. Both variants share identical markup with only the scope_copy and paths differing. The pivot links to org-scoped views (user_show_live.ex:173-179) correctly appear only for platform-admin scope (`show_pivot_link?/2` at :285-288). No redundancy or coherence failure found for org-admin lens.

---

## Resolution Notes (Plan 209-04)

**Resolved:** 2026-07-01 — All actionable verdicts remediated in `lib/sigra/admin/live/user_show_live.ex`.

### Platform Admin Q1 (earning_its_place): Sessions count de-duplication — RESOLVED
**Diff ref:** `Sessions` `<dt>/<dd>` block removed from `<dl class="sg-summary-facts">` header. The count now appears only in the Sessions card sub-heading (`sg-section-copy` at `:84`). The header `dl` retains MFA and Last seen — both earn their place as quick-scan identity facts not replicated below.

### Platform Admin Q2 / Support Investigator Q2 (ia_muddy): Kicker sharpened — RESOLVED
**Diff ref:** `<p class="sg-page-kicker">User</p>` → `<p class="sg-page-kicker">User detail</p>`. Matches the pattern of "User audit evidence" / "User operations" on sibling pages; anchors the page scope without adding noise.

### Platform Admin Q2 / Support Investigator Q2 (ia_muddy): "Manage sessions" prominence raised — RESOLVED
**Diff ref:** `sg-btn--secondary sg-btn--sm` demotion pair removed. The "Manage sessions" affordance is now `sg-btn sg-btn--primary` — a standard primary button in the Sessions card header cluster. This is the measurable floor (variant (a): non-secondary, non-small). No confirm overlay added (per UI-SPEC: that lives on UserSessionsLive).

### Support Investigator Q1 (earning_its_place): Empty-state copy harmonized — RESOLVED
**Diff ref:** All 4 `<.empty_state>` bodies rewritten to the uniform `"No {noun} are associated with this user in the current scope."` / `"No {noun} are associated with this user."` register:
- Sessions: "No sessions are associated with this user in the current scope."
- Identities: "No external identities are associated with this user."
- Organizations: "No organizations are associated with this user."
- Recent audit: "No audit events are associated with this user in the current scope."

### Support Investigator Q3 (redundant_coherent_surprising): Sessions count de-duplication — RESOLVED
**Same diff as Platform Admin Q1 above.** The header `dl` Sessions row is gone; the count renders once in the Sessions card sub-heading.
