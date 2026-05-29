# Milestones

## v1.30 TRUST-HARDENING (Shipped: 2026-05-29)

**Phases completed:** 4 phases (137–140), 10 plans, all VERIFICATION = passed, all 4 phases Nyquist-compliant
**Requirements:** 11/11 satisfied (OD-01/02, DR-01/02, RCT-01, RCV-01/02, DEPR-01/02, PROOF-01, DOC-01)
**Timeline:** ~2 days (2026-05-28 → 2026-05-29) · **Changes:** 90 files, +10,991 / −63 (mostly `.planning/` docs — a deliberately low-code consolidation milestone)
**Git range:** `de3f3f8` (feat 137-01) → milestone close on `v1.28-data-lifecycle` branch
**Milestone audit:** `gaps_found` reflecting process/hygiene only — 0 unsatisfied requirements, 4/4 integration seams WIRED, 3/3 flows intact; all 4 hygiene gaps closed retroactively at this close.

**Delivered:** Turned Sigra's accumulated maturity into legible operator trust — a `Sigra.OptionalDeps` single-source-of-truth, the long-promised `mix sigra.doctor` diagnostic, merge-blocking recipe-contract fixtures, sister-repo contract verification, and deprecation-timeline hygiene — without crossing the Diminishing Returns Wall.

**Key accomplishments:**

- **Phase 137 — `Sigra.OptionalDeps` SOT (OD-01/OD-02):** one canonical module with 9 optional-dep `*_available?/0` predicates + config-driven `encryption_active?/1`; ~29 scattered `Code.ensure_loaded?` guards consolidated across 17 delegation sites with **zero runtime behavior change** (drift-catching 12-test unit suite + dep-off CI lane green; documented fences preserved).
- **Phase 138 — `mix sigra.doctor` operator diagnostic (DR-01/DR-02):** per-feature nine-feature matrix (loaded/available/configured-but-missing/missing) with actionable remediation hints, four D-09 boot-wiring hard-fail checks, and an `exit({:shutdown, 1})` CI gate; pure injectable `Sigra.Doctor` core + thin Mix-task shell, 30 tests via injection seam + CaptureIO.
- **Phase 139 — recipe-contract integrity & sister-repo verification (RCT-01/RCV-01/RCV-02):** merge-blocking ExUnit fixture asserting all six companion-lib recipes carry five required markers (+ standalone D-05 non-empty-glob guard); Lockspire `resolve_account/2` return shape and Rulestead `@behaviour Rulestead.Admin.Policy` corrected and verified against sister-repo commits (`def616d` / `0a18360`).
- **Phase 140 — deprecation hygiene + verification & docs close (DEPR-01/02, PROOF-01, DOC-01):** Hex-SemVer removal targets + migration notes for both live `@deprecated` functions (`cookie_opts/0` → 0.4.0, `audit_forced_password_change/2` → 0.5.0); eight-gate proof bundle; docs aligned (deployment operator-diagnostics + MAINTAINING `OptionalDeps`/recipe-fixture/deprecation notes).
- **Trust close:** full suite green (2296 tests, 0 failures), dep-off CI lane green, `mix docs --warnings-as-errors` clean; at milestone close all four audit hygiene gaps were closed retroactively (137-VERIFICATION filed, 138 Nyquist reconstructed, 139 Nyquist signed off, OD-01/OD-02 traceability ticked) and the WR-01 dual-version-axis deprecation wart was resolved to "accept + document".

**Known deferred items at close:** 3 (tracked tech debt — see STATE.md Deferred Items: phase-135 cross-milestone findings, the WR-01 since-vs-removal version-axis todo kept open by design, and the phase-138 IN-01/02/03 doctor findings).

---

## v1.29 SUITE-INTEGRATION (Shipped: 2026-05-29)

**Phases completed:** 6 phases (131–136), 13 plans, all VERIFICATION = passed
**Requirements:** 16/16 satisfied (TL-01..05, FB-01, RC-01..06, NX-01, EX-01, PROOF-01, DOC-01)
**Timeline:** 2 days (2026-05-27 → 2026-05-28) · **Changes:** ~110 files, +19,460 / −67 (~17k of which is recipe/narrative docs)
**Git range:** `5026262` (docs(131) context) → HEAD on `v1.28-data-lifecycle` branch

**Delivered:** Sigra now composes cleanly with the szTheory OSS suite — a first-class, optional-dep-safe Threadline audit forwarder (the milestone's only new library code), recipe coverage for the five other companion libraries, and a coherent suite-narrative entry point — without owning any sister library's roadmap.

**Key accomplishments:**

- **Threadline audit forwarder (only new library code)** — `Sigra.Audit.Forwarder` single-callback behaviour (`attach/1`) + `Sigra.Audit.Forwarders.Threadline` telemetry-tap impl + `Sigra.Audit.Forwarders.Noop` fallback + optional `Sigra.Workers.AuditForward` Oban worker. `:auto`/`:async`/`:sync` dispatch per the `Sigra.Delivery` precedent; `[:sigra,:audit,:forward,:ok|:error]` telemetry. The Sigra audit DB row stays source-of-truth; Threadline is a post-commit projection that never rolls back the originating auth transaction. Optional-dep safe (whole impl wrapped in `Code.ensure_loaded?(Threadline)`, one-shot boot `Logger.warning` when configured-but-missing). (Phase 131 — TL-01..05, FB-01)
- **Six companion-library recipes** under `guides/recipes/companion-libs/` (Threadline, Mailglass, Accrue, Lockspire, Relyra, Rulestead) on a uniform template — `validated_against:`/`last_validated:` frontmatter, `mix.exs` snippet, "Failure modes", "Non-goals", and the "Sigra works fully standalone" banner — all reachable under a new ExDoc "Companion Libraries" group. (Phases 132, 134 — RC-01..06)
- **Suite-narrative entry point** — `guides/introduction/suite-integration.md` ships the ASCII ecosystem diagram, 7-row role table, 6×5 audit fan-out matrix, and Diminishing Returns Wall framing; README Topic-map gains a pointer. No banned marketing phrases. (Phase 133 — NX-01)
- **Runnable reference demo** — `test/example/` extended with a Sigra→Threadline audit projection: dev/test dep + ordered migrations + dual `forwarders:` config + an integration test asserting a `session.create` audit event materializes as a Threadline `audit_actions` row joined on `correlation_id`, green on existing CI lanes (no new top-level `examples/`). (Phase 135 — EX-01)
- **Verification proof bundle + narrative-honesty corrigendum** — six PROOF-01 gates green on release-branch HEAD (full suite 2252 tests, audit suite, dep-off lane 2246 tests with Threadline absent, example app 236 tests, `mix docs --warnings-as-errors` exit 0); `131-VERIFICATION.md`..`136-VERIFICATION.md` filed; and the v1.25 EMAIL-RAILS Mailglass overclaim corrected across MILESTONES.md, PROJECT.md, and CHANGELOG.md (the library-resident `Sigra.Mailers.Adapters.Mailglass` module + `--with-mailglass` flag never landed; recipe-only host-owned wiring is the supported posture). (Phase 136 — PROOF-01, DOC-01)

**Post-verification fixes (quick tasks):** `260528-nwa` corrected the threadline.md `forwarders:` config drift (`endpoint:`/`api_key:` → `repo:`) and an accrue/audit-logging `log/2` API mismatch; `260528-sbn` fixed the mailglass corrigendum pointer and aligned all 7 recipe self-pins to `{:sigra, "~> 0.2"}` (IN-01).

**Known deferred items at close (non-blocking, see STATE.md Deferred Items):** 2 tracked todos (WR-02/WR-05 sister-repo contract checks; Threadline 0.6.0 migration-count deviation) + 2 standing-posture items (credo `--strict` 506 advisory issues, non-CI-enforced; retroactive Nyquist sign-off). All classified non-blocking by the passing v1.29 milestone audit.

---

## v1.28 DATA-LIFECYCLE (Shipped: 2026-05-27)

**Phases completed:** 4 phases, 6 plans, 12 tasks

**Key accomplishments:**

- Executable RED tests now pin lifecycle status, omission truth, configured-schema serialization, and credential-secret exclusion for the auth data export contract.
- Library-owned schema_version 1 auth export now derives lifecycle truth, reports optional-schema omissions, and serializes configured auth records through safe allowlists.
- Account deletion lifecycle truth is now pinned by tests for Oban enqueue shape, safe missing-context degradation, stale worker no-ops, and row-preserving soft-delete finalization.
- Generated host, example app, and install golden now expose thin Sigra-owned auth export wrappers and strategy-neutral lifecycle copy.
- Guide tests and public docs now pin Sigra-owned auth/account export boundaries, optional-schema omissions, and strategy-specific deletion outcomes.

---

## v1.27 ENT-SSO (Shipped: 2026-05-26)

**Phases completed:** 5 phases, 17 plans, 35 tasks

**Key accomplishments:**

- Added an organization-bound enterprise connection model with truthful OIDC validation and activation refusal.
- Shipped canonical org-scoped enterprise entry plus bounded exact-match domain discovery and callback revalidation.
- Landed safe JIT enterprise reconciliation on top of the existing org, membership, invitation, and identity substrate.
- Added SSO-only enforcement with explicit break-glass recovery semantics instead of hidden local-auth fallback.
- Closed the milestone with generated-host/example proof, installer parity, canonical enterprise docs, and retroactive authoritative verification for Phases 123-125.

**Stats:**

- **Requirements:** 8/8 satisfied
- **Milestone audit:** passed (`verified_and_archive_ready` on 2026-05-26)
- **Timeline:** 2026-05-25 → 2026-05-26
- **Known deferred items at close:** 6 carried forward from v1.26 (see `STATE.md` Deferred Items)

**Archive:**

- [v1.27 Roadmap](milestones/v1.27-ROADMAP.md)
- [v1.27 Requirements](milestones/v1.27-REQUIREMENTS.md)
- [v1.27 Milestone Audit](milestones/v1.27-MILESTONE-AUDIT.md)

---

## v1.26 PK-LIFECYCLE (Shipped: 2026-05-25)

**Phases completed:** 7 phases, 9 plans, 17 tasks

**Key accomplishments:**

- Introduced a library-owned final-passkey delete posture and kept generated-host copy explicit about fallback without implying Sigra-owned recovery.
- Preserved visible fallback and bootstrap guidance across passkey-primary login, signup follow-through, and passkey enrollment flows.
- Settled cross-device and RP-ID/origin migration truth across docs, runtime advisories, and generated-host copy.
- Closed the canonical generated-host/browser proof lane for the milestone's lifecycle claims.
- Backfilled authoritative `PK-02` and `PK-03` proof homes onto Phases 115 and 116, then reconciled the live truth surfaces.
- Closed the remaining Nyquist and milestone-truth debt so the v1.26 re-audit passed cleanly.

**Stats:**

- **Requirements:** 4/4 satisfied
- **Milestone audit:** passed (`verified_and_archive_ready` on 2026-05-25)
- **Timeline:** 2026-05-23 → 2026-05-25
- **Committed implementation range:** `26a5b9f` → `93d3f8d`
- **Known deferred items at close:** 6 (see `STATE.md` Deferred Items)

**Archive:**

- [v1.26 Roadmap](milestones/v1.26-ROADMAP.md)
- [v1.26 Requirements](milestones/v1.26-REQUIREMENTS.md)
- [v1.26 Milestone Audit](milestones/v1.26-MILESTONE-AUDIT.md)

---

## v1.25 EMAIL-RAILS (Shipped: 2026-05-23)

**Phases completed:** 4 phases, 8 plans, 5 tasks

**Key accomplishments:**

- Introduced an optional `Sigra.Mailers.Adapters.Mailglass` shim and `--with-mailglass` installer path without forcing Mailglass on existing adopters.
- Shipped generated-host override rails and the Mailglass preview catalog for all 18 auth email surfaces.
- Verified existing Oban-based async dispatch and provider-agnostic `[:sigra, :email, :deliver]` telemetry spans for email delivery (Zero-Code Closure).
- Added a canonical bounce/complaint normalization contract plus generated host-owned `EmailFailureHandler` seams.
- Published Postmark and SendGrid webhook recipes with example-app proof wiring.
- Mailglass adapter compilation is now optional-dependency-safe, and the nested example app can compile and prove the Phase 114 bounce/complaint recipes again.

**Corrigendum (v1.29 DOC-01, 2026-05-28):** The three bullets above that reference Mailglass are historically recorded but did not land on the release branch. Specifically: the library-resident `Sigra.Mailers.Adapters.Mailglass` module and the `--with-mailglass` installer flag described in Phase 111/114 were NOT merged to `main` and are NOT part of the supported surface. Likewise, no Mailglass preview catalog shipped in the library, and the "optional-dependency-safe" adapter compilation claim applies only to code that was never committed to `main`. The supported Mailglass posture as of v1.29 is recipe-only host-owned wiring: the host implements `Sigra.Mailer` and delegates to a Mailglass-backed module; Sigra ships no library-resident adapter and no `--with-mailglass` flag. See `guides/recipes/companion-libs/mailglass.md` for the current supported integration path.

---

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

**Backlog** (999.x parking lot; archaeology only):

- `Phase 999.1` — Retroactive Nyquist validation pass for 6 draft + 1 missing VALIDATION.md files; shipped in v1.3 and now retained as a tombstone/pointer only
- `Phase 999.2` — Dependabot major-version bumps (setup-node 4→6, upload-artifact 4→7, checkout 4→6) requiring per-bump CI verification; historical parking-lot label only until promoted into a newly numbered phase

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
- `Phase 999.1` Nyquist backfill remains archaeology-only; Phase 84 owns the routing-honesty cleanup so active workflows stop pointing at the tombstone.
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

- `SEED-001` human-only GA UAT items; `SEED-002` audit atomicity hybrid; backlog **999.1** / **999.2** remain historical parking-lot labels only.
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
- **AUD-03 boundary:** OAuth ceremony audit assertions intentionally not claimed in v1.3. **As of v1.6 (OA-01):** merge-blocking ceremony audit assertions exist; see **`docs/uat-ci-coverage.md`** for the machine vs human baseline.

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

## v1.5 Public release narrative & community readiness (Shipped: 2026-04-22)

**Scope:** 4 phases (53–56), 5 plans.

**What shipped:** **PUB-01** — `mix.exs` / Hex description and `package[:links]` aligned with shipped **v1.0–v1.4** capabilities and optional deps. **PUB-02** — `CHANGELOG.md` milestone glossary, roadmap traceability for **v1.2–v1.4**, ordered **0.1.0** sections, and Keep a Changelog compare links. **DOC-01** / **DOC-02** — README **Production readiness & GA evidence** block, new **`SECURITY.md`**, **`docs/ga-evidence.md`**, ExDoc extras, and clean `mix docs --warnings-as-errors`. **MAINT-01** — **First public launch** checklist in **`MAINTAINING.md`** with owners, tag-scoped `.planning` evidence URLs, and explicitly optional comms rows where **v1.4** waivers apply.

### Key accomplishments

1. **Phase 53 — honest Hex surface** — Core vs optional integrations reflected in public package metadata without dead claims.
2. **Phase 54 — changelog as narrative spine** — Planning milestones and SemVer releases are distinguishable; traceability blocks link roadmap archives and compare URLs.
3. **Phase 55 — OSS entry to GA evidence** — README and ExDoc give a short path to **Executed / Waived** language and **v1.4** artifacts.
4. **Phase 56 — shippable announcement runbook** — Maintainer checklist orders **tag → Hex → announce → monitor** with pointers to **install golden** and **v1.4-GA-UAT** evidence.

### Stats

- **Requirements:** 5/5 Complete in archived [`milestones/v1.5-REQUIREMENTS.md`](milestones/v1.5-REQUIREMENTS.md).
- **Milestone audit:** none filed for v1.5; closure used requirements traceability + phase summaries.
- **Pre-close `audit-open`:** all artifact types clear (2026-04-22).
- **Timeline:** 2026-04-22 (single-day milestone execution on disk).

### Tech debt carried forward

- **`gsd-sdk query milestone.complete`** returned `version required for phases archive`; archival followed the same manual path as **v1.3** / **v1.4**.

**Archive:**

- [v1.5 Roadmap](milestones/v1.5-ROADMAP.md)
- [v1.5 Requirements](milestones/v1.5-REQUIREMENTS.md)

---

## v1.6 Nyquist closure + OAuth audit depth (Shipped: 2026-04-23)

**Scope:** 3 phases (57–59), 6 plans.

**What shipped:** Maintainer-facing **41–44** Nyquist posture matrix (`.planning/nyquist-phases-41-44-matrix.md`) indexed from **`MAINTAINING.md`** with explicit per-row disposition and reopen triggers (**NYQ-01**, **NYQ-02**); **`Sigra.OAuthCeremonyAuditTest`** proving OAuth registration and `authorize_url` paths emit expected audit rows on Postgres (**OA-01**); CI contract **`phase_58_oauth_oa01_ci_contract_test`** keeping `library_tests` on plain `mix test` without OAuth-related excludes drift; **`docs/uat-ci-coverage.md`** as the OA-01/OA-02 machine-vs-human hub with GA-03 / waiver / evidence **INDEX** / **`docs/ga-evidence.md`** / **PROJECT** narrative alignment (**OA-02**). Optional **`Sigra.Planning.Phase57NyquistMatrixContractTest`** guards matrix anchors.

### Key accomplishments

1. **Phase 57 — honest Nyquist posture for 41–44** — Canonical matrix under `.planning/` plus `MAINTAINING.md` index and contract test so disposition cannot silently regress.
2. **Phase 58 — OA-01 machine proof** — Dedicated OAuth ceremony audit tests separate from rollback-only atomicity coverage; CI structure locked for merge-blocking OAuth audit work.
3. **Phase 59 — OA-02 narrative closure** — UAT coverage doc, GA evidence router, and planning surfaces consistently describe what is proven in CI vs what remains human/live-provider only.

### Stats

- **Requirements:** 4/4 Complete in archived [`milestones/v1.6-REQUIREMENTS.md`](milestones/v1.6-REQUIREMENTS.md).
- **Milestone audit:** **passed** (retroactive file: [`milestones/v1.6-MILESTONE-AUDIT.md`](milestones/v1.6-MILESTONE-AUDIT.md)); closure already used **4/4** requirements + phase summaries + pre-close **`audit-open`** all clear (2026-04-22).
- **Pre-close `audit-open`:** all artifact types clear (2026-04-22).
- **Timeline:** 2026-04-22 → 2026-04-23 (execution on disk + milestone archival).

### Tech debt carried forward

- **`gsd-sdk query milestone.complete`** returned `version required for phases archive`; archival followed the same manual path as **v1.3** / **v1.4** / **v1.5**.
- **SEED-002** breadth (`log_safe/3` → `Ecto.Multi`) remains backlog-triggered, not this milestone.

**Archive:**

- [v1.6 Roadmap](milestones/v1.6-ROADMAP.md)
- [v1.6 Requirements](milestones/v1.6-REQUIREMENTS.md)
- [v1.6 Milestone Audit](milestones/v1.6-MILESTONE-AUDIT.md)

---

## v1.7 Adoption readiness & audit durability (Shipped: 2026-04-23)

**Scope:** 3 phases (**60–62**), **3** plans with on-disk **`*-SUMMARY.md`** under **061** / **062**; **Phase 60** satisfied via shipped guides + recipe without a discrete **`060-*`** phase directory (see [`milestones/v1.7-MILESTONE-AUDIT.md`](milestones/v1.7-MILESTONE-AUDIT.md)).

**What shipped:** **ADOPT-01..03** + **INTG-01** — `guides/introduction/first-hour.md`, `upgrading-to-v1.7.md`, `troubleshooting-install.md`, and `guides/recipes/companion-oauth-provider.md` wired for ExDoc with explicit non-coupling to a companion authorization server. **AUD-01** — `verify_backup/4` wrong-code path now runs in **`Ecto.Multi`** with co-fated audit rows; **`mfa_audit_atomicity_test.exs`**; **AUD-04-067** + C-1 matrix / inventory updates (**061**). **AUD-02** — **`09-03-SUMMARY.md`** carries v1.7 document status + Phase **61** bounded-batch narrative; **D-06** required no **`09-VERIFICATION.md`** edit (**062**).

### Key accomplishments

1. **Adoption path clarity (Phase 60)** — First-hour, upgrade, troubleshooting, and companion recipe docs land without folding IdP scope into Sigra core.
2. **AUD-01 bounded SEED-002 batch (Phase 61)** — Invalid backup verification matches atomic audit semantics with merge-gated regression tests.
3. **AUD-02 C-1 honesty (Phase 62)** — Phase 9 executive summary reflects post-batch truth; requirements closed traceably.

### Stats

- **Requirements:** 6/6 Complete in archived [`milestones/v1.7-REQUIREMENTS.md`](milestones/v1.7-REQUIREMENTS.md).
- **Milestone audit:** **passed** ([`milestones/v1.7-MILESTONE-AUDIT.md`](milestones/v1.7-MILESTONE-AUDIT.md)).
- **Pre-close `audit-open`:** all artifact types clear (2026-04-23).
- **Git (since `v1.6`):** ~32 commits; **47** files touched (**1986** insertions / **82** deletions in `git diff --stat v1.6..HEAD` summary).
- **Timeline:** 2026-04-23 (single-day execution on disk for **61–62**; Phase **60** docs pre-existed the formal milestone window).

### Tech debt carried forward

- **`gsd-sdk query milestone.complete`** returned `version required for phases archive`; archival followed the same manual path as **v1.3**–**v1.6**.
- **SEED-002** remainder — further `log_safe/3` → **`Ecto.Multi`** batches remain backlog-triggered.
- **Optional:** add a retro **`060-*`** phase pack if stricter per-phase disk history is desired.

**Archive:**

- [v1.7 Roadmap](milestones/v1.7-ROADMAP.md)
- [v1.7 Requirements](milestones/v1.7-REQUIREMENTS.md)
- [v1.7 Milestone Audit](milestones/v1.7-MILESTONE-AUDIT.md)

---

## v1.8 Adopter polish (diminishing returns) (Shipped: 2026-04-23)

**Scope:** 3 phases (**63–65**), **0** on-disk plan packs — all scope satisfied via **shipped guides** + **`mix.exs`** ExDoc wiring (no discrete `.planning/phases/063-*` … `065-*` directories; see archived traceability).

**What shipped:** **ADOPT-04** — **`guides/introduction/upgrading-to-v1.8.md`** plus honest **planning v1.8** vs **Hex SemVer** framing and pointers back to **`upgrading-to-v1.7.md`**. **ADOPT-05** — cross-links among **`getting-started.md`**, **`first-hour.md`**, **`troubleshooting-install.md`**, **`CHANGELOG.md`**, and both upgrade guides. **INTG-02** — **`companion-oauth-provider.md`** prerequisite callout, explicit **B2C-only / no third-party API clients** anti-pattern line, and **See also** link to **`upgrading-to-v1.8.html`**.

### Key accomplishments

1. **Phase 63 — v1.8 upgrade spine** — Single maintainer-facing upgrade page ordered after **v1.7** in ExDoc extras.
2. **Phase 64 — navigation mesh** — First-week readers can traverse install → walkthrough → troubleshooting → upgrades without dead ends.
3. **Phase 65 — companion recipe honesty** — Prerequisites and non-goals are explicit before hosts wire **AccountResolver**.

### Stats

- **Requirements:** 3/3 Complete in archived [`milestones/v1.8-REQUIREMENTS.md`](milestones/v1.8-REQUIREMENTS.md).
- **Milestone audit:** none filed for v1.8; closure used requirements traceability + shipped docs (same posture as **v1.5**).
- **Pre-close `audit-open`:** all artifact types clear (2026-04-23).
- **Git (since `v1.7`):** ~1 commit on the measured range; **12** files touched (**147** insertions / **30** deletions in `git diff --stat v1.7..HEAD` summary).
- **Timeline:** 2026-04-23 (same-day doc closure on disk).

### Tech debt carried forward

- **`gsd-sdk query milestone.complete`** returned `version required for phases archive`; archival followed the same manual path as **v1.3**–**v1.7**.
- **No `063-*` / `064-*` / `065-*` phase directories** — optional retro packs if stricter per-phase execution history is desired.

**Archive:**

- [v1.8 Roadmap](milestones/v1.8-ROADMAP.md)
- [v1.8 Requirements](milestones/v1.8-REQUIREMENTS.md)

---

## v1.9 Audit atomicity (bounded SEED-002) (Shipped: 2026-04-23)

**Scope:** 2 phases (**66–67**), **3** on-disk plans (**066-01**, **066-02**, **067-01**) under **`.planning/phases/066-*`** / **`067-*`**.

**What shipped:** **AUD-09** — **`Sigra.MFA.confirm_enrollment/5`** **AUD-04-020..021** batch on **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** with **`mfa_audit_atomicity_test.exs`** merge-gated coverage. **AUD-10** — **`09-03-SUMMARY.md`** carries post–phase-**66** bounded-batch narrative; **D-06** reconciliation for **AUD-04-020..022** vs **44** inventory with explicit **no `09-VERIFICATION.md` edit** attestation.

### Key accomplishments

1. **Phase 66 — bounded SEED-002 batch** — Enrollment **`insert_failed`** audit path co-fated with business writes; Postgrex-aware failure handling; audit atomicity tests.
2. **Phase 67 — C-1 planning closure** — Phase **9** executive summary aligned to post-batch truth without unnecessary verification churn.

### Stats

- **Requirements:** 2/2 Complete in archived [`milestones/v1.9-REQUIREMENTS.md`](milestones/v1.9-REQUIREMENTS.md).
- **Milestone audit:** **passed** ([`milestones/v1.9-MILESTONE-AUDIT.md`](milestones/v1.9-MILESTONE-AUDIT.md)).
- **Pre-close `audit-open`:** all artifact types clear (2026-04-23).
- **Git (since `v1.8`):** ~18 commits; **27** files touched (**1616** insertions / **53** deletions in `git diff --stat v1.8..HEAD` summary).
- **Timeline:** 2026-04-23 (same-day execution on disk for **66–67**).

### Tech debt carried forward

- **`gsd-sdk query milestone.complete`** returned `version required for phases archive`; archival followed the same manual path as **v1.3**–**v1.8**.
- **SEED-002** remainder — further **`log_safe/3` → `Ecto.Multi`** batches remain backlog-triggered (see **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`**).

**Archive:**

- [v1.9 Roadmap](milestones/v1.9-ROADMAP.md)
- [v1.9 Requirements](milestones/v1.9-REQUIREMENTS.md)
- [v1.9 Milestone Audit](milestones/v1.9-MILESTONE-AUDIT.md)

---

## v1.10 Adopter confidence for solo production (Shipped: 2026-04-23)

**Scope:** 3 phases (**68–70**), **5** on-disk plans (**068-01**, **068-02**, **069-01**, **070-01**, **070-02**) under **`.planning/phases/068-*`**, **`069-*`**, **`070-*`**.

**What shipped:** **ACF-01** / **ACF-04** — production HTTPS / proxy / session checklist hub plus **Oban vs inline** mail TL;DR in **`guides/recipes/deployment.md`** with intro + maintainer cross-links and install flag anchors. **ACF-02** / **ACF-03** — **`guides/introduction/intermediate-production-path.md`** and **`guides/reference/generator-options.md`** with ExDoc **Reference** group wiring. **ACF-05** / **ACF-06** — **`guides/introduction/upgrading-to-v1.10.md`** plus explicit **ADR 001** / **SEED-002** deferrals in planning surfaces.

### Key accomplishments

1. **Phase 68 — deploy + mail confidence** — Single deployment recipe hub for session + mail semantics hosts hit in production.
2. **Phase 69 — intermediate path + optional features** — One dogfood narrative and one canonical generator flag index linked from first-week intro docs.
3. **Phase 70 — upgrade stub + non-goals** — Planning **v1.10** vs Hex framing without pretending Lockspire or full **SEED-002** shipped.

### Stats

- **Requirements:** 6/6 **Validated** in archived [`milestones/v1.10-REQUIREMENTS.md`](milestones/v1.10-REQUIREMENTS.md) (live traceability for **ACF-01** / **ACF-04** reconciled at close to match **`068-VERIFICATION.md` passed**).
- **Milestone audit:** **passed** ([`milestones/v1.10-MILESTONE-AUDIT.md`](milestones/v1.10-MILESTONE-AUDIT.md)).
- **Pre-close `audit-open`:** all artifact types clear (2026-04-23).
- **Git (since `v1.9`):** ~28 commits; **47** files touched (**2424** insertions / **35** deletions in `git diff --stat v1.9..HEAD` summary).
- **Timeline:** 2026-04-23 (same-day execution on disk for **68–70**).

### Tech debt carried forward

- **`gsd-sdk query milestone.complete`** not used; archival followed the same manual path as **v1.3**–**v1.9**.
- **SEED-002** remainder — further **`log_safe/3` → `Ecto.Multi`** batches remain backlog-triggered (see **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`**).

**Archive:**

- [v1.10 Roadmap](milestones/v1.10-ROADMAP.md)
- [v1.10 Requirements](milestones/v1.10-REQUIREMENTS.md)
- [v1.10 Milestone Audit](milestones/v1.10-MILESTONE-AUDIT.md)

---

## v1.11 Adoption stabilization (Shipped: 2026-04-23)

**Scope:** 2 phases (**71–72**), docs + planning only (no discrete **`071-*`** / **`072-*`** phase directories).

**What shipped:** **STAB-01** — **`.planning/v1.11-TRIAGE.md`** adoption triage log. **STAB-03** — **`MAINTAINING.md`** *Milestone cadence and pause* (Hex-only vs `/gsd-new-milestone`). **STAB-02** — **`guides/introduction/upgrading-to-v1.11.md`** + **`mix.exs`** ExDoc extras. **STAB-04** — **getting-started** + **upgrading-to-v1.10** cross-links.

### Stats

- **Requirements:** 4/4 **Validated** in archived [`milestones/v1.11-REQUIREMENTS.md`](milestones/v1.11-REQUIREMENTS.md).
- **Timeline:** 2026-04-23.

### Tech debt carried forward

- **SEED-002** / **SEED-001** / **Lockspire** — unchanged deferral posture (**ADR 001**, seed triggers).

**Archive:**

- [v1.11 Roadmap](milestones/v1.11-ROADMAP.md)
- [v1.11 Requirements](milestones/v1.11-REQUIREMENTS.md)

---

## v1.12 Trust, evidence, and adoption polish (Shipped: 2026-04-24)

**Scope:** 3 phases (**73–75**), **7** on-disk plans across **`.planning/phases/73-*`**, **`74-*`**, **`75-*`**.

**What shipped:** **AUD-11** — bounded **`lib/sigra/mfa.ex`** **`Multi`** + **`log_multi_safe`** with expanded **`mfa_audit_atomicity_test.exs`**. **AUD-12** / **UAT-01** / **UAT-02** — **`09-03-SUMMARY.md`**, **`.planning/v1.12-UAT-EVIDENCE.md`**, **`docs/uat-ci-coverage.md`** § v1.12 launch evidence. **TRN-01**..**TRN-03** — **`upgrading-to-v1.12.md`**, ExDoc extras, getting-started / **MAINTAINING** / **CHANGELOG** trust-bundle surfacing, **`v1.11-TRIAGE.md`** reconciliation + **`75-VERIFICATION.md`**.

### Key accomplishments

1. **Phase 73 — audit atomicity** — One more **C-1** hybrid site closed with merge-gated audit tests.
2. **Phase 74 — evidence legibility** — Single index for eight **SEED-001** rows + honest machine vs human boundaries.
3. **Phase 75 — adoption continuity** — Upgrade stub + maintainer-visible trust bundle + triage-driven doc truth.

### Stats

- **Requirements:** 7/7 **Validated** in archived [`milestones/v1.12-REQUIREMENTS.md`](milestones/v1.12-REQUIREMENTS.md).
- **Milestone audit:** not filed (optional).
- **Pre-close `audit-open`:** all artifact types clear (2026-04-24).
- **`gsd-sdk query milestone.complete`:** failed (`version required for phases archive`); archival manual (same pattern as **v1.10**–**v1.11**).
- **Git (since `v1.10` tag):** ~49 commits; **59** files (**3601** insertions / **111** deletions in `git diff --shortstat v1.10..HEAD` summary) — spans **v1.11** + **v1.12** tranches.

### Tech debt carried forward

- **SEED-002** remainder — further **`log_safe/3` → `Ecto.Multi`** batches remain backlog-triggered (see **`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`**).

**Archive:**

- [v1.12 Roadmap](milestones/v1.12-ROADMAP.md)
- [v1.12 Requirements](milestones/v1.12-REQUIREMENTS.md)

---

## v1.13 Post–v1.12 operational cadence (Shipped: 2026-04-24)

**Scope:** 1 phase (**76**), planning artifacts only (no library code tranche).

**What shipped:** **CAD-01**..**CAD-03** — **`.planning/PROJECT.md`**, **`.planning/STATE.md`**, **`.planning/ROADMAP.md`**, live **`.planning/REQUIREMENTS.md`** (now archived), and **`.planning/phases/76-post-v1-12-cadence-lock-in/*`** record the **default Hex patch cadence** and **trust-signal event** lanes for resuming full **`/gsd-new-milestone`** (**SEED-001**, **SEED-002**, adoption gap, **ADR 001**), per post–v1.12 production-confidence prioritization.

### Stats

- **Requirements:** 3/3 **Validated** in archived [`milestones/v1.13-REQUIREMENTS.md`](milestones/v1.13-REQUIREMENTS.md).
- **Timeline:** single session **2026-04-24**; **`/gsd-complete-milestone`** same day — live **`REQUIREMENTS.md`** removed.

### Tech debt carried forward

- Unchanged — **SEED-002** / **SEED-001** / **ADR 001** deferral posture (see **`MAINTAINING.md`** *Resume `/gsd-new-milestone`*).

**Archive:**

- [v1.13 Roadmap](milestones/v1.13-ROADMAP.md)
- [v1.13 Requirements](milestones/v1.13-REQUIREMENTS.md)

---

## v1.14 Bounded audit trust closure (Shipped: 2026-04-24)

**Scope:** 1 phase (**77**), library + tests + planning truth (**AUD-13**..**AUD-13-04**).

**What shipped:** **`Sigra.MFA.audit_backup_codes_regenerate/3`** and **`Sigra.MFA.audit_trust_browser/2`** now use **`commit_ad_hoc_mfa_audit/5`** — **`Repo.transaction/1`** on **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set — closing **AUD-04-033** / **AUD-04-034** from **T2** **`log_safe`** to **T1** in **`09-VERIFICATION.md`**. **`test/sigra/mfa_audit_atomicity_test.exs`** gains success, no-op, and CHECK-guard cases. **`09-03-SUMMARY.md`**, **`44-AUD-04-INVENTORY.md`** (grep + table + **EX-44-03**/**04** appendix), and **`CHANGELOG` [Unreleased]** updated. **`regenerate_backup_codes/4`** remains the authoritative backup-code rotation audit path.

### Stats

- **Requirements:** 4/4 **Validated** in archived [`milestones/v1.14-REQUIREMENTS.md`](milestones/v1.14-REQUIREMENTS.md).
- **Timeline:** **2026-04-24**; **`/gsd-complete-milestone`** same day — live **`REQUIREMENTS.md`** removed.
- **Milestone audit:** not filed (optional); pre-close **`audit-open`**: all artifact types clear (2026-04-24).
- **`gsd-sdk query milestone.complete`:** failed (`version required for phases archive`); archival manual (same pattern as **v1.12**–**v1.13**).

### Tech debt carried forward

- **SEED-002** — **Account** / **API token** / OAuth rows in **`44-AUD-04-INVENTORY.md`** and phase **45** inventory remain backlog-triggered.
- **AUD-04-022** — **`log_safe`** invalid enrollment code path unchanged (**EX-44-02**).

**Archive:**

- [v1.14 Roadmap](milestones/v1.14-ROADMAP.md)
- [v1.14 Requirements](milestones/v1.14-REQUIREMENTS.md)

---

## v1.17 Forced password change audit atomicity (Shipped: 2026-04-24)

**Scope:** 1 phase (**80**), **`Sigra.Account.clear_password_change_requirement/3`** + planning truth (**AUD-17-01**..**AUD-17-04**).

**What shipped:** **`clear_password_change_requirement/3`** co-fates **`must_change_password: false`** with **`account.password_change`** (`metadata: %{forced: true}`) via **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set; **`audit_forced_password_change/2`** **`@deprecated`**; **`test/sigra/account_audit_atomicity_test.exs`** forced-clear + CHECK rollback; **44** inventory + **09-VERIFICATION** C-1 **043** **T1** + **09-03-SUMMARY** + **`CHANGELOG` [Unreleased]**; **EX-44-05** closed.

### Key accomplishments

1. **AUD-17-01** — Forced-clear path matches atomic audit pattern used elsewhere on **Account**.
2. **AUD-17-02** — Standalone post-commit **`log_safe`** for that completion path retired (**deprecation**).
3. **AUD-17-03 / AUD-17-04** — Postgres-backed atomicity tests + planning truth aligned to **AUD-04-043**.

### Stats

- **Requirements:** 4/4 **Validated** in archived [`milestones/v1.17-REQUIREMENTS.md`](milestones/v1.17-REQUIREMENTS.md).
- **Timeline:** **2026-04-24**; **`/gsd-complete-milestone`** — live **`REQUIREMENTS.md`** removed.
- **Milestone audit:** not filed (optional); pre-close **`audit-open`**: all artifact types clear (2026-04-24).
- **`gsd-sdk query milestone.complete`:** failed (`version required for phases archive`); manual **`milestones/v1.17-*`** archival (same pattern as **v1.12**–**v1.16**).
- **Git (since `v1.16` tag):** 9 commits; **24** files (**1288** insertions / **50** deletions in `git diff --shortstat v1.16..HEAD` at close).

### Tech debt carried forward

- **SEED-002** — remaining **`log_safe/3`** clusters (**048–049**, OAuth phase **45**, etc.).
- **AUD-04-022** — **`log_safe`** invalid enrollment path unchanged (**EX-44-02**).

**Archive:**

- [v1.17 Roadmap](milestones/v1.17-ROADMAP.md)
- [v1.17 Requirements](milestones/v1.17-REQUIREMENTS.md)

---

## v1.16 API verify failure audit atomicity (Shipped: 2026-04-24)

**Scope:** 1 phase (**79**), **`Sigra.APIToken.verify/2`** failure audits + planning truth (**AUD-16-01**..**AUD-16-04**).

**What shipped:** **`api.token_verify.failure`** for invalid / revoked / expired branches uses **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set; **`log_safe_error`** telemetry on audit insert failure while callers still receive **`{:error, reason}`**; **44** + **09** + **09-03-SUMMARY** + **`CHANGELOG` [Unreleased]**; **`test/sigra/api_token_audit_atomic_test.exs`** coverage + fault injection; **EX-44-01** verify slice retired (appendix row retained).

### Key accomplishments

1. **AUD-16-01 / AUD-16-02** — **`verify/2`** failure branches match atomic audit pattern without **D-27** success-path noise.
2. **AUD-16-03** — **AUD-04-044..046** **T1** in **44** inventory + **09-VERIFICATION** C-1 matrix.
3. **AUD-16-04** — Success path remains telemetry-only.

### Stats

- **Requirements:** 4/4 **Validated** in archived [`milestones/v1.16-REQUIREMENTS.md`](milestones/v1.16-REQUIREMENTS.md).
- **Timeline:** **2026-04-24**; **`/gsd-complete-milestone`** same day — live **`REQUIREMENTS.md`** removed.
- **Milestone audit:** not filed (optional); pre-close **`audit-open`**: all artifact types clear (2026-04-24).
- **`gsd-sdk query milestone.complete`:** not relied on; manual **`milestones/v1.16-*`** archival (same pattern as **v1.12**–**v1.15**).
- **Git (since `v1.15` tag):** 1 commit; **13** files (**487** insertions / **80** deletions in `git diff --shortstat 'v1.15^{}'..HEAD` at close).

### Tech debt carried forward

- **SEED-002** — remaining **`log_safe/3`** clusters (e.g. **043**, **048–049**, OAuth phase **45**).
- **AUD-04-022** — **`log_safe`** invalid enrollment path unchanged (**EX-44-02**).

**Archive:**

- [v1.16 Roadmap](milestones/v1.16-ROADMAP.md)
- [v1.16 Requirements](milestones/v1.16-REQUIREMENTS.md)

---

## v1.15 Account + API C-1 planning truth (Shipped: 2026-04-24)

**Scope:** 1 phase (**78**), library tests + planning truth (**AUD-14**..**AUD-14-05**).

**What shipped:** **`44-AUD-04-INVENTORY.md`** rows **035–042** and **047** aligned to **`Multi` + `log_multi_safe`** in **`lib/sigra/account.ex`** and **`lib/sigra/api_token.ex`**; **`09-VERIFICATION.md`** C-1 **T1**/**T2** honesty for those rows; **`09-03-SUMMARY.md`** bounded-batch note for **phase 78** / **AUD-14**; **`CHANGELOG.md` [Unreleased]** trace bullet; **`test/sigra/account_audit_atomicity_test.exs`** **`change_password`** success + CHECK-guard rollback.

### Key accomplishments

1. **AUD-14-01 / AUD-14-02** — Inventory rows match code for **Account** paths and **`APIToken.revoke/2`**, preserving **EX-44-05** and **EX-44-01** for **044–046** at **v1.15** close (**044–046** advanced in **v1.16** / **phase 79**).
2. **AUD-14-03** — **09-VERIFICATION** Phase **44** table carries defensible **T1**/**T2** labels for **035–042**, **043**, **044–046**, **047**, **048–049**.
3. **AUD-14-04 / AUD-14-05** — Summary + changelog trace; Postgres-backed atomicity tests for **`change_password`**.

### Stats

- **Requirements:** 5/5 **Validated** in archived [`milestones/v1.15-REQUIREMENTS.md`](milestones/v1.15-REQUIREMENTS.md).
- **Timeline:** **2026-04-24**; **`/gsd-complete-milestone`** same day — live **`REQUIREMENTS.md`** removed.
- **Milestone audit:** not filed (optional); pre-close **`audit-open`**: all artifact types clear (2026-04-24).
- **`gsd-sdk query milestone.complete`:** failed (`version required for phases archive`); archival manual (same pattern as **v1.12**–**v1.14**).
- **Git (since `v1.14` tag):** ~4 commits; **13** files (**282** insertions / **72** deletions in `git diff --shortstat v1.14..HEAD` at close).

### Tech debt carried forward

- **SEED-002** — remaining **`log_safe/3`** clusters per **44** / phase **45** inventory; backlog-triggered.
- **AUD-04-022** — **`log_safe`** invalid enrollment path unchanged (**EX-44-02**).

**Archive:**

- [v1.15 Roadmap](milestones/v1.15-ROADMAP.md)
- [v1.15 Requirements](milestones/v1.15-REQUIREMENTS.md)

---

## v1.20 GA Launch (SEED closure + public release) (Shipped: 2026-04-28)

**Scope:** 6 phases (**85–90**), 14 on-disk plans. (Phase 90 waived).

**What shipped:** **AUD-21** — OAuth audit atomicity closure, converting remaining `log_safe/3` clusters in Phase 45 T2 to atomic `Repo.transaction/1` + `Ecto.Multi`. **GAUAT-01..09** — Fully automated E2E harnesses for email visual QA, OAuth real-credential cycles, MFA backup-code rotation, and getting-started proof, resulting in SEED-001 closure. **LAUNCH-01..07** — Hex v1.20.0 publish, README promotion, and CHANGELOG alignment.

### Key accomplishments

1. **AUD-21 closure** — Phase 9 C-1 caveat officially downgraded to PASS.
2. **GAUAT zero-human proof** — Replaced all manual SEED-001 testing requirements with deterministic CI automation (Playwright + Premailex).
3. **v1.20.0 Public Launch** — Reached the "use this in production" inflexion point.

### Stats

- **Requirements:** 21/21 requirements satisfied/waived.
- **Milestone audit:** **passed** ([`milestones/v1.20-MILESTONE-AUDIT.md`](milestones/v1.20-MILESTONE-AUDIT.md)).
- **Timeline:** 2026-04-25 → 2026-04-28.

### Tech debt carried forward

- Lockspire glue package deferred.
- Week-one launch-feedback follow-ups deferred to patch milestone.

**Archive:**

- [v1.20 Roadmap](milestones/v1.20-ROADMAP.md)
- [v1.20 Requirements](milestones/v1.20-REQUIREMENTS.md)
- [v1.20 Milestone Audit](milestones/v1.20-MILESTONE-AUDIT.md)

---

## v1.21 B2B-ready & production-honest (Shipped: 2026-05-06)

**Scope:** 6 phases (**91–96**), 33 on-disk plan summaries (across 26 PLAN.md files; some phases inline-summarized).

**What shipped:** First milestone after v1.20 public launch. Three legs converged. **Leg 1 — B2B trust** (Phases **91**, **92**, **93**) — `Sigra.Plug.RequireOrgMfa` + `enforce_mfa_for_members` + admin LiveView toggle + atomic `organization.mfa_policy_change` audit row (**B2B-01**); `Sigra.Authz` `can?/3` behaviour + nullable `role` on `OrganizationMembership` + scope-struct `:role` propagation + role-based-access-control recipe (zero opinionated roles in `lib/sigra/`) (**B2B-02**); org-scoped service-account tokens via `client_credentials` grant on existing JWT path + `current_scope.actor_type: :service_account` discriminator + 5 SA-mutation rollback proofs (**B2B-03**, re-verified 22/22 after gap-closure plans 06–10 + critical fixes in commit `bf5a8a8`). **Leg 2 — Production hardening** (Phases **94**, **95**) — `mix sigra.install` refuses non-Postgres adapter at pre-flight + removed MySQL/SQLite placeholder branches + aligned `mix.exs` description / README / getting-started narrative; environmental Oban-test caveat closed in 2026-05-06 audit (**HARD-01**); `Sigra.OptionalDeps` SOT + raise-on-missing for Oban/Bcrypt/EQRCode + `mix sigra.doctor` per-feature dep matrix + 3 dep-off CI lanes (**HARD-02**, only v1.21 phase with `nyquist_compliant: true`). **Leg 3 — OAuth + API polish** (Phase **96**) — per-provider OAuth refresh dispatch for GitHub/Apple/Facebook/Generic via Assent + atomic `oauth.token_refreshed` audit (**HARD-03**); single-pass `Sigra.Plug.RateLimit` emitting `X-RateLimit-Limit/Remaining/Reset` + `Retry-After` from Hammer state, wired into generated host's `:auth_rate_limit` pipeline (**API-01**) — 122 passing tests across 4 evidence sections.

### Key accomplishments

1. **Org-level MFA enforcement** — Atomic policy-change audit + plug + LiveView gate; full library suite green (33 doctests, 3 properties, 2214 tests, 0 failures).
2. **RBAC seams without opinions** — `Sigra.Authz` ships as behaviour-only; library has zero `:owner / :admin / :member` constants; recipe is the only place those names appear, illustratively.
3. **M2M service-account tokens** — `client_credentials` grant on existing JWT path; scope-struct `actor_type` discriminator; SA short-circuits user-membership and org-MFA checks; 5/5 mutations co-fated with audit (D-AUD-08).
4. **Honest Postgres-only narrative** — Aligned the documented adapter support to what CI actually exercises and what migrations actually implement.
5. **Optional-dep boot validation** — `mix sigra.doctor` reports per-feature status; missing optional deps raise tagged errors at first use instead of compiling to silent `nil`; CI matrix toggles each off.
6. **OAuth refresh dispatch + rate-limit headers** — Closed the `lib/sigra/oauth.ex:174` "not yet implemented" warning across 4 providers with atomic audit; clients on rate-limited paths get standards-compliant headers for backoff.

### Stats

- **Requirements:** 7/7 requirements satisfied (B2B-01, B2B-02, B2B-03, HARD-01, HARD-02, HARD-03, API-01).
- **Milestone audit:** **tech_debt → reconciled** ([`milestones/v1.21-MILESTONE-AUDIT.md`](milestones/v1.21-MILESTONE-AUDIT.md)). Substantive 7/7 with passing test evidence; bookkeeping reconciled 2026-05-06.
- **Timeline:** 2026-04-28 → 2026-05-06 (8 days).
- **Cross-phase wires verified:** B2B-02 `:actor_type` reservation → B2B-03 `:service_account` population; B2B-02 host-supplied `:roles` → B2B-03 SA short-circuit; HARD-01 Postgres-only → HARD-02 `mix sigra.doctor`; HARD-03 OAuth refresh → API-01 rate-limit headers.

### Known deferred items at close (non-blocking)

- 2 install-smoke pending todos from 2026-04-30: JOSE.JWT.peek_payload/1 undefined warning + transient Postgres `too_many_connections` during install smoke (both surfaced during Phase 94 work).
- `DEF-92-02-01` — InvitationAcceptLive audit-Multi-step name collision (pre-existing bug from commit `5e6c026`, predates Phase 92; recommended landing point not yet assigned).
- Nyquist VALIDATION.md gaps — only Phase 95 has `nyquist_compliant: true`; 91/92/93 have draft VALIDATION.md (`nyquist_compliant: false`); 94/96 missing entirely. Optional retroactive fill via `/gsd-validate-phase`.

### Tech debt carried forward

- Webhooks (`WH-01..03`) — deferred to v1.22 as its own design-first milestone (event schema, signed delivery, retry/dead-letter, host UX).
- Tier-3 polish carried in Future Requirements: Session UX (`SESS-01..03`), Email overrides + i18n + bounce (`EMAIL-01..03`), Passkey multi-authenticator + recovery (`PK-01..03`), DataExport depth (`DATA-01..03`).
- `sigra_lockspire` glue package per **ADR 001** — still awaiting companion-app trigger.

**Archive:**

- [v1.21 Roadmap](milestones/v1.21-ROADMAP.md)
- [v1.21 Requirements](milestones/v1.21-REQUIREMENTS.md)
- [v1.21 Milestone Audit](milestones/v1.21-MILESTONE-AUDIT.md)

---

## v1.22 Webhooks / outbound event pipeline (Shipped: 2026-05-06)

**Scope:** 6 phases (**97–102**), 20 on-disk plans.

**What shipped:** Sigra now emits real outbound auth and identity webhooks as a first-party product surface. **Phase 97** established the event contract, durable subscription registry, stable payload envelope, and HMAC signing contract. **Phase 98** added persisted attempts, bounded retries, and dead-letter state so delivery reliability no longer depends on raw Oban semantics. **Phase 99** exposed the capability through generated admin LiveViews, routes, and adopter-facing guidance. After the first milestone audit found end-to-end gaps, **Phase 100** restored the production enqueue handoff from persisted delivery rows into the async worker path, **Phase 101** corrected operator-state query truth for retrying and dead-lettered views, and **Phase 102** proved the generated-host flow end to end while reconciling roadmap, requirements, state, and verification artifacts.

### Key accomplishments

1. **Stable webhook contract** — durable subscription registry, canonical event catalog, public payload serializers, and documented HMAC verification contract for Sigra-owned auth and identity events.
2. **Reliable delivery pipeline** — persisted summary rows, append-only attempt history, bounded retries, and durable dead-letter state.
3. **Generated-host operator UX** — admin LiveViews for subscription management, delivery history, failure inspection, and secret rotation.
4. **Production handoff repaired** — persisted delivery rows now enqueue the first worker job automatically from the mutation path instead of stalling before async dispatch.
5. **Operator truth restored** — retrying and dead-lettered views now match persisted delivery state before pagination.
6. **Adopter proof closed** — generated-host evidence correlates receiver-side verification with admin-visible delivery history and reconciled planning artifacts.

### Stats

- **Requirements:** 3/3 requirements satisfied (`WH-01..03`).
- **Milestone audit:** historical `gaps_found` audit preserved and superseded by [`102-VERIFICATION.md`](phases/102-generated-host-proof-and-planning-reconciliation/102-VERIFICATION.md) after Phases 100–102 closed the listed gaps.
- **Pre-close `audit-open`:** all artifact types clear on 2026-05-07 after resolving quick-task metadata drift and the two install-smoke todos.
- **Git (milestone range):** first milestone commit `6b8ef36` on 2026-05-06; current diff vs that start point is `43` files changed, `5833` insertions, `32` deletions.

### Tech debt carried forward

- Webhook follow-ons remain future work only: replay support, safer secret-rotation windows, and tighter outbound egress controls (`WH-04..06`).
- Tier-3 polish stays deferred: session UX completeness, email overrides + i18n + bounce handling, passkey multi-authenticator + recovery, and DataExport depth.
- `sigra_lockspire` glue package per **ADR 001** remains trigger-based.
- Nyquist VALIDATION.md coverage remains thin for earlier B2B phases; not part of the webhook milestone contract.

**Archive:**

- [v1.22 Roadmap](milestones/v1.22-ROADMAP.md)
- [v1.22 Requirements](milestones/v1.22-REQUIREMENTS.md)
- [v1.22 Milestone Audit](milestones/v1.22-MILESTONE-AUDIT.md)

---

## v1.23 Webhook operator trust & controls (Shipped: 2026-05-08)

**Scope:** 5 phases (**103–107**), 16 on-disk plans.

**What shipped:** v1.23 closes the three operational trust gaps left after the outbound webhook pipeline launch. **Phase 103** replaced one-shot signing-secret rotation with a dual-slot lifecycle, overlap-window signatures, truthful admin controls, and generated-host proof (**WH-04**). **Phase 104** implemented replay as a new delivery lineage with durable parent/root pointers, admin recovery actions, LiveView lineage truth, and generated-host proof; **Phase 106** then turned that evidence into authoritative milestone verification via `104-VERIFICATION.md` (**WH-05**). **Phase 105** implemented enforceable endpoint policy, generated-host policy seams, and deployment guidance; **Phase 107** finished the blocked-policy admin truth, denied-path browser proof, and repaired-form `105-VERIFICATION.md` / `105-VALIDATION.md` closeout (**WH-06**).

### Key accomplishments

1. **Overlap-safe secret rotation** — webhook subscriptions can carry current and next secrets through a bounded overlap window without delivery loss or replay-contract drift.
2. **Replay as truthful recovery** — operators can replay dead-lettered deliveries as fresh child rows with new `delivery_id` values while preserving the original failed history and attempt ledger.
3. **Enforceable outbound policy** — Sigra can deny disallowed webhook destinations locally before egress and preserve canonical `policy_reason` / `policy_detail` truth across worker, admin, and proof surfaces.
4. **Generated-host evidence is now adopter-grade** — rotation lifecycle, replay recovery, and blocked-policy operator inspection all have durable `.planning/uat-evidence/v1.23/*` bundles.
5. **Milestone audit closed cleanly** — `WH-04..06` are all satisfied, `104-VERIFICATION.md` and `105-VERIFICATION.md` exist, and the live v1.23 audit now passes.

### Stats

- **Requirements:** 3/3 requirements satisfied (`WH-04`, `WH-05`, `WH-06`).
- **Milestone audit:** passed at close ([`milestones/v1.23-MILESTONE-AUDIT.md`](milestones/v1.23-MILESTONE-AUDIT.md)).
- **Pre-close `audit-open`:** all artifact types clear (2026-05-08).
- **Timeline:** 2026-05-07 → 2026-05-08.
- **Worktree delta from milestone start commit `200e131`:** 63 tracked files changed, 6131 insertions, 557 deletions.

### Known deferred items at close

- `REL-01` release-cut work is intentionally deferred to the next milestone now that webhook operator trust is closed honestly.
- Tier-3 follow-ons remain future work only: session UX, email overrides and i18n, passkey polish, and data-export depth.
- `sigra_lockspire` glue package per **ADR 001** remains trigger-based and out of scope for this milestone.

### Technical debt carried forward

- The repository was still on a dirty worktree at milestone close, so the planning archive is complete but the git closeout commit and release tag must be cut only after the shipped code and docs land in clean commits.

**Archive:**

- [v1.23 Roadmap](milestones/v1.23-ROADMAP.md)
- [v1.23 Requirements](milestones/v1.23-REQUIREMENTS.md)
- [v1.23 Milestone Audit](milestones/v1.23-MILESTONE-AUDIT.md)

---

## v1.24 Session Control Plane (Shipped: 2026-05-08)

**Scope:** 3 phases (**108–110**), 9 on-disk plans.

**What shipped:** v1.24 turned Sigra's session and audit substrate into a coherent account-security control plane. **Phase 108** shipped preserve-current revoke semantics, truthful current-session labeling, and aligned user/admin/docs behavior for session truth (**SESS-02**, first `SESS-04/05` slice). **Phase 109** shipped the library-owned recent-security-activity seam plus explicit logout/MFA activity truth across generated-host, admin, and docs surfaces (**SESS-03**, remaining `SESS-04/05`). **Phase 110** converted the implementation summary chain into authoritative `108-VERIFICATION.md` and `109-VERIFICATION.md` artifacts, then reconciled the active milestone truth across planning files and the live audit.

### Key accomplishments

1. **Preserve-current revoke is now first-class** — users can revoke sibling sessions without losing the current device, and the operation fails closed if the preserved session cannot be proven.
2. **Current-session truth is authoritative** — user and admin surfaces derive the current session from persisted/session-token truth rather than LiveView heuristics or raw-token comparisons.
3. **Recent security activity is now Sigra-owned** — sign-in, suspicious-login, logout, revoke, and MFA verification render through a canonical library seam over persisted audit rows.
4. **Thin-host boundaries held** — generated hosts delegate session-control and activity logic to Sigra-owned seams instead of reimplementing business rules.
5. **Milestone proof is repaired and archive-ready** — `108-VERIFICATION.md`, `109-VERIFICATION.md`, and `v1.24-MILESTONE-AUDIT.md` now provide a coherent authoritative closeout surface.

### Stats

- **Requirements:** 4/4 requirements satisfied (`SESS-02`, `SESS-03`, `SESS-04`, `SESS-05`).
- **Milestone audit:** passed at close ([`milestones/v1.24-MILESTONE-AUDIT.md`](milestones/v1.24-MILESTONE-AUDIT.md)).
- **Pre-close `audit-open`:** all artifact types clear (2026-05-08).
- **Timeline:** 2026-05-08.
- **Scoped worktree delta at close:** 17 files changed, 1355 insertions, 243 deletions across the tracked session-control implementation and planning surfaces.

### Known deferred items at close

- `EMAIL-RAILS` is now the default next milestone candidate; it was intentionally not pulled into the v1.24 scope.
- `PK-LIFECYCLE` and `DATA-LIFECYCLE` remain ranked follow-ons, not hidden v1.24 gaps.
- Historical Nyquist coverage thin spots from older milestones remain non-blocking carried debt, not session-control misses.

### Technical debt carried forward

- The repository is still on a dirty worktree at milestone close. The planning archive can be committed selectively, but a release-accurate `v1.24` git tag must wait until the shipped implementation and proof changes are committed cleanly.

**Archive:**

- [v1.24 Roadmap](milestones/v1.24-ROADMAP.md)
- [v1.24 Requirements](milestones/v1.24-REQUIREMENTS.md)
- [v1.24 Milestone Audit](milestones/v1.24-MILESTONE-AUDIT.md)

---
