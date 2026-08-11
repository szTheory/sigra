---
phase: 239
slug: hosted-session-interop
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-08
validated: 2026-08-10
---

# Phase 239 — Validation Strategy

> Retrospective Nyquist audit for the hosted SIGRA-to-Crosswake session boundary.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox 1.2.0 + Ecto/PostgreSQL; ShellCheck for the proof runner |
| **Config files** | `test/test_helper.exs`, `test/example/test/test_helper.exs` |
| **Fast contract** | `MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs` |
| **Complete phase proof** | `scripts/ci/hosted-session-interop-proof.sh` |
| **Static runner checks** | `bash -n scripts/ci/hosted-session-interop-proof.sh && shellcheck -x scripts/ci/hosted-session-interop-proof.sh` |
| **Full repository suite** | `mix test` (PostgreSQL service required) |
| **Observed audit runtime** | Fast contract: 0.04 seconds; complete adapter suite: 2.3 seconds |

## Sampling Rate

- **After every task commit:** Run the focused ExUnit tag or source/release contract named by that task.
- **After every plan wave:** Run the complete adapter file when a wave changes the adapter boundary.
- **At phase close and during retroactive validation:** Run `scripts/ci/hosted-session-interop-proof.sh`, then validate the runner with Bash and ShellCheck.
- **Max observed feedback latency:** Under 3 seconds for the test processes in the 2026-08-10 audit.

## Requirement Coverage

| Requirement | Automated evidence | Status |
|-------------|--------------------|--------|
| XW-01 | Immutable Crosswake release proof; personal `org_id: nil`, nonblank organization, blank rejection, opaque/secret-free projection; recipe and dependency alignment; fast phase contract | COVERED |
| XW-02 | Immutable AuthReturn proof; real-row currentness, expiry, binding, account-switch, and evidence-only matrices with evaluator non-invocation; complete proof runner | COVERED |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Automated verification | Evidence | Status |
|---------|------|------|-------------|------------------------|----------|--------|
| 239-00-01 | 00 | 0 | XW-01, XW-02 | Public Hex package and Git tag availability gate | Public successor coordinates captured in `239-CROSSWAKE-RELEASE-PROOF.json` | COVERED |
| 239-00-02 | 00 | 0 | XW-01, XW-02 | Four exact formatter/contract/AuthReturn/full-suite commands at the immutable Crosswake SHA | Ordered zero-exit `passed` records validated by the fast phase contract | COVERED |
| 239-01-01 | 01 | 1 | XW-01, XW-02 | Strict JSON schema/command gate plus Hex checksum and peeled-tag reconciliation | Release proof and normalized release receipt remain aligned | COVERED |
| 239-02-01 | 02 | 2 | XW-01, XW-02 | `--only crosswake_tracer` plus release/dependency predicates | Included in the green complete 14-test adapter suite and fast contract | COVERED |
| 239-03-01 | 03 | 3 | XW-02 | `--only crosswake_currentness` | Missing, malformed, deleted, missing-subject, and inactive state deny before evaluator invocation | COVERED |
| 239-03-02 | 03 | 3 | XW-02 | `--only crosswake_expiry` | Idle and absolute equality boundaries deny deterministically with fixed instants | COVERED |
| 239-04-01 | 04 | 4 | XW-02 | `--only crosswake_binding` | Session, subject, and server-owned version mismatches deny before evaluation | COVERED |
| 239-04-02 | 04 | 4 | XW-02 | `--only crosswake_account_switch` | Cross-account and same-account session substitution deny without evaluator calls | COVERED |
| 239-05-01 | 05 | 5 | XW-01, XW-02 | `--only crosswake_return_evidence` | Valid or invalid return evidence cannot select or revive host authority; smuggling fields reject | COVERED |
| 239-05-02 | 05 | 5 | XW-01, XW-02 | Complete adapter suite plus fast recipe/release contract | Recipe requirement and authority language match the executable boundary | COVERED |
| 239-06-01 | 06 | 6 | XW-01, XW-02 | Fast phase contract, Bash syntax check, and ShellCheck | 4 tests passed; runner is bounded, failure-propagating, and receipt-last | COVERED |
| 239-06-02 | 06 | 6 | XW-01, XW-02 | `scripts/ci/hosted-session-interop-proof.sh` | 14 database-backed adapter tests passed and current exact-SHA evidence was regenerated | COVERED |

## Wave 0 Requirements

- [x] The release proof uses schema `sigra.phase239.crosswake-release-proof.v1` and carries complete public release coordinates.
- [x] Its command array contains exactly the required four ordered records with numeric zero statuses and exact `passed` outcomes.
- [x] The immutable release executed personal nil-org, organization compatibility, blank rejection, AuthReturn boundary, and complete companion coverage.
- [x] The generated-host adapter resolves current session/user state and emits only secret-free lane, context, denial, and evidence output.
- [x] The deterministic replay matrix covers unavailable/revoked state, idle and absolute expiry, stale version, subject/session mismatch, account switch, and evidence-only return.
- [x] Every denial family proves evaluator non-invocation, so account switches and return evidence cannot become an authority source.

## Manual-Only Verifications

None. The independently owned publication authorization was a one-time human action, but its public coordinates, immutable source, command outcomes, and all SIGRA consumer behavior are proven mechanically.

## Validation Sign-Off

- [x] All 12 tasks have automated verification.
- [x] XW-01 and XW-02 have behavioral tests that ran green in this audit.
- [x] Sampling continuity has no unverified task sequence.
- [x] Wave 0 release evidence is complete and mechanically consumed by the phase seal.
- [x] No watch-mode flags, sleeps, or manual-UAT authority paths are present.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** automated validation passed on 2026-08-10.

## Validation Audit 2026-08-10

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
| Requirements covered | 2/2 |
| Tasks covered | 12/12 |

Audit commands passed:

- `scripts/ci/hosted-session-interop-proof.sh` — 4 fast contract tests and 14 database-backed adapter tests, 0 failures.
- `bash -n scripts/ci/hosted-session-interop-proof.sh` — passed.
- `shellcheck -x scripts/ci/hosted-session-interop-proof.sh` — passed.
