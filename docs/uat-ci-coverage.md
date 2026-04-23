# GA UAT — CI vs human coverage (SEED-001 shift-left)

This document maps the eight **SEED-001** human GA items to **merge-blocking CI** substitutes, **library/integration tests**, and **residual** risk that still needs occasional human or vendor-assisted verification.

| SEED | Topic | CI / automated substitute | Residual (not replaced by CI) |
|------|--------|----------------------------|-------------------------------|
| **1** | Lockout + suspicious-login email HTML | `Example.Accounts.EmailsSecurityHtmlTest` — structure, CTAs, IP/device copy | Gmail / Outlook / Apple Mail rendering, dark mode, clipping |
| **2** | Seven account-lifecycle templates | `Example.Accounts.EmailsLifecycleHtmlTest` — headings, CTAs, security footer strings | Same as SEED-1 in real clients |
| **3** | `mix sigra.gen.oauth` greenfield | **`install_smoke` CI job** → `scripts/ci/install-smoke.sh` (`mix phx.new` + `mix sigra.install` + `mix sigra.gen.oauth`, path + migration + router checks) | Subjective “reads well” in generated files; major Phoenix generator churn |
| **4** | Google OAuth E2E | **`Sigra.OAuthTest`** (+ related) — `MockStrategy` round-trip: authorize URL, HMAC state, `handle_callback/4` without HTTP; see **§ OA-01 / OA-02 — `library_tests` + `oauth_ceremony` machine baseline** for the OA-01 audit persistence story. | Google consent UX, token refresh against live Google |
| **5** | Provider linking / last-method unlink | **`Sigra.OAuth.OAuthSettingsTemplateContractTest`** — template strings for D-03 last-provider + “Set a password first” | Live tooltip timing, exact disabled-button styling in host CSS |
| **6** | Email-match confirmation / invitation lock | **`ga-uat-shift-left.spec.ts`** — invitation signup path: tamper locked email → server-side `email_mismatch` form error | Other email-match surfaces (non-invitation) if added later |
| **7** | Backup code regenerate wiring | **`example_unit_smoke`** (`ci.yml`) runs `mix test --include example_app`, including **`test/example/test/example_web/smoke/backup_code_rotation_test.exs`** — proves old backup plaintext fails after `Accounts.mfa_regenerate_backup_codes/3` with a valid TOTP. **`ga-uat-shift-left.spec.ts`** (same workflow’s Playwright job) covers MFA settings UX shell only. | Live browser timing, copy tweaks |
| **8** | Clean-machine getting started | **`scripts/ci/getting-started-contract.sh`** — internal doc links + required command strings | Wall-clock “&lt; 30 min” for unfamiliar human; prose friction |

## OA-01 / OA-02 — `library_tests` + `oauth_ceremony` machine baseline

This subsection is the **grep-friendly** hub for **OA-01** (merge-blocking ceremony audit assertions) and **OA-02** (how we describe machine vs human coverage). It complements the SEED table row **SEED-4** and the **GA-03** bullet under **v1.4 GA** — those stay scannable; depth lives here.

### Machine (merge-blocking)

- **`Sigra.OAuthCeremonyAuditTest`** (`test/sigra/oauth/oauth_ceremony_audit_test.exs`) proves persisted `audit_events` for **`oauth.register_via_oauth`** (registration ceremony) and **`oauth.authorize`** on the successful **`Sigra.OAuth.authorize_url/3`** path, using **Postgres + Sandbox**, an in-process mock strategy, and **no live IdP HTTP**.
- **`Sigra.Planning.Phase58OauthOa01CiContractTest`** (`test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs`) is a **structural** CI gate: the **`library_tests`** GitHub Actions job runs plain `mix test` and asserts the OA-01 modules stay wired into CI — it does **not** replace the integration assertions in the audit test.
- **`Sigra.OAuthTest`** (`test/sigra/oauth/oauth_test.exs`) covers the authorize/callback **contract** with Assent-shaped mock behavior (complement to the audit persistence proof above, not a duplicate).

Discoverability: see **`.github/workflows/ci.yml`** job **`library_tests`** (“Run library tests”).

### Human / live-provider residual

- **Live Google** (consent UX, refresh flows, tenant-specific policy) is **not** asserted by the modules above.
- Anything outside those named contracts remains occasional human or vendor-assisted verification.
- Machine proofs above are **scoped** to the named tests; IdP-specific end-to-end behavior is **not** exhaustively automated in CI.

## v1.4 GA (GA-02..GA-05)

Human vs machine boundaries for **v1.4** are recorded in **`.planning/v1.4-GA-UAT.md`** (canonical **Executed / Waived / Blocked** table). This section **cross-links** that matrix only — it does **not** replace the SEED-1..8 table above or duplicate merge-blocking job lists.

- **GA-01 (pointer):** Product proof lives in Phase 41 + **`example_unit_smoke`**; see `.planning/uat-evidence/v1.4/GA-01-pointer/README.md` and the GA-01 row in `.planning/v1.4-GA-UAT.md` — **no rotation re-run** in Phase 42.
- **GA-02:** Human = real MUAs when templates change; machine = **`library_tests`** / example HTML tests (`EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`) + **`example_unit_smoke`** per SEED-1/2.
- **GA-03:** Human = live Google OAuth; machine = **`Sigra.OAuthTest`** + **`MockStrategy`** contract path (SEED-4) **and** **`Sigra.OAuthCeremonyAuditTest`** for persisted audit rows — see **§ OA-01 / OA-02 — `library_tests` + `oauth_ceremony` machine baseline** (subsection owns depth).
- **GA-04:** Human = witnessed `guides/introduction/getting-started.md` run; machine = **`getting_started_uat_contract`** + `scripts/ci/getting-started-contract.sh` (SEED-8).
- **GA-05:** Consolidated matrix ownership — links **`.planning/v1.4-GA-UAT.md`** here and defers full CI graph to this file’s SEED rows.

## Where to run this

- **GitHub Actions:** `.github/workflows/ci.yml` — jobs `library_tests`, `example_unit_smoke`, `example_playwright_smoke` (includes `ga-uat-shift-left.spec.ts`), `install_smoke`, `getting_started_uat_contract`.
- **Installer golden / idempotency contract:** locally run **`mix ci.install_golden`** (see [`MAINTAINING.md`](../MAINTAINING.md)); CI mirrors it with job **`install_golden_contract`** in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) (path-filtered on PRs, always on `main` pushes).
- **Local:** same as CI: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost` for Elixir tests; Playwright from `test/example/priv/playwright` with example app on port 4000.

## Policy

- **Merge-blocking:** Rows SEED-1–2, 3, 4, 5, 6, 7 (example smoke + Playwright UX), and 8 (doc contract) are considered **machine-closed** for GA posture when the jobs above are green.
- **Residual:** Real mail clients and live Google OAuth remain **optional** pre-announcement spot checks; track separately (e.g. quarterly) if desired.
