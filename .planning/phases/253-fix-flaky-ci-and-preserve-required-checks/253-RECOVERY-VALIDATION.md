---
phase: "253"
slug: "fix-flaky-ci-and-preserve-required-checks"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-13"
---

# Phase 253 recovery validation map

This adds checks for new Plans 09–14. The original `253-VALIDATION.md` and original eight plans remain byte-identical. Every row below is pending execution. Local tests check implementation; browser/hosted commands in task actions produce native receipts, and the listed fast verifier checks those receipts after the bounded run. A truthful open requirement remains open.

| Requirement | Task / recovery wave | Native or source proof | Automated check | Expected failing direction | Status |
|---|---|---|---|---|---|
| CIREL-01 | 09 T1 / W1 | New freeze before one real selected browser path; report/log/drop identity | `node --test scripts/ci/ci-registration-recovery.test.mjs && node scripts/ci/ci-registration-recovery.mjs --verify-diagnostic .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-REGISTRATION-EVIDENCE.json` | Missing browser/report/hash fails | pending |
| CIREL-01 | 09 T2 / W1 | Three project diagnostic attempts and original failed outcomes | Same 09 T1 command | Forged pass, wrong source/project, missing drop fail | pending |
| CIREL-01 | 10 T1 / W2 | Real held/missing readiness, broken wait, collision and first-failure trace | `node --test scripts/ci/ci-registration-recovery.test.mjs scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs && node scripts/ci/ci-registration-recovery.mjs --verify-controls .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-REGISTRATION-EVIDENCE.json` | Broken control or absent native trace fails | pending |
| CIREL-01 | 10 T2 / W2 | Cause-backed pre/post control and three fresh invocations per affected project, or explicit gap | `node --test scripts/ci/ci-registration-recovery.test.mjs scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs && node scripts/ci/ci-registration-recovery.mjs --verify-acceptance .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-REGISTRATION-EVIDENCE.json` | Unsupported fix/no-flake claim fails | pending |
| CIREL-02 | 11 T1 / W1 | Fake full path through charged dispatch/poll/redirect/artifact/verifier | `bash scripts/ci/ci-gate-canary.test.sh && python3 scripts/ci/ci-hosted-gate-verify.test.py` | Extra request, 403/429 or oversized input fails | pending |
| CIREL-02 | 11 T2 / W1 | New source/fixture/budget freeze distinct from failed old run | `bash scripts/ci/ci-gate-canary.test.sh && bash scripts/ci/ci-gate-canary.sh --check-only --recovery-freeze .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json` | Old ref or changed required names fails | pending |
| CIREL-02 | 12 T1 / W2 | New real full-pass fixture, jobs/steps/artifact digest | `python3 scripts/ci/ci-hosted-gate-verify.py --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-EVIDENCE.json --scenario full-pass && bash scripts/ci/ci-gate-canary.test.sh` | Wrong candidate/workflow/digest fails | pending |
| CIREL-02 | 12 T2 / W2 | Five remaining real scenarios and separate hosted verifier | `bash scripts/ci/ci-gate-canary.test.sh && python3 scripts/ci/ci-hosted-gate-verify.test.py && python3 scripts/ci/ci-hosted-gate-verify.py --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-EVIDENCE.json --scenario matrix` | Green negative source or inferred cancellation fails | pending |
| CIREL-02 | 13 T1 / W3 | Fake full PR family with head/merge/check/report/digest and docs classifier | `bash scripts/ci/ci-pr-proof.test.sh && python3 scripts/ci/ci-hosted-gate-verify.test.py` | Wrong SHA or false docs-only fails | pending |
| CIREL-02 | 13 T2 / W3 | Normal draft PR to main and five exact effective required contexts | `python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-PR-EVIDENCE.json --family normal` | Missing check/report or wrong merge revision fails | pending |
| CIREL-02 | 13 T3 / W3 | Real docs-only PR to scoped candidate base, actual classifier success/true | `python3 scripts/ci/ci-hosted-gate-verify.py --mode pr --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-PR-EVIDENCE.json --family docs-only` | Synthetic event, wrong workflow body or unexpected skip fails | pending |
| CIREL-01/02 | 14 T1 / W4 | Separate honest requirement dispositions, original failures retained | `python3 scripts/ci/ci-hosted-gate-verify.test.py && python3 scripts/ci/ci-hosted-gate-verify.py --mode completion --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-COMPLETION-RECORD.json` | Missing native proof cannot be accepted | pending |
| CIREL-01/02 | 14 T2 / W4 | Exact historical byte read-back; 08 superseded only after acceptance | `python3 scripts/ci/ci-hosted-gate-verify.py --mode completion --require-accepted --evidence .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-COMPLETION-RECORD.json && gsd_run query phase-plan-index 253` plus the 253-14 task's `jq -e` predicate | Open requirement or old status changed fails | pending |

Budgets are fixed before action: registration at most ten diagnostic invocations or twenty minutes per signature, sixty minutes total; only one independently diagnosed infrastructure retry. Canary at most 120 charged requests, 45 actually executed tiny jobs and 60 minutes, including all six scenarios and separate verifier. Production PR proof has a separate <=120-request/60-minute total for the normal and real docs-only families and at most one diagnosed infrastructure rerun. Every 403/429 stops until reset/retry time; REST core remaining <=250 stops polling. No original exhausted freeze is reused.

No human UAT is substituted for native proof. If a bounded run cannot establish an old registration cause, a real canary source outcome, independent verifier, or both PR families, the corresponding requirement and whole-phase verification remain open. The immediate execution command after planning is `$gsd-execute-phase 253 --gaps-only`; after accepted reconciliation, run unfiltered `$gsd-execute-phase 253` for phase verification.
