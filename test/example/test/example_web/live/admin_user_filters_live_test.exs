defmodule ExampleWeb.AdminUserFiltersLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.User
  alias Example.Accounts.UserMFACredential
  alias Example.Repo

  describe "Phase 28 admin user filter contracts" do
    test "quick filters cover confirmed, mfa, passkeys, locked, and deleted states", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      confirmed_user =
        user_fixture(%{email: "confirmed-filter@example.com", display_name: "Confirmed Filter"})
        |> update_user(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      mfa_user =
        user_fixture(%{email: "mfa-filter@example.com", display_name: "MFA Filter"})
        |> tap(&insert_mfa/1)

      passkey_user =
        user_fixture(%{email: "passkey-filter@example.com", display_name: "Passkey Filter"})
        |> tap(&passkey_fixture/1)

      locked_user =
        user_fixture(%{email: "locked-filter@example.com", display_name: "Locked Filter"})
        |> update_user(%{locked_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      deleted_user =
        user_fixture(%{email: "deleted-filter@example.com", display_name: "Deleted Filter"})
        |> update_user(%{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      assert filter_html(conn, platform_admin, "confirmed=true") =~ confirmed_user.email
      assert filter_html(conn, platform_admin, "mfa=true") =~ mfa_user.email
      assert filter_html(conn, platform_admin, "passkeys=true") =~ passkey_user.email
      assert filter_html(conn, platform_admin, "locked=true") =~ locked_user.email
      assert filter_html(conn, platform_admin, "deleted=true") =~ deleted_user.email

      assert filter_html(conn, platform_admin, "needs_review=true") =~ locked_user.email
      assert filter_html(conn, platform_admin, "needs_review=true") =~ deleted_user.email
    end

    test "summary metrics explain unfiltered user posture with counts, percentages, and help", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()

      user_fixture(%{email: "confirmed-summary@example.com", display_name: "Confirmed Summary"})
      |> update_user(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      user_fixture(%{email: "mfa-summary@example.com", display_name: "MFA Summary"})
      |> tap(&insert_mfa/1)

      user_fixture(%{email: "passkey-summary@example.com", display_name: "Passkey Summary"})
      |> tap(&passkey_fixture/1)

      user_fixture(%{email: "locked-summary@example.com", display_name: "Locked Summary"})
      |> update_user(%{locked_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      user_fixture(%{email: "deletion-summary@example.com", display_name: "Deletion Summary"})
      |> update_user(%{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})

      html =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users")
        |> html_response(200)

      assert html =~ ~s(id="users-metric-total")
      assert html =~ "User health"
      assert html =~ "Find users"
      assert html =~ ~s(<dd class="sg-metric__caption">total users</dd>)
      refute html =~ "Visible in this scope"
      refute html =~ "All accounts visible in this admin scope."
      refute html =~ ~s(id="users-metric-total-help")
      assert html =~ ~s(<dd class="sg-metric__caption">confirmed</dd>)
      assert html =~ ~s(<dd class="sg-metric__caption">MFA enabled</dd>)
      assert html =~ ~s(<dd class="sg-metric__caption">with passkeys</dd>)
      assert html =~ ~s(<dd class="sg-metric__caption">locked out</dd>)
      assert html =~ ~s(<dd class="sg-metric__caption">pending deletion</dd>)
      refute html =~ "sg-metric__value-suffix"
      assert html =~ "% of total users"
      assert html =~ "These users confirmed their email and can sign in normally."

      assert html =~
               "These users have multifactor authentication enabled. Higher coverage lowers account takeover risk."

      assert html =~
               "These users have at least one passkey. Passkeys make phishing attacks harder."

      assert html =~
               "These users are locked out after failed sign-in attempts. Review the user before unlocking."

      assert html =~
               "These users are scheduled for deletion. Access is disabled and active sessions are revoked."

      assert html =~ ~s(data-sg-metric-help-root="true")
      assert html =~ ~s(data-icon="check")
      assert html =~ ~s(data-icon="mfa")
      refute html =~ ~s(data-icon="phone-check")
      assert html =~ ~s(data-icon="fingerprint")
      refute html =~ ~s(data-icon="check-circle")
      refute html =~ ~s(data-sg-metric-help-trigger)
      refute html =~ "sg-metric__help-trigger"
      assert html =~ ~s(id="users-metric-mfa-help")
      assert html =~ ~s(data-tone="risk")
      assert html =~ ~s(data-tone="warn")

      filtered_html =
        conn
        |> recycle()
        |> log_in_user(platform_admin)
        |> get("/admin/users?q=definitely-no-user")
        |> html_response(200)

      assert filtered_html =~ "No users match this view"

      assert metric_number(filtered_html, "users-metric-total") ==
               metric_number(html, "users-metric-total")
    end

    test "more filters include provider and registered_from registered_to range controls", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get("/admin/users?provider=local&registered_from=2026-01-01&registered_to=2026-12-31")

      html = html_response(conn, 200)

      assert html =~ "More filters"
      assert html =~ ~s(name="provider")
      assert html =~ ~s(name="registered_from")
      assert html =~ ~s(name="registered_to")
      assert html =~ ~s(name="organization")
    end

    test "organization membership lookup stays structurally scoped to the current admin context",
         %{conn: conn} do
      org_admin = org_admin_fixture()
      acme = create_organization(%{name: "Acme Ops", slug: "acme-ops"})
      beta = create_organization(%{name: "Beta Ops", slug: "beta-ops"})

      create_membership(org_admin, acme, :admin)

      in_scope =
        user_fixture(%{email: "acme-user@example.com", display_name: "Acme User"})
        |> tap(&create_membership(&1, acme, :member))

      _cross_scoped =
        user_fixture(%{email: "beta-user@example.com", display_name: "Beta User"})
        |> tap(&create_membership(&1, beta, :member))

      _dual_member =
        user_fixture(%{email: "dual-user@example.com", display_name: "Dual User"})
        |> tap(&create_membership(&1, acme, :member))
        |> tap(&create_membership(&1, beta, :member))

      html =
        conn
        |> log_in_user(org_admin)
        |> get("/admin/organizations/#{acme.slug}/users?organization=beta")
        |> html_response(200)

      assert html =~ "No users match this view"
      refute html =~ in_scope.email
      refute html =~ "beta-user@example.com"
      refute html =~ "dual-user@example.com"
    end
  end

  defp filter_html(conn, admin, query_string) do
    conn
    |> log_in_user(admin)
    |> get("/admin/users?" <> query_string)
    |> html_response(200)
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp org_admin_fixture do
    user_fixture(%{
      email: "org-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Organization Admin"
    })
  end

  defp update_user(%User{} = user, attrs) do
    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end

  defp insert_mfa(user) do
    %UserMFACredential{}
    |> UserMFACredential.create_changeset(%{
      user_id: user.id,
      type: "totp",
      encrypted_secret: <<1, 2, 3>>,
      enabled_at: DateTime.utc_now()
    })
    |> Repo.insert!()

    user
  end

  defp metric_number(html, id) do
    pattern =
      ~r/id="#{Regex.escape(id)}".*?<span class="sg-metric__number">\s*(?<number>\d+)/s

    %{"number" => number} = Regex.named_captures(pattern, html)
    String.to_integer(number)
  end
end
