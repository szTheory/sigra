defmodule Sigra.ServiceAccountsTest do
  use ExUnit.Case, async: true

  alias Sigra.{JWT, ServiceAccounts}

  defmodule ServiceAccount do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "service_accounts" do
      field :name, :string
      field :scopes, {:array, :string}, default: []
      field :role, :string
      field :token_epoch, :integer, default: 0
      field :revoked_at, :utc_datetime
      field :last_used_at, :utc_datetime
      field :organization_id, :binary_id
      field :created_by_user_id, :binary_id
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:id, :name, :scopes, :role, :token_epoch, :organization_id, :created_by_user_id])
      |> validate_required([:name, :organization_id])
    end
  end

  defmodule Credential do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "service_account_credentials" do
      field :client_id, :string
      field :hashed_client_secret, :binary
      field :expires_at, :utc_datetime
      field :last_used_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :service_account_id, :binary_id
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:id, :client_id, :hashed_client_secret, :expires_at, :service_account_id])
      |> validate_required([:client_id, :hashed_client_secret, :service_account_id])
    end
  end

  defmodule MockRepo do
    def insert(changeset, _opts \\ []) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset) |> with_id()}
      else
        {:error, changeset}
      end
    end

    def update(changeset, _opts \\ []), do: {:ok, Ecto.Changeset.apply_changes(changeset)}

    def transaction(%Ecto.Multi{} = multi) do
      return = fn err -> throw({:mock_multi_abort, err}) end
      wrap = fn fun -> fun.() end

      try do
        case Ecto.Multi.__apply__(multi, __MODULE__, wrap, return) do
          {:ok, result} -> {:ok, result}
          result when is_map(result) -> {:ok, result}
          {:error, {name, val, acc}} -> {:error, name, val, acc}
        end
      catch
        :throw, {:mock_multi_abort, {name, val, acc}} ->
          {:error, name, val, acc}
      end
    end

    def get(ServiceAccount, id), do: Process.get({:service_account, id})
    def get(Credential, id), do: Process.get({:credential, id})
    def get_by(Credential, client_id: client_id), do: Process.get({:credential_by_client_id, client_id})

    defp with_id(struct) do
      Map.put(struct, :id, Map.get(struct, :id) || "id-#{System.unique_integer([:positive])}")
    end
  end

  defp config(overrides \\ []) do
    defaults = [
      repo: MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :sigra,
      secret_key_base: String.duplicate("a", 64),
      audit: [audit_schema: Sigra.Test.AuditEvent],
      service_accounts: [
        service_account_schema: ServiceAccount,
        service_account_credential_schema: Credential,
        client_id_prefix: "sigra_sa_",
        client_id_byte_size: 24
      ],
      jwt: [enabled: true, algorithm: "HS256", issuer: "sigra", client_credentials_access_ttl: 3600]
    ]

    Sigra.Config.new!(Keyword.merge(defaults, overrides))
  end

  defp scope, do: %{user: %{id: "user-1"}, active_organization: %{id: "org-1"}}

  test "create/3 inserts a service account" do
    assert {:ok, sa} =
             ServiceAccounts.create(config(), scope(), %{
               name: "CI",
               scopes: ["deploy:write"],
               organization_id: "org-1"
             })

    assert sa.name == "CI"
    assert sa.organization_id == "org-1"
  end

  test "revoke/3 bumps token_epoch and sets revoked_at" do
    sa = %ServiceAccount{id: "sa-1", organization_id: "org-1", token_epoch: 3}

    assert {:ok, updated} = ServiceAccounts.revoke(config(), scope(), sa)
    assert updated.token_epoch == 4
    refute is_nil(updated.revoked_at)
  end

  test "create_credential/4 returns plaintext secret and stored hash" do
    sa = %ServiceAccount{id: "sa-1", organization_id: "org-1"}

    assert {:ok, credential, raw_secret} = ServiceAccounts.create_credential(config(), scope(), sa, %{})
    assert credential.service_account_id == sa.id
    assert credential.client_id =~ "sigra_sa_"
    assert credential.hashed_client_secret == Sigra.Token.hash_token(raw_secret)
  end

  test "revoke_credential/3 sets revoked_at without error" do
    sa = %ServiceAccount{id: "sa-1", organization_id: "org-1"}
    credential = %Credential{id: "cred-1", service_account_id: sa.id, client_id: "sigra_sa_abc"}
    Process.put({:service_account, sa.id}, sa)

    assert {:ok, updated} = ServiceAccounts.revoke_credential(config(), scope(), credential)
    refute is_nil(updated.revoked_at)
  end

  test "issue_token/4 delegates to JWT service-account generator" do
    sa = %ServiceAccount{id: "sa-1", organization_id: "org-1", scopes: ["deploy:write"], token_epoch: 0}
    credential = %Credential{
      id: "cred-1",
      service_account_id: sa.id,
      client_id: "sigra_sa_abc",
      hashed_client_secret: Sigra.Token.hash_token("secret"),
      revoked_at: nil
    }
    Process.put({:service_account, sa.id}, sa)
    Process.put({:credential, credential.id}, credential)

    assert {:ok, %{access_token: jwt, refresh_token: nil, expires_in: 3600}} =
             ServiceAccounts.issue_token(config(), sa, credential)

    assert {:ok, claims} = JWT.verify_access(config(), jwt)
    assert claims["actor_type"] == "service_account"
  end
end
