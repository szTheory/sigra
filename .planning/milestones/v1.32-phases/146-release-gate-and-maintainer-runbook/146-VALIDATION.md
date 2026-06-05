---
phase: 146
slug: release-gate-and-maintainer-runbook
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-31
---

# Phase 146 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + GitHub Actions CI workflows |
| **Config file** | `mix.exs` + `.github/workflows/ci.yml` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs` |
| **Full suite command** | `MIX_ENV=test PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && mix docs --warnings-as-errors` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run the targeted lane for the edited gate/runbook surface.
- **After every plan wave:** Run the relevant CI jobs and docs warnings lane.
- **Before `$gsd-verify-work`:** Evidence-complete dry-run checklist and publish/recovery branch walkthrough must be complete.
- **Max feedback latency:** 180 seconds for local gates; CI/manual evidence may exceed this with explicit evidence link.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 146-01-01 | 01 | 1 | REL1-02 | T-146-01 | Release gates are mapped to release refs or explicit manual waivers with evidence. | automated contract | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs` | yes | green |
| 146-01-02 | 01 | 1 | REL1-03 | T-146-02 | Publish workflows enforce version, package, dry-run, publish, and Hex visibility gates. | automated contract | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs` | yes | green |
| 146-02-01 | 02 | 2 | REL1-02 | T-146-03 | Canonical runbook covers release gates, evidence, recovery, cleanup, and first-14-day hotfix policy. | automated contract | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs` | yes | green |
| 146-02-02 | 02 | 2 | REL1-03 | T-146-04 | Maintainer router docs point to the canonical runbook and avoid stale release-evidence routes. | automated contract | `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs` | yes | green |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [x] Add explicit runbook checklist artifact template covering gate, evidence URL, release ref, and reviewer.
- [x] Add or confirm command snippets for release-ref reruns and evidence retrieval.
- [x] Confirm the canonical path/name for the Phase 146 maintainer runbook artifact.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex publish production action | REL1-03 | Publishing to Hex is an irreversible public release operation outside normal planning execution. | Verify dry-run output, workflow inputs, expected version, tag/SHA, and recovery path before real publish. |
| First-14-day hotfix triage policy | REL1-03 | Policy requires maintainer judgment on severity and replacement/revert decision boundaries. | Review policy text against runbook success criteria and record approval in release evidence. |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or explicit manual evidence requirements
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 180s for local gates, or CI/manual evidence has a URL
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated Phase 146 contract test passed on 2026-05-31

## Validation Audit 2026-05-31

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

**Generated automated coverage:** `test/sigra/planning/phase_146_release_validation_test.exs`

**Verification command:** `MIX_ENV=test mix test test/sigra/planning/phase_146_release_validation_test.exs`

**Result:** 4 tests, 0 failures. Test boot emitted existing `Chimeway.Repo` database configuration connection errors, but the targeted contract test completed successfully.
