# Pitfalls Research — Sigra v1.1 Foundations (Organizations + Passkeys)

**Domain:** Adding logical multi-tenancy + WebAuthn/passkeys to an already-shipped Phoenix 1.8+ auth library
**Researched:** 2026-04-11
**Confidence:** HIGH (every pitfall cites a concrete CVE / GitHub advisory / post-mortem / spec clause)
**Scope rule:** This document is about **integration pitfalls** — what breaks when these features are bolted onto an existing system, not greenfield. Complements STACK.md and ARCHITECTURE.md; no duplication of version / pattern content.

> **Forward-compat rule:** Every pitfall notes whether it "explodes later under impersonation" (v1.2). Pitfalls flagged `IMP+` are silent bugs in v1.1 that become data-attribution disasters once v1.2 impersonation lands. Address them in v1.1 even if they feel premature.

---

## Part 1 — Organizations (Multi-Tenancy) Critical Pitfalls

### Pitfall O-1: Missing `organization_id` filter on a query — the cross-tenant data leak
**Severity:** CRITICAL (the defining MT bug class)
**IMP+:** YES — same bug also leaks across impersonation boundaries

**What goes wrong:** A developer adds a new endpoint, LiveView, background worker, count, export, autocomplete, or "recent items" list and forgets `where: x.organization_id == ^scope.active_organization.id`. The query returns rows from every tenant. Bug sits in production for days-to-weeks before someone notices in logs or a support ticket.

**Real examples:**
- *Multi-Tenant Leakage: When "Row-Level Security" Fails in SaaS* (InstaTunnel, Jan 2026) documents a case where a single un-scoped query "lived quietly in production for two weeks, leaking user records across tenants."
- *Six Shades of Multi-Tenant Mayhem* (Borabastab, May 2025) — "every bug that drops tenant_id becomes a data leak."
- OWASP Multi-Tenant Security Cheat Sheet lists "missing tenant filter" as #1 root cause of SaaS BOLA-class incidents.

**Why it happens:** The type system can't see it. `Ecto.Query` composes freely — there's no compiler signal that `from p in Post` without `for_org(scope)` is wrong. Copy-paste from an example that forgot the scope. Rename of a context module that dropped the query helper. New Oban worker written against `Repo` directly.

**Prevention (layered — do ALL three, not just one):**
1. **Query helper convention (runtime):** `Sigra.Organizations.Query.for_org(query, scope)` and make it so it `raise`s if `scope.active_organization` is nil. Every tenant-scoped context fun funnels through it. Document "no raw Repo in tenant contexts" in `guides/organizations.md`.
2. **Credo custom check (compile-time, advisory):** new `Sigra.Credo.TenantScopedQuery` check warns when `Repo.all/one/aggregate` is called inside a module tagged `@tenant_scoped true` without a `for_org` call visible in the pipeline. Don't make it an error (too many false positives on joins); make it a warning that developers must justify with a `# credo:disable-for-next-line` + reason comment.
3. **Integration tests (belt-and-suspenders):** `test/sigra/organizations/isolation_test.exs` — for every tenant-scoped operation, create two orgs with distinct data, run the operation scoped to org A, assert zero org-B rows appear. Template generator emits a stub for host apps to extend.

**Warning signs:**
- A `Repo.` call inside a context module whose name contains `Organization` or `Tenant` without a `for_org` call above it
- Counts, exports, or "recent activity" views added without asking "how does this get scoped?"
- Oban worker `perform/1` that doesn't read `args["organization_id"]`
- "I just added a small filter improvement" PR that touches a context but doesn't touch an isolation test

**Phase to address:** Phase 3 (context) installs `for_org/2`; Phase 4 (plugs) raises the exception path; Phase 5 (audit) verifies via integration test; Phase 13 (docs) captures the rule for host apps.

**Sources:**
- https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html
- https://medium.com/@instatunnel/multi-tenant-leakage-when-row-level-security-fails-in-saas-da25f40c788c
- https://borabastab.medium.com/six-shades-of-multi-tenant-mayhem-the-invisible-vulnerabilities-hiding-in-plain-sight-182e9ad538b5
- https://bytemedaily.medium.com/the-multi-tenancy-bug-that-leaked-10-000-user-records-d133d4c59447

---

### Pitfall O-2: Invite token redeemable by a different logged-in user (account hijack)
**Severity:** CRITICAL
**IMP+:** YES — under impersonation this becomes a catastrophic mis-attribution vector

**What goes wrong:** User A is logged in as `a@example.com`. User A clicks an invite link for `b@example.com` (forwarded in Slack, or A is mid-session on a shared device). The app accepts the invite and adds **user A** (wrong email!) to the target organization. The original invitee B is never added and may never know. Attacker paths: phishing A to click a B-intended link; opportunistic access on a shared machine.

**Real examples:**
- **Jetstream issue #907** — exact bug: "The invitation link is not checking the currently logged-in user is authorized to accept the invitation or not." Jetstream accepted invitations from whichever user happened to be logged in when the link was clicked.
- **Invitation Hijacking** (Vishal Barot, Medium) — same class: invite sent to one email could be redeemed by a different account; same token reusable.
- **CVE-2026-1529 (Keycloak)** — organization invitation JWT accepted without cryptographic verification; attacker could modify `org_id` and target email in the token payload and self-register into any org.

**Why it happens:** Invite token validates "is this token valid?" but not "is the token's bound email == current_user.email?" The "logged in context" is ambient — easy to forget.

**Prevention:**
1. **Email-bound token (hard):** the invitation record stores `email` + `hashed_token`. `Sigra.Organizations.accept_invitation/2` MUST assert `invitation.email == current_user.email` (case-insensitive via citext). Mismatch → render a dedicated "This invitation is addressed to `x@y.com`. You're currently signed in as `a@b.com`. Sign out and try again, or ask the sender to re-issue." page with **no** accept button.
2. **HMAC-signed token (not JWT):** use `Sigra.Token` v1.0 HMAC helper. Token payload includes `{invitation_id, email, org_id, expires_at}`. Server re-hashes and compares — no parse-then-trust. Avoids CVE-2026-1529 pattern entirely.
3. **Single-use:** `accepted_at` is `NOT NULL` after first success; subsequent redemptions return the same dedicated error page. Do NOT delete the invitation row — audit trail depends on it.
4. **Short TTL:** 7 days default, configurable via NimbleOptions. Document: longer TTL = phishing window.
5. **Audit every acceptance attempt** (success AND mismatch AND expired) with `invitation_id` + `acting_user_id` + reason. Under v1.2 impersonation, mismatch attempts during impersonation become a red-flag signal.

**Warning signs:**
- `accept_invitation` function doesn't read `current_user` at all, or doesn't compare emails
- Invitation token is a JWT or anything that "parses and trusts"
- `expires_at` is nullable or defaults to 30+ days
- No test case: "logged in as X, accept invite for Y → rejected"

**Phase to address:** Phase 7 (invitation flow). Must ship with the email-bound assertion test as a Phase-7 requirement (not a nice-to-have).

**Sources:**
- https://github.com/laravel/jetstream/issues/907
- https://medium.com/@kshunya/invitation-hijacking-4d6467f418cc
- https://advisories.gitlab.com/pkg/maven/org.keycloak/keycloak-services/CVE-2026-1529/
- https://f3ds.vercel.app/posts/cve-2026-1529-keycloak-unauthorized-registration-via-invitation-token/
- Auth0 docs: "invited users must log in or create an account with the email address to which the invitation was sent" — https://auth0.com/docs/manage-users/organizations/configure-organizations/invite-members

---

### Pitfall O-3: Invite token reuse / replay
**Severity:** HIGH
**IMP+:** no direct impact

**What goes wrong:** Same invite token redeemable N times. Attacker who captures the URL (leaked email, server logs, browser history on a shared machine, proxy logs) can replay it to rejoin the org after the legitimate member is removed — or to occupy multiple seats.

**Real example:** The Vishal Barot *Invitation Hijacking* write-up explicitly demonstrates "the same invitation token could be reused multiple times, when technically the token should expire once it has been used."

**Prevention:**
1. `accepted_at :utc_datetime` on `OrganizationInvitation`. After successful accept, update inside the same `Ecto.Multi` that creates the membership. Partial failure → `Multi` rolls back, invitation stays open.
2. `revoked_at :utc_datetime` — owners/admins can revoke. Revocation checked in `accept/2` path.
3. Token stored as **hash** (SHA-256 or Sigra's existing `generate_hashed_token/0`), never plaintext. Prevents DB-leak replay.
4. Reject on any of: `accepted_at != nil`, `revoked_at != nil`, `expires_at <= now`.
5. Test: "accept twice → second fails with specific error"; "accept after revoke → fails"; "accept after expiry → fails".

**Warning signs:** `accepted_at` not set inside the `Multi`; `accept/2` doesn't check all three gates; plaintext token in DB column.

**Phase to address:** Phase 7.

**Source:** https://medium.com/@kshunya/invitation-hijacking-4d6467f418cc

---

### Pitfall O-4: Last-owner lockout + admin-can-delete-owner escalation
**Severity:** CRITICAL
**IMP+:** YES — v1.2 impersonation multiplies blast radius (impersonated admin deleting the real owner)

**What goes wrong:** Two related bugs in one hazard area.
1. **Last-owner lockout:** The only owner of an org removes themselves (or is removed by a race). Org has zero owners. No one can manage billing, add members, or delete the org. Support ticket → manual DB surgery.
2. **Admin-deletes-owner escalation:** UI hides the "remove owner" button for admins but the server-side action doesn't enforce it. Admin crafts the API call, removes the owner, becomes effectively top-of-tree. Documented as a real bounty finding.

**Real examples:**
- *Privilege Escalation Allow Admin to Delete Owner Leading to Organization Takeover* (Islam Ghandar, Medium) — exact bug class: UI RBAC without server-side enforcement, admin deletes owner via API request tampering.
- *Luminate Internal Privilege Escalation — Admin to Owner* (Rojan Rijal) — same shape.

**Prevention:**
1. **Server-side role gate is the only source of truth.** `Sigra.Organizations.remove_membership/3` takes `(scope, target_user, opts)` and checks:
   - `scope.membership.role in [:owner, :admin]`
   - If target is `:owner`, acting scope MUST be `:owner`. Admins cannot remove owners — server error, not a UI choice.
2. **Last-owner guard inside the Multi:** `Repo.one(from m in Membership, where: m.organization_id == ^org_id and m.role == :owner, select: count())` INSIDE the same transaction as the delete. If `count == 1` and target is that owner, return `{:error, :last_owner}`. Test: two owners → remove one OK; one owner → remove fails.
3. **Role-change has the same guard:** demoting the last owner to `:admin` is a last-owner event. Cover both paths.
4. **Self-demotion allowed, but with the same guard.** User can downgrade themselves only if another owner exists.
5. **Transfer-ownership flow as the explicit alternative:** `transfer_ownership(scope, new_owner_id)` — promote first, then optionally demote. Document as the "I'm leaving and I'm the only owner" path.

**Warning signs:**
- `remove_membership` reads role from `params` instead of from the DB'd membership row
- Delete path doesn't start a `Multi` (count + delete must be atomic to avoid a race where two admins click "remove owner" on two owners simultaneously)
- No test: "last owner removes self → error"
- UI is the only thing preventing owner deletion

**Phase to address:** Phase 3 (context fun + Multi); Phase 4 (plug check); Phase 6 (UI gates). All three layers.

**Sources:**
- https://medium.com/@islamghandar/admin-can-delete-workspace-owner-leading-to-organization-takeover-45de0c78fb60
- https://medium.com/@rojanrijal/luminate-internal-privilege-escalation-admin-to-owner-2ca28e575985

---

### Pitfall O-5: Cross-org session confusion — user has org A active, action targets org B
**Severity:** HIGH
**IMP+:** YES — under v1.2, wrong-org actions attributed to impersonator compound the problem

**What goes wrong:** Session's `active_organization_id` is A. User opens a second tab, switches to B in tab 2 (session updated), then takes an action in tab 1's stale LiveView which posts to a resource in org B — but the server loads `active_organization` from the session which now says B. LiveView assigns are stale. Action succeeds in the wrong org, or fails confusingly. Also: a URL carries `?org=B` but session says A — which wins?

**Prevention:**
1. **Server session is authoritative for "active org", never URL params** (v1.1 decision — see ARCHITECTURE A5). URL params for org-scoped routes are reserved for v1.3+.
2. **`Sigra.Plug.RequireMembership` re-verifies every request:** load `membership` fresh from DB against `session.active_organization_id`. Don't trust a stale assigns cache.
3. **LiveView `handle_params` re-checks scope:** if socket's `current_scope.active_organization.id != session["active_organization_id"]`, force a `push_navigate` to refresh. Don't silently fix — surface that the user switched elsewhere.
4. **Action endpoints assert org from scope, not from form params:** `create_post(scope, attrs)` uses `scope.active_organization.id` — NEVER `attrs["organization_id"]`. Ignore any org_id in inbound attrs (cast it out in the changeset).
5. **Test: multi-tab org switch.** `conn1 = log_in_user_with_org(user, org_a); conn2 = log_in_user_with_org(user, org_b); act on conn1 → must happen in org_a even though conn2 switched`. Each conn has its own session.

**Warning signs:** changeset accepts `:organization_id` in `cast/2`; LiveView stores `:active_org_id` in assigns and never reloads; routes take `org_slug` in the path.

**Phase to address:** Phase 4 (plug) + Phase 6 (LV pattern).

**Source:** ARCHITECTURE A1/A4/A5 (v1.1 internal decision).

---

### Pitfall O-6: Stale `active_organization_id` after membership removal (500 or silent wrong-org)
**Severity:** HIGH
**IMP+:** no direct impact

**What goes wrong:** User is kicked from org A while they have an active session with `session.active_organization_id = A`. Next request loads the session, tries to load membership, gets `nil` — code crashes or silently falls through to a wrong org.

**Prevention:**
1. **`LoadActiveOrganization` plug handles missing membership gracefully:** if `session.active_organization_id` is set but no active membership exists, clear the session field, pick the user's first remaining membership (if any), audit the transition (`audit: :active_org_auto_reassigned`), and continue. No 500.
2. **Zero memberships → `scope.active_organization = nil`, scope.user still set.** LiveViews must handle `nil` (either prompt to create an org or redirect to a "no org" page). Generator template includes the nil branch.
3. **Session rotation on membership change:** when a user is removed from an org, schedule an Oban job to invalidate their sessions for that org (or just clear the `active_organization_id` field on rows matching the removed user). Optional but safer.
4. **Test:** user removed mid-session → next request → scope either switches orgs or lands on the no-org page, never 500.

**Warning signs:** `scope.active_organization.id` dereferenced without nil guard in LV code; no test for "user removed mid-session."

**Phase to address:** Phase 4.

**Source:** STACK.md §3 ("Stale active_organization_id" guardrail)

---

### Pitfall O-7: Audit row misattribution that explodes under v1.2 impersonation (IMP+ critical)
**Severity:** MEDIUM in v1.1; CRITICAL in v1.2
**IMP+:** YES — the reason this pitfall exists

**What goes wrong:** In v1.1, audit rows attribute every action to `scope.user.id`. Works fine — user == actor. In v1.2, impersonation lands: `scope.impersonating_from = <admin>`, `scope.user = <target>`. If v1.1 audit code wrote only `user_id`, the v1.2 audit query "show me everything admin X did while impersonating" returns nothing — the admin never appears in rows. Worse: "show me everything that happened to user Y" mixes admin actions and real user actions indistinguishably. Compliance disaster.

**Prevention (address in v1.1 even though v1.2 is deferred):**
1. **Add `effective_user_id` column to `audit_events` NOW in v1.1** (nullable). Populate it identically to `user_id` in v1.1. In v1.2 it diverges: `user_id = scope.impersonating_from.id` (the admin), `effective_user_id = scope.user.id` (the target). ARCHITECTURE.md already flags this as an additive column.
2. **`metadata_from_scope/2` is the single audit-metadata assembly point.** Reserved comment block for `impersonating_from` — no v1.2 code change to the call sites, only to the helper.
3. **`organization_id` as a real column on `audit_events`** (ARCHITECTURE.md recommendation) — indexed, queryable, not buried in JSONB. v1.2 per-org audit views need it.
4. **Test the forward-compat shape:** v1.1 tests assert `user_id == effective_user_id` on every audit row. When v1.2 impersonation lands, those same tests still pass for non-impersonated paths; new impersonation tests cover divergence.
5. **Never log from inside a worker without reconstructing scope from args.** Every Oban worker that writes audit MUST take `user_id`, `effective_user_id`, `organization_id` from `args` and rebuild a minimal `%Scope{}` (ARCHITECTURE Part A1 §6).

**Warning signs:** audit call sites that read `user_id` from anywhere other than `metadata_from_scope`; `audit_events.organization_id` stored only in JSONB `metadata`; no `effective_user_id` column in the v1.1 migration.

**Phase to address:** Phase 5 (audit integration). The v1.1 migration MUST ship the forward-compat columns.

**Source:** ARCHITECTURE Part E (v1.2 forward-compat checklist) + PROJECT.md v1.2 direction.

---

### Pitfall O-8: "Personal org" auto-creation — both directions have failure modes
**Severity:** HIGH
**IMP+:** no direct impact

**What goes wrong (two sides):**
- **If you auto-create a personal org on signup:** every user has a vestigial org they didn't want. In B2B flows, users who join via invite now have two orgs (personal + invited) and get confused about which is active. Deletion of the personal org requires special-casing ("you can't delete the only org you own" — wait, but you can?). Slug collisions explode.
- **If you don't auto-create:** every v1.0 LiveView needs a "no active org" branch. `scope.active_organization` is nil for freshly-migrated v1.0 users. "Create your first org" wizard becomes part of the happy path. Breaking change for existing installs.

**Backfill problem specifically:** existing v1.0 deployments upgrading to v1.1 have users with no org. Running a backfill migration that creates "personal-<user_id>" orgs for every existing user is a heavy DDL operation that can fail halfway (OOM, timeout, FK error) leaving half the user base with orgs, half without.

**Real pattern observations:** Clerk defaults to "personal accounts" with explicit opt-in to org mode. Linear, Slack, Notion all require explicit org creation at signup — no hidden orgs. Auth0 Organizations requires explicit assignment.

**Prevention:**
1. **Policy decision, documented as D-v1.1-orgs-default:** default is **"org created on first org-creating action, not on signup."** Users without an org have `scope.active_organization = nil` and see a "Create your first organization" prompt when they visit an org-scoped LV. No hidden personal org.
2. **Backfill migration is opt-in** (`mix sigra.install --organizations --backfill-personal-orgs`) and **idempotent** — safe to re-run on partial failure. Wrap in a batched migration (100 users at a time) so OOM doesn't brick a large install. Emit `IO.puts` progress.
3. **Backfill slug strategy:** `"personal-" <> Base.url_encode64(:crypto.hash(:sha256, lowercase_email), padding: false) |> binary_part(0, 12)` — deterministic, collision-resistant, no PII leak.
4. **Rollback path documented:** "delete all orgs where `slug LIKE 'personal-%' AND created_at > <backfill_time>`" — single query, idempotent.
5. **Do NOT set `active_organization_id` on sessions during backfill** — next login picks up via normal flow. Backfill that also mutates session rows has too many ways to break.

**Warning signs:** migration file without batch/progress markers; no rollback doc; no test for "apply backfill twice → same result"; generator emits org creation in a `User.create/1` hook (tight coupling, hard to remove).

**Phase to address:** Phase 8 (backfill + generator wiring).

**Sources:**
- Clerk docs — https://clerk.com/docs/guides/organizations/org-slugs-in-urls (personal accounts + orgs)
- Auth0 — https://auth0.com/docs/manage-users/organizations/configure-organizations/invite-members

---

### Pitfall O-9: Slug squatting, reserved names, and unique constraint races
**Severity:** MEDIUM
**IMP+:** no direct impact

**What goes wrong:**
1. **Reserved path collision:** user creates org with slug `admin`. Suddenly `/admin` is ambiguous — does it route to admin UI or to org `admin`? v1.2 admin dashboard will have this exact conflict.
2. **Slug squatting:** no reserved list → attackers grab `api`, `docs`, `support`, `help`, `www`, `admin`, `billing` before real customers sign up. Now `acme.example.com/api` could collide if subdomain routing is ever added.
3. **Uniqueness race:** two users submit the same slug at the same moment. Without a DB unique index, both succeed and you have duplicates. With an index but only application-level check, you get a `unique_violation` 500 instead of a validation error.
4. **Case-insensitive uniqueness:** `Acme` vs `acme` — both allowed under naive `citext` schema but routing treats them as one.

**Prevention:**
1. **Hardcoded reserved list** in `Sigra.Organizations.reserved_slugs/0` — at minimum: `admin`, `api`, `auth`, `billing`, `dashboard`, `docs`, `help`, `login`, `logout`, `mail`, `oauth`, `root`, `settings`, `signup`, `status`, `support`, `system`, `users`, `webhooks`, `www`. Host apps can extend via config. Reject at changeset level with a specific error message.
2. **Forward-compat with v1.2 admin:** add `admin` to reserved list in v1.1 so v1.2 `/admin` never collides.
3. **DB unique index on `LOWER(slug)`** (PostgreSQL) or `citext` column + unique index. Ecto changeset uses `unique_constraint/3` so races → `{:error, changeset}` not 500.
4. **Slug format regex:** `~r/^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/` — lowercase, hyphens, no leading/trailing hyphen, 3-40 chars. Reject everything else.
5. **No auto-rename on collision.** Rejecting with a validation error is less surprising than silently appending `-2`.

**Warning signs:** slug column is `:string` without `citext`/lower-index; no reserved list; no test that `/admin` as a slug is blocked.

**Phase to address:** Phase 3 (schema); recheck in Phase 8 (generator pitfall — generator must emit the reserved list).

**Sources:**
- https://github.com/spatie/laravel-sluggable/discussions/260 (reserved slug pattern)
- https://github.com/supakeen/pinnwand/issues/34 (slug race condition)
- https://clerk.com/docs/guides/organizations/org-slugs-in-urls

---

### Pitfall O-10: Organization deletion cascade — members, invites, audit, sessions
**Severity:** HIGH
**IMP+:** YES — v1.2 audit feed must survive org deletion

**What goes wrong:** Owner deletes org. What happens to:
- `organization_memberships` — cascade delete? If yes, users lose role history. If no, orphaned FKs.
- `organization_invitations` — cascade delete? Revoking them is better (audit trail).
- `audit_events.organization_id` — MUST NOT cascade. You need the history. But a hard FK with `on_delete: :delete_all` would wipe it.
- `user_sessions.active_organization_id` — dangling pointer. Next login 500s if not nil-guarded.
- `user_sessions` with the deleted org as active → should fall back to next available org or nil.

Real class: v0 SaaS apps ship "DELETE FROM orgs WHERE id = ?" and cascade-wipe audit logs, which is a compliance violation under SOC2 / GDPR data retention.

**Prevention:**
1. **Soft-delete orgs by default:** `deleted_at :utc_datetime` on `organizations`. All queries filter `is_nil(deleted_at)`. Hard-delete via a separate admin action after a retention window.
2. **FK design (Phase 3 migration):**
   - `organization_memberships.organization_id` → `on_delete: :delete_all` (memberships don't survive a hard delete)
   - `organization_invitations.organization_id` → `on_delete: :delete_all`
   - `audit_events.organization_id` → `on_delete: :nilify_all` + keep `metadata` JSONB copy of org name/slug for forensic context. **Audit rows survive forever.**
   - `user_sessions.active_organization_id` → `on_delete: :nilify_all`
3. **Hard-delete is a separate path** (`Sigra.Organizations.hard_delete/2`) gated on `soft_deleted_at <= now - retention_window`. v1.1 can ship soft-delete only; hard-delete is v1.2 admin territory.
4. **Test the cascade matrix:** for each FK, "hard delete org → row X is deleted / nilified / preserved" assertion.

**Warning signs:** `references(:organizations, on_delete: :delete_all)` on `audit_events`; no `deleted_at` column; no test for "delete org, query audit" asserting rows remain.

**Phase to address:** Phase 3 (migration) + Phase 5 (audit FK design).

**Source:** https://hexdocs.pm/ecto_sql/Ecto.Migration.html#references/2 + https://doriankarter.com/avoiding-data-loss-understanding-the-ondelete-option-in-elixir-migrations/

---

### Pitfall O-11: Background worker runs without tenant context
**Severity:** HIGH
**IMP+:** YES

**What goes wrong:** Oban worker does `Repo.all(Post)` instead of `Repo.all(from p in Post, where: p.organization_id == ^args["organization_id"])`. At perform time there's no "current user" so the developer omits the filter. Worker now reads/writes across all tenants. Classic documented failure mode.

**Real pattern:** Agnite Studio's cross-tenant leakage post: "A background worker running outside tenant context" listed as a primary root cause.

**Prevention:**
1. **Every Oban worker `args` contains `organization_id` and `actor_id`.** Sigra's convention, enforced in `Sigra.Workers` behaviour (new in v1.1).
2. **Worker `perform/1` reconstructs a minimal `%Scope{}`** from args (load user, load active org, verify membership still exists) before any `Repo` call. If membership was removed between enqueue and perform, worker returns `{:cancel, :membership_revoked}` — not an error, an expected outcome.
3. **Credo custom check** (same as O-1) flags `Repo.` calls inside worker modules that don't reference `args`.
4. **Test:** enqueue a worker, remove user from org, perform the worker → asserts cancellation, not execution.

**Warning signs:** worker arg shape doesn't include org; `perform/1` reads nothing from args before hitting Repo; no "membership revoked between enqueue and perform" test.

**Phase to address:** Phase 5 (worker pattern in the audit backfill worker); reinforced in Phase 9+ for passkey workers.

**Sources:**
- https://agnitestudio.com/blog/preventing-cross-tenant-leakage/
- https://github.com/ErwinM/acts_as_tenant (Rails precedent: automatic tenant propagation to ActiveJob)

---

## Part 2 — Passkeys / WebAuthn Critical Pitfalls

### Pitfall P-1: Server does not store challenge — replay attack (OneUptime CVE pattern)
**Severity:** CRITICAL
**IMP+:** no direct impact

**What goes wrong:** RP issues a challenge, sends it to client, **does not persist it server-side**. Client signs, POSTs assertion. Server "verifies" by accepting the challenge from the client's own `clientDataJSON`. Any attacker who captures a single valid assertion (via XSS, log exposure, MitM, browser extension) can replay it forever — there's no server-side state to invalidate. Bypasses WebAuthn's entire security model.

**Real example — OneUptime GHSA-gjjc-pcwp-c74m:** exact bug. "Server accepts client-supplied challenge instead of server-stored value, allowing credential replay." The assertion never expires because there's no server-side challenge state to invalidate.

**Prevention:**
1. **Challenge is server-generated, server-stored, server-verified.** STACK.md §1 + ARCHITECTURE B1 — store in Plug session (signed+encrypted) under `:passkey_challenge`, `max_age: 60`. Never accept a challenge that arrives in the request body as authoritative; only compare to stored.
2. **Single-use:** delete the stored challenge after verification (success OR failure). Second POST with same challenge → rejected because session no longer has it.
3. **Bound to mode + user where possible:** `%{challenge: bytes, user_id: id | nil, mode: :registration | :authentication, inserted_at: ...}`. Verification asserts mode matches the endpoint.
4. **Short TTL:** 60s. Longer = larger replay window if session leaks.
5. **Test: capture assertion, tamper with session to remove challenge, replay → verify fails.** Also: replay with fresh challenge but same assertion → fails.

**Warning signs:** `Wax.register/3` called with a challenge extracted from request body; no session write in `new_challenge`; no session delete in `verify`.

**Phase to address:** Phase 9 (registration) + Phase 10 (plug). MUST be a hard requirement.

**Sources:**
- https://github.com/OneUptime/oneuptime/security/advisories/GHSA-gjjc-pcwp-c74m
- https://medium.com/@instatunnel/the-webauthn-loop-common-logic-flaws-in-the-passwordless-handshake-017065517f83
- https://github.com/duo-labs/webauthn.io/issues/28 (CookieStore replay issue — DO NOT store challenge in the session cookie unencrypted)
- W3C WebAuthn Level 2 §13.4.3 — https://www.w3.org/TR/webauthn-2/

---

### Pitfall P-2: Passkey enrollment without re-auth (stolen-session privilege escalation)
**Severity:** CRITICAL
**IMP+:** YES — under v1.2 impersonation, an impersonating admin could enroll their own passkey as the target user unless this is blocked

**What goes wrong:** Attacker steals a session cookie (infostealer malware, session fixation, XSS). Attacker navigates to `/settings/passkeys/new`, enrolls their own authenticator, now has a permanent phishing-resistant credential for the victim's account. The session cookie theft becomes a persistent account takeover.

**Real pattern:**
- Spycloud + Obsidian Security: session cookie theft is the #1 way passkey accounts get taken over — "many CIAM systems have weak verification during the add-new-device phase."
- Google Workspace's DBSC (Device Bound Session Credentials) initiative specifically targets this class.
- Abnormal AI + Bleeping Computer: "when attackers already have the keys, MFA is just another door to open" — passkey enrollment is one of those doors.

**Prevention:**
1. **Gate `PasskeyEnrollmentLive` on `Sigra.Plug.RequireSudo`** — the v1.0 sudo re-auth plug. User must re-enter password (or complete fresh MFA) within the last N minutes before reaching the passkey enrollment screen. Sigra v1.0 already ships sudo mode; reuse it.
2. **Email notification on every passkey registration** ("A new passkey was added to your account from <IP/UA/geo>. If this wasn't you, click here to revoke."). Reuse the v1.0 suspicious-login email shape. Link revokes the passkey + invalidates all sessions.
3. **Audit event `:passkey_registered`** with full context for forensics.
4. **Consider requiring a 2nd factor during enrollment if MFA is enabled** — if user has TOTP, enrollment should re-prompt TOTP. Avoid TOTP→passkey silent downgrade.
5. **Under v1.2 impersonation, passkey enrollment MUST be in the locked-down ops list** (already in v1.2 direction doc). Record as forward-compat decision now.

**Warning signs:** `/passkeys/new` route is in the normal authenticated pipeline without `RequireSudo`; no email notification on registration; no audit event.

**Phase to address:** Phase 11 (enrollment LV) — must wire sudo plug on day one, not as a follow-up.

**Sources:**
- https://spycloud.com/blog/passkeys-their-impact-and-their-vulnerabilities/
- https://www.bleepingcomputer.com/news/security/when-attackers-already-have-the-keys-mfa-is-just-another-door-to-open/
- https://thehackernews.com/2025/10/how-attackers-bypass-synced-passkeys.html
- https://workspace.google.com/blog/identity-and-security/defending-against-account-takeovers-top-threats-passkeys-and-dbsc

---

### Pitfall P-3: RP ID / origin mismatch breaks all existing passkeys on domain rotation
**Severity:** HIGH (operational, not a CVE)
**IMP+:** no direct impact

**What goes wrong:** App ships with `rp_id = "app.example.com"`. Rebrand → new domain `app.example.io`. Admin updates config. **Every existing passkey is now dead** — the RP ID is baked into the credential, and the browser refuses any ceremony where the current origin doesn't match. Users who had passkeys as their only factor are locked out. Support floods with "I can't log in."

Related: `rp_id` set to full URL instead of effective domain (`https://app.example.com` instead of `app.example.com`) — passkey registration fails at ceremony start with `SecurityError`.

**Real source:**
- Corbado: "Changing the RP ID invalidates all existing passkeys... changing it in production environments is not recommended."
- Ory troubleshooting: `SecurityError` when RP ID is not an effective domain.
- WebAuthn spec / `w3c/webauthn` issue #963 and #1731 — RP ID confusion is a top FAQ.

**Prevention:**
1. **Runtime-configurable RP ID** (STACK.md §1, ARCHITECTURE B2) — no compile-time baking. Env vars `PASSKEY_RP_ID`, `PASSKEY_ORIGIN`, `PASSKEY_RP_NAME`.
2. **Validate at boot:** `NimbleOptions` schema rejects URLs with scheme/port in `rp_id`; asserts `origin` starts with `https://` in prod (allow `http://localhost` only when `Mix.env() != :prod`).
3. **Document the "rename your domain" playbook prominently** in `guides/passkeys.md`:
   - Use **Related Origin Requests** (`.well-known/webauthn`) allowlist to cover both old and new domains during transition.
   - Or: keep old RP ID permanently and only change origin.
   - Or: force all users to re-enroll (breaking) with 30-day notice + fallback to password.
   - **Never:** flip RP ID without a migration plan.
4. **Store the RP ID that was used at registration time** on `user_passkeys.rp_id`. Lets you detect which credentials belong to which RP ID era if you ever migrate.
5. **Config validation test:** boot with bad config variants → get clear error, not a cryptic runtime ceremony failure.

**Warning signs:** `rp_id` is `Application.compile_env`; no RP ID rename playbook in docs; no `rp_id` column on `user_passkeys`.

**Phase to address:** Phase 9 (schema — add `rp_id` column) + Phase 10 (runtime config + validation) + Phase 13 (docs).

**Sources:**
- https://www.corbado.com/blog/webauthn-relying-party-id-rpid-passkeys
- https://www.ory.com/docs/troubleshooting/passkeys-webauthn-security-error
- https://github.com/w3c/webauthn/issues/963
- https://github.com/w3c/webauthn/wiki/Explainer:-Related-origin-requests

---

### Pitfall P-4: Sign count regression handling — false positives AND false negatives
**Severity:** MEDIUM (imperfect signal either way)
**IMP+:** no direct impact

**What goes wrong (two sides):**
- **Too strict:** reject any non-monotonic sign count → lock out users whose authenticators legitimately return constant-zero (Apple iCloud Keychain passkeys, many TPMs) or whose counter resets after firmware updates. Support floods.
- **Too loose:** don't check sign count at all → miss the one real signal WebAuthn gives for detecting cloned authenticators.

**Real source:**
- *ImperialViolet — Signature counters* (Adam Langley, Aug 2023): "no one has ever gotten any utility from signature counters" — context: the real-world signal is noisy.
- W3C webauthn issues #1590, #125, #1008, #1734: multiple proposals to relax sign-count requirements; constant-zero is spec-compliant.
- Spomky-labs webauthn framework docs: explicit handling of "counter is always zero" case.

**Prevention:**
1. **Skip sign-count check when stored `sign_count == 0` AND received `sign_count == 0`** (known-null authenticator). This is spec-compliant and matches Apple passkeys.
2. **When stored `sign_count > 0` and received `sign_count <= stored`:** do NOT hard-reject. Instead:
   - Log audit event `:passkey_sign_count_regression` with both values.
   - Increment a `Sigra.Passkeys` telemetry counter.
   - Optionally email the user ("Your passkey was used in a way that suggests cloning — please review your credentials").
   - Configurable policy: `:warn | :require_reauth | :revoke`. **Default `:warn`** (log + email). `:revoke` is opt-in via config for high-sensitivity installs.
3. **Document the tradeoff** in `guides/passkeys.md`: "sign count is a noisy signal; we default to warn, not revoke."
4. **Test:** register with counter=5, authenticate with counter=3 → audit event + warn response, not a lockout.

**Warning signs:** `if sign_count > stored, do: :ok, else: raise` pattern; no telemetry; no policy config.

**Phase to address:** Phase 9 (authentication context).

**Sources:**
- https://www.imperialviolet.org/2023/08/05/signature-counters.html
- https://github.com/w3c/webauthn/issues/1590
- https://github.com/w3c/webauthn/issues/1734
- https://webauthn-doc.spomky-labs.com/v3.3/deep-into-the-framework/authenticator-counter

---

### Pitfall P-5: Passkey as sole factor without recovery → lost-device lockout
**Severity:** HIGH (UX/support)
**IMP+:** no direct impact

**What goes wrong:** User enrolls one passkey in passkey-as-primary mode. Phone falls in a lake. Synced passkeys aren't synced to another device (they turned off iCloud Keychain, or they're on Android without Google Password Manager). Now they have no way in. Unless the app has a recovery path.

**Real source:** Authsignal, Corbado, Mojoauth, Askleo all converge on "you MUST have fallback" when passkeys are the only factor. NIST SP 800-63B requires a backup authenticator at AAL2/3.

**Prevention:**
1. **Sigra v1.1 policy: passkey-as-primary is opt-in, and when enabled, at least ONE fallback is mandatory.** Enforce at enrollment time:
   - Must have a verified email (for magic-link recovery) OR
   - Must have backup codes generated (v1.0 `Sigra.Auth` backup codes repurposed as account recovery codes) OR
   - Must have a second passkey on a different device
2. **Recovery path:** Sigra already ships magic-link in v1.0 — the recovery path is "click magic link → land in session → re-enroll passkey, revoke lost one." Document as D-v1.1-passkey-recovery.
3. **Warn on last-passkey delete:** if user deletes their only passkey and has no other auth method, require sudo + show a confirmation modal. Mirror the "last owner" pattern.
4. **Recovery rate-limit:** magic-link recovery from a new IP/UA → additional email confirmation delay (reuse v1.0 suspicious-login pipeline).
5. **Do NOT allow passkey-as-sole-factor** (passkey only, no email, no password) in v1.1. Too many foot-guns. Defer sole-factor to a later milestone after UX is validated.

**Warning signs:** passkey-as-primary config enables without email requirement; no "delete last passkey" warning; no recovery path test.

**Phase to address:** Phase 11 (enrollment/authentication LVs).

**Sources:**
- https://www.authsignal.com/blog/articles/passkey-recovery-fallback
- https://www.corbado.com/faq/what-if-passkey-device-lost
- https://www.corbado.com/blog/passkey-fallback-recovery
- NIST SP 800-63B (phishing-resistant MFA requirements)

---

### Pitfall P-6: Username enumeration + credential-confusion bypass (StrongKey CVE pattern)
**Severity:** HIGH
**IMP+:** no direct impact

**What goes wrong:** Passkey authentication flow takes a username, returns the list of `allowCredentials` (credential IDs) for that user. Attacker probes usernames → presence of credentials leaks "this account exists and has a passkey." Worse (StrongKey CVE-2025-26788): server didn't distinguish discoverable vs non-discoverable credentials, so attacker could start a flow with victim's username, get the challenge, sign with attacker's OWN passkey, and be authenticated as the victim.

**Real source — CVE-2025-26788 (StrongKey FIDO Server):** exact flow confusion bug.

**Prevention:**
1. **Prefer usernameless / discoverable credentials (resident keys) flow** where possible. Client presents credentials it has for the RP ID; server verifies against stored credential ID. No username leak.
2. **For username-first flow (v1.1 default):** return a constant-time, constant-shape response regardless of whether the user exists. Never return "user not found" with a different timing profile. Reuse v1.0 enumeration-prevention guidance.
3. **Server MUST verify the returned credential ID is in the requested user's `allowCredentials`.** If the ceremony was started for user A but the signed credential belongs to user B, REJECT — do not authenticate as whichever owner of the credential it happens to be. This is the StrongKey bug.
4. **Verify `userHandle` in the authenticator response matches the user the ceremony was started for** (for usernameless flows).
5. **Test: start ceremony for user A, sign with user B's passkey → rejected.**

**Warning signs:** verification code that looks up the user by the credential ID that came back, instead of asserting it matches the requested user; no timing-constant path for "no such user."

**Phase to address:** Phase 9 (authentication context).

**Sources:**
- https://www.securing.pl/en/cve-2025-26788-passkey-authentication-bypass-in-strongkey-fido-server/
- W3C WebAuthn Level 2 §7.2 (authentication verification steps)

---

### Pitfall P-7: Attestation default — privacy vs security tradeoff done wrong
**Severity:** MEDIUM
**IMP+:** no direct impact

**What goes wrong:** App defaults to `attestation: :direct` (or `:indirect`) without realizing:
- Direct attestation can leak authenticator model / AAGUID → user fingerprinting
- Many passkey providers (Apple, Google synced) don't support attestation → registration fails for those users
- Consumer SaaS almost never needs attestation verification

Result: registration failures on major platforms, or accidental privacy leak if you do accept it and log it.

**Real source:** W3C WebAuthn L2 spec, Corbado attestation guide, Yubico developer guide — all recommend `none` for consumer scenarios.

**Prevention:**
1. **Default `attestation: :none`** in Sigra config (ARCHITECTURE B2 already specifies). Matches OWASP, Yubico, W3C guidance.
2. **Do not store raw attestation statements** when `:none` is in use (they'll be empty anyway).
3. **Document upgrade path** for apps that DO need attestation (regulated/enterprise): "set `attestation: :direct`, add your accepted AAGUID list, expect Apple/synced passkeys to fail unless whitelisted."
4. **Store `aaguid` as opaque bytes** (ARCHITECTURE B3) — don't map to provider names in v1.1. Defer FIDO MDS integration to a later milestone.
5. **Test: registration with `attestation: :none` against Wax test vectors for Apple/Yubikey/Windows Hello → all succeed.**

**Warning signs:** config default is anything other than `:none`; code stores attestation blobs when attestation is `:none`.

**Phase to address:** Phase 9 (registration context).

**Sources:**
- https://www.w3.org/TR/webauthn-2/ (§5.4.7 attestationConveyancePreference)
- https://www.corbado.com/glossary/attestation
- https://developers.yubico.com/WebAuthn/Concepts/Securing_WebAuthn_with_Attestation.html

---

### Pitfall P-8: JS hook race / abort / cancel / timeout not handled
**Severity:** MEDIUM (UX), HIGH (if it leaves server state inconsistent)
**IMP+:** no direct impact

**What goes wrong:** `navigator.credentials.create/get` is async. User cancels the authenticator prompt (timeout, hit cancel, denied biometric). Hook never sends a follow-up event. LiveView sits waiting. Refresh → challenge is stale → user re-tries → "invalid challenge" error. Or: user opens two tabs, starts enrollment in both, challenges overwrite each other in session.

Also: forgetting `AbortController` / `AbortSignal` leaves a dangling ceremony when the user navigates away, blocking future ceremonies on the same authenticator.

**Real source:** The "~30 lines of vanilla JS" trap documented in STACK.md §5 — base64url, error translation, and lifecycle handling balloon the code. SimpleWebAuthn's `startRegistration` / `startAuthentication` exist specifically because every hand-rolled hook misses these edges.

**Prevention:**
1. **Use `@simplewebauthn/browser ~> 13`** (STACK.md §5) — handles AbortController, error translation, conditional mediation, cancellation events.
2. **LiveView hook catches EVERY error** from SimpleWebAuthn and sends `passkey:error` with a sanitized message. Server LV `handle_event("passkey:error", ...)` clears the stored challenge from session and surfaces a user-friendly error ("Registration was cancelled. Click 'Start again' to retry."). No zombie state.
3. **Challenge TTL is short (60s)** — stale challenges auto-expire, so "abandoned ceremony" cleans itself up.
4. **Single active ceremony per session:** server stores at most one challenge. Starting a new ceremony overwrites the previous. Document as a known limitation: two-tab enrollment in the same session uses the most recent tab's challenge.
5. **Test matrix:** start + cancel; start + timeout; start + browser close; two simultaneous starts — all must clean up server state without 500.
6. **`AbortController` wired into the LiveView hook's `destroyed()` callback** so navigating away aborts the native ceremony.

**Warning signs:** hook code calls `navigator.credentials.*` directly without SimpleWebAuthn; no `error` handler path; no `destroyed()` hook cleanup; no cancel/timeout test.

**Phase to address:** Phase 10 (JS hooks) + Phase 11 (LV event handling).

**Sources:**
- https://simplewebauthn.dev/docs/packages/browser/
- https://github.com/MasterKale/SimpleWebAuthn
- STACK.md §5 (Sigra internal decision)

---

### Pitfall P-9: Platform vs roaming authenticator UI confusion
**Severity:** LOW-MEDIUM (UX)
**IMP+:** no direct impact

**What goes wrong:** UI shows a single "Add a passkey" button. On desktop Chrome, click → platform biometric. On Firefox → nothing visibly happens. On iOS Safari → iCloud Keychain prompt. On a corporate laptop → Windows Hello, no external key support. Users blame Sigra.

Also: `authenticatorAttachment` not specified → browser picks inconsistently. Some browsers show "use another device" QR for cross-device flow, some don't.

**Prevention:**
1. **Let the authenticator decide, don't constrain `authenticatorAttachment` by default.** Omit the field → browser offers all options (platform + cross-platform). Better UX than forcing platform-only.
2. **Show the registered AAGUID / transports** on the passkey list page: "Passkey on iPhone (iCloud Synced)", "Passkey on YubiKey 5 NFC" — user can tell which device maps to which entry. `transports` array already in the schema (ARCHITECTURE B3).
3. **Offer a "nickname" field** on registration — users can label "Work laptop" vs "Personal phone". Mandatory in the LV form.
4. **Document browser support** — Sigra `guides/passkeys.md` has a compatibility table. Phoenix 1.8 + passkeys targets evergreen browsers only; document IE/old-Safari exclusion.
5. **Graceful fallback:** if `PublicKeyCredential` is undefined (old browser), the enrollment LV shows "Your browser doesn't support passkeys. Use [TOTP / email MFA] instead." Don't surface a crash.

**Warning signs:** authenticator attachment hardcoded; no nickname field; no browser-support check; no transports displayed.

**Phase to address:** Phase 11 (LVs) + Phase 13 (docs).

**Sources:**
- https://www.w3.org/TR/webauthn-2/ (§5.4 `PublicKeyCredentialCreationOptions`)
- https://webauthn.guide/

---

### Pitfall P-10: WebAuthn API hijacking by malicious browser extension
**Severity:** INFORMATIONAL (app-level defense limited)
**IMP+:** no direct impact

**What goes wrong:** DEF CON 33 (Aug 2025) "Passkey Pwned" research — malicious extension replaces `navigator.credentials.create/get` with attacker code, intercepts ceremonies, fake-completes them, or reroutes assertions to an attacker server. Users see no visible change. Passkey prompt never appears but server gets a "successful" forged response (or a real one from attacker's own device).

**Real sources:**
- SquareX labs: https://labs.sqrx.com/passkeys-pwned-turning-webauth-against-itself-0dbddb7ade1a
- SC Media coverage: https://www.scworld.com/brief/webauthn-api-hijack-could-enable-passkey-login-bypass
- CISO guide: https://freemindtronic.com/webauthn-api-hijacking-ciso-guide-nullifying-phishing-en/

**Prevention (app-level mitigations are limited — document honestly):**
1. **Server-side challenge binding is the hard floor** (P-1). A hijacked ceremony still has to satisfy RP ID + origin + challenge. A malicious extension can fake a ceremony visually but the cryptographic proof still must match server state. Your job: never trust client-supplied challenge (P-1).
2. **Require attestation for high-sensitivity installs.** Direct attestation forces the authenticator to prove it's a physical device, not a JS-forged response. Document as an opt-in for regulated environments.
3. **Content Security Policy** with strict `script-src` to reduce malicious-script surface area. Sigra generator emits a recommended CSP in the controller scope.
4. **Document the limitation:** Sigra `guides/passkeys.md` is honest — "if the user's browser is compromised by a malicious extension, no server can fully protect the ceremony. Defense is layered: CSP, attestation, browser hygiene, device posture."
5. **Audit event on every passkey action** — post-compromise forensics depends on having the trail.
6. **NOT attempting:** trying to detect API hijacking from the server side. The research is clear that's unreliable.

**Warning signs:** docs claim "passkeys are phishing-proof full stop" (oversell); no CSP guidance; relying on client-supplied data in verification.

**Phase to address:** Phase 13 (honest docs).

**Sources:**
- https://labs.sqrx.com/passkeys-pwned-turning-webauth-against-itself-0dbddb7ade1a
- https://www.scworld.com/brief/webauthn-api-hijack-could-enable-passkey-login-bypass
- https://www.securityweek.com/passkey-login-bypassed-via-webauthn-process-manipulation/

---

### Pitfall P-11: CVE-2024-9956 — FIDO:/ intent hijacking (mobile browser class)
**Severity:** INFORMATIONAL (fixed at browser layer; no Sigra action)
**IMP+:** no direct impact

**What goes wrong:** Oct 2024 vulnerability affecting Chrome/Safari/Firefox on Android and iOS. Attacker-controlled page triggers `fido:/` intent URLs, which the mobile browser accepts without gating, starting a passkey ceremony that the victim's device may auto-complete (BLE hybrid transport, within 100m). Account takeover via proximity attack.

**Status:** patched — Chrome (Oct 2024), Safari 18.3 (Jan 2025), Firefox 136 (Mar 2025). All major browsers now blacklist `fido:/` URIs from page navigation.

**Sigra action:** none directly — this was a browser-layer bug. **Document in threat model** so host apps know:
1. Sigra assumes browsers that patch this class exist and are in use.
2. If supporting old mobile browsers, consider requiring attestation + same-device-only (no BLE hybrid) ceremonies.
3. Audit + email notification on registration (P-2) is the mitigation if a historical compromise happened pre-patch.

**Phase to address:** Phase 13 (threat model section in guides/passkeys.md).

**Sources:**
- https://mastersplinter.work/research/passkey/
- https://www.offsec.com/blog/cve-2024-9956/
- https://www.rescana.com/post/passkey-account-takeover-vulnerability-in-mobile-browsers-understanding-cve-2024-9956-and-its-impli

---

## Part 3 — Cross-Cutting Pitfalls

### Pitfall X-1: Generator partial-apply on conditional templates (first use — load-bearing)
**Severity:** HIGH
**IMP+:** YES — v1.2 `--no-admin` inherits this bug surface

**What goes wrong:** v1.1 is the **first time** the generator ships conditional templates (`--no-organizations`, `--no-passkeys`). Partial generation failure modes multiply:
1. User runs `mix sigra.install --organizations --passkeys`, gets interrupted mid-write (Ctrl-C, disk full, permission error). Half the org files exist, migrations don't — now the project is broken.
2. User re-runs the installer. Generator detects some files present and skips — but the ones it skipped are the broken half from the interrupted run. Silent breakage.
3. `--no-organizations` still leaks: an `injection` into `router.ex` doesn't check the flag, references a module that wasn't generated, compile fails.
4. User runs `--organizations` first, then `--passkeys` later — the passkey code assumes org files exist because dev tested both together.

**Prevention:**
1. **Subdir + feature manifest pattern** (ARCHITECTURE C1) — each feature declares its files in one place. Generator walks the manifest, checks `enabled?(opts)`, and generates OR skips — never conditional mid-template.
2. **Idempotent by design:** re-running the installer is safe. Each file write checks "does this file exist?" → prompts user (overwrite / skip / diff). Injection into existing files (`router.ex`, `app.js`) uses marker comments so re-injection is a no-op.
3. **Atomic-ish generation:** collect the full file list first, validate (no conflicts with existing user code via `Mix.Phoenix.check_*`), then write. Interrupted mid-write still leaves a broken project, but at least the pre-flight catches the obvious cases.
4. **`mix sigra.install.check`** helper task: dry-run, reports what would be generated/modified/skipped without touching files.
5. **Integration smoke test:** every combination `{organizations, no_organizations} × {passkeys, no_passkeys} × {live, no_live}` → `mix compile` → passes. At minimum 4 combos in CI (extend phase 10.1.1 harness).
6. **Feature module isolation:** `Features.Passkeys` never references `Features.Organizations` symbols — if they need to interact, it happens in `Features.Core`.
7. **Document the "I picked wrong, how do I reverse?" path** in `guides/installing.md`: each feature has a documented rollback (migration down, file list to delete, injection markers to remove).

**Warning signs:** generator code has `if Keyword.get(opts, :organizations)` branches scattered across `generate/4` instead of feature modules; router injection doesn't check feature enablement; no combinatorial smoke test.

**Phase to address:** Phase 1 (feature system foundation) — load-bearing. Phase 12 (passkey wiring) validates the pattern. Phase 13 (CI extension) locks it in.

**Source:** ARCHITECTURE.md Part C1 (v1.1 internal decision) + `priv/templates/sigra.install/` v1.0 precedent.

---

### Pitfall X-2: Migration ordering — backfill reads a column that doesn't exist yet
**Severity:** HIGH
**IMP+:** no direct impact

**What goes wrong:** v1.1 install adds (a) `organizations` table, (b) `user_sessions.active_organization_id` column, (c) `audit_events.organization_id` column, (d) personal-org backfill. If the generator emits them in the wrong order, or the host app picks them up across multiple `ecto.migrate` invocations on mixed environments, a backfill migration can execute before its prerequisite column exists. Real failure mode: migration crashes on production deploy, rollback is ambiguous.

**Prevention:**
1. **Timestamp prefix enforces order:** generator emits migrations with strictly increasing timestamps. The backfill migration has a timestamp strictly after all its prerequisites.
2. **Backfill is in its OWN migration file** — does not combine table creation + backfill in one. Rollback semantics are cleaner.
3. **Backfill uses `execute/1` with raw SQL** or `Ecto.Migration.flush/0` between DDL and DML within a single migration if combined. Default to separate files.
4. **Backfill is idempotent** — safe to `ecto.migrate` twice. Use `INSERT ... ON CONFLICT DO NOTHING` + `UPDATE ... WHERE ... IS NULL`. Migration has a `down/0` that reverses the backfill.
5. **Batched backfill for large user tables:** process 100 users per batch, `IO.puts` progress, commit per batch. OOM on a 1M-user install is a real risk otherwise.
6. **Adapter branch** (PG/MySQL/SQLite) — v1.0 already does this at `sigra.install.ex:89`. Reuse the pattern; don't use PG-specific syntax in cross-adapter migrations.
7. **Test**: run migrations → rollback → re-run → assert idempotency.

**Warning signs:** backfill + DDL in one file; no batch markers; PG-specific SQL in cross-adapter migration; no rollback test.

**Phase to address:** Phase 8 (backfill + generator).

**Source:** OneUptime Ecto migration guide — https://oneuptime.com/blog/post/2026-02-02-elixir-ecto-migrations/view

---

### Pitfall X-3: Conditional template leakage into `--no-X` installs
**Severity:** MEDIUM
**IMP+:** no direct impact

**What goes wrong:** User runs `mix sigra.install --no-organizations`. Generator skips org templates. But `router.ex` injection emits `live "/orgs/switch", OrganizationSwitcherLive`. Compile fails on first `mix compile` because `OrganizationSwitcherLive` doesn't exist. Same class: layout template unconditionally renders `<.live_component module={OrganizationSwitcher} />`.

**Prevention:**
1. **Every injection site checks feature enablement.** `Features.Organizations.injections(binding)` is the only source of org-related injections — nothing else knows the route list.
2. **Generator templates use conditional EEx blocks gated on `@features` binding:**
   ```
   <%= if :organizations in @features do %>
     live "/orgs/switch", OrganizationSwitcherLive
   <% end %>
   ```
3. **Post-generate `mix compile` check**: generator runs `System.cmd("mix", ["compile", "--warnings-as-errors"])` in the host project after file writes. Failure → generator reports clearly and suggests rollback. Document the "generator compile failed, what do I do" path.
4. **Combinatorial CI smoke test** (same as X-1 §5) catches this class.
5. **Ban unconditional references from core templates to feature modules.** `Features.Core` templates MUST compile with zero other features enabled.

**Warning signs:** any file in `priv/templates/sigra.install/core/` references `Organization*`, `UserPasskey`, `OrganizationInvitation`; injection builders ignore the features list.

**Phase to address:** Phase 1 (feature system) + Phase 8 + Phase 12 (wirings).

**Source:** ARCHITECTURE.md C1

---

### Pitfall X-4: Existing v1.0 installs upgrade — users mid-session during migration
**Severity:** MEDIUM
**IMP+:** no direct impact

**What goes wrong:** Production app upgrades from Sigra 1.0 → 1.1. Users are mid-session with `session.active_organization_id = nil` (column just added). LiveView `on_mount` hydration tries to load an org from nil → nil branch exists → OK. But the generated `Layout.render` calls `@current_scope.active_organization.name` unconditionally → crash for every active user until they reload against the new layout.

**Prevention:**
1. **Every template access to org fields is nil-guarded:** `<%= @current_scope.active_organization && @current_scope.active_organization.name %>` or `.name || "Personal"`. Generator enforces this in templates.
2. **Layout "create your first org" CTA** renders when `active_organization == nil`. Always nil-safe rendering.
3. **Generator emits v1.0 → v1.1 upgrade notes** in `guides/upgrading-1-0-to-1-1.md`: "before deploying, verify your layout handles `nil` active_organization", "expect brief no-op redirects for users without orgs until they create one."
4. **Test upgrading from v1.0:** `test/upgrade_test.exs` fixture installs v1.0 example app, runs v1.1 install task with `--no-backfill-personal-orgs`, asserts no crashes on the 10 main routes.
5. **Rolling-deploy safe:** migrations add columns as nullable; code deploys handle both shapes during the rolling window.

**Warning signs:** any `.name` / `.slug` / `.id` access on `active_organization` without nil guard; no upgrade guide; no upgrade test.

**Phase to address:** Phase 13 (docs + upgrade test).

**Source:** Agnite Studio cross-tenant leakage — https://agnitestudio.com/blog/preventing-cross-tenant-leakage/ (pattern: half-migrated installs are the riskiest moment).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|---|---|---|---|
| Store `organization_id` in audit `metadata` JSONB instead of a real column | Fewer migration files in v1.1 | Unindexed queries, slow per-org audit views in v1.2, breaks v1.2 admin dashboard | **Never** — promote to real column in v1.1 (ARCHITECTURE E) |
| Skip `effective_user_id` until v1.2 actually needs it | Smaller v1.1 scope | Backfill hell when v1.2 lands — have to run a migration that guesses attribution | **Never** — add in v1.1 (O-7) |
| Use unencrypted `public_key` on passkeys | Simpler, passkey public keys aren't secret anyway | Breaks v1.0 precedent of "all sensitive material goes through Cloak"; inconsistent key-rotation surface | Acceptable only if audited + documented |
| Hardcode RP ID at compile time | Simpler config parse | Every env needs a rebuild; breaks multi-env / PR review apps | **Never** (P-3) |
| Pass tenant_id to Oban workers via process dictionary | Less boilerplate | Process dict is lost on job serialization; silent cross-tenant jobs | **Never** (O-11) |
| Skip Credo custom check, rely on review | No tooling investment | First missed filter is a data leak | Acceptable only if integration tests enforce 100% (belt-and-suspenders still recommended) |
| Auto-rename slug on collision instead of validation error | Smoother signup UX | Users get unexpected slugs, support tickets, squatting via rapid collision harvesting | **Never** (O-9) |
| Single challenge per server (ETS global) instead of per-session | Faster implementation | Breaks multi-node; one tab invalidates another's ceremony | **Never** — Plug session (P-1, P-8) |
| Allow invitation token reuse | Simpler acceptance flow | Replay attacks, seat occupation | **Never** (O-3) |
| One migration file for backfill + table creation | Cleaner timestamp list | Rollback ambiguity, partial-apply risk | **Never** (X-2) |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| `wax_` library | Hand-roll base64url on both sides instead of using SimpleWebAuthn bridge | Use `@simplewebauthn/browser` on client, build a ~40-line `Sigra.Passkeys.WaxJson` bridge (STACK.md §5) |
| `wax_` challenge | Store in ETS (assumed single-node) | Store in signed+encrypted Plug session (ARCHITECTURE B1) |
| `cloak_ecto` on passkey `public_key` | Query `WHERE public_key = ?` | Unqueryable by design — look up by `credential_id` (STACK.md §2) |
| `Sigra.Token` HMAC for invites | Store plaintext token in DB | Hash before store (`Sigra.Token.generate_hashed_token/0`) — v1.0 pattern |
| `Oban` worker enqueue | Read `current_user` from process context | Pass `user_id` + `organization_id` + `effective_user_id` in args; reconstruct scope in `perform/1` (O-7, O-11) |
| Phoenix 1.8 `on_mount` scope hydration | Re-fetch org on every render | Load once in `on_mount`, refresh only on `handle_params` when session differs (O-5) |
| `Hammer` rate limiter | One global key for passkey ceremonies | Per-user key `"passkey_ceremony:#{user_id}"` 5/min (STACK.md integration map) |
| Swoosh mailer | Pass org to email builder via process dict | Optional `opts[:organization]` param; template nil-safe (ARCHITECTURE A6) |
| `citext` email column | Compare invite email case-sensitively | Case-insensitive match via `citext`; reject if casing differs (O-2) |
| LiveView hook ↔ controller | Complete login via `push_event` | Auto-submit hidden form to POST controller — rotate Plug session via HTTP (ARCHITECTURE B5, D-v1.1-passkey-login-post) |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|---|---|---|---|
| Audit org filter via JSONB metadata operator | Slow `@ >` queries on large audit tables | Promote `organization_id` to real indexed column (O-7) | ~100k audit rows |
| Backfill migration loads all users into memory | OOM on production migration | Batched migration (100 rows/tx) with progress (X-2) | ~10k users |
| N+1 loading `membership` on every request | Each request = 2 extra queries | Single JOIN query in `LoadActiveOrganization` plug | Always |
| No index on `organization_memberships (user_id, organization_id)` | Slow switcher dropdown | Unique composite index (ARCHITECTURE A2) | ~1k users with 5+ orgs |
| No index on `user_passkeys.credential_id` | Slow authentication lookup | Unique index (ARCHITECTURE B3) | Immediately — auth path |
| Scope reload on every LiveView event | LV latency spike | Load scope once per `mount`, cache in socket assigns, invalidate on explicit switch events only | ~50 events/sec per socket |
| Challenge in DB instead of session | DB write per ceremony | Plug session (P-1) | ~500 ceremonies/min |
| No rate limit on invitation creation | Email bomb DoS | Hammer per-user: 20/day default | Immediately |
| No rate limit on passkey ceremonies | WebAuthn flood → server CPU | Hammer per-user: 5/min (STACK.md map) | Immediately |

---

## Security Mistakes (domain-specific, beyond OWASP basics)

| Mistake | Risk | Prevention |
|---|---|---|
| Accept `organization_id` from form params | BOLA — act on wrong org | Always read from `scope.active_organization.id`; cast `:organization_id` out in changesets (O-5) |
| Role enum from params | Admin self-promotion | Role changes only via `Sigra.Organizations.update_membership_role/3`, never via direct `cast` |
| Server reads challenge from `clientDataJSON` | WebAuthn replay (P-1 / OneUptime CVE) | Server-stored challenge; delete on verify |
| Invitation email not bound to current_user | Invite hijack (O-2 / Jetstream / Keycloak) | Case-insensitive email assertion at accept time |
| Passkey enrollment in normal pipeline | Stolen-session perma-takeover (P-2) | Gate with `Sigra.Plug.RequireSudo` |
| Forward `rp_id` from request param | Host-header attack | RP ID is runtime config only, never request-derived (P-3) |
| Store plaintext invitation token | DB leak → replay | Hash before store (O-3) |
| Auto-generate on slug collision | Squatting vector | Validation error (O-9) |
| Apply CASCADE to `audit_events.organization_id` | Compliance violation — audit rows wiped with org | `nilify_all` + keep org name/slug snapshot in metadata (O-10) |
| Username enumeration via `allowCredentials` timing | Account discovery | Constant-time, constant-shape "no such user" path (P-6) |
| Credential-ID lookup without asserting requested user match | StrongKey-class bypass (P-6) | Server verifies credential belongs to requested user |
| Passkey-as-sole-factor without enforced recovery | Permanent account loss (P-5) | At least one fallback mandatory |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---|---|---|
| Silent org switch on another tab | User posts comment in wrong org | Re-verify `session.active_organization_id` on every request; surface mismatch (O-5) |
| "Accept invitation" button shown when logged in as wrong user | User clicks → unexpected account join | Email-mismatch page with sign-out CTA, no accept button (O-2) |
| Generic "passkey registration failed" error | User can't troubleshoot | SimpleWebAuthn error codes → specific messages ("Passkey cancelled", "Device already registered", "Browser unsupported") (P-8) |
| No passkey nickname | User can't tell which device is which | Mandatory nickname field + transports display (P-9) |
| Delete last passkey with no warning | Account lockout if no fallback | Sudo + explicit modal + list of other factors (P-5) |
| Last owner gets "you can't leave" with no recourse | Stuck forever | "Transfer ownership" flow visible on the same screen (O-4) |
| Personal org auto-created silently | Confusion about which org is mine | Don't auto-create; prompt on first org-scoped action (O-8) |
| RP ID misconfigured error is cryptic | User bounces | NimbleOptions validation at boot with clear error (P-3) |
| Passkey prompt never appears on unsupported browser | User thinks app is broken | `PublicKeyCredential` feature-detection + fallback message (P-9) |
| Invite link on shared device → accepted by wrong user | Account compromise | Require sign-out + re-sign-in as invitee (O-2) |

---

## "Looks Done But Isn't" Checklist

- [ ] **Cross-tenant query isolation:** verify `test/sigra/organizations/isolation_test.exs` exists and fails when `for_org` is removed from any one function (mutation-test the guard)
- [ ] **Invitation email-mismatch:** verify the accept test matrix covers (logged-out, logged-in-as-invitee, logged-in-as-other-user, expired, revoked, already-accepted)
- [ ] **Last-owner guard:** verify test creates 2 owners, removes 1 OK; creates 1 owner, removes 1 fails; demotes last owner to admin fails
- [ ] **Stale active org:** verify test removes user from active org mid-session and asserts graceful fallback (no 500)
- [ ] **Audit `effective_user_id` column:** verify v1.1 migration adds it (even though unused in v1.1); verify every audit test asserts `user_id == effective_user_id`
- [ ] **Audit `organization_id` column:** verify it's a real column (not JSONB); verify the unique FK design (`nilify_all`, not `delete_all`)
- [ ] **Backfill idempotency:** verify running the backfill migration twice produces the same state
- [ ] **Backfill rollback:** verify `mix ecto.rollback` on backfill migration cleans up personal orgs
- [ ] **Reserved slug list:** verify `admin` is rejected (forward-compat with v1.2)
- [ ] **Challenge storage:** verify the challenge is NEVER read from the request body — grep `Sigra.Passkeys` for "params" near `Wax.`
- [ ] **Challenge single-use:** verify session challenge is deleted after verify (success AND failure paths)
- [ ] **Challenge TTL:** verify expired challenge produces a specific error, not a crash
- [ ] **Sign-count regression policy:** verify default is `:warn`, not `:revoke`
- [ ] **Sign-count zero case:** verify stored=0 + received=0 does NOT audit a regression event
- [ ] **Passkey enrollment sudo gate:** verify `PasskeyEnrollmentLive` has `RequireSudo` in the plug pipeline, not just the mount
- [ ] **Passkey registration email notification:** verify email is sent on every registration with revoke link
- [ ] **RP ID runtime config:** verify config is in `runtime.exs`, not `config.exs`; verify boot validation rejects bad shapes
- [ ] **RP ID rename docs:** verify `guides/passkeys.md` has the "what if I rebrand" playbook
- [ ] **SimpleWebAuthn abort:** verify hook `destroyed()` callback aborts the pending ceremony
- [ ] **Two-tab ceremony cleanup:** verify starting a second ceremony cleanly invalidates the first
- [ ] **Generator combinatorial smoke:** verify CI tests `{org, no_org} × {passkey, no_passkey}` combinations compile
- [ ] **Generator idempotency:** verify re-running `mix sigra.install --organizations` on an existing install is a no-op (or prompts)
- [ ] **Template nil-guard:** grep generated templates for `@current_scope.active_organization.` without a preceding `&&` or `!= nil` check
- [ ] **v1.0 → v1.1 upgrade test:** verify an install-on-v1.0-then-upgrade path exists in CI
- [ ] **Last-passkey delete warning:** verify modal + sudo + fallback check
- [ ] **Passkey username-enumeration test:** verify the "start ceremony with user A's username, sign with user B's key" test exists and rejects

---

## Recovery Strategies

When a pitfall ships anyway, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---|---|---|
| O-1 cross-tenant leak in production | **HIGH** | 1) Hotfix the missing filter; 2) audit-log all suspicious queries from past 30 days; 3) disclosure to affected tenants per SOC2; 4) add integration test that would have caught it; 5) add Credo check |
| O-2 invitation hijack | **HIGH** | 1) Revoke all outstanding invitations (`UPDATE invitations SET revoked_at = now()`); 2) audit memberships created in the window; 3) email affected orgs; 4) ship email-bound validation; 5) re-issue invitations |
| O-4 owner lockout | **MEDIUM** | DB surgery to promote a trusted member back to owner; then ship last-owner guard |
| O-7 audit attribution wrong | **HIGH** (post-v1.2 only) | Backfill migration using best-effort attribution (impossible to recover cleanly); ship `effective_user_id` + warn on wrong rows |
| O-8 backfill partially applied | **MEDIUM** | Rollback the backfill migration, fix the batching, re-run |
| O-9 slug squatting discovered | **LOW-MEDIUM** | Rename squatted slugs via admin; add to reserved list; notify affected users |
| O-10 cascade deleted audit rows | **CRITICAL** | Restore from backup; re-run the deletion with correct `on_delete`; full compliance review |
| O-11 worker leaked tenant context | **HIGH** | Same as O-1; audit worker-written data for cross-tenant rows |
| P-1 replay attack exploited | **CRITICAL** | Revoke all passkeys, force re-enrollment under sudo, audit all sessions from the window, disclosure |
| P-2 passkey enrolled via stolen session | **HIGH** | User clicks the "revoke" email link; session invalidation; force password reset; re-enroll under sudo |
| P-3 RP ID rename broke passkeys | **HIGH** | Deploy Related Origin Requests `.well-known/webauthn`; if already past the point, force re-enrollment via magic link |
| P-4 false-positive sign-count revoke | **LOW** | Re-enable the affected passkey; switch policy to `:warn`; apologize |
| P-5 passkey-only user lost device | **MEDIUM** | Magic link → new session → re-enroll → revoke old |
| P-6 username enumeration | **MEDIUM** | Patch the flow to constant-time; review access logs for probing |
| P-8 zombie ceremony state | **LOW** | Clear session; user retries |
| X-1 generator partial-apply | **MEDIUM** | Document rollback; ship `mix sigra.install.check` |
| X-2 migration order bug | **HIGH** | Restore from backup; fix the ordering; re-deploy |

---

## Pitfall-to-Phase Mapping

Phase numbers track ARCHITECTURE Part D build order.

| Pitfall | Prevention Phase(s) | Verification |
|---|---|---|
| O-1 cross-tenant leak | Phase 3 (helper), Phase 4 (plug), Phase 5 (test) | Integration test + Credo check |
| O-2 invitation hijack | Phase 7 | Email-mismatch test matrix |
| O-3 invite replay | Phase 7 | "Accept twice" test |
| O-4 last owner | Phase 3 + 6 | "Remove last owner" test |
| O-5 cross-org session | Phase 4 + 6 | Multi-tab test |
| O-6 stale active org | Phase 4 | "Remove user mid-session" test |
| O-7 audit attribution (IMP+) | Phase 5 | `effective_user_id` column shipped |
| O-8 personal org / backfill | Phase 8 | Idempotency test + rollback test |
| O-9 slug squatting | Phase 3 (+ Phase 8 generator) | Reserved-list test |
| O-10 cascade delete | Phase 3 + 5 | FK matrix test |
| O-11 worker tenant context | Phase 5 + 9 | Worker isolation test |
| P-1 challenge replay | Phase 9 + 10 | Replay test |
| P-2 enrollment without re-auth (IMP+) | Phase 11 | Sudo gate test + email test |
| P-3 RP ID rename | Phase 9 + 10 + 13 | Config validation boot test |
| P-4 sign count | Phase 9 | Policy test + zero-case test |
| P-5 passkey sole factor | Phase 11 | "Delete last passkey" test |
| P-6 username enumeration | Phase 9 | Constant-time test + StrongKey test |
| P-7 attestation default | Phase 9 | Default is `:none` test |
| P-8 JS hook lifecycle | Phase 10 + 11 | Cancel/timeout/two-tab tests |
| P-9 platform UX | Phase 11 + 13 | Manual UAT + docs |
| P-10 API hijacking | Phase 13 | Honest docs + CSP guidance |
| P-11 CVE-2024-9956 | Phase 13 | Threat model section |
| X-1 generator partial-apply | Phase 1 + 13 | Combinatorial CI smoke |
| X-2 migration ordering | Phase 8 | Idempotency + rollback test |
| X-3 conditional template leakage | Phase 1 + 8 + 12 | Compile in all combos |
| X-4 v1.0 → v1.1 upgrade | Phase 13 | Upgrade test |

---

## Sources

### CVEs / Advisories
- **CVE-2024-9956** — Chrome Android passkey FIDO:/ intent hijack — https://mastersplinter.work/research/passkey/
- **CVE-2025-26788** — StrongKey FIDO server passkey bypass — https://www.securing.pl/en/cve-2025-26788-passkey-authentication-bypass-in-strongkey-fido-server/
- **CVE-2026-1529** — Keycloak invitation token bypass — https://advisories.gitlab.com/pkg/maven/org.keycloak/keycloak-services/CVE-2026-1529/
- **GHSA-gjjc-pcwp-c74m** — OneUptime WebAuthn challenge replay — https://github.com/OneUptime/oneuptime/security/advisories/GHSA-gjjc-pcwp-c74m

### GitHub Issues / Bug Reports
- Jetstream invitation hijack (#907) — https://github.com/laravel/jetstream/issues/907
- duo-labs webauthn.io CookieStore replay (#28) — https://github.com/duo-labs/webauthn.io/issues/28
- W3C webauthn RP ID clarification (#963, #1731) — https://github.com/w3c/webauthn/issues/963
- W3C webauthn sign count (#1590, #1008, #1734) — https://github.com/w3c/webauthn/issues/1590
- pinnwand slug race (#34) — https://github.com/supakeen/pinnwand/issues/34

### Post-mortems / Research
- "Multi-Tenant Leakage: When RLS Fails in SaaS" — https://medium.com/@instatunnel/multi-tenant-leakage-when-row-level-security-fails-in-saas-da25f40c788c
- "Six Shades of Multi-Tenant Mayhem" — https://borabastab.medium.com/six-shades-of-multi-tenant-mayhem-the-invisible-vulnerabilities-hiding-in-plain-sight-182e9ad538b5
- "The Multi-Tenancy Bug That Leaked 10,000 User Records" — https://bytemedaily.medium.com/the-multi-tenancy-bug-that-leaked-10-000-user-records-d133d4c59447
- "Privilege Escalation Allow Admin to Delete Owner" — https://medium.com/@islamghandar/admin-can-delete-workspace-owner-leading-to-organization-takeover-45de0c78fb60
- "Luminate Admin-to-Owner Escalation" — https://medium.com/@rojanrijal/luminate-internal-privilege-escalation-admin-to-owner-2ca28e575985
- "Invitation Hijacking" (Vishal Barot) — https://medium.com/@kshunya/invitation-hijacking-4d6467f418cc
- "The WebAuthn Loop: Common Logic Flaws" — https://medium.com/@instatunnel/the-webauthn-loop-common-logic-flaws-in-the-passwordless-handshake-017065517f83
- "Passkeys Pwned — DEF CON 33" — https://labs.sqrx.com/passkeys-pwned-turning-webauth-against-itself-0dbddb7ade1a
- "WebAuthn API Hijacking" — https://freemindtronic.com/webauthn-api-hijacking-ciso-guide-nullifying-phishing-en/
- "How Attackers Bypass Synced Passkeys" — https://thehackernews.com/2025/10/how-attackers-bypass-synced-passkeys.html
- ImperialViolet — Signature counters — https://www.imperialviolet.org/2023/08/05/signature-counters.html
- Agnite — Preventing Cross-Tenant Data Leakage — https://agnitestudio.com/blog/preventing-cross-tenant-leakage/

### Specs / Official Docs
- W3C WebAuthn Level 2 — https://www.w3.org/TR/webauthn-2/
- OWASP Multi-Tenant Security Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html
- Related Origin Requests Explainer — https://github.com/w3c/webauthn/wiki/Explainer:-Related-origin-requests
- Ecto Migration docs — https://hexdocs.pm/ecto_sql/Ecto.Migration.html
- NIST SP 800-63B (phishing-resistant MFA)

### Vendor docs (how mature products handle these)
- Auth0 Organizations invite flow — https://auth0.com/docs/manage-users/organizations/configure-organizations/invite-members
- Clerk organization slugs — https://clerk.com/docs/guides/organizations/org-slugs-in-urls
- Corbado RP ID guide — https://www.corbado.com/blog/webauthn-relying-party-id-rpid-passkeys
- Corbado passkey recovery — https://www.corbado.com/blog/passkey-fallback-recovery
- Authsignal passkey recovery — https://www.authsignal.com/blog/articles/passkey-recovery-fallback
- Ory passkey troubleshooting — https://www.ory.com/docs/troubleshooting/passkeys-webauthn-security-error
- Yubico attestation developer guide — https://developers.yubico.com/WebAuthn/Concepts/Securing_WebAuthn_with_Attestation.html
- Spomky-labs webauthn-framework authenticator counter — https://webauthn-doc.spomky-labs.com/v3.3/deep-into-the-framework/authenticator-counter
- SimpleWebAuthn docs — https://simplewebauthn.dev/docs/packages/browser/
- Google Workspace DBSC — https://workspace.google.com/blog/identity-and-security/defending-against-account-takeovers-top-threats-passkeys-and-dbsc

### Sigra internal (v1.1 decisions referenced)
- `/Users/jon/projects/sigra/.planning/PROJECT.md`
- `/Users/jon/projects/sigra/.planning/research/STACK.md` (v1.1)
- `/Users/jon/projects/sigra/.planning/research/ARCHITECTURE.md` (v1.1)
- `/Users/jon/projects/sigra/.planning/v1.2-DIRECTION.md` (forward-compat)

---
*Pitfalls research for: Sigra v1.1 Foundations — Organizations + Passkeys, as additions to a shipped Phoenix 1.8+ auth library, with v1.2 impersonation forward-compat checked.*
*Researched: 2026-04-11*
