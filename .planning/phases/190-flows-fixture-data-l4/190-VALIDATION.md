---
phase: 190
slug: flows-fixture-data-l4
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-17
---

# Phase 190 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright (chromium behavior lane) + ExUnit (seed/Elixir) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example && npx playwright test --project=chromium admin-flow-<persona>` |
| **Full suite command** | `cd test/example && npx playwright test --project=chromium` (behavior lane) + `mix test` (seed/Elixir) |
| **Estimated runtime** | ~60–120 seconds (chromium behavior lane) |

---

## Sampling Rate

- **After every task commit:** Run the per-persona flow spec just authored (`--project=chromium admin-flow-<persona>`)
- **After every plan wave:** Run the full chromium behavior lane + the example admin/seed ExUnit tests
- **Before `/gsd:verify-work`:** Full chromium behavior lane green + `mix run priv/repo/seeds.exs` reproduces all three cases per flow
- **Max feedback latency:** ~120 seconds

---

## Per-Task Verification Map

> Populated by the planner / gsd-nyquist-auditor against the authored tasks. Each FLOW/DATA requirement is verified by deterministic Playwright behavior assertions and seed reproducibility — no manual UAT (zero-human UAT doctrine).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | FLOW-01 | — | scope + return-context preserved across journey | e2e | `npx playwright test --project=chromium admin-flow-*` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | FLOW-02 | — | full keyboard operability, focus return/containment, focus-visible after Tab | e2e | `npx playwright test --project=chromium admin-flow-*` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | FLOW-03 | — | calm reduced-motion (collapsed effect) + theme persists across nav/reload/system-flip + no-flash | e2e | `npx playwright test --project=chromium admin-flow-*` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | DATA-01 | — | each flow's happy/error/boundary reproducible from deterministic seed | integration | `mix run priv/repo/seeds.exs` + flow spec | ✅ (existing seed) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/priv/playwright/tests/helpers/adminFlows.ts` — shared login / navigation / theme / keyboard / LiveView-readiness utilities for the flow specs
- [ ] `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts` — FLOW-01/02/03 + DATA-01 for platform-admin journey
- [ ] `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` — investigator-posture journey
- [ ] `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` — tenant-bounded journey + permission-denied + empty-audit boundary
- [ ] `ADMIN_BEHAVIOR_SPECS` regex update in `playwright.config.ts` so `admin-flow-*` runs on chromium only (RESEARCH gap)

*Existing seed fixture (`Example.Demo.Seeds.run/0`) covers the data cases — enrichment likely unnecessary per RESEARCH.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

*All phase behaviors have automated verification (zero-human UAT).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
