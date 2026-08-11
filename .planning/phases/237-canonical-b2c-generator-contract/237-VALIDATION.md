---
phase: 237
slug: canonical-b2c-generator-contract
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: validated
nyquist_compliant: false
wave_0_complete: true
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
| 237-01-01 | 01 | 1 | B2C-01, B2C-02, B2C-03 | T-237-01 / — | Fresh host contains required OAuth artifacts and omits disabled feature residue | ExUnit fixture contract | `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs` | ✅ | ❌ red — exact-profile and retained-core source locks expose smoke drift |
| 237-01-02 | 01 | 1 | B2C-01, B2C-02, B2C-03 | T-237-02 / — | Assets-enabled PostgreSQL host compiles, migrates, builds assets, and boots while enforcing the B2C contract | shell integration smoke | `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` | ✅ | ❌ red — implementation correction required before CI rerun |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing `test/sigra/install/generator_passkeys_opt_out_test.exs` provides the fast generated-host fixture contract.
- [x] Existing `scripts/ci/passkeys-opt-out-smoke.sh` provides the assets-enabled PostgreSQL lifecycle and bounded boot probe.

---

## Manual-Only Verifications

No phase behavior is accepted through manual-only verification. The following automated gaps are escalated because validation tests may not modify the smoke implementation:

| Requirement | Escalated gap | Required correction |
| --- | --- | --- |
| B2C-01 | The authoritative B2C smoke invokes an extra `--no-live` flag, while the phase contract and verification define the exact three-flag profile. | Remove `--no-live` from the `sigra_b2c_alpha` `run_leg` call in `scripts/ci/passkeys-opt-out-smoke.sh`. |
| B2C-01, B2C-02 | The smoke source assertion still expects obsolete `Auth.request_magic_link`; the generated controller uses `Auth.deliver_user_magic_link_instructions`. | Update the smoke assertion to the current generated public helper. |

The PostgreSQL smoke must run in CI when a local PostgreSQL service is unavailable; this is an environment constraint, not a manual acceptance step. The 2026-08-10 audit could not connect to `127.0.0.1:53988` and therefore does not claim a current database-backed pass.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all referenced requirements
- [x] No watch-mode flags
- [x] Feedback latency < 60s for the fixture test
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** partial — automated coverage exists, but two smoke implementation corrections remain red

---

## Validation Audit 2026-08-10

| Metric | Count |
| --- | ---: |
| Gaps found | 2 |
| Resolved | 0 |
| Escalated | 2 |

### Audit Evidence

- Corrected the fixture expectation to the generated `Auth.deliver_user_magic_link_instructions` public helper.
- Added an exact source lock for the canonical three-flag B2C smoke invocation and an explicit rejection of `--no-live`.
- Updated the retained-core source lock to require the current generated magic-link helper.
- `mix format --check-formatted test/sigra/install/generator_passkeys_opt_out_test.exs` passed.
- `bash -n scripts/ci/passkeys-opt-out-smoke.sh` passed.
- Split the smoke source lock into two focused behavioral checks, so each independent implementation drift is reported even when the first one fails.
- `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs:185` failed: the B2C `run_leg` call includes `--no-live`, rather than the required exact three flags.
- `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs:195` failed: the smoke checks obsolete `Auth.request_magic_link`, rather than `Auth.deliver_user_magic_link_instructions` emitted by the generated controller.
- The focused/full ExUnit target remains red because the new guards expose both smoke drifts; PostgreSQL connection attempts also failed at `127.0.0.1:53988`.
- Test guard commits: `f9238f2c`, `33b966f3`.

## Validation Audit 2026-08-10 (retry)

| Metric | Count |
| --- | ---: |
| Gaps found | 2 |
| Resolved | 0 |
| Escalated | 2 |

### Retry Evidence

- The `gsd-nyquist-auditor` independently reproduced both focused source-lock failures and returned `## ESCALATE`; the gaps require smoke implementation changes, which the test-only auditor is forbidden to make.
- `bash -n scripts/ci/passkeys-opt-out-smoke.sh` passed.
- `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs:185 test/sigra/install/generator_passkeys_opt_out_test.exs:195` completed with `2 tests, 2 failures`, confirming both implementation drifts remain observable.
- B2C-03 remains covered by the existing generated-host negative sentinels; no redundant validation test was added.
- No PostgreSQL-backed lifecycle pass is claimed. The local test endpoint `127.0.0.1:53988` remained unavailable during the focused run.

## Validation Audit 2026-08-10 (second retry)

| Metric | Count |
| --- | ---: |
| Gaps found | 2 |
| Resolved | 0 |
| Escalated | 2 |

### Second Retry Evidence

- After the user selected **Fix all gaps**, the typed `gsd-nyquist-auditor` independently reproduced both focused source-lock failures and returned `## ESCALATE` because resolving them requires changes to the read-only smoke implementation.
- `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs:185 test/sigra/install/generator_passkeys_opt_out_test.exs:195` completed with `2 tests, 2 failures`.
- B2C-01 remains red because the smoke invokes `sigra_b2c_alpha` with the extra `--no-live` flag instead of the exact canonical three-flag profile.
- B2C-01/B2C-02 remain red because the smoke asserts obsolete `Auth.request_magic_link` instead of generated `Auth.deliver_user_magic_link_instructions` behavior.
- `bash -n scripts/ci/passkeys-opt-out-smoke.sh` and formatting checks passed; these structural checks do not resolve the behavioral failures.
- B2C-03 remains covered by the existing generated-host negative sentinels; no redundant test was added.
- No PostgreSQL-backed lifecycle pass is claimed. The local test endpoint `127.0.0.1:53988` remained unavailable.
- Auditor changed no files and preserved the unrelated `.planning/v1.48-MILESTONE-AUDIT.md` worktree modification.

## Validation Audit 2026-08-10 (third retry)

| Metric | Count |
| --- | ---: |
| Gaps found | 2 |
| Resolved | 0 |
| Escalated | 2 |

### Retry Evidence

- `bash -n scripts/ci/passkeys-opt-out-smoke.sh` passed.
- `MIX_ENV=test mix test test/sigra/install/generator_passkeys_opt_out_test.exs:185 test/sigra/install/generator_passkeys_opt_out_test.exs:195` completed with `2 tests, 2 failures`.
- B2C-01 remains unmet: the B2C `run_leg` invocation contains `--no-live` instead of the exact three canonical flags.
- B2C-01/B2C-02 remain unmet: the smoke asserts `Auth.request_magic_link` rather than the generated `Auth.deliver_user_magic_link_instructions` helper.
- These are implementation defects in the read-only smoke harness. No test assertion was weakened and no implementation file was changed.
- The focused ExUnit run logged refused connections to `127.0.0.1:53988`; no PostgreSQL-backed lifecycle evidence is claimed.
