defmodule Sigra.Templates.SessionTemplatesTest do
  @moduledoc """
  Tests that session-related EEx generator templates compile and contain
  expected content. These validate the raw template files, not the
  generated output (which depends on host app bindings).
  """

  use ExUnit.Case, async: true

  @templates_dir Path.expand("../../../priv/templates/sigra.install", __DIR__)

  describe "migration template" do
    setup do
      content = File.read!(Path.join(@templates_dir, "migration.exs"))
      %{content: content}
    end

    test "contains user_sessions table creation", %{content: content} do
      assert content =~ "create table(:user_sessions"
    end

    test "contains hashed_token column", %{content: content} do
      assert content =~ ":hashed_token, :binary, null: false"
    end

    test "contains type column with default", %{content: content} do
      assert content =~ ~s(:type, :string, null: false, default: "standard")
    end

    test "contains ip column", %{content: content} do
      assert content =~ ":ip, :string"
    end

    test "contains user_agent column", %{content: content} do
      assert content =~ ":user_agent, :text"
    end

    test "contains geo columns", %{content: content} do
      assert content =~ ":geo_city, :string"
      assert content =~ ":geo_country_code, :string, size: 2"
    end

    test "contains timestamp columns", %{content: content} do
      assert content =~ ":last_active_at, :utc_datetime_usec, null: false"
      assert content =~ ":sudo_at, :utc_datetime_usec"
    end

    test "contains unique index on hashed_token", %{content: content} do
      assert content =~ "unique_index(:user_sessions, [:hashed_token])"
    end

    test "contains composite index on user_id and type", %{content: content} do
      assert content =~ "index(:user_sessions, [:user_id, :type])"
    end

    test "contains index on inserted_at", %{content: content} do
      assert content =~ "index(:user_sessions, [:inserted_at])"
    end

    test "includes user_sessions in all three adapter sections", %{content: content} do
      # Each adapter section should have user_sessions
      sections = String.split(content, "create table(:user_sessions")
      # Original + 3 adapter sections = 4 parts
      assert length(sections) == 4, "Expected user_sessions in postgres, mysql, and sqlite sections"
    end
  end

  describe "user_session schema template" do
    setup do
      content = File.read!(Path.join(@templates_dir, "user_session.ex"))
      %{content: content}
    end

    test "defines schema on user_sessions table", %{content: content} do
      assert content =~ ~s(schema "user_sessions")
    end

    test "contains hashed_token field", %{content: content} do
      assert content =~ "field :hashed_token, :binary"
    end

    test "contains type field with default", %{content: content} do
      assert content =~ ~s(field :type, :string, default: "standard")
    end

    test "contains session metadata fields", %{content: content} do
      assert content =~ "field :ip, :string"
      assert content =~ "field :user_agent, :string"
      assert content =~ "field :geo_city, :string"
      assert content =~ "field :geo_country_code, :string"
    end

    test "contains temporal fields", %{content: content} do
      assert content =~ "field :last_active_at, :utc_datetime_usec"
      assert content =~ "field :sudo_at, :utc_datetime_usec"
    end

    test "belongs to user", %{content: content} do
      assert content =~ "belongs_to :user"
    end

    test "uses usec timestamps without updated_at", %{content: content} do
      assert content =~ "timestamps(type: :utc_datetime_usec, updated_at: false)"
    end
  end

  describe "auth context extensions" do
    setup do
      content = File.read!(Path.join(@templates_dir, "auth.ex"))
      %{content: content}
    end

    test "contains list_sessions function", %{content: content} do
      assert content =~ "def list_sessions("
    end

    test "contains revoke_session function", %{content: content} do
      assert content =~ "def revoke_session("
    end

    test "contains revoke_all_sessions function", %{content: content} do
      assert content =~ "def revoke_all_sessions("
    end

    test "contains confirm_sudo function", %{content: content} do
      assert content =~ "def confirm_sudo("
    end

    test "contains locked? function", %{content: content} do
      assert content =~ "Sigra.Lockout.locked?"
    end

    test "contains lock_status function", %{content: content} do
      assert content =~ "def lock_status("
    end

    test "contains sigra_config helper", %{content: content} do
      assert content =~ "def sigra_config"
    end

    test "delegates to Sigra.Auth library functions", %{content: content} do
      assert content =~ "Sigra.Auth.list_sessions"
      assert content =~ "Sigra.Auth.revoke_session"
      assert content =~ "Sigra.Auth.delete_all_sessions"
      assert content =~ "Sigra.Auth.confirm_sudo"
    end
  end

  describe "sudo controller template" do
    setup do
      content = File.read!(Path.join(@templates_dir, "sudo_controller.ex"))
      %{content: content}
    end

    test "defines SudoController module", %{content: content} do
      assert content =~ "SudoController"
    end

    test "uses Sigra.Crypto.verify_password", %{content: content} do
      assert content =~ "Sigra.Crypto.verify_password"
    end

    test "calls confirm_sudo on success", %{content: content} do
      assert content =~ "confirm_sudo"
    end

    test "handles return_to parameter", %{content: content} do
      assert content =~ "return_to"
    end

    test "shows error flash on wrong password", %{content: content} do
      assert content =~ "Incorrect password. Please try again."
    end
  end

  describe "sudo HTML template" do
    setup do
      content = File.read!(Path.join(@templates_dir, "sudo_html.ex"))
      %{content: content}
    end

    test "contains heading per UI-SPEC", %{content: content} do
      assert content =~ "Confirm your password"
    end

    test "contains subtitle per UI-SPEC", %{content: content} do
      assert content =~ "For your security, please re-enter your password to continue."
    end

    test "uses max-w-sm layout", %{content: content} do
      assert content =~ "mx-auto max-w-sm"
    end

    test "has password autocomplete", %{content: content} do
      assert content =~ ~s(autocomplete="current-password")
    end

    test "has confirm password button", %{content: content} do
      assert content =~ "Confirm password"
    end

    test "has go back link", %{content: content} do
      assert content =~ "Go back"
    end
  end

  describe "email templates" do
    setup do
      content = File.read!(Path.join(@templates_dir, "emails.ex"))
      %{content: content}
    end

    test "contains suspicious_login_email function", %{content: content} do
      assert content =~ "def suspicious_login_email("
    end

    test "contains lockout_notification_email function", %{content: content} do
      assert content =~ "def lockout_notification_email("
    end

    test "suspicious login has correct subject", %{content: content} do
      assert content =~ "New sign-in to your account"
    end

    test "lockout has correct subject", %{content: content} do
      assert content =~ "Your account has been temporarily locked"
    end

    test "suspicious login has secure your account CTA", %{content: content} do
      assert content =~ "Not you? Secure your account"
    end

    test "lockout has change password CTA", %{content: content} do
      assert content =~ "Change your password"
    end

    test "suspicious login includes detail fields", %{content: content} do
      assert content =~ "IP address:"
      assert content =~ "Location:"
      assert content =~ "Device:"
      assert content =~ "Time:"
    end

    test "lockout includes lockout duration text", %{content: content} do
      assert content =~ "temporarily locked for 15 minutes"
    end

    test "security emails use security footer", %{content: content} do
      assert content =~ "security_footer_text"
    end
  end

  describe "user_auth cookie options" do
    setup do
      content = File.read!(Path.join(@templates_dir, "user_auth.ex"))
      %{content: content}
    end

    test "remember-me max age is 60 days", %{content: content} do
      assert content =~ "60 * 60 * 24 * 60"
    end

    test "remember-me has same_site Lax", %{content: content} do
      assert content =~ ~s(same_site: "Lax")
    end

    test "remember-me has http_only", %{content: content} do
      assert content =~ "http_only: true"
    end

    test "remember-me has secure flag", %{content: content} do
      # Phase 10 D-09: remember_me_options is resolved at runtime; the :secure
      # flag is injected via Keyword.put. Mix.env/0 is guarded with
      # function_exported?/3 so the template is release-safe (mix is not
      # loaded inside a production release). See REVIEW CR-01.
      assert content =~ "function_exported?(Mix, :env, 0)"
      assert content =~ ":secure, env == :prod"
    end
  end
end
