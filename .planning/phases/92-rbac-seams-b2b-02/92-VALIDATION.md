---
phase: 92
slug: rbac-seams-b2b-02
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-29
---

# Phase 92 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/authz_test.exs test/sigra/plug/put_active_organization_test.exs test/sigra/scope/build_test.exs test/sigra/scope/hydration_test.exs test/sigra/scope/plug_liveview_parity_test.exs test/sigra/install/scope_template_fields_test.exs test/sigra/install/scope_template_invariants_test.exs test/sigra/install/features/coverage_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs test/sigra/install/golden_diff_test.exs test/sigra/guides_dx02_test.exs test/example/test/example_web/smoke/install_compile_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~2–8 minutes locally, depending on Postgres and example-install regeneration |

---

## Sampling Rate

- **After every task commit touching `lib/`, `priv/templates/`, `guides/`, or `test/`:** Run the task’s scoped `<automated>` command.
- **After every generator-affecting task:** Re-run ownership/idempotency plus template render/syntax checks.
- **After every plan wave:** Run the quick run command above.
- **Before `/gsd-verify-work`:** Run `mix docs --warnings-as-errors`, `mix compile --warnings-as-errors`, and the full suite command.
- **Max feedback latency:** Prefer scoped commands under 60 seconds; allow the full quick bundle to run at wave boundaries.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 92-01-01 | 01 | 1 | B2B-02 | T-92-01 | `Sigra.Authz` stays a role-agnostic behaviour seam with no built-in policy engine | unit | `MIX_ENV=test mix test test/sigra/authz_test.exs` | ❌ | ⬜ pending |
| 92-01-02 | 01 | 1 | B2B-02 | T-92-02 / T-92-03 | Relevant `lib/sigra/` RBAC surfaces stop shipping canonical role defaults and validate only host-supplied roles | unit + grep | `MIX_ENV=test mix test test/sigra/plug/require_membership_test.exs && rg -n "@default_admin_roles|@default_role_universe|default: \\[:owner, :admin, :member\\]|default: :owner|@auth_roles|\\[:owner, :admin\\]|\\[:owner\\]|:member" lib/sigra/admin/policy.ex lib/sigra/organizations.ex lib/sigra/organizations/invitations.ex lib/sigra/plug/require_membership.ex` | ✅ | ⬜ pending |
| 92-02-01 | 02 | 2 | B2B-02 | T-92-04 | Generated host authz stub compiles, is core-owned, and returns `true` for everything while scope reserves `role` and inert `actor_type` | unit/render | `MIX_ENV=test mix test test/sigra/install/scope_template_fields_test.exs test/sigra/install/scope_template_invariants_test.exs` | ✅ | ⬜ pending |
| 92-02-02 | 02 | 2 | B2B-02 | T-92-05 / T-92-06 | Membership role storage becomes nullable, generated wrapper owns explicit config, and ownership/idempotency do not drift | generator | `MIX_ENV=test mix test test/sigra/install/features/coverage_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/idempotency_test.exs` | ✅ | ⬜ pending |
| 92-03-01 | 03 | 3 | B2B-02 | T-92-07 | `Sigra.Scope.build/3` carries `role` and inert `actor_type` without changing auth-entry semantics | unit | `MIX_ENV=test mix test test/sigra/scope/build_test.exs` | ✅ | ⬜ pending |
| 92-03-02 | 03 | 3 | B2B-02 | T-92-08 / T-92-09 | `current_scope.role` is hydrated only for active membership and cleared on nil/stale branches with plug/live parity | integration | `MIX_ENV=test mix test test/sigra/scope/hydration_test.exs test/sigra/scope/plug_liveview_parity_test.exs test/sigra/plug/put_active_organization_test.exs` | ✅ | ⬜ pending |
| 92-04-01 | 04 | 4 | B2B-02 | T-92-10 / T-92-12 | Recipe ships in docs, distinguishes generated allow-all stub from host-owned deny-by-default hardening, and docs build stays warning-clean | docs | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 92-04-02 | 04 | 4 | B2B-02 | T-92-11 / T-92-12 | Golden snapshot includes rendered `authz.ex`, generator render/syntax stay valid, example install compiles, and verification gates close cleanly | generator + compile | `MIX_ENV=test mix test test/sigra/install/features/coverage_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs test/sigra/install/golden_diff_test.exs test/sigra/guides_dx02_test.exs test/example/test/example_web/smoke/install_compile_test.exs && mix compile --warnings-as-errors` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/authz_test.exs` exists and covers the behaviour contract before implementation claims are closed.
- [ ] Scope template field/invariant tests are extended for `role` and reserved `actor_type`.
- [ ] Ownership/idempotency tests cover the new core-owned `authz.ex` output and organizations-owned membership files.
- [ ] Golden fixture includes `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/authz.ex`.
- [ ] Docs recipe file is registered in `mix.exs` extras before docs validation runs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | B2B-02 | Existing ExUnit/docs/golden/example smoke surfaces are sufficient | N/A |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or an explicit manual-only row
- [ ] Sampling continuity covers library, generator, docs, and example-app compile truths
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter after green wave and phase gates

**Approval:** pending
