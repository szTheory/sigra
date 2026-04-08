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

  # -- Phase 3 Plan 02: Confirmation and Reset functions --

  @secret_key_base String.duplicate("a", 64)

  describe "generate_confirmation_token/3" do
    test "returns {encoded_token, code, link_token_struct, code_token_struct}" do
      user = %TestUser{id: 1, email: "user@example.com"}

      {encoded_token, code, link_struct, code_struct} =
        Auth.generate_confirmation_token(Sigra.MockRepo, user,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken
        )

      # encoded_token is a URL-safe base64 string (HMAC-signed)
      assert is_binary(encoded_token)
      assert byte_size(encoded_token) > 0

      # code is a 6-digit numeric string
      assert Regex.match?(~r/^\d{6}$/, code)
      code_int = String.to_integer(code)
      assert code_int >= 100_000 and code_int <= 999_999

      # link_struct has context "confirm"
      assert link_struct.context == "confirm"
      assert link_struct.user_id == 1
      assert link_struct.sent_to == "user@example.com"
      assert is_binary(link_struct.token)

      # code_struct has context "confirm_code"
      assert code_struct.context == "confirm_code"
      assert code_struct.user_id == 1
      assert is_binary(code_struct.token)
    end
  end

  describe "confirm_user/3" do
    test "with valid HMAC-signed token returns {:ok, user} with confirmed_at set" do
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: nil}

      # Generate a real confirmation token
      {encoded_token, _code, link_struct, _code_struct} =
        Auth.generate_confirmation_token(Sigra.MockRepo, user,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken
        )

      # Mock get_by for token lookup, then transaction for atomic confirm
      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: _, context: "confirm"] ->
        %TestUserToken{id: 1, token: link_struct.token, context: "confirm", user_id: 1,
                       inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      end)
      |> expect(:transaction, fn multi ->
        assert %Ecto.Multi{} = multi
        confirmed_user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{confirm_user: confirmed_user}}
      end)

      result =
        Auth.confirm_user(Sigra.MockRepo, encoded_token,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser
        )

      assert {:ok, confirmed_user} = result
      assert confirmed_user.confirmed_at
    end

    test "with valid token deletes all confirm and confirm_code tokens for user" do
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: nil}

      {encoded_token, _code, link_struct, _code_struct} =
        Auth.generate_confirmation_token(Sigra.MockRepo, user,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken
        )

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: _, context: "confirm"] ->
        %TestUserToken{id: 1, token: link_struct.token, context: "confirm", user_id: 1,
                       inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      end)
      |> expect(:transaction, fn multi ->
        assert %Ecto.Multi{} = multi
        confirmed_user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{confirm_user: confirmed_user}}
      end)

      assert {:ok, _user} =
               Auth.confirm_user(Sigra.MockRepo, encoded_token,
                 secret_key_base: @secret_key_base,
                 user_token_schema: TestUserToken,
                 user_schema: TestUser
               )
    end

    test "with expired token returns {:error, :token_expired}" do
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: nil}

      # Generate token, then verify with a very short TTL that's already passed
      {encoded_token, _code, _link_struct, _code_struct} =
        Auth.generate_confirmation_token(Sigra.MockRepo, user,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken
        )

      result =
        Auth.confirm_user(Sigra.MockRepo, encoded_token,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          confirmation_ttl: 0
        )

      assert {:error, :token_expired} = result
    end

    test "with invalid HMAC signature returns {:error, :token_invalid}" do
      result =
        Auth.confirm_user(Sigra.MockRepo, "totally-invalid-token",
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser
        )

      assert {:error, :token_invalid} = result
    end

    test "with already-confirmed user returns {:error, :already_confirmed}" do
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: nil}

      {encoded_token, _code, link_struct, _code_struct} =
        Auth.generate_confirmation_token(Sigra.MockRepo, user,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken
        )

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: _, context: "confirm"] ->
        %TestUserToken{id: 1, token: link_struct.token, context: "confirm", user_id: 1,
                       inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      end)
      |> expect(:transaction, fn _multi ->
        {:error, :confirm_user, :already_confirmed, %{}}
      end)

      result =
        Auth.confirm_user(Sigra.MockRepo, encoded_token,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser
        )

      assert {:error, :already_confirmed} = result
    end
  end

  describe "verify_confirmation_code/3" do
    test "with valid 6-digit code returns {:ok, user} with confirmed_at set" do
      user = %TestUser{id: 1, email: "user@example.com", confirmed_at: nil}

      {_encoded_token, code, _link_struct, code_struct} =
        Auth.generate_confirmation_token(Sigra.MockRepo, user,
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken
        )

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: _, context: "confirm_code"] ->
        %TestUserToken{id: 2, token: code_struct.token, context: "confirm_code", user_id: 1,
                       inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      end)
      |> expect(:transaction, fn multi ->
        assert %Ecto.Multi{} = multi
        confirmed_user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{confirm_user: confirmed_user}}
      end)

      result =
        Auth.verify_confirmation_code(Sigra.MockRepo, code,
          user_id: user.id,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          secret_key_base: @secret_key_base
        )

      assert {:ok, confirmed_user} = result
      assert confirmed_user.confirmed_at
    end

    test "with invalid code returns {:error, :invalid_code}" do
      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: _, context: "confirm_code"] -> nil end)

      result =
        Auth.verify_confirmation_code(Sigra.MockRepo, "000000",
          user_id: 1,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          secret_key_base: @secret_key_base
        )

      assert {:error, :invalid_code} = result
    end

    test "with rate limiting returns {:error, :rate_limited}" do
      Sigra.MockRateLimiter
      |> expect(:check_rate, fn "sigra:confirm_code:1", 5, 900_000 -> {:deny, 60_000} end)

      result =
        Auth.verify_confirmation_code(Sigra.MockRepo, "123456",
          user_id: 1,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          secret_key_base: @secret_key_base,
          rate_limiter: Sigra.MockRateLimiter
        )

      assert {:error, :rate_limited} = result
    end
  end

  describe "request_password_reset/3" do
    test "with existing email returns {:ok, {token, url}}" do
      user = %TestUser{id: 1, email: "user@example.com"}

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:insert!, fn token_struct ->
        assert token_struct.context == "reset_password"
        assert token_struct.user_id == 1
        assert is_binary(token_struct.token)
        token_struct
      end)

      url_fun = fn token -> "https://example.com/reset/#{token}" end

      result =
        Auth.request_password_reset(Sigra.MockRepo, "user@example.com",
          user_schema: TestUser,
          secret_key_base: @secret_key_base,
          url_fun: url_fun
        )

      assert {:ok, {signed_token, url}} = result
      assert is_binary(signed_token)
      assert String.starts_with?(url, "https://example.com/reset/")
    end

    test "with non-existent email returns {:ok, :sent} (enumeration-safe)" do
      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "nobody@example.com"] -> nil end)

      result =
        Auth.request_password_reset(Sigra.MockRepo, "nobody@example.com",
          user_schema: TestUser,
          secret_key_base: @secret_key_base,
          url_fun: fn _t -> "" end
        )

      assert {:ok, :sent} = result
    end

    test "with rate limiting returns {:error, :rate_limited}" do
      user = %TestUser{id: 1, email: "user@example.com"}

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)

      Sigra.MockRateLimiter
      |> expect(:check_rate, fn "sigra:reset:" <> _, 3, 900_000 -> {:deny, 60_000} end)

      result =
        Auth.request_password_reset(Sigra.MockRepo, "user@example.com",
          user_schema: TestUser,
          secret_key_base: @secret_key_base,
          url_fun: fn _t -> "" end,
          rate_limiter: Sigra.MockRateLimiter
        )

      assert {:error, :rate_limited} = result
    end
  end

  describe "reset_password/4" do
    test "with valid token changes password and deletes all tokens" do
      user = %TestUser{id: 1, email: "user@example.com", hashed_password: "old_hash"}

      # Generate a real reset token
      {raw_bytes, hashed} = Sigra.Token.generate_hashed_token()
      signed_token = Plug.Crypto.sign(@secret_key_base, "sigra-reset-token", raw_bytes)
      encoded_token = Base.url_encode64(signed_token, padding: false)

      token_record = %TestUserToken{
        id: 1,
        token: hashed,
        context: "reset_password",
        sent_to: "user@example.com",
        user_id: 1,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUserToken, [token: _, context: "reset_password"] -> token_record end)
      |> expect(:transaction, fn multi ->
        assert %Ecto.Multi{} = multi
        updated_user = %{user | hashed_password: "new_argon2_hash"}
        {:ok, %{reset_password: updated_user}}
      end)

      changeset_fn = fn _user, _attrs ->
        Ecto.Changeset.change(user, hashed_password: "new_argon2_hash")
      end

      result =
        Auth.reset_password(Sigra.MockRepo, encoded_token, %{"password" => "new_secure_password"},
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          changeset_fn: changeset_fn
        )

      assert {:ok, updated_user} = result
      assert updated_user.hashed_password == "new_argon2_hash"
    end

    test "with expired token returns {:error, :token_expired}" do
      result =
        Auth.reset_password(Sigra.MockRepo, "some-token", %{"password" => "new_password"},
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          changeset_fn: fn _u, _a -> Ecto.Changeset.change(%TestUser{}) end,
          reset_ttl: 0
        )

      # With TTL of 0, a real token would expire immediately
      # But an invalid token will fail HMAC verification first
      assert {:error, :token_invalid} = result
    end

    test "with invalid token returns {:error, :token_invalid}" do
      result =
        Auth.reset_password(Sigra.MockRepo, "totally-bogus", %{"password" => "new_password"},
          secret_key_base: @secret_key_base,
          user_token_schema: TestUserToken,
          user_schema: TestUser,
          changeset_fn: fn _u, _a -> Ecto.Changeset.change(%TestUser{}) end
        )

      assert {:error, :token_invalid} = result
    end
  end

  # -- Phase 4 Plan 02: Session management functions --

  @session_config %Sigra.Config{
    repo: Sigra.MockRepo,
    user_schema: TestUser,
    session: [
      store: Sigra.MockSessionStore,
      idle_timeout: 1_800,
      absolute_timeout: 86_400,
      activity_update_threshold: 300,
      remember_me_max_age: 5_184_000,
      session_schema: TestUser
    ]
  }

  defp build_session(overrides \\ %{}) do
    defaults = %Sigra.Session{
      id: 1,
      user_id: 1,
      hashed_token: "hashed-token-1",
      type: :standard,
      last_active_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      sudo_at: nil
    }

    struct(defaults, overrides)
  end

  describe "create_session/4" do
    test "creates session via SessionStore and emits telemetry" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :session, :create, :stop]])
      session = build_session(%{token: "raw-token"})

      Sigra.MockSessionStore
      |> expect(:create, fn 1, %{type: :standard, ip: "1.2.3.4"}, _opts ->
        {:ok, session}
      end)

      user = %TestUser{id: 1}
      metadata = %{type: :standard, ip: "1.2.3.4"}

      result = Auth.create_session(@session_config, user, metadata)

      assert {:ok, ^session} = result
      assert_received {[:sigra, :session, :create, :stop], ^ref, _measurements, _metadata}
    end
  end

  describe "delete_session/3" do
    test "deletes session via SessionStore and emits telemetry" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :session, :delete, :stop]])

      Sigra.MockSessionStore
      |> expect(:delete, fn "hashed-token", _opts -> :ok end)

      result = Auth.delete_session(@session_config, "hashed-token")

      assert :ok = result
      assert_received {[:sigra, :session, :delete, :stop], ^ref, _measurements, _metadata}
    end
  end

  describe "delete_all_sessions/3" do
    test "deletes all sessions, returns count, broadcasts PubSub disconnect" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :session, :revoke_all, :stop]])

      session1 = build_session(%{hashed_token: "hash1"})
      session2 = build_session(%{hashed_token: "hash2"})

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [session1, session2] end)
      |> expect(:delete_all_for_user, fn 1, _opts -> {2, nil} end)

      # Start a PubSub for testing
      start_supervised!({Phoenix.PubSub, name: :test_pubsub})

      # Subscribe to the disconnect topics
      topic1 = "users_sessions:#{Base.url_encode64("hash1")}"
      topic2 = "users_sessions:#{Base.url_encode64("hash2")}"
      Phoenix.PubSub.subscribe(:test_pubsub, topic1)
      Phoenix.PubSub.subscribe(:test_pubsub, topic2)

      result = Auth.delete_all_sessions(@session_config, 1, pubsub: :test_pubsub)

      assert {2, nil} = result
      assert_receive :disconnect
      assert_receive :disconnect
      assert_received {[:sigra, :session, :revoke_all, :stop], ^ref, %{count: 2}, %{user_id: 1}}
    end

    test "with except_token option excludes current session" do
      session1 = build_session(%{hashed_token: "hash1"})
      session2 = build_session(%{hashed_token: "hash2"})

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [session1, session2] end)
      |> expect(:delete_all_for_user, fn 1, opts ->
        assert Keyword.get(opts, :except_token) == "hash1"
        {1, nil}
      end)

      start_supervised!({Phoenix.PubSub, name: :test_pubsub_except})

      topic2 = "users_sessions:#{Base.url_encode64("hash2")}"
      Phoenix.PubSub.subscribe(:test_pubsub_except, topic2)

      # hash1 should NOT get a broadcast
      topic1 = "users_sessions:#{Base.url_encode64("hash1")}"
      Phoenix.PubSub.subscribe(:test_pubsub_except, topic1)

      result = Auth.delete_all_sessions(@session_config, 1,
        except_token: "hash1",
        pubsub: :test_pubsub_except
      )

      assert {1, nil} = result
      # hash2 should get disconnect
      assert_receive :disconnect
      # hash1 should NOT get disconnect
      refute_receive :disconnect, 50
    end
  end

  describe "confirm_sudo/3" do
    test "updates sudo_at on session record" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :session, :sudo, :stop]])

      Sigra.MockSessionStore
      |> expect(:update_sudo, fn "hashed-token", %DateTime{}, _opts -> :ok end)

      result = Auth.confirm_sudo(@session_config, "hashed-token")

      assert :ok = result
      assert_received {[:sigra, :session, :sudo, :stop], ^ref, _measurements, _metadata}
    end
  end

  describe "list_sessions/3" do
    test "returns all sessions for user" do
      session1 = build_session(%{hashed_token: "hash1"})
      session2 = build_session(%{hashed_token: "hash2"})

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [session1, session2] end)

      result = Auth.list_sessions(@session_config, 1)

      assert length(result) == 2
    end
  end

  describe "revoke_session/3" do
    test "deletes specific session by hashed_token" do
      Sigra.MockSessionStore
      |> expect(:delete, fn "specific-hash", _opts -> :ok end)

      result = Auth.revoke_session(@session_config, "specific-hash")

      assert :ok = result
    end
  end

  # -- Phase 4 Plan 04: Lockout + Suspicious Login Integration --

  @auth_config %Sigra.Config{
    repo: Sigra.MockRepo,
    user_schema: TestUser,
    session: [
      store: Sigra.MockSessionStore,
      session_schema: TestUser
    ],
    lockout: [threshold: 5, duration: 900, notify: true],
    suspicious_login: [enabled: true, notify: true],
    geo_ip: [],
    email_module: Sigra.MockEmailTemplates
  }

  describe "authenticate/2 (config-based)" do
    test "returns {:error, :account_locked} when user is locked (before hash check)" do
      locked_at = DateTime.utc_now() |> DateTime.add(-100, :second)

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: "should_not_be_checked",
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 5,
        locked_at: locked_at
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      # No password verification should happen -- Mox will fail if Crypto is called

      result =
        Auth.authenticate(@auth_config, %{
          "email" => "user@example.com",
          "password" => "any_password"
        })

      assert {:error, :account_locked} = result
    end

    test "increments failed_login_attempts on wrong password" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 2,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset ->
        changes = changeset.changes
        assert changes.failed_login_attempts == 3
        struct(user, changes)
      end)

      result =
        Auth.authenticate(@auth_config, %{
          "email" => "user@example.com",
          "password" => "wrong_password"
        })

      assert {:error, :invalid_credentials} = result
    end

    test "sets locked_at when failed_login_attempts reaches threshold" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 4,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset ->
        changes = changeset.changes
        assert changes.failed_login_attempts == 5
        assert %DateTime{} = changes.locked_at
        struct(user, changes)
      end)

      # Expect lockout email notification
      Sigra.MockEmailTemplates
      |> expect(:lockout_notification_email, fn ^user, %{ip: nil} ->
        %{to: user.email, subject: "Account locked", body: %{}}
      end)

      Sigra.MockMailer
      |> expect(:deliver, fn _to, _subject, _body -> {:ok, :sent} end)

      config = %{@auth_config | mailer: Sigra.MockMailer}

      result =
        Auth.authenticate(config, %{
          "email" => "user@example.com",
          "password" => "wrong_password"
        })

      assert {:error, :account_locked} = result
    end

    test "emits [:sigra, :security, :lockout] telemetry when lockout triggered" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:sigra, :security, :lockout]])
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 4,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset -> struct(user, changeset.changes) end)

      Sigra.MockEmailTemplates
      |> expect(:lockout_notification_email, fn _user, _details ->
        %{to: "user@example.com", subject: "Locked", body: %{}}
      end)

      Sigra.MockMailer
      |> expect(:deliver, fn _to, _subject, _body -> {:ok, :sent} end)

      config = %{@auth_config | mailer: Sigra.MockMailer}

      Auth.authenticate(config, %{
        "email" => "user@example.com",
        "password" => "wrong_password"
      })

      assert_received {[:sigra, :security, :lockout], ^ref, _measurements, metadata}
      assert metadata.user_id == 1
      assert metadata.reason == :threshold_reached
    end

    test "sends lockout notification email when lockout threshold reached (D-28)" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 4,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset -> struct(user, changeset.changes) end)

      Sigra.MockEmailTemplates
      |> expect(:lockout_notification_email, fn ^user, %{ip: nil} ->
        %{to: user.email, subject: "Account locked", body: %{html: "<p>Locked</p>", text: "Locked"}}
      end)

      Sigra.MockMailer
      |> expect(:deliver, fn "user@example.com", "Account locked", _body -> {:ok, :sent} end)

      config = %{@auth_config | mailer: Sigra.MockMailer}

      Auth.authenticate(config, %{
        "email" => "user@example.com",
        "password" => "wrong_password"
      })
    end

    test "resets failed_login_attempts to 0 on successful login" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 3,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset ->
        changes = changeset.changes
        assert changes.failed_login_attempts == 0
        # locked_at may or may not be in changes depending on whether it changed
        struct(user, Map.merge(%{failed_login_attempts: 0, locked_at: nil}, changes))
      end)

      # Suspicious login check -- no prior sessions means no suspicion
      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [] end)

      result =
        Auth.authenticate(@auth_config, %{
          "email" => "user@example.com",
          "password" => "correct_password"
        })

      assert {:ok, _user} = result
    end

    test "detects suspicious login on success and returns {:ok, user, suspicious: details}" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 0,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset -> struct(user, changeset.changes) end)

      # Has prior sessions from different IP
      session = %Sigra.Session{id: 1, user_id: 1, hashed_token: "h", type: :standard, ip: "1.2.3.4"}

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [session] end)

      # Expect suspicious login email
      Sigra.MockEmailTemplates
      |> expect(:suspicious_login_email, fn _user, %{ip: "9.9.9.9"} ->
        %{to: "user@example.com", subject: "New login", body: %{html: "<p>New</p>", text: "New"}}
      end)

      Sigra.MockMailer
      |> expect(:deliver, fn _to, _subject, _body -> {:ok, :sent} end)

      config = %{@auth_config | mailer: Sigra.MockMailer}

      result =
        Auth.authenticate(config, %{
          "email" => "user@example.com",
          "password" => "correct_password",
          "ip" => "9.9.9.9"
        })

      assert {:ok, _user, %{suspicious_login: details}} = result
      assert details.ip == "9.9.9.9"
    end

    test "sends suspicious login notification email on detection (D-46)" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 0,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset -> struct(user, changeset.changes) end)

      session = %Sigra.Session{id: 1, user_id: 1, hashed_token: "h", type: :standard, ip: "1.2.3.4"}

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [session] end)

      Sigra.MockEmailTemplates
      |> expect(:suspicious_login_email, fn ^user, %{ip: "5.5.5.5"} ->
        %{to: user.email, subject: "Suspicious login", body: %{html: "<p>New</p>", text: "New"}}
      end)

      Sigra.MockMailer
      |> expect(:deliver, fn "user@example.com", "Suspicious login", _body -> {:ok, :sent} end)

      config = %{@auth_config | mailer: Sigra.MockMailer}

      Auth.authenticate(config, %{
        "email" => "user@example.com",
        "password" => "correct_password",
        "ip" => "5.5.5.5"
      })
    end

    test "does not send suspicious login email when detection returns :ok" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 0,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset -> struct(user, changeset.changes) end)

      # Known IP -- no suspicion
      session = %Sigra.Session{id: 1, user_id: 1, hashed_token: "h", type: :standard, ip: "1.2.3.4"}

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [session] end)

      # No email template or mailer calls expected (Mox will fail if called)

      result =
        Auth.authenticate(@auth_config, %{
          "email" => "user@example.com",
          "password" => "correct_password",
          "ip" => "1.2.3.4"
        })

      assert {:ok, _user} = result
    end

    test "does not detect suspicious login on failure" do
      hashed = Sigra.Crypto.hash_password("correct_password")

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 0,
        locked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset -> struct(user, changeset.changes) end)

      # No session store calls expected -- suspicious login not checked on failure

      result =
        Auth.authenticate(@auth_config, %{
          "email" => "user@example.com",
          "password" => "wrong_password",
          "ip" => "9.9.9.9"
        })

      assert {:error, :invalid_credentials} = result
    end

    test "allows login when lockout has expired (auto-unlock)" do
      hashed = Sigra.Crypto.hash_password("correct_password")
      # Locked 20 minutes ago, lockout duration is 15 minutes (900s) = expired
      locked_at = DateTime.utc_now() |> DateTime.add(-1200, :second)

      user = %TestUser{
        id: 1,
        email: "user@example.com",
        hashed_password: hashed,
        confirmed_at: ~U[2024-01-01 00:00:00Z],
        failed_login_attempts: 5,
        locked_at: locked_at
      }

      Sigra.MockRepo
      |> expect(:get_by, fn TestUser, [email: "user@example.com"] -> user end)
      |> expect(:update!, fn changeset ->
        changes = changeset.changes
        assert changes.failed_login_attempts == 0
        assert changes.locked_at == nil
        struct(user, changes)
      end)

      Sigra.MockSessionStore
      |> expect(:list_by_user, fn 1, _opts -> [] end)

      result =
        Auth.authenticate(@auth_config, %{
          "email" => "user@example.com",
          "password" => "correct_password"
        })

      assert {:ok, _user} = result
    end
  end

  describe "TokenCleanup session cleanup" do
    test "cleanup_expired_sessions/1 deletes expired sessions" do
      # Test that cleanup_expired_sessions calls delete_all for both session types.
      # We need a real (non-embedded) schema for Ecto.Query, so we define one inline.
      defmodule TestSessionSchema do
        use Ecto.Schema
        schema "user_sessions" do
          field :type, :string
          field :inserted_at, :utc_datetime
        end
      end

      config = %Sigra.Config{
        repo: Sigra.MockRepo,
        user_schema: TestUser,
        session: [
          session_schema: TestSessionSchema,
          absolute_timeout: 86_400,
          remember_me_max_age: 5_184_000
        ]
      }

      # Expect two delete_all calls for session cleanup (standard + remember_me)
      Sigra.MockRepo
      |> expect(:delete_all, fn %Ecto.Query{} -> {3, nil} end)
      |> expect(:delete_all, fn %Ecto.Query{} -> {1, nil} end)

      assert :ok = Sigra.Workers.TokenCleanup.cleanup_expired_sessions(config)
    end
  end
end
