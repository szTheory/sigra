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

  alias Sigra.Account.Deletion

  @optional_sections [
    %{
      section: :sessions,
      schema_option: :session_schema
    },
    %{
      section: :identities,
      schema_option: :identity_schema
    },
    %{
      section: :audit,
      schema_option: :audit_schema
    },
    %{
      section: :mfa_credentials,
      schema_option: :mfa_credential_schema
    },
    %{
      section: :passkeys,
      schema_option: :user_passkey_schema
    },
    %{
      section: :backup_codes,
      schema_option: :backup_code_schema
    },
    %{
      section: :memberships,
      schema_option: :membership_schema
    }
  ]

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
    data = %{
      schema_version: 1,
      exported_at: DateTime.utc_now() |> DateTime.truncate(:second),
      account: %{
        id: user.id,
        email: user.email,
        confirmed_at: Map.get(user, :confirmed_at),
        inserted_at: user.inserted_at,
        deleted_at: Map.get(user, :deleted_at),
        scheduled_deletion_at: Map.get(user, :scheduled_deletion_at),
        lifecycle_status: lifecycle_status(user)
      },
      sessions:
        fetch_user_records(repo, Keyword.get(opts, :session_schema), user.id, [
          :id,
          :type,
          :ip,
          :user_agent,
          :last_active_at,
          :sudo_at,
          :active_organization_id,
          :inserted_at,
          :updated_at
        ]),
      identities:
        fetch_user_records(repo, Keyword.get(opts, :identity_schema), user.id, [
          :id,
          :provider,
          :provider_uid,
          :provider_email,
          :provider_name,
          :provider_avatar_url,
          :metadata,
          :last_used_at,
          :inserted_at,
          :updated_at
        ]),
      audit: fetch_audit_records(repo, Keyword.get(opts, :audit_schema), user.id),
      mfa: %{
        credentials:
          fetch_user_records(repo, Keyword.get(opts, :mfa_credential_schema), user.id, [
            :id,
            :type,
            :enabled_at,
            :last_used_at,
            :last_verified_step,
            :locked_until,
            :failed_attempts,
            :inserted_at,
            :updated_at
          ]),
        passkeys:
          fetch_user_records(repo, Keyword.get(opts, :user_passkey_schema), user.id, [
            :id,
            :nickname,
            :device_hint,
            :transports,
            :last_used_at,
            :sign_count,
            :rp_id,
            :aaguid,
            :inserted_at,
            :updated_at
          ]),
        backup_codes: %{
          count: count_records(repo, Keyword.get(opts, :backup_code_schema), user.id),
          exported: false,
          reason: "Backup codes are stored hashed and cannot be exported in raw form."
        }
      },
      organizations: %{
        memberships:
          fetch_user_records(repo, Keyword.get(opts, :membership_schema), user.id, [
            :id,
            :organization_id,
            :user_id,
            :role,
            :inserted_at,
            :updated_at
          ])
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

  defp fetch_user_records(nil, _schema, _user_id, _fields), do: []
  defp fetch_user_records(_repo, nil, _user_id, _fields), do: []

  defp fetch_user_records(repo, schema, user_id, fields) do
    import Ecto.Query

    if function_exported?(schema, :__schema__, 1) and :user_id in schema.__schema__(:fields) do
      fields = export_fields(schema, fields)

      schema
      |> where([record], field(record, ^:user_id) == ^user_id)
      |> select([record], map(record, ^fields))
      |> repo.all()
      |> normalize_records(fields)
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

    export_fields =
      export_fields(schema, [
        :id,
        :action,
        :outcome,
        :actor_id,
        :effective_user_id,
        :target_id,
        :target_type,
        :organization_id,
        :ip_address,
        :user_agent,
        :metadata,
        :occurred_at,
        :inserted_at
      ])

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
        |> select([record], map(record, ^export_fields))

      repo.all(query)
      |> normalize_records(export_fields)
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

  defp lifecycle_status(user) do
    user =
      user
      |> Map.put_new(:deleted_at, nil)
      |> Map.put_new(:scheduled_deletion_at, nil)

    case Deletion.status(user) do
      {:scheduled, days_remaining} ->
        %{state: :scheduled, days_remaining: days_remaining}

      :deleted ->
        %{state: :deleted}

      :not_scheduled ->
        %{state: :not_scheduled}
    end
  end

  defp export_fields(schema, fields) do
    schema_fields = schema.__schema__(:fields)
    Enum.filter(fields, &(&1 in schema_fields))
  end

  defp normalize_records(records, fields) do
    Enum.map(records, &normalize_record(&1, fields))
  end

  defp normalize_record(%{__struct__: _} = record, fields) do
    record
    |> Map.from_struct()
    |> Map.take(fields)
  end

  defp normalize_record(record, fields) when is_map(record) do
    Map.take(record, fields)
  end

  defp omissions(opts) do
    @optional_sections
    |> Enum.filter(fn %{schema_option: schema_option} ->
      is_nil(Keyword.get(opts, schema_option))
    end)
    |> Enum.map(fn %{section: section, schema_option: schema_option} ->
      %{
        section: section,
        schema_option: schema_option
      }
    end)
  end
end
