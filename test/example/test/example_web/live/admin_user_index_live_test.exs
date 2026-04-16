defmodule ExampleWeb.AdminUserIndexLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.User
  alias Example.Repo

  describe "Phase 28 admin user index contracts" do
    test "search and pagination preserve URL state when operators open a user and return", %{
      conn: conn
    } do
      platform_admin = platform_admin_fixture()

      target =
        user_fixture(%{
          email: "alice-index@example.com"
        })
        |> update_user(%{display_name: "Alice Index"})

      _other =
        user_fixture(%{
          email: "zebra-index@example.com"
        })
        |> update_user(%{display_name: "Zebra Index"})

      conn =
        conn
        |> log_in_user(platform_admin)
        |> get(
          "/admin/users?q=alice-index&page=1&page_size=1&order_by=inserted_at&order_direction=asc"
        )

      html = html_response(conn, 200)

      assert html =~ "Alice Index"
      assert html =~ "Open user"

      encoded =
        URI.encode_www_form(
          "/admin/users?order_by=inserted_at&order_direction=asc&page=1&page_size=1&q=alice-index"
        )

      assert html =~ "/admin/users/#{target.id}?return_to=#{encoded}"
    end

    test "desktop rows and mobile cards share the same user query contract", %{conn: conn} do
      platform_admin = platform_admin_fixture()

      matched =
        user_fixture(%{
          email: "shared-surface@example.com"
        })
        |> update_user(%{display_name: "Shared Surface"})

      _other =
        user_fixture(%{
          email: "other-surface@example.com"
        })
        |> update_user(%{display_name: "Other Surface"})

      conn = conn |> log_in_user(platform_admin) |> get("/admin/users?q=shared-surface")
      html = html_response(conn, 200)

      assert html =~ ~s(data-testid="admin-users-desktop-results")
      assert html =~ ~s(data-testid="admin-users-mobile-results")
      assert html =~ "Shared Surface"
      assert html =~ matched.email
      assert html =~ matched.id
      refute html =~ "Other Surface"
    end

    test "Open user remains the primary row action on the list surface", %{conn: conn} do
      platform_admin = platform_admin_fixture()
      user = user_fixture(%{email: "open-user@example.com", display_name: "Open User"})

      conn = conn |> log_in_user(platform_admin) |> get("/admin/users?q=open-user")
      html = html_response(conn, 200)

      assert html =~ "Open user"
      assert html =~ "/admin/users/#{user.id}?return_to="
    end
  end

  defp platform_admin_fixture do
    user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
      display_name: "Platform Admin"
    })
  end

  defp update_user(%User{} = user, attrs) do
    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update!()
  end
end
