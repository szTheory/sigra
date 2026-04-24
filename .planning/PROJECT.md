# Sigra

## What This Is

Sigra is a comprehensive authentication library for Elixir/Phoenix that fills the critical gap left by Pow's incompatibility with Phoenix 1.8+. It uses a hybrid lib+generator architecture: security-critical code lives in the library (updated via `mix deps.update`), while customizable application code (schemas, routes, LiveViews) is generated into the developer's project. Sigra targets Phoenix/Ecto as the blessed path, with Plug compatibility where it doesn't compromise DX.

## Core Value

Authentication that works out of the box with great DX on the happy path AND on the rough edges — so developers can ship SaaS apps fast and grow with confidence, without wiring together 4+ libraries or maintaining security-sensitive code themselves.

## North Star (milestones)

Milestone scoping for GSD (`/gsd-new-milestone`, `/gsd-plan-phase`) should prefer work that advances these outcomes; defer open-ended polish unless it is tied to adoption, operator trust, or concrete risk.

- **Production-viable by default** — Optional integrations and limitations stay honest in package metadata and docs; merge-blocking CI and documented evidence (README production readiness, `MAINTAINING.md`, GA / audit artifacts) are the trust surface, not marketing claims.
- **Clear integration path** — `mix sigra.install`, generator output, introductory guides, upgrade stubs, and companion seams (with explicit non-goals where Sigra stops) so teams can adopt without reverse-engineering the library.
- **Great DX on happy path and rough edges** — First-run success, predictable errors, migrations, audit expectations, and maintainer operations are first-class, not afterthoughts.

**GSD use:** When a phase or milestone proposal does not clearly move one of the bullets above, treat it as lower priority unless it closes a documented adoption gap or security/audit risk.

## Current milestone

_No coordinated GSD milestone open._ Use **`/gsd-new-milestone`** when **`MAINTAINING.md`** *Resume `/gsd-new-milestone`* triggers fire; otherwise ship small fixes via **CHANGELOG + Hex** without a new planning milestone.

**Last closed:** **v1.14 — Bounded audit trust closure (SEED-002 slice)** (**Phase 77**, **AUD-13**..**AUD-13-04**, **2026-04-24**). **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** use **`commit_ad_hoc_mfa_audit/5`**; **`mfa_audit_atomicity_test.exs`**; planning truth on **09** / **44** / **CHANGELOG**. Archives: [`.planning/milestones/v1.14-ROADMAP.md`](milestones/v1.14-ROADMAP.md), [`.planning/milestones/v1.14-REQUIREMENTS.md`](milestones/v1.14-REQUIREMENTS.md). Verification: **`.planning/phases/77-mfa-adhoc-audit-multi/77-VERIFICATION.md`**.

**Previously closed:** **v1.13 — Post–v1.12 operational cadence** (planning **2026-04-24**, **Phase 76**, **CAD-01**..**CAD-03**). Archives: [`.planning/milestones/v1.13-ROADMAP.md`](milestones/v1.13-ROADMAP.md), [`.planning/milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md). Attestation: **`.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md`**.

**Last shipped code milestone:** **v1.14 — Bounded audit trust closure** (**Phase 77**, **2026-04-24**; **`AUD-13`**). Archives: [`.planning/milestones/v1.14-ROADMAP.md`](milestones/v1.14-ROADMAP.md), [`v1.14-REQUIREMENTS.md`](milestones/v1.14-REQUIREMENTS.md). _(Prior multi-phase doc ship: **v1.12** — phases **73–75**.)_

**Previously closed:** **v1.11 Adoption stabilization** — shipped **2026-04-23** (**phases 71–72**; **`STAB-01`**..**`STAB-04`**). Archives: [`.planning/milestones/v1.11-ROADMAP.md`](milestones/v1.11-ROADMAP.md), [`v1.11-REQUIREMENTS.md`](milestones/v1.11-REQUIREMENTS.md); triage [`.planning/v1.11-TRIAGE.md`](v1.11-TRIAGE.md).

**Previously closed:** **v1.10 Adopter confidence for solo production** — shipped **2026-04-23** (**phases 68–70**; **`ACF-01`**..**`ACF-06`**). Archives: [`.planning/milestones/v1.10-ROADMAP.md`](milestones/v1.10-ROADMAP.md), [`v1.10-REQUIREMENTS.md`](milestones/v1.10-REQUIREMENTS.md), [`v1.10-MILESTONE-AUDIT.md`](milestones/v1.10-MILESTONE-AUDIT.md); summary in [`.planning/MILESTONES.md`](MILESTONES.md).

**Reader bundle (v1.10 planning label):** [`.planning/v1.10-ADOPTER-SCOPE.md`](v1.10-ADOPTER-SCOPE.md).

**Previously closed:** **v1.9 Audit atomicity (bounded SEED-002)** — shipped **2026-04-23** (**phases 66–67**; **`AUD-09`** + **`AUD-10`**). Archives: [`.planning/milestones/v1.9-ROADMAP.md`](milestones/v1.9-ROADMAP.md), [`v1.9-REQUIREMENTS.md`](milestones/v1.9-REQUIREMENTS.md), [`v1.9-MILESTONE-AUDIT.md`](milestones/v1.9-MILESTONE-AUDIT.md).

**Reference (continuing work):** **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`** for further **SEED-002** batches when scheduled.

## Current State

**v1.14 (archived 2026-04-24):** Phase **77** — **AUD-13**..**AUD-13-04** MFA ad-hoc audit **`Multi`** closure. Archives: **`milestones/v1.14-ROADMAP.md`**, **`milestones/v1.14-REQUIREMENTS.md`**; verification **`.planning/phases/77-mfa-adhoc-audit-multi/77-VERIFICATION.md`**. Live **`.planning/REQUIREMENTS.md`** removed at milestone close — recreate via **`/gsd-new-milestone`**.

**v1.13 (planning shipped 2026-04-24):** Phase **76** — **CAD-01**..**CAD-03** cadence lock-in. Archives: **`milestones/v1.13-ROADMAP.md`**, **`milestones/v1.13-REQUIREMENTS.md`**; verification **`.planning/phases/76-post-v1-12-cadence-lock-in/76-VERIFICATION.md`**.

**v1.12 (shipped 2026-04-24):** Phases **73–75** complete — bounded **SEED-002** batch + **09-03** truth (**73**), launch evidence + **`docs/uat-ci-coverage.md`** alignment (**74**), and upgrade continuity + triage reconciliation (**75**). Planning archives: **`milestones/v1.12-ROADMAP.md`**, **`milestones/v1.12-REQUIREMENTS.md`**; verification **`.planning/phases/75-upgrade-continuity-triage-polish/75-VERIFICATION.md`**.

**v1.11 (shipped 2026-04-23):** Phases **71–72** — **`STAB-01`**..**`STAB-04`** adoption stabilization (triage log, **`MAINTAINING.md`** pause guidance, **`upgrading-to-v1.11.md`** + ExDoc, intro cross-links). Archives: [`.planning/milestones/v1.11-ROADMAP.md`](milestones/v1.11-ROADMAP.md), [`v1.11-REQUIREMENTS.md`](milestones/v1.11-REQUIREMENTS.md).

**v1.10 (shipped 2026-04-23):** Phases **68–70** — **`ACF-01`**..**`ACF-06`** adopter-confidence documentation (deployment + mail hub, intermediate path + **`generator-options`** index, **`upgrading-to-v1.10.md`** + **ADR 001** / **SEED-002** non-goal attestation). Archives: [`.planning/milestones/v1.10-ROADMAP.md`](milestones/v1.10-ROADMAP.md), [`v1.10-REQUIREMENTS.md`](milestones/v1.10-REQUIREMENTS.md).

**v1.9 (shipped 2026-04-23):** Phases **66–67** — **`confirm_enrollment/5`** **AUD-04-020..021** **`Multi`** + **`mfa_audit_atomicity_test.exs`** (**AUD-09**); **`09-03-SUMMARY.md`** + **D-06** attestation (**AUD-10**). Archives: [`.planning/milestones/v1.9-ROADMAP.md`](milestones/v1.9-ROADMAP.md), [`v1.9-REQUIREMENTS.md`](milestones/v1.9-REQUIREMENTS.md), [`v1.9-MILESTONE-AUDIT.md`](milestones/v1.9-MILESTONE-AUDIT.md).

**v1.8 (shipped 2026-04-23):** Phases **63–65** — **ADOPT-04** / **ADOPT-05** / **INTG-02** doc polish (archives: [`.planning/milestones/v1.8-ROADMAP.md`](milestones/v1.8-ROADMAP.md), [`v1.8-REQUIREMENTS.md`](milestones/v1.8-REQUIREMENTS.md)).

**v1.7 (shipped 2026-04-23):** **Phases 60–62** — archives: [`.planning/milestones/v1.7-ROADMAP.md`](milestones/v1.7-ROADMAP.md), [`v1.7-REQUIREMENTS.md`](milestones/v1.7-REQUIREMENTS.md), [`v1.7-MILESTONE-AUDIT.md`](milestones/v1.7-MILESTONE-AUDIT.md). **Phase 61:** **`AUD-01`** — `verify_backup/4` wrong-code failures are **`Ecto.Multi`** + **`log_multi_safe`** with **`mfa_audit_atomicity_test.exs`**; **AUD-04-067** + C-1 matrix refreshed. **Phase 62:** **`AUD-02`** — **`09-03-SUMMARY.md`** carries **v1.7** document status + Phase **61** bounded-batch narrative keyed to **`AUD-04-067`**; **D-06** left **`09-VERIFICATION.md`** unchanged. **Phase 60:** adoption + companion recipe guides under **`guides/introduction/`** and **`guides/recipes/companion-oauth-provider.md`** (no discrete **`060-*`** phase directory — see milestone audit).

**v1.6 (shipped):** **Phases 57–59** — **NYQ-01** / **NYQ-02** Nyquist posture matrix for **41–44**, **OA-01** merge-blocking OAuth ceremony audit coverage (**`Sigra.OAuthCeremonyAuditTest`**, **`phase_58_oauth_oa01_ci_contract_test`**), and **OA-02** documentation alignment across **`docs/uat-ci-coverage.md`**, **GA-03** planning surfaces, and maintainer routers. Archives: `.planning/milestones/v1.6-ROADMAP.md`, `v1.6-REQUIREMENTS.md`, `v1.6-MILESTONE-AUDIT.md` (audit filed retroactively on 2026-04-23).

**v1.5 (narrative + maintainer readiness):** Shipped **2026-04-22** — **`mix.exs`** Hex metadata (**PUB-01**), **`CHANGELOG.md`** milestone anchors (**PUB-02**), README / ExDoc GA entry paths (**DOC-01**, **DOC-02**), and maintainer **First public launch** checklist in **`MAINTAINING.md`** (**MAINT-01**). Archives: `.planning/milestones/v1.5-ROADMAP.md`, `v1.5-REQUIREMENTS.md`.

**Shipped:** **v1.4 GA readiness & audit trail completeness** (2026-04-22) — Phases **41–52**: backup-code rotation (**GA-01**), GA matrix with executed/waived rows and evidence (**GA-02..GA-05**), audit inventory + prioritized **`log_safe/3` → `Ecto.Multi`** batches through **OAuth/ops** (**AUD-04..AUD-08**) with formal **43/44/45 `*-VERIFICATION.md`** gates, **Nyquist + install-golden CI** policy (**50–51**), and **ROADMAP / milestone honesty** guardrails (**52**). Archives: `.planning/milestones/v1.4-ROADMAP.md`, `v1.4-REQUIREMENTS.md`, `v1.4-MILESTONE-AUDIT.md`.

**Previously shipped:** v1.3 Cleanup & Hardening (2026-04-19); v1.2 Admin Dashboard (2026-04-17); v1.1 Foundations (2026-04-16); v1.0 Phoenix Auth Library (2026-04-11).

Sigra is a Phoenix 1.8+ authentication platform spanning the v1.0 auth stack, v1.1 organizations and passkeys, v1.2 admin (default-on installer admin surface, impersonation, audit exploration, automation-first verification, generator parity), v1.3 hardening (validation/CI/UAT/audit-testability/maintainer tooling), and **v1.4 GA + audit-trail closure** (defensible GA substitutes where waived, broader atomic audit writes with merge-gated verification, CI truth for installer golden).

**Verification:** v1.4 requirements **10/10** satisfied in archive (Complete or Waived with documented substitutes); v1.3 milestone audit **passed** at close (2026-04-19); v1.2 audit **passed** (2026-04-17) with **23/23** in archive; v1.1 remains **79/79** in its archive.

## Next milestone goals

**When to open v1.15+ (or patch-only):** Prefer **CHANGELOG + Hex** for small fixes. Open a **new coordinated milestone** when an event matches **`MAINTAINING.md`** *Resume `/gsd-new-milestone`* list (loud launch + **SEED-001**, compliance / incident + further **SEED-002**, documented adoption gap, **ADR 001** glue).

**Backlog / hygiene:** Phase **999.1** and **999.x** — optional archaeology; see **`.planning/ROADMAP.md`**. **`STATE.md`** is session handoff only. **Planning precedence:** **`ROADMAP.md`** + phase **`*-VERIFICATION.md`** over conflicting **`STATE.md`** notes.

**Later candidates:** bounded **SEED-002** batches, **SEED-001** human matrix before megaphone launch, **999.x** only if promoted, **`sigra_lockspire`** per ADR **001** triggers.

<details>
<summary>Archived v1.2 milestone framing (Admin Dashboard)</summary>

**Goal:** Ship a default-on admin surface that feels excellent to use: mobile-responsive LiveView user management, secure impersonation, and rich audit exploration on top of the v1.1 organizations and passkeys foundation.

**Target features (shipped in v1.2):**
- Admin user-management UI in LiveView, default on with `--no-admin` opt-out, mobile-friendly, light/dark, and basic branding hooks
- Admin impersonation with strict guardrails, visible session state, dual-actor audit trail, and blocked sensitive mutations while impersonating
- Expanded audit views across user, organization, and global admin workflows with scope-respecting CSV export
- Automation-first verification: Playwright, screenshots/video where useful, HTML reports, browser and curl-style smoke, CI jobs including generated-host parity and shift-left gates (Phases 31-35)

</details>

<details>
<summary>Archived v1.1 milestone framing</summary>

**Goal:** Ship the architectural foundation that unlocks v1.2's admin dashboard — logical multi-tenancy (organizations + memberships, single DB, no PG schema-per-tenant) and passkey/WebAuthn authentication. No admin UI in this milestone; only the user-facing surface each feature needs to be usable end-to-end.

**Target features:**
- Organizations (logical multi-tenancy, default-on with `--no-organizations` opt-out): `Organization` / `OrganizationMembership` / `OrganizationInvitation` schemas, `Sigra.Organizations` context, `Sigra.Plug.RequireMembership`, Scope struct extension (`:active_organization`, `:membership`), sessions `active_organization_id` column, automatic `organization_id` in audit metadata, HMAC-protected invite flow with email acceptance, `OrganizationSwitcherLive` / `OrganizationSettingsLive` / `OrganizationMembersLive` / `InvitationAcceptLive`, generator conditional template pattern (first in codebase, load-bearing for v1.2 `--no-admin`)
- Passkeys (WebAuthn via `wax_`, default-on with `--no-passkeys` opt-out): `UserPasskey` schema with `cloak_ecto`-encrypted public keys, `Sigra.Passkeys` / `Sigra.Passkeys.Registration` / `Sigra.Passkeys.Authentication` contexts, `Sigra.Plug.PasskeyChallenge`, passkey-as-2FA AND passkey-as-primary modes, `PasskeyEnrollmentLive` / `PasskeyAuthenticationLive`, `MfaSettingsLive` updates to list passkeys alongside TOTP, runtime RP ID / origin config, JS hooks for credential ceremonies

**Deferred to v1.2 "Admin Dashboard"** (full direction captured in `.planning/v1.2-DIRECTION.md`): admin user-management LiveView UI (Django-admin-loved, mobile-first, light+dark mode, basic branding, default-on opt-out), admin impersonation (time-limited, audited, sudo-gated, locked-down sensitive ops, org-scoped for org admins), expanded audit views (per-user, per-org, global, impersonation feed, CSV export).

</details>

## Requirements

### Validated — v1.14 Bounded audit trust closure (shipped 2026-04-24)

- ✓ **AUD-13-01** — **`audit_backup_codes_regenerate/3`** **`Multi` + `log_multi_safe`** — **Phase 77**
- ✓ **AUD-13-02** — **`audit_trust_browser/2`** same pattern — **Phase 77**
- ✓ **AUD-13-03** — **`mfa_audit_atomicity_test.exs`** coverage — **Phase 77**
- ✓ **AUD-13-04** — C-1 matrix + inventory + summary + **CHANGELOG** — **Phase 77**

### Validated — v1.13 Post–v1.12 operational cadence (planning shipped 2026-04-24)

- ✓ **CAD-01** — **`.planning/PROJECT.md`** + archive **[`milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md)** — default ops lane and event lanes — **Phase 76**
- ✓ **CAD-02** — **`.planning/STATE.md`** (at close) reflected **v1.13** / Phase **76** — **Phase 76**
- ✓ **CAD-03** — **`.planning/ROADMAP.md`** + **[`milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md)** traceability — **Phase 76**

### Validated — v1.12 Trust, evidence, and adoption polish (shipped 2026-04-24)

- ✓ **AUD-11** — Bounded **SEED-002** **`Multi`** + **`log_multi_safe`** batch + audit-aware tests — **Phase 73**
- ✓ **AUD-12** — **09-03-SUMMARY** (+ **09-VERIFICATION** rationale) — **Phase 74**
- ✓ **UAT-01** — **`.planning/v1.12-UAT-EVIDENCE.md`** (eight SEED-001 rows) — **Phase 74**
- ✓ **UAT-02** — **`docs/uat-ci-coverage.md`** aligned with **v1.12** evidence — **Phase 74**
- ✓ **TRN-01** — **`upgrading-to-v1.12.md`** + **`mix.exs`** ExDoc extras — **Phase 75**
- ✓ **TRN-02** — Intro + **MAINTAINING** or **CHANGELOG** pointers — **Phase 75**
- ✓ **TRN-03** — Triage/issue-derived polish or explicit “no triage deltas” — **Phase 75**

### Validated — v1.11 Adoption stabilization (shipped 2026-04-23)

- ✓ **STAB-01** — **`.planning/v1.11-TRIAGE.md`** records triage + week-one path notes — **Phase 71**
- ✓ **STAB-03** — **`MAINTAINING.md`** *Milestone cadence and pause* section — **Phase 71**
- ✓ **STAB-02** — **`guides/introduction/upgrading-to-v1.11.md`** + **`mix.exs`** ExDoc extras — **Phase 72**
- ✓ **STAB-04** — **getting-started** + **upgrading-to-v1.10** cross-links — **Phase 72**

### Validated — v1.0

**Core authentication:**
- ✓ `mix sigra.install` generator (migrations, schemas, context, routes, optional LiveView pages) — v1.0
- ✓ Phoenix context pattern (`MyApp.Auth`) — v1.0
- ✓ Headless mode (all logic works without UI) — v1.0
- ✓ Behaviour + callback architecture for extensibility (no hidden macros) — v1.0
- ✓ Smart defaults with easy overrides via NimbleOptions — v1.0
- ✓ Email/password registration with Argon2id hashing — v1.0
- ✓ Magic link / passwordless email authentication — v1.0
- ✓ Login / logout with server-side database-backed sessions — v1.0
- ✓ Password hash migration (bcrypt → Argon2id transparent upgrade on login) — v1.0
- ✓ Email confirmation (link + 6-digit code verification) — v1.0
- ✓ Password reset via HMAC-protected single-use time-limited email tokens — v1.0
- ✓ Remember-me persistent sessions — v1.0
- ✓ Sudo/re-authentication mode for sensitive operations — v1.0

**OAuth / Social login:**
- ✓ OAuth integration via Assent (Google, GitHub, Apple, Facebook, Generic) — v1.0
- ✓ Account linking (existing user adds OAuth provider, email-match handling) — v1.0
- ✓ Multiple OAuth providers per user — v1.0
- ✓ PKCE and OIDC support via Assent — v1.0

**MFA:**
- ✓ TOTP enrollment, verification, and recovery (full lifecycle) — v1.0
- ✓ Backup codes (SHA-256 hashed, single-use, regeneration) — v1.0
- ✓ "Trust this browser" cookie to skip MFA on trusted devices — v1.0
- ✓ MFA enforcement policies via plug — v1.0

**Session management:**
- ✓ Active session tracking (IP, user agent, last active, device) — v1.0
- ✓ Session revocation (individual and log-out-everywhere) — v1.0
- ✓ Session invalidation on password change — v1.0
- ✓ Idle and absolute timeout (configurable) — v1.0
- ✓ Secure cookie defaults (SameSite=Lax, HttpOnly, Secure) — v1.0
- ✓ Account lockout after N failed attempts — v1.0
- ✓ Email enumeration prevention — v1.0

**API authentication:**
- ✓ Bearer token authentication with human-readable prefix (`myapp_sk_*`) — v1.0
- ✓ Personal access tokens (user-scoped, scopes + expiration) — v1.0
- ✓ JWT support for stateless API use cases (opt-in, family-based refresh rotation) — v1.0
- ✓ Dual-mode auth plug (session for browser, bearer for API, identical `current_scope`) — v1.0

**Security:**
- ✓ IP-based and account-based rate limiting via Hammer 7.x — v1.0
- ✓ HMAC-protected tokens for all email flows — v1.0
- ✓ Suspicious login detection with email notification — v1.0

**Transactional email:**
- ✓ Confirmation, password reset, lockout, suspicious-login, MFA, account lifecycle emails — v1.0
- ✓ Swoosh integration with pluggable mailer — v1.0
- ✓ HTML + text multipart with inline CSS — v1.0
- ✓ Async delivery via Oban with inline fallback — v1.0

**Account lifecycle:**
- ✓ Email change with re-verification — v1.0
- ✓ Password change with current password verification — v1.0
- ✓ Account deletion (soft, hard, anonymize) with grace period — v1.0
- ✓ Profile hooks engine with Ecto.Multi abort support — v1.0

**Developer experience:**
- ✓ Testing helpers (`log_in_user/2`, `register_user/1`, `setup_totp/1`, `create_api_key/2`, browser trust helpers) — v1.0
- ✓ Telemetry events for all auth operations (24+ events across phases) — v1.0
- ✓ Audit logging (security events with user, IP, user agent, action, metadata) — v1.0 (with C-1 caveat)
- ✓ `getting-started.md` guide + 15 additional guides + `llms.txt` — v1.0

### Validated — v1.5 Public release narrative & community readiness

- ✓ **PUB-01** — `mix.exs` package description and links aligned with shipped **v1.0–v1.4** capabilities; optional deps called out honestly — **Phase 53** (2026-04-22)
- ✓ **PUB-02** — `CHANGELOG.md` milestone anchors, roadmap traceability (**v1.2–v1.4**), compare links — **Phase 54** (2026-04-22)
- ✓ **DOC-01** — README GA / production-readiness paragraph with pointers to **v1.4** evidence — **Phase 55** (2026-04-22)
- ✓ **DOC-02** — ExDoc landing path to maintainer GA / audit narrative — **Phase 55** (2026-04-22)
- ✓ **MAINT-01** — `MAINTAINING.md` **First public launch** checklist with owners and evidence links — **Phase 56** (2026-04-22)

### Validated — v1.8 Adopter polish (shipped 2026-04-23)

- ✓ **ADOPT-04** — **`guides/introduction/upgrading-to-v1.8.md`**, **`mix.exs`** ExDoc extras ordering, **planning v1.8** vs **Hex SemVer** framing, pointers to **v1.7** upgrade context — **Phase 63**
- ✓ **ADOPT-05** — Cross-links across **`getting-started`**, **`first-hour`**, **`troubleshooting-install`**, **`CHANGELOG`**, and both upgrade guides — **Phase 64**
- ✓ **INTG-02** — **`companion-oauth-provider.md`** prerequisites, **B2C-only / no third-party clients** anti-pattern clarity, **See also** → **`upgrading-to-v1.8.html`** — **Phase 65**

### Validated — v1.9 Audit atomicity (bounded SEED-002) (shipped 2026-04-23)

- ✓ **AUD-09** — **`Sigra.MFA.confirm_enrollment/5`** **AUD-04-020..021** **`Multi`** + **`log_multi_safe`** with **`mfa_audit_atomicity_test.exs`**; **022** remains **T2** / **`EX-44-02`** — **Phase 66**
- ✓ **AUD-10** — **`09-03-SUMMARY.md`** post–**phase-66** trace + bounded-batch narrative; **D-06** reconciliation **AUD-04-020..022** vs **44** inventory with explicit **no `09-VERIFICATION.md` edit`** attestation — **Phase 67**

### Validated — v1.10 Adopter confidence for solo production (shipped 2026-04-23)

- ✓ **ACF-01** — Production **HTTPS / proxy / session cookie** checklist hub in **`guides/recipes/deployment.md`** with maintainer + intro discovery links — **Phase 68**
- ✓ **ACF-04** — **Oban-backed vs inline** Swoosh delivery TL;DR + install flags + example pointers — **Phase 68**
- ✓ **ACF-02** — **`guides/introduction/intermediate-production-path.md`** intermediate dogfood spine + **`.planning/v1.10-ADOPTER-SCOPE.md`** link — **Phase 69**
- ✓ **ACF-03** — **`guides/reference/generator-options.md`** optional-feature index + intro cross-links — **Phase 69**
- ✓ **ACF-05** — **`guides/introduction/upgrading-to-v1.10.md`** + **`mix.exs`** ExDoc extras — **Phase 70**
- ✓ **ACF-06** — Archived **v1.10** requirements + **`PROJECT.md`** explicit deferrals for **`sigra_lockspire`** and full **SEED-002** with **ADR 001** + seed pointers — **Phase 70**

### Validated — v1.7 Adoption readiness & audit durability (shipped 2026-04-23)

- ✓ **ADOPT-01** / **ADOPT-02** / **ADOPT-03** — First-hour guide, **v1.7** upgrade stub, install troubleshooting wired into ExDoc — **Phase 60**
- ✓ **INTG-01** — Companion embedded OAuth/OIDC provider recipe (non-coupled seam) — **Phase 60**
- ✓ **AUD-01** — Bounded **`verify_backup/4`** failure-path **`Multi`** + audit-aware tests + honest **AUD-04** / **C-1** rows — **Phase 61** (2026-04-23)
- ✓ **AUD-02** — **`09-03-SUMMARY.md`** aligned to post–**phase-61** **C-1** truth with explicit planning trace; **D-06** required no **`09-VERIFICATION.md`** edit — **Phase 62** (2026-04-23)

### Validated — v1.6 Nyquist closure + OAuth audit depth

- ✓ **NYQ-01** / **NYQ-02** — Maintainer-facing **41–44** posture matrix under **`.planning/`** with **`MAINTAINING.md`** entry point + precedence rule; optional **D-11** contract test — **Phase 57** (2026-04-23)
- ✓ **OA-01** — Postgres-backed **`Sigra.OAuthCeremonyAuditTest`** (registration + **`authorize_url`** audit rows) and **`phase_58_oauth_oa01_ci_contract_test`** CI honesty for **`library_tests`** — **Phase 58** (2026-04-22)
- ✓ **OA-02** — **`docs/uat-ci-coverage.md`** machine vs human hub plus **GA-03** matrix / waiver / evidence **INDEX** / **`docs/ga-evidence.md`** alignment — **Phase 59** (2026-04-23)

### Validated — v1.4 GA readiness & audit trail completeness

- ✓ **GA-01** — Backup-code rotation: `Sigra.MFA.regenerate_backup_codes/4`, example `Accounts` + `MFASettingsLive`, install templates, regression in `test/example/.../backup_code_rotation_test.exs` — **Phase 41** (2026-04-20)
- ✓ **GA-02** — Email visual QA row **Waived** with machine baseline + evidence pointers — **Phase 46** (2026-04-21)
- ✓ **GA-03** — Live Google OAuth row **Waived** with `Sigra.OAuthTest` substitute — **Phase 46** (2026-04-21)
- ✓ **GA-04** — Clean-machine getting-started row **Waived** with CI contract substitute — **Phase 46** (2026-04-21)
- ✓ **GA-05** — Consolidated matrix `.planning/v1.4-GA-UAT.md` + cross-links — **Phase 46** (2026-04-21)
- ✓ **AUD-04** / **AUD-05** — Inventory + Auth `Ecto.Multi` batch + `43-VERIFICATION.md` — **Phase 47** (2026-04-21)
- ✓ **AUD-06** / **AUD-07** — MFA + Account/API batch + `44-VERIFICATION.md` — **Phase 48** (2026-04-21)
- ✓ **AUD-08** — OAuth/ops batch + `45-VERIFICATION.md` + `mix ci.audit_45`; Phase 9 **C-1** matrices refreshed — **Phase 49** (2026-04-21)
- ✓ **Process closure** — Nyquist policy + **`mix ci.install_golden`** + **`install_golden_contract`** (**50**), CI path coupling + GA↔installer attestation tests (**51**), ROADMAP honesty + contract tests (**52**) — **2026-04-21–22**

### Validated — v1.3 Cleanup & Hardening

**Planning, CI, UAT, audit, tooling:**
- ✓ Nyquist retro inventory + waivers for historical validation debt (**999.1**) — v1.3
- ✓ SHA-pinned first-party Actions upgrades with Dependabot triage notes (**999.2**) — v1.3
- ✓ GA UAT gate evidence + shift-left automation map for **SEED-001** posture — v1.3
- ✓ `Sigra.Audit.Assertions` + atomic audited `api.token_create` + example login/MFA audit smoke — v1.3
- ✓ Maintainer release checklist + planning hygiene supersession (`MAINTAINING.md`, optional Hex publish job pattern) — v1.3

### Validated — v1.2 Admin Dashboard

**Admin user management UI:**
- ✓ LiveView admin dashboard enabled by default with `--no-admin` opt-out — v1.2
- ✓ Mobile-responsive user list and user detail flows for core operator jobs — v1.2
- ✓ Light/dark mode plus basic branding controls suitable for internal tooling — v1.2
- ✓ Org-aware admin scopes so platform admins and org admins see the right surface by construction — v1.2

**Impersonation + audit:**
- ✓ Secure admin impersonation with visible banner state, time bounds, dual-actor audit trail, and forbidden sensitive actions — v1.2
- ✓ Rich audit views for per-user, per-organization, and global exploration, including impersonation-aware filtering — v1.2 (Phase 30; polish Phase 33)
- ✓ Admin-side user detail views for sessions, security state, identities, organizations, memberships, and danger-zone actions — v1.2

**Verification + review ergonomics:**
- ✓ Browser and system automation for critical admin flows using Playwright and CI — v1.2 (Phases 31, 34-35)
- ✓ Review artifacts (Playwright HTML, screenshots/traces/video where configured, curated PNG baselines) — v1.2
- ✓ Route, controller, and curl-style smoke coverage outside the browser happy path — v1.2

### Other deferred items

_SEED-001 and SEED-002 were promoted and **closed in v1.4** (see `.planning/milestones/v1.4-REQUIREMENTS.md`). Use this list for ideas **not** selected for the next milestone._

- (none captured — add here when `/gsd-new-milestone` promotes new seeds)

### Out of Scope

- SAML support — enterprise SSO protocol, high maintenance burden, low SaaS builder need. Leave architecture extensible for future plugin.
- Acting as OAuth/OIDC identity provider — enterprise/B2B concern, dramatically expands scope. Architecture should not prevent future addition.
- Rebuilding organizations or passkeys as standalone milestones — v1.1 shipped the foundation; v1.2 builds on top of it.
- Authorization (RBAC, permissions, policies) — separate concern. Sigra provides identity context; authorization builds on top.
- SCIM directory sync — enterprise feature, out of scope for v1.
- Full theming engine or runtime UI builder — only basic branding hooks are in scope for the admin surface.

## Context

**Ecosystem gap:** Elixir's auth ecosystem is fragmented. phx.gen.auth is a minimal generator (no OAuth, MFA, API tokens, rate limiting). Pow is dead on Phoenix 1.8+. Ueberauth/NimbleTOTP/Guardian each handle one slice — no integrated solution exists. State of Elixir surveys (2023-2025) rank missing libraries as the #1-2 challenge.

**Prior art studied extensively:**
- **Devise** (Ruby) — cautionary tale of hidden magic, but defined the "batteries-included" category
- **Rodauth** (Ruby) — architectural gold standard (encapsulated auth object, per-feature tables, HMAC tokens, uniform DSL), but integration ergonomics suffer from Rack middleware approach
- **Better Auth** (JS) — modern benchmark for plugin architecture and composable features
- **Django Allauth** — feature completeness standard (100+ providers, MFA, headless API, identity provider)
- **Laravel** — progressive complexity with clear layers (Breeze → Jetstream → Fortify → Sanctum → Passport)
- **phx.gen.auth** — respects José's "own your code" philosophy, but security patches don't propagate

**Hybrid architecture chosen because:** Pure generators have a fatal flaw (no security patch propagation). Pure libraries fight the Elixir philosophy of visible code. The hybrid — security in the dep, UX in generated code — threads the needle.

**Database design:** Hybrid user/identity pattern — `users` table as stable identity anchor, `user_identities` table for credentials (password, OAuth providers). Separate tables per concern (tokens, passkeys, MFA credentials, API keys, audit log). This is the pattern Better Auth, Django Allauth, and PowAssent all converge on.

**Key dependencies (minimal, high-quality):**
- Assent — OAuth/OIDC (framework-agnostic, PKCE, 20+ providers in one package)
- Comeonin + Argon2 — password hashing
- NimbleTOTP — TOTP primitives (or copy-paste if simple enough)
- Wax — WebAuthn/FIDO2 ceremonies
- Swoosh — transactional email (pluggable mailer interface)
- Prefer copy-paste over deps where the code is small and stable

**Code philosophy:**
- Idiomatic Elixir/Plug/Phoenix
- DDD with clean layered architecture (domain → application services → infrastructure)
- Command/query separation at application layer
- Behaviours + callbacks for extensibility (no hidden macros)
- Dependency injection via module attributes/config for testability
- Principle of least surprise — API should be a joy to use
- Flat, self-contained AAA-style specs with scenario-based fixtures

**Target users:**
- Solo SaaS builders wanting auth done in an afternoon (Persona A)
- Mid-market engineering teams needing MFA/SSO for enterprise customers (Persona B)
- API builders needing bearer tokens and JWT (Persona C)
- Developers migrating from Pow or hand-rolled auth (Persona D)

## Constraints

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. Plug compatibility where DX is not compromised.
- **Database:** PostgreSQL as primary (citext, JSONB). MySQL/SQLite support via conditional migrations.
- **Security:** OWASP standards throughout. Argon2id default. All tokens HMAC-protected. Enumeration prevention by default.
- **Dependencies:** Minimal transitive deps. Copy-paste over deps when code is small and stable.
- **LiveView:** Supported but optional. Core works with standard controllers. Login/logout via HTTP POST (not LiveView events).
- **Testing:** Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hybrid lib+generator architecture | Security patches propagate via dep updates; devs own customizable code. Respects José's philosophy while solving the patch propagation problem. | ✓ Validated v1.0 — no regret |
| Phoenix context pattern for generated code | `MyApp.Auth` context follows DDD boundaries, is idiomatic Phoenix, and keeps the public API clean. | ✓ Validated v1.0 — no regret |
| Assent over Ueberauth for OAuth | Framework-agnostic, PKCE/OIDC built-in, single package vs N strategy deps, actively maintained. | ✓ Validated v1.0 — shipped 5 strategy wrappers (Google/GitHub/Apple/Facebook/Generic); Assent's PKCE + OIDC + single-package design paid off |
| Hybrid user/identity table pattern | `users` + `user_identities` — clean multi-provider support, natural Ecto idiom, matches Better Auth/Django Allauth/PowAssent. | ✓ Validated v1.0 — pattern held through registration/login/linking/unlink |
| Argon2id default with bcrypt migration path | OWASP gold standard; memory-hard; transparent upgrade on login keeps migration invisible to users. | ✓ Validated v1.0 — `verify_with_upgrade/3` pattern works cleanly |
| Database-backed session tokens (no JWT for browser) | Revocation requires server-side state; JWT-only for browser is an anti-pattern for session auth. | ✓ Validated v1.0 — JWT remains opt-in for stateless API paths only |
| D-01 universal atomic `Ecto.Multi` for audit writes | Audit rows must be as durable as the business op that produced them; no dropped rows on partial failure. | ✓ Advanced in v1.4 — prioritized Auth/MFA/Account/OAuth batches + merge-gated verification; remaining deferrals are explicitly listed under post–v1.4 **C-1** matrices |
| D-10 installer default PK type = `binary_id` (uuid) | UUIDs are idiomatic for modern Phoenix; avoids enumeration of integer IDs; matches phx.gen.auth 1.8 convention. | ✓ Validated v1.0 (flipped in phase 10.1.1) — no integer-PK regressions downstream |
| IN-03 SHA-pin all GitHub Actions | Supply-chain security: tag-based references allow the tag to be moved post-publish; SHA pins lock the exact code. | ✓ Validated v1.0 (phase 10.1 + 10.1.1) — Dependabot `github-actions` ecosystem handles upgrade churn |
| D-15 no `continue-on-error` on any required CI check | Flakes must be fixed at root cause; masking them defeats the gate's purpose. | ✓ Validated v1.0 — all 5 CI jobs are strict-pass; no `continue-on-error` anywhere in `.github/workflows/ci.yml` |
| Playwright over Cypress/WebdriverIO for browser smoke | Only runner with first-class frameLocator support for Swoosh dev-mailbox iframe; lowest-friction TypeScript setup. | ✓ Validated v1.0 (phase 10.1.1) — golden-path spec runs in ~90s on CI, zero flakes to date |
| Organizations as first-class multi-tenancy | Logical tenants without schema-per-tenant; scope + membership + invitations. | ✓ Shipped v1.1 — org switcher, plugs, audit columns; superseded the old “defer to v2” note |
| SAML / OAuth IdP out of scope | Enterprise concern with high maintenance burden. Architecture should not prevent future plugin/extension. | — Pending (still out of scope) |
| Optional `sigra_lockspire` glue package | Keeps Sigra core deps minimal; companion OAuth servers integrate via **host-generated** seams (`AccountResolver`); glue only after both APIs stable. | — Deferred — see `.planning/decisions/001-defer-sigra-lockspire-glue-package.md` |
| WebAuthn / passkeys deferred from v1.0 MFA | TOTP covers the broader developer use case; WebAuthn adds meaningful complexity; `wax_` dep was evaluated but not integrated. | ✓ Shipped v1.1 — passkeys + orgs foundations |
| v1.2 admin is default-on installer feature with library-owned enforcement | Keeps security semantics in the dep while host owns policy module + shell chrome; matches hybrid architecture. | ✓ Validated v1.2 — plugs, `Sigra.Admin.*`, generator parity phases 32-33 |
| Shift-left gates for installer + verification docs | Prevents INT-01..04 recurrence: emission audit, drift dead-text nav guard, milestone VERIFICATION.md gate, installer-scoped milestone audit CI, artifact bundle contract. | ✓ Validated v1.2 — Phase 35 |
| v1.3 audit assertions + partial Multi conversion | Give hosts test-grade audit helpers and prove one high-risk API path can commit business + audit rows atomically without inventing audit macros. | ✓ Validated v1.3 — Assertions module + `api.token_create` Multi; OAuth smoke out of scope |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

<details>
<summary>Archived milestone “Last updated” footers (v1.0–v1.13 execution log)</summary>

- **2026-04-24** — **`/gsd-complete-milestone` v1.14**: archived **`v1.14-REQUIREMENTS.md`**, **`v1.14-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.14`**.
- **2026-04-24** — **`/gsd-complete-milestone` v1.13** (planning-only): archived **`v1.13-REQUIREMENTS.md`**, **`v1.13-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; no Hex tag (no library version bump).
- **2026-04-24** — **`/gsd-complete-milestone` v1.12**: archived **`v1.12-REQUIREMENTS.md`**, **`v1.12-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed; tag **`v1.12`**.
- **2026-04-23** — **v1.11** phases **71–72** complete; archived **`v1.11-REQUIREMENTS.md`** + **`v1.11-ROADMAP.md`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.10** phases **68–70** complete; `/gsd-complete-milestone` archived planning + tag **`v1.10`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.9** phases **66–67** complete; `/gsd-complete-milestone` archived planning + tag **`v1.9`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.8** phases **63–65** complete; `/gsd-complete-milestone` archived planning + tag **`v1.8`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.7** phases **60–62** complete; `/gsd-complete-milestone` archived planning + tag **`v1.7`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-23** — **v1.6** phases **57–59** complete; `/gsd-complete-milestone` archived planning + tag **`v1.6`**; live **`REQUIREMENTS.md`** removed.
- **2026-04-22** — **v1.5** phases **53–56** complete; `/gsd-complete-milestone` archived planning + tag **`v1.5`**.
- **2026-04-22** — v1.4 phases **41–52** complete on ROADMAP; milestone wrap via `/gsd-complete-milestone`.
- **2026-04-21** — Phases **50** (Nyquist + `install_golden_contract`), **49** (`45-VERIFICATION.md`, **AUD-08**), **48** / **47** (44/43 verification), **46** (GA matrix gap closure).
- **2026-04-20** — Phase **41** (**GA-01**); `/gsd-new-milestone` opened v1.4.
- **2026-04-19** — v1.3 shipped; live `REQUIREMENTS.md` removed for next milestone.
- **2026-04-17** — v1.2 shipped.
- **2026-04-11** — v1.0 shipped + v1.1 milestone start notes.
- **2026-04-09** — Phase 8 account lifecycle completion notes.

</details>

*Last updated: 2026-04-24 — **`/gsd-complete-milestone` v1.14**: archived **`v1.14-ROADMAP.md`** + **`v1.14-REQUIREMENTS.md`**; live **`REQUIREMENTS.md`** removed; git tag **`v1.14`**; **`77-01-SUMMARY.md`** added.*
