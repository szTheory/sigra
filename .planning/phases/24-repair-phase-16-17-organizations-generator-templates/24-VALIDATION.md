---
phase: 24
slug: repair-phase-16-17-organizations-generator-templates
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-14
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

> Task IDs populated by planner — this phase ships as a single plan `24-01`. The map is filled in during planning.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | D-01 | — | `invitation_accept_live.ex` generator-renders without EEx CompileError | unit | `mix test test/sigra/install/template_render_test.exs` | ❌ W0 | ⬜ pending |
| 24-01-02 | 01 | 1 | D-02 | — | Verifies both "missing" templates on disk; `read_template!` succeeds | unit | `mix test test/sigra/install/features/organizations_test.exs` | ❌ W0 | ⬜ pending |
| 24-01-03 | 01 | 2 | D-04 | — | `organization_invitation_email.ex` moved to `organizations/` + registered in `Features.Organizations.files/1` | unit | `mix test test/sigra/install/features/` | ✅ | ⬜ pending |
| 24-01-04 | 01 | 2 | D-04 | — | `core/emails.ex` conditional-generates `organization_invitation/4` under `organizations?` flag; comment at lines 696-700 reworded | unit | `mix test test/sigra/install/isolation_test.exs` | ✅ | ⬜ pending |
| 24-01-05 | 01 | 3 | D-06.1 | — | `template_render_test.exs` walks `organizations/**/*.ex` templates and compiles each rendered output | unit | `mix test test/sigra/install/template_render_test.exs` | ❌ W0 | ⬜ pending |
| 24-01-06 | 01 | 3 | D-06.2 | — | `Features.CoverageTest` asserts every file under `priv/templates/sigra.install/<feat>/` is owned by that feature | unit | `mix test test/sigra/install/features/coverage_test.exs` | ❌ W0 | ⬜ pending |
| 24-01-07 | 01 | 3 | D-06.3 | — | `TemplateSyntaxTest` asserts no `<%= / <%` inside `~H"""` heredocs | unit | `mix test test/sigra/install/template_syntax_test.exs` | ❌ W0 | ⬜ pending |
| 24-01-08 | 01 | 4 | D-05 | — | Golden fixture regenerated; diff visually reviewed; `golden_diff_test.exs` green | integration | `mix test test/sigra/install/golden_diff_test.exs` | ✅ | ⬜ pending |
| 24-01-09 | 01 | 4 | D-06.4 | — | `mix sigra.install --yes` leg in `.github/workflows/ci.yml:151-223` passes against scratch app | e2e | `act` run or CI green | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/install/template_render_test.exs` — generator-render unit test, one assertion per `organizations/**/*.ex` template. Minimal fixture binding derived from `lib/mix/tasks/sigra.install.ex:97-119` + `migration_timestamps: %{}`.
- [ ] `test/sigra/install/template_syntax_test.exs` — HEEx-inside-EEx guard (D-06.3).
- [ ] `test/sigra/install/features/coverage_test.exs` — per-feature file-coverage lint (D-06.2).
- [ ] Verification task for `Features.Organizations.router_injection/1` + `user_auth_on_mount_assign_user_organizations.ex` `read_template!` calls (D-02).

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
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
