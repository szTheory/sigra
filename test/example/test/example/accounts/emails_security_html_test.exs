defmodule Example.Accounts.EmailsSecurityHtmlTest do
  @moduledoc """
  Phase 04 security template coverage — G1-G9 rubric per D-86-05.

  Extends the original shift-left SEED-001 structural assertions with
  Phase 86 locked gaps: contrast, byte budget, multipart parity, recipient
  correctness, XSS escaping, Outlook deny-list, image tripwire, default-arg
  DateTime branches, and caniemail CSS lint.

  All fixtures are frozen per D-86-04:
    - time: ~U[2026-04-17 12:00:00Z]
    - ip: "203.0.113.7" (RFC 5737 documentation address)
    - geo_city: "Exampleton", geo_country_code: "ZZ"
    - device: "TestBrowser/1.0"
    - user email: "security-html-contract@example.test"
  """
  use Example.DataCase, async: true

  import Example.EmailAssertions

  alias Example.Accounts.Emails
  alias Example.Accounts.User
  alias Sigra.Email.CssLint

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

  # ---------------------------------------------------------------------------
  # suspicious_login_email/2
  # ---------------------------------------------------------------------------

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

    # G1 — contrast
    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      assert_cta_contrast(email, 4.5)
    end

    # G2 — byte budget
    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      assert_under_gmail_clip(email)
    end

    # G3 — multipart parity
    test "every URL in html_body also appears in text_body" do
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      assert_text_part_mirrors_html(email)
    end

    # G4 — recipient correctness
    test "email is sent to the user's email address" do
      user = sample_user()
      email = Emails.suspicious_login_email(user, sample_security_details())
      assert_email_to(email, user.email)
    end

    # G5 — XSS escaping for user-controlled fields
    test "XSS payload in ip field is escaped in html_body" do
      details = Map.put(sample_security_details(), :ip, "<script>alert(1)</script>")
      email = Emails.suspicious_login_email(sample_user(), details)
      assert_xss_escaped(email, "<script>alert(1)</script>")
    end

    test "XSS payload in geo_city field is escaped in html_body" do
      details = Map.put(sample_security_details(), :geo_city, "<img src=x onerror=alert(1)>")
      email = Emails.suspicious_login_email(sample_user(), details)
      assert_xss_escaped(email, "<img src=x onerror=alert(1)>")
    end

    test "apostrophe in device field is escaped in html_body" do
      details = Map.put(sample_security_details(), :device, "O'Brien's Device")
      email = Emails.suspicious_login_email(sample_user(), details)
      # Raw apostrophe-containing payload should NOT appear verbatim as HTML break
      html = email.html_body
      refute html =~ "O'Brien's Device" and String.contains?(html, "<")
    end

    # G6 — Outlook Word-engine deny-list
    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      assert_no_outlook_landmines(email)
    end

    # G7 — image tripwire (no <img> tags — future logo PR must pass through deliberate decision)
    test "html contains no <img> tags (image tripwire — see G7 in D-86-05)" do
      # NOTE: This tripwire is intentional. If you are adding a logo or image,
      # ensure it has proper alt text and dark-mode invert handling before removing this assert.
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      refute email.html_body =~ ~r/<img/i
    end

    # G8 — default-arg DateTime.utc_now/0 branch coverage
    test "renders correctly when no time is provided in details (uses DateTime.utc_now/0)" do
      details_without_time = Map.delete(sample_security_details(), :time)
      email = Emails.suspicious_login_email(sample_user(), details_without_time)
      # Should still render the time field (uses DateTime.utc_now/0 default)
      assert email.html_body =~ "Time:"
      assert byte_size(email.html_body) > 0
    end

    # CSS lint — caniemail allowlist gate
    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.suspicious_login_email(sample_user(), sample_security_details())
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # lockout_notification_email/2
  # ---------------------------------------------------------------------------

  describe "lockout_notification_email/2" do
    test "html includes lockout headline, body copy, password CTA, layout footer" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      html = email.html_body

      assert html =~ "Account Locked"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"link\""
      assert html =~ "You're receiving this email because you have an account with Example."
    end

    # G1
    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      assert_cta_contrast(email, 4.5)
    end

    # G2
    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      assert_under_gmail_clip(email)
    end

    # G3
    test "every URL in html_body also appears in text_body" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      assert_text_part_mirrors_html(email)
    end

    # G4
    test "email is sent to the user's email address" do
      user = sample_user()
      email = Emails.lockout_notification_email(user, %{})
      assert_email_to(email, user.email)
    end

    # G6
    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      assert_no_outlook_landmines(email)
    end

    # G7
    test "html contains no <img> tags (image tripwire — see G7 in D-86-05)" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      refute email.html_body =~ ~r/<img/i
    end

    # CSS lint
    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.lockout_notification_email(sample_user(), %{})
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # password_changed_email/2
  # ---------------------------------------------------------------------------

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

    # G1 — also covers D-86-07 red-emphasis lock: #dc2626 on #ffffff >= 4.5:1
    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      assert_cta_contrast(email, 4.5)
    end

    # G2
    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      assert_under_gmail_clip(email)
    end

    # G3
    test "every URL in html_body also appears in text_body" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      assert_text_part_mirrors_html(email)
    end

    # G4
    test "email is sent to the user's email address" do
      user = sample_user()
      email = Emails.password_changed_email(user, sample_security_details())
      assert_email_to(email, user.email)
    end

    # G5
    test "XSS payload in ip field is escaped in html_body" do
      details = Map.put(sample_security_details(), :ip, "<script>xss</script>")
      email = Emails.password_changed_email(sample_user(), details)
      assert_xss_escaped(email, "<script>xss</script>")
    end

    # G6
    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      assert_no_outlook_landmines(email)
    end

    # G7
    test "html contains no <img> tags (image tripwire — see G7 in D-86-05)" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      refute email.html_body =~ ~r/<img/i
    end

    # G8
    test "renders correctly when no time is provided in details (uses DateTime.utc_now/0)" do
      details_without_time = Map.delete(sample_security_details(), :time)
      email = Emails.password_changed_email(sample_user(), details_without_time)
      assert email.html_body =~ "Time:"
      assert byte_size(email.html_body) > 0
    end

    # CSS lint
    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.password_changed_email(sample_user(), sample_security_details())
      assert :ok = CssLint.lint(email.html_body)
    end
  end
end
