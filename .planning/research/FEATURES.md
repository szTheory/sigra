# Feature Research — Sigra v1.1 Foundations

**Domain:** Phoenix authentication library — logical multi-tenancy (Organizations) + Passkeys (WebAuthn)
**Researched:** 2026-04-11
**Confidence:** HIGH (primary sources from Clerk, Auth0, WorkOS, GitHub, Better Auth, Laravel Jetstream, FIDO Alliance, Google/Chrome, and web.dev)

**Scope note:** This file covers ONLY v1.1 Foundations — Organizations + Passkeys user-facing features. Admin UI, impersonation, and audit views are earmarked for v1.2 and are intentionally excluded here. v1.0 features (password, magic links, OAuth, TOTP, sessions, API keys, audit log) are treated as dependencies, not research subjects.

---

## Part A — Organizations / Multi-Tenancy

### A.1 Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `Organization` entity with name + unique slug | Every B2B SaaS user associates "workspace" with a named URL-safe identifier. Clerk, Auth0, WorkOS, Better Auth, Jetstream all expose this. | LOW | Already in v1.1 schema plan. `citext` slug unique index; validate slug format server-side. |
| `OrganizationMembership` many-to-many with role enum | Membership != ownership; a user can be in multiple orgs with different roles per org. This is the `member`/`admin`/`owner` triad that Clerk, Better Auth, and Jetstream all settled on. | LOW | v1.1 schema has this. Keep roles as a simple enum (`owner`, `admin`, `member`) in v1.1 — do NOT build RBAC/permissions here. Better Auth explicitly separates the member plugin from a permissions plugin. |
| Invite-by-email with signed token + expiry | The dominant pattern. Clerk, Auth0, Better Auth, Jetstream all send a tokenized link. | MEDIUM | v1.1 plan already uses `Sigra.Token` HMAC. Default expiry **7 days** — Better Auth default, SailPoint default, Atlassian Cloud default, Laravel Invite Only default. |
| Active organization concept in session/scope | Two-phase auth (identity -> tenant context) is industry-standard. WorkOS explicitly names this. | MEDIUM | v1.1 plan: `sessions.active_organization_id` + `%Scope{active_organization, membership}`. This matches Clerk's `setActive()` semantics. |
| Organization switcher UI (dropdown or modal) | Any user in 2+ orgs will immediately look for this. Clerk ships `<OrganizationSwitcher/>`; Better Auth UI ships the same; Jetstream has a team dropdown; Slack/Linear/Notion all ship it. | MEDIUM | v1.1 plan: `OrganizationSwitcherLive`. Pattern: show current org at top, list memberships, "Create new organization" at bottom. |
| Login flow handles 0/1/2+ org cases | Jetstream GitHub #188 is a canonical pain point — logging in with a user with no teams throws a 500. Must be handled gracefully. | MEDIUM | v1.1 plan already enumerates: 0 = no active org, 1 = auto-select, 2+ = resume last-active or show picker. Last-active matters because workspace context is per-project. |
| Invite acceptance works for new AND existing users | Split code paths for "accept as logged-in user" vs "sign up then accept" is where bugs live. Clerk, Auth0, Better Auth all unify on a single acceptance endpoint that branches on `user_exists`. | MEDIUM | v1.1 plan: `InvitationAcceptLive` handles both. Critical: the signed-up email MUST be locked to the invited email to prevent the SharePoint-class mismatch bug (see A.3). |
| Remove member + change role (owner/admin gated) | Table stakes in Clerk, Auth0, Jetstream, Better Auth. | LOW | v1.1 plan: `OrganizationMembersLive`. |
| "Last owner" guard — cannot remove or demote the sole owner | GitHub, Scaleway, Make, Bitwarden all enforce this. Removing the last owner bricks the org. | LOW | Implement as a DB-layer check in `Sigra.Organizations.Membership.remove/2` with a custom changeset error. |
| Invite expiry + resend + revoke | Clerk exposes `revoke()`, Better Auth exposes `cancelPendingInvitationsOnReInvite`, Auth0 exposes invitation revocation via Management API. | LOW | v1.1 plan: `revoked_at` column + `Sigra.Organizations.revoke_invitation/2`. |
| Per-org data scoping via plug | `Sigra.Plug.RequireMembership` is v1.1 plan. Matches Clerk's `auth().orgId` pattern and WorkOS's tenant-scoped request context. | LOW | Already scoped. |
| Audit log carries `organization_id` when scope has active org | Every auth library with both audit + orgs does this. Without it, v1.2 per-org audit view is impossible. | LOW | v1.1 plan: auto-attach via scope metadata into JSONB column. |

### A.2 Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| `--no-organizations` generator opt-out | Solo SaaS builders often don't need orgs. Jetstream's hard-wired "Personal Team" on every user is the most-complained-about aspect (Jetstream #117). Making orgs opt-out (default-on) fixes the Jetstream mistake. | LOW | v1.1 plan confirms this. The key design: orgs must be cleanly removable without leaving dead columns/schemas in the host app. |
| No "personal org" anti-pattern | Jetstream creates a "Sally's Team" on every signup. Complaints: clutters the system, confuses users, cannot be disabled cleanly, forces workarounds via community packages (`itbm/laravel-jetstream-disable-personal-team`). | LOW | Sigra should NOT auto-create a personal org. Registration may optionally prompt "create your first organization" but must not force it. |
| Invite token + query-param -> register-into-org flow | Unifies the happy path. Clerk does this; Auth0's "invitation flow" does this. User clicks email link, signs up, is immediately a member — zero friction. | MEDIUM | v1.1 plan already. Implementation note: the email field on the registration form must be pre-filled and disabled. |
| Resume last-active organization on login | A project-aware workspace memory. Users with 5+ orgs (common in agency work) hate being dumped back to a picker every login. Linear, Notion, Clerk all do this. | LOW | v1.1 plan: stored in sessions table. Falls back to first membership if last-active was deleted. |
| Email-locked invite acceptance (no "accept as different user" hijack) | SharePoint has a tenant-level setting to require this; mature products default to it. The alternative is a silent account-mismatch class of bug where users accept as their personal account and can't reach the workspace with their work email. | LOW | On accept: if logged in AND `current_user.email != invitation.email`, show a "sign out and use X" screen. Do NOT auto-accept. |
| Backfill migration for existing users | Running Sigra v1.0 -> v1.1 should be zero-downtime. A generated migration that creates one default org per existing user (skippable via flag) is a DX differentiator. | MEDIUM | v1.1 plan already. |
| Organization-level `settings` JSONB | Future-proof for per-org branding (v1.2), per-org auth policies (v2), per-org feature flags. WorkOS's explicit "organizations are the root for configuration" guidance. | LOW | Single JSONB column in v1.1 is cheap insurance. |
| Testing helpers (`create_organization/1`, `add_membership/3`, `log_in_user_with_org/3`) | Phoenix test ergonomics. Every v1.0 feature shipped with test helpers; orgs should too. | LOW | v1.1 plan already. |
| HMAC-protected invite tokens (not PKs, not UUIDs) | Sigra's v1.0 pattern. Reusing `Sigra.Token` gives single-use, HMAC-signed, server-hashed tokens — matches Sigra's security posture. Better than many competitors who store raw tokens. | LOW | v1.1 plan uses `Sigra.Token`. |

### A.3 Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Auto-created personal/default team on signup | Jetstream's default. Looks friendly. | Creates orphaned/junk orgs, confuses users ("what is 'Sally's Team'?"), cannot be removed cleanly, forces users to write workarounds (Jetstream #117, GH community packages). "Many unneeded teams being created" per Nick Pratley blog. | Optional "create organization" step in registration. Let users decide. |
| Organization-per-PostgreSQL-schema | "Maximum isolation." | Operational nightmare — migrations fan out, backups bloat, connection pools explode, analytics impossible. WorkOS explicitly says "start with shared-runtime multi-tenancy." | Single DB, logical `organization_id` scoping with explicit plug/query helpers. v1.1 plan is correct. |
| Full RBAC/permissions engine in v1.1 | "Roles aren't enough." | Scope creep. Rolls permissions, policies, resources, and inheritance into the auth lib. Better Auth explicitly separates permissions into a different plugin. Rodauth doesn't ship it at all. | Simple `owner/admin/member` enum in v1.1. Leave RBAC for v2+ (already out of scope per PROJECT.md). |
| "Accept invitation as any logged-in user" | Convenient. | Creates an identity-confusion class of bug (SharePoint docs warn about this; Microsoft Q&A has dozens of cases). User's work email invited, user accepts with personal account, org now has wrong user and the actual target can never join. | Email-locked acceptance. If logged-in user's email doesn't match, force sign-out-and-sign-in-as-X. |
| Unbounded invite lifetime | "Less friction." | Invites become a permanent backdoor. Azure B2B's 90-day SharePoint default is widely criticized. Atlassian users ask for configurable expiry (CLOUD-7198) precisely because the default is too long. | 7-day default (Better Auth, SailPoint, Atlassian, Laravel Invite Only consensus). Configurable via NimbleOptions. |
| Forcing invite-only (no self-signup into an org) | Enterprise-ish. | Blocks the dominant solo SaaS path. | Self-signup AND invite both supported. `--no-organizations` for host apps that don't want orgs at all. |
| Multi-org user models that share tables ambiguously | "Cleaner schema." | Rodauth's multi-account docs show this is a genuine pain — developers have to choose between a shared table with a type column or fully separate tables, and either choice has gotchas. | Keep it simple: one `users` table, one `organizations` table, one `organization_memberships` join. No ambiguity. |
| Admin UI for org management (in v1.1) | "Users need to admin orgs from day one." | v1.2 territory. Adding admin UI in v1.1 doubles the scope and breaks the milestone contract. | Ship `OrganizationMembersLive`/`SettingsLive` LiveViews for the OWNER of the org (not global admin). Admin UI for cross-org management ships in v1.2. |

---

## Part B — Passkeys (WebAuthn)

### B.1 Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Enrollment from settings page | Every passkey-capable auth product ships this. GitHub, Clerk, Auth0, Better Auth, 1Password, Dashlane. | MEDIUM | v1.1 plan: `PasskeyEnrollmentLive` + JS hook for `navigator.credentials.create`. |
| Authentication from login page | Obvious. | MEDIUM | v1.1 plan: `PasskeyAuthenticationLive` + JS hook for `navigator.credentials.get`. |
| List of enrolled passkeys with device names | GitHub lists "Safari on macOS"; Clerk lists authenticator name; Apple/Google show AAGUID-derived names. Without this, users cannot distinguish "which passkey is this?". | MEDIUM | v1.1 plan: `MfaSettingsLive` lists passkeys alongside TOTP. |
| Rename passkey | Users need to distinguish "laptop" from "yubikey" from "phone." FIDO/SnapAuth/web.dev all call this out as mandatory. | LOW | `nickname` column on `user_passkeys` schema (v1.1 plan has it). |
| Delete passkey | Users lose devices. 1Password, GitHub, Clerk all ship this. Sudo-gated. | LOW | v1.1 plan: via `MfaSettingsLive`. Reuse v1.0 sudo re-auth plug. |
| Sign count tracking | WebAuthn spec mandates for clone detection on non-synced credentials. `wax_` handles this if you store it. | LOW | v1.1 plan: `sign_count` column. |
| Encrypted public key storage | Public keys are public but AAGUID + sign_count + credential_id metadata together can be a privacy signal. Sigra's v1.0 `cloak_ecto` vault covers OAuth tokens; reusing it for passkeys is consistent. | LOW | v1.1 plan: encrypt `public_key` via `cloak_ecto`. |
| Runtime RP ID / origin configuration | Required for multi-env (dev/staging/prod) deploys. Clerk's most-cited gotcha is dev/staging/prod passkey non-portability — not a bug, but must be clearly documented. | LOW | v1.1 plan: runtime config, not compile-time. |
| Passkey-as-second-factor mode | The most common integration path. GitHub treats passkeys as either primary OR second factor depending on account config. Compatible with TOTP. | MEDIUM | v1.1 plan: MFA prompt shows TOTP + passkey + backup codes. |
| Challenge storage with short TTL | Prevents replay. `Sigra.Plug.PasskeyChallenge` in v1.1 plan. TTL <= 5 minutes is FIDO recommendation. | LOW | In-memory ETS or short-lived DB rows. |
| Transports + AAGUID stored | AAGUID lets you display "1Password", "Google Password Manager", "Windows Hello" in the device list. Community-maintained AAGUID registry at `passkeydeveloper/passkey-authenticator-aaguids`. | LOW | v1.1 plan: columns exist. Ship a static mapping of common AAGUIDs with a fallback to "Unknown authenticator". |

### B.2 Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Conditional UI / autofill passkey login | THE biggest passkey UX improvement per web.dev and Chrome team. User sees passkey in browser autofill dropdown alongside saved passwords — no separate "Sign in with passkey" button needed. Zero disruption to existing login form. | MEDIUM | Needs `autocomplete="username webauthn"` attribute + `mediation: 'conditional'` in JS. Feature-detect with `PublicKeyCredential.isConditionalMediationAvailable()`. This is MEDIUM not HIGH effort once the ceremony is wired. |
| Passkey-as-primary mode (passwordless login) | Clerk, Auth0, and GitHub all support primary passkey. Industry direction per Bitwarden/Keeper/1Password analyses: "Use passkeys for primary logins where possible." | MEDIUM | v1.1 plan: opt-in mode. Email + passkey (no password). |
| Friendly AAGUID-derived device names | GitHub shows "Safari on macOS"; web.dev and SnapAuth both call out the AAGUID registry. Users hate generic "Security Key 1", "Security Key 2" (Hanko #1027). | LOW | Bundle AAGUID name mapping. Allow user rename. Default = AAGUID name; fallback = UA string; last resort = "Passkey". |
| Duplicate-device detection on enrollment | GitHub detects when the same browser/OS combo already has a passkey and prevents overwrite. Prevents users accidentally ending up with a single passkey twice. | LOW | Check credential_id uniqueness (already a DB constraint) — also surface a friendly "you already have a passkey on this device" message when AAGUID + user agent match. |
| Clear "which device is this?" UI at enrollment | Top passkey UX pain point per Germain UX, Ideem, and MDPI literature review. Users get confused: "is this creating a passkey for my laptop or my phone?" | LOW | Enrollment flow: capture a nickname UP FRONT in a text input, default to a smart guess (AAGUID + browser), commit AFTER the WebAuthn ceremony succeeds. |
| Recovery fallback explicit at enrollment time | FIDO Alliance guidance: "establish clear recovery options during account creation." Ideem lists recovery as a top mistake. Sigra already has backup codes and magic links — enrollment should remind the user these exist. | LOW | Inline copy: "If you lose this device, you can still sign in with [password/magic link/backup codes]." Zero code if all fallbacks already exist (they do, from v1.0). |
| Sync-credential transparency | Synced passkeys (Apple/Google/1Password) are a "single factor" even though they feel like multi-device. Clerk docs explicitly note this. Being upfront about which passkeys are synced (if the browser tells us) is a trust win. | MEDIUM | `transports` field includes `hybrid` for cross-device; the `backupEligible` + `backupState` flags from the attestation object indicate syncability. Display as a small badge "Synced to your iCloud/Google/Windows account". |
| Unified MFA settings page (TOTP + passkeys + backup codes) | v1.0 already has TOTP + backup codes. v1.1 plan: `MfaSettingsLive` lists all three. This is the Clerk pattern — one "Multi-factor" settings page, not separate pages per factor type. | LOW | v1.1 plan already. |
| Testing helpers (`register_passkey/2`, `authenticate_with_passkey/2`) | Phoenix testing ergonomics. No Elixir auth lib ships these yet (wax_ is a primitive); Sigra can be first. | MEDIUM | Mock the navigator ceremony by directly calling `wax_` verification with a fixture. |

### B.3 Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| No password fallback at all | "Full passwordless." | The #1 cited passkey failure mode. Dark Reading, Ideem, Germain UX, MDPI review all say recovery is the weakest link. If the passkey sync fabric loses credentials, users are bricked. NIST 2026 guidance via Yubico emphasizes recovery. | Passkey as primary OR second factor, but ALWAYS keep at least one recovery path (password OR magic link OR backup codes). v1.0 already provides these. |
| Attestation `direct` by default | "More secure." | Breaks consumer flows — most consumer authenticators don't provide direct attestation, and users get a scary browser prompt. FIDO Alliance UX guidelines recommend `none` for consumer apps. | Default `attestation: none`. Allow `direct` as opt-in config for enterprise use. v1.1 plan confirms `:none` default. |
| Requiring user verification for every passkey | "Biometric every time." | Some passkey providers don't support UV reliably; causes enrollment failures. | Set `userVerification: 'preferred'` (not `'required'`) unless the host app opts in. |
| "Only one passkey per user" | Prevents key sprawl. | Users need backup passkeys (laptop + phone + hardware key). Clerk allows 10. GitHub allows many. Blocking multi-passkey enrollment is a footgun. | Allow N passkeys per user. Soft cap around 10 (Clerk's limit) to keep list UI sane. |
| Cross-domain / subdomain passkey portability | "Sign in once, use everywhere." | WebAuthn spec forbids this at the protocol level. Clerk's #1 passkey gotcha is satellite domains. Attempting to work around it is a dead end. | Document RP ID carefully. Recommend single primary domain. Let developers configure RP ID explicitly. |
| Implementing raw WebAuthn ceremony ourselves | "Minimal deps." | WebAuthn attestation formats are wildly complex. `wax_` is the only battle-tested Elixir implementation (passes all 170 FIDO test suite tests). Rolling our own is a 6-month security hazard. | Use `wax_ ~> 0.7`. Already in v1.1 plan. |
| Mandatory usernameless login | "Coolest flow." | Requires discoverable credentials, which not all authenticators support reliably. Breaks users on older OS/browser combos. | Support usernameless via Conditional UI as a differentiator, but keep email-first as the default flow. |
| Passkey as the ONLY MFA option | "Simplest settings page." | Locks users with older password managers out of MFA. | Offer TOTP + passkeys + backup codes side-by-side. v1.1 plan confirms this. |
| Silent passkey auto-enrollment | "Nudge users to adopt." | Creates passkeys users don't know about; later can't remember which device they're on. Microsoft's Entra ID 2026 passkey registration campaigns are opt-in, not silent. | Explicit enrollment button. Optional post-login prompt ("You don't have a passkey yet — set one up?") as a v1.2 concern. |

---

## Feature Dependencies

```
Organizations
  |- requires --> v1.0 Sessions (adds active_organization_id column)
  |- requires --> v1.0 Scope struct (extends with :active_organization, :membership)
  |- requires --> v1.0 Sigra.Token (HMAC-protected invite tokens)
  |- requires --> v1.0 Swoosh mailer (invitation email template)
  |- requires --> v1.0 Audit log (organization_id auto-attached)
  \- enables ---> v1.2 per-org admin UI, per-org impersonation, per-org audit views

Organization Switcher
  \- requires --> Organization Membership, Scope extension, Sessions column

Invite Acceptance
  |- requires --> Sigra.Token HMAC
  |- requires --> Email-locked registration (changeset update in v1.1)
  \- requires --> v1.0 Registration + Login flows

Passkeys
  |- requires --> v1.0 MFA settings page (PasskeyEnrollmentLive extends MfaSettingsLive)
  |- requires --> v1.0 Sudo re-auth plug (gate delete/rename)
  |- requires --> v1.0 cloak_ecto vault (encrypt public_key field)
  |- requires --> wax_ ~> 0.7 (NEW dep in v1.1)
  \- enables ---> v1.2 passkey-only policy enforcement

Passkey Conditional UI
  \- requires --> Passkey Authentication ceremony + feature-detected JS hook

Passkey-as-Primary Mode
  |- requires --> Passkey Authentication ceremony
  \- requires --> Fallback path (password OR magic link OR backup codes — all v1.0)

Organizations <--unrelated--> Passkeys
  (the two features are independent; either can ship first)
```

### Dependency Notes

- **Organizations requires v1.0 Scope:** The `%Scope{}` struct must be extended with `:active_organization` and `:membership` in the same phase that introduces Organizations. Downstream plugs (`RequireMembership`) and audit metadata depend on scope-as-source-of-truth.
- **Invite flow requires email-locked registration:** The registration changeset must accept an "invitation email" parameter and lock the `email` field when present. This is a small but load-bearing change to v1.0 registration.
- **Passkeys are independent of Organizations:** The two features share only infrastructure (cloak vault, sudo plug, MFA settings page). They can be implemented in either order. Consider Organizations first if it is load-bearing for v1.2 conditional-template patterns (per PROJECT.md).
- **v1.0 backup codes are passkey recovery:** Sigra already has backup codes from v1.0. Passkey enrollment should surface these as the recovery path — zero new code needed, just inline copy.
- **v1.0 Audit log is the scaffold for v1.2 per-org views:** The `organization_id` field MUST land in audit metadata in v1.1 even though the admin UI that reads it ships in v1.2. Retrofitting audit metadata post-hoc is expensive.

---

## MVP Definition — v1.1 Scope

### Launch With (v1.1)

**Organizations (default-on, `--no-organizations` opt-out):**
- [ ] `Organization`, `OrganizationMembership`, `OrganizationInvitation` schemas
- [ ] `Sigra.Organizations` context (CRUD + invite lifecycle)
- [ ] `Sigra.Plug.RequireMembership`
- [ ] Scope extension + sessions column
- [ ] Owner/admin/member enum (NO RBAC engine)
- [ ] Invite-by-email with HMAC token, 7-day default expiry, revoke + resend
- [ ] Email-locked invite acceptance (new + existing user paths, locked email)
- [ ] `OrganizationSwitcherLive`, `OrganizationSettingsLive`, `OrganizationMembersLive`, `InvitationAcceptLive`
- [ ] Login handles 0/1/2+ org cases gracefully (last-active resume)
- [ ] NO auto-created personal org on signup
- [ ] Last-owner guard (cannot remove/demote sole owner)
- [ ] Audit log auto-attaches `organization_id`
- [ ] Testing helpers

**Passkeys (default-on, `--no-passkeys` opt-out):**
- [ ] `UserPasskey` schema with cloak-encrypted public key
- [ ] `Sigra.Passkeys` / `Registration` / `Authentication` contexts
- [ ] `Sigra.Plug.PasskeyChallenge` (short TTL)
- [ ] Passkey-as-2FA mode (integrated into MfaSettingsLive)
- [ ] Passkey-as-primary mode (opt-in, email-first)
- [ ] `PasskeyEnrollmentLive`, `PasskeyAuthenticationLive`
- [ ] AAGUID -> friendly name mapping (bundled)
- [ ] Device nickname (rename supported)
- [ ] Multiple passkeys per user (soft cap 10)
- [ ] Runtime RP ID / origin config
- [ ] Attestation `:none` default
- [ ] User verification `preferred` default
- [ ] Duplicate-device detection on enrollment
- [ ] Conditional UI / autofill login (feature-detected)
- [ ] Testing helpers

### Deferred to v1.2 "Admin Dashboard"

- [ ] Cross-org admin UI for user management (v1.2 scope)
- [ ] Admin impersonation (v1.2 scope)
- [ ] Per-org / global / security-event audit views + CSV export (v1.2 scope)
- [ ] Per-org branding (logo, colors) — schema-ready via JSONB settings but UI ships in v1.2
- [ ] Post-login "you don't have a passkey yet" nudge (v1.2 UX polish)

### Future Consideration (v2+)

- [ ] RBAC / permissions / policies engine (separate concern per PROJECT.md)
- [ ] SAML / OAuth IdP for orgs (enterprise B2B)
- [ ] SCIM directory sync
- [ ] Multi-tenant custom domains / per-org DNS
- [ ] Teams-within-orgs (Better Auth's teams-as-sub-unit pattern)
- [ ] Org-level SSO enforcement

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Organizations schemas + context | HIGH | MEDIUM | P1 |
| RequireMembership plug + Scope extension | HIGH | LOW | P1 |
| Invite flow (HMAC token, 7d expiry) | HIGH | MEDIUM | P1 |
| Email-locked invite acceptance | HIGH | LOW | P1 |
| Login 0/1/2+ org handling + last-active resume | HIGH | LOW | P1 |
| OrganizationSwitcherLive | HIGH | MEDIUM | P1 |
| OrganizationMembersLive + role change + remove | HIGH | MEDIUM | P1 |
| OrganizationSettingsLive | MEDIUM | LOW | P1 |
| Last-owner guard | HIGH | LOW | P1 |
| Audit log org_id integration | HIGH | LOW | P1 |
| `--no-organizations` conditional generator | HIGH | MEDIUM | P1 (load-bearing for v1.2 `--no-admin`) |
| Backfill migration for existing users | MEDIUM | MEDIUM | P1 |
| Passkey schemas + context + ceremonies | HIGH | HIGH | P1 |
| Passkey-as-2FA mode | HIGH | MEDIUM | P1 |
| Passkey enrollment + authentication LiveViews | HIGH | HIGH | P1 |
| AAGUID -> friendly name mapping | MEDIUM | LOW | P1 |
| Device nickname + rename + delete | HIGH | LOW | P1 |
| `--no-passkeys` opt-out | MEDIUM | LOW | P1 |
| Passkey-as-primary mode (opt-in) | MEDIUM | MEDIUM | P1 |
| Conditional UI / autofill | HIGH | MEDIUM | P1 (huge UX win, modest cost) |
| Duplicate-device detection on enrollment | MEDIUM | LOW | P2 |
| Sync-credential transparency badge | MEDIUM | MEDIUM | P2 |
| Testing helpers (orgs + passkeys) | HIGH | MEDIUM | P1 (required by Sigra v1.0 test conventions) |

---

## Competitor Feature Analysis

### Organizations

| Feature | Clerk | Auth0 Orgs | WorkOS | Better Auth | Jetstream | **Sigra v1.1** |
|---------|-------|-----------|--------|-------------|-----------|----------------|
| Org entity + slug | yes | yes | yes | yes | yes (team) | yes |
| Membership with roles | yes (owner/admin/member) | yes | yes | yes | yes | yes (owner/admin/member enum) |
| Invite-by-email + token | yes | yes | yes | yes (`createInvitation`) | yes | yes (HMAC via `Sigra.Token`) |
| Invite expiry default | Configurable | Configurable | Configurable | 7d | Configurable | **7d (NimbleOptions)** |
| Revoke invitation | yes | yes | yes | yes | yes | yes |
| Active org in session | yes (`setActive`) | yes (token claim) | yes (org context) | yes | yes (current_team_id) | yes (scope + sessions column) |
| Org switcher component | yes (`<OrganizationSwitcher/>`) | — | — | yes (Better Auth UI) | yes | yes (`OrganizationSwitcherLive`) |
| Auto "personal" org | — | — | — | — | yes (complained about) | no (deliberate) |
| Can disable orgs entirely | yes (skip plugin) | yes (skip feature) | yes | yes (skip plugin) | partial (community packages only) | yes (`--no-organizations`) |
| Per-org branding | yes (paid) | yes | yes | — | — | JSONB settings (v1.2 UI) |
| Last-owner guard | yes | yes | yes | yes | yes | yes |
| Email-locked invite accept | Configurable | yes | yes | yes | yes | yes (default-on) |
| RBAC engine bundled | yes | yes | yes | Separate plugin | basic | no (deliberate, v2+) |

### Passkeys

| Feature | GitHub | Clerk | Auth0 | Better Auth | 1Password mgmt | **Sigra v1.1** |
|---------|--------|-------|-------|-------------|----------------|----------------|
| Passkey-as-primary | yes | yes | yes | yes | — (client) | yes (opt-in) |
| Passkey-as-2FA | yes | partial (not yet per docs) | yes | yes | — | yes (default) |
| Multiple passkeys per user | yes (many) | yes (10 max) | yes | yes | N/A | yes (soft cap 10) |
| Device nickname + rename | yes (auto name) | yes | yes | yes | yes | yes |
| AAGUID friendly names | yes | yes | yes | partial | yes | yes (bundled mapping) |
| Duplicate device detection | yes | — | — | — | N/A | yes (differentiator) |
| Conditional UI / autofill | yes | yes | yes | yes | N/A | yes |
| Attestation default | `none` | `none` | `none` | `none` | N/A | `:none` |
| Recovery path | 2FA recovery codes + password | Password + email | Password + email | Password + magic | N/A | Password + magic link + backup codes |
| Testing helpers | N/A (product) | Internal | Internal | limited | N/A | yes (Sigra differentiator) |

---

## Sources

### Organizations

**Clerk:**
- [Clerk Organizations overview](https://clerk.com/docs/guides/organizations/overview) — HIGH
- [Clerk custom flow for switching Organizations](https://clerk.com/docs/guides/development/custom-flows/organizations/organization-switcher) — HIGH
- [Clerk custom flow for managing invitations](https://clerk.com/docs/guides/development/custom-flows/organizations/manage-organization-invitations) — HIGH
- [Clerk send and manage invitations](https://clerk.com/docs/guides/organizations/add-members/invitations) — HIGH
- [Clerk accept invitation links](https://clerk.com/docs/guides/development/custom-flows/organizations/accept-organization-invitations) — HIGH
- [Clerk manage roles](https://clerk.com/docs/guides/development/custom-flows/organizations/manage-roles) — HIGH
- [Clerk Next.js OrganizationSwitcher component](https://clerk.com/docs/nextjs/reference/components/organization/organization-switcher) — HIGH

**Auth0:**
- [Auth0 Branding (B2B)](https://auth0.com/docs/get-started/architecture-scenarios/business-to-business/branding) — HIGH
- [Auth0 invite workflow lab](https://developer.auth0.com/resources/labs/saas/invite-workflow-using-the-auth0-organizations-invitation-feature) — HIGH
- [Auth0 Management API v2 — post-invitations](https://auth0.com/docs/api/management/v2/organizations/post-invitations) — HIGH
- [Auth0 expiration of invitation — community](https://community.auth0.com/t/how-to-set-the-expiration-of-an-organization-member-invitation/157744) — MEDIUM
- [Auth0 failed invite accept invalidates invitation](https://community.auth0.com/t/errorcase-failed-invite-accept-invalidates-the-invitation-and-doesnt-allow-users-for-a-retry/80350) — MEDIUM (pain point)
- [Auth0 introducing Organizations blog](https://auth0.com/blog/introducing-auth0-organizations/) — HIGH
- [Auth0 B2B SaaS identity challenges](https://auth0.com/blog/b2b-saas-identity-challenges-the-foundations/) — HIGH

**WorkOS:**
- [Developer's guide to SaaS multi-tenant architecture](https://workos.com/blog/developers-guide-saas-multi-tenant-architecture) — HIGH
- [Model your B2B SaaS with organizations](https://workos.com/blog/model-your-b2b-saas-with-organizations) — HIGH
- [WorkOS AuthKit — modeling your app](https://workos.com/docs/authkit/modeling-your-app) — HIGH
- [What is multitenant authentication?](https://workos.com/blog/what-is-multitenant-authentication) — HIGH

**Better Auth:**
- [Better Auth Organization plugin docs](https://better-auth.com/docs/plugins/organization) — HIGH
- [Better Auth organization plugin source](https://github.com/better-auth/better-auth/blob/main/docs/content/docs/plugins/organization.mdx) — HIGH
- [Better Auth members, roles, invitations](https://deepwiki.com/better-auth/better-auth/5.2-organization-plugin) — HIGH
- [Better Auth Issue #496 — Teams for Organizations](https://github.com/better-auth/better-auth/issues/496) — HIGH (design rationale)
- [Better Auth Issue #3672 — invite without email](https://github.com/better-auth/better-auth/issues/3672) — HIGH (pain point)
- [Better Auth UI Organizations](https://better-auth-ui.com/advanced/organizations) — HIGH
- [Better Auth UI OrganizationSwitcher](https://better-auth-ui.com/components/organization-switcher) — HIGH

**Laravel Jetstream:**
- [Jetstream Teams docs](https://jetstream.laravel.com/features/teams.html) — HIGH
- [Jetstream Issue #117 — option to disable personal teams](https://github.com/laravel/jetstream/issues/117) — HIGH (top complaint)
- [Jetstream Issue #188 — error when user has no teams](https://github.com/laravel/jetstream/issues/188) — HIGH (pain point)
- [Jetstream Issue #382 — Teams not respecting route key](https://github.com/laravel/jetstream/issues/382) — HIGH (pain point)
- [Jetstream Issue #649 — TeamMemberManager not using custom invitation model](https://github.com/laravel/jetstream/issues/649) — HIGH (pain point)
- [Jetstream Discussion — Team model relationships](https://github.com/laravel/framework/discussions/51679) — HIGH (architectural pain point)
- [Jetstream change Team model directory discussion](https://github.com/laravel/framework/discussions/35756) — MEDIUM
- [Nick Pratley — Disabling Personal Teams blog](https://medium.com/devlan-io/disabling-personal-teams-in-laravel-8-and-jetstream-1fd083593e08) — MEDIUM (pain point narrative)
- [`itbm/laravel-jetstream-disable-personal-team` package](https://github.com/itbm/laravel-jetstream-disable-personal-team) — HIGH (evidence of widespread workaround need)
- [Freek Van der Herten — Jetstream vs Spark customization](https://freek.dev/1912-how-to-customize-jetstream-and-laravel-spark) — MEDIUM

**Rodauth / Ruby:**
- [Rodauth GitHub](https://github.com/jeremyevans/rodauth) — HIGH
- [Rodauth docs](https://rodauth.jeremyevans.net/documentation.html) — HIGH
- [rodauth-rails Account Types wiki](https://github.com/janko/rodauth-rails/wiki/Account-Types) — HIGH

**Supabase / Postgres multi-tenancy:**
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) — HIGH
- [Makerkit — Supabase RLS best practices](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices) — MEDIUM

**Invite mismatch / security:**
- [SharePoint invitation account mismatch](https://learn.microsoft.com/en-us/answers/questions/5195956/why-am-i-unable-to-accept-an-invitation-to-sharepo) — HIGH (pain point)
- [B2B collaboration invitation redemption](https://docs.azure.cn/en-us/entra/external-id/redemption-experience) — HIGH
- [SharePoint external user invitation errors archive](https://learn.microsoft.com/en-us/archive/blogs/sposupport/external-users-trying-to-accept-the-invitation-get-an-error-message-that-didnt-work) — MEDIUM

**Invite expiry default (7d pattern):**
- [SailPoint — inviting users (7d default)](https://documentation.sailpoint.com/saas/help/common/users/inviting_users.html) — HIGH
- [Atlassian CLOUD-7198 — configurable invite expiry](https://jira.atlassian.com/browse/CLOUD-7198) — HIGH
- [Laravel Invite Only package (7d default)](https://laravel-news.com/laravel-invite) — MEDIUM
- [Auth0 — User Onboarding Strategies in B2B SaaS](https://auth0.com/blog/user-onboarding-strategies-b2b-saas/) — HIGH

**Last-owner guard:**
- [GitHub — Transferring organization ownership](https://docs.github.com/en/organizations/managing-organization-settings/transferring-organization-ownership) — HIGH
- [Bitwarden — managing access when owner leaves](https://bitwarden.com/help/managing-access-when-the-organization-owner-leaves/) — HIGH

### Passkeys / WebAuthn

**GitHub passkey UX (industry reference):**
- [GitHub — Managing your passkeys](https://docs.github.com/en/authentication/authenticating-with-a-passkey/managing-your-passkeys) — HIGH
- [GitHub — Signing in with a passkey](https://docs.github.com/en/authentication/authenticating-with-a-passkey/signing-in-with-a-passkey) — HIGH
- [GitHub — About passkeys](https://docs.github.com/en/authentication/authenticating-with-a-passkey/about-passkeys) — HIGH
- [Corbado — GitHub passkey best practices analysis](https://www.corbado.com/blog/github-passkeys-best-practices-analysis) — HIGH
- [GitHub community passkey feedback discussion #54450](https://github.com/orgs/community/discussions/54450) — HIGH (real user pain points)
- [GitHub community passkey discussion #67791](https://github.com/orgs/community/discussions/67791) — HIGH

**Clerk passkeys:**
- [Clerk sign-up/sign-in options (passkey docs)](https://clerk.com/docs/guides/configure/auth-strategies/sign-up-sign-in-options) — HIGH
- [Clerk custom passkey flow](https://clerk.com/docs/guides/development/custom-flows/authentication/passkeys) — HIGH
- [Clerk — how do I implement passkeys in Next.js](https://clerk.com/blog/how-do-i-implement-passkeys-in-nextjs) — HIGH
- [Clerk passkeys beta changelog](https://clerk.com/changelog/2024-04-22) — HIGH (10-passkey cap, subdomain portability, limitations)

**AAGUID / device naming:**
- [passkeydeveloper/passkey-authenticator-aaguids repo](https://github.com/passkeydeveloper/passkey-authenticator-aaguids) — HIGH (bundled mapping source)
- [web.dev — Determine the passkey provider with AAGUID](https://web.dev/articles/webauthn-aaguid) — HIGH
- [Corbado — What is the AAGUID in WebAuthn](https://www.corbado.com/glossary/aaguid) — MEDIUM
- [Hanko Issue #1027 — Improve passkey naming](https://github.com/teamhanko/hanko/issues/1027) — HIGH (pain point)

**Conditional UI / autofill:**
- [web.dev — Sign in with passkey through form autofill](https://web.dev/articles/passkey-form-autofill) — HIGH
- [Chrome — WebAuthn conditional UI](https://developer.chrome.com/docs/identity/webauthn-conditional-ui) — HIGH
- [Corbado — WebAuthn Conditional UI technical explanation](https://www.corbado.com/blog/webauthn-conditional-ui-passkeys-autofill) — HIGH
- [Yubico — Simple autofill flow](https://developers.yubico.com/WebAuthn/Concepts/Passkey_Autofill/Implementation_Guidance/Simple_Autofill_Flow.html) — HIGH

**Passkey enrollment UX pain points:**
- [Germain UX — Passkey authentication UX patterns](https://germainux.com/2025/10/28/passkey-authentication-ux-the-patterns-that-make-phishing-resistant-sign-ins-stick-in-2025/) — MEDIUM
- [Ideem — When passkeys fail the user](https://www.useideem.com/post/when-passkeys-fail-the-user-common-ux-mistakes-and-how-to-avoid-them) — MEDIUM
- [MDPI — Challenges and potential improvements for passkey adoption (literature review)](https://www.mdpi.com/2076-3417/15/8/4414) — HIGH (academic)
- [Corbado — Why passkey implementations fail](https://www.corbado.com/blog/why-passkey-implementations-fail) — HIGH
- [Dark Reading — Ongoing passkey usability challenges](https://www.darkreading.com/identity-access-management-security/passkey-usability-challenges-require-problem-solving) — MEDIUM

**Passkey recovery / fallback:**
- [Authsignal — Passkey recovery & fallback](https://www.authsignal.com/blog/articles/passkey-recovery-fallback) — HIGH
- [Authsignal — What happens when passkey device is lost](https://www.authsignal.com/blog/articles/what-happens-when-your-passkey-device-is-lost-understanding-recovery-and-device-sync) — HIGH
- [Corbado — Passkey fallback recovery identifier-first](https://www.corbado.com/blog/passkey-fallback-recovery) — HIGH
- [Yubico — NIST guidance on passkeys](https://www.yubico.com/blog/new-nist-guidance-on-passkeys-key-takeaways-for-enterprises/) — HIGH

**FIDO Alliance / spec / standards:**
- [FIDO Alliance UX Guidelines for Passkey Creation and Sign-ins (PDF)](https://fidoalliance.org/wp-content/uploads/2023/05/FIDO-Alliance-UX-Guidelines-for-Passkey-Creation-and-Sign-ins.pdf) — HIGH (canonical)
- [FIDO Passkeys overview](https://fidoalliance.org/passkeys/) — HIGH
- [Passkey Central Design Guidelines](https://www.passkeycentral.org/design-guidelines/) — HIGH
- [Google — Passkeys user journeys](https://developers.google.com/identity/passkeys/ux/user-journeys) — HIGH
- [SnapAuth — Passkey best practices](https://www.snapauth.app/passkeys-best-practices) — MEDIUM
- [SimpleWebAuthn — Passkeys advanced](https://simplewebauthn.dev/docs/advanced/passkeys) — HIGH

**Passkey-as-primary vs 2FA:**
- [passkeys.com — Passkey vs 2FA](https://www.passkeys.com/passkey-vs-2fa) — MEDIUM
- [1Password — Passkeys vs 2FA and TOTP](https://blog.1password.com/passkeys-2fa-totp-differences/) — HIGH
- [Bitwarden — Passkeys vs 2FA](https://bitwarden.com/resources/passkeys-vs-2fa/) — HIGH
- [Keeper — Passkeys vs 2FA](https://www.keepersecurity.com/blog/2024/06/18/passkeys-vs-two-factor-authentication-2fa-whats-the-difference/) — MEDIUM

**Sync fabric awareness:**
- [HN discussion — passkey sync fabric portability](https://news.ycombinator.com/item?id=34754308) — MEDIUM (community insight)
- [IDPro — Don't pass on passkeys](https://idpro.org/dont-pass-on-passkeys/) — HIGH

---

*Feature research for: Sigra v1.1 Foundations — Organizations + Passkeys*
*Researched: 2026-04-11*
*Scope excludes: admin UI, impersonation, audit views (all v1.2). v1.0 features treated as dependencies.*
