# Phase 29: Secure Impersonation - Research

**Researched:** 2026-04-16
**Domain:** Phoenix controller-owned impersonation on Sigra's existing session, scope, and audit runtime
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- Reason capture, approval workflows, or read-only impersonation modes
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IMPR-01 | Platform admin can start an impersonation session for an allowed user through a controller-owned flow that rotates session state and preserves the real admin as the actor. | Controller-owned start flow, `UserAuth` renewal seam reuse, preserved admin raw token, and library-owned `Sigra.Impersonation.start/4` recommendation. [VERIFIED: 29-CONTEXT.md] [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| IMPR-02 | Org admin can impersonate only users within their allowed organization scope; out-of-scope impersonation attempts fail server-side and audit as denied. | `Sigra.Admin.Scope` plus `Sigra.Admin.Authorizer` remain the server-side scope boundary for target lookup before session issuance. [VERIFIED: lib/sigra/admin/scope.ex] [VERIFIED: lib/sigra/admin/authorizer.ex] |
| IMPR-03 | Every impersonation session is time-bounded, non-nestable, and visibly marked with a persistent banner plus an always-available end-session action. | Existing session timeout enforcement, reserved `Scope.impersonating_from`, and generated layout seams support timeout plus visible state; stop must live outside admin-only routes. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: test/example/lib/example/accounts/scope.ex] [VERIFIED: test/example/lib/example_web/components/layouts.ex] |
| IMPR-04 | While impersonating, Sigra forbids sensitive account-security mutations server-side, including password changes, MFA/passkey management, API-key management, and account deletion. | Dedicated `Sigra.Plug.ForbidDuringImpersonation` plus direct-path guard in generated Accounts wrappers should cover the concrete controllers and LiveViews already present in the example app. [VERIFIED: test/example/lib/example_web/router.ex] [VERIFIED: test/example/lib/example_web/controllers/session_controller.ex] [VERIFIED: test/example/lib/example/accounts.ex] |
| IMPR-05 | Ending impersonation returns the admin to their original context without destroying the original admin session. | Preserve the original raw admin token in Plug session state, restore it on stop/timeout, and leave the original `user_sessions` row valid. [VERIFIED: 29-CONTEXT.md] [VERIFIED: test/example/lib/example_web/user_auth.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Keep security-sensitive runtime library-owned and generated host code thin. [VERIFIED: CLAUDE.md]  
- Stay on Phoenix 1.8+ / Ecto 3.x patterns and use HTTP POST controller flows for login-like session transitions. [VERIFIED: CLAUDE.md]  
- Prefer existing repo patterns over new abstractions; add only additive seams. [VERIFIED: CLAUDE.md]  
- Tests must be comprehensive on happy path, main error paths, and boundaries. [VERIFIED: CLAUDE.md]  
- `mix test` in this repo requires a live Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs]  

## Summary

Phase 29 should be implemented as a thin generated Phoenix controller boundary over a new library-owned `Sigra.Impersonation` runtime that reuses Sigra's existing session store, scope hydrator, audit writer, and admin scope authorizer instead of introducing a parallel impersonation subsystem. [VERIFIED: 27-CONTEXT.md] [VERIFIED: 28-CONTEXT.md] [VERIFIED: lib/sigra/session_stores/ecto.ex] [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/admin/authorizer.ex]

The critical implementation detail is not session creation itself, because `Sigra.Auth.create_session/4` and `ExampleWeb.UserAuth.put_user_session_token/2` already cover fixation-safe token rotation. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] The real work is preserving the original admin raw token across `renew_session/1`, restoring it on stop or timeout, and making timeout recovery happen before the user falls into an ambiguous logged-out state. [VERIFIED: 29-CONTEXT.md] [VERIFIED: test/example/lib/example_web/user_auth.ex] [VERIFIED: test/example/lib/example/accounts.ex]

Audit attribution should stay a one-seam change in `Sigra.Audit.scope_fields/1`: during impersonation, `actor_id` must resolve from `scope.impersonating_from.id`, `effective_user_id` must resolve from `scope.user.id`, and `organization_id` must keep following the effective scope. [VERIFIED: 29-CONTEXT.md] [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/scope/hydration.ex] That preserves downstream queryability on canonical columns and keeps Phase 30 additive instead of corrective. [VERIFIED: 15-CONTEXT.md] [VERIFIED: lib/sigra/audit/query.ex]

**Primary recommendation:** Add a library-owned `Sigra.Impersonation` orchestrator plus a shared `Sigra.Plug.ForbidDuringImpersonation`, and keep generated changes limited to a controller seam, router wiring, `UserAuth` token-preservation helpers, and visible layout/banner seams. [VERIFIED: 27-CONTEXT.md] [VERIFIED: 29-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Start impersonation | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/router.ex] | API / Backend [VERIFIED: lib/sigra/auth.ex] | The entry point must be an HTTP controller guarded by `RequireSudo` and admin scope, while the actual authorization and session issuance stay in library code. [VERIFIED: 29-CONTEXT.md] [VERIFIED: lib/sigra/plug/require_sudo.ex] |
| Stop / timeout restore | Frontend Server (SSR) [ASSUMED] | Database / Storage [VERIFIED: lib/sigra/session_stores/ecto.ex] | Restoration must run in web-layer token/session code because Plug session renewal and cookies live there, but the persisted rows remain in `user_sessions`. [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| Impersonation scope hydration | API / Backend [VERIFIED: lib/sigra/scope/hydration.ex] | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/user_auth.ex] | The hydrator is already the single scope assembly point; Plug and LiveView callers must keep using it. [VERIFIED: 29-CONTEXT.md] |
| Persistent banner visibility | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/components/layouts.ex] | Browser / Client [VERIFIED: test/example/lib/example_web/components/admin_shell.ex] | Visibility belongs in host-owned HEEx/layout seams rendered by the server; there is no evidence of client-only session state in this repo. [VERIFIED: 16-CONTEXT.md] |
| Audit attribution | API / Backend [VERIFIED: lib/sigra/audit.ex] | Database / Storage [VERIFIED: test/example/lib/example/accounts/audit_event.ex] | `Sigra.Audit.scope_fields/1` and `audit_events` columns already own actor/effective-user composition. [VERIFIED: 15-CONTEXT.md] |
| Forbidden security mutations | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/router.ex] | API / Backend [VERIFIED: test/example/lib/example/accounts.ex] | Request plugs must stop controller paths early, and direct-path library calls still need an explicit runtime guard so LiveView/controller code cannot bypass protection accidentally. [VERIFIED: 29-CONTEXT.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix` | `~> 1.8` in this repo. [VERIFIED: mix.exs] | Router scopes, controllers, verified routes, layouts. [VERIFIED: test/example/lib/example_web/router.ex] | Phase 27 and Phase 29 both lock controller-owned flows and normal Phoenix route scopes instead of a separate admin framework. [VERIFIED: 27-CONTEXT.md] [VERIFIED: 29-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html#scope/2] |
| `phoenix_live_view` | `~> 1.1` in this repo. [VERIFIED: mix.exs] | Admin detail UI, `on_mount` parity, persistent layout state. [VERIFIED: test/example/lib/example_web/router.ex] | Existing admin pages already use LiveView with library-owned `on_mount` guards, so impersonation should extend that model rather than replace it. [VERIFIED: lib/sigra/live_view/admin_scope.ex] |
| `ecto` + `ecto_sql` | `~> 3.12` in this repo. [VERIFIED: mix.exs] | Persist `user_sessions` and `audit_events`. [VERIFIED: lib/sigra/session_stores/ecto.ex] [VERIFIED: test/example/lib/example/accounts/audit_event.ex] | D-02 explicitly rejects a new impersonation table, so existing session persistence remains the standard storage layer. [VERIFIED: 29-CONTEXT.md] |
| Existing Sigra runtime | repo-local modules. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/audit.ex] | Session issuance, scope hydration, audit attribution, admin authorization. | The repo already centralizes security-sensitive behavior in library code and keeps generated web code thin. [VERIFIED: 27-CONTEXT.md] [VERIFIED: 28-CONTEXT.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flop` + `flop_phoenix` | `~> 0.26.x` in this repo. [VERIFIED: mix.exs] | Existing admin list/query ergonomics. [VERIFIED: lib/sigra/admin/live/users_index_live.ex] | Reuse for returning to Phase 28 user-detail/list URLs after stop; do not add a second query-state mechanism. [VERIFIED: 28-CONTEXT.md] |
| `Sigra.Plug.RequireSudo` | repo-local plug. [VERIFIED: lib/sigra/plug/require_sudo.ex] | Fresh re-auth boundary for start impersonation. | Required on start routes; do not build a custom admin-only password prompt. [VERIFIED: 29-CONTEXT.md] |
| `Sigra.Admin.Scope` + `Sigra.Admin.Authorizer` | repo-local modules. [VERIFIED: lib/sigra/admin/scope.ex] [VERIFIED: lib/sigra/admin/authorizer.ex] | Global-vs-org impersonation authorization. | Required before creating an impersonation session or loading the target user. [VERIFIED: 29-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `user_sessions` rows [VERIFIED: 29-CONTEXT.md] | Separate `impersonation_sessions` table | Rejected by D-02 because it would fork timeout, revocation, and restoration behavior away from Sigra's established session model. [VERIFIED: 29-CONTEXT.md] |
| Controller POST/DELETE flows [VERIFIED: 29-CONTEXT.md] | LiveView event-only start/stop | Rejected by D-01 because session renewal and fixation-safe token swaps already live in controller-oriented `UserAuth` helpers. [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| `Sigra.Audit.scope_fields/1` attribution [VERIFIED: lib/sigra/audit.ex] | Metadata-only dual-actor tagging | Metadata-only tagging would weaken queryability that Phase 15 intentionally moved into canonical columns. [VERIFIED: 15-CONTEXT.md] [VERIFIED: test/example/lib/example/accounts/audit_event.ex] |

**Installation:**
```bash
# No new dependencies for Phase 29.
mix deps.get
```

**Version verification:** Phase 29 should not add packages; it should extend the repo-pinned Phoenix, LiveView, Ecto, and Flop stack already declared in [`mix.exs`](/Users/jon/projects/sigra/mix.exs). [VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Admin user detail LiveView
  -> POST /admin/.../users/:id/impersonation [RequireSudo + RequireAdminAccess]
    -> Generated ImpersonationController
      -> Sigra.Impersonation.start(config, admin_scope, target_user, opts)
        -> Sigra.Admin.Authorizer / scoped target lookup
        -> Sigra.Auth.create_session(...) for effective user
        -> audit "admin.impersonation.start"
      -> ExampleWeb.UserAuth.begin_impersonation(...)
        -> preserve raw admin token + return_to
        -> renew_session()
        -> put_session(:user_token, impersonation_raw_token)
        -> assign visible impersonation marker state
          -> next request / LiveView mount
            -> ExampleWeb.UserAuth.fetch_current_scope / mount_current_scope
              -> Accounts.get_user_and_session_by_token(raw_token)
              -> Sigra.Scope.Hydration.hydrate(...)
              -> current_scope.user = effective user
              -> current_scope.impersonating_from = admin user
                -> host layout / admin shell banner renders
                -> Sigra.Plug.ForbidDuringImpersonation blocks sensitive writes

Impersonation stop or timeout
  -> DELETE /impersonation OR timeout hook in UserAuth fetch path [ASSUMED]
    -> Sigra.Impersonation.stop_or_restore(...)
      -> validate preserved admin raw token
      -> delete impersonation session row
      -> audit stop/timeout event
      -> renew_session()
      -> restore :user_token = preserved admin raw token
      -> redirect to preserved return_to or login fallback
```

### Recommended Project Structure

```text
lib/
├── sigra/
│   ├── impersonation.ex                # start/stop/timeout orchestration
│   ├── plug/
│   │   └── forbid_during_impersonation.ex
│   ├── audit.ex                        # scope_fields/1 dual-actor diff
│   ├── audit/query.ex                  # optional impersonation-only filter
│   └── scope/hydration.ex              # hydrate impersonating_from + effective scope
priv/templates/sigra.install/
├── admin/
│   ├── impersonation_controller.ex     # generated host controller seam
│   ├── router_injection.ex             # start routes under admin scopes
│   └── admin_shell.ex                  # dedicated impersonation indicator copy
└── core/
    ├── user_auth.ex                    # begin/restore/timeout token helpers
    └── layouts.ex                      # app-wide banner seam, not admin-only
```

### Pattern 1: Thin Generated Controller, Library-Owned Runtime

**What:** Keep start/stop routing and Plug-session mutation in generated host files, but move authorization, session issuance, timeout policy, and audit writes into a new `Sigra.Impersonation` library module. [VERIFIED: 27-CONTEXT.md] [VERIFIED: test/example/lib/example_web/user_auth.ex]

**When to use:** For both platform-admin global routes and org-scoped admin routes. [VERIFIED: test/example/lib/example_web/router.ex]

**Example:**
```elixir
# Source: repo pattern from test/example/lib/example_web/user_auth.ex
def create(conn, %{"user_id" => user_id, "return_to" => return_to}) do
  admin_scope = conn.assigns.admin_scope
  admin_token = get_session(conn, :user_token)

  with {:ok, result} <-
         Sigra.Impersonation.start(Example.Accounts.sigra_config(), admin_scope, user_id,
           admin_token: admin_token,
           return_to: return_to
         ) do
    conn
    |> ExampleWeb.UserAuth.begin_impersonation(result)
    |> redirect(to: result.redirect_to)
  end
end
```

### Pattern 2: Preserve the Original Raw Admin Token in Plug Session State

**What:** The original admin session row stays in `user_sessions`; the browser preserves its raw token in Plug session keys that survive `renew_session/1`, then restores that raw token on stop or timeout. [VERIFIED: 29-CONTEXT.md] [VERIFIED: test/example/lib/example_web/user_auth.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex]

**When to use:** On impersonation start, stop, and timeout recovery. [VERIFIED: 29-CONTEXT.md]

**Example:**
```elixir
# Source: renew/clear pattern from test/example/lib/example_web/user_auth.ex
def begin_impersonation(conn, %{impersonation_token: token, admin_token: admin_token, return_to: return_to}) do
  conn
  |> renew_session_preserving(%{
    impersonator_token: admin_token,
    impersonator_return_to: return_to
  })
  |> put_session(:user_token, token)
end
```

### Pattern 3: Keep Scope Hydration Single-Path

**What:** Extend `Sigra.Scope.Hydration.hydrate/3` and the generated `UserAuth` fetch/mount paths so Plug and LiveView both receive the same `%Scope{user, active_organization, membership, impersonating_from}`. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex]

**When to use:** Every request and every LiveView mount while impersonation is active. [VERIFIED: 29-CONTEXT.md]

**Example:**
```elixir
# Source: repo scope assembly pattern from lib/sigra/scope/hydration.ex
defp scope_fields(%{user: user} = scope) do
  admin = Map.get(scope, :impersonating_from)
  org = Map.get(scope, :active_organization)

  [
    organization_id: org && org.id,
    effective_user_id: user && user.id,
    actor_id: (admin && admin.id) || (user && user.id)
  ]
end
```

### Anti-Patterns to Avoid

- **Admin-only stop route:** If stop lives only under `/admin`, impersonated users can lose the end-session path on normal app pages. [VERIFIED: test/example/lib/example_web/components/layouts.ex] [ASSUMED]
- **New impersonation table:** Duplicates timeout and restoration logic that already exists in `user_sessions`. [VERIFIED: 29-CONTEXT.md] [VERIFIED: lib/sigra/session_stores/ecto.ex]
- **Metadata-only attribution:** Breaks the Phase 15 design that made `effective_user_id` a first-class query column. [VERIFIED: 15-CONTEXT.md]
- **UI-only blocking:** The example app already exposes sensitive writes through controllers, LiveViews, and direct Accounts wrappers, so hidden buttons alone are not a boundary. [VERIFIED: test/example/lib/example_web/router.ex] [VERIFIED: test/example/lib/example/accounts.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Session swap and fixation defense | Custom cookie/token mutation logic separate from `UserAuth` [VERIFIED: test/example/lib/example_web/user_auth.ex] | Reuse `renew_session/1` plus additive preserve-and-restore helpers in generated `user_auth.ex` | The repo already relies on `renew_session/1` for login and MFA token rotation. [VERIFIED: test/example/lib/example_web/user_auth.ex] [CITED: https://hexdocs.pm/plug/Plug.Conn.html#configure_session/2] |
| Parallel impersonation storage | `impersonation_sessions` table | Existing `user_sessions` + preserved admin raw token | D-02 already rejects a parallel table and the store API already supports session create/delete/update. [VERIFIED: 29-CONTEXT.md] [VERIFIED: lib/sigra/session_store.ex] |
| Alternate audit assembler | Separate impersonation audit helper | `Sigra.Audit.scope_fields/1` | Phase 15 intentionally created this as the one-line v1.2 diff seam. [VERIFIED: 15-CONTEXT.md] [VERIFIED: lib/sigra/audit.ex] |
| Per-endpoint ad hoc impersonation checks | Endpoint-specific conditionals | Shared `Sigra.Plug.ForbidDuringImpersonation` + direct-path library guard helper | The blocked set spans controller, LiveView, and context paths, so the boundary must be reusable and centralized. [VERIFIED: 29-CONTEXT.md] |

**Key insight:** Phase 29 is safest when it behaves like "login into a second normal Sigra session while preserving the first raw token for restoration", not like "attach an impersonation flag onto the existing browser session". [VERIFIED: 29-CONTEXT.md] [VERIFIED: lib/sigra/auth.ex]

## Common Pitfalls

### Pitfall 1: Timeout Drops the Operator to Logged-Out State Instead of Restoring Admin Context

**What goes wrong:** The impersonation session expires, `fetch_current_scope` returns `nil`, and the preserved admin token is never restored. [ASSUMED]  
**Why it happens:** The example app currently looks up `{user, session}` directly in `Example.Accounts.get_user_and_session_by_token/1` and has no restore hook when the current raw token no longer maps to a session row. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex]  
**How to avoid:** Add timeout recovery to the generated `UserAuth.ensure_user_token/1` or `fetch_current_scope/2` path before assigning `current_scope`. [VERIFIED: test/example/lib/example_web/user_auth.ex]  
**Warning signs:** Expired impersonation leaves `:impersonator_token` in Plug session but `current_scope` becomes `nil`. [ASSUMED]  

### Pitfall 2: Audit Rows Keep Attributing the Impersonated User as the Actor

**What goes wrong:** Existing `scope_fields/1` sets both `actor_id` and `effective_user_id` from `scope.user.id`, which would hide the real admin during impersonation. [VERIFIED: lib/sigra/audit.ex]  
**Why it happens:** The current implementation is still the pre-impersonation Phase 15 version. [VERIFIED: lib/sigra/audit.ex]  
**How to avoid:** Make the Phase 29 change only in `scope_fields/1`, and keep callers passing scopes as they do today. [VERIFIED: 29-CONTEXT.md]  
**Warning signs:** `admin.impersonation.*` events and user actions emitted during impersonation show identical `actor_id` and `effective_user_id`. [ASSUMED]  

### Pitfall 3: Stop or Banner Exists Only in Admin Layout

**What goes wrong:** Once the operator is acting on normal user pages, the admin shell no longer renders and the end-session action disappears. [VERIFIED: test/example/lib/example_web/components/layouts.ex]  
**Why it happens:** The current dedicated special-session seam exists only in `AdminShell`; the main `Layouts.app/1` has no impersonation surface yet. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex] [VERIFIED: test/example/lib/example_web/components/layouts.ex]  
**How to avoid:** Add a shared host-owned impersonation banner seam to both `Layouts.app/1` and `Layouts.admin/1`, with the same end-session controller action behind it. [VERIFIED: 29-CONTEXT.md] [ASSUMED]  
**Warning signs:** The banner is visible on `/admin/...` but disappears after navigating into standard authenticated pages. [ASSUMED]  

### Pitfall 4: Forbidden-Operation Plug Covers Routes but Not Direct-Path Runtime Calls

**What goes wrong:** A blocked path remains reachable through a LiveView event or generated Accounts wrapper even if the obvious controller route is fenced. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/controllers/session_controller.ex]  
**Why it happens:** Sigra exposes many security operations through generated wrappers like `change_password/3`, `mfa_disable/3`, `register_passkey/3`, and `schedule_deletion/1`. [VERIFIED: test/example/lib/example/accounts.ex]  
**How to avoid:** Pair the plug with a small runtime helper such as `Sigra.Impersonation.assert_allowed!/2` and call it from the generated wrappers for blocked actions. [ASSUMED]  
**Warning signs:** The browser route is blocked but tests can still invoke the generated Accounts wrapper successfully under an impersonated scope. [ASSUMED]  

## Code Examples

Verified patterns from official sources and this repo:

### Session Renewal That Preserves Explicit Keys
```elixir
# Source: test/example/lib/example_web/user_auth.ex + Plug.Conn docs
defp renew_session_preserving(conn, preserved) do
  delete_csrf_token()

  conn
  |> configure_session(renew: true)
  |> clear_session()
  |> then(fn conn ->
    Enum.reduce(preserved, conn, fn {key, value}, acc ->
      if is_nil(value), do: acc, else: put_session(acc, key, value)
    end)
  end)
end
```
`configure_session(renew: true)` and `clear_session/1` are the documented Plug primitives already used by this repo's `UserAuth`. [VERIFIED: test/example/lib/example_web/user_auth.ex] [CITED: https://hexdocs.pm/plug/Plug.Conn.html#configure_session/2] [CITED: https://hexdocs.pm/plug/Plug.Conn.html#clear_session/1]

### Controller-Owned Start Route Under Existing Admin Scopes
```elixir
# Source: router scope pattern from test/example/lib/example_web/router.ex
scope "/", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_global, :require_sudo]

  post "/admin/users/:id/impersonation", ExampleWeb.Admin.ImpersonationController, :create
end

scope "/admin/organizations/:org", alias: false do
  pipe_through [:browser, :require_authenticated, :admin_organization, :require_sudo]

  post "/users/:id/impersonation", ExampleWeb.Admin.ImpersonationController, :create
end
```
This matches the repo's existing split between global and org admin scopes. [VERIFIED: test/example/lib/example_web/router.ex] [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html#scope/2]

### Audit Attribution Diff Point
```elixir
# Source: lib/sigra/audit.ex
defp scope_fields(%{user: user} = scope) do
  admin = Map.get(scope, :impersonating_from)
  org = Map.get(scope, :active_organization)

  [
    organization_id: org && org.id,
    effective_user_id: user && user.id,
    actor_id: (admin && admin.id) || (user && user.id)
  ]
end
```
This keeps Phase 15's single-seam design intact. [VERIFIED: 15-CONTEXT.md] [VERIFIED: lib/sigra/audit.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct auth/session flows renew the Plug session and swap the raw token in `UserAuth`. [VERIFIED: test/example/lib/example_web/user_auth.ex] | Impersonation should reuse the same controller + renewal pattern instead of adding a LiveView-only state transition. [VERIFIED: 29-CONTEXT.md] | Existing repo state as of 2026-04-16. [VERIFIED: test/example/lib/example_web/user_auth.ex] | Fixation protection stays aligned with login and MFA upgrade behavior. [VERIFIED: lib/sigra/auth.ex] |
| `Sigra.Audit.scope_fields/1` currently maps actor/effective user to the same principal. [VERIFIED: lib/sigra/audit.ex] | Phase 29 should diverge them only when `scope.impersonating_from` is present. [VERIFIED: 29-CONTEXT.md] | Planned for Phase 29. [VERIFIED: 29-CONTEXT.md] | Phase 30 can query impersonation using columns instead of metadata parsing. [VERIFIED: 15-CONTEXT.md] |
| Admin shell shows only a generic `"Special session"` badge. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex] | Phase 29 should render dedicated impersonation identity plus end-session action across app and admin layouts. [VERIFIED: 29-CONTEXT.md] | Planned for Phase 29. [VERIFIED: 29-CONTEXT.md] | Operators keep visible state outside `/admin`. [ASSUMED] |

**Deprecated/outdated:**
- Generic `special_session` labeling in [`test/example/lib/example_web/components/admin_shell.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex) is too vague for a security boundary and should be replaced by explicit impersonation copy. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex] [VERIFIED: 29-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Stop and timeout restoration should use a route outside admin-only scopes so the end action remains reachable while the effective user is non-admin. | Architecture Patterns / Pitfalls | The operator could get stuck in impersonation on non-admin pages. |
| A2 | The safest browser behavior is to clear any remember-me cookie on start and restore the admin token on stop, to avoid silent admin rehydration in a new tab while impersonation is active. | Session strategy | Parallel admin and impersonated contexts could become confusing or bypass visible banner expectations. |
| A3 | Pairing the plug with a runtime helper in generated Accounts wrappers is necessary because not every blocked operation is controller-only today. | Common Pitfalls | A direct-path call could bypass the forbidden-operation boundary. |

## Open Questions

1. **Should Phase 29 add `Sigra.Audit.Query` sugar for `:impersonation_only` now, or leave it for Phase 30?**
   - What we know: Existing canonical columns already support `actor_id`, `effective_user_id`, and `organization_id` filtering today. [VERIFIED: lib/sigra/audit/query.ex]
   - What's unclear: Whether Phase 29 needs the convenience filter for tests before the Phase 30 explorer exists. [ASSUMED]
   - Recommendation: Keep Phase 29 correctness on the column writes; add `:impersonation_only` only if a concrete Phase 29 test becomes noisy without it. [VERIFIED: 29-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Compile and ExUnit coverage | ✓ [VERIFIED: local shell] | `Mix 1.19.5` [VERIFIED: local shell] | — |
| Node.js / npm | Existing Playwright/browser artifact tooling in the example app | ✓ [VERIFIED: local shell] | `v22.14.0` / `11.1.0` [VERIFIED: local shell] | Direct ExUnit coverage only |
| PostgreSQL CLI | Local DB verification and ad hoc inspection | ✓ [VERIFIED: local shell] | `psql 14.17` [VERIFIED: local shell] | — |
| Postgres server on `localhost:5432` | `mix test` in this repo | ✗ [VERIFIED: local shell] | — | Start local container per `CLAUDE.md` |

**Missing dependencies with no fallback:**
- A running Postgres instance on `localhost:5432` is required for full `mix test` coverage in this repo. [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs] [VERIFIED: local shell]

**Missing dependencies with fallback:**
- Browser verification can be deferred to Phase 31 because Phase 29's critical boundaries are still coverable with controller, LiveView, and direct-path ExUnit tests. [VERIFIED: ROADMAP.md] [ASSUMED]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with Phoenix ConnCase and LiveViewTest. [VERIFIED: test/test_helper.exs] [VERIFIED: test/example/test/support/conn_case.ex] |
| Config file | [`test/test_helper.exs`](/Users/jon/projects/sigra/test/test_helper.exs) and [`test/example/test/test_helper.exs`](/Users/jon/projects/sigra/test/example/test/test_helper.exs). [VERIFIED: repo grep] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/audit/log_safe_scope_test.exs test/sigra/live_view/admin_scope_test.exs test/sigra/plug/require_admin_access_test.exs` [VERIFIED: local repo layout] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMPR-01 | Start impersonation rotates into effective-user session while preserving admin raw token | integration | `mix test test/example/test/example_web/controllers/admin_impersonation_controller_test.exs -x` | ❌ Wave 0 |
| IMPR-02 | Org admin cannot impersonate out-of-scope user; denied attempts audit | integration | `mix test test/example/test/example_web/controllers/admin_impersonation_controller_test.exs -x` | ❌ Wave 0 |
| IMPR-03 | Banner appears on admin and app layouts; timeout restores or logs out safely | liveview/integration | `mix test test/example/test/example_web/live/impersonation_banner_live_test.exs -x` | ❌ Wave 0 |
| IMPR-04 | Password/MFA/passkey/API-key/account-deletion paths are blocked during impersonation | controller + direct-path | `mix test test/example/test/example_web/controllers/impersonation_forbidden_ops_test.exs -x` | ❌ Wave 0 |
| IMPR-05 | Stop returns to preserved admin context and prior `return_to` path | integration | `mix test test/example/test/example_web/controllers/admin_impersonation_controller_test.exs -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** targeted ExUnit file(s) for the touched boundary. [VERIFIED: repo test layout]
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test`. [VERIFIED: CLAUDE.md]
- **Phase gate:** full suite green before `/gsd-verify-work`. [VERIFIED: workflow config in .planning/config.json]

### Wave 0 Gaps
- [ ] `test/sigra/impersonation_test.exs` — library orchestration, non-nesting, timeout policy, audit action names.
- [ ] `test/sigra/plug/forbid_during_impersonation_test.exs` — shared blocked-operation plug behavior.
- [ ] `test/sigra/scope/hydration_impersonation_test.exs` — Plug/LiveView parity for `impersonating_from`.
- [ ] `test/example/test/example_web/controllers/admin_impersonation_controller_test.exs` — start/stop flows, sudo enforcement, return-to restoration.
- [ ] `test/example/test/example_web/controllers/impersonation_forbidden_ops_test.exs` — blocked controller endpoints.
- [ ] `test/example/test/example_web/live/impersonation_banner_live_test.exs` — persistent visible state on app/admin layouts.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: REQUIREMENTS.md] | Start requires `Sigra.Plug.RequireSudo` and stop/timeout restore uses existing Sigra session semantics. [VERIFIED: lib/sigra/plug/require_sudo.ex] [VERIFIED: lib/sigra/auth.ex] |
| V3 Session Management | yes [VERIFIED: REQUIREMENTS.md] | Reuse `user_sessions`, fixation-safe `renew_session/1`, and explicit idle/absolute timeout checks. [VERIFIED: lib/sigra/session_stores/ecto.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] [VERIFIED: lib/sigra/plug/fetch_session.ex] |
| V4 Access Control | yes [VERIFIED: REQUIREMENTS.md] | `Sigra.Admin.Scope`, `Sigra.Admin.Authorizer`, and a shared impersonation-forbid boundary. [VERIFIED: lib/sigra/admin/scope.ex] [VERIFIED: lib/sigra/admin/authorizer.ex] |
| V5 Input Validation | yes [VERIFIED: repo patterns] | Reuse existing local-path `return_to` validation and typed route params. [VERIFIED: test/example/lib/example_web/controllers/auth/sudo_controller.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| V6 Cryptography | yes [VERIFIED: repo patterns] | Keep using Sigra's existing raw-token/hash split and secure session handling; do not invent new token formats. [VERIFIED: lib/sigra/token.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Nested impersonation | Elevation of Privilege | Explicit non-nesting guard before session creation plus denied audit event. [VERIFIED: 29-CONTEXT.md] |
| Silent sensitive mutation while impersonating | Tampering | Shared server-side forbidden-operation plug and runtime guard. [VERIFIED: 29-CONTEXT.md] |
| Lost real-actor attribution | Repudiation | `actor_id` from `impersonating_from`, `effective_user_id` from `current_scope.user`. [VERIFIED: 29-CONTEXT.md] [VERIFIED: lib/sigra/audit.ex] |
| Session fixation during start/stop | Spoofing | Reuse `renew_session/1` and explicit raw-token rewrite instead of mutating the session map in place. [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| Stale preserved admin token | Denial of Service | On timeout/stop, validate the preserved token; if invalid, clear impersonation and redirect to normal login with audit evidence. [VERIFIED: 29-CONTEXT.md] [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- [`lib/sigra/auth.ex`](/Users/jon/projects/sigra/lib/sigra/auth.ex) - existing session create/delete/sudo/MFA rotation behavior.
- [`lib/sigra/session_stores/ecto.ex`](/Users/jon/projects/sigra/lib/sigra/session_stores/ecto.ex) - canonical persisted session row behavior.
- [`lib/sigra/scope/hydration.ex`](/Users/jon/projects/sigra/lib/sigra/scope/hydration.ex) - single hydration seam.
- [`lib/sigra/audit.ex`](/Users/jon/projects/sigra/lib/sigra/audit.ex) - current `scope_fields/1` attribution behavior.
- [`lib/sigra/audit/query.ex`](/Users/jon/projects/sigra/lib/sigra/audit/query.ex) - current canonical audit filters.
- [`lib/sigra/admin/authorizer.ex`](/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex) and [`lib/sigra/admin/scope.ex`](/Users/jon/projects/sigra/lib/sigra/admin/scope.ex) - admin scope enforcement.
- [`test/example/lib/example_web/user_auth.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex) - fixation-safe token swap and Plug/LiveView auth seams.
- [`test/example/lib/example_web/router.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/router.ex) - current auth, sudo, admin, and passkey route boundaries.
- [`test/example/lib/example_web/controllers/session_controller.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/controllers/session_controller.ex) - concrete sensitive controller endpoints that Phase 29 must fence.
- [`test/example/lib/example/accounts.ex`](/Users/jon/projects/sigra/test/example/lib/example/accounts.ex) - direct-path generated wrappers for sensitive operations.
- [`test/example/lib/example_web/components/layouts.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/components/layouts.ex) and [`test/example/lib/example_web/components/admin_shell.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex) - current visible shell seams.
- [`test/example/lib/example/accounts/scope.ex`](/Users/jon/projects/sigra/test/example/lib/example/accounts/scope.ex) and [`test/example/lib/example/accounts/audit_event.ex`](/Users/jon/projects/sigra/test/example/lib/example/accounts/audit_event.ex) - reserved scope field and canonical audit columns.

### Secondary (MEDIUM confidence)
- https://hexdocs.pm/phoenix/Phoenix.Router.html#scope/2 - Phoenix route-scope reference used to confirm the controller-owned route recommendation. [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html#scope/2]
- https://hexdocs.pm/plug/Plug.Conn.html#configure_session/2 - Plug session renewal reference used to confirm `renew_session/1` reuse. [CITED: https://hexdocs.pm/plug/Plug.Conn.html#configure_session/2]
- https://hexdocs.pm/plug/Plug.Conn.html#clear_session/1 - Plug session clearing reference used to confirm preserved-key rewrite strategy. [CITED: https://hexdocs.pm/plug/Plug.Conn.html#clear_session/1]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phase 29 should reuse already-pinned repo dependencies and existing runtime seams. [VERIFIED: mix.exs] [VERIFIED: repo files]
- Architecture: MEDIUM - The controller/runtime split is strongly supported by repo patterns, but the exact stop-route placement outside admin scopes is still an implementation inference. [VERIFIED: repo files] [ASSUMED]
- Pitfalls: MEDIUM - The main risks are grounded in current code paths, but timeout-restore behavior is not implemented yet and therefore partly inferred. [VERIFIED: repo files] [ASSUMED]

**Research date:** 2026-04-16
**Valid until:** 2026-05-16
