defmodule Sigra.EnterpriseConnections do
  @moduledoc """
  Organization-scoped enterprise connection lifecycle management.

  This module owns the persisted truth for enterprise SSO setup. Host apps
  provide the schemas and repo; Sigra owns the lifecycle and validation rules.
  """

  alias Sigra.EnterpriseConnections.Validation

  @type config :: %{
          required(:repo) => module(),
          required(:schemas) => %{required(:enterprise_connection) => module()},
          optional(:http_client) => function()
        }

  @spec get_connection(config(), map()) :: struct() | nil
  def get_connection(config, scope) do
    with {:ok, org_id} <- active_organization_id(scope) do
      config.repo.get_by(connection_schema(config), organization_id: org_id)
    else
      _ -> nil
    end
  end

  @spec change_connection(config(), map(), map()) :: Ecto.Changeset.t()
  def change_connection(config, scope, attrs \\ %{}) do
    connection = get_connection(config, scope) || struct(connection_schema(config))
    attrs = attrs |> normalize_attrs() |> Map.put("organization_id", active_organization_id!(scope))
    connection_schema(config).changeset(connection, attrs)
  end

  @spec save_connection(config(), map(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def save_connection(config, scope, attrs) do
    connection = get_connection(config, scope) || struct(connection_schema(config))

    connection
    |> connection_schema(config).changeset(draft_attrs(scope, attrs))
    |> persist(config)
  end

  @spec validate_connection(config(), map(), map()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()} | {:error, :validation_failed, struct()}
  def validate_connection(config, scope, attrs \\ %{}) do
    connection = get_connection(config, scope) || struct(connection_schema(config))
    changeset = connection_schema(config).changeset(connection, draft_attrs(scope, attrs))

    with true <- changeset.valid? || {:error, changeset},
         candidate <- Ecto.Changeset.apply_changes(changeset),
         {:ok, diagnostics} <- Validation.validate(config, candidate),
         {:ok, persisted} <- persist(Ecto.Changeset.change(changeset, validated_attrs(diagnostics)), config) do
      {:ok, persisted}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, :validation_failed, message} ->
        {:ok, persisted} =
          persist(
            Ecto.Changeset.change(
              changeset,
              validation_failed_attrs(message)
            ),
            config
          )

        {:error, :validation_failed, persisted}
    end
  end

  @spec activate_connection(config(), map(), map()) ::
          {:ok, struct()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :validation_failed}
          | {:error, :forbidden}
  def activate_connection(config, scope, attrs_or_connection \\ %{})

  def activate_connection(_config, scope, %{organization_id: organization_id} = connection) do
    if organization_id == active_organization_id!(scope) do
      {:ok, connection}
    else
      {:error, :forbidden}
    end
  end

  def activate_connection(config, scope, attrs) do
    case validate_connection(config, scope, attrs) do
      {:ok, connection} ->
        connection
        |> Ecto.Changeset.change(%{
          status: :active,
          last_validated_at: DateTime.utc_now() |> DateTime.truncate(:second),
          last_validation_error: nil
        })
        |> persist(config)

      {:error, :validation_failed, _connection} ->
        {:error, :validation_failed}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @spec disable_connection(config(), map(), map()) ::
          {:ok, struct()} | {:error, :not_found} | {:error, :forbidden}
  def disable_connection(config, scope, connection \\ nil)

  def disable_connection(config, scope, nil) do
    case get_connection(config, scope) do
      nil ->
        {:error, :not_found}

      connection ->
        disable_connection(config, scope, connection)
    end
  end

  def disable_connection(config, scope, %{organization_id: organization_id} = connection) do
    if not is_nil(organization_id) and organization_id != active_organization_id!(scope) do
      {:error, :forbidden}
    else
      connection
      |> Ecto.Changeset.change(%{status: :disabled, last_validation_error: nil})
      |> persist(config)
    end
  end

  defp connection_schema(config), do: config.schemas.enterprise_connection

  defp persist(changeset, config) do
    case Map.get(changeset.data, :id) do
      nil -> config.repo.insert(changeset)
      _id -> config.repo.update(changeset)
    end
  end

  defp draft_attrs(scope, attrs) do
    attrs
    |> normalize_attrs()
    |> Map.put("organization_id", active_organization_id!(scope))
    |> Map.put("status", :draft)
    |> Map.put("last_validation_error", nil)
  end

  defp validated_attrs(diagnostics) do
    %{
      status: :draft,
      last_validated_at: diagnostics.validated_at,
      last_validation_error: nil
    }
  end

  defp validation_failed_attrs(message) do
    %{
      status: :validation_failed,
      last_validation_error: message
    }
  end

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(_attrs), do: %{}

  defp active_organization_id(%{active_organization: %{id: id}}) when not is_nil(id), do: {:ok, id}
  defp active_organization_id(_scope), do: {:error, :missing_organization}

  defp active_organization_id!(scope) do
    case active_organization_id(scope) do
      {:ok, id} -> id
      {:error, :missing_organization} -> raise ArgumentError, "enterprise connections require an active organization"
    end
  end
end
