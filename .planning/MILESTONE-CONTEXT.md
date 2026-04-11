---
source: conversation with user on 2026-04-11
status: draft — to be consumed by /gsd-new-milestone
milestone_target: v1.1 "Foundations"
---

# v1.1 Foundations — Captured Direction

This file holds in-flight milestone context that hasn't been formalized into
PROJECT.md / REQUIREMENTS.md yet. The `/gsd-new-milestone` workflow consumes
and deletes this file once requirements are written.

Scope decision recorded in
`/Users/jon/.claude/plans/breezy-beaming-beacon.md` (2026-04-11): the user
initially wanted a single "admin UI + passkeys" milestone but then surfaced
organizations/multi-tenancy and impersonation as also-important. After
sequencing discussion, we split the work into two milestones:

- **v1.1 "Foundations"** — Organizations (logical multi-tenancy) + Passkeys.
  No admin UI. Architectural foundation that unblocks v1.2.
- **v1.2 "Admin Dashboard"** — Admin UI (Django-admin-loved), Impersonation,
  expanded Audit views. Built org-aware from day 1 on the v1.1 foundation.
  Full direction captured in `.planning/v1.2-DIRECTION.md`.

## v1.1 Scope (confirmed 2026-04-11)

- **[ANCHOR-1]** Organizations / logical multi-tenancy
- **[ANCHOR-2]** WebAuthn / Passkeys

Both anchors are architecturally independent — zero shared code paths. They
ship together because:
1. Organizations must land before the v1.2 admin UI (otherwise the admin UI
   gets retrofit with org-scoping everywhere — painful and error-prone).
2. Passkeys is self-contained and small enough that pairing it with the
   bigger Organizations lift gives v1.1 a complete narrative without
   blocking v1.2.

## v1.1 Milestone goal

> Ship the architectural foundation that unlocks v1.2's admin dashboard:
> logical multi-tenancy (organizations + memberships, single DB, no PG
> schema-per-tenant complexity) and passkey/WebAuthn authentication. Only
> the user-facing surface each feature needs to be usable end-to-end — no
> admin UI.

---

## Anchor 1: Organizations (logical multi-tenancy)

### User direction (their own words, paraphrased lightly)

> "We'll need to add organization-type multi-tenancy and stuff — I think it's
> important. I'm not saying we want to build some total amazing multi-tenancy
> solution because I think that might possibly be a little out of scope ...
> but we at least need logical organization support even if we don't go crazy
> down the path of like trying to divide it into different PG schemas etc.
> I feel like that stuff is out of scope but at least we can have logical
> organizations. I guess we could support other schemas like in PG but we
> just have to consider that this is more realistically about being able to
> support multiple orgs/teams in your app. ... Great in the happy path and
> also some of the paths that developers will go down with this — like in
> error cases and boundary conditions — so that it's great for onboarding
> and the common case but also in some of the main edge cases that people
> would run into with multi-tenancy in their applications."

### Non-negotiables

1. **Logical multi-tenancy only.** Single DB, single PG schema, `org_id` FK
   pattern. No schema-per-tenant or DB-per-tenant modes. Document in
   `Sigra.Organizations` moduledoc that host apps needing physical isolation
   can layer their own adapter; Sigra doesn't prevent it.
2. **Great DX on happy path AND main error/boundary paths.** Invite flows,
   role changes, member removal, last-owner lockout, cross-org confusion —
   all handled explicitly with clear UX feedback.
3. **First-class citizen, naturally slotted in.** Not an add-on bolted onto
   the side — orgs thread through `current_scope`, audit metadata, session
   state, email templates, and the testing helpers.
4. **Default ON, opt-out via `--no-organizations`.** Consistent with the
   v1.0 convention that security-critical features are on by default.

### Functional scope (to refine in `/gsd-discuss-phase`)

**Schemas generated into host app:**
- `Organization` — `id`, `name`, `slug` (unique), `settings` jsonb,
  `deleted_at`, timestamps
- `OrganizationMembership` — `user_id`, `organization_id`, `role` (enum:
  `owner` / `admin` / `member`), `status` (`active` / `invited` /
  `suspended`), `joined_at`, `invited_by_id`
- `OrganizationInvitation` — `email`, `organization_id`, `role`,
  `hashed_token`, `expires_at`, `accepted_at`, `revoked_at`

**Library modules (in `lib/sigra/`):**
- `Sigra.Organizations` — CRUD + membership ops + invite tokens (HMAC via
  existing `Sigra.Token` pattern)
- `Sigra.Organizations.Membership` — query helpers (list memberships for
  user, check role, last-owner guard)
- `Sigra.Plug.RequireMembership` — enforces `current_scope` has an active
  org membership

**Scope + session extension:**
- Extend `%Scope{}` struct with `:active_organization`, `:membership`
- `fetch_current_scope` plug loads active org from session
- LiveView `on_mount` assigns org to socket
- `sessions` table gains `active_organization_id` (nullable — users with
  no orgs still work)

**Audit integration:**
- Every audit row automatically carries `organization_id` in `metadata` if
  `current_scope.active_organization` is set (one helper change in
  `lib/sigra/audit.ex`)
- `Sigra.Audit.query/1` gains `:organization_id` filter via metadata jsonb
  operator

**Auth flows org-awareness:**
- Registration: optional "create organization" step; invite-token query
  param flows register-into-org
- Login: if user has ≥2 orgs, session starts with last-active or prompts
  pick; if 1 org, auto-selected; if 0 orgs, standard behavior
- Sessions LiveView displays active org per session

**User-facing LiveViews (minimal — no admin UI yet):**
- `OrganizationSwitcherLive` — dropdown/modal to switch active org
- `OrganizationSettingsLive` — owner-only: rename, slug change, delete org
- `OrganizationMembersLive` — list members, invite, remove, change role
- `InvitationAcceptLive` — accept an invite token (existing user signs in,
  new user signs up with email pre-filled)

**Invite flow:**
- Owner/admin enters email → `OrganizationInvitation` row + HMAC token
- Email template: `organization_invitation_email.ex`
- Accept URL: `/orgs/invitations/:token/accept`
- Accept with existing account → membership row, redirect
- Accept with new account → signup flow with email pre-filled, membership
  created on confirm
- Expire after 7 days default, configurable
- Revocable by owner/admin

**Generator integration (`mix sigra.install`):**
- `--organizations` flag (default ON), `--no-organizations` opts out
- **Introduces first conditional template pattern** — design carefully
  because v1.2 admin UI will reuse it (`--admin` / `--no-admin`)
- Existing installs: backfill migration creates "personal" orgs for all
  existing users (documented, skippable)

**Testing helpers:**
- `Sigra.Testing.create_organization/1`
- `Sigra.Testing.add_membership/3`
- `Sigra.Testing.log_in_user_with_org/3`

### Explicitly NOT in v1.1 scope

- PG-schema-per-tenant or DB-per-tenant modes
- Full RBAC / permission policies (roles are a 3-enum convention only;
  authorization stays out of Sigra's scope per PROJECT.md)
- Nested orgs / sub-orgs / workspaces-within-orgs
- Cross-org user merging or data transfer
- Org-level billing integration
- Custom roles beyond the 3 defaults
- SCIM provisioning
- **Admin UI for org management — deferred to v1.2**
- **Admin impersonation — deferred to v1.2**

---

## Anchor 2: Passkeys / WebAuthn

### Why now

Explicitly deferred from v1.0 (see PROJECT.md Key Decisions: "WebAuthn /
passkeys deferred from v1.0 MFA — v1.1 candidate"). `wax_ ~> 0.7` was
evaluated during v1.0 research as the only maintained Elixir WebAuthn RP
library (passes all 170 official test suite tests). No unknown unknowns on
the stack side.

### Scope

**Dependency:** `wax_ ~> 0.7`

**Schema generated into host app:**
- `UserPasskey` — `user_id`, `credential_id` (bytea, unique), `public_key`
  (bytea, encrypted via `cloak_ecto`), `sign_count` (integer), `aaguid`,
  `nickname`, `device_hint`, `last_used_at`, `transports` array, timestamps

**Library modules:**
- `Sigra.Passkeys` — context for registration, authentication, credential
  CRUD, challenge verification via `wax_`
- `Sigra.Passkeys.Registration` — ceremony options + response verification
- `Sigra.Passkeys.Authentication` — ceremony options + response verification
- `Sigra.Plug.PasskeyChallenge` — short-lived challenge storage

**Two modes:**
1. **Passkey as second factor** — alongside TOTP. MFA prompt shows both
   options. Backup codes still work.
2. **Passkey as primary passwordless** — opt-in, log in with email +
   passkey (usernameless where platform supports). Password path remains
   unless user explicitly disables.

**LiveViews / controllers:**
- `PasskeyEnrollmentLive` — JS hook calling `navigator.credentials.create`
- `PasskeyAuthenticationLive` — JS hook calling `navigator.credentials.get`
- Update `MfaSettingsLive` to show passkeys alongside TOTP + backup codes
  (rename / delete)

**Config (runtime, not compile):**
- `rp_id` from env (domain)
- `rp_name` from config
- `origin` from env (respects multi-origin dev/prod)
- `attestation_preference` configurable (`:none` default)

**JS hooks:**
- `priv/templates/sigra.install/passkey_hooks.js`

**Testing helpers:**
- `Sigra.Testing.register_passkey/2`
- `Sigra.Testing.authenticate_with_passkey/2`

**Generator changes:**
- `--passkeys` flag (default ON) / `--no-passkeys` opt-out
- Migration: create `user_passkeys` table
- Router: passkey routes under MFA scope
- JS bundle: include passkey hooks

### Explicitly NOT in v1.1 scope

- Admin revocation of passkeys (deferred to v1.2 admin UI)
- FIDO metadata service integration / attestation policy engine
- Conditional UI autofill beyond what `wax_` natively supports
- Cross-device hand-off beyond OS/browser native support
- Device trust scoring

---

## Research assignments (mandatory — enable research phase)

The user's explicit direction: "do deep research using subagents on the web
... what did other ones do right, what is their pain points and lessons
learned and we'll want to incorporate that into ours ... think deeply on
this."

Four parallel `gsd-project-researcher` agents. Each covers one dimension.

### STACK.md researcher
- Verify `wax_ 0.7.0` compatibility with OTP 27 / Phoenix 1.8
- Verify `cloak_ecto 1.3.0` key rotation for passkey public keys
- Any new Elixir multi-tenancy libraries shifted since v1.0 research
- Confirm no new "one-true-way" Phoenix org pattern emerged

### FEATURES.md researcher — deep web research

**Multi-tenancy in auth libraries / frameworks:**
- Clerk Organizations API — invite flow, active org switcher, membership,
  what they do well
- Auth0 Organizations — same questions, esp. around per-org branding
- WorkOS Organizations — enterprise-focused; what's worth copying vs
  overshoots for indie SaaS
- Supabase Auth organizations (if any) — PG-native approach
- Better Auth (JS) — plugin-based org support
- Rails + Rodauth multi-account — how does Rodauth-style scale to orgs?
- Django Allauth + organizations
- Laravel Jetstream Teams — one of the most-copied team models; what
  works, what users complain about

**Passkey UX in modern auth dashboards:**
- Clerk, Auth0, GitHub (best-in-class), 1Password, Dashlane
- What are the top UX pain points users report?
- Passkey-as-primary vs passkey-as-2FA conventions

**Invite flow pain points:**
- Signed-token invite failure modes
- Expiry / revocation UX
- Email mismatch on accept
- Invite to new user vs existing user (unified code path or fork?)

### ARCHITECTURE.md researcher — integration into Sigra
- How does `organization_id` travel through `current_scope`, audit
  metadata, session state, Oban job args?
- Correct Ecto pattern: `users JOIN memberships JOIN organizations`
  (users are shared across orgs — `SELECT users WHERE organization_id`
  is WRONG)
- Email template changes for org context ("for the X organization")
- Switcher layout placement (top nav / sidebar / modal)
- Passkey challenge storage: session cookie vs ETS vs DB (security vs
  scaling tradeoff)
- "User's active org" storage: session column vs separate table

### PITFALLS.md researcher — failures and CVEs

**Org multi-tenancy pitfalls:**
- Data leaks via missing org_id filters (most common MT bug class)
- Invite token reuse / replay
- Email-mismatch invite → account hijack vectors
- Role escalation (owner removing self, last-owner lockout)
- Cross-org session confusion
- Audit row attribution errors when impersonation lands later

**Passkey pitfalls:**
- RP ID / origin mismatches on domain rotation
- Account recovery flow bypassing passkey requirement
- Passkey enrollment without re-auth (stolen session enrolls attacker's
  passkey)
- Sign count replay / weak verification
- Platform vs roaming authenticator confusion in UI

**Known CVEs in WebAuthn implementations** (last 2 years)

---

## Open questions (to resolve in `/gsd-discuss-phase`)

1. **Existing user migration** — auto-backfill "personal" orgs or require
   explicit create/join? Default: auto-backfill, skippable.
2. **`slug` uniqueness** — globally unique or tenant-scoped? Default:
   globally unique + reserved word list.
3. **Active org in URL path vs session** — `/orgs/:slug/...` routes vs
   session-only? Default: route-scoped with `/orgs/:slug/` prefix.
4. **Invite email-mismatch policy** — reject with flash or allow? Default:
   reject with explicit flash.
5. **Passkey-as-primary** — can user disable password entirely? Default:
   password always available unless explicitly disabled (sudo + confirm).
6. **Multiple passkeys per user** — hard cap? Default: soft cap 10,
   configurable.
7. **Conditional generator template pattern** — subdir convention or
   manifest file? Load-bearing for v1.2; get it right the first time.

---

## Estimated phase count

**5-7 phases:**
- Phase 11: Organizations foundation (schemas, context, scope extension,
  audit integration, session column)
- Phase 12: Organizations invite + switcher + member management UI
- Phase 13: Organizations generator integration (conditional templates,
  backfill migration, installer flag)
- Phase 14: Passkeys foundation (schema, wax_ integration, challenge plug,
  encryption, library context)
- Phase 15: Passkeys UX (enrollment, authentication, MFA settings update,
  JS hooks)
- Phase 16: Passkeys generator integration (templates, migration, router)
- Phase 17 (optional polish): Cross-cutting — testing helpers, docs,
  getting-started guide updates

Continues phase numbering from v1.0 (which ended at 10.1.1; next is 11).

---

## Prior art in this repo

- `test/example/lib/example/accounts/scope.ex` — current minimal Scope
  struct; extension point for org fields
- `test/example/lib/example_web/user_auth.ex` — `fetch_current_scope` +
  `on_mount` patterns
- `lib/sigra/session.ex` — session struct (`user_id`, `token`, geo, etc);
  adds `active_organization_id`
- `lib/sigra/audit.ex` + `lib/sigra/audit/query.ex` — mature query DSL;
  extends with `:organization_id` filter
- `lib/sigra/plug/require_sudo.ex` — sudo re-auth plug pattern for
  destructive org actions (delete org, remove last owner)
- `lib/sigra/token.ex` — HMAC token generation for invite tokens
- `priv/templates/sigra.install/` — 45 unconditional templates; v1.1
  introduces first conditional pattern
