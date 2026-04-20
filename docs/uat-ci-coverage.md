# GA UAT — CI vs human coverage (SEED-001 shift-left)

This document maps the eight **SEED-001** human GA items to **merge-blocking CI** substitutes, **library/integration tests**, and **residual** risk that still needs occasional human or vendor-assisted verification.

| SEED | Topic | CI / automated substitute | Residual (not replaced by CI) |
|------|--------|----------------------------|-------------------------------|
| **1** | Lockout + suspicious-login email HTML | `Example.Accounts.EmailsSecurityHtmlTest` — structure, CTAs, IP/device copy | Gmail / Outlook / Apple Mail rendering, dark mode, clipping |
| **2** | Seven account-lifecycle templates | `Example.Accounts.EmailsLifecycleHtmlTest` — headings, CTAs, security footer strings | Same as SEED-1 in real clients |
| **3** | `mix sigra.gen.oauth` greenfield | **`install_smoke` CI job** → `scripts/ci/install-smoke.sh` (`mix phx.new` + `mix sigra.install` + `mix sigra.gen.oauth`, path + migration + router checks) | Subjective “reads well” in generated files; major Phoenix generator churn |
| **4** | Google OAuth E2E | **`Sigra.OAuthTest`** (+ related) — `MockStrategy` round-trip: authorize URL, HMAC state, `handle_callback/4` without HTTP | Google consent UX, token refresh against live Google |
| **5** | Provider linking / last-method unlink | **`Sigra.OAuth.OAuthSettingsTemplateContractTest`** — template strings for D-03 last-provider + “Set a password first” | Live tooltip timing, exact disabled-button styling in host CSS |
| **6** | Email-match confirmation / invitation lock | **`ga-uat-shift-left.spec.ts`** — invitation signup path: tamper locked email → server-side `email_mismatch` form error | Other email-match surfaces (non-invitation) if added later |
| **7** | Backup code regenerate wiring | **`example_unit_smoke`** (`ci.yml`) runs `mix test --include example_app`, including **`test/example/test/example_web/smoke/backup_code_rotation_test.exs`** — proves old backup plaintext fails after `Accounts.mfa_regenerate_backup_codes/3` with a valid TOTP. **`ga-uat-shift-left.spec.ts`** (same workflow’s Playwright job) covers MFA settings UX shell only. | Live browser timing, copy tweaks |
| **8** | Clean-machine getting started | **`scripts/ci/getting-started-contract.sh`** — internal doc links + required command strings | Wall-clock “&lt; 30 min” for unfamiliar human; prose friction |

## v1.4 GA (GA-02..GA-05)

Human vs machine boundaries for **v1.4** are recorded in **`.planning/v1.4-GA-UAT.md`** (canonical **Executed / Waived / Blocked** table). This section **cross-links** that matrix only — it does **not** replace the SEED-1..8 table above or duplicate merge-blocking job lists.

- **GA-01 (pointer):** Product proof lives in Phase 41 + **`example_unit_smoke`**; see `.planning/uat-evidence/v1.4/GA-01-pointer/README.md` and the GA-01 row in `.planning/v1.4-GA-UAT.md` — **no rotation re-run** in Phase 42.
- **GA-02:** Human = real MUAs when templates change; machine = **`library_tests`** / example HTML tests (`EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`) + **`example_unit_smoke`** per SEED-1/2.
- **GA-03:** Human = live Google OAuth; machine = **`Sigra.OAuthTest`** + **`MockStrategy`** contract path (SEED-4).
- **GA-04:** Human = witnessed `guides/introduction/getting-started.md` run; machine = **`getting_started_uat_contract`** + `scripts/ci/getting-started-contract.sh` (SEED-8).
- **GA-05:** Consolidated matrix ownership — links **`.planning/v1.4-GA-UAT.md`** here and defers full CI graph to this file’s SEED rows.

## Where to run this

- **GitHub Actions:** `.github/workflows/ci.yml` — jobs `library_tests`, `example_unit_smoke`, `example_playwright_smoke` (includes `ga-uat-shift-left.spec.ts`), `install_smoke`, `getting_started_uat_contract`.
- **Local:** same as CI: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost` for Elixir tests; Playwright from `test/example/priv/playwright` with example app on port 4000.

## Policy

- **Merge-blocking:** Rows SEED-1–2, 3, 4, 5, 6, 7 (example smoke + Playwright UX), and 8 (doc contract) are considered **machine-closed** for GA posture when the jobs above are green.
- **Residual:** Real mail clients and live Google OAuth remain **optional** pre-announcement spot checks; track separately (e.g. quarterly) if desired.
