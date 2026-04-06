defmodule Sigra.AuthTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Auth

  # Set up Mox mocks
  setup :verify_on_exit!

  # A minimal test schema that mimics the generated User schema
  defmodule TestUser do
    use Ecto.Schema

    @primary_key {:id, :integer, autogenerate: false}
    embedded_schema do
      field :email, :string
      field :hashed_password, :string
      field :confirmed_at, :utc_datetime
      field :locked_at, :utc_datetime
      field :password_changed_at, :utc_datetime
      field :failed_login_attempts, :integer, default: 0
    end
  end

  # A minimal test token schema that mimics the generated UserToken schema
  defmodule TestUserToken do
    use Ecto.Schema

    @primary_key {:id, :integer, autogenerate: false}
    embedded_schema do
      field :token, :binary
      field :context, :string
      field :sent_to, :string
      field :user_id, :integer
      field :inserted_at, :utc_datetime
    end
  end

  describe "register/3" do
    test "with valid attrs returns {:ok, user}" do
      user = %TestUser{id: 1, email: "user@example.com", hashed_password: "$argon2id$..."}
      changeset = %Ecto.Changeset{valid?: true, data: %TestUser{}}

      Sigra.MockRepo
      |> expect(:insert, fn ^changeset -> {:ok, user} end)

      result =
        Auth.register(Sigra.MockRepo, %{"email" => "user@example.com", "password" => "long_enough_pw"}, changeset_fn: fn _attrs -> changeset end)

      assert {:ok, ^user} = result
    end

    test "with invalid attrs returns {:error, changeset}" do
      changeset = %Ecto.Changeset{valid?: false, data: %TestUser{}, errors: [password: {"too short", []}]}

      Sigra.MockRepo
      |> expect(:insert, fn ^changeset -> {:error, changeset} end)

      result =
        Auth.register(Sigra.MockRepo, %{"email" => "u@e.com", "password" => "short"}, changeset_fn: fn _attrs -> changeset end)

      assert {:error, %Ecto.Changeset{}} = result
    end

    test "with duplicate email returns {:error, :email_taken}" do
      changeset = %Ecto.Changeset{
        valid?: true,
        data: %TestUser{},
        errors: []
      }

      error_changeset = %Ecto.Changeset{
        valid?: false,
        data: %TestUser{},
        errors: [email: {"has already been taken", [constraint: :unique, constraint_name: "users_email_index"]}]
      }

      Sigra.MockRepo
      |> expect(:insert, fn ^changeset -> {:error, error_changeset} end)

      result =
        Auth.register(Sigra.MockRepo, %{"email" => "dup@e.com", "password" => "long_enough_pw"}, changeset_fn: fn _attrs -> changeset end)

      assert {:error, :email_taken} = result
    end

    test "emits register telemetry event" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :auth, :register, :stop]])

      user = %TestUser{id: 42, email: "user@example.com"}
      changeset = %Ecto.Changeset{valid?: true, data: %TestUser{}}

      Sigra.MockRepo
      |> expect(:insert, fn _cs -> {:ok, user} end)

      Auth.register(Sigra.MockRepo, %{}, changeset_fn: fn _attrs -> changeset end)

      assert_received {[:sigra, :auth, :register, :stop], ^ref, _measurements, metadata}
      assert metadata.user_id == 42
    end
  end

  describe "authenticate/3" do
    test "with correct email and password returns {:ok, user}" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 2
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update, fn changeset ->
        changes = changeset.changes
        assert changes.failed_login_attempts == 0
        {:ok, struct(user, changes)}
      end)

      result =
        Auth.authenticate(
          Sigra.MockRepo,
          %{"email" => "user@example.com", "password" => "correct_password"},
          user_schema: TestUser
        )

      assert {:ok, authenticated_user} = result
      assert authenticated_user.id == 1
    end

    test "with wrong password increments failed_login_attempts" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 0
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update, fn changeset ->
        changes = changeset.changes
        assert changes.failed_login_attempts == 1
        {:ok, struct(user, changes)}
      end)

      result =
        Auth.authenticate(
          Sigra.MockRepo,
          %{"email" => "user@example.com", "password" => "wrong_password"},
          user_schema: TestUser
        )

      assert {:error, :invalid_credentials} = result
    end

    test "with non-existent email returns {:error, :invalid_credentials} without DB write" do
      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "nobody@example.com"] -> nil end)
      # No update call expected - verified by Mox verify_on_exit!

      result =
        Auth.authenticate(
          Sigra.MockRepo,
          %{"email" => "nobody@example.com", "password" => "any_password"},
          user_schema: TestUser
        )

      assert {:error, :invalid_credentials} = result
    end

    test "with bcrypt hash upgrades to argon2id" do
      # Only run if bcrypt_elixir is available
      if Code.ensure_loaded?(Bcrypt) do
        bcrypt_hash = Bcrypt.hash_pwd_salt("correct_password")

        user = %TestUser{
          id: 1,
          email: "user@example.com",
          hashed_password: bcrypt_hash,
          confirmed_at: ~U[2024-01-01 00:00:00Z],
          failed_login_attempts: 0
        }

        Sigra.MockRepo
        |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
        |> expect(:update, fn changeset ->
          changes = changeset.changes
          # failed_login_attempts may not appear in changes if already 0
          assert Map.get(changes, :failed_login_attempts, 0) == 0
          assert String.starts_with?(changes.hashed_password, "$argon2id$")
          {:ok, struct(user, changes)}
        end)

        result =
          Auth.authenticate(
            Sigra.MockRepo,
            %{"email" => "user@example.com", "password" => "correct_password"},
            user_schema: TestUser
          )

        assert {:ok, _user} = result
      end
    end

    test "with unconfirmed user and require_confirmation returns {:error, :unconfirmed}" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: nil,
        failed_login_attempts: 0
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)

      result =
        Auth.authenticate(
          Sigra.MockRepo,
          %{"email" => "user@example.com", "password" => "correct_password"},
          user_schema: TestUser,
          require_confirmation: true
        )

      assert {:error, :unconfirmed} = result
    end

    test "emits login telemetry event on success" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :auth, :login, :stop]])
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 5,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 3
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, _ -> user end)
      |> expect(:update, fn changeset -> {:ok, Map.merge(user, changeset.changes)} end)

      Auth.authenticate(
        Sigra.MockRepo,
        %{"email" => "user@example.com", "password" => "correct_password"},
        user_schema: TestUser
      )

      assert_received {[:sigra, :auth, :login, :stop], ^ref, _measurements, metadata}
      assert metadata.user_id == 5
      assert metadata.failed_attempts_before == 3
    end

    test "emits hash_upgraded telemetry event on hash upgrade" do
      if Code.ensure_loaded?(Bcrypt) do
        ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :auth, :hash_upgraded]])
        bcrypt_hash = Bcrypt.hash_pwd_salt("correct_password")

        user = %TestUser{
          id: 1,
          email: "user@example.com",
          hashed_password: bcrypt_hash,
          confirmed_at: ~U[2024-01-01 00:00:00Z],
          failed_login_attempts: 0
        }

        Sigra.MockRepo
        |> expect(:get_by, fn TestUser, _ -> user end)
        |> expect(:update, fn changeset -> {:ok, Map.merge(user, changeset.changes)} end)

        Auth.authenticate(
          Sigra.MockRepo,
          %{"email" => "user@example.com", "password" => "correct_password"},
          user_schema: TestUser
        )

        assert_received {[:sigra, :auth, :hash_upgraded], ^ref, _measurements, metadata}
        assert metadata.user_id == 1
      end
    end

    test "normalizes email before lookup" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 0
      }

      # Expects normalized email (lowercase, trimmed)
      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update, fn changeset -> {:ok, Map.merge(user, changeset.changes)} end)

      Auth.authenticate(
        Sigra.MockRepo,
        %{"email" => "  USER@Example.COM  ", "password" => "correct_password"},
        user_schema: TestUser
      )
    end
  end

  describe "request_magic_link/3" do
    test "for existing user returns {:ok, {token, url}}" do
      user = %TestUser{id: 1, email: "user@example.com"}

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:insert!, fn %{token: _, context: "magic_link", sent_to: "user@example.com", user_id: 1} -> :ok end)

      url_fun = fn token -> "https://example.com/magic/#{token}" end

      result =
        Auth.request_magic_link(
          Sigra.MockRepo,
          "user@example.com",
          user_schema: TestUser,
          url_fun: url_fun
        )

      assert {:ok, {raw_token, url}} = result
      assert is_binary(raw_token)
      assert String.starts_with?(url, "https://example.com/magic/")
    end

    test "for non-existent email returns {:ok, :sent} without DB write" do
      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "nobody@example.com"] -> nil end)
      # No insert! call expected

      result =
        Auth.request_magic_link(
          Sigra.MockRepo,
          "nobody@example.com",
          user_schema: TestUser,
          url_fun: fn _t -> "" end
        )

      assert {:ok, :sent} = result
    end

    test "when rate limited returns {:error, :rate_limited}" do
      user = %TestUser{id: 1, email: "user@example.com"}

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)

      Sigra.MockRateLimiter
      |> expect(:check_rate, fn "magic_link:user@example.com", 3, 900_000 -> {:deny, 60_000} end)

      result =
        Auth.request_magic_link(
          Sigra.MockRepo,
          "user@example.com",
          user_schema: TestUser,
          url_fun: fn _t -> "" end,
          rate_limiter: Sigra.MockRateLimiter
        )

      assert {:error, :rate_limited} = result
    end
  end

  describe "verify_magic_link/3" do
    test "valid token returns {:ok, user} and deletes token" do
      {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: ~U[2024-01-01 00:00:00Z]}
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      token_struct = %TestUserToken{
        token: hashed_token,
        context: "magic_link",
        sent_to: "user@example.com",
        user_id: 1,
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: ^hashed_token, context: "magic_link"] -> token_struct end)
      |> expect(:get!, fn TestUser, 1 -> user end)
      |> expect(:delete!, fn ^token_struct -> :ok end)

      result =
        Auth.verify_magic_link(
          Sigra.MockRepo,
          raw_token,
          user_schema: TestUser,
          user_token_schema: TestUserToken,
          magic_link_ttl: 600
        )

      assert {:ok, ^user} = result
    end

    test "expired token returns {:error, :expired}" do
      {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()
      # Token inserted 20 minutes ago (past 10-minute TTL)
      inserted_at = DateTime.utc_now() |> DateTime.add(-1200, :second) |> DateTime.truncate(:second)

      token_struct = %TestUserToken{
        token: hashed_token,
        context: "magic_link",
        sent_to: "user@example.com",
        user_id: 1,
        inserted_at: inserted_at
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: ^hashed_token, context: "magic_link"] -> token_struct end)

      result =
        Auth.verify_magic_link(
          Sigra.MockRepo,
          raw_token,
          user_schema: TestUser,
          user_token_schema: TestUserToken,
          magic_link_ttl: 600
        )

      assert {:error, :expired} = result
    end

    test "already-used token returns {:error, :invalid}" do
      {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: ^hashed_token, context: "magic_link"] -> nil end)

      result =
        Auth.verify_magic_link(
          Sigra.MockRepo,
          raw_token,
          user_schema: TestUser,
          user_token_schema: TestUserToken,
          magic_link_ttl: 600
        )

      assert {:error, :invalid} = result
    end

    test "confirms unconfirmed user" do
      {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: nil}
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      token_struct = %TestUserToken{
        token: hashed_token,
        context: "magic_link",
        sent_to: "user@example.com",
        user_id: 1,
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: ^hashed_token, context: "magic_link"] -> token_struct end)
      |> expect(:get!, fn TestUser, 1 -> user end)
      |> expect(:delete!, fn ^token_struct -> :ok end)
      |> expect(:update, fn changeset ->
        assert changeset.changes.confirmed_at
        {:ok, Map.put(user, :confirmed_at, changeset.changes.confirmed_at)}
      end)

      result =
        Auth.verify_magic_link(
          Sigra.MockRepo,
          raw_token,
          user_schema: TestUser,
          user_token_schema: TestUserToken,
          magic_link_ttl: 600
        )

      assert {:ok, confirmed_user} = result
      assert confirmed_user.confirmed_at
    end
  end
end
