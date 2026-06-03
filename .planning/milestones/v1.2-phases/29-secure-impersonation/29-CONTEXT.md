# Phase 29: Secure Impersonation - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 29 adds a security-sensitive admin impersonation flow on top of the Phase
27 admin foundation and Phase 28 user detail surface. Admins can start and end
time-bounded impersonation sessions for allowed users, Sigra keeps the real
admin attributable throughout the session, and sensitive account-security
mutations are blocked server-side while impersonation is active.

This phase does not deliver the richer audit explorer or CSV export from Phase
30, broader bulk admin operations, or stricter enterprise controls like reason
capture, approval workflows, or read-only impersonation modes.

</domain>

<decisions>
## Implementation Decisions

### Session ownership and lifecycle
- **D-01:** [auto] Impersonation starts and stops through controller-owned HTTP
  flows, not ad hoc LiveView events. The flow must reuse the existing
  session-rotation pattern in
  `test/example/lib/example_web/user_auth.ex` so fixation protection stays
  identical to normal login and MFA upgrade paths.
- **D-02:** [auto] Impersonation uses a real second Sigra session for the
  effective user while preserving the original admin session token separately
  for restoration. Do not introduce a separate `impersonation_sessions` table in
  this phase; extend the existing session/scope model additively.
- **D-03:** [auto] The original admin session must remain valid and restorable
  without re-login. Ending impersonation swaps the preserved admin token back
  into the Plug session, deletes the impersonation token, and returns the
  operator to their prior admin context.
- **D-04:** [auto] Impersonation gets its own shorter timeout policy, separate
  from normal browser sessions and separate from sudo. Default to a 30-minute
  absolute timeout and a shorter idle timeout, both configurable under Sigra's
  runtime config.
- **D-05:** [auto] Impersonation is strictly non-nestable. If the current scope
  already carries `impersonating_from`, start attempts fail explicitly,
  server-side, and are audited as denied.

### Authorization and start/stop entry points
- **D-06:** [auto] Starting impersonation requires fresh sudo confirmation at
  the controller boundary. Reuse the existing `Sigra.Plug.RequireSudo` and
  `/users/sudo?return_to=...` pattern instead of inventing an admin-only
  re-auth flow.
- **D-07:** [auto] Authorization uses the existing resolved admin scope contract
  from Phase 27. Platform admins may impersonate any allowed user; org admins
  may impersonate only users structurally reachable inside their resolved
  organization scope. Denied or out-of-scope attempts fail server-side and
  audit as denied.
- **D-08:** [auto] The primary start action lives on the Phase 28 user detail
  surface, not in dense list-row menus. Impersonation is a high-risk,
  user-specific action that should sit near other security-sensitive admin
  actions where scope and target are already visible.

### Visible impersonation state and return behavior
- **D-09:** [auto] The impersonation banner follows the Phase 16 generated-UI
  precedent: a host-owned generated banner component/manual layout seam, with
  the non-dismissable security contract enforced by library-owned controller and
  `on_mount` logic. Users must not be able to hide the state without ending the
  session through Sigra.
- **D-10:** [auto] The banner must always show the impersonated user's identity,
  the real admin identity, and a single obvious "End impersonation" action. The
  existing `special_session` seam in
  `test/example/lib/example_web/components/admin_shell.ex` should become a
  dedicated impersonation indicator rather than a vague generic badge.
- **D-11:** [auto] Start and stop flows must preserve `return_to` context so the
  operator can resume the same admin screen they came from. Phase 28's
  URL-driven `return_to` handling on user list/detail pages is the precedent to
  extend here.

### Forbidden operations during impersonation
- **D-12:** [auto] Sensitive account-security mutations are blocked at the
  server-side controller/context boundary through a dedicated impersonation gate
  plug, not just hidden in the UI. LiveView buttons, controller endpoints, and
  direct-path calls must all hit the same protection boundary.
- **D-13:** [auto] The first blocked set is exactly the requirement set:
  password changes, MFA/TOTP management, passkey enrollment/rename/delete,
  API-key create/revoke, and account deletion/anonymization/reactivation flows
  that would let an admin materially alter the user's security posture while
  impersonating.
- **D-14:** [auto] Blocked actions must fail with explicit user-facing copy and
  an audit trail. Do not silently no-op or redirect away; the operator should
  understand that the restriction is caused by impersonation state.

### Scope hydration and audit attribution
- **D-15:** [auto] While impersonating, `current_scope.user` is the effective
  user and `current_scope.impersonating_from` is the real admin user struct.
  This preserves the Phase 12 reserved-field contract and lets Phase 15's
  `Sigra.Audit.scope_fields/1` remain the single dual-actor assembly point.
- **D-16:** [auto] Phase 29 should take the planned one-line Phase 15 diff:
  `actor_id` remains the real admin, `effective_user_id` becomes the
  impersonated user, and `organization_id` continues to reflect the effective
  organization scope. Do not invent a second audit attribution path.
- **D-17:** [auto] Impersonation lifecycle events use explicit audit action
  names for clarity, such as start, stop, timeout-expire, and denied-attempt
  events. Keep the important query dimensions in canonical columns
  (`actor_id`, `effective_user_id`, `organization_id`) and use metadata only
  for supporting context like session ids or return paths.
- **D-18:** [auto] Timeout-driven end-of-session behavior must be auditable and
  must restore the admin context if possible. If restoration fails because the
  preserved admin token is no longer valid, Sigra should end impersonation
  safely and force a normal login rather than leaving the operator in an
  ambiguous partial state.

### the agent's Discretion
- Exact module names under `Sigra.Impersonation.*`
- Exact config key names for impersonation idle/absolute timeouts
- Exact banner copy and badge styling, as long as the state is persistent and
  unmistakable
- Exact metadata payload shape for impersonation lifecycle audit events
- Exact route names for start/stop controller endpoints, provided they remain
  controller-owned and explicit

</decisions>

<specifics>
## Specific Ideas

- Reuse the existing admin user detail page as the place where an operator sees
  the target user, the current admin scope, and the high-risk action copy before
  starting impersonation.
- Preserve the Phase 15 design goal that dual-actor audit attribution is a
  small extension of the existing `scope_fields/1` seam, not a second parallel
  audit pipeline.
- Follow the Phase 16 precedent that the security contract lives in
  controller/`on_mount` code and the host-owned HEEx is only the display seam.
- Treat the admin session token as restorable state, not as disposable context.
  The requirement is to return the operator to their original admin session, not
  merely to a fresh login page.

### Auto-selected defaults
- [auto] Use the existing session table plus additive session/scope fields, not
  a new impersonation table.
- [auto] Require sudo before start.
- [auto] Place the start action on user detail, not the list.
- [auto] Reuse admin-shell special-session chrome for the persistent banner.
- [auto] Block sensitive operations with a dedicated server-side plug.
- [auto] Preserve `return_to` through start and stop.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase requirements
- `.planning/ROADMAP.md` — Phase 29 goal, success criteria, dependency on the
  admin foundation, and milestone ordering
- `.planning/REQUIREMENTS.md` — IMPR-01 through IMPR-05 plus the adjacent audit
  and verification requirements this phase sets up
- `.planning/PROJECT.md` — v1.2 milestone framing, admin-surface principles,
  and non-negotiable impersonation goals
- `.planning/STATE.md` — current milestone status and the explicit warning that
  Phase 29 needs careful timeout and return-context handling
- `.planning/v1.2-DIRECTION.md` — original user direction for admin
  impersonation, always-visible banner state, time bounds, dual-actor audit,
  and forbidden actions

### Prior phase decisions that already constrain Phase 29
- `.planning/phases/27-admin-access-foundation/27-CONTEXT.md` — locked admin
  scope, route split, host/runtime ownership, and shell visibility rules
- `.planning/phases/28-user-operations-surface/28-CONTEXT.md` — locked user
  detail placement, action safety model, URL-driven `return_to`, and query
  surfaces Phase 29 should extend
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` — reserved
  `Scope.impersonating_from` contract and the additive session/scope extension
  precedent
- `.planning/phases/15-audit-integration/15-CONTEXT.md` — dual-actor audit seam
  through `Sigra.Audit.log_safe/3` and `scope_fields/1`
- `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md` — host-owned
  generated banner/component precedent with library-owned security enforcement
- `UPGRADE-v1.2.md` — reserved generated-field contract for impersonation

### Existing runtime and web seams
- `lib/sigra/auth.ex` — session creation, deletion, sudo confirmation, and the
  current login-time audit/session lifecycle
- `lib/sigra/session.ex` — session struct shape that Phase 29 extends additively
- `lib/sigra/scope.ex` — library-side scope construction helper with reserved
  `impersonating_from`
- `lib/sigra/scope/hydration.ex` — single scope-hydration seam that future
  impersonation hydration should extend
- `lib/sigra/audit.ex` — current `scope_fields/1` implementation and the
  v1.2 impersonation diff point
- `lib/sigra/audit/query.ex` — existing canonical query filters Phase 30 will
  use after Phase 29 starts generating impersonation-aware rows
- `lib/sigra/admin/authorizer.ex` — direct-path admin scope enforcement helpers
- `lib/sigra/admin/live/user_show_live.ex` — current user detail screen and
  `return_to` behavior that Phase 29 should extend
- `test/example/lib/example_web/user_auth.ex` — session rotation, token storage,
  current-scope fetch, and LiveView mount patterns
- `test/example/lib/example_web/controllers/auth/sudo_controller.ex` — existing
  sudo re-auth UX and safe `return_to` validation
- `test/example/lib/example_web/router.ex` — admin route split, current sudo
  pipeline, and controller/LiveView mount structure
- `test/example/lib/example_web/components/admin_shell.ex` — persistent admin
  chrome and existing special-session seam

### Related generated/example schemas
- `test/example/lib/example/accounts/scope.ex` — generated host scope shape with
  reserved `impersonating_from`
- `test/example/lib/example/accounts/user_session.ex` — generated session schema
  that will need additive impersonation state
- `test/example/lib/example/accounts/audit_event.ex` — example audit schema with
  `effective_user_id` already present as a canonical column

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ExampleWeb.UserAuth.renew_session/1` and `put_user_session_token/2` already
  provide the fixation-safe token swap pattern Phase 29 needs for start/stop.
- `Sigra.Audit.scope_fields/1` is already shaped as the single dual-actor diff
  point; Phase 29 should extend it instead of branching audit writes across the
  codebase.
- `Sigra.Admin.Authorizer` already gives Phase 29 the correct global-vs-org
  enforcement boundary for deciding who may impersonate whom.
- `Sigra.Admin.Live.UserShowLive` already preserves safe local `return_to`
  values, giving impersonation a concrete navigation precedent.
- `ExampleWeb.Components.AdminShell` already has persistent scope chrome and a
  special-session seam that can surface impersonation state globally.
- `Sigra.Plug.RequireSudo` plus the generated sudo controller already give Phase
  29 a mature re-auth path for high-risk admin actions.

### Established Patterns
- Security-sensitive runtime stays library-owned; the host owns only explicit
  policy/layout seams.
- Admin scope is enforced structurally through routes, `on_mount`, and direct
  path authorizers, not by hidden UI controls.
- Scope and session evolution happen additively through existing structs and
  hydrators rather than parallel auth objects.
- High-risk actions preserve local `return_to` state and validate it as a local
  path before redirecting.

### Integration Points
- New controller routes for impersonation start/stop wired into the existing
  admin router scopes
- Additive session persistence for preserved-admin and active-impersonation
  state
- Scope hydration updates so Plug and LiveView receive identical impersonation
  context
- User detail action surface updates for the start entry point
- Admin shell/banner updates so impersonation state remains visible everywhere
- Sensitive controller/LiveView endpoints protected by a shared impersonation
  gate plug

</code_context>

<deferred>
## Deferred Ideas

- Reason capture, approval workflows, or read-only impersonation modes
- Starting impersonation from list views or future bulk-operation surfaces
- Rich audit exploration, impersonation feed, and CSV export in the admin UI
  (Phase 30)
- Broader enterprise policy controls around who may impersonate whom beyond the
  current platform-admin/org-admin scope model

</deferred>

---

*Phase: 29-secure-impersonation*
*Context gathered: 2026-04-16*
