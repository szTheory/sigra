---
phase: 91
slug: org-level-mfa-enforcement-b2b-01
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-29
---

# Phase 91 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+, Phoenix 1.8) with `Sigra.DataCase` / `Sigra.ConnCase` / `Phoenix.LiveViewTest` |
| **Config file** | `mix.exs`, `test/test_helper.exs`, `test/support/{data_case,conn_case}.ex` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test {single_file}` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~90s full suite (per CLAUDE.md prerequisites) |

---

## Sampling Rate

- **After every task commit:** Run quick command on the test file affected by the task (single-file `mix test`)
- **After every plan wave:** Run the full suite (`mix test`)
- **Before `/gsd-verify-work`:** Full suite must be green AND generator-host integration suite (`test/example/test/example_web/integration/`) green
- **Max feedback latency:** ~30s for single-file, ~90s for full suite

---

## Per-Task Verification Map

> Populated during execution as `gsd-executor` writes each task. Initial layout below mirrors RESEARCH.md "Concrete File List" surface areas.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 91-01-XX | 01 (schema + upgrade migration) | 1 | B2B-01 | T-91-01 (drift) | `enforce_mfa_for_members` exists, default false, NOT NULL | migration | `mix test test/sigra/organizations_schema_test.exs` | ❌ W0 | ⬜ pending |
| 91-02-XX | 02 (`set_mfa_policy/3` + atomicity) | 1 | B2B-01 | T-91-02 (orphan audit) | Co-fated rollback under CHECK-guard fault injection | atomicity (fault-injection) | `mix test test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` | ❌ W0 | ⬜ pending |
| 91-03-XX | 03 (`Sigra.Plug.RequireOrgMfa`) | 2 | B2B-01 | T-91-03 (bypass) | Non-MFA member halted at `:org_scoped`; MFA member passes; non-enforced org passes | plug unit | `mix test test/sigra/plug/require_org_mfa_test.exs` | ❌ W0 | ⬜ pending |
| 91-04-XX | 04 (`Sigra.LiveView.RequireOrgMfa` on_mount) | 2 | B2B-01 | T-91-04 (LV bypass on policy flip) | `:halt` + `:sigra_redirect_to` set when enforcement required and user not MFA-enrolled | LV mount unit | `mix test test/sigra/live_view/require_org_mfa_test.exs` | ❌ W0 | ⬜ pending |
| 91-05-XX | 05 (generator templates: migration, schema, router_injection, error_handler) | 2 | B2B-01 | T-91-05 (template drift) | Templates render without compile errors; `:org_scoped` includes new plug | golden-diff + render | `mix test test/sigra_install_test.exs` | partial — extends existing | ⬜ pending |
| 91-06-XX | 06 (`OrganizationSettingsLive` Security section + admin pre-flight) | 3 | B2B-01 | T-91-06 (admin self-lockout) | Pre-flight refuses with `:admin_must_enroll_first`; LiveView disables toggle when admin not MFA-enrolled | LV unit + LV integration | `mix test test/sigra/organization_settings_live_test.exs` | partial — extends existing | ⬜ pending |
| 91-07-XX | 07 (generator-host integration test) | 3 | B2B-01 | T-91-07 (E2E policy) | Admin flips toggle → non-MFA member sees enrollment redirect → audit row exists | integration | `mix test test/example/test/example_web/integration/org_mfa_enforcement_test.exs` | ❌ W0 | ⬜ pending |
| 91-08-XX | 08 (ROADMAP success-criterion #1 surgical edit + CHANGELOG + VERIFICATION.md) | 4 | B2B-01 | — | Planning truth records action name canonicalization (D-91-12) | doc | `git diff --check .planning/ROADMAP.md` | partial — surgical edit | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/organizations_schema_test.exs` — stub assertion `field?(:enforce_mfa_for_members, :boolean)` for B2B-01
- [ ] `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` — stub mirroring `test/sigra/jwt_refresh_audit_cofate_test.exs` (Phase 82) for fault-injection assertion shape (CHECK constraint on `audit_events`, expect `{:error, :mfa_policy_aborted}`, expect zero rows in both tables)
- [ ] `test/sigra/plug/require_org_mfa_test.exs` — stubs for the four plug paths (no policy → pass; policy on, MFA on → pass; policy on, MFA off → halt; missing scope → halt)
- [ ] `test/sigra/live_view/require_org_mfa_test.exs` — stub for `on_mount` halt + `:sigra_redirect_to` assignment
- [ ] `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` — stub for end-to-end admin-flips-toggle-then-non-MFA-member-blocked round-trip per ROADMAP success criterion #4
- [ ] No new framework install — ExUnit + Phoenix.LiveViewTest + Sigra.DataCase are already wired in the project (CLAUDE.md prerequisites confirm Postgres at localhost:5432)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual regression of "Security" section between General and Danger Zone in `OrganizationSettingsLive` | B2B-01 SC #1 | DaisyUI toggle visual + impact-preview copy is hard to assert via test (UI-SPEC.md 91 already locks the design contract; humans confirm) | Open `OrganizationSettingsLive` as admin in dev mode, confirm toggle in "Security" card matches UI-SPEC.md mockup |

> Per project preference (zero-human UAT), this is the only manual verification. All five ROADMAP success criteria are otherwise asserted by automated tests above.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
