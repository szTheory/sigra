defmodule Sigra.EnterpriseConnections.ActivationTest do
  use ExUnit.Case, async: true

  import Mox

  defmodule TestOrg do
    defstruct [:id]
  end

  defmodule TestScope do
    defstruct [:active_organization]
  end

  defmodule TestOIDCSettings do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :issuer, :string
      field :discovery_document_uri, :string
      field :client_id, :string
      field :encrypted_client_secret, :binary
      field :client_authentication_method, :string
      field :scopes, {:array, :string}
    end

    def changeset(settings, attrs) do
      settings
      |> cast(attrs, [
        :issuer,
        :discovery_document_uri,
        :client_id,
        :encrypted_client_secret,
        :client_authentication_method,
        :scopes
      ])
      |> validate_required([
        :issuer,
        :client_id,
        :encrypted_client_secret,
        :client_authentication_method
      ])
    end
  end

  defmodule TestConnection do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "enterprise_connections" do
      field :protocol, Ecto.Enum, values: [:oidc], default: :oidc

      field :status, Ecto.Enum,
        values: [:draft, :validation_failed, :active, :disabled],
        default: :draft

      field :display_name, :string
      field :login_hint_domains, {:array, :string}, default: []
      field :last_validated_at, :utc_datetime_usec
      field :last_validation_error, :string
      field :organization_id, :binary_id
      embeds_one :oidc_settings, TestOIDCSettings, on_replace: :update
    end

    def changeset(connection, attrs) do
      connection
      |> cast(attrs, [
        :organization_id,
        :protocol,
        :status,
        :display_name,
        :login_hint_domains,
        :last_validated_at,
        :last_validation_error
      ])
      |> validate_required([:organization_id, :protocol, :status, :display_name])
      |> cast_embed(:oidc_settings, required: true, with: &TestOIDCSettings.changeset/2)
    end
  end

  setup :verify_on_exit!

  test "activation failure returns validation_failed and never leaves the row active" do
    org_id = Ecto.UUID.generate()
    scope = %TestScope{active_organization: %TestOrg{id: org_id}}

    config = %{
      repo: Sigra.MockRepo,
      schemas: %{enterprise_connection: TestConnection},
      http_client: fn _opts -> {:error, :econnrefused} end
    }

    Sigra.MockRepo
    |> expect(:get_by, fn TestConnection, [organization_id: ^org_id] -> nil end)
    |> expect(:insert, fn changeset ->
      assert Ecto.Changeset.get_change(changeset, :status) == :validation_failed
      refute Ecto.Changeset.get_change(changeset, :status) == :active
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end)

    assert {:error, :validation_failed} =
             Sigra.EnterpriseConnections.activate_connection(
               config,
               scope,
               %{
                 "display_name" => "Acme Workforce",
                 "oidc_settings" => %{
                   "issuer" => "https://issuer.example",
                   "client_id" => "client-123",
                   "encrypted_client_secret" => "secret",
                   "client_authentication_method" => "client_secret_basic",
                   "scopes" => ["openid"]
                 }
               }
             )
  end
end
