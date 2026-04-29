defmodule Sigra.Authz do
  @moduledoc """
  Role-agnostic authorization seam for host applications.

  Phase 92 / B2B-02 ships RBAC as a *seam*, not as a permission engine.
  Sigra exposes a single behaviour with one callback (`c:can?/3`) and
  defines no role taxonomy — host applications own which actions exist,
  which subjects are privileged, and how scope is interpreted.

  ## Why no built-in roles?

  Earlier defaults that named specific role atoms leaked an opinionated
  permission model into every Sigra-consuming app. Hosts with different
  role universes were forced to either accept the canonical names or
  fight the library.

  The Phase 92 contract is the opposite:

    * The library ships **only** this behaviour.
    * The library does **not** ship a default `can?/3` implementation.
    * The library does **not** ship `allow?/3`, `deny?/3`, or any other
      pre-baked policy helper that would re-introduce hidden defaults.
    * Host applications generate (or hand-write) a module that
      `@behaviour Sigra.Authz` and answer the callback for the actions
      and subjects that matter to them. The Plan 92-02 generator emits
      a host-owned starter that returns `true` for every call; the
      Plan 92-04 recipe walks hosts through hardening that to
      deny-by-default semantics.

  ## Callback contract

  Implementations must answer `can?(action, subject, scope)`:

    * `action` — an arbitrary host-defined term naming the operation
      under question (typically an atom or `{action, resource}` tuple).
    * `subject` — an arbitrary host-defined term identifying the actor
      whose privilege is being evaluated. Hosts commonly pass the
      current user struct or a service-account principal.
    * `scope` — the request scope. In Phase 92, generated host code
      passes the `current_scope` struct produced by
      `Sigra.Scope.Hydration`. The struct may carry a `:role` and a
      reserved-for-Phase-93 `:actor_type` (Plan 92-02). Hosts are free
      to ignore either field.

  Implementations must return a plain `boolean()`. The library does not
  interpret `:ok` / `:error` tuples or any other shape — keep the
  contract narrow so policy semantics stay readable.

  ## Example

      defmodule MyApp.Authz do
        @behaviour Sigra.Authz

        @impl Sigra.Authz
        def can?(:read, _subject, _scope), do: true
        def can?({:manage, :billing}, _subject, %{role: :tenant_lead}), do: true
        def can?(_action, _subject, _scope), do: false
      end

  Plug into request scopes from controllers, LiveViews, or background
  jobs by calling `MyApp.Authz.can?(action, subject, scope)`. The
  library never invokes the host module on its own.

  ## Phase 92 boundaries

    * Phase 92 adds the seam and the host-owned starter.
    * Phase 92 does **not** add a Sigra-side default policy helper or
      a permission engine.
    * Phase 93 reserves a `:service_account` `:actor_type` on the
      generated scope struct; the library still does not interpret it.

  See `.planning/phases/92-rbac-seams-b2b-02/` for the design notes
  and the deny-by-default recipe (Plan 92-04).
  """

  @typedoc """
  Caller-defined action term. Sigra does not constrain the shape; common
  shapes include atoms (`:read`) or tuples (`{:manage, :billing}`).
  """
  @type action :: term()

  @typedoc """
  Caller-defined subject term. Typically the current user struct or a
  service-account principal — Sigra does not require any particular shape.
  """
  @type subject :: term()

  @typedoc """
  Caller-defined scope term. In Phase 92 the generated wiring passes the
  `current_scope` struct from `Sigra.Scope.Hydration`, but hosts may pass
  any term they like — Sigra does not interpret it.
  """
  @type scope :: term()

  @doc """
  Decide whether `subject` may perform `action` within `scope`.

  Returns `true` to allow, `false` to deny. The library does not
  recognize any other return shape.
  """
  @callback can?(action, subject, scope) :: boolean()
end
