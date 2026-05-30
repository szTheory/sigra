defmodule Example.SigraAdminPolicy do
  @moduledoc """
  Example-host admin policy used by the generated admin wiring.

  This module stays explicit on purpose. Phase 27's example app grants admin
  access only to fixture-backed users whose emails opt into the admin role
  shape used by the integration tests.
  """

  @behaviour Sigra.Admin.Policy

  import Ecto.Query, only: [from: 2]

  alias Example.Accounts.OrganizationMembership
  alias Example.Repo

  @platform_admin_prefix "platform-admin+"
  @org_admin_prefix "org-admin+"
  @demo_admin_email "admin@demo.sigra.dev"

  @impl true
  def platform_admin?(%{user: %{email: email}}) when is_binary(email) do
    String.starts_with?(email, @platform_admin_prefix) or email == @demo_admin_email
  end

  def platform_admin?(_scope), do: false

  @impl true
  def admin_org_ids(%{user: %{id: user_id, email: email}})
      when is_binary(email) and is_binary(user_id) do
    if String.starts_with?(email, @org_admin_prefix) do
      user_id
      |> admin_memberships()
      |> Sigra.Admin.Policy.admin_org_ids_from_memberships()
    else
      []
    end
  end

  def admin_org_ids(_scope), do: []

  defp admin_memberships(user_id) do
    from(membership in OrganizationMembership,
      where: membership.user_id == ^user_id,
      select: %{organization_id: membership.organization_id, role: membership.role}
    )
    |> Repo.all()
  end
end
