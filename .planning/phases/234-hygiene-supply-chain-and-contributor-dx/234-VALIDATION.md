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
| **Quick run command** | `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_234_hygiene_contract_test.exs` |
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
| 234-01-01 | 01 | 1 | DX-01 | T-234-01-01 | Golden fixtures remain byte-owned while local and CI gates share one alias | structural tracer | focused Phase 198 contract | ✅ existing file revised | ⬜ pending |
| 234-02..04, 11..13 | 02–04, 11–13 | 2 | DX-01 | T-234-02-01 | Six independently reversible 7–8-file batches clear the first 45 non-golden formatter failures | native formatter + compile/tests | scoped checks with exact file lists and golden exclusion | ✅ native tools | ⬜ pending |
| 234-05-01 | 05 | 3 | DX-01 | T-234-05-01 | Final six files seal repository-wide formatting without generated-byte drift | native formatter + golden tests | repository-wide `mix format --check-formatted` and golden tests | ✅ native tools | ⬜ pending |
| 234-06-01 | 06 | 1 | DX-02 | T-234-06-01 | Release-critical actions are immutable dereferenced SHA pins with version comments | structural + mutation | focused action-pinning contract | ❌ W0 | ⬜ pending |
| 234-07-01 | 07 | 1 | DX-03 | T-234-07-01 | Dependabot ecosystems, directories, schedules, manifests, and locks reconcile exactly | structural + mutation | focused Dependabot contract | ❌ W0 | ⬜ pending |
| 234-08-01 | 08 | 2 | DX-04 | T-234-08-01 | Every live Playwright spec has a resolvable CI owner and no stale inventory row survives | reconciliation | focused Playwright inventory contract + Playwright list | ❌ W0 | ⬜ pending |
| 234-09-01 | 09 | 4 | DX-01 | T-234-09-01 | Clean-checkout and real PR receipts prove one direct alias owner and the protected aggregate | evidence contract + live CI | focused evidence test; `gh run watch/view` | ❌ W0 | ⬜ pending |
| 234-10-01 | 10 | 5 | DX-02/DX-03/DX-06 | T-234-10-01 | Release, Dependabot, and gallery claims use GitHub-owned evidence or durable tracked defects | evidence contract + managed services | focused evidence test; bounded CLI/browser polling | ❌ W0 | ⬜ pending |
| 234-14-01 | 14 | 6 | DX-01/DX-02/DX-03/DX-04/DX-06 | T-234-14-01 | Draft/false validation transitions only after every structural and live receipt is green | sign-off mutation contract | all focused contracts, planning suite, formatter, and golden tests | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Revise `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` for the new alias-as-CI-call-through contract.
- [ ] Add `test/sigra/planning/phase_234_hygiene_contract_test.exs` (or a deterministic `scripts/ci` guard plus self-test) covering action pins, Dependabot shape, and inventory reconciliation.
- [ ] Add the committed Phase 234 Playwright spec-to-lane inventory artifact consumed by the reconciliation guard.
- [ ] Add machine-readable receipt slots/evidence for Dependabot update jobs and a current gallery execution.

---

## Manual-Only Verifications

All phase behaviors must have automated evidence. GitHub-owned behaviors may require post-merge service receipts, but those receipts must be collected through deterministic CLI/API polling and committed as machine-readable evidence; they are not manual pass claims.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency is measured and bounded
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
