defmodule Sigra.OAuth.AuthIntegrationTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.Auth
  alias Sigra.Error.OAuthError

  describe "Auth.register_oauth/4" do
    test "delegates to Callback.process_callback and registers new user" do
      config = build_config(repo: Sigra.Test.CallbackRepo.NewUser)

      assert {:ok, :registered, user, session_meta} =
               Auth.register_oauth(config, :google, mock_user_info(), mock_token())

      assert user.email == "oauth@example.com"
      assert session_meta.auth_method == :oauth
      assert session_meta.provider == :google
    end

    test "returns no_email error for missing email" do
      config = build_config()

      assert {:error, %OAuthError{error_code: :no_email}} =
               Auth.register_oauth(config, :google, mock_user_info(%{"email" => nil}), mock_token())
    end
  end

  describe "Auth.login_oauth/4" do
    test "delegates to Callback.process_callback and logs in existing user" do
      config = build_config(repo: Sigra.Test.CallbackRepo.ExistingIdentity)

      assert {:ok, :logged_in, user, _session} =
               Auth.login_oauth(config, :google, mock_user_info(), mock_token())

      assert user.id == 42
    end

    test "returns link_confirmation_required for email match" do
      config = build_config(repo: Sigra.Test.CallbackRepo.EmailMatch)

      assert {:link_confirmation_required, info} =
               Auth.login_oauth(config, :google, mock_user_info(), mock_token())

      assert info.provider == :google
    end
  end

  describe "Auth.link_provider/4" do
    test "delegates to OAuth.link_provider" do
      config = build_config()
      user = %{id: 1, email: "user@example.com"}

      # MockRepo returns existing identity for google+user_id
      assert {:error, :already_linked} =
               Auth.link_provider(config, user, %{
                 provider: :google,
                 provider_uid: "uid_123",
                 user_info: mock_user_info(),
                 token: mock_token()
               }, session: %Sigra.Session{sudo_at: DateTime.utc_now()})
    end
  end

  describe "Auth.unlink_provider/4" do
    test "delegates to OAuth.unlink_provider" do
      config = build_config()
      user = %{id: 1, email: "user@example.com", hashed_password: nil}

      assert {:error, :last_provider} =
               Auth.unlink_provider(config, user, :google, session: %Sigra.Session{sudo_at: DateTime.utc_now()})
    end
  end

  describe "Telemetry OAuth events" do
    test "oauth_events/0 returns 7 event names" do
      events = Sigra.Telemetry.oauth_events()
      assert length(events) == 7
      assert [:sigra, :oauth, :authorize, :stop] in events
      assert [:sigra, :oauth, :callback, :stop] in events
      assert [:sigra, :oauth, :link, :stop] in events
      assert [:sigra, :oauth, :unlink, :stop] in events
      assert [:sigra, :oauth, :refresh, :stop] in events
      assert [:sigra, :oauth, :register, :stop] in events
      assert [:sigra, :oauth, :login, :stop] in events
    end

    test "telemetry events fire for OAuth callback" do
      ref = make_ref()
      parent = self()

      handler = fn event, _measurements, _metadata, _config ->
        send(parent, {ref, event})
      end

      :telemetry.attach("test-oauth-login", [:sigra, :oauth, :login, :stop], handler, nil)

      config = build_config(repo: Sigra.Test.CallbackRepo.ExistingIdentity)
      Auth.login_oauth(config, :google, mock_user_info(), mock_token())

      assert_receive {^ref, [:sigra, :oauth, :login, :stop]}, 1000

      :telemetry.detach("test-oauth-login")
    end

    test "telemetry events fire for OAuth registration" do
      ref = make_ref()
      parent = self()

      handler = fn event, _measurements, _metadata, _config ->
        send(parent, {ref, event})
      end

      :telemetry.attach("test-oauth-register", [:sigra, :oauth, :register, :stop], handler, nil)

      config = build_config(repo: Sigra.Test.CallbackRepo.NewUser)
      Auth.register_oauth(config, :google, mock_user_info(), mock_token())

      assert_receive {^ref, [:sigra, :oauth, :register, :stop]}, 1000

      :telemetry.detach("test-oauth-register")
    end
  end

  describe "Testing helpers" do
    test "mock_oauth_callback/1 returns expected shape" do
      result = Sigra.Testing.mock_oauth_callback()

      assert result.provider == :google
      assert result.user_info["email"] == "oauth@example.com"
      assert result.user_info["sub"] == "provider_123"
      assert is_binary(result.token["access_token"])
    end

    test "mock_oauth_callback/1 accepts overrides" do
      result = Sigra.Testing.mock_oauth_callback(provider: :github, email: "gh@example.com")

      assert result.provider == :github
      assert result.user_info["email"] == "gh@example.com"
    end

    test "create_identity/1 returns Identity struct" do
      identity = Sigra.Testing.create_identity(user_id: 42)

      assert %Sigra.Identity{} = identity
      assert identity.user_id == 42
      assert identity.provider == "google"
      assert identity.provider_email == "oauth@example.com"
    end

    test "create_identity/1 accepts overrides" do
      identity = Sigra.Testing.create_identity(user_id: 1, provider: "github", email: "gh@example.com")

      assert identity.provider == "github"
      assert identity.provider_email == "gh@example.com"
    end

    test "oauth_user_fixture/1 returns user and identity" do
      fixture = Sigra.Testing.oauth_user_fixture(email: "test@example.com")

      assert fixture.user.email == "test@example.com"
      assert fixture.user.confirmed_at != nil
      assert fixture.user.hashed_password == nil
      assert %Sigra.Identity{} = fixture.identity
      assert fixture.identity.user_id == fixture.user.id
    end
  end

  # -- Helpers --

  defp build_config(overrides \\ []) do
    %{
      repo: Keyword.get(overrides, :repo, Sigra.Test.MockRepo),
      user_schema: Sigra.Test.MockUser,
      secret_key_base: String.duplicate("c", 64),
      oauth: [
        enabled: true,
        providers: [google: [client_id: "id", client_secret: "secret"]],
        session_type: :remember_me,
        link_confirmation: :required,
        trust_provider_email: true
      ],
      session: [
        session_schema: Sigra.Test.MockSession,
        store: Sigra.Test.MockSessionStore
      ],
      identity_schema: Sigra.Test.MockIdentity
    }
  end
end
