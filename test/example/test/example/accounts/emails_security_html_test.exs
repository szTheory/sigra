defmodule Example.Accounts.EmailsSecurityHtmlTest do
  @moduledoc """
  Shift-left SEED-001 mail items (1–2): assert HTML structure and CTAs on
  security-sensitive templates without Gmail/Outlook/Apple manual passes.
  """
  use Example.DataCase, async: true

  alias Example.Accounts.Emails
  alias Example.Accounts.User

  defp sample_user do
    %User{email: "security-html-contract@example.test"}
  end

  defp sample_security_details do
    %{
      ip: "203.0.113.7",
      device: "TestBrowser/1.0",
      geo_city: "Exampleton",
      geo_country_code: "ZZ",
      time: ~U[2026-04-17 12:00:00Z]
    }
  end

  describe "suspicious_login_email/2" do
    test "html includes headline, IP/location/device block, CTA to reset password, layout footer" do
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      html = email.html_body

      assert html =~ "New Sign-In Detected"
      assert html =~ "203.0.113.7"
      assert html =~ "Exampleton"
      assert html =~ "TestBrowser"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"presentation\""
      assert html =~ "role=\"link\""
      assert html =~ "You're receiving this email because you have an account with Example."
    end
  end

  describe "lockout_notification_email/2" do
    test "html includes lockout headline, body copy, password CTA, layout footer" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      html = email.html_body

      assert html =~ "Account Locked"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"link\""
      assert html =~ "You're receiving this email because you have an account with Example."
    end
  end

  describe "password_changed_email/2" do
    test "html includes change headline, security context block, reset CTA, layout footer" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      html = email.html_body

      assert html =~ "Password Changed"
      assert html =~ "203.0.113.7"
      assert html =~ "/users/reset-password"
      assert html =~ "If this wasn't you, reset your password immediately."
      assert html =~ "You're receiving this email because you have an account with Example."
    end
  end
end
