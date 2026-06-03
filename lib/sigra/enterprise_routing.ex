defmodule Sigra.EnterpriseRouting do
  @moduledoc """
  Library-owned enterprise routing rules for bounded discovery and canonical
  organization entry.
  """

  import Ecto.Query

  alias Sigra.Auth

  @type config :: %{
          required(:repo) => module(),
          required(:schemas) => %{
            required(:enterprise_connection) => module(),
            optional(:organization) => module()
          }
        }

  @spec discover_connection(config(), String.t() | nil) ::
          {:ok,
           %{
             organization_id: term(),
             organization_slug: String.t(),
             organization_name: String.t() | nil,
             connection_id: term(),
             routing_source: :domain_discovery
           }}
          | {:error, :no_org_match | :multiple_org_matches | :org_connection_unavailable}
  def discover_connection(config, email) do
    case extract_email_domain(email) do
      nil ->
        {:error, :no_org_match}

      domain ->
        config
        |> list_exact_domain_matches(domain)
        |> resolve_discovery_match(config)
    end
  end

  @spec get_routable_connection(config(), map() | String.t()) ::
          {:ok,
           %{
             organization: struct() | nil,
             organization_id: term(),
             organization_slug: String.t() | nil,
             organization_name: String.t() | nil,
             connection: struct(),
             connection_id: term(),
             routing_source: :explicit_org
           }}
          | {:error, :org_connection_unavailable | :multiple_org_matches}
  def get_routable_connection(config, organization) do
    with {:ok, organization_id, organization_record} <- resolve_organization(config, organization),
         matches <- active_connections_for_org(config, organization_id) do
      case matches do
        [connection] ->
          {:ok,
           %{
             organization: organization_record,
             organization_id: organization_id,
             organization_slug: organization_record && Map.get(organization_record, :slug),
             organization_name: organization_record && Map.get(organization_record, :name),
             connection: connection,
             connection_id: connection.id,
             routing_source: :explicit_org
           }}

        [] ->
          {:error, :org_connection_unavailable}

        _ ->
          {:error, :multiple_org_matches}
      end
    end
  end

  defp resolve_discovery_match([], _config), do: {:error, :no_org_match}

  defp resolve_discovery_match(matches, config) do
    case matches do
      [%{status: :active, organization_id: organization_id} = connection] ->
        with {:ok, organization} <- fetch_organization(config, organization_id),
             slug when is_binary(slug) <- Map.get(organization, :slug) do
          {:ok,
           %{
             organization_id: organization_id,
             organization_slug: slug,
             organization_name: Map.get(organization, :name),
             connection_id: connection.id,
             routing_source: :domain_discovery
           }}
        else
          _ -> {:error, :org_connection_unavailable}
        end

      [_connection] ->
        {:error, :org_connection_unavailable}

      _ ->
        {:error, :multiple_org_matches}
    end
  end

  defp list_exact_domain_matches(config, domain) do
    config
    |> connection_query([:active, :draft, :validation_failed, :disabled])
    |> config.repo.all()
    |> Enum.filter(&exact_login_hint_domain?(&1, domain))
  end

  defp active_connections_for_org(config, organization_id) do
    config
    |> connection_query([:active])
    |> where([connection], connection.organization_id == ^organization_id)
    |> config.repo.all()
  end

  defp connection_query(config, statuses) do
    connection_schema = config.schemas.enterprise_connection

    from(connection in connection_schema,
      where: connection.status in ^statuses
    )
  end

  defp resolve_organization(_config, %{id: id} = organization) when not is_nil(id),
    do: {:ok, id, organization}

  defp resolve_organization(config, %{slug: slug}) when is_binary(slug) do
    with {:ok, organization_schema} <- organization_schema(config),
         organization when not is_nil(organization) <- config.repo.get_by(organization_schema, slug: slug) do
      {:ok, organization.id, organization}
    else
      _ -> {:error, :org_connection_unavailable}
    end
  end

  defp resolve_organization(config, slug) when is_binary(slug) do
    resolve_organization(config, %{slug: slug})
  end

  defp resolve_organization(_config, _organization), do: {:error, :org_connection_unavailable}

  defp fetch_organization(config, organization_id) do
    with {:ok, organization_schema} <- organization_schema(config),
         organization when not is_nil(organization) <- config.repo.get(organization_schema, organization_id) do
      {:ok, organization}
    else
      _ -> {:error, :org_connection_unavailable}
    end
  end

  defp organization_schema(config) do
    case get_in(config, [:schemas, :organization]) do
      nil -> {:error, :org_connection_unavailable}
      schema -> {:ok, schema}
    end
  end

  defp exact_login_hint_domain?(connection, domain) do
    connection
    |> Map.get(:login_hint_domains, [])
    |> Enum.map(&normalize_login_hint_domain/1)
    |> Enum.any?(&(&1 == domain))
  end

  defp normalize_login_hint_domain(domain) when is_binary(domain) do
    domain
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_login_hint_domain(_domain), do: nil

  defp extract_email_domain(email) do
    case Auth.normalize_email(email) do
      normalized when is_binary(normalized) and normalized != "" ->
        if Auth.valid_email?(normalized) do
          normalized
          |> String.split("@", parts: 2)
          |> case do
            [_local, domain] when domain != "" -> domain
            _ -> nil
          end
        else
          nil
        end

      _ ->
        nil
    end
  end
end
