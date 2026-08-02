---
phase: 234
slug: hygiene-supply-chain-and-contributor-dx
status: draft
nyquist_compliant: false
wave_0_complete: false
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

### Command Receipts

| Command | UTC completed | Exit | Output SHA-256 |
|---------|---------------|------|----------------|
| `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence` | 2026-08-02T01:30:12Z | 0 | `d73f67004509eb9b93972c78711dcba84745ff413cf8a0f51b3f0cb4f37e0b2e` |
| `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs` | 2026-08-02T01:30:18Z | 0 | `cb13166255c4fba8ccc28ac13546784691f08ce1fb6a1de60155f04b129b2202` |
| `mix test test/sigra/planning/` | 2026-08-02T01:30:22Z | 0 | `fd83aca755ee3115d25b880de56fc3fa5fc1b7fde83cf50f8714fd458e645efe` |
| `mix format --check-formatted` | 2026-08-02T01:30:25Z | 0 | `f57af136af7f075eeff02cdd79d93b53a43a23a8e10470c001497b37945575ae` |
| `test -z "$(git diff --name-only -- test/fixtures/install_golden/tree)" && mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` | 2026-08-02T01:31:38Z | 1 | `6d0d43c1d782ac1777467a54bd16be683d8042feadcbfbd1d403a1c8a43cebe3` |

The command receipts above are sanitized hashes only; captured output paths, session credentials, cookies, and environment values are not recorded.

**Approval:** blocked — Dependabot residual: all three configured ecosystem slots remain `failed` in `234-EVIDENCE.json` because an authenticated GitHub browser session was unavailable to capture per-ecosystem job logs. golden fixture residual: the required golden/idempotency command exits 1 because the generated `config/dev.exs` is 2,679 bytes while the committed fixture is 3,252 bytes. `status: draft`, `nyquist_compliant: false`, and `wave_0_complete: false` are intentionally retained until both residuals are resolved.
