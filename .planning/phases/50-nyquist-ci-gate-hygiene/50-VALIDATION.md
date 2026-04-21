---
phase: 50
slug: nyquist-ci-gate-hygiene
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for Nyquist batch **41–44** closure + CI gate hygiene (process only).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`MIX_ENV=test`) |
| **Config file** | `test/test_helper.exs` (no default tag excludes) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` (matches CI `library_tests` step) |
| **Estimated runtime** | ~3–15 minutes (includes `phx_new` scaffolding in golden tests) |

---

## Sampling Rate

- **After Wave 1 commits (VALIDATION edits):** `mix format --check-formatted` on touched Elixir files if any; otherwise doc-only greps from plan acceptance.
- **After Wave 2 commits (`mix.exs` / CI):** Run **`mix ci.install_golden`** as defined in **`mix.exs`** after the alias lands.
- **Before `/gsd-verify-work`:** Merge gate block in **`50-VERIFICATION.md`** green on recorded SHA.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | ROADMAP (1) | T-50-01 | No false Nyquist claims | doc / grep | `grep -E "nyquist_compliant:|phase 50|waiver" .planning/phases/41-backup-codes-ga-product-closure/41-VALIDATION.md` | ✅ | ⬜ pending |
| 50-01-02 | 01 | 1 | ROADMAP (1) | T-50-01 | Same | doc / grep | `grep -E "nyquist_compliant:|phase 50|waiver" .planning/phases/42-human-ga-matrix-evidence/42-VALIDATION.md` | ✅ | ⬜ pending |
| 50-01-03 | 01 | 1 | ROADMAP (1) | T-50-01 | Same | doc / grep | `grep -E "nyquist_compliant:|phase 50|waiver" .planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md` | ✅ | ⬜ pending |
| 50-01-04 | 01 | 1 | ROADMAP (1) | T-50-01 | Same | doc / grep | `grep -E "nyquist_compliant:|phase 50|waiver" .planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md` | ✅ | ⬜ pending |
| 50-01-05 | 01 | 1 | D-50-01 | T-50-02 | Policy table public | grep | `grep -q "41" MAINTAINING.md && grep -q "44" MAINTAINING.md` | ✅ | ⬜ pending |
| 50-02-01 | 02 | 2 | ROADMAP (2) | T-50-03 | CI runs cited command | mix | `mix ci.install_golden` | ⬜ W0 | ⬜ pending |
| 50-02-02 | 02 | 2 | D-50-02 | T-50-04 | Timeouts documented | grep | `grep -q "golden_diff\\|install_golden\\|300_000" MAINTAINING.md` | ✅ | ⬜ pending |
| 50-03-01 | 03 | 3 | ROADMAP (3) | T-50-05 | Receipts not fabricated | manual+log | Merge gate in `50-VERIFICATION.md` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [ ] Postgres reachable at **`localhost:5432`** — same as **`CLAUDE.md`** / CI.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| **`50-VERIFICATION.md` merge gate** | ROADMAP (3) | Records human-attested SHA at close | Run printed commands; paste exit lines into **Automated checks run**; set `verified` date. |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` / grep acceptance or Wave 0 deps
- [ ] `mix ci.install_golden` exists and matches **`50-VERIFICATION.md`**
- [ ] No watch-mode flags in merge gate
- [ ] **`50-RESEARCH.md`** §4 constraint respected in **`mix.exs`** alias body
- [ ] `nyquist_compliant: true` in **50-VALIDATION.md** frontmatter only when **`50-VERIFICATION.md`** is honestly green

**Approval:** pending
