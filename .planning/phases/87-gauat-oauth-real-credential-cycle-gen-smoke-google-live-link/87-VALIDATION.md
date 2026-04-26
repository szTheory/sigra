---
phase: 87
slug: gauat-oauth-real-credential-cycle-gen-smoke-google-live-link
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-26
---

# Phase 87 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Detailed Nyquist coverage matrix lives in `87-RESEARCH.md` `## Validation Architecture`. This file is the planner-facing contract.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit 1.18 (Elixir) + Playwright 1.x (TypeScript) |
| **Config file** | `mix.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/testing/oauth_issuer_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && (cd test/example/priv/playwright && npx playwright test oauth-)` |
| **Estimated runtime** | ~30s lib tests, ~90s Playwright OAuth specs (3 specs, serial), ~3min install-smoke (cold), ~105s install-smoke (warm) |

---

## Sampling Rate

- **After every task commit:** Run `mix test path/to/affected_test.exs` (per-file)
- **After every plan wave:** Run full Elixir suite + relevant Playwright specs
- **Before `/gsd-verify-work`:** All four CI lanes green at SHA — `mix test`, `install_smoke` (extended with `mix test` step), `oauth_e2e_playwright` (new job), evidence dir filings present
- **Max feedback latency:** 90s for Playwright lane; 30s for Elixir lane; 3min for install-smoke

---

## Per-Task Verification Map

> Final per-task rows are filled in by the planner. The matrix below is the seed by capability area; the planner expands to one row per task in PLAN.md files.

| Capability | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|------------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| Sigra.Testing.OAuthIssuer (issuer module) | 01 | 1 | GAUAT-04/05/06 | — | RS256-signed ID token verifies; PKCE rejects bad verifier; multi-key JWKS; `email_verified` boolean | unit | `mix test test/sigra/testing/oauth_issuer_test.exs` | ❌ W0 | ⬜ pending |
| `mix sigra.oauth.smoketest` task | 01 | 1 | (D-87-03) | — | Exits 0 on valid Google config; non-zero with diagnostic on failure | unit | `mix test test/sigra/install/oauth_smoketest_task_test.exs` | ❌ W0 | ⬜ pending |
| `oauth_controller.ex` integration extension (state mismatch / provider error / no-email) | 01 | 1 | GAUAT-04, GAUAT-06 | — | Controller surfaces provider-error flash; rejects state mismatch; flash text matches `oauth_controller.ex:96` verbatim | integration | `mix test test/example/test/example_web/oauth_controller_test.exs` | ❌ W0 | ⬜ pending |
| install-smoke.sh extension (mix test + 12/12 log + transcript tee) | 01 | 1 | GAUAT-03 | — | Fresh-host gen → compile (warnings-as-errors) → ecto setup → `mix test` green; transcript at `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` | smoke | `bash scripts/ci/install-smoke.sh` | ❌ W0 | ⬜ pending |
| `oauth-register.spec.ts` (Playwright) | 01 | 1 | GAUAT-04 | — | Provider button → mock issuer → callback → user+identity row → session → logout → re-login (no new identity) | E2E | `cd test/example/priv/playwright && npx playwright test oauth-register.spec.ts` | ❌ W0 | ⬜ pending |
| `oauth-link.spec.ts` (Playwright; 4 visual states + 1 hero PNG) | 01 | 1 | GAUAT-05 | — | linked/disabled-tooltip/after-set-password/post-unlink; tooltip string matches `oauth_settings_live.ex:92` verbatim | E2E | `cd test/example/priv/playwright && npx playwright test oauth-link.spec.ts` | ❌ W0 | ⬜ pending |
| `oauth-email-match.spec.ts` (Playwright) | 01 | 1 | GAUAT-06 | — | Flash text verbatim from `oauth_controller.ex:96`; redirect destination; identity row created; `provider_linked_email` arrives in mailbox | E2E | `cd test/example/priv/playwright && npx playwright test oauth-email-match.spec.ts` | ❌ W0 | ⬜ pending |
| `oauthIssuer.ts` Playwright fixture | 01 | 1 | GAUAT-04/05/06 | — | `setupIssuer/resetIssuer/probeIdentities` shape mirrors `mailbox.ts`; injects via test-only HTTP endpoint | integration | (covered transitively by 3 OAuth specs) | ❌ W0 | ⬜ pending |
| Test-only DB probe / OAuth-issuer-setup endpoint | 01 | 1 | GAUAT-04/05/06 | — | Mounted only when `EXAMPLE_DB_PROBE_ENABLED=1` (or `Mix.env() == :test`); rejects all other access | integration | `mix test test/example/test/example_web/test_endpoints_test.exs` | ❌ W0 | ⬜ pending |
| `docs/oauth-google-setup.md` adopter recipe | 01 | 1 | (D-87-03 paired) | — | Numbered Google Cloud Console recipe + ENV var names + `mix sigra.oauth.smoketest` invocation | docs | `test -f docs/oauth-google-setup.md && grep -q "mix sigra.oauth.smoketest" docs/oauth-google-setup.md` | ❌ W0 | ⬜ pending |
| `mix.exs` test_server dev/test dep | 01 | 1 | (D-87-02) | — | `:test_server, "~> 0.1.22", only: [:dev, :test]` (or only :test); compiles | build | `mix deps.get && mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| `.github/workflows/ci.yml` install_smoke transcript upload | 01 | 1 | GAUAT-03 | — | `actions/upload-artifact@v4` with transcript path; release-asset promotion on `v*` tags | CI-meta | (verified by green CI run with artifact present) | ❌ W0 | ⬜ pending |
| `.github/workflows/ci.yml` new `oauth_e2e_playwright` job | 01 | 1 | GAUAT-04/05/06 | — | Runs the 3 OAuth specs against Sigra.Testing.OAuthIssuer; uploads Playwright trace.zip on failure | CI-meta | (verified by green CI run) | ❌ W0 | ⬜ pending |
| `.planning/uat-evidence/v1.20/oauth-gen/` (README + manifest + transcript + artifact-inventory) | 02 | 2 | GAUAT-03 | — | Phase 86 schema verbatim; 9-field YAML frontmatter; `12/12` artifact count in inventory | docs | `mix sigra.uat.report --phase=oauth-gen --check` | ❌ W0 | ⬜ pending |
| `.planning/uat-evidence/v1.20/oauth-google/` (README + manifest + reports/) | 02 | 2 | GAUAT-04 | — | 4-row manifest (button/redirect/callback/session+logout+relogin); CI run URL embedded | docs | `mix sigra.uat.report --phase=oauth-google --check` | ❌ W0 | ⬜ pending |
| `.planning/uat-evidence/v1.20/oauth-link/` (README + manifest + reports + 1 hero PNG) | 02 | 2 | GAUAT-05 | — | 4-row manifest; one hero PNG `oauth-link__disabled-tooltip__sha-{short}.png` | docs | `mix sigra.uat.report --phase=oauth-link --check` | ❌ W0 | ⬜ pending |
| `.planning/uat-evidence/v1.20/oauth-email-match/` (README + manifest + reports/) | 02 | 2 | GAUAT-06 | — | 4-row manifest (flash/redirect/identity/linked-email-mailbox) | docs | `mix sigra.uat.report --phase=oauth-email-match --check` | ❌ W0 | ⬜ pending |
| `.planning/uat-evidence/v1.20/INDEX.md` (4 new rows) | 02 | 2 | GAUAT-03/04/05/06 | — | Top-level index extended with the 4 phase 87 directories | docs | `grep -c "oauth-gen\|oauth-google\|oauth-link\|oauth-email-match" .planning/uat-evidence/v1.20/INDEX.md` ≥ 4 | ❌ W0 | ⬜ pending |
| `87-VERIFICATION.md` | 02 | 2 | GAUAT-03/04/05/06 | — | Records CI run URL, snapshot count, artifact count, dated PASS attestations per GAUAT-* | docs | `grep -E "PASS.*GAUAT-(03|04|05|06)" 87-VERIFICATION.md` (≥4 lines) | ❌ W0 | ⬜ pending |
| Milestone-scope edits: REQUIREMENTS / ROADMAP / docs/uat-ci-coverage / CHANGELOG | 02 | 2 | GAUAT-03/04/05/06, D-87-08 | — | All four files updated alongside CONTEXT.md commit (Phase 86 D-86-08 pattern) | docs | `grep -q "Sigra.Testing.OAuthIssuer" .planning/REQUIREMENTS.md && grep -q "oauth_e2e_playwright" docs/uat-ci-coverage.md` | ❌ W0 | ⬜ pending |
| `mix sigra.uat.report` extension for OAuth phases | 02 | 2 | (D-87-06 reuse-not-duplicate) | — | Recognizes `--phase=oauth-{gen,google,link,email-match}`; reads manifest.json; renders README table | unit | `mix test test/mix/tasks/sigra_uat_report_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

> Wave 0 = test infrastructure that must exist before any Wave 1 implementation task can verify itself. The planner converts these into explicit Wave 0 tasks at the head of plan-1.

- [ ] `mix.exs` — add `{:test_server, "~> 0.1.22", only: [:dev, :test]}` (or `only: :test`); confirm `elixirc_paths(:test) ++ ["test/support"]` already exists (it does — verify)
- [ ] `test/support/sigra/testing/oauth_issuer.ex` — module skeleton with `start_link/1`, `url/0`, `set_user/1`, `openid_config/0`, `set_kid_count/1`, `stop/1`
- [ ] `test/support/sigra/testing/oauth_issuer_keys/private.pem` + `public.pem` (committed RSA fixture; multi-key path needs `private2.pem` + `public2.pem`)
- [ ] `test/sigra/testing/oauth_issuer_test.exs` — failing stub that exercises every endpoint shape (discovery, authorize, token, userinfo, jwks)
- [ ] `test/sigra/install/oauth_smoketest_task_test.exs` — failing stub for Mix task
- [ ] `test/example/priv/playwright/fixtures/oauthIssuer.ts` — failing helper module
- [ ] `test/example/priv/playwright/tests/oauth-register.spec.ts`, `oauth-link.spec.ts`, `oauth-email-match.spec.ts` — failing skeleton
- [ ] `test/example/lib/example_web/controllers/test_endpoints_controller.ex` — `Mix.env() == :test`-gated controller for OAuth-issuer-setup + DB probe (or planner picks env-flag gate per RESEARCH Option A)
- [ ] `.github/workflows/ci.yml` — pin `mix archive.install hex phx_new 1.8.5 --force` line (planner verifies exact location against current YAML)
- [ ] `.planning/uat-evidence/v1.20/oauth-{gen,google,link,email-match}/` directories created with empty `README.md` + `manifest.json` placeholders so wave-2 plan has somewhere to write

*Why Wave 0 first:* The Sigra.Testing.OAuthIssuer module is consumed by 3 Playwright specs + 1 ExUnit module test + 1 controller test. Without the skeleton existing, every Wave-1 task would self-block on a module-not-found compile error. Wave 0 = all stubs compile but test-red.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real-Google `client_id`/`client_secret` round-trip via `mix sigra.oauth.smoketest --provider=google` | (D-87-03; adopter-side) | NOT a Sigra release gate by D-87-01. Adopter-side check at install time, in adopter's environment with adopter's credentials. Sigra's CI never runs against real Google (banhammer/quota/datacenter-IP detection). | `mix sigra.oauth.smoketest --provider=google` — adopter follows `docs/oauth-google-setup.md` recipe, runs the task locally, expects exit 0 + "got back valid id_token with sub=... and email=..." |

*Note:* This is the **only** manual-only verification for Phase 87 and it is **architecturally classified as out-of-scope for Sigra's CI** (D-87-09). It is documented as residual in `docs/uat-ci-coverage.md` SEED-001 row — NOT waived (Phase 86 D-86-09 framing: documented residual ≠ waiver because nothing is being skipped, items are out-of-scope by classification).

All four GAUAT-03/04/05/06 requirements have full automated verification at the Sigra-CI layer.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (RSA fixture pem files, test_server dep, test/support skeleton, evidence dir placeholders)
- [ ] No watch-mode flags (Playwright `--headed`, ExUnit `--stale`/`--watch`)
- [ ] Feedback latency < 90s (Playwright OAuth lane is the slowest at ~90s; under threshold)
- [ ] Nyquist coverage matrix from `87-RESEARCH.md` `## Validation Architecture` is referenced from each plan's `must_haves`
- [ ] `nyquist_compliant: true` set in frontmatter once planner has covered all matrix cells

**Approval:** pending
