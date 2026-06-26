---
phase: 202
slug: audit-surfaces-elevation
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| {N}-01-01 | 01 | 1 | AUDIT-{XX} | — | N/A | unit | `{command}` | ✅ / ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Populated by the planner per the RESEARCH.md `## Validation Architecture` map (pagination ExUnit test; `assertAuditResultEquivalence` lockstep; glossary-clean; ledger monotonic-guard parse; CSS triple-copy golden-diff; snapshot-recapture-gate routing).*

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (ExUnit)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
