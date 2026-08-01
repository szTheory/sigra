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
| 234-01-01 | 01 | 1 | DX-01 | T-234-01 | Golden fixtures remain byte-owned while local and CI gates share one alias | structural + integration | focused Phase 198/234 contract; `mix format --check-formatted`; `mix ci` | ❌ W0 | ⬜ pending |
| 234-02-01 | 02 | 1 | DX-02 | Release-critical actions are immutable, dereferenced SHA pins with version comments | structural | focused Phase 234 guard | ❌ W0 | ⬜ pending |
| 234-03-01 | 03 | 1 | DX-03 | Dependabot ecosystems, directories, schedules, manifests, and locks reconcile exactly | structural | focused Phase 234 guard | ❌ W0 | ⬜ pending |
| 234-04-01 | 04 | 1 | DX-04 | Every live Playwright spec has a resolvable CI owner and no stale inventory row survives | reconciliation | focused Phase 234 guard | ❌ W0 | ⬜ pending |
| 234-05-01 | 05 | 2 | DX-06 | Closure uses a current successful gallery receipt or a durable tracked defect | evidence contract + live CI | focused evidence test; `gh run view <run-id>` | ❌ W0 | ⬜ pending |

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
