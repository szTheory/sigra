defmodule Sigra.DataExport do
  @moduledoc """
  Behaviour for exporting user data.

  Sigra provides a default implementation that exports auth-related data
  (user profile, sessions, OAuth identities).
  Application developers implement this behaviour to add app-specific data.

  ## Usage

      defmodule MyApp.DataExport do
        @behaviour Sigra.DataExport

        @impl true
        def export_user_data(user) do
          {:ok, %{
            profile: %{name: user.name, bio: user.bio},
            posts: MyApp.Posts.list_by_user(user.id)
          }}
        end
      end
  """

  @doc """
  Export all data associated with the given user.

  Returns `{:ok, map()}` with the exported data or `{:error, reason}`.
  The map keys and structure are implementation-defined.
  """
  @doc since: "0.8.0"
  @callback export_user_data(user :: struct()) :: {:ok, map()} | {:error, term()}

  @doc """
  Exports Sigra's own auth data for a user.

  Returns a map with keys: `:user`, `:sessions`, `:identities`.
  This is always included in exports regardless of the app's implementation.

  ## Options

    * `:session_schema` - The generated UserSession Ecto schema module.
    * `:identity_schema` - The generated UserIdentity Ecto schema module.
  """
  @doc since: "0.8.0"
  @spec export_auth_data(module(), struct(), keyword()) :: {:ok, map()}
  def export_auth_data(repo, user, opts \\ []) do
    import Ecto.Query

    session_schema = Keyword.get(opts, :session_schema)
    identity_schema = Keyword.get(opts, :identity_schema)

    data = %{
      user: %{
        id: user.id,
        email: user.email,
        confirmed_at: Map.get(user, :confirmed_at),
        inserted_at: user.inserted_at
      },
      sessions:
        if(session_schema,
          do: repo.all(from(s in session_schema, where: s.user_id == ^user.id)),
          else: []
        ),
      identities:
        if(identity_schema,
          do: repo.all(from(i in identity_schema, where: i.user_id == ^user.id)),
          else: []
        )
    }

    {:ok, data}
  end
end
