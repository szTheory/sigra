defmodule Sigra.DataExport do
  @moduledoc """
  Behaviour for exporting user data.

  Sigra provides a versioned export contract for Sigra-owned auth and
  account data. Application developers implement this behaviour to add
  host-app data alongside the Sigra-owned export.

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

  Returns a versioned map describing Sigra-owned auth/account surfaces for
  the user. The payload is intentionally explicit and stable so host apps can
  present or archive it without reverse-engineering Sigra internals.

  ## Options

    * `:session_schema` - The generated UserSession Ecto schema module.
    * `:identity_schema` - The generated UserIdentity Ecto schema module.
    * `:audit_schema` - The generated AuditEvent schema module.
    * `:mfa_credential_schema` - The generated MFA credential schema module.
    * `:backup_code_schema` - The generated backup code schema module.
    * `:user_passkey_schema` - The generated passkey schema module.
    * `:membership_schema` - The generated organization membership schema module.
  """
  @doc since: "0.8.0"
  @spec export_auth_data(module(), struct(), keyword()) :: {:ok, map()}
  def export_auth_data(repo, user, opts \\ []) do
    import Ecto.Query

    data = %{
      schema_version: 1,
      exported_at: DateTime.utc_now() |> DateTime.truncate(:second),
      account: %{
        id: user.id,
        email: user.email,
        confirmed_at: Map.get(user, :confirmed_at),
        inserted_at: user.inserted_at,
        deleted_at: Map.get(user, :deleted_at),
        scheduled_deletion_at: Map.get(user, :scheduled_deletion_at)
      },
      sessions: fetch_records(repo, Keyword.get(opts, :session_schema), user.id),
      identities: fetch_records(repo, Keyword.get(opts, :identity_schema), user.id),
      audit: fetch_audit_records(repo, Keyword.get(opts, :audit_schema), user.id),
      mfa: %{
        credentials: fetch_records(repo, Keyword.get(opts, :mfa_credential_schema), user.id),
        passkeys: fetch_records(repo, Keyword.get(opts, :user_passkey_schema), user.id),
        backup_codes: %{
          count: count_records(repo, Keyword.get(opts, :backup_code_schema), user.id),
          exported: false,
          reason: "Backup codes are stored hashed and cannot be exported in raw form."
        }
      },
      organizations: %{
        memberships: fetch_records(repo, Keyword.get(opts, :membership_schema), user.id)
      },
      enterprise: %{
        connections: [],
        exported: false,
        reason:
          "Enterprise connections are organization-scoped and are not included in the user export contract."
      },
      omissions: omissions(opts)
    }

    {:ok, data}
  end

  defp fetch_records(nil, _schema, _user_id), do: []
  defp fetch_records(_repo, nil, _user_id), do: []

  defp fetch_records(repo, schema, user_id) do
    import Ecto.Query

    if function_exported?(schema, :__schema__, 1) and :user_id in schema.__schema__(:fields) do
      repo.all(from(r in schema, where: field(r, ^:user_id) == ^user_id))
    else
      []
    end
  end

  defp count_records(nil, _schema, _user_id), do: 0
  defp count_records(_repo, nil, _user_id), do: 0

  defp count_records(repo, schema, user_id) do
    import Ecto.Query

    if function_exported?(schema, :__schema__, 1) and :user_id in schema.__schema__(:fields) do
      repo.aggregate(from(r in schema, where: field(r, ^:user_id) == ^user_id), :count, :id)
    else
      0
    end
  end

  defp fetch_audit_records(nil, _schema, _user_id), do: []
  defp fetch_audit_records(_repo, nil, _user_id), do: []

  defp fetch_audit_records(repo, schema, user_id) do
    import Ecto.Query

    fields = schema.__schema__(:fields)

    predicates =
      [:actor_id, :effective_user_id, :target_id]
      |> Enum.filter(&(&1 in fields))

    if predicates == [] do
      []
    else
      predicate =
        Enum.reduce(predicates, dynamic(false), fn field_name, acc ->
          dynamic([record], ^acc or field(record, ^field_name) == ^user_id)
        end)

      query =
        from(record in schema, where: ^predicate)
        |> maybe_order_audit_records(fields)

      repo.all(query)
    end
  end

  defp maybe_order_audit_records(query, fields) do
    import Ecto.Query

    cond do
      :occurred_at in fields ->
        from(record in query, order_by: [asc: field(record, ^:occurred_at)])

      :inserted_at in fields ->
        from(record in query, order_by: [asc: field(record, ^:inserted_at)])

      true ->
        query
    end
  end

  defp omissions(opts) do
    []
    |> maybe_add_omission(
      is_nil(Keyword.get(opts, :audit_schema)),
      "Audit events are omitted because no audit schema was provided."
    )
    |> maybe_add_omission(
      is_nil(Keyword.get(opts, :membership_schema)),
      "Organization memberships are omitted because no membership schema was provided."
    )
    |> maybe_add_omission(
      is_nil(Keyword.get(opts, :mfa_credential_schema)),
      "MFA credential rows are omitted because no MFA credential schema was provided."
    )
  end

  defp maybe_add_omission(omissions, true, message), do: [message | omissions]
  defp maybe_add_omission(omissions, false, _message), do: omissions
end
