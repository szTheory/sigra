---
phase: 240
slug: alpha-operations-rehearsal
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-10
validated: 2026-08-11
---

# Phase 240 — Validation Strategy

> Retrospective Nyquist audit for the provider-neutral, no-secrets B2C operations gate.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox; generated-host runtime proof uses Phoenix/Playwright; documentation uses ExDoc |
| **Config files** | `test/test_helper.exs`, `test/example/test/test_helper.exs` |
| **Focused contract command** | `MIX_ENV=test mix test test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/install/generated_rate_limit_context_test.exs test/sigra/plug/rate_limit_test.exs test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs test/sigra/planning/phase_240_no_secrets_ci_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` |
| **Golden/idempotency command** | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs && MIX_ENV=test mix sigra.fixture.rebless_golden --check` |
| **Fresh-host proof** | `scripts/ci/passkeys-opt-out-smoke.sh` |
| **Documentation/static checks** | `mix docs --warnings-as-errors` and `bash -n scripts/ci/passkeys-opt-out-smoke.sh scripts/ci/generated-auth-runtime-proof.sh` |
| **Full suite command** | `mix test` with the repository PostgreSQL environment loaded |
| **Observed audit runtime** | Focused contracts: <1 second; generated-host golden/idempotency: ~2 minutes |

## Sampling Rate

- **After every task commit:** Run the focused test file(s) owned by that task.
- **After generator or fixture changes:** Run golden diff, idempotency, and `sigra.fixture.rebless_golden --check`.
- **After documentation or CI-harness changes:** Run the source contracts, warnings-as-errors docs build, and Bash syntax checks.
- **At phase close:** Run the credential-free fresh-host smoke with PostgreSQL available.
- **No elapsed-window waits:** Rate-limit assertions use injected low bounds and synchronous N-1/N/N+1 requests.

## Requirement Coverage

| Requirement | Automated evidence | Status |
|-------------|--------------------|--------|
| OPS-01 | Generated Hammer ownership, independent route/context limiter map, bounded denial/Retry-After behavior, exact golden/idempotent output, three-tier recipe contract, and fresh-host lifecycle | COVERED |
| OPS-02 | Independent no-secret generator/runtime lanes, inherited-Google removal, disposable fixture labeling, local-only claim boundaries, staging-gate/redaction documentation contract | COVERED |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Automated verification | Evidence | Status |
|---------|------|------|-------------|------------------------|----------|--------|
| 240-05-01 | 05 | 0 | OPS-01 | Format and parse the generated ownership/flow-map ExUnit modules; downstream focused execution | Active Wave 0 contracts are green in the 57-test focused run | COVERED |
| 240-05-02 | 05 | 0 | OPS-01, OPS-02 | Format and parse the operations/no-secrets ExUnit modules; downstream focused execution | Active Wave 0 contracts are green in the 57-test focused run | COVERED |
| 240-01-01 | 01 | 1 | OPS-01 | Ownership/plug contracts, Bash syntax, and credential-free fresh-host smoke | Generated Hammer owner and bounded generic POST denial are executable | COVERED |
| 240-02-01 | 02 | 2 | OPS-01 | Generated context/ownership/plug contracts | Independent controller-IP and normalized-email keys plus non-enumerating outcomes are green | COVERED |
| 240-02-02 | 02 | 2 | OPS-01 | Golden diff, idempotency, and fixture drift detector | 4/4 tests pass after scoped official rebless; drift detector exits 0 | COVERED |
| 240-03-01 | 03 | 2 | OPS-01, OPS-02 | Operations recipe contract and warnings-as-errors docs build | Three tiers, secure tuple, host-only gates, Doctor boundary, and redacted receipts are green | COVERED |
| 240-04-01 | 04 | 2 | OPS-02 | No-secrets/Phase 238 source contracts, Bash syntax, and exact `COVERAGE.md` declaration | Separate credential-free lanes reject secrets, inherited Google state, lane merging, and claim inflation | COVERED |

## Wave 0 Requirements

- [x] `test/sigra/install/generated_rate_limit_contract_test.exs` actively covers generated ownership, threshold, Retry-After precision, idempotency, and the fresh-host tracer.
- [x] `test/sigra/install/generated_rate_limit_context_test.exs` actively covers the complete flow map, independent prefixes/keys, and non-enumerating outcomes.
- [x] `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` actively covers evidence tiers, the literal host tuple, host-only gates, redaction, and Doctor claim boundaries.
- [x] `test/sigra/planning/phase_240_no_secrets_ci_test.exs` actively covers separate lane topology, disposable fixtures, inherited-Google removal, negative credential/claim assertions, and local-only coverage.

## Manual-Only Verifications

None within the Phase 240 requirement boundary. Real Google authorization, controlled-recipient mail delivery, public TLS/proxy behavior, and physical-iPhone return remain adopter-host launch gates that OPS-02 requires the repository to name but explicitly forbids library CI from claiming as passed.

## Validation Sign-Off

- [x] All seven tasks have automated verification.
- [x] OPS-01 and OPS-02 have active behavioral/source contracts that ran green.
- [x] Sampling continuity has no unverified task sequence.
- [x] All four Wave 0 artifacts exist and are green.
- [x] Golden fixture parity and repeat-install idempotency are green.
- [x] No watch-mode flags, fixed sleeps, or rate-window waits are used.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** automated validation passed on 2026-08-11.

## Validation Audit 2026-08-11

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |
| Requirements covered | 2/2 |
| Tasks covered | 7/7 |

Audit evidence:

- Focused Phase 240/238 contracts: 57 tests, 0 failures.
- Golden/idempotency suite: 4 tests, 0 failures after one official scoped fixture rebless.
- Golden drift detector: exit 0.
- Documentation warnings-as-errors build: passed.
- Both CI harnesses parse with Bash: passed.
