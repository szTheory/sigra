---
phase: 25
slug: fix-sigra-upgrade-duplicate-migration-version-bug-and-restor
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` (already configured for live Postgres) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/upgrade_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~5s (unit only) / ~90s (full library suite) / ~200s (full + integration tests post-unskip) |

---

## Sampling Rate

- **After every task commit:** Run quick command (unit suite on `test/sigra/upgrade_test.exs`)
- **After every plan wave:** Run full library suite (`mix test`)
- **Before `/gsd-verify-work`:** Full suite green + `test/upgrade_test.exs` 3 tests pass (0 skipped)
- **Max feedback latency:** ~5 seconds (unit) / ~90 seconds (full)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 01 | 1 | Bug B regression | — | N/A | unit | `mix test test/sigra/upgrade_test.exs` | ✅ (existing) | ⬜ pending |
| 25-01-02 | 01 | 1 | Bug B fix | — | N/A | unit | `mix test test/sigra/upgrade_test.exs` | ✅ (existing) | ⬜ pending |
| 25-02-01 | 02 | 2 | Bug A fix + un-skip | — | N/A | integration | `mix test test/upgrade_test.exs` | ✅ (existing) | ⬜ pending |
| 25-02-02 | 02 | 2 | Full suite parity | — | N/A | full | `mix test` | ✅ (existing) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Task IDs are placeholders — planner owns the final mapping.*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. `test/sigra/upgrade_test.exs` and `test/upgrade_test.exs` already exist and are compiling against the live Postgres container (`sigra-uat-postgres` on :5432). No new test-framework install required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CI parity post-merge | Full suite green in `library_tests` job | CI env differs from local only in runner OS + container age | After merging Phase 25 PR, watch `gh pr checks` → verify `library_tests` reports `0 failures, 0 skipped` and includes the 3 `Sigra.UpgradeIntegrationTest` tests in the count |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (full suite)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
