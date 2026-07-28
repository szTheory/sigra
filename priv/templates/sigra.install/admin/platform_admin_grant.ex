<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= context_module %>.PlatformAdminGrant do
  @moduledoc """
  Host-owned persisted platform-admin grant.

  A grant is active while `revoked_at` is nil. Keep authorization decisions
  explicit: signup order, email domain, and account creation never create one.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type <%= if binary_id, do: ":binary_id", else: ":id" %>
<%= if auth_prefix do %>  @schema_prefix "<%= auth_prefix %>"
<% end %>

  schema "sigra_platform_admin_grants" do
    belongs_to :user, <%= context_module %>.<%= schema_alias %>
    field :revoked_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:user_id, :revoked_at])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
