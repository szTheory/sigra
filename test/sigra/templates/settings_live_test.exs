defmodule Sigra.Templates.SettingsLiveTest do
  @moduledoc """
  Tests that account settings and reactivation EEx generator templates
  contain expected content. These validate the raw template files, not
  the generated output (which depends on host app bindings).
  """

  use ExUnit.Case, async: true

  @templates_dir Path.expand("../../../priv/templates/sigra.install", __DIR__)

  describe "settings_live.ex template" do
    setup do
      content = File.read!(Path.join(@templates_dir, "settings_live.ex"))
      %{content: content}
    end

    test "defines SettingsLive module", %{content: content} do
      assert content =~ "SettingsLive"
    end

    test "contains Account Settings heading", %{content: content} do
      assert content =~ "Account Settings"
    end

    test "contains page subtitle", %{content: content} do
      assert content =~ "Manage your email, password, and account."
    end

    test "contains email section with id", %{content: content} do
      assert content =~ ~s(id="email")
    end

    test "contains password section with id", %{content: content} do
      assert content =~ ~s(id="password")
    end

    test "contains deletion section with id", %{content: content} do
      assert content =~ ~s(id="delete")
    end

    test "deletion section has danger zone styling", %{content: content} do
      assert content =~ "border-l-4 border-red-500"
    end

    test "contains pending email change display", %{content: content} do
      assert content =~ "pending_email"
      assert content =~ "awaiting confirmation"
    end

    test "contains cancel email change button", %{content: content} do
      assert content =~ "cancel_email_change"
      assert content =~ "Cancel email change"
    end

    test "contains request email change form", %{content: content} do
      assert content =~ "request_email_change"
      assert content =~ "Update email"
    end

    test "contains change password form", %{content: content} do
      assert content =~ "change_password"
      assert content =~ "Change password"
    end

    test "contains set password variant for OAuth-only users", %{content: content} do
      assert content =~ "set_password"
      assert content =~ "Set a password"
    end

    test "contains OAuth-only detection", %{content: content} do
      assert content =~ "has_password?"
    end

    test "contains force password change banner", %{content: content} do
      assert content =~ "force_password_change?"
      assert content =~ "must_change_password"
      assert content =~ "You must change your password"
    end

    test "contains deletion confirmation with data-confirm", %{content: content} do
      assert content =~ "confirm_delete"
      assert content =~ "data-confirm"
      assert content =~ "Delete my account"
    end

    test "contains scheduled deletion status display", %{content: content} do
      assert content =~ "scheduled for deletion"
      assert content =~ "scheduled_deletion_date"
    end

    test "contains cancel deletion button", %{content: content} do
      assert content =~ "cancel_deletion"
      assert content =~ "Cancel deletion"
    end

    test "contains email confirmation via handle_params", %{content: content} do
      assert content =~ "confirm_email_change"
      assert content =~ ":confirm_email"
    end

    test "uses max-w-2xl layout matching other settings pages", %{content: content} do
      assert content =~ "mx-auto max-w-2xl"
    end

    test "contains flash messages matching UI-SPEC", %{content: content} do
      assert content =~ "Your password has been changed"
      assert content =~ "Account deletion cancelled"
      assert content =~ "Password set successfully"
    end

    test "deletion section has red CTA button", %{content: content} do
      assert content =~ "bg-red-600 hover:bg-red-700"
    end
  end

  describe "reactivation_live.ex template" do
    setup do
      content = File.read!(Path.join(@templates_dir, "reactivation_live.ex"))
      %{content: content}
    end

    test "defines ReactivationLive module", %{content: content} do
      assert content =~ "ReactivationLive"
    end

    test "contains scheduled for deletion heading", %{content: content} do
      assert content =~ "Your account is scheduled for deletion"
    end

    test "contains reactivation CTA", %{content: content} do
      assert content =~ "Cancel deletion and keep my account"
    end

    test "contains sign out option", %{content: content} do
      assert content =~ "I understand, sign me out"
    end

    test "contains cancel_deletion event handler", %{content: content} do
      assert content =~ "cancel_deletion"
    end

    test "redirects to settings after cancellation", %{content: content} do
      assert content =~ ~s(/users/settings)
    end

    test "contains scheduled deletion date display", %{content: content} do
      assert content =~ "scheduled_deletion_date"
    end

    test "links to log out", %{content: content} do
      assert content =~ ~s(/users/log_out)
    end

    test "uses max-w-md layout", %{content: content} do
      assert content =~ "mx-auto max-w-md"
    end
  end

  describe "user_auth.ex lifecycle plugs" do
    setup do
      content = File.read!(Path.join(@templates_dir, "user_auth.ex"))
      %{content: content}
    end

    test "contains require_password_unchanged plug", %{content: content} do
      assert content =~ "def require_password_unchanged(conn, _opts)"
    end

    test "require_password_unchanged checks must_change_password", %{content: content} do
      assert content =~ "must_change_password"
    end

    test "require_password_unchanged redirects to settings#password", %{content: content} do
      assert content =~ ~s(/users/settings#password)
    end

    test "contains check_account_active plug", %{content: content} do
      assert content =~ "def check_account_active(conn, _opts)"
    end

    test "check_account_active checks deleted_at", %{content: content} do
      assert content =~ "deleted_at"
    end

    test "check_account_active redirects to reactivation", %{content: content} do
      assert content =~ ~s(/users/reactivation)
    end
  end

  describe "auth_fixtures.ex lifecycle fixtures" do
    setup do
      content = File.read!(Path.join(@templates_dir, "auth_fixtures.ex"))
      %{content: content}
    end

    test "contains scheduled_deletion_fixture", %{content: content} do
      assert content =~ "def scheduled_deletion_fixture"
    end

    test "contains force_password_change_fixture", %{content: content} do
      assert content =~ "def force_password_change_fixture"
    end
  end
end
