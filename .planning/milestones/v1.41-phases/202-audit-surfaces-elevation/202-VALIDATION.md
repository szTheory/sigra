---
phase: 202
slug: audit-surfaces-elevation
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-26
---

# Phase 202 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Playwright (admin browser specs) |
| **Config file** | `mix.exs` (ExUnit) / `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/admin/` |
| **Full suite command** | `mix test` + admin Playwright projects (chromium/dark/mobile) |
| **Estimated runtime** | ~varies (ExUnit fast; Playwright capture lane longer) |

---

## Sampling Rate

- **After every task commit:** Run `mix test {touched admin test files}`
- **After every plan wave:** Run `mix test test/sigra/admin/` + affected Playwright equivalence specs
- **Before `/gsd-verify-work`:** Full suite + admin browser specs green; recapture idempotency proven
- **Max feedback latency:** ExUnit < ~60s; browser capture lane out-of-band

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 202-01-01 | 01 | 1 | AUDIT-02 | T-202-02 | HEEx auto-escape; no `raw/1` in shared row | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 202-01-02 | 01 | 1 | AUDIT-02 | — | N/A | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 202-01-03 | 01 | 1 | AUDIT-02 | — | N/A | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 202-02-01 | 02 | 2 | AUDIT-01 | T-202U-01 | `return_to` survives once; existing sanitizer preserved; GET-form contract | compile | `cd test/example && mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 202-02-02 | 02 | 2 | AUDIT-01, AUDIT-02 | T-202U-02/03 | shared-component rewire; glossary-clean | compile+unit | `cd test/example && mix compile --warnings-as-errors && cd /Users/jon/projects/sigra && mix test test/sigra/admin/glossary_test.exs` | ✅ | ⬜ pending |
| 202-03-01 | 03 | 2 | AUDIT-01 | T-202I-03 | `<details>` disclosure; GET-form contract; HEEx auto-escape | compile | `cd test/example && mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 202-03-02 | 03 | 2 | AUDIT-01, AUDIT-02 | T-202I-01/02 | shared-component rewire; glossary-clean | compile+unit | `cd test/example && mix compile --warnings-as-errors && cd /Users/jon/projects/sigra && mix test test/sigra/admin/glossary_test.exs` | ✅ | ⬜ pending |
| 202-04-01 | 04 | 3 | AUDIT-02, AUDIT-03 | T-202T-01 | strict un-sliced 2-code guard (loud-fail vacuous pass) | e2e | `cd test/example/priv/playwright && npx playwright test admin-design.spec.ts --grep "content-equivalent"` | ✅ | ⬜ pending |
| 202-04-02 | 04 | 3 | AUDIT-02 | T-202T-02 | deterministic pagination proof, no dev seeds | unit | `cd test/example && mix test test/example_web/live/admin_audit_index_live_test.exs` | ✅ | ⬜ pending |
| 202-05-01 | 05 | 4 | AUDIT-03 | T-202R-01/02/03 | bare-`2` ledger ratchet; monotonic guard; CSS triple-copy parity | guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ | ⬜ pending |
| 202-05-02 | 05 | 4 | AUDIT-03 | — | Audit Explorer archetype; glossary-clean | grep+unit | `grep -c "Audit Explorer Archetype" guides/reference/admin-design-contract.md && mix test test/sigra/admin/glossary_test.exs` | ✅ | ⬜ pending |
| 202-05-03 | 05 | 4 | AUDIT-03 | T-202R-04 | audit baselines recaptured + canary byte-stable (git assertions) | gate | `bash -n scripts/ci/snapshot-recapture-gate.sh` + git-status audit/canary byte assertions (see plan) | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Populated from each plan's `<automated>` verify block per the RESEARCH.md `## Validation Architecture` map (pagination ExUnit test; `assertAuditResultEquivalence` lockstep + strict un-sliced 2-code guard; glossary-clean; ledger monotonic-guard parse; CSS triple-copy golden-diff; snapshot-recapture-gate routing with byte-level git assertions). Every task carries an automated verify — no Wave-0 scaffolding gap.*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements (ExUnit admin LiveView tests + Playwright admin specs already exist). Net-new: the deterministic ExUnit pagination test (D-10) and the revised equivalence selectors (D-06).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tier-2 motion-tokens / density-rhythm / target-size ≥24px proxies | AUDIT-03 | Documented-as-manual Tier-2 Add-on proxies (admin-fractal-scorecard.md) | Cite as manual proxy evidence in the ledger cells per D-11 |

*Remaining audit behaviors have automated verification (ExUnit + Playwright equivalence + glossary + golden-diff + recapture idempotency).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (all 11 tasks carry an automated command; no MISSING references)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has one)
- [x] Wave 0 covers all MISSING references (none — existing ExUnit + Playwright infrastructure covers all requirements; net-new tests are first-class tasks in 202-04)
- [x] No watch-mode flags
- [x] Feedback latency < 60s (ExUnit compile/unit tasks; Playwright/recapture lanes run out-of-band by design)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — Per-Task Verification Map populated from plan `<automated>` blocks; every task has an automated verify.
