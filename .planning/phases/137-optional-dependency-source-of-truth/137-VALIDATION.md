---
phase: 137
slug: optional-dependency-source-of-truth
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-29
---

# Phase 137 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 137-RESEARCH.md § Validation Architecture (HIGH confidence, call sites read at exact file:line).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 / OTP 28, per `.tool-versions`) |
| **Config file** | none custom — standard `mix test`; `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/optional_deps_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | SOT unit file ~1–2s (no DB needed); full suite minutes (needs live Postgres @ localhost:5432, postgres/postgres) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/optional_deps_test.exs` + the touched call-site's existing test file
- **After every plan wave:** Run full `mix test` + `mix compile --warnings-as-errors` + `mix credo` (no new strict regressions)
- **Before `/gsd-verify-work`:** Full suite green + `library_tests_dep_off` lane green + `mix docs --warnings-as-errors` green
- **Max feedback latency:** ~2 seconds (SOT unit file standalone)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| W0 | (Wave 0) | 0 | OD-01 | — | N/A | unit | `mix test test/sigra/optional_deps_test.exs` | ❌ W0 | ⬜ pending |
| SOT-predicates | TBD | 1 | OD-01 | — | All 9 `*_available?/0` predicates + encryption predicate exist; each returns the same truth value as `Code.ensure_loaded?(Mod)` | unit | `mix test test/sigra/optional_deps_test.exs` | ❌ W0 | ⬜ pending |
| SOT-encryption | TBD | 1 | OD-01 | — | `encryption_active?/1` mirrors `__sigra_encryption_mode__/0` stub-vs-real (false for stub, true for real) — NOT a `Code.ensure_loaded?(Cloak)` check | unit | `mix test test/sigra/optional_deps_test.exs` | ❌ W0 | ⬜ pending |
| delegate-crypto | TBD | 2 | OD-02 | — | bcrypt-verify fallback unchanged (`crypto.ex:244`, `hashers/bcrypt.ex:39,48`) | unit (existing) | `mix test test/sigra/crypto_test.exs` | ✅ verify | ⬜ pending |
| delegate-rate-limit | TBD | 2 | OD-02 | — | Hammer-vs-Noop resolution unchanged (`plug/rate_limit.ex:85`) | unit (existing) | `mix test test/sigra/plug/rate_limit_test.exs` | ✅ verify | ⬜ pending |
| delegate-routing | TBD | 2 | OD-02 | — | delivery/forwarders sync↔async routing + compound-guard liveness half preserved (`delivery.ex:114`, `audit/forwarders.ex:99`, `deletion.ex:307`) | unit (existing) | `mix test test/sigra/application_forwarders_test.exs` | ✅ verify | ⬜ pending |
| dep-off-lane | TBD | 2 | OD-02 | — | Threadline-absent lane stays green; compile clean, no new `no_warn_undefined` entries | CI lane / compile | `library_tests_dep_off` (ci.yml:170) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/optional_deps_test.exs` — unit tests for all 9 `*_available?/0` predicates + the encryption predicate. Each predicate test asserts equality to a freshly-evaluated `Code.ensure_loaded?(Mod)` (drift-catching, not a hardcoded `true`), so the same test stays valid in a dep-off env. Encryption test needs a fixture host module exporting `__sigra_encryption_mode__/0` returning `:stub` and `:real` (model on existing `verify_vault!` tests in `test/sigra/application_*_test.exs`).
- [ ] Confirm `test/sigra/crypto_test.exs` covers the bcrypt-verify fallback path; if not, add a falsy-branch assertion (the bcrypt sites' falsy branch is otherwise unexercised by CI).
- [ ] No framework install needed — ExUnit is present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

*All phase behaviors have automated verification. The one dep-absence path that CI does not exercise (8 of 9 predicates' falsy branch — only Threadline is removed in any lane) is covered by the drift-catching equality assertions in the Wave 0 unit file, so no manual step is required.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`test/sigra/optional_deps_test.exs`)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s (SOT unit file)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
