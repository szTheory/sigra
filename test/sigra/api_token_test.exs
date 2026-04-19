defmodule Sigra.APITokenTest do
  use ExUnit.Case, async: true

  alias Sigra.APIToken

  # A minimal mock schema module for api_token_schema
  defmodule MockAPITokenSchema do
    use Ecto.Schema

    schema "user_api_tokens" do
      field :user_id, :integer
      field :hashed_token, :binary
      field :prefix, :string
      field :name, :string
      field :scopes, {:array, :string}
      field :expires_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :last_used_at, :utc_datetime
      timestamps()
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [
        :user_id,
        :hashed_token,
        :prefix,
        :name,
        :scopes,
        :expires_at
      ])
      |> Ecto.Changeset.validate_required([:user_id, :hashed_token, :prefix, :name, :scopes])
      |> Ecto.Changeset.validate_length(:name, max: 255)
    end
  end

  # A mock repo that stores in-memory for testing
  defmodule MockRepo do
    @behaviour Sigra.APITokenTest.RepoBehaviour

    def insert(changeset, opts \\ [])

    def insert(changeset, _opts) do
      if changeset.valid? do
        token = Ecto.Changeset.apply_changes(changeset)
        token = Map.put(token, :id, System.unique_integer([:positive]))
        {:ok, token}
      else
        {:error, changeset}
      end
    end

    def transaction(%Ecto.Multi{} = multi) do
      return = fn err -> throw({:mock_multi_abort, err}) end
      wrap = fn fun -> fun.() end

      try do
        case Ecto.Multi.__apply__(multi, __MODULE__, wrap, return) do
          {:ok, result} ->
            {:ok, result}

          result when is_map(result) ->
            {:ok, result}

          {:error, {name, val, acc}} ->
            {:error, name, val, acc}
        end
      catch
        :throw, {:mock_multi_abort, {name, val, acc}} ->
          {:error, name, val, acc}
      end
    end

    def get_by(_schema, clauses) do
      send(self(), {:repo_get_by, clauses})
      # Default: return nil (not found)
      receive do
        {:mock_get_by_result, result} -> result
      after
        0 -> nil
      end
    end

    def get(_schema, id) do
      send(self(), {:repo_get, id})

      receive do
        {:mock_get_result, result} -> result
      after
        0 -> nil
      end
    end

    def update(changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

    def update_all(_query, _updates) do
      receive do
        {:mock_update_all_result, result} -> result
      after
        0 -> {0, nil}
      end
    end

    def all(_query) do
      receive do
        {:mock_all_result, result} -> result
      after
        0 -> []
      end
    end
  end

  defmodule RepoBehaviour do
    @callback insert(Ecto.Changeset.t()) :: {:ok, term()} | {:error, Ecto.Changeset.t()}
    @callback get_by(module(), keyword()) :: term() | nil
  end

  defp config(opts \\ []) do
    defaults = [
      repo: MockRepo,
      user_schema: MyApp.User,
      otp_app: :my_app,
      api_token:
        Keyword.merge([api_token_schema: MockAPITokenSchema], Keyword.get(opts, :api_token, []))
    ]

    opts_without_api_token = Keyword.delete(opts, :api_token)
    Sigra.Config.new!(Keyword.merge(defaults, opts_without_api_token))
  end

  defp mock_user do
    %{id: 42}
  end

  describe "create/3" do
    test "returns {:ok, raw_key, token} with prefix prepended" do
      cfg = config()
      user = mock_user()

      {:ok, raw_key, token} =
        APIToken.create(cfg, user, %{name: "CI Key", scopes: ["profile:read"]})

      assert String.starts_with?(raw_key, "my_app_sk_")
      assert token.name == "CI Key"
      assert token.scopes == ["profile:read"]
    end

    test "raw_key starts with configured prefix" do
      cfg = config(api_token: [prefix: "test_sk_", api_token_schema: MockAPITokenSchema])
      user = mock_user()

      {:ok, raw_key, _token} =
        APIToken.create(cfg, user, %{name: "Test", scopes: ["profile:read"]})

      assert String.starts_with?(raw_key, "test_sk_")
    end

    test "stores SHA-256 hash of full raw_key including prefix" do
      cfg = config()
      user = mock_user()

      {:ok, raw_key, token} =
        APIToken.create(cfg, user, %{name: "Hash Test", scopes: ["profile:read"]})

      expected_hash = :crypto.hash(:sha256, raw_key)
      assert token.hashed_token == expected_hash
    end

    test "returns {:error, :scopes_required} when scopes is empty" do
      cfg = config()
      user = mock_user()

      assert {:error, :scopes_required} =
               APIToken.create(cfg, user, %{name: "No Scopes", scopes: []})
    end

    test "validates scopes against registry, rejects unregistered" do
      cfg = config()
      user = mock_user()

      assert {:error, {:unregistered_scopes, ["fake:scope"]}} =
               APIToken.create(cfg, user, %{name: "Bad Scopes", scopes: ["fake:scope"]})
    end

    test "validates name is required" do
      cfg = config()
      user = mock_user()

      assert {:error, _} = APIToken.create(cfg, user, %{name: "", scopes: ["profile:read"]})
    end

    test "validates name max 255 chars" do
      cfg = config()
      user = mock_user()
      long_name = String.duplicate("a", 256)

      assert {:error, _} =
               APIToken.create(cfg, user, %{name: long_name, scopes: ["profile:read"]})
    end

    test "with require_expiry: true rejects nil expires_at" do
      cfg = config(api_token: [require_expiry: true, api_token_schema: MockAPITokenSchema])
      user = mock_user()

      assert {:error, :expiry_required} =
               APIToken.create(cfg, user, %{name: "No Expiry", scopes: ["profile:read"]})
    end

    test "with max_ttl enforces maximum expiration" do
      cfg = config(api_token: [max_ttl: 3600, api_token_schema: MockAPITokenSchema])
      user = mock_user()
      too_far = DateTime.add(DateTime.utc_now(), 7200, :second)

      assert {:error, :ttl_exceeded} =
               APIToken.create(cfg, user, %{
                 name: "Too Long",
                 scopes: ["profile:read"],
                 expires_at: too_far
               })
    end

    test "validates prefix does not start with eyJ" do
      cfg = config(api_token: [prefix: "eyJfoo_", api_token_schema: MockAPITokenSchema])
      user = mock_user()

      assert {:error, :invalid_prefix} =
               APIToken.create(cfg, user, %{name: "JWT Collision", scopes: ["profile:read"]})
    end
  end

  describe "verify/2" do
    test "returns {:error, :invalid_token} for unknown token" do
      cfg = config()

      assert {:error, :invalid_token} = APIToken.verify(cfg, "my_app_sk_nonexistent_token")
    end

    test "returns {:ok, token} for valid active token" do
      cfg = config()
      user = mock_user()

      {:ok, raw_key, _token} =
        APIToken.create(cfg, user, %{name: "Valid", scopes: ["profile:read"]})

      # Provide the token via mock message
      hashed = :crypto.hash(:sha256, raw_key)

      mock_token = %{
        id: 1,
        hashed_token: hashed,
        revoked_at: nil,
        expires_at: nil,
        last_used_at: nil,
        scopes: ["profile:read"]
      }

      send(self(), {:mock_get_by_result, mock_token})

      assert {:ok, ^mock_token} = APIToken.verify(cfg, raw_key)
    end

    test "returns {:error, :token_revoked} for revoked token" do
      cfg = config()
      hashed = :crypto.hash(:sha256, "my_app_sk_test")

      mock_token = %{
        id: 1,
        hashed_token: hashed,
        revoked_at: DateTime.utc_now(),
        expires_at: nil,
        last_used_at: nil
      }

      send(self(), {:mock_get_by_result, mock_token})

      assert {:error, :token_revoked} = APIToken.verify(cfg, "my_app_sk_test")
    end

    test "returns {:error, :token_expired} for expired token" do
      cfg = config()
      hashed = :crypto.hash(:sha256, "my_app_sk_test")

      mock_token = %{
        id: 1,
        hashed_token: hashed,
        revoked_at: nil,
        expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        last_used_at: nil
      }

      send(self(), {:mock_get_by_result, mock_token})

      assert {:error, :token_expired} = APIToken.verify(cfg, "my_app_sk_test")
    end
  end

  describe "can?/2" do
    test "returns true when token has required scope" do
      token = %{scopes: ["profile:read", "sessions:write"]}
      assert APIToken.can?(token, ["profile:read"]) == true
    end

    test "returns false when token lacks required scope" do
      token = %{scopes: ["profile:read"]}
      assert APIToken.can?(token, ["sessions:write"]) == false
    end

    test "with wildcard * scope returns true for any check" do
      token = %{scopes: ["*"]}
      assert APIToken.can?(token, ["anything:here"]) == true
    end

    test "with match: :all requires all scopes (default)" do
      token = %{scopes: ["profile:read"]}
      assert APIToken.can?(token, ["profile:read", "sessions:write"]) == false
    end

    test "with match: :any returns true if any scope matches" do
      token = %{scopes: ["profile:read"]}
      assert APIToken.can?(token, ["profile:read", "sessions:write"], match: :any) == true
    end

    test "with match: :any returns false if no scope matches" do
      token = %{scopes: ["profile:read"]}
      assert APIToken.can?(token, ["sessions:write", "mfa:read"], match: :any) == false
    end

    test "accepts scope struct with token_scopes field" do
      scope = %{token_scopes: ["profile:read", "sessions:write"]}
      assert APIToken.can?(scope, ["profile:read"]) == true
    end
  end

  describe "list_scopes/1" do
    test "delegates to ScopeRegistry.all_scopes" do
      cfg = config()
      scopes = APIToken.list_scopes(cfg)

      assert "profile:read" in scopes
      assert "mfa:write" in scopes
      assert length(scopes) == 8
    end
  end

  describe "encode_cursor/2 and decode_cursor/1" do
    test "round-trips cursor encoding" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      cursor = APIToken.encode_cursor(now, 42)
      {decoded_at, decoded_id} = APIToken.decode_cursor(cursor)

      assert decoded_at == now
      assert decoded_id == 42
    end
  end
end
