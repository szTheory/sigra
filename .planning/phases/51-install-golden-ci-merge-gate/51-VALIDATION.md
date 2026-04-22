---
phase: 51
slug: install-golden-ci-merge-gate
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (CI + planning docs only).

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` |
| **Estimated runtime** | ~5–15 seconds (no subprocess harness in these files) |

## Sampling Rate

- **After every task commit:** Run the quick command above
- **After every plan wave:** Run the full suite command above
- **Before `/gsd-verify-work`:** `mix ci.install_golden` green if `50-VERIFICATION.md` claims **PASS** for the merge gate
- **Max feedback latency:** 60s for structural tests; merge gate excluded from Nyquist sampling cap

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | ROADMAP (2) CI coupling | T-51-01 | Path gate cannot silently shrink vs documented regex | unit | `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` | ✅ | ⬜ pending |
| 51-01-02 | 01 | 1 | ROADMAP (2) parity | T-51-02 | Both jobs use identical diff detector | unit | same | ✅ | ⬜ pending |
| 51-02-01 | 02 | 1 | ROADMAP (1) receipt | T-51-03 | Verification doc cannot claim PASS without grep token | unit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` (updated) | ✅ | ⬜ pending |
| 51-02-02 | 02 | 1 | ROADMAP (3) GA cross-link | T-51-04 | Waived GA rows reference installer substitute | grep | `rg -n "install_golden|ci.install_golden" MAINTAINING.md .planning/v1.4-GA-UAT.md` | ✅ | ⬜ pending |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 stubs.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| Green `mix ci.install_golden` on maintainer machine | ROADMAP (1) | Subprocess + Hex network | Postgres at localhost:5432; run documented merge gate; copy exit code + wall time into `50-VERIFICATION.md` |

## Validation Sign-Off

- [ ] All tasks have automated verify or documented manual merge gate
- [ ] Sampling continuity: structural tests after YAML edits
- [ ] `50-VERIFICATION.md` **PASS** line present before `status: passed`
- [ ] `nyquist_compliant: true` set in frontmatter only when map above is ✅

**Approval:** pending
