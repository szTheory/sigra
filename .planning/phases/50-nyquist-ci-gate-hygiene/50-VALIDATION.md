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
| **Phase 50 doc/CI contract (fast)** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` (matches CI `library_tests` step) |
| **Estimated runtime** | ~3–15 minutes (includes `phx_new` scaffolding in golden tests) |

---

## Sampling Rate

- **After Wave 1 commits (VALIDATION edits):** `mix format --check-formatted` on touched Elixir files if any; otherwise doc-only greps from plan acceptance.
- **After Wave 2 commits (`mix.exs` / CI):** Optional local **`mix ci.install_golden`**; authoritative green is **`install_golden_contract`** on **`main`** (required check — see **`MAINTAINING.md`**).
- **Before `/gsd-verify-work`:** Required **`Install golden + idempotency contract (subprocess harness)`** check green on **`main`**; **`50-VERIFICATION.md`** documents CI-as-truth (no pasted PASS row).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | ROADMAP (1) | T-50-01 | No false Nyquist claims | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:21` (batch **41–44** marker regex) | ✅ | ✅ green |
| 50-01-02 | 01 | 1 | ROADMAP (1) | T-50-01 | Same | ExUnit | same file/line as **50-01-01** | ✅ | ✅ green |
| 50-01-03 | 01 | 1 | ROADMAP (1) | T-50-01 | Same | ExUnit | same file/line as **50-01-01** | ✅ | ✅ green |
| 50-01-04 | 01 | 1 | ROADMAP (1) | T-50-01 | Same | ExUnit | same file/line as **50-01-01** | ✅ | ✅ green |
| 50-01-05 | 01 | 1 | D-50-01 | T-50-02 | Policy table public | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:34` | ✅ | ✅ green |
| 50-02-01 | 02 | 2 | ROADMAP (2) | T-50-03 | CI runs cited command | ExUnit + mix | Structure: `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:41`; **full subprocess harness:** `mix ci.install_golden` / `install_golden_contract` (see `50-VERIFICATION.md` §CI attestation) | ✅ | ✅ green |
| 50-02-02 | 02 | 2 | D-50-02 | T-50-04 | Timeouts documented | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:55` | ✅ | ✅ green |
| 50-02-41 | 02 | 2 | D-50-01 | T-50-10 | 41 cites installer contract | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:60` | ✅ | ✅ green |
| 50-02-42 | 02 | 2 | D-50-01 | T-50-10 | 42 waiver + `nyquist_compliant: false` | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:65` | ✅ | ✅ green |
| 50-02-43 | 02 | 2 | D-50-01 | T-50-10 | 43/44 MAINTAINING + VERIFICATION pointers | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:72` | ✅ | ✅ green |
| 50-02-50v | 02 | 2 | D-50-04 | T-50-11 | `50-VERIFICATION.md` CI attestation template | ExUnit | `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs:83` | ✅ | ✅ green |
| 50-03-01 | 03 | 3 | ROADMAP (3) | T-50-05 | Receipts not fabricated | policy + CI | `50-VERIFICATION.md` + branch protection runbook (`MAINTAINING.md`) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [ ] Postgres reachable at **`localhost:5432`** — same as **`CLAUDE.md`** / CI.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| **`50-VERIFICATION.md` merge gate** | ROADMAP (3) | CI-as-truth on `main` | Enable required check per **`MAINTAINING.md`**; optional local **`mix ci.install_golden`** for debugging only. |

---

## Validation Audit 2026-04-21

| Metric | Count |
|--------|-------|
| Gaps found | 8 (map rows were pending with no ExUnit anchor) |
| Resolved | 8 (added `test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` + map refresh) |
| Escalated | 0 |

---

## Validation Sign-Off

- [x] All tasks have `<verify>` / grep acceptance or Wave 0 deps (automated slice via ExUnit; **50-03-01** satisfied by CI-as-truth policy)
- [x] `mix ci.install_golden` / **`install_golden_contract`** documented in **`50-VERIFICATION.md`** and asserted in ExUnit
- [x] No watch-mode flags in merge gate
- [x] **`50-RESEARCH.md`** §4 constraint respected in **`mix.exs`** alias body (two explicit test paths only)
- [ ] `nyquist_compliant: true` in **50-VALIDATION.md** frontmatter only when team elevates phase Nyquist posture

**Approval:** complete for verification-doc refresh — machine attestation is **required `install_golden_contract`** on `main` (see **`MAINTAINING.md`**)
