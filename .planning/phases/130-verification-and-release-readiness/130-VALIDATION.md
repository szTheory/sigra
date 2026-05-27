---
phase: 130
slug: verification-and-release-readiness
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-27
---

# Phase 130 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5 |
| **Config file** | `test/test_helper.exs`; `config/test.exs`; project test filters in `mix.exs` |
| **Quick run command** | `mix test test/sigra/data_export_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs test/sigra/account_audit_atomicity_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Docs gate command** | `mix docs --warnings-as-errors` |
| **Estimated runtime** | Quick targeted lane under 60 seconds; full suite/docs gate environment-dependent |

---

## Sampling Rate

- **After every task commit:** Run the targeted lane for the artifact touched; for traceability-only edits, run the traceability `rg` command.
- **After every plan wave:** Run both targeted DATA-LIFECYCLE suites and the generated-host/docs proof lane.
- **Before `$gsd-verify-work`:** Full root test lane and docs warnings-as-errors must pass, or failures must be captured as explicit blockers.
- **Max feedback latency:** 60 seconds for targeted lanes; full release gates may exceed this and must be recorded with command output.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 130-01-01 | 01 | 1 | PROOF-01 | T-130-01 | Export proof excludes secret/replay-relevant credential fields | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | Yes | pending |
| 130-01-02 | 01 | 1 | PROOF-01 | T-130-02 | Account deletion proof covers lifecycle truth and worker scheduling behavior | unit | `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --max-failures 1` | Yes | pending |
| 130-01-03 | 01 | 1 | PROOF-01 | T-130-03 | Generated host remains aligned with library export/lifecycle contract | integration | `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1` | Yes | pending |
| 130-01-04 | 01 | 1 | PROOF-01 | T-130-04 | Docs do not overclaim export, omission, or deletion behavior | docs | `mix test test/sigra/guides_dx02_test.exs --max-failures 1` and `mix docs --warnings-as-errors` | Yes | pending |
| 130-01-05 | 01 | 1 | PROOF-01 | T-130-05 | Release readiness is based on fresh full-suite evidence or explicit blockers | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` | Yes | pending |
| 130-01-06 | 01 | 1 | PROOF-01 | T-130-06 | Requirements traceability maps all v1.28 requirements to active roadmap phases | artifact audit | `rg -n "EXP-01|EXP-02|LIFE-01|LIFE-02|LIFE-03|HOST-01|DOC-01|PROOF-01" .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/phases/127-* .planning/phases/128-* .planning/phases/129-* .planning/phases/130-*` | Yes | pending |

---

## Wave 0 Requirements

- [ ] `.planning/phases/130-verification-and-release-readiness/130-01-PLAN.md` - executable release-readiness plan exists.
- [ ] `.planning/phases/130-verification-and-release-readiness/130-01-SUMMARY.md` - command evidence and traceability changes are recorded during execution.
- [ ] `.planning/phases/130-verification-and-release-readiness/130-VERIFICATION.md` - final verifier proof exists before PROOF-01 is closed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Classification of broader release gate failures as blockers | PROOF-01 | A failing command may be environmental, pre-existing, or release-blocking; the executor must classify from command output. | Record failing command, short failure summary, owner/next action, and retry condition in `130-01-SUMMARY.md` and do not claim PROOF-01 complete unless the blocker is resolved or explicitly accepted. |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or explicit manual blocker handling.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing phase artifact references.
- [x] No watch-mode flags.
- [x] Feedback latency target defined for targeted lanes.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
