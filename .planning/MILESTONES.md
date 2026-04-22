# Milestones

## v1.0 Phoenix Auth Library — Initial Release (Shipped: 2026-04-11)

**Scope:** 12 phases (including 2 remediation phases), 60 plans, 117 tasks.

**What shipped:** A comprehensive Phoenix 1.8+ authentication library that fills the gap left by Pow's incompatibility — hybrid lib+generator architecture, Argon2id default, bcrypt→Argon2id transparent migration, magic-link passwordless, email confirmation + password reset with HMAC-protected single-use tokens, database-backed sessions with revocation + sudo re-auth + rate limiting + suspicious-login detection, OAuth/OIDC via Assent (Google/GitHub/Apple/Facebook/Generic), MFA via TOTP with backup codes and trust-this-browser, API authentication with opaque bearer tokens + PATs + optional JWT with refresh rotation, full account lifecycle (email change, password change, scheduled deletion, reactivation), audit logging with 24+ telemetry events, and a complete developer experience layer with `mix sigra.install` generator, testing helpers, docs, and UAT runbook.

### Key Accomplishments

1. **Hybrid lib+generator architecture (Phase 1)** — Security-critical code in `Sigra.*` library dep; generated schemas/routes/LiveViews in the host app. Plain Ecto schemas with no macro injection. Phoenix 1.8-compatible scaffold via `mix sigra.install`.

2. **Core auth + email flows (Phases 2–3)** — Email/password registration with Argon2id, magic-link passwordless, bcrypt→Argon2id transparent hash upgrade on login, enumeration-safe error responses, HMAC-signed confirmation (link + 6-digit code), password reset with atomic `Ecto.Multi` + all-sessions invalidation, and async email delivery via Oban with inline fallback.

3. **Session management + security baseline (Phase 4)** — Database-backed sessions with 13-field `Sigra.Session` struct, `SessionStore` behaviour, GeoIP-aware suspicious-login detection, Hammer 7.x rate limiting (account + IP), account lockout with configurable threshold/duration, sudo re-auth, and session listing LiveView with device/IP/location display and revoke actions.

4. **OAuth and MFA (Phases 5–6)** — `mix sigra.gen.oauth` generator producing 12+ files with encrypted token storage, 5 Assent strategy wrappers (Google/GitHub/Apple/Facebook/Generic), OAuth callback processor handling register/login/link-confirm/no-email/UID-conflict scenarios; TOTP MFA with NimbleTOTP primitives, backup codes with SHA-256 hashing, trust-this-browser cookies, `mfa_pending` session gate, MFA enforcement plug, and admin-facing enforcement policies.

5. **API authentication (Phase 7)** — Dual-mode auth plug producing identical `current_scope` shape for session and bearer paths, SHA-256-hashed PATs with human-readable prefix and one-time display, JWT support via Joken with HMAC-SHA256 and Auth0-style family-based refresh token rotation with reuse detection, headless mode support via `--no-live`/`--api`/`--jwt` install flags.

6. **Account lifecycle + audit logging (Phases 8–9)** — Email change with re-verification, password change with current-password verification, scheduled account deletion (soft/hard/anonymize) via Oban worker, reactivation during grace period, Hooks engine for profile update callbacks, DataExport behaviour, 24+ audit events covering all security-relevant operations, queryable audit API, and atomic `Ecto.Multi` audit writes at 3 critical sites (confirm, verify, reset) with telemetry-on-commit at all integration sites.

7. **Developer experience (Phase 10)** — `Sigra.Testing` helpers (`log_in_user`, `setup_totp`, `create_api_key`, `scenario`, browser trust helpers), `getting-started.md` guide + 15 additional guides + `llms.txt` generation, `mix docs --warnings-as-errors` clean, cookie config, and polished error messages.

8. **Library remediation (Phase 10.1)** — Fixed critical library bugs found during phase 10 review: AR-10-01/AR-10-02 plain-map-insert DoS in `request_password_reset/3` and `request_magic_link/3` (now use `struct!(user_token_schema, …)`), backported 16 installer template fixes from `test/example/` into `priv/templates/sigra.install/*` with a drift-guard test, eliminated all `mix docs --warnings-as-errors` warnings, SHA-pinned 6 GitHub Actions + Dependabot `github-actions` config, extracted release-safe `Sigra.Env.current/0`, and fixed 5 pre-existing failing tests. Full suite green: 1249 tests + 33 doctests + 3 properties, 0 failures.

9. **Example-app repair + CI smoke harness (Phase 10.1.1)** — Closed 9 DX bugs (B1–B9) found during v1.0 UAT session, flipped installer default to `binary_id` primary keys (D-10), added `--yes` non-interactive flag, and landed a 5-job CI harness gating every PR:
   - `library_tests` — full ExUnit suite + `mix docs --warnings-as-errors`
   - `example_unit_smoke` — ExUnit ConnTest against real Postgres
   - `install_smoke` — fresh `mix phx.new` + `mix sigra.install --yes` + compile clean
   - `example_http_smoke` — boot example app + `curl` critical routes (gate on 5xx)
   - `example_playwright_smoke` — full browser lifecycle spec (register → confirm → login → sessions → sudo → MFA enroll with real TOTP → logout → re-login) via Playwright + otplib
   Branch protection ruleset on `main` requires all 5 by display name (verified via `gh api`).

### Stats

- **Library:** 1249 tests + 33 doctests + 3 properties, 0 failures
- **CI:** 5 required status checks on `main`, all green
- **Requirements:** 85/85 satisfied and marked Complete
- **Timeline:** 2026-04-05 → 2026-04-11 (6 days of focused execution)

### Tech Debt Carried Forward (tracked, non-blocking)

**Seeds** (trigger-conditioned, surface during `/gsd-new-milestone`):
- `SEED-001` — 8 human-only UAT items to run before GA public announcement (email visual × 4, OAuth real-credential × 4)
- `SEED-002` — Phase 9 `log_safe/3` hybrid to atomic `Ecto.Multi` conversion (C-1 caveat followup)

**Backlog** (999.x parking lot):
- `Phase 999.1` — Retroactive Nyquist validation pass for 6 draft + 1 missing VALIDATION.md files
- `Phase 999.2` — Dependabot major-version bumps (setup-node 4→6, upload-artifact 4→7, checkout 4→6) requiring per-bump CI verification

**Archive:**
- [v1.0 Roadmap](milestones/v1.0-ROADMAP.md) — full phase details
- [v1.0 Requirements](milestones/v1.0-REQUIREMENTS.md) — all 85 REQ-IDs with outcomes
- [v1.0 Milestone Audit](milestones/v1.0-MILESTONE-AUDIT.md) — final audit report

---

## v1.1 Foundations (Shipped: 2026-04-16)

**Scope:** 13 phases, 68 plans, 154 plan tasks.

**What shipped:** Sigra v1.1 delivered logical multi-tenancy and passkeys end to end. The release now includes organizations, memberships, invitations, active-organization scope/session hydration, tenant-aware audit columns, passkey registration and authentication, passkey MFA and passkey-primary login modes, generator opt-outs for both organizations and passkeys, updated guide set, org/passkey testing helpers, and CI/browser smoke coverage that exercises the release-gate flows.

### Key Accomplishments

1. **Generator feature system proved out** — the `core`/feature-manifest pattern shipped two real feature consumers, validating the additive generator architecture for future milestones.
2. **Organizations shipped as the v1.1 multi-tenant foundation** — scoped queries, memberships, invites, switcher UX, org settings, member management, and upgrade/backfill paths all landed with current verification.
3. **Passkeys shipped across the full stack** — data layer, challenge handling, runtime config, JS hooks, controller boundaries, example app flows, and generator opt-out coverage all landed.
4. **Audit and scope foundations were upgraded for tenant-aware future work** — real `organization_id` and `effective_user_id` columns plus scope/session hydration now support later admin and audit views cleanly.
5. **Docs and DX moved from aspirational to exercised** — guide set, upgrade runbook, org/passkey helpers, and Playwright smoke are all backed by current tests and workflow wiring.
6. **Milestone verification debt was closed before archive** — Phase 26 wrote the missing verification artifacts for Phases 18, 19, 22, and 23, bringing v1.1 to 79/79 requirements satisfied.

### Stats

- **Requirements:** 79/79 satisfied
- **Audit:** archive-ready
- **Timeline:** 2026-04-05 -> 2026-04-16
- **Git range:** `4efb4a5` -> `3fc8a6a`

### Tech Debt Carried Forward

- **`gsd-tools audit-open --json` is deprecated** for Sigra maintainers; the **supported path** is [`MAINTAINING.md`](../MAINTAINING.md) section **Planning hygiene (without gsd-tools JSON)** plus optional [`scripts/maintainers/planning-audit-hygiene.sh`](../scripts/maintainers/planning-audit-hygiene.sh).
- `Phase 999.1` Nyquist backfill remains parked.
- `Phase 999.2` Dependabot major-version cleanup remains parked.

**Archive:**
- [v1.1 Roadmap](milestones/v1.1-ROADMAP.md)
- [v1.1 Requirements](milestones/v1.1-REQUIREMENTS.md)
- [v1.1 Milestone Audit](milestones/v1.1-MILESTONE-AUDIT.md)

---

## v1.2 Admin Dashboard (Shipped: 2026-04-17)

**Scope:** 9 phases, 32 plans (Phases 27-31 plus gap-closure 32-35).

**What shipped:** A default-on, Phoenix/LiveView-first admin surface on top of v1.1: explicit host policy for platform vs organization admins, scope-safe routing and `Sigra.Admin` enforcement, searchable and filterable user operations with session revocation, time-bounded impersonation with dual-actor audit and blocked sensitive mutations, global and organization and per-user audit exploration with CSV export, automation-first verification (Playwright, smoke scripts, CI artifacts including mobile and dark checkpoints), and generator/installer parity so freshly generated hosts mount user admin LiveViews, emit impersonation and audit export controllers, ship usable admin shell navigation, and prove flows on the generated host. Shift-left CI gates (emission audit, drift guard for dead nav labels, milestone `VERIFICATION.md` presence, installer-scoped milestone audit, artifact bundle contract) reduce recurrence of the integration defects caught in the mid-milestone audit.

### Key Accomplishments

1. **Admin access foundation (Phase 27)** — Default-on `--no-admin` opt-out, library-owned admin scope resolution, plugs and LiveView `on_mount`, example and template wiring with visible global vs organization chrome.
2. **User operations (Phase 28)** — Scope-safe user index and detail, host hooks contract, session revoke-one and revoke-all with audit, responsive operator journeys; retroactively verified in `28-VERIFICATION.md` (Phase 34).
3. **Secure impersonation (Phase 29)** — Controller-owned start/stop, preserved admin session restoration, persistent banner, shared forbid plug across controllers and LiveViews, generated API-token guards.
4. **Audit exploration and export (Phase 30)** — Normalized query contract, global/org/user explorers, impersonation-aware presentation, scope-respecting CSV export endpoints.
5. **Automation-first verification (Phases 31, 34-35)** — Partitioned Playwright harness, example and generated-host specs, direct-path smoke, HTML and visual artifacts; generated-host E2E for users, impersonation, and audit export; shift-left machine gates.
6. **Installer parity and polish (Phases 32-33)** — Router injection and template emission closing INT-01..03; admin shell Users navigation and mobile bottom nav; recent audit preview aligned with `Presenter`.

### Stats

- **Requirements:** 23/23 v1.2 IDs satisfied (archived traceability in `milestones/v1.2-REQUIREMENTS.md`)
- **Milestone audit:** passed (see `milestones/v1.2-MILESTONE-AUDIT.md` front matter; body retains morning gap narrative for archaeology)
- **Timeline:** 2026-04-16 → 2026-04-17 (core delivery and gap closure)

### Tech Debt Carried Forward

- `SEED-001` human-only GA UAT items; `SEED-002` audit atomicity hybrid; backlog **999.1** / **999.2** unchanged from prior milestones.
- Residual subjective reviewer items called out in phase VERIFICATION/HUMAN-UAT docs where automation cannot fully substitute judgment.

**Archive:**

- [v1.2 Roadmap](milestones/v1.2-ROADMAP.md)
- [v1.2 Requirements](milestones/v1.2-REQUIREMENTS.md)
- [v1.2 Milestone Audit](milestones/v1.2-MILESTONE-AUDIT.md)

---

## v1.3 Cleanup & Hardening (Shipped: 2026-04-19)

**Scope:** 5 phases, 11 plans (Phases 36–40).

**What shipped:** Planning and engineering hardening without new product features: retroactive Nyquist validation inventory plus explicit waivers for historical draft validation debt (**999.1**), SHA-pinned first-party GitHub Actions upgrades with Dependabot triage notes (**999.2** / CI-01–03), a defensible GA UAT posture for **SEED-001** via shift-left automation (`docs/uat-ci-coverage.md`, Playwright `ga-uat-shift-left.spec.ts`, expanded CI gates) plus consolidated human-UAT tables and evidence scaffolding, audit-testability primitives (`Sigra.Audit.Assertions`) and an atomic audited `api.token_create` path when audit schema is configured (**SEED-002** partial), and maintainer-facing release plus planning-hygiene docs (`MAINTAINING.md`, optional `hex-publish.yml`, `scripts/maintainers/planning-audit-hygiene.sh`) superseding the broken JSON `audit-open` path.

### Key accomplishments

1. **Phase 36 — Nyquist debt made legible** — `36-INVENTORY.md`, `36-WAIVERS.md`, `verify-phase36.sh`, and traceability updates closed VAL-01–VAL-03.
2. **Phase 37 — Supply-chain hygiene** — `checkout` / `setup-node` / `upload-artifact` majors landed as SHA-pinned pins across primary workflows with recorded triage vs Dependabot.
3. **Phase 38 — GA UAT gate** — `v1.3-HUMAN-UAT.md`, versioned evidence tree, and automation-first mapping so merge-blocking CI substitutes subjective “trust me” for most SEED-001 rows.
4. **Phase 39 — Audit completeness** — Plain-function audit assertions for tests, `Ecto.Multi` + audit for API token creation, example-app smoke for login and MFA enrollment audit rows.
5. **Phase 40 — Maintainer ergonomics** — Release checklist, optional isolated Hex publish workflow pattern, and bash-first planning hygiene without unsupported JSON audit tooling.

### Stats

- **Requirements:** 13/13 v1.3 REQ IDs satisfied in archived `milestones/v1.3-REQUIREMENTS.md`
- **Milestone audit:** passed at close (see `milestones/v1.3-MILESTONE-AUDIT.md`)
- **Pre-close `audit-open`:** all artifact types clear (2026-04-19)
- **Timeline:** 2026-04-17 → 2026-04-19 (planning + execution on disk)

### Tech debt carried forward

- **SEED-002 remainder:** convert remaining hybrid `log_safe/3` sites to audited `Ecto.Multi` flows beyond `api.token_create` when subsystems grow audit-aware tests.
- **SEED-001 residuals:** real mail clients, live Google OAuth UX, clean-machine wall-clock, backup-code **rotation** proof — still human- or product-dependent until explicit features land (`mfa_regenerate_backup_codes`, etc.).
- **AUD-03 boundary:** OAuth ceremony audit assertions intentionally not claimed in v1.3.

**Archive:**

- [v1.3 Roadmap](milestones/v1.3-ROADMAP.md)
- [v1.3 Requirements](milestones/v1.3-REQUIREMENTS.md)
- [v1.3 Milestone Audit](milestones/v1.3-MILESTONE-AUDIT.md)

---

## v1.4 GA readiness & audit trail completeness (Shipped: 2026-04-22)

**Scope:** 12 phases (41–52), 38 plans.

**What shipped:** **SEED-001** closure with **TOTP-gated backup-code rotation** (`Sigra.MFA.regenerate_backup_codes/4`), example and install parity, and regression tests; a canonical **GA matrix** (`.planning/v1.4-GA-UAT.md`) with **Executed / Waived / Blocked** rows, dated evidence under `.planning/uat-evidence/v1.4/`, and machine substitutes where explicitly waived. **SEED-002** continuation: **AUD-04** inventory plus prioritized **`log_safe/3` → `Ecto.Multi`** conversions across **Auth**, **MFA**, **Account/API**, and **OAuth/ops** batches with **audit-aware** tests; formal **43/44/45 `*-VERIFICATION.md`** merge gates (**47–49**) including **`mix ci.audit_45`** and refreshed **Phase 9 C-1** matrices. **Phase 50** documented **Nyquist policy for 41–44** in **`MAINTAINING.md`**, **`mix ci.install_golden`**, and **`install_golden_contract`**. **Phase 51** widened CI path detection for installer-golden jobs and locked **GA waiver ↔ install-golden attestation** cross-links in contract tests. **Phase 52** aligned ROADMAP presentation (implementation vs verification phases) and added milestone-honesty contract coverage.

### Key accomplishments

1. **Phase 41 — GA-01 product fact** — Library backup-code rotation with optional audit on the same `Ecto.Multi`, generator/example wiring, and automated rotation regression.
2. **Phases 42 + 46 — defensible GA posture** — Matrix scaffold plus gap closure so **GA-02..GA-05** are not “silent Pending” at close.
3. **Phases 43–45 + 47–49 — audit atomicity + honest verification** — Inventory-driven batches, merge-gated verification docs, and **AUD-04..AUD-08** traceability reconciled with implementation reality.
4. **Phase 50 — Nyquist + expensive CI as policy** — Explicit batch posture for **41–44** and documented **install golden** / CI truth on `main`.
5. **Phase 51 — CI merge coupling** — Path filters and structural tests so **`install_golden_contract`** stays coupled to relevant PRs and waived GA rows point at attestations.
6. **Phase 52 — planning honesty** — ROADMAP reader clarity for **44/45 vs 48/49** and contract tests guarding milestone narrative drift.

### Stats

- **Requirements:** 10/10 GA + AUD IDs in archived `milestones/v1.4-REQUIREMENTS.md` (mix of **Complete** and **Waived** with documented substitutes).
- **Milestone audit:** early **`gaps_found`** snapshot preserved under `milestones/v1.4-MILESTONE-AUDIT.md` with an archive note; gaps were closed by phases **46–52** before ship.
- **Pre-close `audit-open`:** all artifact types clear (2026-04-22).
- **Timeline:** 2026-04-20 → 2026-04-22 (execution on disk + verification closure).

### Tech debt carried forward

- **Nyquist `nyquist_compliant: false` on 41–44** remains intentional unless policy elevates it (`MAINTAINING.md`).
- **Explicitly deferred `log_safe/3` rows** under **AUD-08** must stay listed with reopen triggers (see post-close **C-1** matrices).
- **`gsd-sdk query milestone.complete`** did not complete archival in this environment; maintainers used the same manual archive path as v1.3.

**Archive:**

- [v1.4 Roadmap](milestones/v1.4-ROADMAP.md)
- [v1.4 Requirements](milestones/v1.4-REQUIREMENTS.md)
- [v1.4 Milestone Audit](milestones/v1.4-MILESTONE-AUDIT.md)

---
