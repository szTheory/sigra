<!-- validated_against: accrue ~> 1.2 -->
<!-- last_validated: 2026-05-28 -->
# Recipe: Sigra + Accrue (seat-limit gating + subscription lifecycle)

Validated against: `accrue ~> 1.2` as of 2026-05-28

> **Sigra works fully standalone.** Accrue is an optional integration; Sigra ships without it, and removing the wiring below returns Sigra to standalone operation with no further changes.

## What this is

| Role | Library | Responsibility |
|------|---------|----------------|
| Seat-limit seam + lifecycle hooks | **Sigra** | Exposes `before_add_member/4` and `after_member_remove/2` callbacks (`lib/sigra/organizations/callbacks.ex:17-18, 38-48`); fires `on_delete` lifecycle hook (`lib/sigra/hooks.ex:1-103`); owns `AuditEvent` source-of-truth (`lib/sigra/audit.ex`) |
| Seat accounting + subscription state | **Accrue** | Tracks seat counts, billing limits, and subscription lifecycle; exposes the `Accrue.Auth` behaviour the host implements |

Sigra owns the **seam** — the callback that fires at membership add/remove and the lifecycle hook that fires at user delete. Accrue owns the **logic** — seat limits, subscription state, and billing semantics. Neither library calls the other directly.

## Prerequisites

- **Sigra organizations + hooks must be green first** — confirm that organization create/delete, membership add/remove, and user delete flows are working in `dev` and `test` before wiring Accrue callbacks. The callbacks augment a working membership pipeline; they do not establish one.
- **Accrue `~> 1.2` is installed in your host app** — add it to `mix.exs` (see snippet below) and run Accrue's bootstrap generators per the [Accrue README](https://hex.pm/packages/accrue).

## `mix.exs` snippet

**Host app only** — Sigra does not add Accrue as a dependency.

```elixir
defp deps do
  [
    {:sigra, "~> 1.0"},
    {:accrue, "~> 1.2"},
    # ... your other deps
  ]
end
```

If you are reading `main` before Hex shows `1.0.0`, use the latest published `0.3.x` Sigra package or a source checkout until the release PR lands.

## Wiring overview

Two Sigra seams connect to Accrue:

1. **Organizations callbacks (seat gating on membership add/remove)** — pinned to
   `lib/sigra/organizations/callbacks.ex:17-18, 38-48`
2. **User-lifecycle hooks (subscription cleanup on user delete)** — pinned to
   `lib/sigra/hooks.ex:1-103`

Both paths flow through a single host module that implements the `Accrue.Auth` behaviour
(`accrue/lib/accrue/auth.ex:41-49`).

### 1. Implement the `Accrue.Auth` behaviour

The host module bridges Sigra's identity context into Accrue. The behaviour requires five
callbacks and accepts two optional ones:

| Callback | Arity | Status |
|----------|-------|--------|
| `current_user/1` | 1 | required |
| `require_admin_plug/0` | 0 | required |
| `user_schema/0` | 0 | required |
| `log_audit/2` | 2 | required |
| `actor_id/1` | 1 | required |
| `step_up_challenge/2` | 2 | optional |
| `verify_step_up/3` | 3 | optional |

```elixir
defmodule MyApp.Accrue.Auth do
  @behaviour Accrue.Auth

  @impl Accrue.Auth
  def current_user(conn), do: conn.assigns.current_scope.user

  @impl Accrue.Auth
  def require_admin_plug, do: MyApp.AdminPlug

  @impl Accrue.Auth
  def user_schema, do: MyApp.Accounts.User

  @impl Accrue.Auth
  def log_audit(user, event_map) do
    # Forward to the Sigra audit pipeline; Sigra's AuditEvent row stays source-of-truth.
    # See lib/sigra/audit.ex and the Threadline recipe for event-type filtering options.
    Sigra.Audit.log("billing.seat.added",
      actor_id: user.id,
      actor_type: "user",
      metadata: Map.take(event_map, [:action, :target_id, :target_type, :reason])
    )
  end

  @impl Accrue.Auth
  def actor_id(user), do: user.id
end
```

Register in your Sigra config:

```elixir
config :accrue, :auth_adapter, MyApp.Accrue.Auth
```

**`log_audit/2` note:** Accrue's `log_audit/2` is a consumer of identity-event side-effects,
not a destination swap. Sigra's `AuditEvent` row (`lib/sigra/audit.ex`) remains the
source-of-truth. To filter audit events by type before forwarding, see the
[Audit logging flow](../../flows/audit-logging.html) and the [Threadline recipe](./threadline.html).

### 2. Gate membership adds on seat limits

Override `before_add_member/4` in your generated organizations module. The callback is defined
at `lib/sigra/organizations/callbacks.ex:38-39` — returning `{:error, reason}` aborts the
enclosing `Ecto.Multi` transaction (per the `callbacks.ex:17` table row "Can abort — Check seat
limits"):

```elixir
defmodule MyApp.Organizations do
  use Sigra.Organizations

  @impl Sigra.Organizations.Callbacks
  def before_add_member(org, _user, _role, _scope) do
    case Accrue.check_seat_limit(org.id) do
      :ok -> :ok
      {:error, :seat_limit_reached} -> {:error, :seat_limit_reached}
    end
  end
end
```

### 3. Release seats on membership remove

Override `after_member_remove/2` (defined at `lib/sigra/organizations/callbacks.ex:47-48`)
to notify Accrue when a membership is removed:

```elixir
@impl Sigra.Organizations.Callbacks
def after_member_remove(membership, _scope) do
  Accrue.release_seat(membership.organization_id, membership.user_id)
  :ok
end
```

### 4. Clean up subscriptions on user delete

Wire an `on_delete` hook via `lib/sigra/hooks.ex:1-103` to cancel any Accrue subscription
when a user is deleted. Hooks are read from your `Sigra.Config` struct — add them to the
`Sigra.Config.new!/1` call inside your `MyApp.Auth.sigra_config/0`, **not** to `config :sigra`
app env (the app-env path is not read by hook dispatch and the hook will silently never fire):

```elixir
# in MyApp.Auth.sigra_config/0
Sigra.Config.new!(
  repo: MyApp.Repo,
  # ... your other Sigra config ...
  hooks: [
    on_delete: {MyApp.AccrueHooks, :on_user_delete}
  ]
)
```

```elixir
defmodule MyApp.AccrueHooks do
  def on_user_delete(multi, %{user: user}) do
    {:ok, Ecto.Multi.run(multi, :cancel_accrue_subscription, fn _repo, _changes ->
      Accrue.cancel_user_subscription(user.id)
      {:ok, :cancelled}
    end)}
  end
end
```

The hook receives the `Ecto.Multi` and context map and must return `{:ok, multi}` or
`{:error, reason}`. Returning `{:error, _}` aborts the delete transaction.

## Failure modes

### 1. Accrue dep absent at boot

If `{:accrue, "~> 1.2"}` is absent from the host's compiled deps, `Accrue.check_seat_limit/1`
and other Accrue calls will raise `UndefinedFunctionError` at runtime. No Sigra boot warning
is emitted — Sigra does not know whether Accrue is present. Guard with a `Code.ensure_loaded?/1`
check or ensure the dep is in your `mix.exs` before enabling the callbacks.

### 2. `before_add_member/4` returns `{:error, _}` — membership add aborted

When `before_add_member/4` returns `{:error, reason}`, the enclosing `Ecto.Multi` is aborted
and the `add_member` call returns `{:error, :before_add_member, reason, %{}}`.
The caller (controller or LiveView) is responsible for translating `reason` to a user-facing
message. No partial state is written.

### 3. `log_audit/2` raises

If `MyApp.Accrue.Auth.log_audit/2` raises, the exception propagates to the caller. Wrap the
body in a `try/rescue` to prevent audit side-effects from aborting auth operations. Sigra's own
`AuditEvent` write happens inside the originating transaction and is not affected by a
post-commit `log_audit/2` failure.

### 4. `on_delete` hook returns `{:error, _}` — user delete aborted

If `on_user_delete/2` returns `{:error, reason}`, the user-delete transaction is aborted.
Investigate whether `Accrue.cancel_user_subscription/1` is returning an error and whether the
delete should proceed regardless. If Accrue cancellation should not block deletes, return `:ok`
unconditionally and log the error instead.

## Non-goals

- Sigra owns the **seam** (the callback and hook execution points), not the seat-limit logic.
  Seat counts, billing limits, and subscription state live entirely in Accrue.
- There is **no `--with-accrue` install flag** in `mix sigra.install`. No precedent exists for
  companion-lib install flags; the wiring above requires no generator support.
- Sigra does **not** manage Accrue webhook subscriptions, billing events, or invoice state.
  The `log_audit/2` bridge makes Sigra identity events available to Accrue as a consumer; it
  does not swap the Sigra `AuditEvent` for an Accrue-shaped destination.

## See also

- [Audit logging flow](../../flows/audit-logging.html) — how Sigra writes `AuditEvent` rows and
  emits telemetry; event-type filtering for `log_audit/2` forwarding
- [Threadline recipe](./threadline.html) — forwarding audit events to Threadline for queryable
  timelines; `log_audit/2` and the Threadline forwarder complement each other
- [Suite integration overview](../../introduction/suite-integration.html) — companion-library
  ecosystem diagram and Diminishing Returns Wall framing
- [Mailglass recipe](./mailglass.html) — wiring transactional auth email via Mailglass
