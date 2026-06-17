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
