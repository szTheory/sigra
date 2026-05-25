defmodule Sigra.OAuth.EnterpriseCallbackTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.Error.OAuthError
  alias Sigra.OAuth

  @secret_key_base String.duplicate("c", 64)

  defmodule MockStrategy do
    def authorize_url(_config) do
      {:ok,
       %{
         url: "https://provider.example.com/auth?state=original&scope=email",
         session_params: %{code_verifier: "pkce_verifier"}
       }}
    end

    def callback(_config, _params) do
      {:ok,
       %{
         user: %{
           "sub" => "provider_uid_123",
           "email" => "oauth@example.com",
           "name" => "OAuth User",
           "picture" => nil,
           "email_verified" => true
         },
         token: %{"access_token" => "tok", "refresh_token" => "ref", "expires_in" => 3600}
       }}
    end
  end

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

  defmodule EnterpriseCallbackRepo do
    alias Sigra.OAuth.EnterpriseCallbackTest.{TestConnection, TestOrganization}

    @organization %TestOrganization{id: "org-acme", slug: "acme", name: "Acme"}

    @active_connection %TestConnection{
      id: "conn-acme",
      organization_id: "org-acme",
      status: :active,
      display_name: "Acme Workforce",
      login_hint_domains: ["acme.example"]
    }

    def get(TestOrganization, "org-acme"), do: @organization
    def get(_schema, _id), do: nil

    def get_by(TestOrganization, slug: "acme"), do: @organization
    def get_by(TestOrganization, _clauses), do: nil

    def get_by(Sigra.Test.MockIdentity, clauses) do
      if clauses[:provider_uid] == "provider_uid_123" do
        %Sigra.Test.MockIdentity{
          id: 1,
          user_id: 42,
          provider: clauses[:provider] || "mock",
          provider_uid: "provider_uid_123"
        }
      end
    end

    def get_by(Sigra.Test.MockUser, _clauses), do: nil

    def get!(Sigra.Test.MockUser, 42) do
      %{id: 42, email: "oauth@example.com", hashed_password: nil, confirmed_at: ~U[2026-01-01 00:00:00Z]}
    end

    def all(%Ecto.Query{wheres: wheres}) do
      Enum.filter([@active_connection], fn connection ->
        Enum.all?(wheres, fn where -> matches_expr?(where.expr, where.params, connection) end)
      end)
    end

    def update(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
    def transaction(%Ecto.Multi{} = multi), do: Sigra.Test.MultiStub.run(__MODULE__, multi)
    def insert(%Ecto.Changeset{} = changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
    def insert(struct) when is_map(struct), do: {:ok, Map.put(struct, :id, 1)}

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

  defmodule UnavailableEnterpriseRepo do
    def get(_schema, _id), do: nil
    def get_by(_schema, _clauses), do: nil
    def all(_query), do: []
  end

  defp build_config(overrides \\ []) do
    providers =
      Keyword.get(overrides, :providers,
        mock: [client_id: "test_id", client_secret: "test_secret", strategy: MockStrategy]
      )

    %{
      repo: Keyword.get(overrides, :repo, EnterpriseCallbackRepo),
      user_schema: Sigra.Test.MockUser,
      secret_key_base: @secret_key_base,
      oauth: [
        enabled: true,
        providers: providers,
        session_type: :remember_me,
        link_confirmation: :required,
        trust_provider_email: true
      ],
      session: [
        session_schema: Sigra.Test.MockSession,
        store: Sigra.Test.MockSessionStore
      ],
      identity_schema: Sigra.Test.MockIdentity,
      schemas: %{
        enterprise_connection: TestConnection,
        organization: TestOrganization
      }
    }
  end

  test "handle_callback/4 rejects mismatched enterprise_context" do
    config = build_config()

    enterprise = %{
      organization_id: "org-acme",
      connection_id: "conn-acme",
      routing_source: :domain_discovery
    }

    assert {:ok, url, session_params} = OAuth.authorize_url(config, :mock, enterprise: enterprise)
    state = URI.parse(url).query |> URI.decode_query() |> Map.fetch!("state")
    params = %{"state" => state, "code" => "auth-code"}

    mismatched_session =
      Map.put(session_params, :enterprise_context, %{enterprise | connection_id: "conn-other"})

    assert {:error, %OAuthError{error_code: :enterprise_context_mismatch}} =
             OAuth.handle_callback(config, :mock, params, mismatched_session)
  end

  test "handle_callback/4 returns enterprise session metadata on success" do
    config = build_config()

    enterprise = %{
      organization_id: "org-acme",
      connection_id: "conn-acme",
      routing_source: :explicit_org
    }

    assert {:ok, url, session_params} = OAuth.authorize_url(config, :mock, enterprise: enterprise)
    state = URI.parse(url).query |> URI.decode_query() |> Map.fetch!("state")
    params = %{"state" => state, "code" => "auth-code"}

    assert {:ok, :logged_in, _user, session_metadata} =
             OAuth.handle_callback(config, :mock, params, session_params)

    assert session_metadata.active_organization_id == "org-acme"
    assert session_metadata.enterprise_connection_id == "conn-acme"
    assert session_metadata.enterprise_routing_source == :explicit_org
  end

  test "process_callback/5 rejects unavailable enterprise connection context" do
    config = build_config(repo: UnavailableEnterpriseRepo)

    context = %{
      state: %{
        organization_id: "org-acme",
        connection_id: "conn-acme",
        routing_source: :domain_discovery
      },
      session: %{
        organization_id: "org-acme",
        connection_id: "conn-acme",
        routing_source: :domain_discovery
      }
    }

    assert {:error, %OAuthError{error_code: :org_connection_unavailable}} =
             OAuth.Callback.process_callback(
               config,
               :mock,
               mock_user_info(),
               mock_token(),
               enterprise_context: context
             )
  end
end
