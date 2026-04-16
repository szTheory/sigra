defmodule Sigra.Scope do
  @moduledoc """
  Library-side scope helpers. The `%Scope{}` struct itself is generated
  into the host app — this module only provides constructors that work
  via `struct/2` reflection on the host's module.

  Used by:
  - Login-time scope synthesis in `Sigra.Auth` (D-27 in 15-CONTEXT.md)
  - Worker reference implementation `Sigra.Workers.AccountDeletion` (D-21, D-22)

  **Worker scopes are audit-only.** Host apps MUST NOT pass a worker-reconstructed
  scope to authorization functions — the minimal skeleton does not carry a real
  request context.
  """

  @spec build(scope_module :: module(), user :: struct() | map() | nil, opts :: keyword()) ::
          struct()
  def build(scope_module, user, opts \\ []) when is_atom(scope_module) and is_list(opts) do
    struct(scope_module,
      user: user,
      active_organization: Keyword.get(opts, :active_organization),
      membership: Keyword.get(opts, :membership),
      impersonating_from: nil
    )
  end

  @doc """
  Builds a minimal user-only scope from a keyword opts list that may carry
  `:scope_module`. Returns `nil` when `:scope_module` is absent or nil.

  Intended for library integration sites (Plan 15-02 semantic enrichment) that
  have a resolved user but no lexical `%Scope{}` — the call site can then pass
  `Sigra.Scope.from_opts(opts, user)` as the second positional arg to
  `Sigra.Audit.log_safe/3` without forcing every caller to thread a scope
  through. `active_organization` is always `nil`: these sites fire pre- or
  post-auth but BEFORE org selection (Phase 15 D-26..D-28).

  ## Examples

      iex> Sigra.Scope.from_opts([], %{id: "u"})
      nil

      iex> Sigra.Scope.from_opts([scope_module: nil], %{id: "u"})
      nil
  """
  @spec from_opts(keyword(), struct() | map() | nil) :: struct() | nil
  def from_opts(opts, user) when is_list(opts) do
    case Keyword.get(opts, :scope_module) do
      nil -> nil
      mod when is_atom(mod) -> build(mod, user, active_organization: nil)
    end
  end

  @doc """
  Builds a minimal user-only scope from a `Sigra.Config` struct or plain map.
  Returns `nil` when `config.scope_module` is unset or absent.

  Used by library sites that accept a `%Sigra.Config{}` (as opposed to a raw
  opts keyword list) — e.g. `Sigra.Auth` (authenticate_with_config/2),
  `Sigra.MFA`, `Sigra.OAuth`, `Sigra.APIToken`. Tolerates plain-map configs
  used in fast unit tests (OAuth test suite) via `Map.get/3`.
  """
  @spec from_config(struct() | map(), struct() | map() | nil) :: struct() | nil
  def from_config(config, user) when is_map(config) do
    case Map.get(config, :scope_module) do
      nil -> nil
      mod when is_atom(mod) -> build(mod, user, active_organization: nil)
    end
  end

  def from_config(_config, _user), do: nil
end
