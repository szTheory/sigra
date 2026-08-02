---
phase: 234
slug: hygiene-supply-chain-and-contributor-dx
status: complete
nyquist_compliant: true
wave_0_complete: true
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
| `mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence` | 2026-08-02T03:14:13Z | 0 | `2a856f6f9709eed0a703870243c482853172bc578a58b37646161c184dc4137b` |
| `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs` | 2026-08-02T03:14:14Z | 0 | `366f74d4ca75c0efe4bd6ecf793f83f33468de2f4564916c118c26c083a632cf` |
| `mix test test/sigra/planning/` | 2026-08-02T03:14:15Z | 0 | `b84eaf48334b7f94d126da493549748bad63344f9ead3fc9d1b0c0affd23b94b` |
| `mix format --check-formatted` | 2026-08-02T03:14:15Z | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `test -z "$(git diff --name-only -- test/fixtures/install_golden/tree)" && mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs` | 2026-08-02T03:15:28Z | 0 | `876af7d027415647005842183d1643cacb5594610a90dc70ee6b64e422c6e42d` |

The command receipts above are sanitized hashes only; captured output paths, session credentials, cookies, and environment values are not recorded.

**Approval:** approved — machine evidence ratified at 2026-08-02T03:15:28Z; exact five-command receipt inventory, Wave 0/task rows, immutable service receipts, and all final evidence slots are green at this commit snapshot. Approval receipt SHA-256: `876af7d027415647005842183d1643cacb5594610a90dc70ee6b64e422c6e42d`.
