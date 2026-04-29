defmodule Sigra.LiveView.RequireOrgMfaTest do
  use ExUnit.Case, async: true

  alias Sigra.LiveView.RequireOrgMfa

  defmodule TestUser do
    defstruct [:id]
  end

  defmodule TestOrg do
    defstruct [:slug, :enforce_mfa_for_members]
  end

  defmodule TestScope do
    defstruct [:user, :active_organization]
  end

  defp fake_socket(assigns), do: %{assigns: assigns}

  defp scope(attrs \\ %{}) do
    Map.merge(
      %TestScope{
        user: %TestUser{id: "u1"},
        active_organization: %TestOrg{slug: "acme", enforce_mfa_for_members: false}
      },
      attrs
    )
  end

  test "nil scope passes through" do
    socket = fake_socket(%{current_scope: nil})

    assert {:cont, _socket} =
             RequireOrgMfa.on_mount([mfa_check_fn: fn _ -> false end], %{}, %{}, socket)
  end

  test "policy disabled passes through" do
    socket = fake_socket(%{current_scope: scope()})

    assert {:cont, _socket} =
             RequireOrgMfa.on_mount([mfa_check_fn: fn _ -> false end], %{}, %{}, socket)
  end

  test "enrolled user passes through" do
    org = %TestOrg{slug: "acme", enforce_mfa_for_members: true}
    socket = fake_socket(%{current_scope: scope(%{active_organization: org})})

    assert {:cont, _socket} =
             RequireOrgMfa.on_mount([mfa_check_fn: fn _ -> true end], %{}, %{}, socket)
  end

  test "unenrolled user halts with redirect assign" do
    org = %TestOrg{slug: "acme", enforce_mfa_for_members: true}
    socket = fake_socket(%{current_scope: scope(%{active_organization: org})})

    assert {:halt, halted} =
             RequireOrgMfa.on_mount([mfa_check_fn: fn _ -> false end], %{}, %{}, socket)

    assert halted.assigns[:sigra_redirect_to] == "/users/settings/mfa"
  end

  test "missing :mfa_check_fn raises" do
    socket = fake_socket(%{current_scope: scope()})

    assert_raise KeyError, fn ->
      RequireOrgMfa.on_mount([], %{}, %{}, socket)
    end
  end
end
