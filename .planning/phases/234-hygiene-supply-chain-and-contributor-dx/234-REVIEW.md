---
phase: 234-hygiene-supply-chain-and-contributor-dx
reviewed: 2026-08-02T01:37:34Z
depth: deep
files_reviewed: 67
files_reviewed_list:
  - .formatter.exs
  - .github/dependabot.yml
  - .github/workflows/ci.yml
  - .github/workflows/release-please.yml
  - CONTRIBUTING.md
  - lib/mix/tasks/sigra.install.ex
  - lib/sigra/admin/components.ex
  - lib/sigra/admin/organizations/detail.ex
  - lib/sigra/audit/forwarders/threadline.ex
  - lib/sigra/doctor.ex
  - lib/sigra/enterprise_connections.ex
  - lib/sigra/enterprise_connections/validation.ex
  - lib/sigra/enterprise_routing.ex
  - lib/sigra/install/features/organizations.ex
  - lib/sigra/integrations/chimeway.ex
  - lib/sigra/jwt.ex
  - lib/sigra/jwt/refresh_token.ex
  - lib/sigra/mfa/trust.ex
  - lib/sigra/oauth.ex
  - lib/sigra/oauth/callback.ex
  - lib/sigra/oauth/enterprise_reconciliation.ex
  - lib/sigra/organizations/invitations.ex
  - lib/sigra/workers/audit_forward.ex
  - mix.exs
  - test/example/lib/example/demo/branding.ex
  - test/example/lib/example/demo/personas.ex
  - test/example/lib/example/demo/seeds.ex
  - test/example/lib/example_web/live/settings_live.ex
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts
  - test/example/priv/playwright/tests/admin-theme.spec.ts
  - test/example/priv/repo/migrations/20260410125245_create_organizations.exs
  - test/example/priv/repo/migrations/20260525010000_create_enterprise_connections.exs
  - test/example/priv/repo/migrations/20260528152137_threadline_audit_schema.exs
  - test/example/priv/repo/migrations/20260528152139_threadline_governance_schema.exs
  - test/example/priv/repo/migrations/20260529000000_create_user_identities.exs
  - test/example/test/example_web/live/admin_audit_user_live_test.exs
  - test/example/test/example_web/live/admin_user_filters_live_test.exs
  - test/example/test/example_web/live/admin_user_sessions_live_test.exs
  - test/sigra/admin/components_test.exs
  - test/sigra/admin/organizations_detail_test.exs
  - test/sigra/application_forwarders_test.exs
  - test/sigra/audit/forwarders/dispatch_test.exs
  - test/sigra/audit_telemetry_test.exs
  - test/sigra/doctor_test.exs
  - test/sigra/enterprise_connections/activation_test.exs
  - test/sigra/enterprise_connections/context_test.exs
  - test/sigra/enterprise_connections/schema_test.exs
  - test/sigra/enterprise_routing/discovery_test.exs
  - test/sigra/install/api_token_generator_test.exs
  - test/sigra/install/generator_passkeys_opt_out_test.exs
  - test/sigra/install/oauth_generator_test.exs
  - test/sigra/mix/tasks/doctor_task_test.exs
  - test/sigra/oauth/enterprise_callback_test.exs
  - test/sigra/oauth/enterprise_reconciliation_test.exs
  - test/sigra/planning/phase_146_release_validation_test.exs
  - test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs
  - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
  - test/sigra/planning/phase_230_ci_timeouts_test.exs
  - test/sigra/planning/phase_230_design_gallery_split_test.exs
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_234_action_pinning_contract_test.exs
  - test/sigra/planning/phase_234_dependabot_contract_test.exs
  - test/sigra/planning/phase_234_evidence_contract_test.exs
  - test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
  - test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs
  - test/sigra/workers/audit_forward_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 234: Code Review Report

**Reviewed:** 2026-08-02T01:37:34Z
**Depth:** deep
**Files Reviewed:** 67
**Status:** issues_found

## Summary

The CI, supply-chain, Playwright ownership, validation contracts, and formatter batches were reviewed. The focused Phase 234 contract suite passes (29 tests), but two defects remain: the claimed fail-closed sign-off can be completed without any command receipts, and the advertised local `mix ci` command destructively modifies the contributor's lockfile.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Validation completion accepts an empty command-receipt set

**Classification:** BLOCKER

**File:** `test/sigra/planning/phase_234_evidence_contract_test.exs:516`

**Issue:** `Enum.all?([], ...)` returns `true`. Once the external evidence slots are green, `assert_transition_allowed!/3` accepts the complete frontmatter even when all command-receipt rows have been deleted. This contradicts the plan's stated fail-closed requirement and permits a Nyquist-complete claim without any local verification receipts. The mutation coverage checks a red receipt but never a missing/empty receipt set.

**Fix:** Require the exact expected receipt inventory and validate each receipt before declaring it green. For example:

```elixir
commands_green? =
  length(command_receipts) == 5 and
    Enum.all?(command_receipts, &(valid_command_receipt?(&1) and &1.exit_status == "0"))
```

Add an assertion that `assert_transition_allowed!(complete, green_evidence, [])` is blocked, plus cases for missing and malformed rows.

## Warnings

### WR-01: The documented local CI gate leaves `mix.lock` changed

**Classification:** WARNING

**File:** `mix.exs:163-168`

**Issue:** `mix ci` now calls `sigra.dep_off`, whose first leg is `deps.unlock threadline`. Unlike the preceding `--check-unused` leg, `deps.unlock threadline` is destructive: it removes the direct dependency lock entry and writes `mix.lock`. Thus a successful local command advertised as a contributor gate leaves a tracked file dirty and the workspace missing the optional dependency; the documentation actively directs contributors to run it at `CONTRIBUTING.md:13-23`. CI gets a disposable checkout, but developer worktrees do not.

**Fix:** Keep the destructive dep-off proof in an isolated CI workspace/process, or restore the original lock/dependency state reliably before the alias returns. Prefer a dedicated script that copies `mix.lock` to a temporary location, runs the dep-off check, and restores it in an `after`/shell `trap`; verify `git diff --exit-code -- mix.lock` after `mix ci`.

---

_Reviewed: 2026-08-02T01:37:34Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
