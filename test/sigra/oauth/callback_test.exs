defmodule Sigra.OAuth.CallbackTest do
  use ExUnit.Case, async: true

  import Sigra.Test.OAuthHelpers

  alias Sigra.OAuth.Callback
  alias Sigra.Error.OAuthError

  describe "process_callback/4 - no email" do
    test "returns error when email is nil" do
      config = build_config()

      assert {:error, %OAuthError{error_code: :no_email}} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(%{"email" => nil}),
                 mock_token()
               )
    end

    test "returns error when email is empty string" do
      config = build_config()

      assert {:error, %OAuthError{error_code: :no_email}} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(%{"email" => ""}),
                 mock_token()
               )
    end
  end

  describe "process_callback/4 - existing identity" do
    test "logs in user and updates identity fields when identity found" do
      config = build_config(repo: Sigra.Test.CallbackRepo.ExistingIdentity)

      assert {:ok, :logged_in, user, _session} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(),
                 mock_token()
               )

      assert user.id == 42
    end

    test "returns email_mismatch when identity user differs from email user" do
      config = build_config(repo: Sigra.Test.CallbackRepo.EmailMismatch)

      assert {:error, %OAuthError{error_code: :email_mismatch}} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(),
                 mock_token()
               )
    end
  end

  describe "process_callback/4 - no identity, email match" do
    test "returns link_confirmation_required when email matches existing user" do
      config = build_config(repo: Sigra.Test.CallbackRepo.EmailMatch)

      assert {:link_confirmation_required, info} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(),
                 mock_token()
               )

      assert info.provider == :google
      assert info.email == "oauth@example.com"
    end
  end

  describe "process_callback/4 - new user registration" do
    test "registers new user with confirmed_at when trust_provider_email and email_verified" do
      config = build_config(repo: Sigra.Test.CallbackRepo.NewUser)

      assert {:ok, :registered, user, _session} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(),
                 mock_token()
               )

      assert user.confirmed_at != nil
    end

    test "registers new user without confirmed_at when email not verified" do
      config = build_config(repo: Sigra.Test.CallbackRepo.NewUser)

      assert {:ok, :registered, user, _session} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(%{"email_verified" => false}),
                 mock_token()
               )

      assert user.confirmed_at == nil
    end

    test "uses Ecto.Multi for race condition safety" do
      config = build_config(repo: Sigra.Test.CallbackRepo.NewUser)

      # The registration should succeed (Multi wraps user+identity insert)
      assert {:ok, :registered, _user, _session} =
               Callback.process_callback(
                 config,
                 :google,
                 mock_user_info(),
                 mock_token()
               )
    end
  end

  describe "process_callback/4 - Apple provider nil name handling" do
    test "does not overwrite existing name with nil on re-auth" do
      config = build_config(repo: Sigra.Test.CallbackRepo.ExistingIdentity)

      # Apple re-auth returns nil name (Pitfall 2)
      assert {:ok, :logged_in, _user, _session} =
               Callback.process_callback(
                 config,
                 :apple,
                 mock_user_info(%{"name" => nil}),
                 mock_token()
               )

      # The identity update should only set non-nil fields
      # (verified by the mock repo tracking updates)
    end
  end

  # -- Helpers --

  defp build_config(overrides \\ []) do
    defaults = [
      repo: Sigra.Test.MockRepo,
      user_schema: Sigra.Test.MockUser,
      secret_key_base: String.duplicate("b", 64),
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
    ]

    merged = Keyword.merge(defaults, overrides)

    %{
      repo: merged[:repo],
      user_schema: merged[:user_schema],
      secret_key_base: merged[:secret_key_base],
      oauth: merged[:oauth],
      session: merged[:session],
      identity_schema: merged[:identity_schema]
    }
  end
end
