---
phase: "250"
slug: "close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat"
status: validated
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-10"
---

# Phase 250 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash fixture tests, ExUnit workflow contract tests, Node.js closeout validator, `actionlint` |
| **Config file** | `.github/workflows/*.yml`, `mix.exs`, phase-local closeout validators |
| **Quick run command** | `bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh` |
| **Full suite command** | `bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh && mix test test/sigra/planning/phase_248_release_gate_contract_test.exs test/sigra/planning/phase_248_release_observer_contract_test.exs && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` |
| **Estimated runtime** | ~2 minutes locally; hosted canary duration is bounded by the source workflow timeout |

## Sampling Rate

- **After every task commit:** Run the focused check owned by that task; receipt and observer changes use the quick run command above.
- **After every plan wave:** Run the full suite command and `actionlint` for every changed workflow.
- **Before `$gsd-verify-work`:** Re-run all focused contract tests, the strict owner-verification/milestone validators, and the hosted canary retrieval check.
- **Max feedback latency:** 120 seconds locally; hosted run waits use one watcher per run at 60-second intervals.

## Per-Task Verification Map

The task IDs below are plan/task coordinates (`250-{plan}-{task}`). Statuses distinguish local fixture/integrity coverage from blocked external acceptance evidence. Commands are copied from each plan task's `<automated>` verifier; outcomes and limitations are sourced from the committed plan summaries and the current Phase 250 evidence.

| Task ID and name | Plan | Wave | Original owner requirement(s) | Threat ref / secure behavior | Automated command | Current status |
|------------------|------|------|-------------------------------|-----------------------------|-------------------|----------------|
| 250-01-01 — Task 1: Wire one complete dual-outcome canary tracer | 01 | 1 | AUTO-02 | T-250-01–04, T-250-SC — trusted observer uses exact workflow allowlists and never runs source artifacts; cancellation is exact-run-only; receipts bind full source/artifact identity and omit credentials. | `bash scripts/ci/release-canary.sh --self-test && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh && actionlint .github/workflows/release-receipt-canary.yml .github/workflows/release-receipt-canary-controller.yml .github/workflows/release-run-observer.yml` | PASS — fresh canary, receipt, and observer suites pass 34/15/22; prior actionlint and canary self-test evidence remains recorded in 250-01 summary. |
| 250-01-02 — Task 2: Lock down canary identity and cancellation boundaries with fixtures | 01 | 1 | AUTO-02 | T-250-01–04, T-250-SC — reject malformed or misbound canary receipts, production/canary namespace crossover, and cancellation of any non-canary or non-waiting run; keep production identity matching unchanged. | `bash scripts/ci/release-canary.test.sh && mix test test/sigra/planning/phase_250_canary_contract_test.exs` | PASS — fresh canary fixtures pass 34/34; the TAP wrapper's `mix test` child is blocked by a Phoenix lock mismatch, while the Phase 250 and Phase 248 ExUnit contract files pass standalone 7/7. Exact-main CI run 38060050307 remains separate historical evidence. |
| 250-01-03 — Task 3: Capture the exact hosted proof and fail closed on unavailable Actions evidence | 01 | 1 | AUTO-02 | T-250-02–04, T-250-SC — read-only preflight; exact run/artifact IDs and digests; never expose credentials; missing hosted evidence remains blocked. | `bash scripts/ci/release-canary.test.sh && bash scripts/ci/release-canary.sh --validate-proof .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PROOF.json` | BLOCKED — local fail-closed proof behavior is covered; hosted failure artifact is absent, cancellation was not dispatched, and the authorized retry is consumed. |
| 250-02-01 — Task 1: Reconcile authorization and one immutable candidate tuple | 02 | 2 | READY-01, READY-02 | T-250-05, T-250-06, T-250-SC — require immutable approval of the exact tuple; independently bind full SHAs, source blobs, CI attempt and dry-run; absent approval stays blocked. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs && node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | PASS — fresh 14-test verifier and 25-test owner-validator suites pass; live approval/tuple evidence remains unsatisfied. |
| 250-02-02 — Task 2: Write the canonical Phase 247 verifier from the captured join | 02 | 2 | READY-01, READY-02 | T-250-06, T-250-07, T-250-SC — retain exact evidence identities and captured time; report missing joins as unsatisfied rather than inheriting claims from a summary. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-report .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md` | PASS — fresh verifier suite passes 14/14 and 247 report integrity returns valid with verdict/blocker/identity checks matching; READY-01/02 remain unsatisfied. |
| 250-03-01 — Task 1: Re-query Phase 248's exact environment, source and receipt identities | 03 | 2 | AUTO-01, AUTO-02 | T-250-08, T-250-09, T-250-SC — query secret names and policy only; validate exact run/attempt/SHA/workflow/artifact/observer identity and both hosted outcomes. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.test.mjs && bash scripts/ci/release-environment-preflight.test.sh` | PASS — fresh 10-test verifier and 9-test environment-preflight suites pass; AUTO-01 is supported by name/policy/source evidence. AUTO-02 remains externally blocked. |
| 250-03-02 — Task 2: Refresh the canonical Phase 248 report without hiding historical gaps | 03 | 2 | AUTO-01, AUTO-02 | T-250-09, T-250-10, T-250-SC — bind a fresh report to captured identities, retain the prior result as history, and leave either owner requirement unsatisfied if current evidence fails. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs --check-report .planning/phases/248-exact-source-release-gate/248-VERIFICATION.md && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh` | PASS — fresh report check passes with AUTO-02 unsatisfied, and receipt/observer suites pass 15/22; hosted failure/cancellation receipts remain absent. |
| 250-04-01 — Task 1: Independently join public, historical terminal and post-canary main evidence | 04 | 3 | REL-01, REL-02 | T-250-11, T-250-12, T-250-SC — verify package/source and historical-main identities separately from current post-canary main and inventory. | `bash scripts/ci/release-public-proof.test.sh && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs && node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs` | PASS — fresh public-proof 60/60, closeout 60/60, and Phase 249 verifier 9/9 pass; live current-main and PR blockers keep REL-02 unsatisfied. |
| 250-04-02 — Task 2: Refresh Phase 249 verification and retain the accepted-loss record | 04 | 3 | REL-01, REL-02 | T-250-12, T-250-13, T-250-SC — independently capture package, historical-main and current-main evidence; describe the authorized HANDOFF loss as accepted-with-recorded-loss, never recovered or preserved. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs --check-report .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` | BLOCKED — fresh report check and one retry both report `public release identity changed since capture`; diagnosis isolates source URL HTTP 503 while Hex checksum/version, docs, and tag/source SHA still match. Closeout tests pass 60/60 separately. |
| 250-05-01 — Task 1: Reconcile original owner summaries and requirement rows | 05 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | T-250-14, T-250-16, T-250-SC — retain original requirement ownership; update statuses only when canonical owner verifiers pass; preserve accepted-loss and all three distinct source identities. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-report .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs --check-report .planning/phases/248-exact-source-release-gate/248-VERIFICATION.md && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs --check-report .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md` | BLOCKED — 247/248 report checks pass; 249 check is blocked by source endpoint HTTP 503; READY-01/02, AUTO-02, and REL-02 remain unsatisfied. |
| 250-05-02 — Task 2: Add a narrow cross-owner freshness and contradiction gate | 05 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | T-250-14, T-250-15, T-250-SC — reject duplicate/orphaned ownership, stale refs, contradictory outcomes, and accepted-loss language that claims recovery. | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources` | PASS — 10 hostile fixtures pass; source audit exits 0 with `gaps_found` at 5/9, retaining owner evidence gaps. |
| 250-05-03 — Task 3: Run the strict milestone audit as the final acceptance gate | 05 | 4 | READY-01, READY-02, AUTO-01, AUTO-02, REL-01, REL-02 | T-250-14–16, T-250-SC — generate the audit from passing owner evidence, reject hand-edited/stale 9/9, and persist only sanitized identities. | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md && test -z "$(git status --porcelain=v1 --untracked-files=all)"` | BLOCKED — integrity check is valid with 31 blockers, but the strict source audit remains `gaps_found` at 5/9. |

## Fresh Post-Fix Regression Gate

The full bounded command inventory, individual exit status, emitted test count, elapsed time, output digest, report-integrity results, and source-identity comparison are recorded in `250-REGRESSION-EVIDENCE.json`. All four Phase 250 verifier suites pass (43 tests total); the prior Phase 247 owner validator, Phase 249 closeout validator, and preservation suite pass (88 tests total). Exact-source, CI-gate, candidate, environment, receipt, observer, public-proof, and canary shell suites pass. The standalone Phase 250 and Phase 248 ExUnit contracts pass 7/7. The TAP wrapper cannot invoke `mix test` because the locked Phoenix dependency is out of date; no dependency fetch was attempted.

The fresh Phase 247 and Phase 248 report checks are valid. The Phase 249 report check and its single retry remain blocked: only the validated GitHub source URL diverged, returning HTTP 503 instead of the captured 200; Hex version/checksum, versioned docs, and the `v1.6.0` tag-to-package-source SHA still match. The owner report and source snapshot remain unchanged. Traceability source audit and milestone integrity check are valid as computations, but the underlying audit remains `gaps_found` at 5/9 requirements with 31 blockers. Hosted canary failure and cancellation evidence remains absent, so `nyquist_compliant: false` and `wave_0_complete: false` remain unchanged.

## Wave 0 Requirements

- [x] Focused controller/canary fixtures cover source/workflow identity, run/attempt/SHA binding, artifact digest, credential-key rejection, wrong-run retrieval, and safe cancellation.
- [x] Production receipt validation rejects canary envelopes while production observer matching remains unchanged.
- [x] Read-only environment and Actions metadata preflights are recorded without secret values; missing terminal artifacts remain explicit blockers.
- [ ] Hosted failure and cancellation artifacts remain absent. The single authorized retry is consumed; no new dispatch is authorized.

## Manual-Only Verifications

No manual-only verification is used. Local fixture and checker coverage is complete; hosted receipt delivery and unresolved owner evidence remain blocked external proof, never waived through UAT.

## Validation Sign-Off

- [x] All tasks have automated checks; blocked outcomes are tied to explicit external evidence dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Wave 0 local fixture references are covered; hosted proof remains explicitly missing.
- [x] No watch-mode flags.
- [x] Local feedback latency is under 120s for focused suites.
- [ ] `nyquist_compliant: true` set in frontmatter after execution validation

**Approval:** validated with external evidence blockers; no human-only substitute accepted.

## Validation Audit 2026-10-10

| Metric | Count |
|---|---|
| Gaps found | 3 |
| Resolved | 9 |
| Escalated | 3 |

## Validation Audit 2026-10-10

| Metric | Count |
|---|---|
| Gaps found | 4 |
| Resolved | 8 |
| Escalated | 4 |

## Gap-closure plan mappings — 250-06 through 250-12

These rows extend the original twelve-task map; none is execution evidence yet. Plans 06–12 carry `gap_closure: true`, so `--gaps-only` selects them without repeating completed Plans 01–05. Each plan task has its own `<automated>` command immediately followed by `<fails_when>`; the commands below are a compact execution index, not a waiver. The six source gaps and eleven spec-less edge rows are mapped in `250-GAP-PLAN-COVERAGE.md`.

| Task | Wave | Original owner requirement | Threat | Automated gate from plan | Planning status |
|---|---:|---|---|---|---|
| 250-06-01 failure-path tracer | 2 | AUTO-02 | T-250-17/18 | `bash scripts/ci/release-canary.test.sh` | PLANNED; historical hosted proof blocked |
| 250-06-02 safe cancellation and scoped rollout | 2 | AUTO-02 | T-250-17/18 | `bash scripts/ci/release-canary.test.sh && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/release-observer.test.sh && actionlint .github/workflows/release-receipt-canary.yml .github/workflows/release-receipt-canary-controller.yml .github/workflows/release-run-observer.yml` | PLANNED; no new dispatch authorized here |
| 250-07-01 exact preflight/authority packet | 3 | AUTO-01/02 | T-250-19/20 | `bash scripts/ci/release-canary.test.sh && bash scripts/ci/release-canary.sh --self-test && actionlint .github/workflows/release-receipt-canary.yml .github/workflows/release-receipt-canary-controller.yml .github/workflows/release-run-observer.yml` | PLANNED; read-only |
| 250-07-02 bounded hosted decision | 3 | AUTO-02 | T-250-19 | `jq -e '.repository == "szTheory/sigra" and .dispatch_attempted == false and .credential_values_recorded == false' .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PREFLIGHT.json` | PLANNED; explicit new authority required |
| 250-07-03 hosted pair and Phase 248 | 3 | AUTO-01/02 | T-250-19/20 | Hosted proof validation, owner `--check-report`, and `jq` asserting AUTO-01/02 satisfied with zero snapshot blockers | PLANNED; real hosted artifacts required for task completion |
| 250-08-01 tuple packet | 3 | READY-01/02 | T-250-21/22 | Both owner fixture suites and `jq` requiring at least one eligible tuple with retrievable exact-candidate browser source | PLANNED; parent run 37800067568/job/artifact and matching dry-run 37803817504 are acquisition targets; child run is supplemental only |
| 250-08-02 exact tuple decision | 3 | READY-01/02 | T-250-21 | Verifier fixtures and `jq` requiring approved packet-bound eligible exact tuple | PLANNED; no approval before a fully grounded route |
| 250-09-01 approved source join | 4 | READY-01 | T-250-23 | Verifier fixtures and `jq` requiring same-candidate CI/browser/dry-run identities and passing results in approval record | PLANNED; exact-candidate historical source required |
| 250-09-02 READY dispositions/ledger | 4 | READY-01/02 | T-250-23/24 | Owner validator fixtures and final `validate-release-readiness.mjs --stage final` | PLANNED; both READY joins required |
| 250-09-03 READY owner report | 4 | READY-01/02 | T-250-23/24 | `verify-247-readiness.mjs --check-report` and `jq` asserting passed, READY-01/02 satisfied and zero reconciliation blockers | PLANNED; integrity-valid blocked report cannot pass |
| 250-10-01 public/current diagnostic | 4 | REL-01/02 | T-250-25/26 | `bash scripts/ci/release-public-proof.test.sh && node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs` | PLANNED; prior source HTTP 503 remains blocked |
| 250-10-02 mobile admin-eval repair | 4 | REL-02 | T-250-26 | Focused five mobile cases; `SIGRA_EXAMPLE_URL=http://localhost:4011 bash scripts/ci/admin-eval-harness.sh` with DB/example LiveView ready; `phase-250-main-ci-gate.sh` requiring exact protected-main workflow attempt and all applicable jobs successful | PLANNED; full harness and whole workflow required |
| 250-10-03 REL dispositions/report | 4 | REL-01/02 | T-250-25/26/27 | Owner fixtures, fresh `--check-report`, and evaluated REL-01/02 satisfied with zero blockers | PLANNED; five PRs and whole CI must close |
| 250-11-01 READY summary reconciliation | 5 | READY-01/02 | T-250-28/29 | `jq` requiring both READY owner verdicts satisfied/zero blockers, then traceability source check | PLANNED; passing READY owner required |
| 250-11-02 AUTO/requirements reconciliation | 5 | all six | T-250-28/29 | Traceability fixtures, `jq` requiring AUTO-01/02 and REL-01/02 satisfied/zero blockers, then source check | PLANNED; all owner passes required before marker promotion |
| 250-11-03 Mix TAP wrapper | 5 | all six validation | T-250-29 | `node --test scripts/ci/phase-250-contract.tap.test.mjs` | PLANNED; exact-lock wrapper pass required, current mismatch interrupts |
| 250-12-01 early REL summaries | 6 | REL-01/02 | T-250-30/31 | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` | PLANNED; no false historical completion |
| 250-12-02 terminal REL summaries/validation | 6 | REL-01/02 | T-250-30/31 | Source audit `jq` gate requiring passed, 9/9, zero blockers/orphans/contradictions | PLANNED; every source must pass before audit write |
| 250-12-03 final strict audit | 6 | all six | T-250-30/31 | `--check-audit` JSON must be valid, passed, 9/9, zero blockers/errors; fresh `--check-sources` must also be passed, 9/9, zero blockers/orphans/contradictions | PLANNED; integrity-valid 5/9 is explicitly a failing completion gate |

All hosted checks remain unexecuted during planning. The current `nyquist_compliant: false` and `wave_0_complete: false` markers remain unchanged. The controller authorization and candidate-tuple decision are execution-time authority gates, not manual test substitutes. Their absence keeps AUTO-02/READY-01/02 unsatisfied and interrupts dependent execution. An integrity-valid owner report or audit with unsatisfied requirements cannot complete a task. The final audit is the last mutation and must be source-derived passed 9/9 with zero blockers before phase verification can claim completion.
