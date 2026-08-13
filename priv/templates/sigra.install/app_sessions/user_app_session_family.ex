<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= context_module %>.UserAppSessionFamily do
  @moduledoc "Host-owned persistence for one opaque first-party app-session family."

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

<%= if auth_prefix do %>  @schema_prefix "<%= auth_prefix %>"
<% end %>
  schema "user_app_session_families" do
    field :client_ref, :string
    field :absolute_expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)

    belongs_to :user, <%= context_module %>.<%= schema_alias %>
  end
end
