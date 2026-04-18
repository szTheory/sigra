defmodule Example.Accounts.EmailsLifecycleHtmlTest do
  @moduledoc """
  Shift-left SEED-001 item 2 (lifecycle mail): HTML structure on account-lifecycle
  templates without per-client manual passes. Complements `EmailsSecurityHtmlTest`.
  """
  use Example.DataCase, async: true

  alias Example.Accounts.Emails
  alias Example.Accounts.User

  defp user do
    %User{email: "lifecycle-html@example.test"}
  end

  describe "confirmation_email/3" do
    test "includes code block, CTA, and footer" do
      html = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456").html_body

      assert html =~ "Confirm email address"
      assert html =~ "1 2 3 4 5 6"
      assert html =~ "https://example.test/confirm/tok"
      assert html =~ "role=\"link\""
      assert html =~ "You're receiving this email because you have an account with Example."
    end
  end

  describe "reset_password_email/2" do
    test "includes reset CTA and raw link" do
      html = Emails.reset_password_email(user(), "https://example.test/reset/tok").html_body

      assert html =~ "Reset password"
      assert html =~ "https://example.test/reset/tok"
      assert html =~ "role=\"link\""
    end
  end

  describe "magic_link_email/2" do
    test "includes magic link CTA" do
      html = Emails.magic_link_email(user(), "https://example.test/magic/tok").html_body

      assert html =~ "Log in to Example"
      assert html =~ "https://example.test/magic/tok"
      assert html =~ "role=\"link\""
    end
  end

  describe "oauth_reset_email/2" do
    test "includes provider-specific copy and login CTA" do
      html = Emails.oauth_reset_email(user(), :google).html_body

      assert html =~ "Google"
      assert html =~ "/users/log_in"
      assert html =~ "role=\"link\""
    end
  end

  describe "mfa_enabled_email/2" do
    test "includes headline and password CTA" do
      html = Emails.mfa_enabled_email(user()).html_body

      assert html =~ "Two-Factor Authentication Enabled"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"link\""
    end
  end

  describe "mfa_disabled_email/2" do
    test "includes headline and settings CTA" do
      html = Emails.mfa_disabled_email(user()).html_body

      assert html =~ "Two-Factor Authentication Disabled"
      assert html =~ "/users/settings"
      assert html =~ "role=\"link\""
    end
  end

  describe "backup_code_used_email/2" do
    test "includes usage headline, remaining count, and optional low-code warning" do
      html = Emails.backup_code_used_email(user(), remaining: 1).html_body

      assert html =~ "Backup Code Used"
      assert html =~ "1 of 8 backup codes remaining"
      assert html =~ "Generate new backup codes"
      assert html =~ "running low on backup codes"
    end
  end

  describe "mfa_lockout_email/2" do
    test "includes lockout headline and password CTA" do
      html = Emails.mfa_lockout_email(user()).html_body

      assert html =~ "Verification Temporarily Locked"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"link\""
    end
  end

  describe "email change + deletion lifecycle" do
    test "email_change_confirmation_email/3" do
      html = Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c").html_body

      assert html =~ "Confirm Email Change"
      assert html =~ "https://ex.test/c"
      assert html =~ "role=\"link\""
    end

    test "email_change_notification_email/3" do
      html =
        Emails.email_change_notification_email(user(), "new@example.test", "https://ex.test/cancel").html_body

      assert html =~ "Email Change Requested"
      assert html =~ "Cancel email change"
      assert html =~ "https://ex.test/cancel"
    end

    test "email_changed_email/1" do
      html = Emails.email_changed_email(user()).html_body

      assert html =~ "Email Updated"
      assert html =~ "/users/reset-password"
    end

    test "deletion_scheduled_email/3" do
      html =
        Emails.deletion_scheduled_email(user(), ~D[2026-12-01], "https://ex.test/undelete").html_body

      assert html =~ "Account Deletion Scheduled"
      assert html =~ "Cancel account deletion"
      assert html =~ "December 01, 2026"
    end

    test "deletion_cancelled_email/2" do
      html = Emails.deletion_cancelled_email(user(), "https://ex.test/in").html_body

      assert html =~ "Deletion Cancelled"
      assert html =~ "Log in to your account"
    end

    test "deletion_finalized_email/1" do
      html = Emails.deletion_finalized_email("gone@example.test").html_body

      assert html =~ "Account Deleted"
    end
  end
end
