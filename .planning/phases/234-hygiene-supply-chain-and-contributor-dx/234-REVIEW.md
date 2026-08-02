---
phase: 234-hygiene-supply-chain-and-contributor-dx
reviewed: 2026-08-01T23:22:07Z
depth: standard
files_reviewed: 61
files_reviewed_list:
  - .github/dependabot.yml
  - .github/workflows/ci.yml
  - .github/workflows/release-please.yml
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
  - test/example/lib/example/demo/branding.ex
  - test/example/lib/example/demo/personas.ex
  - test/example/lib/example/demo/seeds.ex
  - test/example/lib/example_web/live/settings_live.ex
  - test/example/priv/playwright/playwright.config.ts
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
  - test/sigra/workers/audit_forward_test.exs
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 234: Code Review Report

**Reviewed:** 2026-08-01T23:22:07Z
**Depth:** standard
**Files Reviewed:** 61
**Status:** issues_found

## Summary

The configured GitHub Actions use immutable SHA pins and the focused Phase 234 contract suite passes (23 tests). However, the new machine-evidence completion gate can ratify stale or structurally invalid service evidence, and the Playwright ownership inventory can claim a spec is covered by a lane that executes a different spec. These defects undermine Phase 234's stated fail-closed evidence and ownership guarantees.

## Critical Issues

### CR-01: Completion authorization accepts a bare `status: success` for every evidence slot

**File:** `test/sigra/planning/phase_234_evidence_contract_test.exs:741`
**Issue:** `assert_transition_allowed!/3` authorizes the completed validation state when each receipt is merely a map with `"status" => "success"`. It does not call `validate_local_mix_ci_receipt!/1`, `validate_dependabot_receipt!/1`, or equivalent validators for PR, release, and gallery receipts. Thus a malformed or fabricated slot (for example `%{"status" => "success"}`) is sufficient to authorize `status: complete`, despite the intended exact, fail-closed evidence gate. The mutation test itself demonstrates this bypass by using six such bare maps at line 532 and expecting completion at line 543.

**Fix:** Make the transition function validate each concrete receipt before testing the transition fields, and add mutations that pass malformed `status: success` slots to the real sign-off path. For example:

```elixir
assert :ok = validate_local_mix_ci_receipt!(receipts["local_mix_ci"])
assert :ok = validate_pr_ci_receipt!(receipts["pr_ci"])
assert :ok = validate_release_receipt!(receipts["release"])
assert :ok = validate_dependabot_receipt!(receipts["dependabot"])
assert :ok = validate_gallery_receipt!(receipts["gallery"])
```

### CR-02: Command receipts are neither fresh nor bound to the reviewed revision

**File:** `test/sigra/planning/phase_234_evidence_contract_test.exs:706`
**Issue:** The exact-inventory validator checks only command text, syntactic UTC timestamps, exit code, and hash shape. It does not require a receipt commit SHA, bind it to `HEAD`, or impose any freshness limit. An old successful five-command table can therefore authorize the current validation after source or evidence changes. The purported “stale command” mutation at lines 571-575 changes the command string, not its timestamp or revision, so it does not test this failure mode.

**Fix:** Add a commit SHA to every receipt and require it to equal the validated phase revision (or require a signed/CI-attested run for that SHA). Also reject timestamps outside a documented validity window and add stale-timestamp and wrong-SHA mutation tests.

## Warnings

### WR-01: Playwright inventory validation does not bind a spec to its claimed command marker

**File:** `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs:159`
**Issue:** `validate_spec!/3` passes only the lane object to `validate_lane!/3`; the spec path is discarded. `validate_lane!/3` then verifies that `command_marker` occurs somewhere in the job, not that it is the basename/path of this inventory entry. Replacing `admin-theme.spec.ts`'s marker with another existing marker in `example_playwright_shard` leaves the inventory valid while falsely reporting `admin-theme` as owned. This can silently remove browser coverage during a future shard edit.

**Fix:** Pass `spec` to `validate_lane!/4`, require the marker to execute that exact spec (with explicit exceptions for harness-owned specs), and add a mutation which swaps two valid existing markers and must fail.

---

_Reviewed: 2026-08-01T23:22:07Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
