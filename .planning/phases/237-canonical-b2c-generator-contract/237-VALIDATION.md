---
phase: 237
slug: canonical-b2c-generator-contract
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-04
---

# Phase 237 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus an existing shell smoke contract |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs` |
| **Full suite command** | `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` |
| **Estimated runtime** | Fixture test: ~30 seconds; PostgreSQL smoke: CI-bound |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs`
- **After every plan wave:** Run the relevant fixture contract; run `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` when PostgreSQL is available.
- **Before `$gsd-verify-work`:** The fixture contract and the full assets-enabled PostgreSQL smoke must be green.
- **Max feedback latency:** ~30 seconds for the fixture contract.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 237-01-01 | 01 | 1 | B2C-01, B2C-02, B2C-03 | T-237-01 / — | Fresh host contains required OAuth artifacts and omits disabled feature residue | ExUnit fixture contract | `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs` | ✅ | ⬜ pending |
| 237-01-02 | 01 | 1 | B2C-01, B2C-02, B2C-03 | T-237-02 / — | Assets-enabled PostgreSQL host compiles, migrates, builds assets, and boots while enforcing the B2C contract | shell integration smoke | `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing `test/sigra/install/generator_passkeys_opt_out_test.exs` provides the fast generated-host fixture contract.
- [x] Existing `scripts/ci/passkeys-opt-out-smoke.sh` provides the assets-enabled PostgreSQL lifecycle and bounded boot probe.

---

## Manual-Only Verifications

All phase behaviors have automated verification. The PostgreSQL smoke must run in CI when a local PostgreSQL service is unavailable; this is an environment constraint, not a manual acceptance step.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all referenced requirements
- [x] No watch-mode flags
- [x] Feedback latency < 60s for the fixture test
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
