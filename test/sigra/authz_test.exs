defmodule Sigra.AuthzTest do
  @moduledoc """
  Behaviour-contract regression coverage for `Sigra.Authz` (Phase 92 / B2B-02).

  These tests prove only the role-agnostic seam:

    * the behaviour exists
    * it exposes exactly one callback (`can?/3`)
    * the library ships no built-in role taxonomy, hierarchy, or
      default allow/deny helper that would re-opinionate the seam

  Default `can?/3` policy semantics live in host-owned generated code
  (Plan 92-02) and host recipe code, NOT in the library. If a future
  change adds a library-side allow-by-default helper here, that change
  must update Plan 92-02's contract and these tests together.
  """

  use ExUnit.Case, async: true

  describe "behaviour module" do
    test "Sigra.Authz module exists and is loadable" do
      assert Code.ensure_loaded?(Sigra.Authz)
    end

    test "exposes exactly one callback: can?/3" do
      callbacks = Sigra.Authz.behaviour_info(:callbacks)

      assert callbacks == [{:can?, 3}],
             "Sigra.Authz must expose only `can?/3` as a behaviour callback. " <>
               "Adding additional callbacks re-opinionates the seam and conflicts " <>
               "with the Phase 92 host-owned RBAC contract. Got: " <>
               inspect(callbacks)
    end

    test "exposes zero @optional_callbacks (the can?/3 callback is required)" do
      optional = Sigra.Authz.behaviour_info(:optional_callbacks)
      assert optional == []
    end
  end

  describe "role-agnostic seam (no built-in taxonomy)" do
    test "ships no built-in role atoms baked into the module body" do
      # Read the source bytes and assert the role taxonomy `:owner`,
      # `:admin`, `:member` are not literally present anywhere — not in
      # the moduledoc, not in attributes, not in fallback policy code.
      # If a future change introduces such constants here, this test
      # forces the author to update Plan 92-02 in the same change.
      source = File.read!(Path.join([__DIR__, "..", "..", "lib", "sigra", "authz.ex"]))

      refute source =~ ~r/:owner\b/,
             "Sigra.Authz must not ship the `:owner` role atom; the seam is role-agnostic."

      refute source =~ ~r/:admin\b/,
             "Sigra.Authz must not ship the `:admin` role atom; the seam is role-agnostic."

      refute source =~ ~r/:member\b/,
             "Sigra.Authz must not ship the `:member` role atom; the seam is role-agnostic."
    end

    test "exports no library-side `can?/3` default allow/deny implementation" do
      # The behaviour contract must not be backed by a same-module function
      # of the same name, which would let hosts call `Sigra.Authz.can?/3`
      # without supplying their own policy. That would re-opinionate the
      # seam.
      refute function_exported?(Sigra.Authz, :can?, 3),
             "Sigra.Authz must not export a `can?/3` function. The library " <>
               "ships only the behaviour; default semantics live in host code."
    end

    test "exports no library-side `allow?/3`, `deny?/3`, or `authorize/3` helpers" do
      for name <- [:allow?, :deny?, :authorize] do
        refute function_exported?(Sigra.Authz, name, 3),
               "Sigra.Authz must not export `#{name}/3`. Default policy helpers " <>
                 "would conflict with the host-owned authz contract from Plan 92-02."
      end
    end
  end

  describe "host implementation contract" do
    defmodule HostAuthz do
      @moduledoc false
      @behaviour Sigra.Authz

      @impl Sigra.Authz
      def can?(action, _subject, _scope) do
        # Trivial host policy used purely to prove the contract: hosts
        # may key the decision off `action` (or any other input) without
        # a library-side hierarchy dictating the answer.
        action == :read
      end
    end

    test "a host module can implement the behaviour and answer arbitrary actions" do
      assert HostAuthz.can?(:read, %{user_id: 1}, %{role: :viewer})
      refute HostAuthz.can?(:write, %{user_id: 1}, %{role: :viewer})
    end

    test "library does not interpret the host's return value beyond boolean" do
      # The host above returns booleans for two actions and the test passes
      # without any library-side wrapping or hierarchy. This is the
      # role-agnostic seam contract.
      assert is_boolean(HostAuthz.can?(:read, nil, nil))
      assert is_boolean(HostAuthz.can?(:anything_else, nil, nil))
    end
  end
end
