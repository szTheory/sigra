# Phase 125: SSO-Only Enforcement & Break-Glass Truth - Research

**Researched:** 2026-05-26
**Domain:** Organization-scoped SSO-only auth policy, explicit break-glass exemptions, and truthful denied-path behavior in Sigra's hybrid library + generated-host auth model
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Model SSO-only as an organization-owned auth policy, not as a field on `enterprise_connections`, not as a membership-role side effect, and not as a global user flag.
- **D-02:** Use a first-class org-scoped policy resource such as `organization_auth_policies` with one durable row per organization.
- **D-03:** Model break-glass as explicit org-user exemptions keyed by `{organization_id, user_id}`, separate from the membership role itself.
- **D-04:** Keep host-owned schemas for this policy/exemption data and library-owned evaluation/enforcement logic.
- **D-05:** Break-glass is a narrow recovery seam, not a parallel local-auth product mode.
- **D-06:** Exempt users keep local password login and password-reset recovery only.
- **D-07:** Do not preserve magic-link or passkey as break-glass primary sign-in methods under SSO-only enforcement.
- **D-08:** Non-exempt users denied from local auth must be routed back to the explicit enterprise path, not silently downgraded into another local method.
- **D-09:** Put the core enforcement check in the library-owned password-auth decision boundary, after credential verification but before `auth.login.success` and before any session is created.
- **D-10:** Do not rely on controller-only, plug-only, or template-only enforcement for the primary guarantee.
- **D-11:** Generated-host controllers may translate typed library outcomes into redirect/copy, but may not own the core allow/deny rule.
- **D-12:** Routing/discovery and enforcement are separate concerns.
- **D-13:** A denied local password attempt must not emit `auth.login.success` or `session.create`.
- **D-14:** Denied local auth should emit a typed, auditable denial reason, either via bounded `auth.login.failure` metadata or a dedicated deny action.
- **D-15:** The denial/result contract should use bounded result atoms rather than ad hoc controller copy.
- **D-16:** Enterprise callback failures keep the same-mode enterprise retry posture already locked by Phases 123 and 124.
- **D-17:** The operator surface stays on the existing organization settings enterprise area, but the policy UI must remain legible as distinct from connection status and validation state.
- **D-18:** Enabling SSO-only should require an explicit, valid break-glass story rather than treating break-glass as optional guidance.
- **D-19:** The generated-host contract should verify that at least one valid non-SSO recovery path exists before allowing irreversible or lockout-prone transitions.
- **D-20:** Keep this phase focused on password-denial truth and break-glass posture, not a generalized matrix of every auth-method combination.

### Claude's Discretion
- Exact schema/module/function names for policy and exemption records, as long as org ownership and org-user break-glass semantics stay explicit.
- Whether denial audit reuses `auth.login.failure` with typed metadata or introduces a dedicated action, as long as success/denial truth stays unambiguous.
- Exact controller flash copy, redirect details, and settings-page layout, as long as denied users are pointed back to enterprise sign-in and exempt users remain password-only break-glass users.

### Deferred Ideas (OUT OF SCOPE)
- SCIM or directory-driven lifecycle enforcement.
- Break-glass variants that allow passkeys or magic links.
- Hosted control-plane policy UX.
- Broad multi-method auth-policy matrices outside the bounded SSO-only + break-glass contract.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENF-01 | Organizations can require SSO for members while preserving explicit break-glass exemptions for allowed users. | Model a durable organization auth policy plus explicit org-user exemptions, enforce password/reset denial in `Sigra.Auth`, keep generated-host policy controls in organization settings, and prove denied paths emit truthful audit/session outcomes. |
</phase_requirements>

## Repo-Grounded Findings

### Existing Seams That Already Fit Phase 125
- `lib/sigra/auth.ex` already owns password verification, lockout, `auth.login.success`, `auth.login.failure`, and session creation timing. This is the correct enforcement seam for D-09 through D-15.
- `lib/sigra/oauth/callback.ex` already uses typed enterprise outcomes and keeps refusal paths inside enterprise mode. Phase 125 should mirror that "typed result in library, copy/redirect in host" pattern instead of inventing controller-owned security logic.
- `test/example/lib/example/organizations.ex` already wraps organization-scoped enterprise settings and routing. It is the natural host seam for auth-policy changesets/save actions without moving policy logic into the controller.
- `test/example/lib/example_web/live/organization_settings_live.ex` already has the enterprise settings surface. Phase 125 should extend this bounded area rather than creating a separate admin-only control plane.
- `test/example/lib/example/accounts/emails.ex` already has `oauth_reset_email/2`, which is precedent for "local reset is not universally available" messaging. Phase 125 can reuse this posture for truthful recovery guidance.

### Code Paths That Need Policy Awareness
- Password login: `ExampleWeb.SessionController.create/2` -> `Example.Accounts.get_user_by_email_and_password/2` -> `Sigra.Auth.authenticate/2`.
- Password reset request: `Example.Accounts.deliver_user_reset_password_instructions/2` -> `Sigra.Auth.request_password_reset/3`.
- Password reset completion: `Example.Accounts.reset_user_password/2` -> `Sigra.Auth.reset_password/4`.
- Session/audit truth: `Sigra.Auth.create_session/4` and `session_create_audit_metadata/2`.
- Operator controls: `ExampleWeb.OrganizationSettingsLive` enterprise section and `Example.Organizations` wrapper.
- Enterprise recovery surface: `/organizations/:org/sso` and `ExampleWeb.EnterpriseSSOController`.

### Recommended Policy/Data Model
- Add one org-owned policy record with fields bounded to this phase, such as `organization_id`, `enforcement_mode` (`:optional | :sso_required`), and break-glass safety metadata if needed.
- Add one explicit org-user exemption record keyed by `{organization_id, user_id}`. Do not infer break-glass from role, enterprise-connection ownership, or password presence.
- Keep policy/exemption schemas in the generated host example app, while the library reads them through config-backed schema references or a narrow host callback/config seam. This matches the existing hybrid ownership split used for organizations and enterprise connections.
- Do not overload `enterprise_connections` with enforcement flags. Connection validity and auth policy are related but not the same state machine.

## Recommended Architecture

### Pattern 1: Typed Password Enforcement in `Sigra.Auth`
After credential verification succeeds, but before `auth.login.success` and before any session is created, evaluate whether the user belongs to an organization with SSO-only enabled and whether they have an explicit break-glass exemption for that organization.

Recommended result contract:
- `{:ok, user}` or `{:ok, user, session_metadata}` on allowed password login
- `{:error, :sso_required}` for non-exempt users denied under org policy
- `{:error, :break_glass_not_allowed}` only if the implementation needs a distinct internal denial reason

Implementation consequence:
- `auth.login.success` must never fire for denied users.
- `session.create` must never fire for denied users.
- `auth.login.failure` can carry bounded metadata such as `%{reason: "sso_required", organization_id: org_id}` if audit reuse is chosen.

### Pattern 2: Keep Password Reset Recovery Narrow and Truthful
Break-glass includes password-reset recovery for exempt users only. Non-exempt users at SSO-only orgs should not receive a real reset token or complete a local reset, because that would recreate a local-auth bypass.

Recommended behavior:
- Reset request for a denied user should return a generic success-shaped API result for enumeration safety, but produce no usable reset token.
- Generated-host UX may still show truthful guidance on the follow-up page or email surface when the user is known and policy permits revealing the enterprise path.
- Reset completion must fail closed if a token somehow exists but the current org-policy state forbids local reset for that user.

### Pattern 3: Keep Discovery/Routing Separate from Enforcement
Enterprise routing remains responsible for finding the correct org/connection and retrying in enterprise mode. SSO-only enforcement should reuse that surface, but not depend on the login page hiding local forms.

Recommended host behavior:
- Local password denial redirects back to `/organizations/:org/sso` when org context is known.
- Generic login page can still exist for break-glass users; it just cannot be the source of truth for whether password login is allowed.
- Passkey and magic-link surfaces should be suppressed or guidance-only for SSO-only orgs unless a later phase explicitly expands break-glass semantics.

### Pattern 4: Explicit Enablement Safety Rails
The settings surface should not let operators enable SSO-only until there is at least one explicit exempt member with a viable password recovery path.

Minimum rails:
- Require selecting at least one exempt user before activation.
- Verify the exempt user still has a local password account path.
- Distinguish enterprise connection status from policy status in the UI.
- Prevent "active connection exists" from being treated as equivalent to "SSO-only is safely enabled."

## File and Test Impact Map

### Likely New Files
- `lib/sigra/organization_auth_policy.ex` or nearby library policy-evaluation module
- `test/sigra/organization_auth_policy_test.exs` or similar root unit/integration coverage
- Host schemas for org policy and break-glass exemption in `test/example/lib/example/accounts/`
- Example-app tests for settings live view and denied local auth flows

### Likely Modified Files
- `lib/sigra/auth.ex`
- `test/example/lib/example/accounts.ex`
- `test/example/lib/example/organizations.ex`
- `test/example/lib/example_web/controllers/session_controller.ex`
- `test/example/lib/example_web/controllers/session_html.ex`
- `test/example/lib/example_web/live/organization_settings_live.ex`
- `test/example/lib/example/accounts/emails.ex`
- Possibly installer/generated templates under `lib/sigra/install/features/`

## Plan Split Recommendation

### Plan 125-01: Org policy model + operator controls
Own the new org policy/exemption records, generated-host wrapper/config, and settings UI safety rails that make SSO-only enablement explicit and survivable.

### Plan 125-02: Library-owned password/reset enforcement + audit/session truth
Own the `Sigra.Auth` denial seam, typed outcomes, audit metadata, and password-reset gating so local auth cannot bypass the org policy.

### Plan 125-03: Generated-host login/recovery surfaces + proof
Own the example app login page, session controller flows, enterprise rerouting, break-glass guidance, and end-to-end proof that denied users are routed truthfully while exempt users can still recover.

This split matches the existing phase style in 123/124: policy/model substrate first, library-owned auth truth second, and generated-host proof last.

## Validation Architecture

Use two verification lanes:
- Root-library ExUnit for policy evaluation, password denial timing, audit metadata, and reset gating.
- `test/example` ExUnit with `--include example_app` for organization settings, local login denial redirects, break-glass success, and recovery guidance.

Fast feedback commands should stay lane-specific:
- Root lane: `mix test test/sigra/auth_* test/sigra/organization_*`
- Example lane: `cd test/example && mix test --include example_app test/example_web/controllers/session_controller_test.exs test/example_web/live/organization_settings_live_test.exs`

Before phase verification, both full suites should pass:
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`
- `cd test/example && MIX_ENV=test mix test --include example_app`

## Anti-Patterns To Avoid
- UI-only hiding of local login forms while leaving `Sigra.Auth.authenticate/2` unchanged.
- Storing SSO-only on `enterprise_connections` and conflating routing setup with auth policy state.
- Implicit break-glass based on membership role, existing password hash, or "org owner" heuristics.
- Allowing magic-link or passkey login as accidental break-glass paths when the phase explicitly limits break-glass to password + password reset.
- Emitting `auth.login.success` or `session.create` for a denied local password attempt and trying to "repair" the truth later in the controller.
- Returning the same generic invalid-password reason internally for SSO-only denials; the user-facing copy can stay bounded, but the machine-readable audit/result contract must preserve policy truth.

## Key Insight

Phase 125 is not primarily a login-page change. It is a policy-truth phase: add an explicit org-owned enforcement state, evaluate it inside `Sigra.Auth`, preserve one narrow break-glass recovery seam, and let the generated host surface that truth without becoming the security boundary.
