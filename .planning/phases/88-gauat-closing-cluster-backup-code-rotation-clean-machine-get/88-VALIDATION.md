---
phase: 88
slug: gauat-closing-cluster-backup-code-rotation-clean-machine-get
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-28
---

# Phase 88 — Validation Strategy

> Evidence-closing phase: sampling is split between automated preflight checks that prove artifact integrity and blocking human witness steps that prove the two residual launch-facing behaviors.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing Mix/ExUnit commands, repo shell scripts, and markdown evidence bundles |
| **Config file** | `mix.exs`, `scripts/ci/getting-started-contract.sh` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color` |
| **Full suite command** | `mix sigra.uat.report --phase=04 --check && mix sigra.uat.report --phase=08 --check && mix sigra.uat.report --phase=oauth-gen --check && mix sigra.uat.report --phase=oauth-google --check && mix sigra.uat.report --phase=oauth-link --check && mix sigra.uat.report --phase=oauth-email-match --check` |
| **Estimated runtime** | ~30-90s automated preflight, plus human witness time for GAUAT-07 and GAUAT-08 |

---

## Sampling Rate

- **After every task commit:** Run the task-level automated `verify` command from the touched plan.
- **After every plan wave:** Re-run the full UAT report check and the phase-specific grep/file checks for touched bundles.
- **Before `/gsd-verify-work`:** Both new human evidence bundles exist, the consolidated results file has explicit rows for `GAUAT-01..08`, and Phase 87 provenance truth is represented honestly.
- **Max feedback latency:** ~2 minutes for automated doc/evidence checks; human witness latency is bounded by the two blocking checkpoint tasks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 88-01-01 | 01 | 1 | GAUAT-07 | T-88-02, T-88-03 | Machine preflight proves backup-code invalidation semantics and audit semantics before the witness run starts | ExUnit | `MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs --no-color && cd test/example && CLOAK_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' MIX_ENV=test mix test test/example_web/smoke/backup_code_rotation_test.exs --include example_app --no-color` | ✅ post-create | ⬜ pending |
| 88-01-02 | 01 | 1 | GAUAT-07 | T-88-01, T-88-02 | Human witness captures transcript, old-code failure proof, audit-row proof, and exactly four screenshots without over-exposing backup codes | human + file | `test -f .planning/uat-evidence/v1.20/mfa-backup-rotation/transcript.log && test -f .planning/uat-evidence/v1.20/mfa-backup-rotation/reports/old-code-reuse.txt && test -f .planning/uat-evidence/v1.20/mfa-backup-rotation/reports/audit-row.json && find .planning/uat-evidence/v1.20/mfa-backup-rotation/screenshots -maxdepth 1 -type f | wc -l | grep -qx '4'` | ❌ | ⬜ pending |
| 88-01-03 | 01 | 1 | GAUAT-07 | T-88-01, T-88-03 | Final README makes transcript/query artifacts primary and screenshot support secondary | grep + file | `test -f .planning/uat-evidence/v1.20/mfa-backup-rotation/README.md && rg -n "mfa\\.backup_codes_regenerate|old-code-reuse|Outcome|Artifact class" .planning/uat-evidence/v1.20/mfa-backup-rotation/README.md .planning/uat-evidence/v1.20/mfa-backup-rotation/reports/old-code-reuse.txt .planning/uat-evidence/v1.20/mfa-backup-rotation/reports/audit-row.json` | ❌ | ⬜ pending |
| 88-02-01 | 02 | 1 | GAUAT-08 | T-88-08 | Mechanical guide contract passes before the human fresh-host run begins | shell script | `bash scripts/ci/getting-started-contract.sh` | ✅ post-create | ⬜ pending |
| 88-02-02 | 02 | 1 | GAUAT-08 | T-88-05, T-88-06 | Human witness records milestone timestamps, exact env versions, and all friction on a fresh Phoenix host | human + grep | `test -f .planning/uat-evidence/v1.20/getting-started-clean-machine/transcript.log && test -f .planning/uat-evidence/v1.20/getting-started-clean-machine/env.txt && test -f .planning/uat-evidence/v1.20/getting-started-clean-machine/friction-log.md && rg -n "START|FIRST_SERVER_BOOT|FIRST_SUCCESSFUL_REGISTER_LOGIN_RESET|END" .planning/uat-evidence/v1.20/getting-started-clean-machine/transcript.log` | ❌ | ⬜ pending |
| 88-02-03 | 02 | 1 | GAUAT-08 | T-88-05, T-88-06 | Final README states outcome, elapsed time, and friction honestly rather than smoothing the story | grep + file | `test -f .planning/uat-evidence/v1.20/getting-started-clean-machine/README.md && rg -n "Elapsed|Outcome|Friction" .planning/uat-evidence/v1.20/getting-started-clean-machine/README.md` | ❌ | ⬜ pending |
| 88-03-01 | 03 | 2 | GAUAT-09 | T-88-10 | Results filing treats unresolved Phase 87 provenance as a hard `BLOCKED` gate until real CI URLs exist | Mix + file | `mix sigra.uat.report --phase=04 --check && mix sigra.uat.report --phase=08 --check && mix sigra.uat.report --phase=oauth-gen --check && mix sigra.uat.report --phase=oauth-google --check && mix sigra.uat.report --phase=oauth-link --check && mix sigra.uat.report --phase=oauth-email-match --check && test -f .planning/uat-evidence/v1.20/mfa-backup-rotation/README.md && test -f .planning/uat-evidence/v1.20/getting-started-clean-machine/README.md` | ❌ | ⬜ pending |
| 88-03-02 | 03 | 2 | GAUAT-09 | T-88-09, T-88-11 | Consolidated results file has one explicit row for each GAUAT item and SEED-001 only closes when D-88-11 or an explicit D-88-12 exception permits it | grep | `for req in GAUAT-01 GAUAT-02 GAUAT-03 GAUAT-04 GAUAT-05 GAUAT-06 GAUAT-07 GAUAT-08; do rg -n "$req" .planning/v1.20-GA-UAT-RESULTS.md; done && ! rg -n "Pending|TBD" .planning/v1.20-GA-UAT-RESULTS.md && rg -n "status: (validated|partially-validated|deferred)" .planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` | ❌ | ⬜ pending |
| 88-03-03 | 03 | 2 | GAUAT-09 | T-88-09, T-88-10, T-88-11 | Phase verification record matches the results file and carries the launch-leg block forward honestly if provenance is unresolved | grep + file | `test -f .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-VERIFICATION.md && ! rg -n "Pending|TBD" .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-VERIFICATION.md && rg -n "Launch-leg disposition|GAUAT-03|GAUAT-04|GAUAT-05|GAUAT-06|local_pass_pending_ci_provenance|BLOCKED|ci_run_url" .planning/phases/88-gauat-closing-cluster-backup-code-rotation-clean-machine-get/88-VERIFICATION.md` | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing Mix/ExUnit and shell-script infrastructure already present; no new test harness is required for this evidence-closing phase.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real MFA backup-code regeneration witness flow with screenshot capture and old-code invalidation proof | GAUAT-07 | The user-visible flow, redaction discipline, and witness transcript are inherently human-facing | Follow `88-01-PLAN.md` Task 2 exactly; capture the four required screenshots, `transcript.log`, `reports/old-code-reuse.txt`, and `reports/audit-row.json` |
| Fresh-host getting-started witness run with friction tracking | GAUAT-08 | The residual claim is documentation clarity and onboarding friction for a developer new to Sigra | Follow `88-02-PLAN.md` Task 2 exactly; use a fresh Phoenix host, timestamp the four milestones, and record every hint or deviation in `friction-log.md` |
| Launch-leg disposition wording review | GAUAT-09 | The final signoff language can still be mechanically correct but misleading in tone | Maintainer skim `88-VERIFICATION.md` and `.planning/v1.20-GA-UAT-RESULTS.md` to confirm the wording does not over-claim beyond the actual provenance state |

---

## Validation Sign-Off

- [ ] All tasks have an automated `verify` command, including the blocking human tasks
- [ ] Sampling continuity: every human checkpoint is paired with an automated preflight/file-integrity command
- [ ] No watch-mode flags
- [ ] `GAUAT-01..08` each appear exactly once in the final results file
- [ ] Phase 87 provenance is either fully closed or represented as `BLOCKED` in Phase 88 outputs
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution closes with all validation evidence complete

**Approval:** pending
