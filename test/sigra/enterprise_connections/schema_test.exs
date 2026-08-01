defmodule Sigra.EnterpriseConnections.SchemaTest do
  use ExUnit.Case, async: true

  defmodule MyApp.Accounts.Encrypted.Binary do
    use Ecto.Type
    def type, do: :binary
    def cast(v) when is_binary(v) or is_nil(v), do: {:ok, v}
    def cast(_), do: :error
    def dump(v) when is_binary(v) or is_nil(v), do: {:ok, v}
    def dump(_), do: :error
    def load(v) when is_binary(v) or is_nil(v), do: {:ok, v}
    def load(_), do: :error
  end

  defmodule MyApp.Accounts.Organization do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organizations" do
    end
  end

  defmodule MyApp.Accounts.EnterpriseConnectionOIDCSettings do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :issuer, :string
      field :discovery_document_uri, :string
      field :client_id, :string
      field :encrypted_client_secret, MyApp.Accounts.Encrypted.Binary
      field :client_authentication_method, :string, default: "client_secret_basic"
      field :scopes, {:array, :string}, default: ["openid", "profile", "email"]
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

  defmodule MyApp.Accounts.EnterpriseConnection do
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
      belongs_to :organization, MyApp.Accounts.Organization

      embeds_one :oidc_settings, MyApp.Accounts.EnterpriseConnectionOIDCSettings,
        on_replace: :update

      timestamps(type: :utc_datetime)
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
      |> cast_embed(:oidc_settings,
        required: true,
        with: &MyApp.Accounts.EnterpriseConnectionOIDCSettings.changeset/2
      )
    end
  end

  test "generated shape accepts protocol-neutral top-level fields with nested OIDC settings" do
    changeset =
      MyApp.Accounts.EnterpriseConnection.changeset(
        %MyApp.Accounts.EnterpriseConnection{},
        %{
          organization_id: Ecto.UUID.generate(),
          protocol: :oidc,
          status: :draft,
          display_name: "Acme Workforce",
          login_hint_domains: ["acme.example"],
          oidc_settings: %{
            issuer: "https://issuer.example",
            client_id: "client-123",
            encrypted_client_secret: "secret",
            client_authentication_method: "client_secret_basic",
            scopes: ["openid", "email"]
          }
        }
      )

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :status) == :draft
    assert Ecto.Changeset.get_field(changeset, :protocol) == :oidc
  end

  test "exact lifecycle atoms remain available" do
    for status <- [:draft, :validation_failed, :active, :disabled] do
      changeset =
        MyApp.Accounts.EnterpriseConnection.changeset(
          %MyApp.Accounts.EnterpriseConnection{},
          %{
            organization_id: Ecto.UUID.generate(),
            protocol: :oidc,
            status: status,
            display_name: "Status #{status}",
            oidc_settings: %{
              issuer: "https://issuer.example",
              client_id: "client-123",
              encrypted_client_secret: "secret",
              client_authentication_method: "client_secret_basic",
              scopes: ["openid"]
            }
          }
        )

      assert changeset.valid?
    end
  end
end
