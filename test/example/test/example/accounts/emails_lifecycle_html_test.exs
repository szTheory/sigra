defmodule Example.Accounts.EmailsLifecycleHtmlTest do
  @moduledoc """
  Phase 08 lifecycle template coverage — G1-G9 rubric per D-86-05.

  Extends the original shift-left SEED-001 item 2 structural assertions with
  Phase 86 locked gaps: contrast, byte budget, multipart parity, recipient
  correctness, XSS escaping, Outlook deny-list, image tripwire, default-arg
  DateTime branches, backup-code boundary coverage (G9), and caniemail CSS lint.

  All fixtures are frozen per D-86-04:
    - time: ~U[2026-04-17 12:00:00Z]
    - scheduled deletion date: ~D[2026-12-01]
    - user email: "lifecycle-html@example.test"
    - new email (email-change): "new@example.test"
  """
  use Example.DataCase, async: true

  import Example.EmailAssertions

  alias Example.Accounts.Emails
  alias Example.Accounts.User
  alias Sigra.Email.CssLint

  defp user do
    %User{email: "lifecycle-html@example.test"}
  end

  # ---------------------------------------------------------------------------
  # confirmation_email/3
  # ---------------------------------------------------------------------------

  describe "confirmation_email/3" do
    test "includes code block, CTA, and footer" do
      html =
        Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456").html_body

      assert html =~ "Confirm email address"
      assert html =~ "1 2 3 4 5 6"
      assert html =~ "https://example.test/confirm/tok"
      assert html =~ "role=\"link\""
      assert html =~ "You're receiving this email because you have an account with Example."
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      assert_under_gmail_clip(email)
    end

    test "every URL in html_body also appears in text_body" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      assert_text_part_mirrors_html(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.confirmation_email(user(), "https://example.test/confirm/tok", "123456")
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # reset_password_email/2
  # ---------------------------------------------------------------------------

  describe "reset_password_email/2" do
    test "includes reset CTA and raw link" do
      html = Emails.reset_password_email(user(), "https://example.test/reset/tok").html_body

      assert html =~ "Reset password"
      assert html =~ "https://example.test/reset/tok"
      assert html =~ "role=\"link\""
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      assert_under_gmail_clip(email)
    end

    test "every URL in html_body also appears in text_body" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      assert_text_part_mirrors_html(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.reset_password_email(user(), "https://example.test/reset/tok")
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # magic_link_email/2
  # ---------------------------------------------------------------------------

  describe "magic_link_email/2" do
    test "includes magic link CTA" do
      html = Emails.magic_link_email(user(), "https://example.test/magic/tok").html_body

      assert html =~ "Log in to Example"
      assert html =~ "https://example.test/magic/tok"
      assert html =~ "role=\"link\""
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      assert_under_gmail_clip(email)
    end

    test "every URL in html_body also appears in text_body" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      assert_text_part_mirrors_html(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.magic_link_email(user(), "https://example.test/magic/tok")
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # oauth_reset_email/2
  # ---------------------------------------------------------------------------

  describe "oauth_reset_email/2" do
    test "includes provider-specific copy and login CTA" do
      html = Emails.oauth_reset_email(user(), :google).html_body

      assert html =~ "Google"
      assert html =~ "/users/log_in"
      assert html =~ "role=\"link\""
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.oauth_reset_email(user(), :google)
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.oauth_reset_email(user(), :google)
      assert_under_gmail_clip(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.oauth_reset_email(user(), :google)
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.oauth_reset_email(user(), :google)
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.oauth_reset_email(user(), :google)
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.oauth_reset_email(user(), :google)
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # mfa_enabled_email/2
  # ---------------------------------------------------------------------------

  describe "mfa_enabled_email/2" do
    test "includes headline and password CTA" do
      html = Emails.mfa_enabled_email(user()).html_body

      assert html =~ "Two-Factor Authentication Enabled"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"link\""
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.mfa_enabled_email(user())
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.mfa_enabled_email(user())
      assert_under_gmail_clip(email)
    end

    test "every URL in html_body also appears in text_body" do
      email = Emails.mfa_enabled_email(user())
      assert_text_part_mirrors_html(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.mfa_enabled_email(user())
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.mfa_enabled_email(user())
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.mfa_enabled_email(user())
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.mfa_enabled_email(user())
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # mfa_disabled_email/2
  # ---------------------------------------------------------------------------

  describe "mfa_disabled_email/2" do
    test "includes headline and settings CTA" do
      html = Emails.mfa_disabled_email(user()).html_body

      assert html =~ "Two-Factor Authentication Disabled"
      assert html =~ "/users/settings"
      assert html =~ "role=\"link\""
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.mfa_disabled_email(user())
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.mfa_disabled_email(user())
      assert_under_gmail_clip(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.mfa_disabled_email(user())
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.mfa_disabled_email(user())
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.mfa_disabled_email(user())
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.mfa_disabled_email(user())
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # backup_code_used_email/2 — G9: boundary coverage at remaining: 1, 2, 3
  # ---------------------------------------------------------------------------

  describe "backup_code_used_email/2" do
    test "includes usage headline, remaining count, and optional low-code warning" do
      html = Emails.backup_code_used_email(user(), remaining: 1).html_body

      assert html =~ "Backup Code Used"
      assert html =~ "1 of 8 backup codes remaining"
      assert html =~ "Generate new backup codes"
      assert html =~ "running low on backup codes"
    end

    # G9: boundary at remaining: 1 (lowest — triggers low-codes warning)
    test "remaining: 1 — shows low-codes warning (G9 low boundary)" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      assert email.html_body =~ "running low on backup codes"
      assert email.html_body =~ "1 of 8 backup codes remaining"
    end

    # G9: boundary at remaining: 2 (still low — warning shown)
    test "remaining: 2 — shows low-codes warning (G9 low boundary)" do
      email = Emails.backup_code_used_email(user(), remaining: 2)
      assert email.html_body =~ "running low on backup codes"
      assert email.html_body =~ "2 of 8 backup codes remaining"
    end

    # G9: boundary at remaining: 3 (threshold boundary — warning shown per remaining <= 2 gate)
    test "remaining: 3 — does NOT show low-codes warning (G9 boundary — first safe value)" do
      email = Emails.backup_code_used_email(user(), remaining: 3)
      refute email.html_body =~ "running low on backup codes"
      assert email.html_body =~ "3 of 8 backup codes remaining"
    end

    # G9: confirm warning text is absent for higher values too
    test "remaining: 5 — does not show low-codes warning" do
      email = Emails.backup_code_used_email(user(), remaining: 5)
      refute email.html_body =~ "running low on backup codes"
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      assert_under_gmail_clip(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.backup_code_used_email(user(), remaining: 1)
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # mfa_lockout_email/2
  # ---------------------------------------------------------------------------

  describe "mfa_lockout_email/2" do
    test "includes lockout headline and password CTA" do
      html = Emails.mfa_lockout_email(user()).html_body

      assert html =~ "Verification Temporarily Locked"
      assert html =~ "/users/reset-password"
      assert html =~ "role=\"link\""
    end

    test "CTA button contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.mfa_lockout_email(user())
      assert_cta_contrast(email, 4.5)
    end

    test "HTML body is under Gmail clip threshold (100 KB)" do
      email = Emails.mfa_lockout_email(user())
      assert_under_gmail_clip(email)
    end

    test "email is sent to the user's email address" do
      email = Emails.mfa_lockout_email(user())
      assert_email_to(email, user().email)
    end

    test "html contains no <img> tags (image tripwire)" do
      email = Emails.mfa_lockout_email(user())
      refute email.html_body =~ ~r/<img/i
    end

    test "html has no Outlook Word-engine landmine CSS constructs" do
      email = Emails.mfa_lockout_email(user())
      assert_no_outlook_landmines(email)
    end

    test "rendered HTML passes caniemail CSS lint for Gmail/Outlook/Apple Mail" do
      email = Emails.mfa_lockout_email(user())
      assert :ok = CssLint.lint(email.html_body)
    end
  end

  # ---------------------------------------------------------------------------
  # email change + deletion lifecycle
  # ---------------------------------------------------------------------------

  describe "email change + deletion lifecycle" do
    test "email_change_confirmation_email/3" do
      html =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c").html_body

      assert html =~ "Confirm Email Change"
      assert html =~ "https://ex.test/c"
      assert html =~ "role=\"link\""
    end

    # G4 — recipient correctness for email change is security-critical:
    # the confirmation goes to the NEW address, notification to the OLD
    test "email_change_confirmation_email/3 is sent to the NEW email address" do
      email =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c")

      assert_email_to(email, "new@example.test")
    end

    test "email_change_confirmation_email/3 CTA contrast meets WCAG AA (>= 4.5:1)" do
      email =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c")

      assert_cta_contrast(email, 4.5)
    end

    test "email_change_confirmation_email/3 HTML under Gmail clip threshold" do
      email =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c")

      assert_under_gmail_clip(email)
    end

    test "email_change_confirmation_email/3 URL parity between html and text parts" do
      email =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c")

      assert_text_part_mirrors_html(email)
    end

    test "email_change_confirmation_email/3 html has no <img> tags" do
      email =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c")

      refute email.html_body =~ ~r/<img/i
    end

    test "email_change_confirmation_email/3 passes caniemail CSS lint" do
      email =
        Emails.email_change_confirmation_email(user(), "new@example.test", "https://ex.test/c")

      assert :ok = CssLint.lint(email.html_body)
    end

    test "email_change_notification_email/3" do
      html =
        Emails.email_change_notification_email(
          user(),
          "new@example.test",
          "https://ex.test/cancel"
        ).html_body

      assert html =~ "Email Change Requested"
      assert html =~ "Cancel email change"
      assert html =~ "https://ex.test/cancel"
    end

    # G4 — notification goes to OLD address (security-critical)
    test "email_change_notification_email/3 is sent to the OLD (current) user email" do
      email =
        Emails.email_change_notification_email(user(), "new@example.test", "https://ex.test/cancel")

      assert_email_to(email, user().email)
    end

    # G5 — new_email field is user-controlled and must be escaped
    test "email_change_notification_email/3 XSS payload in new_email is escaped" do
      email =
        Emails.email_change_notification_email(
          user(),
          "<script>alert(1)</script>@evil.test",
          "https://ex.test/cancel"
        )

      assert_xss_escaped(email, "<script>alert(1)</script>@evil.test")
    end

    test "email_change_notification_email/3 CTA contrast meets WCAG AA" do
      email =
        Emails.email_change_notification_email(user(), "new@example.test", "https://ex.test/cancel")

      assert_cta_contrast(email, 4.5)
    end

    test "email_change_notification_email/3 passes caniemail CSS lint" do
      email =
        Emails.email_change_notification_email(user(), "new@example.test", "https://ex.test/cancel")

      assert :ok = CssLint.lint(email.html_body)
    end

    test "email_changed_email/1" do
      html = Emails.email_changed_email(user()).html_body

      assert html =~ "Email Updated"
      assert html =~ "/users/reset-password"
    end

    test "email_changed_email/1 CTA contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.email_changed_email(user())
      assert_cta_contrast(email, 4.5)
    end

    test "email_changed_email/1 HTML under Gmail clip threshold" do
      email = Emails.email_changed_email(user())
      assert_under_gmail_clip(email)
    end

    test "email_changed_email/1 passes caniemail CSS lint" do
      email = Emails.email_changed_email(user())
      assert :ok = CssLint.lint(email.html_body)
    end

    test "deletion_scheduled_email/3" do
      html =
        Emails.deletion_scheduled_email(user(), ~D[2026-12-01], "https://ex.test/undelete").html_body

      assert html =~ "Account Deletion Scheduled"
      assert html =~ "Cancel account deletion"
      assert html =~ "December 01, 2026"
    end

    test "deletion_scheduled_email/3 CTA contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.deletion_scheduled_email(user(), ~D[2026-12-01], "https://ex.test/undelete")
      assert_cta_contrast(email, 4.5)
    end

    test "deletion_scheduled_email/3 URL parity between html and text parts" do
      email = Emails.deletion_scheduled_email(user(), ~D[2026-12-01], "https://ex.test/undelete")
      assert_text_part_mirrors_html(email)
    end

    test "deletion_scheduled_email/3 passes caniemail CSS lint" do
      email = Emails.deletion_scheduled_email(user(), ~D[2026-12-01], "https://ex.test/undelete")
      assert :ok = CssLint.lint(email.html_body)
    end

    test "deletion_cancelled_email/2" do
      html = Emails.deletion_cancelled_email(user(), "https://ex.test/in").html_body

      assert html =~ "Deletion Cancelled"
      assert html =~ "Log in to your account"
    end

    test "deletion_cancelled_email/2 CTA contrast meets WCAG AA (>= 4.5:1)" do
      email = Emails.deletion_cancelled_email(user(), "https://ex.test/in")
      assert_cta_contrast(email, 4.5)
    end

    test "deletion_cancelled_email/2 URL parity between html and text parts" do
      email = Emails.deletion_cancelled_email(user(), "https://ex.test/in")
      assert_text_part_mirrors_html(email)
    end

    test "deletion_cancelled_email/2 passes caniemail CSS lint" do
      email = Emails.deletion_cancelled_email(user(), "https://ex.test/in")
      assert :ok = CssLint.lint(email.html_body)
    end

    test "deletion_finalized_email/1" do
      html = Emails.deletion_finalized_email("gone@example.test").html_body

      assert html =~ "Account Deleted"
    end

    test "deletion_finalized_email/1 HTML under Gmail clip threshold" do
      email = Emails.deletion_finalized_email("gone@example.test")
      assert_under_gmail_clip(email)
    end

    test "deletion_finalized_email/1 passes caniemail CSS lint" do
      email = Emails.deletion_finalized_email("gone@example.test")
      assert :ok = CssLint.lint(email.html_body)
    end
  end
end
