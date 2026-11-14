# Admin Glossary

> This glossary is enforced by `test/sigra/admin/glossary_test.exs` which runs in `mix test`. Adopters who customize generated admin copy inherit the same drift guard.

Canonical term table and voice rubric for the Sigra admin interface. One concept, one term — no synonyms in visible admin copy. The `Enforcement` column distinguishes machine-checked terms from those requiring editorial judgment.

---

## Canonical Terms

| Canonical | Banned synonyms | Context rule | Enforcement |
|-----------|-----------------|--------------|-------------|
| **user** | account (as person-noun), member (on global/platform surfaces) | Global surface: the identity record — outside any org context, always "user". First-person self-service copy ("your account settings") is the only legitimate use of "account". | editorial |
| **member** (relationship = *membership*) | user (inside org surfaces), seat, teammate, collaborator | Org surface: a user's role-bearing seat inside one organization. Use "member" on all org-scoped pages. The relationship noun is "membership". | glossary_test.exs |
| **organization** (spelled out) | org (in visible copy); org is permitted only in code / URL slugs / Elixir identifiers | All surfaces: "organization" in any visible label, heading, body text, or notice. "org" is acceptable in function names, URL path segments, and data attributes. | glossary_test.exs |
| **sign in** (verb, two words) | log in, login (as verb), signin, sign off | All surfaces: the auth action as a verb. Two words, no hyphen: "the user can sign in". | glossary_test.exs |
| **sign out** (verb, two words) | log out, logout (as verb), sign off | All surfaces: ending a session as a verb. Two words: "this signs them out". | glossary_test.exs |
| **sign-in** (modifier/noun, hyphenated) | login (noun), signin, log-in | All surfaces: the session or process used as a modifier or noun: "failed sign-in attempt", "sign-in page". Hyphen required. | glossary_test.exs |
| **remove** | delete a member, revoke a member | Org surface: taking a user out of an organization ends the membership; the user identity is not destroyed. | editorial |
| **delete** | remove (when destroying the identity), destroy | Global surface: permanently destroying the user identity and all associated data. | editorial |
| **revoke** | delete, remove, cancel (for live sessions/keys/sent invitations) | All surfaces: ending an active session, API key, or sent invitation. "Revoke session", "revoke invitation". | editorial |
| **suspend** | deactivate, disable, ban, lock (when admin-initiated and reversible) | All surfaces: a policy-based, operator-initiated block. Reversible: the operator unsuspends. Not the same as system lock. | editorial |
| **lock / unlock** | suspend, disable, freeze (when auto-triggered by failed sign-in attempts) | All surfaces: the system-initiated transient block after repeated sign-in failures. Automatically cleared or manually unlocked by an operator. | editorial |
| **revoke** (sent invitation) / **cancel** (not yet sent) | delete invitation | All surfaces: "revoke" applies to an invitation that has been sent and is pending; "cancel" applies before sending. Never "delete invitation". | editorial |
| **invitation** (noun) / **invite** (verb) | — | All surfaces: the pending join offer is an "invitation"; the verb is "invite". | editorial |
| **role** | permission (as synonym for role), access level, group | All surfaces: the authority bundle (owner / admin / member). Use "role" when naming the bundle. | editorial |
| **permission** | role (when describing granular capabilities), scope (in UI prose) | All surfaces: a granular capability within a role. Use "permission" when describing individual access rights, never "role" or "scope" in copy. | editorial |
| **sessions** (plural) | logins (plural noun) | All surfaces: the set of active authenticated sessions for a user. Never "logins". | glossary_test.exs |
| **sign-in preview** / **email preview** | Login preview, login preview | All surfaces: admin chrome label for the branding preview widget in branding_live. The heading "Login preview" is a violation — use "Sign-in preview". | glossary_test.exs |
| **effective user** / **impersonated user** | target, victim, subject (in audit context) | Audit surfaces: the user being acted on during an impersonation session. "effective user" is the established term in audit column headers. | editorial |

**Boundary rule — user vs member:**
- Global / platform surfaces (no org context) → `user`
- Inside an organization's surface → `member`
- "account" as a person-noun in admin chrome → **banned**; first-person self-service copy ("your account settings") is the only acceptable use.

**Security idiom exception:** "account takeover" is a compound security phrase (industry-standard terminology, not a person-noun) and is **not** a violation of the account ban. Do not flag it.

## Brand book v2.0 reconciliation

The brand book v2.0 (2026-11-13) is kept read-only in `brand/`. This section sets its vocabulary (`voice.terms` in `brand/brand.json`, and the wording its open risks flag) beside the Canonical Terms above. Each row opens its Context rule with **Agrees** (the glossary already says the same) or **Differs** (the book and the glossary disagree, or the book names a word or state the glossary has no row for), and says which wording governs Sigra-owned copy. The ownership lanes are in `guides/reference/brand-compatibility.md`; the demo app in `test/example` is a host, so its own wording sits outside Sigra's copy lane.

Product-truth anchors are written as a full repo path and a line number. `test/sigra/brand/vocabulary_docs_test.exs` checks that each anchor names a real file and line, and that the line still holds the term the row cites.

| Canonical | Banned synonyms | Context rule | Enforcement |
|-----------|-----------------|--------------|-------------|
| **user** | account (as a person), customer, end user | Agrees with the book: the identity record, on screens outside any organization. The book's avoid list adds "customer" and "end user"; the glossary bans both in its Voice Rubric rather than in this row. The glossary row also bans "member" on global surfaces, a rule the book puts on its Member row. | `test/sigra/brand/copy_contract_test.exs` ("customer" and "end user" in the admin scope); editorial for "account" |
| **member** (relationship: membership) | seat, teammate, collaborator | Agrees with the book: a user's seat with a role inside one organization, and the relationship is a membership. The glossary also bans "user" on organization surfaces, which the book does not say. | `test/sigra/admin/glossary_test.exs` ("seat", "teammate" and "collaborator" in admin source files) |
| **organization** (spelled out) | org, workspace, tenant | Differs from the book by two words. Both spell "organization" out in anything a person reads and keep "org" for code and URLs. The book also bans "workspace" and "tenant"; the glossary row does not, and its Voice Rubric uses "tenant" when it talks about blast radius. For visible Sigra-owned copy the book's longer list governs; the Voice Rubric wording is guidance for writers and is left as it is. | `test/sigra/admin/glossary_test.exs` ("org"); `test/sigra/brand/copy_contract_test.exs` ("workspace" and "tenant" in the admin scope) |
| **sign in** / **sign out** (verbs) | log in, login, log out, logout | Agrees with the book: both spell the verbs as two words and the noun or modifier with a hyphen, and Sigra-owned copy says "sign in" and "sign out". The glossary also bans "signin" and "sign off" by name; the book does not. The demo host's own "Log in" wording (`test/example/lib/example_web/controllers/session_html.ex:58`) is host-owned and outside Sigra's copy lane, so it is not a defect in Sigra copy. Phoenix's `phx.gen.auth` documentation says "log in"; the book keeps "sign in" and flags the mix. | `test/sigra/admin/glossary_test.exs` (admin source files); `test/sigra/brand/copy_contract_test.exs` (admin and generated copy) |
| **session** | logins | Agrees with the book: one signed-in browser or device. Both say "sessions", never "logins", and both lists carry the same word. | `test/sigra/admin/glossary_test.exs` ("logins" in admin source files) |
| **revoke** | delete, cancel | Differs from the book on one word. Both say revoke ends a live session, API key or sent invitation, and both ban "delete" there. The book bans "cancel" without qualification; the glossary keeps "cancel" for an invitation that has not been sent yet (its own row in the Canonical Terms table above) and also bans "remove" here. For Sigra-owned copy the glossary governs: "Revoke session", "Revoke invitation" once it is sent, "cancel" only before sending. | editorial |
| **delete** | destroy, remove (for the user) | Agrees with the book: delete permanently destroys the user and all associated data. Taking a member out of an organization is not a delete; see the next row. | editorial |
| **remove** (a member leaves an organization) | delete a member, revoke a member | Agrees with the book: taking a member out of an organization is "remove". The membership ends and the user identity survives. "Delete" is for destroying the identity, and "revoke" is for sessions, API keys and sent invitations. The glossary also bans "delete a member" and "revoke a member" by name; the book does not. | editorial |
| **suspend** (state shown as **Suspended**) | deactivate, disable, ban | Differs from the book, which draws a Suspended status. Suspended is an admin action that does not exist: Sigra has no suspend control and no Suspended state, and the brand adoption does not build one, so no Suspended copy may appear on a shipped surface. The glossary row for "suspend" stays as vocabulary for a future admin action; it does not describe a control that exists today. | editorial |
| **lock** / **unlock** (state shown as **Locked**) | freeze, suspend | Agrees with the book: Locked is the system state, set after repeated failed sign-in attempts, and it clears by itself when the configured duration ends (`lib/sigra/lockout.ex:8`). It is not an admin action. The book adds that an admin can unlock it; the admin interface has no unlock control today, and the shipped risk text "Locked — revoke active sessions and unlock below." (`lib/sigra/admin/live/user_show_live.ex:385`) points at one that is not there. The status pill reads "Locked" (`lib/sigra/admin/live/user_show_live.ex:335`). The glossary also bans "disable" for this state; the book does not. | `test/sigra/brand/copy_contract_test.exs` ("freeze" in the admin scope); editorial for "suspend" and "disable" |
| **Deletion scheduled** (pending-deletion status label) | Deleting | Differs from the book, which writes "Deleting" for a user scheduled for deletion. Sigra keeps "Deletion scheduled" because it names a reversible grace period; a label that reads as immediate deletion would misdescribe it. The shipped pill already says "Deletion scheduled" (`lib/sigra/admin/live/user_show_live.ex:336`). | editorial |
| **Active**, **Unconfirmed**, **Locked** (user status words) | Confirmed (as a user status) | Differs from the book: the glossary has no status row, and the shipped confirmed pill does not use the book's word. The target vocabulary is Active, Unconfirmed and Locked, with "Deletion scheduled" as the separate pending-deletion label (row above); a status is always written as a word, and its mark and color support the word. This is the target, not the current product. The shipped pill still reads "Confirmed" for a confirmed user and "Unconfirmed" for an unconfirmed one (`lib/sigra/admin/live/user_show_live.ex:332`), and "Active" is no status pill: its shipped use for people is the stat label "Active users" (`lib/sigra/admin/live/index_live.ex:96`). Aligning the pill is a later copy change (Phase 262) and is not done here. | editorial |
| **role** and **permission** | access level, group, scope | Agrees with the book, which keeps both in one row: a role is a bundle of authority (owner, admin, member) and a permission is one capability within it. The glossary splits them into two rows; between them they ban the book's three words, "access level", "group" and "scope". | `test/sigra/brand/copy_contract_test.exs` ("access level" in the admin scope); editorial for "group" and "scope" |
| **effective user** | target, victim, subject | Agrees with the book: in an audit log, the user an admin was acting as while impersonating, and the actor is the admin. Both ban "target", "victim" and "subject" in that context. | `test/sigra/brand/copy_contract_test.exs` ("victim" in the admin scope); editorial for "target" and "subject" |
| **Confirm it's you again** (the sudo-mode prompt) | sudo mode, re-authenticate, step-up | Differs from the book, because the glossary has no row for this term and the book calls its wording a recommendation that is not found in the product today. The book's wording is the recommended wording for screens; "sudo mode" stays a code and documentation term. This table changes no shipped screen. | `test/sigra/brand/copy_contract_test.exs` ("sudo mode", "re-authenticate" and "step-up" in the admin scope) |
| **backup codes** | recovery codes (unchecked) | Differs from the book, because the glossary has no row for this term. The book calls "backup codes" the product's own word and avoids "recovery codes", noting that providers vary and that it did not check them. Sigra-owned copy says "backup codes". | editorial |
| **magic link** | passwordless link, login link | Differs from the book, because the glossary has no row for this term. The book's wording governs Sigra-owned copy: a "magic link" is a one-time sign-in link sent by email, never a "passwordless link". "Login link" is already covered by the sign-in rows in the Canonical Terms table above. | `test/sigra/brand/copy_contract_test.exs` ("passwordless link" and "login link" in the admin scope) |
| **passkey** | WebAuthn (in screens), security key | Differs from the book, because the glossary has no row for this term. The book's wording governs Sigra-owned copy: a "passkey" is a sign-in credential kept on the user's device, not a password. Screens do not say "WebAuthn" or "security key"; "WebAuthn" stays correct in code and technical documentation. | `test/sigra/brand/copy_contract_test.exs` ("security key" in the admin scope); editorial for "WebAuthn" in screens |
| **generated code** | scaffold, boilerplate | Differs from the book, because the glossary covers admin screens and has no row for a term that belongs in the README and guides. The book's wording governs: the schemas, routes, screens and emails that `mix sigra.install` writes into your repo are "generated code", and they are yours. | `test/sigra/brand/copy_contract_test.exs` ("scaffold" and "boilerplate" in the admin scope); editorial in the README and guides |
| **your app** | host, parent app, consumer | Differs from the book, because the glossary has no row for this term and its own Voice Rubric says "host-owned". The book says "your app" in product copy; in the contract and technical documentation it is "the host" (the Phoenix app that uses Sigra), glossed once. Sigra-owned screen copy says "your app". | `test/sigra/brand/copy_contract_test.exs` ("parent app" in the admin scope); editorial for "host" and "consumer" |
| **Admin** (the platform administrator's label) | Admin (operator) | Differs from the glossary, which has no row for this label. The book writes "Admin" and flags "Admin (operator)" in its open risks, so Sigra-owned copy says "Admin". At the time of writing the only occurrence in the repo is the demo host's persona label (`test/example/lib/example/demo/personas.ex:60`), which is host-owned and is not edited here. | `test/sigra/brand/copy_contract_test.exs` ("admin (operator)" is a banned phrase in the admin and generated scopes) |
| **Review users** (the action on a flagged-user notice) | Review accounts | Agrees with the book and the **user** row above, which both ban "account" as a person-noun, so the label is "Review users", never "Review accounts". Shipped admin copy already says "Review users" (`lib/sigra/admin/live/index_live.ex:49`, `lib/sigra/admin/live/index_live.ex:72`), though the notice beside it still says "No flagged accounts" (`lib/sigra/admin/live/index_live.ex:51`). Correcting that sentence needs a library edit, a later copy change (Phase 262) that is not done here. | editorial (the **user** row above) |
| **Review users** (in documentation examples) | Review accounts | Agrees with the row above. The one "Review accounts" in library code is a documentation example in a component @doc (`lib/sigra/admin/components.ex:532`); it needs the same library edit and the same later copy change. The demo gallery's own "Review accounts" wording is host-owned and is not edited here. | editorial (the **user** row above) |

---

## Voice Rubric

### Cross-cutting gate (all string types)

All visible strings in admin chrome must pass this gate:

- **Active voice.** "The user was deleted by an admin" → "An admin deleted the user."
- **Second person.** "you" = the operator; "the user" = the subject being managed. Never "the customer", never "the end user."
- **GOV.UK words-to-avoid are banned in admin copy.** Forbidden: leverage, utilise, facilitate, seamless, robust, empower, innovative, "it just works", synergy, cutting-edge, best-in-class, transformative, impactful, "Oops!", exclamation marks for routine states, "Unfortunately,".
- **No leaked internals.** No `inspect/1` output, no `%Ecto.Changeset{}` struct shapes, no module names, no bare error codes, no Elixir stack traces. Map known error structs to human copy before rendering. The catch-all `inspect(reason)` error copy is a violation.
- **Length.** ≤ approximately 2 sentences for notices and body copy; headings are noun-phrase or verb-phrase, not full sentences.
- **Calm, no blame, no hype.** Errors do not blame the user. Successes do not celebrate ("Done!", "Great!"). Copy matches the register of a trusted internal tool.
- **Severity-honest color.** Red / `:risk` tone is reserved for business-harm and destructive actions. Routine states (session expired, empty first-use, page load error) are neutral or amber. An empty list is never red.

### Error rubric

A well-formed error string contains three elements:

1. **What failed** — name the specific field or operation, not "something went wrong."
2. **Why it matters** — one phrase on the consequence (optional for obvious cases).
3. **Concrete next action** — what the operator should do now: "Refresh the page", "Check the value and try again", "Contact support if this persists."

Errors are rendered near their source (form field inline validation, or `notice tone={:risk}` adjacent to the failing section). Operator input is preserved in the form — never clear a partially-filled form on error.

**E-6 decisive branch (enumeration boundary):**
- **Auth / enumeration boundary** (login form, password reset, magic link, "does this account exist") — message MUST be **uniform and generic**. Vagueness is required; specificity is forbidden. Example: "If an account with that email exists, you'll receive a reset link." These strings live in `priv/templates/sigra.install/` (host-owned, out of scope for admin chrome).
- **Operator console error** (inside the trusted admin UI, triggered by an operator's own action) — message MUST be **specific**. Operators are trusted engineers; vague copy wastes a support investigator's time. Example: "Could not save auth branding. Check the values and try again." (not "Something went wrong.")

### Empty state rubric

Classify the empty state before writing copy:

| Type | Trigger | Copy pattern | CTA |
|------|---------|--------------|-----|
| **first-use** | Surface has never had data | Explain what will appear here and what action creates it. Neutral tone. | Optional — only if the operator can directly act |
| **filtered no-results** | Active filters exclude all records | "No [items] match the active filters." | Required: "Clear filters" or "Clear all filters" |
| **scope-denied** | User lacks permission to see this content | Calm boundary statement. Do not say "forbidden" or "unauthorized." | None (or "Contact your admin") |
| **load-error** | Data fetch failed | Follow the Error rubric. Offer refresh. | "Refresh the page" or "Try again" |

Additional rules:
- Never red. An empty list is a neutral state.
- Explain what populates the surface, even briefly: "Users appear here as people register." This makes the empty state informative, not just blank.
- No misleading CTA the operator cannot act on. Do not show "Create your first organization" if the operator is on a read-only support role.

### Success rubric

- **Past tense.** "Session revoked." not "Session has been revoked." or "Revoke successful."
- **State the durable consequence.** The operator needs to know what is now true: "All active sessions revoked." is durable; "Done!" is not.
- **Blast-radius scope.** When the action affects a tenant or a subset: "Revoked across Acme Corp only." Single-user actions do not need a tenant qualifier unless the admin is impersonating.
- **Toast for routine reversible saves.** Transient flash for low-stakes changes (profile saved, preference updated).
- **Inline / persistent for security-weight outcomes.** Revoking all sessions or deleting a user warrants a visible persistent notice, not just a toast.
- No hype. "Done!", "All set!", "Great job!" are banned.

### Warning / destructive confirm rubric

A well-formed destructive confirmation contains:

1. **Concrete risk.** Name what will be destroyed or ended: "Revoking this session signs the user out of that browser or device immediately."
2. **Blast radius.** Distinguish one device vs all sessions, one user vs whole tenant: "This revokes every session across all their devices."
3. **Explicit reversibility.** State whether the action can be undone: "This can't be undone." for irreversible actions; for reversible: "The user can sign in again to restore access."
4. **Verb-noun confirm label.** The confirm button must name the action: "Revoke all sessions", "Delete user", "Suspend member". Never "OK", "Yes", "Confirm", or "Proceed".
5. **Risk-reduction guidance.** Where applicable, tell the operator how to reduce blast radius: "To revoke a single session, use the table below."

---

## Exemplars

These strings are drawn directly from the codebase. They are compliant with the voice rubric and canonical term table and serve as reference targets for new copy.

**1. Single-session success flash** — `user_show_live.ex:81`
```
"Session revoked."
```
Verdict: past tense, minimal, accurate. The durable consequence is clear (the session no longer exists). No hype.

**2. Multi-session success flash** — `user_show_live.ex:89`
```
"All active sessions revoked."
```
Verdict: past tense, blast-radius clear ("all active" scopes it correctly), no embellishment.

**3. Destructive confirm copy — single session** — `user_show_live.ex` confirm dialog
```
"Revoke this session for #{email}? This signs them out of that browser or device."
```
Verdict: names the specific user (email scoped), names the concrete consequence (signs out of that browser or device), blast radius is single-device. Question form is acceptable for single-item confirms.

**4. Locked-user help text — post-edit target** — `users_index_live.ex` (Wave 2 fix)
```
"These users are locked out after failed sign-in attempts. Review the user before unlocking."
```
Verdict: explains what caused the state (failed sign-in attempts), explains what the operator should do (review before unlocking), uses correct canonical terms ("sign-in", "user"), no blame.

**5. Scope-denied empty state** — `user_show_live.ex`
```
"This user does not have a currently visible session in this scope."
```
Verdict: calm boundary statement, explains the scope limit without implying error, preserves the user's input context.
