---
phase: 146
slug: release-gate-and-maintainer-runbook
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Quick run command** | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` |
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
| 146-01-01 | 01 | 1 | REL1-02 | T-146-01 | Release gates are mapped to release refs or explicit manual waivers with evidence. | integration/ci-orchestration | `gh run view <run-id> --log` for mapped CI/release jobs | yes | pending |
| 146-01-02 | 01 | 1 | REL1-03 | T-146-02 | Maintainer runbook includes deterministic dry-run, publish, docs, visibility, and recovery steps. | documentation verification | `mix docs --warnings-as-errors` | yes | pending |
| 146-02-01 | 02 | 2 | REL1-02 | T-146-03 | Release truth alignment checks version, manifest, tag, Hex package, and HexDocs source ref. | workflow verification | `gh workflow run "Hex publish (manual recovery)" -f tag=vX.Y.Z -f release_version=X.Y.Z` | yes | pending |
| 146-02-02 | 02 | 2 | REL1-03 | T-146-04 | Failed dry-run or publish has an explicit recover/replace path before release. | manual runbook review | `mix hex.publish --dry-run` | yes | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] Add explicit runbook checklist artifact template covering gate, evidence URL, release ref, and reviewer.
- [ ] Add or confirm command snippets for release-ref reruns and evidence retrieval.
- [ ] Confirm the canonical path/name for the Phase 146 maintainer runbook artifact.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex publish production action | REL1-03 | Publishing to Hex is an irreversible public release operation outside normal planning execution. | Verify dry-run output, workflow inputs, expected version, tag/SHA, and recovery path before real publish. |
| First-14-day hotfix triage policy | REL1-03 | Policy requires maintainer judgment on severity and replacement/revert decision boundaries. | Review policy text against runbook success criteria and record approval in release evidence. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify commands or explicit manual evidence requirements
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s for local gates, or CI/manual evidence has a URL
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
