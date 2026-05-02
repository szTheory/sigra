defmodule Sigra.OAuth.TokenTest do
  use ExUnit.Case, async: true

  alias Sigra.OAuth.Token

  defmodule Credential do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "service_account_credentials" do
      field :client_id, :string
      field :hashed_client_secret, :binary
      field :expires_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :service_account_id, :binary_id
      field :last_used_at, :utc_datetime
    end
  end

  defmodule ServiceAccount do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "service_accounts" do
      field :organization_id, :binary_id
      field :scopes, {:array, :string}, default: []
      field :role, :string
      field :token_epoch, :integer, default: 0
      field :revoked_at, :utc_datetime
    end
  end

  defmodule MockRepo do
    def get_by(Credential, client_id: client_id), do: Process.get({:cred_by_client_id, client_id})
    def get(ServiceAccount, id), do: Process.get({:service_account, id})

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

    def update(changeset, _opts \\ []), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
    def insert(changeset, _opts \\ []), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  end

  defp config do
    Sigra.Config.new!(
      repo: MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :sigra,
      secret_key_base: String.duplicate("a", 64),
      audit: [audit_schema: Sigra.Test.AuditEvent],
      service_accounts: [
        service_account_schema: ServiceAccount,
        service_account_credential_schema: Credential
      ],
      jwt: [enabled: true, algorithm: "HS256", issuer: "sigra", client_credentials_access_ttl: 3600]
    )
  end

  test "returns invalid_client for unknown client_id" do
    assert {:error, :invalid_client} =
             Token.client_credentials(config(), client_id: "missing", client_secret: "secret")
  end

  test "returns invalid_client for revoked credential" do
    cred = %Credential{
      id: "cred-1",
      client_id: "sigra_sa_a",
      hashed_client_secret: Sigra.Token.hash_token("secret"),
      revoked_at: DateTime.utc_now(),
      service_account_id: "sa-1"
    }

    Process.put({:cred_by_client_id, cred.client_id}, cred)

    assert {:error, :invalid_client} =
             Token.client_credentials(config(), client_id: cred.client_id, client_secret: "secret")
  end

  test "returns invalid_scope for scopes outside granted list" do
    sa = %ServiceAccount{id: "sa-1", organization_id: "org-1", scopes: ["billing:read"], token_epoch: 0}

    cred = %Credential{
      id: "cred-1",
      client_id: "sigra_sa_a",
      hashed_client_secret: Sigra.Token.hash_token("secret"),
      service_account_id: sa.id
    }

    Process.put({:cred_by_client_id, cred.client_id}, cred)
    Process.put({:service_account, sa.id}, sa)

    assert {:error, :invalid_scope} =
             Token.client_credentials(
               config(),
               client_id: cred.client_id,
               client_secret: "secret",
               scope: "deploy:write"
             )
  end

  test "issues a token for valid credentials" do
    sa = %ServiceAccount{id: "sa-1", organization_id: "org-1", scopes: ["billing:read"], token_epoch: 0}

    cred = %Credential{
      id: "cred-1",
      client_id: "sigra_sa_a",
      hashed_client_secret: Sigra.Token.hash_token("secret"),
      service_account_id: sa.id
    }

    Process.put({:cred_by_client_id, cred.client_id}, cred)
    Process.put({:service_account, sa.id}, sa)

    assert {:ok, %{access_token: jwt, scope: "billing:read", expires_in: 3600}} =
             Token.client_credentials(config(), client_id: cred.client_id, client_secret: "secret")

    assert is_binary(jwt)
  end
end
