# Phase 191: Microcopy & IA Sweep — Research

**Researched:** 2026-06-17
**Domain:** Admin UI microcopy, information architecture, glossary enforcement
**Confidence:** HIGH (all findings from direct source reading; no external lookup needed)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01** — Glossary defines both `user` and `member` as distinct concepts. Boundary rule:
outside any org / global+platform surfaces → "user"; inside an org's surface → "member."
"account" demoted to first-person self-service copy only.

**D-02** — Canonical glossary table (seed):

| Concept | Canonical | Banned synonyms |
|---|---|---|
| Global identity (the login) | **user** | account (as person), member (on global surfaces) |
| A user's seat in one org | **member** (rel. = *membership*) | user (in org surfaces), seat, teammate, collaborator |
| The tenant | **organization** (spelled out) | org (allowed only in code/URL slugs/identifiers) |
| Auth action (verb) | **sign in** / **sign out** (two words) | log in, login (verb), signin, log out, logout, sign off |
| Auth action (modifier/noun) | **sign-in** (hyphenated, e.g. "failed sign-in") | login (noun), signin |
| Take a member out of an org | **remove** | delete a member, revoke a member |
| Destroy the identity | **delete** (user/account) | remove, destroy |
| End a session / API key / sent invitation | **revoke** | delete, remove, cancel |
| Policy block (reversible, admin-initiated) | **suspend** | deactivate, disable, ban, lock |
| Auto-block after failed sign-ins (system, transient) | **lock / unlock** | suspend, disable, freeze |
| Stop a pending invitation | **revoke** (sent) / **cancel** (not yet sent) | delete invitation |
| Pending join offer | **invitation** (noun) / **invite** (verb) | — |
| Authority bundle | **role** (owner/admin/member) | permission (as synonym), access level, group |
| Granular capability | **permission** | role, scope (in UI prose) |

**D-03** — Cross-cutting plain-language gate: active voice; second person ("you" = operator, "the user" = subject); GOV.UK words-to-avoid banned; no leaked internals; ≤ ~2 sentences; calm, no blame, no hype.

**D-04** — Per-type rubrics. Decisive E-6 branch: auth/enumeration boundary → uniform/generic; operator console error → specific.

**D-05** — Maintainer-grade register throughout.

**D-06** — Glossary lives at `guides/reference/admin-glossary.md`.

**D-07** — Enforcement via ExUnit test `test/sigra/admin/glossary_test.exs`, NOT bash guard.

**D-08** — Scope = exactly 7 admin LiveViews + `components.ex`. Generated auth forms/emails OUT of scope.

**D-09** — Carve-out: `branding_live.ex` lines 580–610 (the `sigra-auth--preview` block including `<h1>Log in</h1>`) — MUST NOT be normalized. Exact carve-out region confirmed as lines 580–610.

**D-10** — 191 lands self-contained same-diff (copy + spec assertions + recapture). Phase 192 stays terminal.

**D-11** — Add `branding-live` L3 row to quality ledger. Re-score D9/D10 axes on all L3 rows.

**D-12** — Fold the `branding-live` explicit-scoring todo. Verify WR-04 `error_message/1` fix was completed in 190.

### Claude's Discretion (planner resolves)
- Exact glossary table contents beyond D-02 seed (additional concepts surfaced during inventory).
- Whether voice rubric lives in `admin-glossary.md` vs `admin-design-contract.md`.
- Structural source-extraction regexes in `glossary_test.exs`.
- Sequencing of inventory → edit → assertion-update → recapture waves.
- Exact L3/L4 tiers achieved per surface after re-score.
- Whether any string edit is large enough to also touch a `components_test.exs` golden vs spec-only.

### Deferred Ideas (OUT OF SCOPE)
- Generated-auth-screen copy normalization (host-owned, v1.37 territory).
- Terminal idempotency gate + full baseline recapture + allowlist reset-to-empty → Phase 192.
- Bash glossary guard `scripts/ci/admin-glossary-guard.sh`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COPY-01 | System-wide voice pass aligns all admin microcopy with brand book; errors state what failed + why it matters + next action | String inventory below identifies every non-compliant string with canonical replacement |
| COPY-02 | GOV.UK plain-language pass yields committed one-term-per-concept glossary with no synonym drift | Expanded glossary table in §Expanded Glossary; banned-term findings per file:line in inventory |
| COPY-03 | Empty-state, success, and warning copy consistent across all admin surfaces | Inventory classifies all empty/success/warning strings; inconsistencies flagged with canonical replacements |
</phase_requirements>

---

## Summary

Phase 191 is a content-only pass over eight already-built Elixir source files. The string inventory below is the primary output — every visible string in each file, classified and checked against the D-02 glossary and D-03/D-04 voice rubric. The work volume is modest: roughly 15–20 strings need editing across all seven LiveViews, concentrated in `organization_live.ex` (3 violations), `users_index_live.ex` (3 violations), `user_show_live.ex` (5 violations), and `branding_live.ex` (2 violations outside the carve-out). The `components.ex` file carries almost no visible strings and has zero violations.

WR-04 status (D-12 planner check): `branding_live.ex:728–731` still has two `inspect(reason)` fallback arms in `error_message/1`. The `%Ecto.Changeset{}` arm (line 714–722) and `%{__struct__: _module}` arm (lines 725–728) both call `Exception.message/1` which is acceptable; but the final catch-all `defp error_message(reason), do: "Could not save auth branding: #{inspect(reason)}"` (line 731) leaks the raw term. This is the WR-04 residual that D-12 says the planner must verify and finish if 190 did not.

**Primary recommendation:** Implement the string inventory edits in a single wave (all seven files), update `admin-checkpoints.spec.ts` literal-text assertions in the same diff, run the recapture gate for all affected slugs, then write `glossary_test.exs` with the structural strip regexes documented below.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Visible admin copy (labels, empty states, notices) | Library (LiveView source) | — | Route-injected library modules; no mirror into host; copy edits are single-source |
| Glossary enforcement | ExUnit (mix test) | — | D-07: test parses source structurally, ships with library to adopters |
| Snapshot baselines | Playwright (example dev server) | — | 8 slugs × 3 projects; must recapture after copy edits change text |
| Ledger monotonic guard | CI (quality-ledger-monotonic.sh) | — | Integer-only increase; D-11 adds branding-live L3 row |
| Auth-preview carve-out | branding_live.ex:580–610 | — | Intentional host-mirror copy; exempt from glossary guard |

---

## Standard Stack

No new packages. Phase is source-editing only.

## Package Legitimacy Audit

No packages installed in this phase.

---

## Carve-Out Region — Exact Location

**File:** `lib/sigra/admin/live/branding_live.ex`
**Carve-out region:** Lines **580–610** (the `defp preview_pair/1` inner HEEx block).

The boundary markers are:
- **Open:** Line 584 — `<div` with `class="sigra-auth sigra-auth--preview"` and `data-sg-auth-branding-preview="login"` (line 587)
- **Includes:** Line 601 — `<h1>Log in</h1>`; line 602 — `<p>Use a magic link, passkey, password, or enterprise SSO.</p>`; line 605 — `<button>Send magic link</button>`
- **Close:** Line 610 — `</div>` (closes the `sigra-auth sigra-auth--preview` div)

The heading on line 583 (`<h2 class="sg-section-heading">Login preview</h2>`) is **admin chrome** — it is the section label for the preview widget, not part of the auth screen replica. It uses the banned term "Login" (should be "Sign-in preview" or "Sign in preview") and IS subject to normalization. Only the content *inside* `class="sigra-auth sigra-auth--preview"` (lines 584–610) is carved out.

Similarly, line 614: `<h2 class="sg-section-heading">Email preview</h2>` is admin chrome and compliant (no vocabulary violation).

---

## Exhaustive Visible-String Inventory

### Classification key
- **Type:** `label` | `nav` | `empty-first-use` | `empty-filtered` | `empty-scope` | `success` | `warning` | `error` | `help` | `confirm-copy` | `confirm-label` | `heading` | `kicker` | `body` | `status-pill`
- **Violation:** glossary term violation or voice-rubric issue. `OK` = compliant.

### `lib/sigra/admin/live/index_live.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 22 | `"Global overview"` | heading (page_title) | OK | — |
| 40 | `Admin overview` | kicker | OK — admin chrome, not a person noun | — |
| 41 | `What do you need to do?` | heading | OK | — |
| 43–44 | `Start from the job at hand — find a user, investigate an event, or review risky accounts.` | body | OK | — |
| 49 | `{@needs_review} accounts need review —` | warning | `account` used as person-noun on global surface. D-01: "account" demoted to first-person only; correct term is "user". | `{@needs_review} users need review —` |
| 50 | `Review accounts` | label (notice_link) | `account` as person-noun on global surface | `Review users` |
| 52 | `All clear` | success | OK | — |
| 59 | `"Find a user"` | heading (task_card title) | OK | — |
| 59 | `"Search by email or ID, inspect security state, revoke sessions, and start support actions."` | body | OK | — |
| 61 | `"Find a user"` | label (action) | OK | — |
| 64 | `"Investigate an event"` | heading (task_card title) | OK | — |
| 65 | `"Filter security events, distinguish actor from effective user, and export CSV evidence."` | body | OK | — |
| 67 | `"Investigate audit"` | label (action) | OK | — |
| 70 | `"Review risky accounts"` | heading (task_card title) | `account` as person-noun | `"Review risky users"` |
| 71 | `"Jump straight to locked or deletion-scheduled accounts before they surprise support."` | body | `account` as person-noun | `"Jump straight to locked or deletion-scheduled users before they surprise support."` |
| 73 | `"Review locked"` | label (action) | Voice issue: verb-object incomplete — what is being reviewed? | `"Review users"` |
| 85 | `User snapshot` | heading | OK | — |
| 86 | `User snapshot` | aria-label | OK | — |
| 91 | `"Total users"` | label (summary_chip) | OK | — |
| 92 | `"total users"` | value_suffix | OK | — |
| 97 | `"New users"` | label | OK | — |
| 98 | `"new this week"` | value_suffix | OK | — |
| 102 | `"Accounts registered since Monday UTC and since the first day of this month."` | help | `Accounts` as person-noun | `"Users registered since Monday UTC and since the first day of this month."` |
| 109 | `"Active users"` | label | OK | — |
| 110 | `"active this week"` | value_suffix | OK | — |
| 112 | `"Users with session activity since Monday UTC and since the first day of this month."` | help | OK | — |
| 118 | `"Authentication coverage"` | label | OK | — |
| 120 | `"MFA coverage"` | value_suffix | OK | — |
| 122 | `"Coverage uses total users as the denominator."` | help | OK | — |

**index_live.ex summary:** 5 violations — `accounts` as person-noun in 4 places (lines 49, 50, 70, 71, 102), and the `"Review locked"` action label (line 73) is incomplete.

---

### `lib/sigra/admin/live/organization_live.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 24 | `"#{organization_name} overview"` | page_title | OK | — |
| 51 | `Organization overview` | kicker | OK | — |
| 53 | `{@organization_name}` | heading | OK (dynamic) | — |
| 54–55 | `Work inside this organization scope: support members, inspect security posture, and review audit evidence without losing tenant context.` | body | OK — uses "members" correctly (org surface) | — |
| 67 | `{@needs_review} {if @needs_review == 1, do: "account needs", else: "accounts need"} review —` | warning | `account` as person-noun on org surface. On org surfaces the correct term is "member". | `{@needs_review} {if @needs_review == 1, do: "member needs", else: "members need"} review —` |
| 67 | `Review accounts` | label (notice_link) | `account` as person-noun on org surface | `Review members` |
| 69 | `All clear` | success | OK | — |
| 76 | `"Support members"` | heading (task_card title) | OK — org surface, "members" is correct | — |
| 77 | `"Search org members, open account detail, and pivot through session, security, and membership state."` | body | Two violations: (1) `org` used in visible copy (banned outside code/slugs — must be "organization"); (2) `account` as person-noun on org surface → "member detail" | `"Search organization members, open member detail, and pivot through session, security, and membership state."` |
| 79 | `"Open members"` | label (action) | OK | — |
| 82 | `"Investigate org events"` | heading (task_card title) | `org` in visible copy | `"Investigate organization events"` |
| 83 | `"Filter audit evidence scoped to this organization and export only its events."` | body | OK | — |
| 85 | `"Open audit"` | label (action) | OK | — |
| 91 | `Members` | heading (section) | OK — org surface | — |
| 96 | `No members yet — invite teammates to populate this organization.` | empty-first-use | `teammates` is a banned synonym for `member` (D-02: collaborator/teammate/seat). | `No members yet — invite members to populate this organization.` |
| 103 | `Locked` | status-pill | OK | — |
| 104 | `Deletion scheduled` | status-pill | OK | — |
| 105 | `Confirmed` | status-pill | OK | — |
| 106 | `Unconfirmed` | status-pill | OK | — |
| 113 | `Pending invitations` | heading | OK | — |
| 119 | `No pending invitations.` | empty-first-use | OK | — |
| 130 | `Expired` | status-pill | OK | — |
| 131 | `Expires {format_date(invite.expires_at)}` | label | OK | — |

**organization_live.ex summary:** 5 violations — `account`/`accounts` as person-noun on org surface (lines 67 ×2), `org` in visible copy (lines 77, 82), `teammates` banned synonym (line 96).

---

### `lib/sigra/admin/live/users_index_live.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 56–58 | `"We couldn't load this user data. Refresh the page, then try again."` | error | OK — specific (operator console); names what to do. Acceptable. | — |
| 79 | `User operations` | kicker | OK | — |
| 80 | `{page_heading(@admin_scope)}` | heading | Dynamic — evaluated as "Users" or "{Name} users" | OK |
| 93 | `User health` | heading | OK | — |
| 94 | `User health summary` | aria-label | OK | — |
| 98 | `"Total users"` | label | OK | — |
| 99 | `"total users"` | value_suffix | OK | — |
| 104 | `"Confirmed users"` | label | OK | — |
| 106 | `"confirmed"` | value_suffix | OK | — |
| 108 | `"These users confirmed their email and can sign in normally."` | help | OK (uses "sign in", correct two-word verb) | — |
| 113 | `"MFA enrolled"` | label | OK | — |
| 115 | `"MFA enabled"` | value_suffix | OK | — |
| 117–118 | `"These users have multifactor authentication enabled. Higher coverage lowers account takeover risk."` | help | `account takeover` — "account" here is not a person-noun but rather a security term ("account takeover attack"). This is standard industry terminology and NOT a violation of D-01 (which bans "account" as a person-noun, not as a noun in compound security phrases). | OK — acceptable security idiom |
| 123 | `"Passkey users"` | label | OK | — |
| 125 | `"with passkeys"` | value_suffix | OK | — |
| 127–128 | `"These users have at least one passkey. Passkeys make phishing attacks harder."` | help | OK | — |
| 132 | `"Locked users"` | label | OK | — |
| 134 | `"locked out"` | value_suffix | OK | — |
| 135 | `"These users are locked out after failed sign-in attempts. Review the account before unlocking."` | help | `account` as person-noun | `"These users are locked out after failed sign-in attempts. Review the user before unlocking."` |
| 140 | `"Deletion scheduled"` | label | OK | — |
| 142 | `"pending deletion"` | value_suffix | OK | — |
| 143–145 | `"These users are scheduled for deletion. Access is disabled and active sessions are revoked."` | help | OK | — |
| 153 | `Find users` | heading | OK | — |
| 159 | `Search` | label | OK | — |
| 165 | `"Email, user id, or name"` | placeholder | OK | — |
| 169 | `Search` | label (button) | OK | — |
| 170 | `Clear` | label (button) | OK | — |
| 183–184 | `More filters` | label (button) | OK | — |
| 190 | `Organization` | label (field) | OK | — |
| 200 | `Provider` | label (field) | OK | — |
| 202 | `Any` | option | OK | — |
| 203 | `Local` | option | OK | — |
| 204 | `Google` | option | OK | — |
| 205 | `GitHub` | option | OK | — |
| 210 | `Registered from` | label | OK | — |
| 220 | `Registered to` | label | OK | — |
| 242 | `Clear all` | label | OK | — |
| 253 | `User` | th | OK | — |
| 254 | `Status` | th | OK | — |
| 255 | `Organizations` | th | OK | — |
| 256 | `Activity` | th | OK | — |
| 257 | `Action` | th | OK | — |
| 291 | `Open user` | label (button) | OK | — |
| 321 | `Organizations` | dt | OK | — |
| 328 | `Activity` | dt | OK | — |
| 332 | `Registered` | dt | OK | — |
| 341 | `Open user` | label (button) | OK | — |
| 348 | `"No users match this view"` | empty-filtered heading | OK | — |
| 350 | `"No users match the active filters. Clear them to widen the result set."` | empty-filtered | OK | — |
| 352 | `Clear all filters` | label | OK | — |
| 355 | `"Users appear here as people register and sign in. Once accounts exist, you can search, filter, and open any user."` | empty-first-use | `accounts` as person-noun | `"Users appear here as people register and sign in. Once users exist, you can search, filter, and open any user."` |
| 378–379 | `Showing {x}–{y} of {z} users` | nav/pagination | OK | — |
| 379 | `Page {@meta.current_page || 1} of {@meta.total_pages || 1}` | nav | OK | — |
| 372 | `aria-label="Previous page"` | aria | OK | — |
| 385 | `aria-label="Next page"` | aria | OK | — |
| 376–377 | `Previous page` / `Next page` | sr-only | OK | — |
| 409 | `{String.replace(@key, "_", " ")}` | label (quick_filter) | Auto-humanized — produces "confirmed", "mfa", "passkeys", "locked", "deleted", "needs review". "deleted" should arguably be "deletion scheduled" to match pill wording, but this is a filter chip shorthand and within scope for planner discretion. | Planner discretion — flag for consideration |
| 458 | `"Global user operations"` | scope_ribbon | OK | — |
| 461 | `"Organization-scoped user operations for #{name}"` | scope_ribbon | OK | — |
| 534 | `"Search: " <> param_value(params, "q")` | chip label | OK | — |
| 554 | `"MFA"` | chip label | OK | — |
| 555 | `"Passkeys"` | chip label | OK | — |
| 556 | `"Needs review"` | chip label | OK | — |
| 558 | `"Provider: " <> value` | chip label | OK | — |
| 559 | `"Registered from: " <> value` | chip label | OK | — |
| 560 | `"Registered to: " <> value` | chip label | OK | — |
| 561 | `"Organization: " <> value` | chip label | OK | — |
| 647 | `"Last activity: Not available"` | label (activity cell) | Voice/tone: "Not available" is technically correct but cold and unexplained. Per D-04 empty rubric: explain what populates the surface. Better: "No activity recorded". | `"Last activity: None recorded"` (or "No activity recorded") |

**users_index_live.ex summary:** 2 violations — `account` as person-noun on line 135, 355. Plus 1 voice/tone improvement (line 647). Quick-filter chip auto-humanizer at line 409 flagged for planner discretion.

---

### `lib/sigra/admin/live/user_show_live.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 23 | `"User"` | page_title | OK | — |
| 43–50 (event handler data) | `"Revoke this session?"` | confirm heading | OK | — |
| 48 | copy: `revoke_session_copy(detail)` → `"Revoke this session for #{detail.user.email}? This signs them out of that browser or device."` | confirm-copy | Voice rubric: question-format confirm copy is acceptable per D-04. "signs them out" uses correct verb. OK. | — |
| 59 | `"Revoke all sessions?"` | confirm heading | OK | — |
| 60 | copy: `revoke_all_sessions_copy(detail)` → `"Revoke every active session for #{detail.user.email}? This signs them out everywhere."` | confirm-copy | OK | — |
| 49 | `"Revoke session"` | confirm_label | OK | — |
| 51 | `"Keep sessions"` | cancel_label | OK | — |
| 61 | `"Revoke all sessions"` | confirm_label | OK | — |
| 62 | `"Keep sessions"` | cancel_label | OK | — |
| 81 | `"Session revoked."` | success (flash) | OK — brand book exemplar matches this exact form | — |
| 89 | `"All active sessions revoked."` | success (flash) | OK | — |
| 105 | `Identity & Status` | kicker | OK | — |
| 119 | `MFA` | dt | OK | — |
| 121 | `Passkeys` | dt | OK | — |
| 124 | `Active` | dt | Ambiguous: "Active" could mean active sessions, active status, or active date. Heading context is the summary-facts strip at top of user detail; it refers to session count. | Rename to `Sessions` (the `<section>` below already has that heading). Planner discretion — could also remain; flag for decision. |
| 126 | `Last seen` | dt | OK | — |
| 141 | `Sessions` | heading (section) | OK | — |
| 151–155 | `Revoke all sessions` | button | OK | — |
| 162 | `Type` | th | OK | — |
| 163 | `IP address` | th | OK | — |
| 164 | `Last activity` | th | OK | — |
| 165 | `Action` | th | OK | — |
| 185 | `Revoke session` | button | OK | — |
| 193 | `"No active sessions."` | empty-scope heading | Trailing period on empty_state title is inconsistent — all other empty_state titles in the codebase have no trailing period. | `"No active sessions"` |
| 193 | `"This user does not have a currently visible session in this scope."` | empty-scope body | OK — explains scope boundary | — |
| 198 | `Security` | heading | OK | — |
| 200 | `MFA` | dt | OK | — |
| 204 | `Passkeys` | dt | OK | — |
| 211 | `Identities` | heading | OK | — |
| 213–215 | `"Linked identities are not available for this app."` | empty-scope | OK — explains why empty | — |
| 224 | `"No linked identities"` | empty-scope heading | OK | — |
| 224 | `"This user signs in without a visible external identity provider."` | empty-scope body | OK — explains scope boundary | — |
| 229–231 | `Organizations` | heading | OK | — |
| 231 | `"Tenant memberships and scoped support pivots for this user."` | body | OK | — |
| 237 | `Organization` | label (meta-label) | OK | — |
| 247 | `"Open organization-scoped view for {organization.organization_name}"` | label (button) | Verbose but informative. Acceptable. OK | — |
| 251 | `"No organization memberships"` | empty-scope heading | OK | — |
| 251 | `"This account is not currently attached to a tenant."` | empty-scope body | `account` as person-noun — and this is a global surface (user detail), so "user" is correct | `"This user is not a member of any organization."` |
| 258 | `Recent Audit` | heading | Capitalizes "Audit" inconsistently — all other `<h2>` headings use sentence case (first word only). | `Recent audit` |
| 259–261 | `"Recent activity stays aligned with the full scoped audit history for this user."` | body | Voice: "stays aligned" is weak. Per D-03: plain, active. | `"Shows the most recent events. Open the full audit to filter and export."` |
| 264 | `View full audit` | label (link) | OK — verb-first | — |
| 271 | `"No recent audit activity"` | empty-first-use heading | OK | — |
| 271 | `"No scoped events are currently tied to this user."` | empty-first-use body | OK | — |
| 277 | `Danger Zone` | heading | Title case inconsistency — sentence case used elsewhere; "Danger Zone" is a conventional section name, planner discretion whether to keep as proper noun or lower. Flag only. | Planner discretion |
| 278 | `"Session revocation uses Sigra's canonical session APIs."` | body | Leaks internal implementation detail ("Sigra's canonical session APIs"). D-03: no leaked internals. | `"Revoking a session signs the user out of that device immediately."` |
| 280 | `"Support actions affect {@detail.danger_zone.impersonation_target_label} in {@detail.scope_label}."` | body | Dynamic — OK, informative about blast radius. | — |
| 290 | `Start impersonation` | button | OK | — |
| 300 | `Revoke all sessions` | button | OK | — |
| 305 | `"End impersonation before starting another session."` | notice | OK — clear next action | — |
| 357–358 | `"Restore config defaults?"` | confirm heading | OK | — |
| 502 | `{:risk, "Locked — revoke active logins and unlock below."}` | notice (error) | `logins` — banned term (D-02: "login" as noun banned; "sign-in" is canonical). | `{:risk, "Locked — revoke active sessions and unlock below."}` |
| 505 | `{:warn, "Email unconfirmed — the user cannot complete sign-in."}` | notice (warning) | `sign-in` is correct hyphenated modifier form. OK. | — |
| 508 | `{:warn, "No MFA configured — recommend enabling a second factor."}` | notice (warning) | Voice: "recommend" is passive. D-03: "make next step obvious." | `{:warn, "No MFA configured — ask the user to set up a second factor."}` |

**user_show_live.ex summary:** 7 violations/improvements — `account` (line 251), `logins` (line 502), leaked internal (line 278), trailing period on empty_state title (line 193), heading case (line 258), passive voice recommendation (line 508), weak body copy (line 259).

---

### `lib/sigra/admin/live/branding_live.ex`

**Note:** Lines 580–610 (the `sigra-auth--preview` div) are CARVED OUT — do not touch.

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 82 | `"Auth branding"` | page_title | OK | — |
| 99 | `Branding` | kicker | OK | — |
| 100 | `Auth forms and emails` | heading | OK | — |
| 101–103 | `Tune the generated login, account, invitation, and transactional email defaults without replacing the host-owned templates.` | body | `login` as noun (banned per D-02; canonical is "sign-in"). | `Tune the generated sign-in, account, invitation, and transactional email defaults without replacing the host-owned templates.` |
| 106 | `"Global auth/email profile"` | scope_ribbon | OK | — |
| 119 | `Unsaved preview` | status | OK | — |
| 122 | `Brand tokens` | heading | OK | — |
| 123 | `Source: {source_label(@profile_source)}` | body | OK | — |
| 129–147 | `Light` / `Dark` / `Details` | nav tabs | OK | — |
| 169–171 | `Light palette` | fieldset legend | OK | — |
| 171 | `Shown on generated auth screens when Light is selected.` | body | OK | — |
| 203–205 | `Dark palette` | fieldset legend | OK | — |
| 205 | `Shown when Dark is selected, or when System resolves dark.` | body | OK | — |
| 238–239 | `Profile details` | heading | OK | — |
| 239 | `Controls identity, links, email sender defaults, and the generated theme mode.` | body | OK | — |
| 245 | `"Product name"` | field label | OK | — |
| 251 | `"Logo URL"` | field label | OK | — |
| 253 | `"Shown on generated auth screens and email headers when set. Use an absolute URL that email clients can load."` | help | OK | — |
| 257 | `"Logo alt text"` | field label | OK | — |
| 259 | `"Used when a logo is shown. Keep it short, like \"Acme logo\"."` | help | OK | — |
| 263 | `"Theme mode"` | field label | OK | — |
| 266–268 | `"System"` / `"Light"` / `"Dark"` | options | OK | — |
| 267 | `"System follows the user's device setting. Light or Dark forces generated auth screens into that theme."` | help | OK | — |
| 273 | `"Support URL"` | field label | OK | — |
| 274 | `"Adds a Support link to generated auth screen footers. Leave blank to hide it."` | help | OK | — |
| 278 | `"Privacy URL"` | field label | OK | — |
| 279 | `"Adds a Privacy link to generated auth screen footers. Leave blank to hide it."` | help | OK | — |
| 283 | `"Terms URL"` | field label | OK | — |
| 284 | `"Adds a Terms link to generated auth screen footers. Leave blank to hide it."` | help | OK | — |
| 296 | `"Email from name"` | field label | OK | — |
| 297 | `"Display name recipients see on generated auth emails."` | help | OK | — |
| 301 | `"Email from address"` | field label | OK | — |
| 303 | `"Sender address for generated auth emails. Use an address your mailer is allowed to send from."` | help | OK | — |
| 306 | `"Reply-to"` | field label | OK | — |
| 307 | `"Replies go to this address when set. Leave blank to use the sender address."` | help | OK | — |
| 327 | `Save profile` | button | OK — verb-first | — |
| 333 | `Discard changes` | button | OK | — |
| 340 | `Restore config defaults` | button | OK — specific, verb-first | — |
| 356 | `"Restore defaults?"` | confirm heading | OK | — |
| 357–359 | `This removes the saved admin branding changes and uses the app's configured defaults for generated auth screens and emails. Unsaved preview changes will also be discarded.` | confirm-copy | OK — concrete risk + blast radius | — |
| 363 | `Cancel` | cancel_label | OK | — |
| 370 | `Restore defaults` | confirm_label | OK — matches heading | — |
| 425 | `"Auth branding profile saved."` | success (flash) | OK | — |
| 448 | `"Unsaved branding changes discarded."` | success (flash) | OK | — |
| 477 | `"Auth branding restored to config defaults."` | success (flash) | OK | — |
| 583 | `Login preview` | **admin chrome heading** (outside carve-out) | `Login` as noun — banned (D-02); this is admin chrome labeling the preview widget, not inside the auth replica. | `Sign-in preview` |
| 601 | `<h1>Log in</h1>` | **CARVED OUT (line 601, inside sigra-auth--preview)** | Carve-out applies — do NOT touch | — |
| 602 | `Use a magic link, passkey, password, or enterprise SSO.` | **CARVED OUT** | — | — |
| 605 | `Send magic link` | **CARVED OUT** | — | — |
| 614 | `Email preview` | heading (admin chrome) | OK | — |
| 731 | `"Could not save auth branding: #{inspect(reason)}"` | error | Leaks `inspect(reason)` — WR-04 residual. D-03: no leaked internals. | `"Could not save auth branding. Check the values and try again."` (the reason is logged server-side) |

**branding_live.ex summary (outside carve-out):** 3 violations — `login` noun (line 101), `Login preview` heading (line 583), `inspect(reason)` leak (line 731).

---

### `lib/sigra/admin/live/audit_index_live.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 39–43 | `"We couldn't load this audit view. Refresh the page, then try again."` | error | OK — specific operator console error | — |
| 53 | `Audit evidence` | kicker | OK | — |
| 54 | `Audit` | heading | OK | — |
| 61 | `Failures` | filter chip | OK | — |
| 76 | `Impersonation` | filter chip | OK | — |
| 84 | `Actor` | field label | OK | — |
| 89 | `Effective user` | field label | OK | — |
| 94 | `Action prefix` | field label | OK | — |
| 99 | `"e.g. auth or admin.impersonation"` | placeholder | OK — internal codes, in code-input context | — |
| 105 | `Outcome` | field label | OK | — |
| 107–112 | `Any` / `Success` / `Failure` | options | OK | — |
| 117 | `Occurred from` | field label | OK | — |
| 122 | `Occurred to` | field label | OK | — |
| 129 | `Apply filters` | button | OK | — |
| 130 | `Clear` | button | OK | — |
| 131 | `Export CSV` | button | OK | — |
| 157 | `Occurred` | th | OK | — |
| 158 | `Event` | th | OK | — |
| 159 | `Actor` | th | OK | — |
| 160 | `Outcome` | th | OK | — |
| 183 | `Actor: {row.actor_label}` | body | OK — impersonation context label | — |
| 184 | `Effective user: {row.effective_user_label}` | body | OK | — |
| 205 | `"No audit events match this view"` | empty-filtered heading | OK | — |
| 207 | `"No audit events match the active filters. Clear one or more to widen the timeline."` | empty-filtered | OK | — |
| 209 | `Clear all filters` | label | OK | — |
| 212 | `"Audit events appear here as activity is recorded. Adjust the filters above to focus on a specific actor, outcome, or time range."` | empty-first-use | OK — explains what populates the surface | — |
| 226 | `aria-label="Previous page"` | aria | OK | — |
| 234 | `aria-label="Next page"` | aria | OK | — |
| 270 | `"Global audit explorer"` | scope_ribbon | OK | — |
| 268 | `"Organization-scoped audit explorer for #{name}"` | scope_ribbon | OK | — |

**audit_index_live.ex summary:** 0 violations. All strings compliant.

---

### `lib/sigra/admin/live/audit_user_live.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 25 | `"User audit"` | page_title | OK | — |
| 50–55 | `"We couldn't load this user's audit history. Refresh the page, then try again."` | error | OK — specific operator console error | — |
| 70 | `User audit evidence` | kicker | OK | — |
| 71 | `{@detail.display_name || @detail.user.email}` | heading | OK (dynamic) | — |
| 72–74 | `Filter this user's scoped event history, distinguish support actions from user actions, and export evidence.` | body | OK | — |
| 86–87 | `Failures` | filter chip | OK | — |
| 100–101 | `Impersonation` | filter chip | OK | — |
| 113 | `Action prefix` | field label | OK | — |
| 118 | `"e.g. session or admin.impersonation"` | placeholder | OK | — |
| 123 | `Outcome` | field label | OK | — |
| 125–130 | `Any` / `Success` / `Failure` | options | OK | — |
| 134 | `Actor` | field label | OK | — |
| 139 | `Occurred from` | field label | OK | — |
| 144 | `Occurred to` | field label | OK | — |
| 153 | `Apply filters` | button | OK | — |
| 154 | `Clear` | button | OK | — |
| 155 | `Export CSV` | button | OK | — |
| 186 | `Occurred` | th | OK | — |
| 187 | `Event` | th | OK | — |
| 188 | `Actor` | th | OK | — |
| 189 | `Outcome` | th | OK | — |
| 211 | `Actor: {@row.actor_label}` | body | OK | — |
| 212 | `Effective user: {@row.effective_user_label}` | body | OK | — |
| 234 | `"No audit events for this user"` | empty-scope heading | OK | — |
| 235 | `"No scoped events are currently tied to this user."` | empty-scope body | OK — explains scope boundary | — |
| 239 | `Clear all filters` | label | OK | — |
| 256 | `Page {@meta.current_page || 1}` | nav | OK | — |
| 426 | `"Global audit explorer"` | scope_ribbon | OK | — |
| 424 | `"Organization-scoped audit explorer for #{name}"` | scope_ribbon | OK | — |

**audit_user_live.ex summary:** 0 violations. All strings compliant.

---

### `lib/sigra/admin/components.ex`

| Line | Current string | Type | Violation | Canonical replacement |
|------|---------------|------|-----------|----------------------|
| 376–378 | `aria-label={"Remove filter " <> @label}` | aria | OK — programmatic, not visible copy | — |
| 379 | `remove` (sr-only) | sr-only | OK | — |
| 376 | Component doc examples contain "account" in non-person contexts. | doc strings | Docs are not visible admin copy — not in scope for glossary enforcement. | — |

**components.ex summary:** 0 violations in visible rendered strings.

---

## Expanded Glossary Table

The D-02 seed table covers the core concepts. The string inventory surfaces several additional concepts that need canonical terms to prevent future drift:

| Concept | Canonical | Banned synonyms | Notes |
|---|---|---|---|
| Global identity (the login) | **user** | account (as person), member (on global surfaces) | D-02 |
| A user's seat in one org | **member** (rel. = *membership*) | user (in org surfaces), seat, teammate, collaborator | D-02 |
| The tenant | **organization** (spelled out) | org (in visible copy); org is OK in code/URL slugs/identifiers | D-02 |
| Auth action (verb) | **sign in** / **sign out** (two words) | log in, login (verb), signin, log out, logout, sign off | D-02 |
| Auth action (modifier/noun) | **sign-in** (hyphenated) | login (noun), signin | D-02 |
| Take a member out of an org | **remove** | delete a member, revoke a member | D-02 |
| Destroy the identity | **delete** (user/account) | remove, destroy | D-02 |
| End a session / API key / sent invitation | **revoke** | delete, remove, cancel | D-02 |
| Policy block (reversible, admin-initiated) | **suspend** | deactivate, disable, ban, lock | D-02 |
| Auto-block after failed sign-ins (system, transient) | **lock / unlock** | suspend, disable, freeze | D-02 |
| Stop a pending invitation | **revoke** (sent) / **cancel** (not yet sent) | delete invitation | D-02 |
| Pending join offer | **invitation** (noun) / **invite** (verb) | — | D-02 |
| Authority bundle | **role** (owner/admin/member) | permission (as synonym), access level, group | D-02 |
| Granular capability | **permission** | role, scope (in UI prose) | D-02 |
| A session that has ended | **revoked** / **expired** | deleted, removed, cancelled | New — surfaces in session-empty state copy |
| User who is logged in via impersonation | **impersonated user** / **effective user** | target, victim, subject | New — in audit copy; "effective user" is the established term |
| The admin performing an action | **actor** | admin (ambiguous), user (ambiguous in audit context) | New — established in audit column headers |
| App-level error during form save | (specific message per field) | "Something went wrong", "Oops!", generic flashes | New — D-03/D-04 |
| The auth preview widget in branding page | **sign-in preview** / **email preview** | Login preview (uses banned "login" noun) | New — from branding_live.ex:583 |

---

## Source-Extraction Regexes for `glossary_test.exs`

The ExUnit test reads source files and strips lines that are NOT visible copy before applying word-boundary banned-term matching. Without stripping, Elixir module names, function names, attributes, CSS classes, and test IDs produce false positives.

### Lines to strip (do NOT match against)

Strip these patterns before scanning each line for banned terms:

| Pattern | Rationale | Elixir regex |
|---------|-----------|--------------|
| Lines starting with `defmodule` / `def ` / `defp ` | Function/module declarations contain technical names | `~r/^\s*(defmodule|def\s|defp\s)/` |
| Lines starting with `alias` / `import` / `use` / `require` | Module directives | `~r/^\s*(alias|import|use|require)\s/` |
| Lines starting with `@` | Module attributes, docs, function guards | `~r/^\s*@/` |
| Lines starting with `#` | Comments | `~r/^\s*#/` |
| Lines containing `data-testid=` | Test IDs are kebab-case identifiers | `~r/data-testid=/` |
| Lines containing `data-sg-` | Design-system data attributes | `~r/data-sg-/` |
| Lines containing `class=` | CSS class strings | `~r/class=["']?[^"']*["']?/` (strip the class= attribute value entirely) |
| Lines containing `href=` / `action=` / `phx-` / `name=` / `id=` as HTML attributes | URL strings, event names, input names | `~r/(href|action|phx-\w+|name|input\s+.*name)=/` |
| Lines starting `|>` or containing `|> ` | Pipeline technical expressions | `~r/\|\>/` |
| Lines containing `~r/` | Regex literals | `~r/~r\//` |
| Lines containing `%{` or `%Ecto` or `__struct__` | Struct patterns | `~r/(%\{|%Ecto|__struct__)/ ` |
| Lines containing `inspect(` | Elixir inspect calls | `~r/inspect\(/ ` |
| Lines containing `raise ArgumentError` | Runtime guards | `~r/raise\s+[A-Z]/ ` |
| Lines matching `defp \w+(_\w+)*\(` | Private function heads | `~r/defp \w+/` |
| `attr :` / `slot :` lines | Component attribute declarations | `~r/^\s+(attr|slot)\s+:/` |

### Carve-out region exemption

The test MUST skip the `sigra-auth--preview` region in `branding_live.ex`. Implementation:

```elixir
defp strip_carve_outs(lines, "lib/sigra/admin/live/branding_live.ex") do
  # Skip lines 580–610 (the sigra-auth--preview inner block in preview_pair/1)
  # Detect region by marker strings instead of hard line numbers for robustness:
  # Open: line containing ~"sigra-auth sigra-auth--preview"
  # Close: the matching closing </div> — detected by tracking nesting depth
  # Simpler approach: skip by line range (580..610) which is stable and
  # identified precisely in RESEARCH.md.
  lines
  |> Enum.with_index(1)
  |> Enum.reject(fn {_line, n} -> n in 580..610 end)
  |> Enum.map(fn {line, _n} -> line end)
end

defp strip_carve_outs(lines, _file), do: lines
```

Alternatively, use marker-based detection: once a line is seen containing `data-sg-auth-branding-preview="login"` (line 587 is inside the carve-out), skip until the depth-balanced `</div>` is found. Line-number range (580–610) is simpler and stable per CONTEXT.md D-09.

### Word-boundary matching for banned terms

```elixir
defp banned_terms do
  [
    # D-02 auth verb violations
    {"\\blog\\s*in\\b", "sign in", "login (verb)"},
    {"\\blog\\s*out\\b", "sign out", "logout (verb)"},
    {"\\blogout\\b", "sign out", "logout"},
    {"\\bsignin\\b", "sign in", "signin"},
    {"\\bsign\\s+off\\b", "sign out", "sign off"},
    # D-02 login noun violations
    {"\\blogin\\b", "sign-in", "login (noun)"},
    {"\\blogins\\b", "sessions", "logins (plural)"},
    # D-02 organization abbreviation in visible copy
    # Note: "org" in identifiers/slugs/data attributes already stripped by line patterns above
    # This catches "org" in prose — but requires word-boundary AND context check
    # to avoid flagging "Organization" containing "org" — use negative lookbehind:
    # Actually \borg\b won't match inside "Organization" since \b matches at word boundary.
    {"\\borg\\b(?!anization)", "organization", "org (in visible copy)"},
    # D-02 person-noun violations
    {"\\bteammate(?:s)?\\b", "member(s)", "teammate(s)"},
    {"\\bcollaborator(?:s)?\\b", "member(s)", "collaborator(s)"},
    {"\\bseat\\b", "member", "seat"},
    # Note: "account" is context-sensitive — only flag as person-noun
    # We flag it and let the ExUnit failure output guide the reviewer:
    # {"\\baccount(?:s)?\\b", "user(s) or member(s)", "account (as person-noun)"},
    # ^ Commented: too many legitimate uses ("account takeover", "your account").
    #   The string inventory handles the specific violations manually.
    #   Planner discretion whether to add narrow forms like:
    #   {"\\baccounts?\\s+need", "users/members need", ...}
  ]
end
```

**Planner note on `account`:** The word `account` has legitimate uses in the codebase (security term "account takeover", branding field "email_from_address for generated auth emails", etc.). The inventory identifies the 6 specific `account`-as-person-noun violations by line; the glossary test SHOULD flag `accounts need review`, `risky accounts`, `Review accounts`, `open any user` (already clean after fix). Adding a narrow regex for `\baccounts? need\b` or `\brisky accounts?\b` is feasible; a broad `\baccount\b` ban will generate false positives.

---

## Literal Text Assertions in `admin-checkpoints.spec.ts` Affected by Copy Edits

The following copy edits from the inventory will break literal assertions in the spec. Each row shows the current assertion, the edit that breaks it, and the replacement assertion.

| Spec line | Current assertion | Edit that breaks it | Replacement assertion |
|-----------|------------------|--------------------|-----------------------|
| 214 | `page.getByText('Global user operations')` | None — this string is NOT being changed (it's the scope_ribbon copy on user_show_live.ex:431 and users_index_live.ex:458; both say "Global user operations" which is correct) | No change needed |
| 282, 316 | `page.getByText('Global audit explorer')` | None — this string is correct and NOT being changed | No change needed |
| 215–218 | `page.getByRole('button', { name: 'Revoke session' })` | None — "Revoke session" is correct | No change needed |
| 219–221 | `page.getByRole('button', { name: 'Start impersonation' })` | None — "Start impersonation" is correct | No change needed |
| 243–244 | `page.getByRole('button', { name: 'Start impersonation' })` | None — correct | No change needed |
| 253–256 | `banner.getByRole('button', { name: 'End impersonation' })` | None — correct | No change needed |
| 254 | `banner.toContainText('Impersonating ${targetEmail}')` | None | No change needed |
| 255 | `banner.toContainText('Signed in as ${adminEmail}')` | None | No change needed |
| 266 | `page.getByRole('button', { name: 'End impersonation' })` | None | No change needed |
| 79 | `page.getByRole('link', { name: 'Open user' })` | None — "Open user" correct | No change needed |
| 324 | `impersonationChip.toContainText('Impersonation')` | None | No change needed |
| 326–327 | `failuresChip.toContainText('Failures')` | None | No change needed |
| 332 | `page.getByRole('link', { name: 'Export CSV' })` | None | No change needed |

**Critical finding:** The 15 literal text assertions in `admin-checkpoints.spec.ts` listed in CONTEXT.md D-10 are all on strings that are either (a) already correct and not being changed, or (b) not in the 7 admin LiveViews. The copy violations found in the inventory are on strings NOT currently asserted in the checkpoint spec. Therefore, the checkpoint spec literal assertions do NOT need updating for the copy edits identified.

**Exception — screenshot baselines will still need recapture** because the visual rendering of changed text (even in non-asserted regions) changes pixel content. Affected slugs:

| Slug | Reason |
|------|--------|
| `global-overview` | index_live.ex changes: "accounts need review" → "users need review", "Review accounts" → "Review users", "Review risky accounts" task card title, "Review locked" action |
| `user-detail` | user_show_live.ex changes: "Locked — revoke active logins" → "sessions", "account is not currently attached" → "user is not a member", "Recent Audit" heading, Danger Zone copy |
| `org-overview` | organization_live.ex changes: "accounts need review" → "members need review", "Review accounts" → "Review members", "Search org members" → "organization members", "Investigate org events" → "organization events", "teammates" → "members" |
| `global-user-index` | users_index_live.ex changes: "account" help text, empty-state "accounts exist" copy |
| `org-scoped-admin` | Same users_index_live.ex changes as global-user-index (shared render path) |

Slugs that do NOT need recapture (no copy changes in their visible viewport):
- `impersonation-banner` — CANARY, never allowlist; changes only in user_show_live which is outside the banner viewport
- `user-audit` — audit_user_live.ex has 0 violations
- `audit-explorer` — audit_index_live.ex has 0 violations

**Net affected slugs:** `global-overview`, `user-detail`, `org-overview`, `global-user-index`, `org-scoped-admin` — 5 slugs × 3 projects = 15 PNG baselines to recapture.

---

## `components_test.exs` Goldens Affected by Copy Edits

The components file has 0 visible-string violations. No golden in `components_test.exs` will be broken by Phase 191 edits.

**One indirect consideration:** If the `notice` golden test (line 406, `@notice_golden`) is ever re-used with the `"Locked — revoke active logins and unlock below."` string that lives in `user_show_live.ex:502`, that notice golden would need updating. However, the golden currently uses exactly that string:

```
@notice_golden "...Locked — revoke active logins and unlock below...."
```

So if `user_show_live.ex:502` changes from "logins" to "sessions", the `@notice_golden` module attribute at line 68 of `components_test.exs` also changes. This IS a components_test.exs change needed in the same diff.

**Confirmed components_test.exs change required:**
- Line 68: `@notice_golden` — change `"logins"` to `"sessions"` in the golden string.

---

## Architecture Patterns

### Recapture Wave Sequence (mirroring Phase 183)

1. **Wave 1 — Source edits:** Edit all 7 LiveViews (plus components_test.exs `@notice_golden`). One commit per file or one unified commit — planner discretion.
2. **Wave 2 — Artifacts:** Write `guides/reference/admin-glossary.md` with the expanded glossary table and voice rubric. Write `test/sigra/admin/glossary_test.exs` with the structural strip regexes.
3. **Wave 3 — Ledger:** Update `guides/reference/admin-quality-ledger.md` — add `branding-live` L3 row, re-score D9/D10 axes on existing L3 rows.
4. **Wave 4 — Recapture:** Boot example dev server pre-compiled on PORT=4011, run `npx playwright test --update-snapshots=all` for the 5 affected slugs, restore canary PNGs, run recapture gate.
5. **Wave 5 — Gate:** `scripts/ci/snapshot-recapture-gate.sh global-overview user-detail org-overview global-user-index org-scoped-admin`; reset allowlist to empty after gate passes.

### Glossary Test Architecture

```
test/sigra/admin/glossary_test.exs
├── reads each of the 8 in-scope source files
├── for each file:
│   ├── strip_carve_outs/2 (branding_live.ex:580–610)
│   ├── strip_non_copy_lines/1 (module attrs, defs, classes, data-*, etc.)
│   └── for each remaining line: check banned_terms/0
├── on violation: fail with "file:line — found '#{term}' — use '#{canonical}' instead"
└── ships with library so adopters inherit drift guard
```

### Glossary File Architecture

```
guides/reference/admin-glossary.md
├── ## Canonical Terms (machine-parseable GOV.UK A-Z table)
│   ├── columns: Canonical | Banned synonyms | Context rule | Enforcement
│   └── mirrors | -delimited ledger idiom (glossary_test.exs parses this table)
├── ## Voice Rubric (per D-03/D-04)
│   ├── Cross-cutting gate (all types)
│   ├── Error rubric (+ E-6 enumeration boundary rule)
│   ├── Empty state rubric (4 subtypes)
│   ├── Success rubric
│   └── Warning/destructive confirm rubric
└── ## Exemplars (compliant copy from the codebase)
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Glossary enforcement | Custom bash grep guard | ExUnit test with structural strip (D-07) |
| Snapshot recapture approval | Human HTML report review | `snapshot-recapture-gate.sh` + canary guard (D-10) |
| Ledger monotonic enforcement | Manual tier tracking | `quality-ledger-monotonic.sh` (existing) |

---

## Common Pitfalls

### Pitfall 1: `account` over-rejection
**What goes wrong:** A broad `\baccount\b` regex in `glossary_test.exs` flags "account takeover risk" (help text), `email_from_address` doc strings, and "your account" in first-person contexts — none of which are violations.
**Why it happens:** "account" is ambiguous — security idiom vs person-noun.
**How to avoid:** Do NOT add `account` to the automated banned-terms list. Handle the 6 specific person-noun violations by file:line edit; they will then be gone from the source. Only add narrow forms like `\baccounts need\b` if desired.
**Warning signs:** glossary_test.exs produces >20 failures on the first run.

### Pitfall 2: `org` false positives from word boundary
**What goes wrong:** `\borg\b` matches "org" inside "Organization" is wrong — but actually `\b` only matches at word boundaries, so `\borg\b` does NOT match inside "Organization". However, it will match `org.` in `Scope{organization_slug: slug}` in function heads, and `org_name` variable names.
**How to avoid:** The structural strip (removing `def`/`defp` lines and attribute lines) removes these. Verify the strip is applied before the regex scan, not after.
**Warning signs:** Failures on lines clearly inside function heads.

### Pitfall 3: Canary PNG accidentally allowlisted
**What goes wrong:** Rushing the recapture step and adding `impersonation-banner` or `board-notice` to the allowlist.
**How to avoid:** The allowlist explicitly documents "The `impersonation-banner` canary must NEVER appear here." The recapture gate script checks this.
**Warning signs:** `snapshot-canary-guard.sh` exits 0 but you added a canary slug.

### Pitfall 4: WR-04 `inspect` leak re-introduced
**What goes wrong:** The catch-all `defp error_message(reason), do: "Could not save auth branding: #{inspect(reason)}"` at branding_live.ex:731 remains after the pass.
**How to avoid:** Edit this line as part of branding_live.ex copy edits. Replace with a generic message.
**Warning signs:** Glossary test won't catch this (`inspect` is stripped). Must be caught by code review or a separate guard rule for `inspect(` in non-stripped copy.

### Pitfall 5: Carve-out boundary drift
**What goes wrong:** An edit touches lines 580–579 (admin chrome just before the carve-out) and accidentally also edits line 583's "Login preview" heading while thinking it's part of the carve-out.
**How to avoid:** The carve-out starts at line 584 (the `<div class="sigra-auth sigra-auth--preview">`), NOT line 583. Line 583's `<h2>Login preview</h2>` is admin chrome and MUST be changed.
**Warning signs:** Reviewing the diff and seeing line 583 unchanged after the edit pass.

---

## Runtime State Inventory

This phase is copy/content editing only — no schema changes, no renamed identifiers, no migrations. Step 2.6 applies:

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — no string constants stored in DB | None |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

---

## Environment Availability

This phase edits `.ex` source files and runs `mix test` + Playwright. Prerequisites are the same as Phase 190.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/mix | `mix test` (glossary_test.exs) | Expected ✓ | ~1.18 | — |
| PostgreSQL | `mix test` (integration tests) | Expected ✓ | 15.x | docker container per CLAUDE.md |
| Node.js / npm | Playwright recapture | Expected ✓ | — | — |
| Example dev server (PORT=4011) | `snapshot-recapture-gate.sh` | Needs pre-compile + boot | — | Boot per Phase 183 procedure |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (existing) + Playwright (existing) |
| Glossary test file | `test/sigra/admin/glossary_test.exs` (new, Wave 2) |
| Quick run command | `mix test test/sigra/admin/glossary_test.exs` |
| Full suite command | `mix test` |
| Playwright gate | `scripts/ci/snapshot-recapture-gate.sh global-overview user-detail org-overview global-user-index org-scoped-admin` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COPY-01 | No banned terms in visible admin copy | Unit (source parse) | `mix test test/sigra/admin/glossary_test.exs` | ❌ Wave 2 gap |
| COPY-01 | Error copy follows D-03/D-04 rubric | Manual + review | Code review of inventory edits | — |
| COPY-01 | No `inspect()` leaks in error copy | Unit (source parse) | `mix test test/sigra/admin/glossary_test.exs` (add inspect rule) | ❌ Wave 2 gap |
| COPY-02 | Glossary committed at `guides/reference/admin-glossary.md` | Static artifact | `test -f guides/reference/admin-glossary.md` | ❌ Wave 2 gap |
| COPY-02 | No synonym drift: banned terms absent from source | Unit | `mix test test/sigra/admin/glossary_test.exs` | ❌ Wave 2 gap |
| COPY-03 | Empty-state copy consistent across surfaces | Review + ExUnit | Glossary test + code review | — |
| COPY-03 | `components_test.exs` golden matches updated notice string | Unit | `mix test test/sigra/admin/components_test.exs` | ✅ (needs 1 golden update) |
| D-11 | `branding-live` L3 row in quality ledger | Static artifact | `quality-ledger-monotonic.sh` | ❌ Wave 3 gap |
| D-10 | Checkpoint baselines match updated copy | Visual regression | `snapshot-recapture-gate.sh ...` | ❌ Wave 4 gap |

### Sampling Rate
- **Per-task commit:** `mix test test/sigra/admin/glossary_test.exs test/sigra/admin/components_test.exs`
- **Per-wave merge:** `mix test`
- **Phase gate:** Full suite + `snapshot-recapture-gate.sh` for 5 slugs green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/admin/glossary_test.exs` — new; covers COPY-01/COPY-02 (Wave 2)
- [ ] `guides/reference/admin-glossary.md` — new; canonical term table + voice rubric (Wave 2)
- [ ] `guides/reference/admin-quality-ledger.md` — needs `branding-live` L3 row + D9/D10 re-score (Wave 3)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No — copy pass only | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | — |
| V6 Cryptography | No | — |

### E-6 Enumeration Boundary Rule (D-04)

The E-6 rule is a **security-critical constraint** that MUST be preserved by the copy pass:

> At the auth/enumeration boundary (login, reset, magic link, "does this account exist") the message MUST be **uniform and generic** — vagueness is required, specificity is forbidden.

**In-scope copy for Phase 191:** The 7 admin LiveViews are **operator-console surfaces** — they are behind authentication and restricted to trusted operators. ALL operator-console errors are the "specific" branch of E-6 (operators are trusted engineers; vagueness wastes their time).

**No enumeration-boundary strings exist in the 7 admin LiveViews.** The auth boundary strings live in the host-generated templates under `priv/templates/sigra.install/` which are explicitly out of scope (D-08).

**Threat note:** The copy edits in this phase (relabeling, rewording notices) carry zero behavioral change. No API endpoints, access controls, rate limits, or token handling are modified. The blast radius is cosmetic only.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `@notice_golden` in `components_test.exs` at line 68 contains "logins" (matching user_show_live.ex:502) | components_test.exs impact section | If the golden uses a different string, no change needed there — verify by reading line 68 of components_test.exs (confirmed: `"Locked — revoke active logins and unlock below."` appears in the golden) | 
| A2 | `user_show_live.ex:502` is the only source of the "logins" string that feeds a golden | components_test.exs impact section | If other goldens reference "logins", they also need updating | 
| A3 | The 5 affected checkpoint screenshot slugs cover all viewports that render the changed strings | Recapture section | If the changed strings appear in other slugs not listed, those baselines also drift and CI fails |

**All claims A1–A3 were verified by reading source files directly; risk is LOW.**

---

## Open Questions (RESOLVED)

1. **`quick_filter` chip auto-humanizer (users_index_live.ex:409)**
   - What we know: `String.replace(@key, "_", " ")` produces chip labels "confirmed", "mfa", "passkeys", "locked", "deleted", "needs review" from the `@quick_filter_keys` list.
   - What's unclear: "deleted" as a filter chip label vs "Deletion scheduled" as the status pill on the same row is inconsistent (one says "deleted", the other says "Deletion scheduled"). Is this worth fixing in 191?
   - Recommendation: Yes — change the `chip_label` fallback for "deleted" to "Deletion scheduled" (consistent with the pill and the summary_chip label). One-line fix in the `chip_label/2` function at line 557. But the auto-humanizer at line 409 only runs for the checkbox display — add an explicit `chip_label("deleted", nil)` clause.
   - **RESOLVED: folded into Plan 02 as a COPY-03 coherence edit.**

2. **`summary_alert/1` line 508 voice improvement**
   - What we know: `"No MFA configured — recommend enabling a second factor."` uses passive "recommend" per D-03 concern.
   - What's unclear: The second half is addressed to... whom? The operator reads this, but they can't configure MFA for the user — only recommend the user do it.
   - Recommendation: `"No MFA configured — ask the user to enable a second factor."` — clearer about who takes the action.
   - **RESOLVED: already fixed in Plan 02 (active-voice rewrite).**

3. **`user_show_live.ex:124` — `Active` dt label**
   - What we know: "Active" in the summary-facts strip refers to the count of active sessions. The Sessions section below has the same data.
   - What's unclear: Is this redundancy intentional (summary strip = at-a-glance, section = detail)?
   - Recommendation: Keep as-is but rename to `Sessions` for clarity. Planner should evaluate whether this is a scope creep (structural concern) vs pure copy.
   - **DEFERRED: borderline structural relabel, not required for COPY-01/02/03; out of this phase's copy-only scope — capture for a later pass if desired.**

---

## Sources

### Primary (HIGH confidence — direct source file reads)
- `lib/sigra/admin/live/index_live.ex` — complete read
- `lib/sigra/admin/live/organization_live.ex` — complete read
- `lib/sigra/admin/live/users_index_live.ex` — complete read
- `lib/sigra/admin/live/user_show_live.ex` — complete read
- `lib/sigra/admin/live/branding_live.ex` — complete read; carve-out lines 580–610 confirmed
- `lib/sigra/admin/live/audit_index_live.ex` — complete read
- `lib/sigra/admin/live/audit_user_live.ex` — complete read
- `lib/sigra/admin/components.ex` — complete read
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — complete read; all literal text assertions catalogued
- `test/sigra/admin/components_test.exs` — complete read; all goldens catalogued
- `guides/reference/admin-quality-ledger.md` — complete read; current state confirmed
- `.planning/phases/191-microcopy-ia-sweep/191-CONTEXT.md` — complete read
- `.planning/REQUIREMENTS.md` — complete read
- `brandbook/brand-book.md` lines 183–251 — voice system confirmed
- `guides/reference/admin-fractal-scorecard.md` lines 28–36 — D9/D10 axes confirmed

## Metadata

**Confidence breakdown:**
- String inventory: HIGH — read every source line directly
- Glossary expansion: HIGH — derived from source + CONTEXT.md D-02 seed
- Regex strategy: HIGH — derived from Elixir/HEEx source patterns
- Playwright assertion impact: HIGH — read complete spec file
- Components golden impact: HIGH — read complete test file; confirmed @notice_golden content

**Research date:** 2026-06-17
**Valid until:** Stable — copy is static until next source edit; no external dependencies
