defmodule ExampleWeb.Emails.OrganizationInvitationEmailTest do
  @moduledoc """
  Phase 17 Plan 04 — tests for the generated organization invitation email.

  Asserts subject shape, XSS escape of user-controllable fields,
  HTML/text multipart content, CTA label, phishing fine print, and
  Swoosh.Adapters.Test end-to-end delivery.
  """
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias Example.Accounts.Emails
  alias Example.Accounts.Organization
  alias Example.Accounts.OrganizationInvitation
  alias Example.Accounts.User
  alias Example.Mailer

  @accept_url "https://example.com/org/acme/invitations/accept?token=SIGNED_TOKEN_FAKE"

  defp build_org(attrs \\ %{}) do
    struct(Organization, Map.merge(%{id: 1, name: "Acme", slug: "acme"}, attrs))
  end

  defp build_invitation(attrs \\ %{}) do
    struct(
      OrganizationInvitation,
      Map.merge(
        %{
          id: 1,
          email: "invitee@example.com",
          role: :member,
          expires_at: ~U[2026-05-01 12:00:00Z]
        },
        attrs
      )
    )
  end

  defp build_inviter(attrs \\ %{}) do
    struct(User, Map.merge(%{id: 1, email: "jane@acme.com"}, attrs))
  end

  describe "organization_invitation/4 — subject line (phishing defense)" do
    test "uses inviter email when user has no name field (example app has none)" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(%{name: "Acme"}),
          build_inviter(%{email: "jane@acme.com"}),
          @accept_url
        )

      assert email.subject =~ "jane@acme.com"
      assert email.subject =~ "Acme"
      assert email.subject =~ "invited you to join"
    end

    test "subject contains both inviter and org name literals" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(%{name: "Widgets Inc"}),
          build_inviter(%{email: "alice@widgets.io"}),
          @accept_url
        )

      assert email.subject == "alice@widgets.io invited you to join Widgets Inc"
    end
  end

  describe "organization_invitation/4 — HTML body escaping (XSS defense)" do
    test "escapes malicious org name in HTML body" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(%{name: "<script>alert(1)</script>"}),
          build_inviter(),
          @accept_url
        )

      refute email.html_body =~ "<script>alert(1)</script>"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "escapes malicious inviter email in HTML body" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(),
          build_inviter(%{email: "<img src=x onerror=alert(1)>"}),
          @accept_url
        )

      refute email.html_body =~ "<img src=x onerror=alert(1)>"
      assert email.html_body =~ "&lt;img"
    end
  end

  describe "organization_invitation/4 — HTML body content" do
    test "HTML body contains the accept URL in href and as plain fallback" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(),
          build_inviter(),
          @accept_url
        )

      assert email.html_body =~ ~s(href="#{@accept_url}")
      # Fallback copy-paste URL block
      assert email.html_body =~ @accept_url
      # CTA label (locked per UI-SPEC)
      assert email.html_body =~ "Accept invitation"
    end

    test "HTML body contains humanized role label" do
      email_member =
        Emails.organization_invitation(
          build_invitation(%{role: :member}),
          build_org(),
          build_inviter(),
          @accept_url
        )

      email_admin =
        Emails.organization_invitation(
          build_invitation(%{role: :admin}),
          build_org(),
          build_inviter(),
          @accept_url
        )

      assert email_member.html_body =~ "Member"
      assert email_admin.html_body =~ "Admin"
    end

    test "HTML body contains formatted expiry date" do
      email =
        Emails.organization_invitation(
          build_invitation(%{expires_at: ~U[2026-05-01 12:00:00Z]}),
          build_org(),
          build_inviter(),
          @accept_url
        )

      assert email.html_body =~ "May 01, 2026"
    end
  end

  describe "organization_invitation/4 — plain-text fallback" do
    test "text body is present and contains accept URL, inviter, org, role" do
      email =
        Emails.organization_invitation(
          build_invitation(%{role: :admin}),
          build_org(%{name: "Acme"}),
          build_inviter(%{email: "jane@acme.com"}),
          @accept_url
        )

      assert is_binary(email.text_body)
      assert email.text_body != ""
      assert email.text_body =~ @accept_url
      assert email.text_body =~ "jane@acme.com"
      assert email.text_body =~ "Acme"
      assert email.text_body =~ "Admin"
    end
  end

  describe "organization_invitation/4 — phishing fine print (locked copy)" do
    test "HTML body contains 'safely ignore' reassurance" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(),
          build_inviter(),
          @accept_url
        )

      assert email.html_body =~ ~r/safely ignore/i
      assert email.text_body =~ ~r/safely ignore/i
    end
  end

  describe "organization_invitation/4 — Swoosh delivery" do
    test "email is delivered via Swoosh test adapter mailbox" do
      email =
        Emails.organization_invitation(
          build_invitation(),
          build_org(%{name: "Acme"}),
          build_inviter(%{email: "jane@acme.com"}),
          @accept_url
        )

      {:ok, _metadata} = Mailer.deliver(email)

      assert_email_sent(fn sent ->
        assert sent.subject =~ "Acme"
        assert sent.subject =~ "jane@acme.com"
        assert sent.html_body =~ "Accept invitation"
        assert sent.text_body =~ "safely ignore"
      end)
    end
  end
end
