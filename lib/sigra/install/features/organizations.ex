defmodule Sigra.Install.Features.Organizations do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the organizations feature:
  multi-tenant organization support with memberships and invitations.

  Owns every template under `priv/templates/sigra.install/organizations/`
  and the single migration that creates the `organizations`,
  `organization_memberships`, and `organization_invitations` tables.

  `enabled?/1` checks `Keyword.get(opts, :organizations, true)` — the
  organizations feature is enabled by default (ORG-01). Pass
  `--no-organizations` to the installer to disable.

  ## Phase 18 completion

  In Phase 13 this module returns empty lists from `files/1`,
  `injections/1`, and `post_instructions/2`. Phase 18 fills these in
  when the generator wiring is implemented.

  ## Isolation invariant (Pitfall X-3)

  This module contains ZERO references to `Features.Core`,
  `Features.Passkeys`, or `Features.Admin`. That boundary is what makes
  `mix sigra.install --no-organizations` produce a compiling app even
  with no Organizations code present.
  """

  @behaviour Sigra.Install.Feature

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :organizations, true)

  @impl true
  def files(_binding), do: []

  @impl true
  def injections(_binding), do: []

  @impl true
  def migrations(_binding) do
    [{:organizations, "organizations/migration.exs", "create_organizations.exs"}]
  end

  @impl true
  def post_instructions(_binding, _report), do: []
end
