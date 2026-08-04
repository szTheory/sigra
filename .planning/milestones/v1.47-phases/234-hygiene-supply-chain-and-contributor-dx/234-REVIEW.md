---
phase: 234-hygiene-supply-chain-and-contributor-dx
reviewed: 2026-08-02T15:47:55Z
depth: standard
files_reviewed: 57
files_reviewed_list:
  - .github/workflows/ci.yml
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
  - test/sigra/planning/phase_234_evidence_contract_test.exs
  - test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
  - test/sigra/workers/audit_forward_test.exs
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 234: Code Review Report

**Reviewed:** 2026-08-02T15:47:55Z
**Depth:** standard
**Files Reviewed:** 57
**Status:** issues_found

## Summary

The reviewed source contains an SSRF primitive in organization-admin OIDC validation, plus two correctness defects in authentication delivery and cursor navigation. Focused ExUnit coverage passed (45 tests), but it does not exercise these adversarial paths.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: OIDC validation fetches an administrator-controlled URL without SSRF controls

**File:** `lib/sigra/enterprise_connections/validation.ex:64-89`

**Issue:** `discovery_document_uri` is accepted as any nonblank string and supplied directly to the configured HTTP client. Organization administrators can therefore make the Sigra host request arbitrary HTTP(S) and non-HTTP URLs, including loopback, link-local/cloud-metadata, and private-network targets. The issuer check occurs only after the request and does not prevent the network access; redirects must also be constrained. This makes a tenant-admin configuration screen a server-side request forgery primitive.

**Fix:** Parse and validate the URI before fetching: permit only `https`, reject userinfo and non-443 ports unless explicitly supported, resolve the hostname and reject loopback/link-local/private/reserved addresses (including every redirect target), then invoke `Req` with redirects disabled or with the same validator applied to each redirect. Add tests for `http://127.0.0.1`, `http://169.254.169.254`, IPv6 loopback, private DNS answers, and a public URL redirecting to a private address.

## Warnings

### WR-01: Magic-link dispatch can bind the wrong URL to an idempotency key under concurrent requests

**File:** `lib/sigra/integrations/chimeway.ex:52-60`

**Issue:** `dispatch_magic_link/5` ignores the returned raw token and finds the user's newest `magic_link` token instead. A second request between insertion and `fetch_magic_link_token_inserted_at/3` makes the first dispatch store URL A under token B's idempotency key. The second dispatch then sees the duplicate key; depending on timing, one request's URL is sent for the other's token and the other login request receives no usable delivery.

**Fix:** Carry the inserted token's immutable identifier or timestamp out of `Sigra.Auth.request_magic_link/3` and derive the idempotency key from that exact record. Do not query for the newest user token after issuing it. Add a deterministic concurrent-request test that interleaves two requests for the same user and asserts each delivery key maps to its own URL.

### WR-02: Disabled cursor controls remain live links

**File:** `lib/sigra/admin/components.ex:830-844`

**Issue:** At either cursor boundary the control gets `aria-disabled="true"` and an `is-disabled` class, but retains its `href`. `aria-disabled` does not suppress native anchor navigation, so keyboard and pointer users can activate a visually disabled Previous/Next control and reload a boundary page. This contradicts the component's disabled state and makes navigation behavior depend on the caller's fallback URL.

**Fix:** Render a non-link element (`<span aria-disabled="true">`) at the boundary, or omit `href`, set `tabindex="-1"`, and prevent click/keyboard activation. Cover both first- and last-page markup/activation behavior in the component and LiveView tests.

---

_Reviewed: 2026-08-02T15:47:55Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
