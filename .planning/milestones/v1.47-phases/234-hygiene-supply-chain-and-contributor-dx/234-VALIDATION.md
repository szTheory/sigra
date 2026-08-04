---
phase: 234
slug: hygiene-supply-chain-and-contributor-dx
status: validated
nyquist_compliant: true
wave_0_complete: true
reviewed_commit_sha: 46c56e0fc830bd49c6a2da4336a646dce63ba280
reviewed_at: 2026-08-02T15:28:48Z
created: 2026-07-31
---

# Phase 234 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (repository existing) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Measure during Wave 0 and record in execution evidence |

---

## Sampling Rate

- **After every task commit:** Run the focused affected planning contract; when formatter inputs change, also run `mix format --check-formatted` and the installer golden-diff test.
- **After every plan wave:** Run `mix test test/sigra/planning/` plus the relevant deterministic CI guard self-tests.
- **Before `$gsd-verify-work`:** `mix ci` must be green locally and a PR CI lane must invoke that exact alias.
- **Max feedback latency:** Measure the focused commands during Wave 0; split any check that cannot provide task-level feedback promptly.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 234-01-01 | 01 | 1 | DX-01 | T-234-01-01 | Golden fixtures remain byte-owned while local and CI gates share one alias | structural tracer | focused Phase 198 contract | ✅ existing file revised | ✅ green |
| 234-02..04, 11..13 | 02–04, 11–13 | 2 | DX-01 | T-234-02-01 | Six independently reversible 7–8-file batches clear the first 45 non-golden formatter failures | native formatter + compile/tests | scoped checks with exact file lists and golden exclusion | ✅ native tools | ✅ green |
| 234-05-01 | 05 | 3 | DX-01 | T-234-05-01 | Final six files seal repository-wide formatting without generated-byte drift | native formatter + golden tests | repository-wide `mix format --check-formatted` and golden tests | ✅ native tools | ✅ green |
| 234-06-01 | 06 | 1 | DX-02 | T-234-06-01 | Release-critical actions are immutable dereferenced SHA pins with version comments | structural + mutation | focused action-pinning contract | ✅ existing file | ✅ green |
| 234-07-01 | 07 | 1 | DX-03 | T-234-07-01 | Dependabot ecosystems, directories, schedules, manifests, and locks reconcile exactly | structural + mutation | focused Dependabot contract | ✅ existing file | ✅ green |
| 234-08-01 | 08 | 2 | DX-04 | T-234-08-01 | Every live Playwright spec has a resolvable CI owner and no stale inventory row survives | reconciliation | focused Playwright inventory contract + Playwright list | ✅ existing file | ✅ green |
| 234-09-01 | 09 | 4 | DX-01 | T-234-09-01 | Clean-checkout and real PR receipts prove one direct alias owner and the protected aggregate | evidence contract + live CI | focused evidence test; `gh run watch/view` | ✅ receipt | ✅ green |
| 234-10-01 | 10 | 5 | DX-02/DX-03/DX-06 | T-234-10-01 | Release, Dependabot, and gallery claims use GitHub-owned evidence or durable tracked defects | evidence contract + managed services | focused evidence test; bounded CLI/browser polling | ✅ receipt/residual | ✅ green |
| 234-14-01 | 14 | 6 | DX-01/DX-02/DX-03/DX-04/DX-06 | T-234-14-01 | Draft/false validation transitions only after every structural and live receipt is green | sign-off mutation contract | all focused contracts, planning suite, formatter, and golden tests | ✅ existing file | ✅ green |
| 234-19-01 | 19 | 10 | DX-04 | T-234-19-01 | Every direct Playwright inventory row owns its exact invocation | structural contract | mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs | ✅ existing file revised | ✅ green |
| 234-19-02 | 19 | 10 | DX-04 | T-234-19-02 | Only two harness mappings resolve to their exact specs | structural contract | mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs && mix test test/sigra/planning/phase_232_playwright_economics_test.exs | ✅ existing file revised | ✅ green |
| 234-20-01 | 20 | 11 | DX-01/DX-02/DX-03/DX-04/DX-06 | T-234-20-01 | Concrete evidence receipts validate before completion | evidence transition | mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff --only final_evidence | ✅ existing file revised | ✅ green |
| 234-20-02 | 20 | 11 | DX-01/DX-02/DX-03/DX-04/DX-06 | T-234-20-02 | Command and task receipts bind to one reviewed snapshot | sign-off contract | mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff && mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence && mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs | ✅ existing file revised | ✅ green |
| 234-21-01 | 21 | 12 | DX-01/DX-02/DX-03/DX-04/DX-06 | T-234-21-01 | Production completion admits exactly the six named evidence keys and rejects every additional slot | evidence transition | mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff && mix test test/sigra/planning/phase_234_evidence_contract_test.exs && mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs | ✅ existing file revised | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Revise `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` and `test/sigra/planning/phase_233_library_economics_contract_test.exs` for the alias-as-CI-call-through and exact-one-suite-owner contracts.
- [x] Add `test/sigra/planning/phase_234_action_pinning_contract_test.exs` for the release-critical immutable-action contract.
- [x] Add `test/sigra/planning/phase_234_dependabot_contract_test.exs` for the exact Dependabot ecosystem/directory contract.
- [x] Add `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` for live-spec and executable-lane reconciliation.
- [x] Add `test/sigra/planning/phase_234_evidence_contract_test.exs` for local/PR/service receipts and validation-signoff mutation coverage.
- [x] Add the committed Phase 234 Playwright spec-to-lane inventory artifact consumed by the reconciliation guard.
- [x] Add machine-readable receipt slots/evidence for Dependabot update jobs and a current gallery execution.

---

## Manual-Only Verifications

All phase behaviors must have automated evidence. GitHub-owned behaviors may require post-merge service receipts, but those receipts must be collected through deterministic CLI/API polling and committed as machine-readable evidence; they are not manual pass claims.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency is measured and bounded
- [x] Completion transition is blocked while any immutable evidence slot is red
- [x] Wave 12 task 234-21-01 proves the production transition admits exactly the six named evidence keys and rejects every seventh slot.

### Command Receipts

| Command | UTC completed | Exit | Output SHA-256 | Commit SHA |
|---------|---------------|------|----------------|------------|
| `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence` | 2026-08-02T15:25:00Z | 0 | `051efb1434f00fe407203af03eb4d0ca8c4a87aa9115a131de69f1959ada4727` | `46c56e0fc830bd49c6a2da4336a646dce63ba280` |
| `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs --exclude validation_signoff` | 2026-08-02T15:25:05Z | 0 | `17e87ebe0164fae93adf3ab93483f3fc7c9d62516dcc5ea8fe58978d6a814094` | `46c56e0fc830bd49c6a2da4336a646dce63ba280` |
| `mix test test/sigra/planning/ --exclude validation_signoff` | 2026-08-02T15:25:10Z | 0 | `5ad1ca77ecbd3aad78316556a21911d8f5cbf412d14c10c934bb5ce949b3982b` | `46c56e0fc830bd49c6a2da4336a646dce63ba280` |
| `mix format --check-formatted` | 2026-08-02T15:25:15Z | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `46c56e0fc830bd49c6a2da4336a646dce63ba280` |
| `test -z "$(git diff --name-only -- test/fixtures/install_golden/tree)" && mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` | 2026-08-02T15:28:30Z | 0 | `9239c5edce9cd96ba2a5bed5054667aa3c10d999ccab9b9ceba9711898c6dd57` | `46c56e0fc830bd49c6a2da4336a646dce63ba280` |

The command receipts above are sanitized hashes only; captured output paths, session credentials, cookies, and environment values are not recorded.

**Approval:** machine evidence ratified at 2026-08-02T15:28:48Z — Wave 12 tasks 234-19-01, 234-19-02, 234-20-01, 234-20-02, and 234-21-01 are covered by the exact green verification map, refreshed reviewed-snapshot receipts, exact six-slot production-transition behavior, and zero-failure post-population verification.

## Validation Audit 2026-08-04 (Phase 236 canonical reconciliation — blocked)

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 0 |
| Escalated | 1 |

The canonical re-audit first passed all six focused Phase-234 planning contracts (41 tests,
0 failures). It then stopped at the required formatter gate. Exact generated diagnostic:

```text
** (Mix) mix format failed due to --check-formatted.
The following files are not formatted:

/Users/jon/projects/sigra/test/sigra/planning/phase_235_fast_01_remeasurement_contract_test.exs
/Users/jon/projects/sigra/test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
/Users/jon/projects/sigra/test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
```

No Phase-234 lifecycle field was promoted. Per Phase 236 scope, the Phase-235 formatter drift is
retained as an out-of-scope blocker; it was neither edited nor waived. No GitHub evidence was
queried or recaptured.

## Validation Audit 2026-08-04 (Phase 236 canonical reconciliation — passed)

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

The canonical re-audit was resumed after the formatter correction in `40ceb739`. The six focused
Phase-234 planning contracts passed (34 tests, 0 failures, 7 excluded), the repository formatter
passed, the planning suite passed (123 tests, 0 failures, 12 skipped, 7 excluded), and the
install golden-diff/idempotency checks passed. Existing GitHub-owned receipts remain retained;
no GitHub evidence was queried or recaptured. The Phase 236 immutable-evidence contract passed
(3 tests, 0 failures). The successful deterministic result now promotes this artifact to
`status: validated`.
