defmodule SigraInstallGoldenTmp.SigraAuthz do
  @moduledoc """
  Host-owned authorization module for Sigra's Phase 92 RBAC seam.

  This file is YOUR code — Sigra ships only the `Sigra.Authz` behaviour
  contract. The library does not provide a default `can?/3` implementation,
  a permission engine, or built-in role atoms; the host owns every policy
  decision.

  ## What this starter does

  Out of the box, `can?/3` returns `true` for every input. That keeps
  installed apps behaving identically to today's no-defaults world while
  the seam is in place. As soon as you have host-defined actions, follow
  the Plan 92-04 deny-by-default recipe to:

    1. Replace the catch-all clause with explicit allow rules per
       `(action, subject, scope)`.
    2. End the function with a `def can?(_action, _subject, _scope), do: false`
       fall-through so unknown actions deny by default.
    3. Add tests that exercise both the allow paths and the deny
       fall-through.

  ## Reading the scope

  Phase 92 generated wiring populates `scope.role` with the active
  membership's host-defined role atom. Branch on it to gate
  privilege-sensitive actions. `scope.actor_type` is reserved for
  Phase 93 (M2M tokens / service accounts) and stays `nil` until then —
  do NOT branch on it from this module under Phase 92.

  ## Example (after running the Plan 92-04 recipe)

      @impl Sigra.Authz
      def can?(:read, _subject, _scope), do: true
      def can?({:manage, :billing}, _subject, %{role: :tenant_lead}), do: true
      def can?(_action, _subject, _scope), do: false

  See `Sigra.Authz` for the full callback contract.
  """

  @behaviour Sigra.Authz

  @impl Sigra.Authz
  def can?(action, subject, scope) do
    # TODO (Plan 92-04): replace this allow-all starter with explicit
    # per-action rules and a deny-by-default fall-through.
    _ = action
    _ = subject
    _ = scope
    true
  end
end
