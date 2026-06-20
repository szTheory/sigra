---
phase: 198
slug: contributor-dx-acceptance-gate
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-20
---

# Phase 198 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This phase is CI/DX/docs — its "tests" are the repo's contract-lock tests plus the
> committed acceptance evidence itself. `mix ci` (delivered here) is the local mirror.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir ~> 1.18 / 1.19.5) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/planning/` (contract locks — no PG needed) |
| **Full suite command** | `mix test` (needs Postgres + phx_new 1.8.7 archive) |
| **Local mirror (new)** | `mix ci` (this phase delivers it) |
| **Estimated runtime** | ~5s quick (contract locks) · full suite multi-minute |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/planning/` (contract locks)
- **After every plan wave:** Run `mix ci` (the new local mirror) where prereqs are present
- **Before closeout:** Acceptance evidence (`198-ACCEPTANCE.md`) committed with real numbers
- **Max feedback latency:** ~5s for contract locks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 198-DX-01 | mix-ci | 1 | DX-01 | — | N/A | structural | `mix ci` runs green locally (PG + 1.8.7) | ❌ W0 | ⬜ pending |
| 198-DX-02 | mix-ci | 1 | DX-01 | — | N/A | doc-contract | contract test asserts CONTRIBUTING mentions `mix ci` | ❌ W0 | ⬜ pending |
| 198-GATE-01 | acceptance | 2 | GATE-01 | — | N/A | evidence | author `198-ACCEPTANCE.md` from `gh run view --json jobs` | ❌ W0 | ⬜ pending |
| 198-GATE-02a | guard | 2 | GATE-02 | — | N/A | assertion | `gh api .../rulesets/14941512 --jq '...'` == 5 known names | ✅ | ⬜ pending |
| 198-GATE-02b | guard | 2 | GATE-02 | — | N/A | unit | `mix test test/sigra/planning/phase_51*_test.exs phase_192*_test.exs` | ✅ | ⬜ pending |
| 198-GATE-02c | guard | 2 | GATE-02 | — | N/A | shell | `bash scripts/ci/snapshot-canary-guard.sh` | ✅ | ⬜ pending |
| 198-GATE-02d | re-gate | 2 | GATE-02 | — | N/A | unit/CI | ci.yml contract tests green after design-gallery hard re-gate | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `mix ci` alias in `mix.exs` — covers DX-01.
- [ ] CONTRIBUTING.md section documenting `mix ci` + prereqs (PG, phx_new 1.8.7) + CI-only-lane caveats — covers DX-01.
- [ ] `198-ACCEPTANCE.md` with real before/after numbers (wall-clock, p95, flake) — covers GATE-01.
- [ ] `phase_198_*_contract_test.exs` locking `mix ci` presence in mix.exs + CONTRIBUTING mention — consistent with the repo's contract-lock pattern; recommended so `mix ci` can't silently drift out of CONTRIBUTING.
- [ ] Remove `continue-on-error: true` at ci.yml:1047 + restore `design_gallery` to the aggregator loop (D-06), behind a confirm-green step.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real "after" CI timings captured | GATE-01 | Requires actual post-197 CI runs on GitHub; numbers are the phase work, not synthesizable locally | Run `gh run view <id> --json jobs` against post-197 PR-path runs; record in `198-ACCEPTANCE.md` |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s for contract locks
- [ ] `nyquist_compliant: true` set in frontmatter (set by planner/executor)

**Approval:** pending
