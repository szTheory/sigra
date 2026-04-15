# Sigra v1.1 Foundations — Requirements

**Milestone:** v1.1 "Foundations" — Organizations + Passkeys
**Status:** Roadmap mapped — 79/79 requirements assigned to phases 11–23
**Last updated:** 2026-04-11

Requirements are written user-centric ("User/developer can X") and grouped
by category. Each maps to exactly one phase during roadmap creation.
Answered discuss-phase questions are inlined as decision notes where they
affect individual requirements.

---

## v1.1 Requirements

### Organizations — Foundation (ORG)

- [ ] **ORG-01**: Developer can add organizations to a new Phoenix app via `mix sigra.install --organizations` (default on) generating `Organization`, `OrganizationMembership`, and `OrganizationInvitation` schemas with migrations.
- [ ] **ORG-02**: Developer can disable organizations entirely via `mix sigra.install --no-organizations`; no org-related templates, schemas, or routes are generated.
- [ ] **ORG-03**: User can be a member of multiple organizations simultaneously with different roles in each; the `users` table has no `organization_id` column (shared-user model).
- [ ] **ORG-04**: User can hold one of three roles per organization: `owner`, `admin`, `member`. Roles are a convention; full RBAC/permission policies remain out of Sigra's scope.
- [ ] **ORG-05**: System prevents the last `owner` of an organization from being removed, demoted, or deleting their own membership — enforced inside an `Ecto.Multi` with a fresh-count check, not via DB constraint (addresses pitfall O-4).
- [ ] **ORG-06**: Developer can query users within an org via the library-provided `Sigra.Organizations.Query.for_org/2` helper that raises on missing `organization_id` (addresses pitfall O-1 — cross-tenant leak).
- [ ] **ORG-07**: System blocks reserved slugs at creation time via a hardcoded reserved-word list including `admin`, `api`, `www`, `static`, and ~20 others (addresses pitfall O-9 + prevents v1.2 `/admin` route collision).
- [ ] **ORG-08**: Organization deletion is soft-delete by default (sets `deleted_at`); hard-delete is a separate operator-only path. Audit rows referencing a deleted org survive via `ON DELETE NULLIFY` on `audit_events.organization_id` (addresses pitfall O-10).

### Organizations — Scope + Session (ORG-SCOPE)

- [ ] **ORG-SCOPE-01**: System extends `%Scope{}` with `:active_organization`, `:membership`, and (reserved, unused in v1.1) `:impersonating_from` fields — the reserved field exists so v1.2 impersonation is purely additive.
- [ ] **ORG-SCOPE-02**: System stores `active_organization_id` on the `user_sessions` table (nullable). "Last active" for returning users comes from the most recent non-nil value across their sessions — per-session, not per-user.
- [ ] **ORG-SCOPE-03**: System exposes `Sigra.Plug.LoadActiveOrganization` that runs after `fetch_current_scope` to hydrate `scope.active_organization` and `scope.membership` from the session; if the session's `active_organization_id` points at an org the user is no longer a member of (stale pointer), the plug resets the scope rather than 500ing (addresses pitfall O-6).
- [ ] **ORG-SCOPE-04**: System exposes `Sigra.Plug.RequireMembership` for routes requiring org-scoped access, optionally filtered by role list.
- [ ] **ORG-SCOPE-05**: LiveView `on_mount` hydrates `current_scope.active_organization` + `membership` from the serialized session map — matches the plug-path behavior.
- [ ] **ORG-SCOPE-06**: User can log in when they belong to zero orgs, one org, or 2+ orgs without a dead-end: zero = prompt to create or accept invite; one = auto-select; 2+ = resume last-active or show picker.

### Organizations — User-Facing (ORG-UX)

- [ ] **ORG-UX-01**: User can create a new organization from the app UI, choosing a name; slug is auto-generated with a reserved-word check.
- [ ] **ORG-UX-02**: User can view and switch their active organization via a dropdown in the header (daisyUI dropdown component). The switcher shows active org + role badge, other orgs, create-org link, and settings link for owners/admins.
- [ ] **ORG-UX-03**: Switching organizations submits a POST to a plain controller (not a LiveView event) which rotates the Plug session's `active_organization_id` and redirects back to the referrer — matches v1.0's "sensitive-mutation-via-POST" convention.
- [ ] **ORG-UX-04**: Organization owner can rename their organization and change the slug (slug change requires re-confirmation + history redirect for 7 days).
- [ ] **ORG-UX-05**: Organization owner can delete their organization (soft-delete by default, sudo re-auth required, typed-confirmation of the org name).
- [ ] **ORG-UX-06**: Organization owner or admin can view the member list showing email, role, status, joined date, and last-active timestamp.
- [ ] **ORG-UX-07**: Organization owner or admin can change a member's role (owner/admin/member) with confirmation.
- [ ] **ORG-UX-08**: Organization owner or admin can remove a member (which revokes the membership and force-logs-out that user's org-scoped sessions).
- [ ] **ORG-UX-09**: No "personal organization" is auto-created on user registration. Signup flow offers an optional "create your first organization" step; users can also accept pending invites during signup. **(Decision: no auto-backfill on signup; opt-in flag for v1.0 upgraders only.)**

### Organization Upgrade Path (ORG-UPGRADE)

- [ ] **ORG-UPGRADE-01**: Developer upgrading a v1.0 install can opt into `mix sigra.upgrade --backfill-personal-orgs` to generate a personal org per existing user. Idempotent, batched, adapter-branched (PG/MySQL/SQLite), safe to re-run.
- [ ] **ORG-UPGRADE-02**: Developer upgrading without the backfill flag sees existing users land in the "create or accept invite" state on next login — no 500s, no dead ends.
- [ ] **ORG-UPGRADE-03**: Repository ships a `test/upgrade_test.exs` fixture that boots a v1.0 install, runs the v1.1 upgrade, and asserts login still works in both the backfill-on and backfill-off paths (addresses pitfall X-4).

---

### Invitations (INV)

- [ ] **INV-01**: Organization owner or admin can invite a user by email, optionally specifying the role the invitee will receive.
- [ ] **INV-02**: System generates a single-use invite token via HMAC (reusing `Sigra.Token`); the token is stored hashed (SHA-256), never in plaintext.
- [ ] **INV-03**: System sends an `organization_invitation_email.ex` containing the accept URL, org name, inviter name, and expiry. HTML + text multipart with inline CSS (matches v1.0 email conventions).
- [ ] **INV-04**: Invitation expires after 7 days by default, configurable via NimbleOptions. Library raises a warning in dev if configured TTL exceeds 30 days (phishing window guidance).
- [ ] **INV-05**: Invitee with no account can accept the invite by signing up; the signup form pre-fills and locks the email field, and membership is created atomically with the confirmed user in an `Ecto.Multi` (addresses pitfall O-2).
- [ ] **INV-06**: Invitee with an existing account matching the invited email can accept the invite while signed in; system asserts `current_user.email == invitation.email` (case-insensitive via citext) and rejects with an explicit "this invitation is for [other-email]" mismatch page if they're signed in as a different user (addresses pitfall O-2 — Jetstream #907 / Keycloak CVE-2026-1529 class).
- [ ] **INV-07**: Accepting an invite marks it `accepted_at` and prevents reuse; a replay attempt returns a clear "already accepted" flash (addresses pitfall O-3).
- [ ] **INV-08**: Organization owner or admin can revoke a pending invite before acceptance; revoked invites show `revoked_at` and return "no longer valid" on accept attempts.
- [ ] **INV-09**: Developer can rate-limit invitation creation (default 20/day per user via Hammer) to prevent invite-as-spam abuse.
- [ ] **INV-10**: Invitation list shows pending invites with email, role, invited-by, expires-in, and a "revoke" button.

---

### Audit Integration (AUD)

- [ ] **AUD-01**: System adds `organization_id :binary_id` as a real indexed column on `audit_events` (not jsonb metadata) — nullable, so library-emitted events outside org context (logged-out password reset, failed login, etc.) land cleanly. **(Load-bearing for v1.2 per-org audit views.)**
- [ ] **AUD-02**: System adds `effective_user_id :binary_id` as a real column on `audit_events`, populated identically to `user_id` in v1.1 (addresses pitfall O-7). **(Load-bearing for v1.2 impersonation — v1.2 will make `user_id` = impersonator and `effective_user_id` = target.)**
- [ ] **AUD-03**: System exposes `Sigra.Audit.metadata_from_scope/2` as a single assembly point for audit metadata. Helper pulls `organization_id` from scope; reserves (with a documented comment block) the future `effective_user_id` population from `scope.impersonating_from` in v1.2.
- [ ] **AUD-04**: System extends `Sigra.Audit.Query` with an `:organization_id` filter backed by the real indexed column.
- [ ] **AUD-05**: System defines a `Sigra.Workers` behaviour for Oban workers requiring tenant context; workers accept `args["organization_id"]` and `args["actor_id"]`, reconstruct a minimal `%Scope{}` in `perform/1`, and emit audits through the same helper (addresses pitfall O-11).

---

### Passkeys — Foundation (PK)

- [ ] **PK-01**: Developer can add passkeys to a new Phoenix app via `mix sigra.install --passkeys` (default on). Adds `{:wax_, "~> 0.7"}` to mix.exs; host app's `assets/package.json` gets `@simplewebauthn/browser ^13.0.0`.
- [ ] **PK-02**: Developer can disable passkeys entirely via `mix sigra.install --no-passkeys`; no passkey templates, schemas, routes, or JS hooks are generated.
- [ ] **PK-03**: System generates a `UserPasskey` schema (`user_id`, `credential_id` unique + unencrypted + indexed, `public_key` encrypted via the existing Cloak vault, `sign_count`, `aaguid`, `nickname`, `device_hint`, `transports` array, `rp_id`, `last_used_at`, timestamps).
- [ ] **PK-04**: System stores `rp_id` on every `UserPasskey` row at registration time so later RP ID rotations can be detected and documented (addresses pitfall P-3).
- [ ] **PK-05**: System exposes `Sigra.Passkeys` context with `register/3`, `authenticate/3`, `list_for_user/1`, `rename/2`, `delete/2` functions; ceremony primitives in `Sigra.Passkeys.Registration` and `Sigra.Passkeys.Authentication` wrapping `wax_`.
- [x] **PK-06**: System exposes `Sigra.Plug.PasskeyChallenge` that stores the WebAuthn challenge in the signed+encrypted Plug session via `Sigra.Token.generate/4` with `max_age: 60`. Challenge is server-generated, server-stored, server-verified; never accepted from `clientDataJSON` (addresses pitfall P-1 — OneUptime GHSA-gjjc-pcwp-c74m).
- [ ] **PK-07**: System verifies the assertion response's returned `credential_id` matches a credential the requested user owns — rejects credential-confusion attacks (addresses pitfall P-6 — StrongKey CVE-2025-26788).
- [ ] **PK-08**: System enforces sign-count monotonicity on authentication; regressions default to **`:warn`** (log + audit-event `:passkey_sign_count_regression` + banner on user's passkey list). `:require_reauth` and `:revoke` modes available via NimbleOptions config (addresses pitfall P-4). **(Decision: `:warn` default — matches Apple iCloud / Google sync credentials.)**
- [x] **PK-09**: System loads `rp_id`, `rp_name`, `origin`, `attestation` (default `:none`), `user_verification` (default `:preferred`), and `timeout_ms` from **runtime** config; `NimbleOptions` validates at first-use with fast-fail.
- [x] **PK-10**: System applies per-user rate limiting on passkey ceremony initiation via Hammer (default 5/min) to prevent ceremony-flood DoS.

### Passkeys — User-Facing (PK-UX)

- [ ] **PK-UX-01**: User can enroll a passkey from account settings. Enrollment is gated by `Sigra.Plug.RequireSudo` — user must re-authenticate with password or TOTP before enrollment (addresses pitfall P-2 — stolen-session takeover).
- [ ] **PK-UX-02**: System emails the user on every passkey registration (reusing the v1.0 suspicious-login email shape); email shows device hint, IP, city, time.
- [ ] **PK-UX-03**: User can name (nickname) each enrolled passkey; nickname defaults to an AAGUID-derived friendly name ("iCloud Keychain", "Google Password Manager", "1Password", "Windows Hello") via a bundled AAGUID registry.
- [ ] **PK-UX-04**: User can rename or delete a passkey (delete is sudo-gated). System maintains a soft cap of 10 passkeys per user, configurable.
- [ ] **PK-UX-05**: User can log in via passkey as a second factor alongside TOTP on the MFA prompt (v1.1 default MFA mode for users with both). Backup codes remain available.
- [ ] **PK-UX-06**: User can opt into passkey-as-primary login via a config-gated flag (`:passkey_primary_enabled`, default false). When enabled at the app level, users can enroll a passkey during signup and log in with email + passkey without a password. **(Decision: opt-in config with mandatory fallback.)**
- [ ] **PK-UX-07**: Every passkey-as-primary user must have a confirmed email and magic-link recovery is always available (cannot be disabled). If passkey login fails, user can always recover via magic link (addresses pitfall P-5 — lost-device lockout).
- [ ] **PK-UX-08**: System ships Conditional UI / passkey autofill where the browser supports it. Login email field gets `autocomplete="username webauthn"` + `navigator.credentials.get({mediation: 'conditional'})`. Feature-detected — unsupported browsers degrade gracefully to explicit-click flow. **(Decision: ship in v1.1, progressive enhancement.)**
- [ ] **PK-UX-09**: System detects duplicate-device enrollment (credential_id collision for the same user) and returns "this passkey is already registered" rather than 500ing.
- [ ] **PK-UX-10**: Passkey enrollment and authentication LiveViews use Phoenix JS hooks (`PasskeyRegister`, `PasskeyAuthenticate`) wrapping `@simplewebauthn/browser` — no vanilla base64url plumbing.
- [ ] **PK-UX-11**: Passkey authentication completion POSTs to a plain controller (not a LiveView event) to rotate the Plug session, matching v1.0's "login is a plain controller" convention (D-29).
- [ ] **PK-UX-12**: Passkey JS hooks handle browser abort, timeout, user-cancel, and AbortController scenarios cleanly — LiveView returns to a recoverable state with a clear error message (addresses pitfall P-8).

---

### Generator Feature System (GEN)

- [ ] **GEN-01**: `mix sigra.install` uses a subdirectory-based feature manifest pattern where each feature (`core`, `organizations`, `passkeys`, future `admin`) lives under `priv/templates/sigra.install/{feature}/` and is represented by a module implementing a shared `Sigra.Install.Feature` behaviour (`enabled?/1`, `files/1`, `injections/1`). **(Load-bearing for v1.2 `--no-admin`.)**
- [ ] **GEN-02**: v1.0 flat templates move into `priv/templates/sigra.install/core/` in a mechanical, content-preserving refactor as the first phase-1 task.
- [ ] **GEN-03**: Generator supports combinatorial CI smoke testing: `mix sigra.install` with every combination of `--organizations`/`--no-organizations` and `--passkeys`/`--no-passkeys` produces a compiling Phoenix app (addresses pitfall X-1).
- [ ] **GEN-04**: Generator is idempotent on re-run; injections use marker comments and skip if already present.
- [ ] **GEN-05**: Generator prints a post-install summary showing generated / modified / skipped / manual-action files — developers see opt-outs were honored.
- [x] **GEN-06**: When `--passkeys` is enabled, generator detects the host app's `assets/js/app.js` injection target via a marker comment. If the marker is absent (custom esbuild/Vite/Webpack layout), generator writes the hook file, skips injection, and prints clear manual instructions with the exact import + registration lines to add. **(Decision: detect marker, never silently fail.)**
- [ ] **GEN-07**: Migrations ship with strictly-ordered timestamps to prevent cross-feature ordering hazards during install and upgrade (addresses pitfall X-2).

---

### Developer Experience (DX)

- [ ] **DX-01**: Testing helpers generated into `auth_fixtures.ex` and new `organization_fixtures.ex` / `passkey_fixtures.ex`: `create_organization/1`, `create_membership/3`, `log_in_user_with_org/3`, `register_passkey/2`, `authenticate_with_passkey/2`.
- [ ] **DX-02**: Library test helpers in `Sigra.Testing`: `assert_scope_has_org/2`, `assert_membership/3`, `assert_audit_logged_for_org/2`.
- [ ] **DX-03**: `getting-started.md` guide updated with an "Organizations & Passkeys" section covering the happy path from `mix phx.new` to a working multi-tenant app with passkey login in under 30 minutes.
- [ ] **DX-04**: New guide `guides/introduction/upgrading-to-v1.1.md` covering the v1.0 → v1.1 upgrade path with both backfill modes, breaking-change callouts (none expected), and the upgrade test invocation.
- [ ] **DX-05**: New guide `guides/how-to/multi-tenancy.md` explaining the logical MT model, the `for_org/2` discipline, and why Sigra rejects PG schema-per-tenant.
- [ ] **DX-06**: New guide `guides/how-to/passkeys.md` covering enrollment flow, passkey-as-primary config, RP ID / origin / rename playbook, and recovery fallback guidance.
- [ ] **DX-07**: CI smoke harness (existing from v1.0 phase 10.1.1) extends to cover org switcher + invitation accept + passkey registration + passkey authentication flows via Playwright.
- [ ] **DX-08**: `mix docs --warnings-as-errors` stays clean after v1.1 additions.
- [ ] **DX-09**: Optional Credo custom check for tenant-scope discipline: time-boxed 1-day spike in the first org phase. Ship the check if implementation stays under 300 lines; otherwise fall back to integration-test-only enforcement and document the decision in CONVENTIONS.md. **(Decision: time-box; ship if ≤300 lines.)**

---

## Future Requirements (deferred to v1.2 or later)

- Admin user-management UI (LiveView, mobile-first, light+dark mode)
- Admin impersonation with dual-actor audit trail
- Expanded audit views (per-user, per-org, global, security event feed, CSV export)
- Full usernameless resident-key-only passkey flow
- FIDO metadata service integration (device trust scoring)
- Cross-device passkey hand-off beyond OS/browser native support
- Admin revocation of passkeys
- Nested organizations / sub-orgs / workspaces
- Full RBAC / permission policies
- PG schema-per-tenant or DB-per-tenant modes (documented extension point only)
- Cross-org user merging / data transfer
- Org-level billing integration
- SCIM directory sync
- Organization-level branding / per-org theming

## Out of Scope (v1.1 explicit exclusions)

- **PG schema-per-tenant.** Logical MT only. Host apps needing physical isolation can layer their own adapter; Sigra documents the extension point but doesn't ship it.
- **Auto-created "personal team" on signup.** Deliberately rejected based on Jetstream #117/#188 feedback. New signups start with zero orgs and a clear path to create or accept an invite.
- **"Accept invitation as any logged-in user".** Email-bound HMAC + citext match assertion. Prevents SharePoint-class identity confusion.
- **Unbounded invite lifetime.** Default 7d, recommended ceiling 30d.
- **Passkey without recovery fallback.** Every passkey-as-primary user has mandatory magic-link recovery.
- **Attestation `:direct` default.** Breaks consumer flows. `:none` default per FIDO Alliance consumer UX guidelines.
- **`userVerification: required` default.** Use `:preferred` to avoid fingerprint-only lockouts on cheap authenticators.
- **Custom role models beyond owner/admin/member.** Host apps layer on top.
- **Full RBAC / permission policies.** Stays out of Sigra's scope per PROJECT.md Key Decisions.
- **Admin cross-org management UI.** v1.2.
- **Admin impersonation.** v1.2 (though v1.1 reserves the scope field + audit column so v1.2 is purely additive).

---

## Traceability

All 79 v1.1 requirements mapped to exactly one phase. Coverage: 79/79 (100%).

| REQ-ID | Phase |
|--------|-------|
| ORG-01 | 13 |
| ORG-02 | 18 |
| ORG-03 | 13 |
| ORG-04 | 13 |
| ORG-05 | 13 |
| ORG-06 | 13 |
| ORG-07 | 13 |
| ORG-08 | 13 |
| ORG-SCOPE-01 | 12 |
| ORG-SCOPE-02 | 12 |
| ORG-SCOPE-03 | 14 |
| ORG-SCOPE-04 | 14 |
| ORG-SCOPE-05 | 14 |
| ORG-SCOPE-06 | 14 |
| ORG-UX-01 | 16 |
| ORG-UX-02 | 16 |
| ORG-UX-03 | 16 |
| ORG-UX-04 | 16 |
| ORG-UX-05 | 16 |
| ORG-UX-06 | 16 |
| ORG-UX-07 | 16 |
| ORG-UX-08 | 16 |
| ORG-UX-09 | 16 |
| ORG-UPGRADE-01 | 18 |
| ORG-UPGRADE-02 | 18 |
| ORG-UPGRADE-03 | 18 |
| INV-01 | 17 |
| INV-02 | 17 |
| INV-03 | 17 |
| INV-04 | 17 |
| INV-05 | 17 |
| INV-06 | 17 |
| INV-07 | 17 |
| INV-08 | 17 |
| INV-09 | 17 |
| INV-10 | 17 |
| AUD-01 | 15 |
| AUD-02 | 15 |
| AUD-03 | 15 |
| AUD-04 | 15 |
| AUD-05 | 15 |
| PK-01 | 19 |
| PK-02 | 22 |
| PK-03 | 19 |
| PK-04 | 19 |
| PK-05 | 19 |
| PK-06 | 20 |
| PK-07 | 19 |
| PK-08 | 19 |
| PK-09 | 20 |
| PK-10 | 20 |
| PK-UX-01 | 21 |
| PK-UX-02 | 21 |
| PK-UX-03 | 21 |
| PK-UX-04 | 21 |
| PK-UX-05 | 21 |
| PK-UX-06 | 21 |
| PK-UX-07 | 21 |
| PK-UX-08 | 21 |
| PK-UX-09 | 21 |
| PK-UX-10 | 21 |
| PK-UX-11 | 21 |
| PK-UX-12 | 21 |
| GEN-01 | 11 |
| GEN-02 | 11 |
| GEN-03 | 18 |
| GEN-04 | 11 |
| GEN-05 | 11 |
| GEN-06 | 20 |
| GEN-07 | 11 |
| DX-01 | 23 |
| DX-02 | 23 |
| DX-03 | 23 |
| DX-04 | 23 |
| DX-05 | 23 |
| DX-06 | 23 |
| DX-07 | 23 |
| DX-08 | 23 |
| DX-09 | 23 |
