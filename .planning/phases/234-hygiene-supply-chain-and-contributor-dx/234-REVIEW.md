---
phase: 234-hygiene-supply-chain-and-contributor-dx
reviewed: 2026-08-02T14:32:13Z
depth: standard
files_reviewed: 64
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
  critical: 5
  warning: 0
  info: 0
  total: 5
status: issues_found
---

# Phase 234: Code Review Report

**Reviewed:** 2026-08-02T14:32:13Z
**Depth:** standard
**Files Reviewed:** 64
**Status:** issues_found

## Summary

The supplied workflow/configuration, library, example, migration, and test files were reviewed at standard depth. The focused enterprise/audit/OAuth worker test selection passed (25 tests), but it does not exercise the defects below. Five BLOCKER findings permit SSRF, exhaust the BEAM atom table, prevent authentication messages from carrying their credentials, crash a normal validation-failure path, or break one-time refresh-token rotation under concurrency.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: OIDC validation permits arbitrary server-side requests

**Classification:** BLOCKER

**File:** `lib/sigra/enterprise_connections/validation.ex:64-80`

**Issue:** An organization-controlled `discovery_document_uri` is accepted verbatim and passed to `Req.get/1`. There is no scheme, host, IP-range, DNS-rebinding, redirect, or response-size policy. An authenticated org admin can therefore make the Sigra server request loopback/private endpoints (including cloud metadata services) and expose whether they are reachable through the validation result/error behavior.

**Fix:** Parse and validate the URI before calling the HTTP client: require HTTPS, reject userinfo/ports as appropriate, resolve and reject loopback/link-local/private/reserved addresses for every redirect target, disable redirects or revalidate each one, and impose connect/read/response-size limits. If private IdPs must be supported, make an explicit, narrowly documented allowlist configuration instead of accepting arbitrary URLs.

### CR-02: Audit action strings are converted into permanent atoms

**Classification:** BLOCKER

**File:** `lib/sigra/audit/forwarders/threadline.ex:269-275`

**Issue:** `String.to_atom/1` turns every audit action string into a non-garbage-collected BEAM atom. The forwarder accepts telemetry metadata, so a host which records request-derived or otherwise unbounded action strings can permanently exhaust the atom table and terminate the VM. The nearby comment explicitly acknowledges the atom-growth risk but leaves the unsafe operation active.

**Fix:** Keep action names as strings through the Threadline boundary, or translate only a finite, application-owned allowlist with `String.to_existing_atom/1`. Reject/telemetry-report unknown action strings; never create atoms from runtime metadata.

### CR-03: Chimeway delivery discards the link and confirmation code

**Classification:** BLOCKER

**File:** `lib/sigra/integrations/chimeway.ex:291-303,358-369`

**Issue:** Both notifier `rendering/2` functions call `PendingDelivery.pop!/1`, then discard its result (`_secrets`). The returned email assigns contain only static subject/body text; neither the magic-link URL nor the confirmation code/URL is passed on. Since `pop!/1` deletes the ETS entry, the required credential cannot be recovered later. Every successful Chimeway authentication notification therefore sends a message that cannot be used to sign in or confirm the account.

**Fix:** Consume the popped values and pass the URL/code into the renderer's protected template inputs (or have the rendering adapter render the message immediately from those values). Add integration tests asserting that a delivered magic-link message includes its URL and that confirmation delivery includes the code.

### CR-04: Failed validation persistence raises instead of returning a changeset error

**Classification:** BLOCKER

**File:** `lib/sigra/enterprise_connections.ex:61-71`

**Issue:** When discovery returns `{:error, :validation_failed, message}`, the code pattern-matches `{:ok, persisted} = persist(...)`. `persist/2` legitimately returns `{:error, changeset}` for a DB/constraint/changeset failure, turning a normal admin validation outcome into a `MatchError` and crashing the caller. The public spec promises an error tuple, not an exception.

**Fix:** Handle `persist/2` with `case`/`with` and return `{:error, changeset}` on persistence failure; return `{:error, :validation_failed, persisted}` only after a successful update. Add a test-double repo that returns `{:error, changeset}` from this branch.

### CR-05: Refresh-token rotation has a replay race

**Classification:** BLOCKER

**File:** `lib/sigra/jwt/refresh_token.ex:127-143,93-106`

**Issue:** Rotation reads a token's metadata without a row lock, observes it as unsuperseded, then updates it and inserts a replacement. Two simultaneous refresh requests can both classify the same token as `:rotate`, both write `superseded_at`, and each mint a valid successor. That defeats one-time-use rotation/reuse detection and leaves a stolen token able to create a valid session if raced with the legitimate client.

**Fix:** Make classification and supersession a single atomic conditional update inside a transaction (for example, `UPDATE ... WHERE superseded_at IS NULL RETURNING ...`), treating a zero-row update as reuse and revoking the family. Add a concurrent two-request test that proves exactly one refresh succeeds and the other triggers reuse handling.

---

_Reviewed: 2026-08-02T14:32:13Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
