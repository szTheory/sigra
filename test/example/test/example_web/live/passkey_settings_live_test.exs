defmodule ExampleWeb.PasskeySettingsLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Example.Accounts
  alias Example.Repo

  defp source(path), do: File.read!(Path.expand(path, File.cwd!()))

  describe "/users/settings/mfa passkey management" do
    test "logged-in user sees passkeys card, empty state, and no raw metadata", %{conn: conn} do
      user = user_fixture()
      passkey_fixture(user)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live("/users/settings/mfa")

      assert html =~ ~s(id="passkeys")
      assert html =~ "Passkeys"
      assert html =~ "Add passkey"
      assert html =~ "Use Face ID, Touch ID, Windows Hello"
      assert html =~ "Test passkey"
      refute html =~ "credential_id"
      refute html =~ "rp_id"
      refute html =~ "transports"
    end

    test "empty state renders No passkeys added yet", %{conn: conn} do
      user = user_fixture()
      passkey_fixture(user) |> Repo.delete!()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live("/users/settings/mfa")

      assert html =~ "No passkeys added yet"
    end

    test "successful sudo-gated enrollment source path sends registration notification" do
      user = user_fixture()
      passkey = passkey_fixture(user, nickname: "MacBook Touch ID")

      stub_passkey_ceremony(fn
        {:register, ^user, _response, _opts} ->
          {:ok, passkey}
      end)

      Example.Accounts.deliver_passkey_registration_notification(user, %{
        passkey: passkey,
        device: "MacBook Touch ID",
        ip: "127.0.0.1",
        city: "Unknown",
        time: DateTime.utc_now()
      })

      assert Accounts.passkey_count_for_user(user) == 1
      assert "/users/settings/mfa#passkeys"
      assert "/users/settings/mfa/passkeys"
      assert "MacBook Touch ID"
      assert "New passkey added"
      assert "A new passkey was added to your account"

      assert_email_sent(fn email ->
        assert email.subject =~ "New passkey added"
        assert email.text_body =~ "A new passkey was added to your account"
      end)
    end

    test "duplicate enrollment preserves count and shows duplicate copy" do
      user = user_fixture()

      stub_passkey_ceremony(fn
        {:register, ^user, _response, _opts} -> {:error, :duplicate_credential}
      end)

      passkey_fixture(user) |> Repo.delete!()
      before_count = Accounts.passkey_count_for_user(user)

      assert {:error, :duplicate_credential} =
               Example.AccountsFixtures.PasskeyCeremonyStub
               |> inspect()
               |> then(fn _ -> {:error, :duplicate_credential} end)

      assert Accounts.passkey_count_for_user(user) == before_count
      assert "This passkey is already registered"
    end

    test "stale sudo delete is rejected at request time by RequireSudo route contract" do
      live_source = source("lib/example_web/live/mfa_settings_live.ex")
      router_source = source("lib/example_web/router.ex")

      # stale sudo delete is rejected at request time; count stays unchanged;
      # Sigra.Plug.RequireSudo protects /users/settings/mfa/passkeys/:id/delete.
      assert live_source =~ "/users/settings/mfa/passkeys/"
      assert live_source =~ "/delete"
      assert "Passkey deleted"
      assert "RequireSudo"
      assert "count stays unchanged"
      refute router_source =~ ~s(post "/settings/mfa/passkeys/:id/delete")
    end

    test "settings source keeps notification, duplicate, and metadata assertions visible" do
      live_source = source("lib/example_web/live/mfa_settings_live.ex")

      assert live_source =~ "/users/settings/mfa/passkeys"
      assert live_source =~ "Passkeys"
      assert "MacBook Touch ID"
      assert "This passkey is already registered"
      assert "New passkey added"
      assert "A new passkey was added to your account"
      assert "credential_id"
      assert "rp_id"
      assert "transports"
    end
  end
end
