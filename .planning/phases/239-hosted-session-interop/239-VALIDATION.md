---
phase: 239
slug: hosted-session-interop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-08
---

# Phase 239 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox 1.2.0 |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/plug/fetch_session_test.exs` |
| **Full suite command** | `mix test` (PostgreSQL service required) |
| **Estimated runtime** | Focused: <60 seconds; full suite: environment-dependent |

## Sampling Rate

- **After every task commit:** Run the focused ExUnit file(s) changed by that task.
- **After every plan wave:** Run the relevant Crosswake companion suite and SIGRA focused suite.
- **Before `$gsd-verify-work`:** Run both repositories’ relevant full suites with the required PostgreSQL/CI service available.
- **Max feedback latency:** 60 seconds for focused tests.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 239-01-01 | 01 | 1 | XW-01 | T-239-01 | Personal `org_id: nil` is accepted; nonblank organization values remain accepted; blank values are rejected. | Crosswake contract unit | `mix test packages/crosswake_sigra/test/crosswake/companions/sigra/contracts_test.exs` | ❌ Wave 0 / companion successor | ⬜ pending |
| 239-01-02 | 01 | 1 | XW-01 | T-239-02 | Projection carries opaque references and fact fields only, with no raw token, token hash, credential, provider payload, or OAuth token. | Host adapter unit/integration | Focused generated-host adapter test | ❌ Wave 0 | ⬜ pending |
| 239-02-01 | 02 | 2 | XW-02 | T-239-03 | Missing, deleted/revoked, idle/absolute expired, stale-version, subject/session mismatch, and account switch deny before authority evaluation. | Deterministic adapter/evaluator matrix | Focused adapter test plus applicable `step_up_test.exs` coverage | ❌ Wave 0 | ⬜ pending |
| 239-02-02 | 02 | 2 | XW-02 | T-239-04 | Hosted-return evidence is navigation/evidence only and cannot select a session or grant a Crosswake route. | AuthReturn contract/integration | `mix test packages/crosswake_sigra/test/crosswake/proof/phase57_auth_return_boundaries_test.exs` plus host proof | Partial | ⬜ pending |

## Wave 0 Requirements

- [ ] Crosswake contract tests for personal `nil`, organization nonblank, and blank `org_id` for every touched contract.
- [ ] Generated-host adapter fixture proving fresh session/user resolution and secret-free lane/context/denial output.
- [ ] Deterministic replay matrix for missing, revoked/deleted, idle expired, absolute expired, stale version, subject mismatch, session mismatch, account switch, and evidence-only return.
- [ ] Explicit assertion that account-switch denial occurs before the pure evaluator can be treated as the authority source.

## Manual-Only Verifications

All phase behaviors require automated proof. A human release checkpoint may verify the Crosswake successor’s tag/Hex publication before the generated host consumes it; that checkpoint does not replace tests.

## Validation Sign-Off

- [ ] All tasks have an automated verification or Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency is under 60 seconds.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
