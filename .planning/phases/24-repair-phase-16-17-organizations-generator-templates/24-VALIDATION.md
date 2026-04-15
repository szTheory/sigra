---
phase: 24
slug: repair-phase-16-17-organizations-generator-templates
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-14
revised: 2026-04-14
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs`, `mix.exs` |
| **Quick run command** | `mix test test/sigra/install/` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~60 seconds (install suite), ~180 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/install/` (scoped to touched files when possible)
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green + `mix sigra.install --yes` against scratch app completes without compile error
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

> Revised 2026-04-14 — TDD-first wave ordering. Regression tests (Wave 0) land before the fixes (Waves 1-2) so they catch the bug class red-first. Wave 0 verify is scoped to syntactic-only checks (file exists + compiles + defines ≥1 `test`/`describe`). Pass/fail transition is verified on the fix tasks in Waves 1 and 2.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 0 | D-06.1 | T-24-03 | `template_render_test.exs` exists, compiles, and defines at least one test/describe macro (initially RED — will pass after 24-01-04) | unit | `test -f test/sigra/install/template_render_test.exs && mix compile --warnings-as-errors 2>&1 | tail -5` | ✅ (this task creates it) | ⬜ pending |
| 24-01-02 | 01 | 0 | D-06.2 | T-24-04 | `features/coverage_test.exs` exists, compiles, and defines at least one test/describe macro (initially RED — will pass after 24-01-07) | unit | `test -f test/sigra/install/features/coverage_test.exs && mix compile --warnings-as-errors 2>&1 | tail -5` | ✅ (this task creates it) | ⬜ pending |
| 24-01-03 | 01 | 0 | D-06.3 | T-24-03 | `template_syntax_test.exs` exists, compiles, and defines at least one test/describe macro (initially RED — will pass after 24-01-04) | unit | `test -f test/sigra/install/template_syntax_test.exs && mix compile --warnings-as-errors 2>&1 | tail -5` | ✅ (this task creates it) | ⬜ pending |
| 24-01-04 | 01 | 1 | D-01 | T-24-01 | `invitation_accept_live.ex` generator-renders without EEx CompileError; 24-01-01 and 24-01-03 tests transition RED → GREEN for this file | unit | `mix test test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs` | ✅ | ⬜ pending |
| 24-01-05 | 01 | 1 | D-02 | — | Verifies both "missing" templates on disk; `read_template!` succeeds | unit | `mix test test/sigra/install/features/organizations_test.exs` | ✅ | ⬜ pending |
| 24-01-06 | 01 | 2 | D-04.1/.2 | T-24-04 | `organization_invitation_email.ex` moved to `organizations/` + registered in `Features.Organizations.files/1` | unit | `mix test test/sigra/install/features/` | ✅ | ⬜ pending |
| 24-01-07 | 01 | 2 | D-04.3 | T-24-02 | `core/emails.ex` conditional-generates `organization_invitation/4` under `organizations?` flag; comment reworded; 24-01-02 coverage lint transitions RED → GREEN | unit | `mix test test/sigra/install/isolation_test.exs test/sigra/install/features/coverage_test.exs` | ✅ | ⬜ pending |
| 24-01-08 | 01 | 3 | D-05 | T-24-05 | Golden fixture regenerated; diff visually reviewed; `golden_diff_test.exs` green | integration | `mix test test/sigra/install/golden_diff_test.exs` | ✅ | ⬜ pending |
| 24-01-09 | 01 | 3 | D-06.4 | — | `mix sigra.install --yes` leg in `.github/workflows/ci.yml:151-223` passes against scratch app on both `""` and `"--no-organizations"` matrix flags | e2e | `act` run or CI green + static-check grep of ci.yml | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 creates the three regression tests BEFORE any fix lands (TDD-first). Each Wave 0 verify is scoped to syntactic checks only — pass/fail transition is verified on the Wave 1 / Wave 2 fix tasks.

- [ ] `test/sigra/install/template_render_test.exs` — generator-render unit test, one assertion per `organizations/**/*.ex` template. Minimal fixture binding derived from `lib/mix/tasks/sigra.install.ex:97-119` + `migration_timestamps: %{}`. Created by Task 24-01-01. Expected to be RED against the current buggy `invitation_accept_live.ex` — that redness is the proof that the test catches the DEF-18-01 bug class. Transitions GREEN after Task 24-01-04 ships.
- [ ] `test/sigra/install/features/coverage_test.exs` — per-feature file-coverage lint (D-06.2). Created by Task 24-01-02. Expected to be RED against the current `core/` tree because `organization_invitation_email.ex` is orphaned under `core/` (no owner feature). Transitions GREEN after Task 24-01-06 moves the file and registers it under `Features.Organizations.files/1`.
- [ ] `test/sigra/install/template_syntax_test.exs` — HEEx-inside-EEx guard (D-06.3). Created by Task 24-01-03. Expected to be RED against the current `invitation_accept_live.ex`. Transitions GREEN after Task 24-01-04.
- [ ] Verification task for `Features.Organizations.router_injection/1` + `user_auth_on_mount_assign_user_organizations.ex` `read_template!` calls (D-02) — covered by Task 24-01-05 (Wave 1).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Golden fixture diff visual review | D-05 | Rebless requires human confirmation that the diff shape matches the expected file move + conditional-generation output. | 1. Run generator against fixture app. 2. `git diff` fixture tree. 3. Confirm: (a) new file under `organizations/`, (b) updated `emails.ex` output, (c) byte/STDOUT.txt updates only. 4. Bless via fixture rebless runbook in `11-01-SUMMARY.md`. |
| `invitation_accept_live.ex` rendered output unchanged | D-01 | Structural refactor; automated tests confirm compile but not visual parity. | Open generated LiveView in dev, walk all 7 `:branch` states via URL params, confirm DOM matches pre-refactor snapshot. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (verify commands in Tasks 24-01-04, 24-01-07, and 24-01-08 can reference Wave 0 test files because Wave 0 creates them first)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter (raised AFTER the plan ships green and Wave 0 tests have transitioned to GREEN via the Wave 1 / Wave 2 fix tasks)

**Approval:** pending
