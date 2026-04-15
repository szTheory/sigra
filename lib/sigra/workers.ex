defmodule Sigra.Workers do
  @moduledoc """
  Behaviour contract for Sigra-aware background workers that require
  tenant context. Pure `@callback` contract — the behaviour itself has
  zero compile-time dependency on any background job library.

  Workers implementing this behaviour:

  1. Accept stringified `"organization_id"` and `"actor_id"` args (nil values
     OK, absent keys NOT OK).
  2. Reconstruct a minimal `%Scope{}` in `perform/1` via `Sigra.Scope.build/3`.
  3. Emit audits through `Sigra.Audit.log_safe/3` with the reconstructed scope.

  ## Worker scopes are audit-only

  Host apps MUST NOT pass a worker-reconstructed scope to authorization
  functions. Worker scopes carry only `user.id` and
  `active_organization.id` — no request, no session, no membership. They
  exist solely so that `Sigra.Audit.log_safe/3` picks up the right IDs
  without a separate call shape.

  ## Not every worker needs this

  `Sigra.Workers.AuditCleanup`, `TokenCleanup`, and `EmailDelivery` are
  genuinely tenant-agnostic and deliberately do NOT implement this
  behaviour. Use it when and only when the worker emits tenant-relevant
  audits.

  ## v1.2 notes

  When impersonation ships in v1.2, workers enqueued by an impersonator will
  receive `"impersonating_from"` as an additional stringified arg, and
  `perform/1` will thread it through `Sigra.Scope.build/3` — a purely
  additive change. The current callback shape does NOT need to change.
  """

  @callback perform(scope :: term() | nil, args :: map()) ::
              :ok | {:ok, term()} | {:error, term()} | {:snooze, pos_integer()}

  # Stringified keys — background job libraries typically serialize args
  # via JSON so all keys become strings by the time perform/1 runs. The
  # behaviour validates the SAME stringified keys at enqueue time so
  # new/3 and fetch_arg!/2 agree.
  @required_keys ["organization_id", "actor_id"]

  @doc """
  Enqueue a job with fail-fast validation that required tenant keys are
  present. Nil values are allowed (pre-auth / system jobs); absent keys
  raise.

  `audit_schema` is intentionally NOT in the required-keys list — it is a
  worker-specific concern. Workers that emit audits add `"audit_schema"`
  to their own arg list and validate it in their own `perform/1`.
  """
  @spec new(module(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def new(worker, args, opts \\ []) when is_atom(worker) and is_map(args) do
    missing = Enum.reject(@required_keys, &Map.has_key?(args, &1))

    if missing != [] do
      raise ArgumentError,
            "Sigra.Workers.new/3: missing required args #{inspect(missing)}. " <>
              "Every Sigra-aware worker must receive #{inspect(@required_keys)} " <>
              "(nil values are permitted, absent keys are not)."
    end

    apply(worker, :new, [args, opts])
  end

  @doc """
  Fetches a required arg or raises `KeyError`. Call from inside `perform/1`
  before reconstructing scope. Belt + suspenders beyond `new/3` validation
  (D-20): hand-built jobs bypass `new/3` but still hit this at run time.
  """
  @spec fetch_arg!(map(), String.t()) :: term()
  def fetch_arg!(args, key) when is_map(args) and is_binary(key) do
    Map.fetch!(args, key)
  end
end
