defmodule Sigra.EnterpriseRouting.DiscoveryTest do
  use ExUnit.Case, async: true

  defmodule TestOrganization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "organizations" do
      field :name, :string
      field :slug, :string
    end
  end

  defmodule TestConnection do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "enterprise_connections" do
      field :organization_id, :binary_id
      field :status, Ecto.Enum, values: [:draft, :validation_failed, :active, :disabled]
      field :display_name, :string
      field :login_hint_domains, {:array, :string}, default: []
    end
  end

  defmodule DiscoveryRepo do
    alias Sigra.EnterpriseRouting.DiscoveryTest.{TestConnection, TestOrganization}

    @organizations %{
      "org-acme" => %TestOrganization{id: "org-acme", name: "Acme", slug: "acme"},
      "org-beta" => %TestOrganization{id: "org-beta", name: "Beta", slug: "beta"},
      "org-gamma" => %TestOrganization{id: "org-gamma", name: "Gamma", slug: "gamma"}
    }

    @connections [
      %TestConnection{
        id: "conn-acme",
        organization_id: "org-acme",
        status: :active,
        display_name: "Acme Workforce",
        login_hint_domains: ["acme.example"]
      },
      %TestConnection{
        id: "conn-shared-beta",
        organization_id: "org-beta",
        status: :active,
        display_name: "Beta Shared",
        login_hint_domains: ["shared.example"]
      },
      %TestConnection{
        id: "conn-shared-gamma",
        organization_id: "org-gamma",
        status: :active,
        display_name: "Gamma Shared",
        login_hint_domains: ["shared.example"]
      },
      %TestConnection{
        id: "conn-disabled",
        organization_id: "org-beta",
        status: :disabled,
        display_name: "Disabled Exact",
        login_hint_domains: ["disabled.example"]
      },
      %TestConnection{
        id: "conn-validation-failed",
        organization_id: "org-beta",
        status: :validation_failed,
        display_name: "Validation Failed Exact",
        login_hint_domains: ["failed.example"]
      },
      %TestConnection{
        id: "conn-wildcard",
        organization_id: "org-beta",
        status: :active,
        display_name: "Wildcard",
        login_hint_domains: ["*.wild.example"]
      },
      %TestConnection{
        id: "conn-suffix",
        organization_id: "org-beta",
        status: :active,
        display_name: "Suffix",
        login_hint_domains: ["suffix.example"]
      }
    ]

    def all(%Ecto.Query{wheres: wheres}) do
      Enum.filter(@connections, fn connection ->
        Enum.all?(wheres, fn where -> matches_expr?(where.expr, where.params, connection) end)
      end)
    end

    def get(TestOrganization, id), do: Map.get(@organizations, id)

    def get_by(TestOrganization, slug: slug) do
      Enum.find(Map.values(@organizations), &(&1.slug == slug))
    end

    defp matches_expr?({:in, _, [left, right]}, params, connection) do
      value_for(left, params, connection) in value_for(right, params, connection)
    end

    defp matches_expr?({:==, _, [left, right]}, params, connection) do
      value_for(left, params, connection) == value_for(right, params, connection)
    end

    defp matches_expr?({:and, _, [left, right]}, params, connection) do
      matches_expr?(left, params, connection) and matches_expr?(right, params, connection)
    end

    defp value_for({{:., _, [{:&, _, [0]}, field]}, _, []}, _params, connection) do
      Map.fetch!(connection, field)
    end

    defp value_for({:^, _, [index]}, params, _connection) do
      params |> Enum.at(index) |> elem(0)
    end

    defp value_for(values, _params, _connection) when is_list(values) do
      Enum.map(values, fn
        %Ecto.Query.Tagged{value: value} -> value
        value -> value
      end)
    end

    defp value_for(value, _params, _connection), do: value
  end

  @config %{
    repo: DiscoveryRepo,
    schemas: %{
      enterprise_connection: TestConnection,
      organization: TestOrganization
    }
  }

  test "discover_connection/2 auto-routes only one exact active match" do
    assert {:ok, result} =
             Sigra.EnterpriseRouting.discover_connection(@config, "  Person@Acme.Example ")

    assert result.organization_id == "org-acme"
    assert result.organization_slug == "acme"
    assert result.organization_name == "Acme"
    assert result.connection_id == "conn-acme"
    assert result.routing_source == :domain_discovery
  end

  test "discover_connection/2 fails closed for duplicate shared domains" do
    assert {:error, :multiple_org_matches} =
             Sigra.EnterpriseRouting.discover_connection(@config, "person@shared.example")
  end

  test "discover_connection/2 treats inactive and validation-failed exact matches as unavailable" do
    assert {:error, :org_connection_unavailable} =
             Sigra.EnterpriseRouting.discover_connection(@config, "person@disabled.example")

    assert {:error, :org_connection_unavailable} =
             Sigra.EnterpriseRouting.discover_connection(@config, "person@failed.example")
  end

  test "discover_connection/2 rejects wildcard, suffix, and non-exact matches" do
    assert {:error, :no_org_match} =
             Sigra.EnterpriseRouting.discover_connection(@config, "person@foo.wild.example")

    assert {:error, :no_org_match} =
             Sigra.EnterpriseRouting.discover_connection(@config, "person@foo.suffix.example")

    assert {:error, :no_org_match} =
             Sigra.EnterpriseRouting.discover_connection(@config, "person@unknown.example")
  end

  test "get_routable_connection/2 resolves the canonical org entry" do
    assert {:ok, result} = Sigra.EnterpriseRouting.get_routable_connection(@config, %{slug: "acme"})
    assert result.organization_slug == "acme"
    assert result.connection_id == "conn-acme"
    assert result.routing_source == :explicit_org
  end
end
