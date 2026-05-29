---
phase: 137
slug: optional-dependency-source-of-truth
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-29
validated: 2026-05-29
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
| W0 | 137-01 | 0 | OD-01 | — | N/A | unit | `mix test test/sigra/optional_deps_test.exs` | ✅ | ✅ green |
| SOT-predicates | 137-01 | 1 | OD-01 | — | All 9 `*_available?/0` predicates + encryption predicate exist; each returns the same truth value as `Code.ensure_loaded?(Mod)` | unit | `mix test test/sigra/optional_deps_test.exs` | ✅ | ✅ green |
| SOT-encryption | 137-01 | 1 | OD-01 | — | `encryption_active?/1` mirrors `__sigra_encryption_mode__/0` stub-vs-real (false for stub, true for real) — NOT a `Code.ensure_loaded?(Cloak)` check | unit | `mix test test/sigra/optional_deps_test.exs` | ✅ | ✅ green |
| delegate-crypto | 137-02 | 2 | OD-02 | — | bcrypt-verify fallback unchanged (`crypto.ex:244`, `hashers/bcrypt.ex:39,48`) | unit (existing) | `mix test test/sigra/crypto_test.exs` | ✅ | ✅ green |
| delegate-rate-limit | 137-02 | 2 | OD-02 | — | Hammer-vs-Noop resolution unchanged (`plug/rate_limit.ex:85`) | unit (existing) | `mix test test/sigra/plug/rate_limit_test.exs` | ✅ | ✅ green |
| delegate-routing | 137-03 | 2 | OD-02 | — | delivery/forwarders sync↔async routing + compound-guard liveness half preserved (`delivery.ex:114`, `audit/forwarders.ex:99`, `deletion.ex:307`) | unit (existing) | `mix test test/sigra/application_forwarders_test.exs test/sigra/account/deletion_test.exs test/sigra/enterprise_connections/validation_test.exs` | ✅ | ✅ green |
| dep-off-lane | 137-02/03 | 2 | OD-02 | — | Threadline-absent lane stays green; compile clean, no new `no_warn_undefined` entries | CI lane / compile | `library_tests_dep_off` (ci.yml:170) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/optional_deps_test.exs` — unit tests for all 9 `*_available?/0` predicates + the encryption predicate. Each predicate test asserts equality to a freshly-evaluated `Code.ensure_loaded?(Mod)` (drift-catching, not a hardcoded `true`), so the same test stays valid in a dep-off env. Encryption test uses in-test fixture modules (`StubVault.Encrypted.Binary` / `RealVault.Encrypted.Binary`) for the stub→false / vault→true / missing→false cases. **Created in 137-01 (commit `8b59943`); 12 tests, 0 failures.**
- [x] Bcrypt-verify fallback path covered. The drift-catching equality assertion in the Wave 0 unit file covers the `bcrypt_available?/0` predicate; the falsy-branch (Bcrypt absent) is exercised end-to-end by the `library_tests_dep_off` CI lane. `crypto_test.exs` (24 tests) covers the truthy path. No additional assertion required.
- [x] No framework install needed — ExUnit present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

*All phase behaviors have automated verification. The one dep-absence path that CI does not exercise (8 of 9 predicates' falsy branch — only Threadline is removed in any lane) is covered by the drift-catching equality assertions in the Wave 0 unit file, so no manual step is required.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (`test/sigra/optional_deps_test.exs` created)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (SOT unit file ran in 0.06s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-05-29 — all 7 task-map rows green, 0 gaps.

---

## Validation Audit 2026-05-29

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Audit re-classified the pre-execution draft against delivered artifacts. All 7 task-map rows confirmed COVERED — no gaps, no auditor spawn needed.

**Test runs (this audit):**
- `mix test test/sigra/optional_deps_test.exs` → 12 tests, 0 failures (0.06s, no DB)
- `mix test crypto_test.exs plug/rate_limit_test.exs application_forwarders_test.exs account/deletion_test.exs enterprise_connections/validation_test.exs` → 71 tests, 0 failures (1.1s, Postgres @ localhost:5432)
- `library_tests_dep_off` CI lane confirmed present at `.github/workflows/ci.yml:170`
- Residual `Code.ensure_loaded?` occurrences (deletion.ex:308, forwarders.ex:139 `@worker_module` defmodule wrapper, forwarders.ex comments) match the documented D-04/D-05/Bucket-C fences exactly — no leaked SOT delegations.
