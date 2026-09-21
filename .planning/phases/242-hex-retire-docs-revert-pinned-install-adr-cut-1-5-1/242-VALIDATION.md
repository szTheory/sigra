---
phase: "242"
slug: "hex-retire-docs-revert-pinned-install-adr-cut-1-5-1"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-20"
---

# Phase 242 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Node built-in test runner, Bash integration helpers |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `.github/workflows/*.yml` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs test/sigra/planning/phase_222_release_lane_hardening_test.exs` |
| **Full suite command** | `MIX_ENV=test mix ci` |
| **Estimated runtime** | Existing quick test runtime plus a bounded live remediation/release workflow only when the plan explicitly dispatches it |

## Sampling Rate

- **After every task commit:** Run the focused hermetic check for that task.
- **After every plan wave:** Run the relevant Node/Bash checks and `MIX_ENV=test mix ci` where the changed surface requires it.
- **Before `$gsd-verify-work`:** Preserve committed, sanitized public evidence and exact-SHA release receipts.
- **Max feedback latency:** Hermetic checks must finish in the normal CI feedback window; live Hex mutations are bounded, single-dispatch evidence operations.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 242-01-01 | 01 | 1 | REL-03 | T-242-01 | Fixed-target workflow scopes `HEX_API_KEY` to mutation steps and commits only sanitized observations | structural | focused remediation-workflow Node test | ❌ W0 | ⬜ pending |
| 242-01-02 | 01 | 1 | REL-04 | T-242-02 | Docs-only revert and root-doc observation are explicit and measurable | structural + live evidence | focused remediation-workflow test plus committed public receipt | ❌ W0 | ⬜ pending |
| 242-02-01 | 02 | 2 | REL-05 | T-242-03 | Fresh `HEX_HOME` probes never use `HEX_IGNORE_RETIREMENTS` and distinguish broad from bounded constraints | integration | `bash scripts/ci/hex-remediation-verify.sh` | ❌ W0 | ⬜ pending |
| 242-03-01 | 03 | 3 | REL-06 | T-242-04 | Release Please follows the exact-SHA green gate and post-publish verification | structural + live receipt | existing release validation tests plus one exact-SHA receipt | ✅ / live pending | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] Focused remediation workflow structural test and known-bad fixture.
- [ ] `scripts/ci/hex-remediation-verify.sh` plus hermetic self-test for sanitized API projection and fresh-home resolver checks.
- [ ] Evidence schema that requires BEFORE, AFTER_RETIRE, AFTER_DOCS_REVERT, root-doc observation, and both resolver receipts.
- [ ] Docs-index/update assertion for each adopter-facing installation source.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Authorized Hex retirement/docs revert | REL-03, REL-04 | The protected production credential cannot be inspected locally | Dispatch the fixed-target workflow once; preserve its sanitized public evidence and successful run URL/ID. |
| 1.5.1 public publication | REL-06 | Immutable external release event | Use the existing Release Please path and preserve the exact-SHA CI and post-publish receipts. |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Live actions are single-dispatch, fixed-target, and evidence-backed
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
