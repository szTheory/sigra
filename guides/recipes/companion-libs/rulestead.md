<!-- validated_against: rulestead ~> 0.1 -->
<!-- last_validated: 2026-05-29 -->
# Recipe: Sigra + Rulestead (feature-flag gating from current_scope)

Validated against: `rulestead ~> 0.1` (`0a18360`) as of 2026-05-29

> **Sigra works fully standalone.** Rulestead is an optional integration; Sigra ships without it, and removing the wiring below returns Sigra to standalone operation with no further changes.

## What this is

| Role | Library | Responsibility |
|------|---------|----------------|
| Auth context + scope | **Sigra** | Populates `current_scope` (user, role, org, membership) that Rulestead reads for flag evaluation and policy authorization |
| Feature-flag evaluation + admin UI | **Rulestead** | Stores flags, evaluates `enabled?`, and manages admin access control via `RulesteadPolicy` |

Sigra supplies the **evaluation context** — `current_scope.role`, `current_scope.user`, and
related fields. Rulestead owns **flag storage, the evaluator, and the admin UI**. Neither
library calls the other directly.

## Prerequisites

- **Sigra session and scope are working first** — `current_scope` must be populated by the
  Sigra plug pipeline before Rulestead reads from it.
- **Rulestead `~> 0.1` is installed and configured** — Rulestead's narrative GA is 1.0.0 but
  the published Hex line is `~> 0.1`; pin `~> 0.1` in your `mix.exs`.
- **For the admin UI only:** add `{:rulestead_admin, "~> 0.1"}` as a separate dep (see the
  optional admin-mount section below).

## `mix.exs` snippet

**Host app only** — Sigra does not add Rulestead as a dependency.

```elixir
defp deps do
  [
    {:sigra, "~> 1.4.0"},
    {:rulestead, "~> 0.1"},
    # ... your other deps
  ]
end
```

If you are reading `main` before Hex shows `1.0.0`, use the latest published Sigra package or a source checkout until the release PR lands.

## Gating a Sigra-protected controller action

Rulestead exposes two `enabled?` surfaces with different calling conventions:

- **`Rulestead.Runtime.enabled?/3`** (`environment_key, flag_key, context`) — the Phoenix
  convenience form. Takes a string environment key, a string flag key, and a Rulestead context
  map built from `conn.assigns`. This is the canonical entry point for a Sigra-protected
  controller (per the Rulestead README:84-85).
- **`Rulestead.enabled?/2`** (`flag_payload, context`) at `rulestead.ex:1189-1194` — the
  low-level payload-first contract the Runtime form wraps. Signature:
  `@spec enabled?(map(), Context.t() | keyword() | map()) :: {:ok, boolean()} | {:error, Error.t()}`.
  README:88-89 describes this as "the explicit contract" — use it when you already hold a
  resolved flag payload.

In a Sigra-protected controller, use `Rulestead.Runtime.enabled?/3`:

```elixir
defmodule MyAppWeb.CheckoutController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    scope = conn.assigns.current_scope

    context = %{
      user_id: scope.user.id,
      organization_id: scope.active_organization_id,
      role: scope.role
    }

    case Rulestead.Runtime.enabled?("production", "checkout_v2", context) do
      {:ok, true} ->
        render(conn, :index_v2)

      {:ok, false} ->
        render(conn, :index)

      {:error, reason} ->
        # Flag lookup error — default to the stable path
        Logger.warning("Rulestead flag error: #{inspect(reason)}")
        render(conn, :index)
    end
  end
end
```

`current_scope` is populated by Sigra's plug pipeline at `lib/sigra/scope.ex:16-25`
(`Sigra.Scope.build/3`). The full field bus on the host-generated `%Scope{}` struct includes
`:user`, `:active_organization`, `:active_organization_id`, `:membership`, `:role`,
`:auth_method`, `:impersonating_from`, `:token_id`, and `:id`.

## Admin UI and `RulesteadPolicy`

To mount the Rulestead admin UI, add the separate `{:rulestead_admin, "~> 0.1"}` package:

```elixir
defp deps do
  [
    {:sigra, "~> 1.4.0"},
    {:rulestead, "~> 0.1"},
    {:rulestead_admin, "~> 0.1"},
    # ... your other deps
  ]
end
```

If you are reading `main` before Hex shows `1.0.0`, use the latest published Sigra package or a source checkout until the release PR lands.

Mount the admin UI in your router and supply a `RulesteadPolicy` module:

```elixir
import Rulestead.Admin.Router

scope "/admin" do
  pipe_through :browser
  rulestead_admin "/flags", policy: MyApp.RulesteadPolicy
end
```

(Per README:111.)

### Implementing `RulesteadPolicy`

The host module implements the `Rulestead.Admin.Policy` behaviour (defined at `policy.ex:121`,
verified against rulestead v0.1.3 `0a18360` on 2026-05-29; dispatched from `authorizer.ex:149`).
Implement the one required callback `can?/4`, which returns a boolean:

| Argument | Type | Description |
|----------|------|-------------|
| `actor` | `%{id, display, roles}` | Normalized actor map; `roles` is `[:viewer \| :editor \| :admin]` per `authorizer.ex:294-308` |
| `action` | atom | The action being authorized (e.g. `:read`, `:write`) |
| `resource` | term | The resource being acted upon |
| `environment_key` | String.t() | The Rulestead environment key |

Configure the policy module:

```elixir
config :rulestead, :admin_policy, MyApp.RulesteadPolicy
```

```elixir
defmodule MyApp.RulesteadPolicy do
  @behaviour Rulestead.Admin.Policy

  @doc """
  Authorize Rulestead admin actions.
  actor.roles derives from current_scope.role via the admin session.
  """
  @impl Rulestead.Admin.Policy
  def can?(%{roles: roles}, action, _resource, _environment_key) do
    cond do
      :admin in roles -> true
      action == :read and (:editor in roles or :viewer in roles) -> true
      action == :write and :editor in roles -> true
      true -> false
    end
  end

  # Optional callbacks — implement only if you use Rulestead governance actions
  # (publish_ruleset, advance_rollout, engage_kill_switch, release_kill_switch,
  # promote_environment). If omitted, Rulestead falls back to its internal defaults.
  #
  #   @impl Rulestead.Admin.Policy
  #   def change_request_required?(actor, action, resource, environment_key), do: ...
  #
  #   @impl Rulestead.Admin.Policy
  #   def allow_self_approval?(actor, action, resource, environment_key), do: ...
end
```

The `actor.roles` list is built from `current_scope.role` (a field on the host-generated
`%Scope{}` struct) when the user logs into the Rulestead admin session.

## Failure modes

### 1. Rulestead dep absent at boot

If `{:rulestead, "~> 0.1"}` is absent from the host's compiled deps, calls to
`Rulestead.Runtime.enabled?/3` raise `UndefinedFunctionError`. No Sigra boot warning is
emitted. Always gate Rulestead calls with a `Code.ensure_loaded?/1` check if the dep is
conditionally present.

### 2. `Rulestead.Runtime.enabled?/3` returns `{:error, _}`

Flag lookup can fail if the flag key does not exist in the specified environment, or if the
Rulestead store is unreachable. Default to the stable code path on error — do not let flag
evaluation failures propagate to users. Log the error for investigation.

### 3. `RulesteadPolicy.can?/4` returns `false` for a legitimate admin

If `current_scope.role` is not mapping to the expected Rulestead roles in the actor
normalization step, the admin may be denied access. Log `actor.roles` at the `can?/4` call
site to confirm the mapping from `current_scope.role` is correct.

### 4. `rulestead_admin` package missing when the admin route is mounted

If `{:rulestead_admin, "~> 0.1"}` is absent from compiled deps, mounting the admin route
raises a compile-time error. The core `{:rulestead, "~> 0.1"}` dep does not include the admin
UI; it is a separate optional package.

## Non-goals

- Sigra owns **no flag storage, evaluator, or admin UI**. `current_scope` only supplies the
  evaluation and authorization context that Rulestead reads.
- There is **no `--with-rulestead` install flag** in `mix sigra.install`. The wiring above
  is pure host-side configuration; no Sigra generator support is needed or planned.
- Sigra does **not** normalize `current_scope.role` to Rulestead's `[:viewer, :editor, :admin]`
  role list — that mapping is host-owned logic inside `RulesteadPolicy`.

## See also

- [Suite integration overview](../../introduction/suite-integration.html) — companion-library
  ecosystem diagram and Diminishing Returns Wall framing
- [Accrue recipe](./accrue.html) — seat-limit gating and subscription lifecycle; another
  pattern that reads `current_scope` from the Sigra plug pipeline
- [Lockspire recipe](./lockspire.html) — embedded OAuth/OIDC provider using the same
  `current_scope.user` field this recipe references
