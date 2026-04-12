defmodule ExampleWeb.SessionActiveOrgRoundTripTest do
  @moduledoc """
  Phase 12 D-14 (clarified) -- proves that:
    1. The new `active_organization_id` column on `user_sessions` round-trips
       through `Sigra.SessionStores.Ecto.fetch/2` into the `%Sigra.Session{}`
       struct (Plan 01 wired the to_session/1 mapping).
    2. The default-nil case is honored (fresh sessions have nil).
    3. The Plug pipeline survives the new field -- login still works and the
       cookie session continues to carry only `:user_token`. The new field
       lives on the DB row only; Phase 12 does NOT extend FetchSession.
  """
  use ExampleWeb.ConnCase, async: true

  import Ecto.Query
  import Example.AccountsFixtures

  alias Example.Accounts
  alias Example.Accounts.UserSession
  alias Example.Repo
  alias Sigra.SessionStores.Ecto, as: EctoStore
  alias ExampleWeb.UserAuth

  @moduletag :example_app

  setup do
    {:ok, user} = Accounts.register_user(valid_user_attributes())
    %{user: user}
  end

  describe "Phase 12 D-14 -- active_organization_id round-trip" do
    test "DB round-trip -- value written to user_sessions row survives EctoStore.fetch/2",
         %{user: user} do
      # Arrange -- create a session via the canonical example-app wrapper
      raw_token = Accounts.generate_user_session_token(user)
      assert is_binary(raw_token)

      # Compute the hashed_token that the store uses as its lookup key
      {:ok, raw_bytes} = Base.url_decode64(raw_token, padding: false)
      hashed_token = Sigra.Token.hash_token(raw_bytes)

      # Set active_organization_id on the row directly via Repo.update_all
      org_id = Ecto.UUID.generate()

      {1, _} =
        Repo.update_all(
          from(s in UserSession, where: s.hashed_token == ^hashed_token),
          set: [active_organization_id: org_id]
        )

      # Act -- reload via the canonical store API
      {:ok, reloaded} =
        EctoStore.fetch(hashed_token, repo: Example.Repo, session_schema: UserSession)

      # Assert -- the value survived the round-trip through to_session/1
      assert %Sigra.Session{} = reloaded
      assert reloaded.active_organization_id == org_id
    end

    test "default-nil case -- fresh session has active_organization_id == nil",
         %{user: user} do
      raw_token = Accounts.generate_user_session_token(user)
      {:ok, raw_bytes} = Base.url_decode64(raw_token, padding: false)
      hashed_token = Sigra.Token.hash_token(raw_bytes)

      {:ok, reloaded} =
        EctoStore.fetch(hashed_token, repo: Example.Repo, session_schema: UserSession)

      assert reloaded.active_organization_id == nil
    end

    test "plug pipeline survives -- UserAuth.log_in_user/2 still works with the new field present",
         %{conn: conn, user: user} do
      # D-14 clarification: active_organization_id lives on the DB row,
      # NOT in the Plug cookie session.
      logged_in_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.log_in_user(user)

      # The cookie session carries :user_token unchanged
      assert is_binary(Plug.Conn.get_session(logged_in_conn, :user_token))

      # active_organization_id is NOT in the cookie session -- it lives on
      # the DB row only. Phase 14 may revisit when LoadActiveOrganization ships.
      refute Plug.Conn.get_session(logged_in_conn, :active_organization_id)
    end
  end
end
