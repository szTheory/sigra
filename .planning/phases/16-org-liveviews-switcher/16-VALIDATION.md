---
phase: 16
slug: org-liveviews-switcher
status: signed-off
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-12
updated: 2026-04-13
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property              | Value                                                             |
| --------------------- | ----------------------------------------------------------------- |
| **Framework**         | ExUnit (Phoenix.LiveViewTest, Phoenix.ConnTest)                   |
| **Config file**       | `test/test_helper.exs`, `test/example/test/test_helper.exs`       |
| **Quick run command** | `mix test --stale`                                                |
| **Full suite command**| `mix test` (library) + `cd test/example && mix test` (example)    |
| **Observed runtime**  | ~62s library, ~0.3s example                                       |

---

## Sampling Rate

- **After every task commit:** `mix test --stale`
- **After every plan wave:** `mix test`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** 30s

---

## Per-Task Verification Map

| Requirement | Plan | Wave | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|------------|------|------|------------|-----------------|-----------|-------------------|--------|
| ORG-UX-01 | 03 | 2 | T-16-03-05 | Create org via Branch A / New form | template-content + integration | `cd test/example && mix test test/example_web/integration/phase_16_integration_test.exs` | ✅ green |
| ORG-UX-02 | 02, 06 | 1, 3 | T-16-02-01 | org_switcher renders in layouts.ex | template-content + integration | `cd test/example && mix test test/example_web/integration/phase_16_integration_test.exs -t phase16` | ✅ green |
| ORG-UX-03 | 02, 06 | 1, 3 | T-16-02-02 | POST /organizations/switch with membership-before-write | template-content + integration | `cd test/example && mix test test/example_web/integration/phase_16_integration_test.exs -t phase16` | ✅ green |
| ORG-UX-04 | 01, 04, 06 | 1, 2, 3 | T-16-04-01 | Settings page renders three sections | template-content + integration | `cd test/example && mix test test/example_web/integration/phase_16_integration_test.exs -t phase16` | ✅ green |
| ORG-UX-05 | 01, 04 | 1, 2 | T-16-04-02 | Soft-delete with typed-confirm + password | template-content | `mix test test/sigra/install/features/organizations_test.exs --only phase16` | ✅ green |
| ORG-UX-06 | 01, 05, 06 | 1, 2, 3 | T-16-05-01 | Members list with last-activity + role badges | template-content + integration | `cd test/example && mix test test/example_web/integration/phase_16_integration_test.exs -t phase16` | ✅ green |
| ORG-UX-07 | 01, 05 | 1, 2 | T-16-05-02 | Role change modal with last-owner guard | template-content | `mix test test/sigra/install/features/organizations_test.exs --only phase16` | ✅ green |
| ORG-UX-08 | 01, 05 | 1, 2 | T-16-05-03 | Remove member with force-logout (SC-4) in Multi | library + template-content | `mix test test/sigra/organizations/context_test.exs --only phase16` | ✅ green |
| ORG-UX-09 | 03, 06 | 2, 3 | T-16-03-01 | Post-signup zero-org lands on /organizations Branch A | SHA256 byte-identity + integration | `cd test/example && mix test test/example_web/integration/phase_16_integration_test.exs -t phase16` | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Library-level Phase 16 changes covered by `test/sigra/**/*phase16*` tests (22 ContextTest + 9 plug/LV + 18 Features.Organizations template-content from Plan 03 + 21 from Plan 04 + 11 from Plan 05)
- [x] Example-app integration coverage landed in `test/example/test/example_web/integration/phase_16_integration_test.exs` (9 tests)
- [x] Full library suite: 1615 tests, 0 failures (baseline preserved)
- [x] Example suite (test env): 20 tests, 0 failures (11 baseline + 9 new)

---

## Manual-Only Verifications

| Behavior                                         | Requirement | Why Manual                           | Test Instructions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------------------------------ | ----------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Visual UI matches UI-SPEC copy/colors            | ORG-UX-01..09 | Pixel-level visual match             | Start the dev server `cd test/example && mix phx.server` then visit `http://localhost:4000/organizations`. Walk through the 6 screens per UI-SPEC §Screen Anatomy; verify headings/copy/badge colors/spacing match exactly. Cover: (1) Branch A zero-state, (2) `/organizations/new` create form, (3) `/organizations/:slug/members` members list, (4) `/organizations/:slug/settings` three sections, (5) progressive-disclosure slug form with 7-day warning banner, (6) danger zone soft-delete form. Verify the organization switcher dropdown opens/closes and shows ACTIVE section + SWITCH TO list + Create / Settings / Manage links.                                                |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s (example suite ~0.3s, library ~62s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** signed-off (Plan 16-06)
