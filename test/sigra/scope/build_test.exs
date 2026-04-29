defmodule Sigra.Scope.BuildTest do
  @moduledoc """
  Wave 0 tests for `Sigra.Scope.build/3`, the library-side scope
  constructor used by login-time synthesis and worker reference
  implementations.

  Created as `@tag :skip` stubs by Plan 15-01 Task 0 and un-skipped by
  Plan 15-01 Task 1.

  Phase 92 / B2B-02 (Plan 92-03 Task 1) extended the constructor with
  additive `:role` and `:actor_type` fields. `:role` carries the active
  membership's host-defined role atom (populated only at the shared
  org-enrichment seams in `Sigra.Scope.Hydration` and
  `Sigra.Plug.PutActiveOrganization`). `:actor_type` is reserved Phase 93
  prep — nil-only under Phase 92 with no library-side branching.

  The reflected scope builder MUST NOT turn worker/audit scopes into
  authoritative authorization state — these are transport fields, not
  request-time authz decisions.
  """
  use ExUnit.Case, async: true

  defmodule Scope do
    @moduledoc false
    # Mirrors the generated scope struct AFTER Plan 92-02: includes the
    # additive `:role` and `:actor_type` RBAC seam fields.
    defstruct [:user, :active_organization, :membership, :impersonating_from, :role, :actor_type]
  end

  test "Sigra.Scope.build/3 with minimal opts returns struct with user set and others nil" do
    user = %{id: Ecto.UUID.generate()}
    scope = Sigra.Scope.build(Scope, user)

    assert %Scope{} = scope
    assert scope.user == user
    assert is_nil(scope.active_organization)
    assert is_nil(scope.membership)
    assert is_nil(scope.impersonating_from)
    # Phase 92: role and actor_type default to nil when not supplied.
    assert is_nil(scope.role)
    assert is_nil(scope.actor_type)
  end

  test "Sigra.Scope.build/3 propagates :active_organization and :membership from opts" do
    user = %{id: Ecto.UUID.generate()}
    org = %{id: Ecto.UUID.generate()}
    membership = %{id: Ecto.UUID.generate(), role: "admin"}

    scope = Sigra.Scope.build(Scope, user, active_organization: org, membership: membership)

    assert scope.user == user
    assert scope.active_organization == org
    assert scope.membership == membership
  end

  test "Sigra.Scope.build/3 propagates :impersonating_from additively for impersonation-aware callers" do
    user = %{id: Ecto.UUID.generate()}
    admin = %{id: Ecto.UUID.generate()}

    scope =
      Sigra.Scope.build(Scope, user,
        active_organization: %{id: Ecto.UUID.generate()},
        impersonating_from: admin
      )

    assert scope.impersonating_from == admin
  end

  describe "Phase 92 / B2B-02 — :role and :actor_type carry-through" do
    test "Sigra.Scope.build/3 carries :role from opts when supplied" do
      user = %{id: Ecto.UUID.generate()}
      scope = Sigra.Scope.build(Scope, user, role: :tenant_lead)

      assert scope.role == :tenant_lead
      assert is_nil(scope.actor_type)
    end

    test "Sigra.Scope.build/3 carries :actor_type from opts when supplied (Phase 93 prep, Phase 92 inert)" do
      # Reservation-only: Phase 92 must accept the field WITHOUT branching on it.
      # Phase 93 will populate it for service accounts; this test proves the
      # field round-trips today so Phase 93 stays additive.
      user = %{id: Ecto.UUID.generate()}
      scope = Sigra.Scope.build(Scope, user, actor_type: :service_account)

      assert scope.actor_type == :service_account
      assert is_nil(scope.role)
    end

    test "Sigra.Scope.build/3 defaults :role and :actor_type to nil when omitted from opts" do
      user = %{id: Ecto.UUID.generate()}

      # Even when other fields are supplied, omitted role/actor_type must default to nil.
      scope =
        Sigra.Scope.build(Scope, user,
          active_organization: %{id: Ecto.UUID.generate()},
          membership: %{id: Ecto.UUID.generate(), role: :ignored_for_build}
        )

      assert is_nil(scope.role)
      assert is_nil(scope.actor_type)
    end

    test "Sigra.Scope.build/3 carries :role and :actor_type together additively" do
      user = %{id: Ecto.UUID.generate()}

      scope = Sigra.Scope.build(Scope, user, role: :site_admin, actor_type: :user)

      assert scope.role == :site_admin
      assert scope.actor_type == :user
    end

    test "Sigra.Scope.from_opts/2 carries :role and :actor_type when supplied" do
      user = %{id: Ecto.UUID.generate()}

      scope =
        Sigra.Scope.from_opts(
          [scope_module: Scope, role: :tenant_lead, actor_type: :user],
          user
        )

      assert scope.user == user
      assert scope.role == :tenant_lead
      assert scope.actor_type == :user
      # active_organization is intentionally always nil at integration sites
      # that fire BEFORE org selection (Phase 15 D-26..D-28).
      assert is_nil(scope.active_organization)
    end

    test "Sigra.Scope.from_opts/2 defaults :role and :actor_type to nil when omitted" do
      user = %{id: Ecto.UUID.generate()}

      scope = Sigra.Scope.from_opts([scope_module: Scope], user)

      assert scope.user == user
      assert is_nil(scope.role)
      assert is_nil(scope.actor_type)
    end

    test "Sigra.Scope.from_config/2 carries :role and :actor_type when supplied on the config" do
      user = %{id: Ecto.UUID.generate()}

      config = %{scope_module: Scope, role: :tenant_lead, actor_type: :user}

      scope = Sigra.Scope.from_config(config, user)

      assert scope.user == user
      assert scope.role == :tenant_lead
      assert scope.actor_type == :user
      assert is_nil(scope.active_organization)
    end

    test "Sigra.Scope.from_config/2 defaults :role and :actor_type to nil when absent from the config" do
      user = %{id: Ecto.UUID.generate()}

      config = %{scope_module: Scope}

      scope = Sigra.Scope.from_config(config, user)

      assert scope.user == user
      assert is_nil(scope.role)
      assert is_nil(scope.actor_type)
    end
  end
end
