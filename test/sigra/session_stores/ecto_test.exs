defmodule Sigra.SessionStores.EctoTest do
  use ExUnit.Case, async: true

  import Mox

  @moduletag :phase4

  alias Sigra.Session
  alias Sigra.SessionStores.Ecto, as: EctoStore

  setup :verify_on_exit!

  @opts [repo: Sigra.MockRepo, session_schema: Sigra.Test.UserSession]

  describe "create/3" do
    test "generates a token, stores with metadata, returns Session struct with raw token" do
      user_id = Ecto.UUID.generate()
      metadata = %{type: :standard, ip: "192.168.1.1", user_agent: "Chrome/120", geo_city: "Portland", geo_country_code: "US"}

      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        assert struct.__struct__ == Sigra.Test.UserSession
        assert struct.user_id == user_id
        assert struct.type == "standard"
        assert struct.ip == "192.168.1.1"
        assert struct.user_agent == "Chrome/120"
        assert struct.geo_city == "Portland"
        assert struct.geo_country_code == "US"
        assert is_binary(struct.hashed_token) and byte_size(struct.hashed_token) == 32
        assert %DateTime{} = struct.last_active_at
        assert %DateTime{} = struct.inserted_at

        {:ok, Map.put(struct, :id, 42)}
      end)

      assert {:ok, %Session{} = session} = EctoStore.create(user_id, metadata, @opts)

      assert session.id == 42
      assert session.user_id == user_id
      assert session.type == :standard
      assert session.ip == "192.168.1.1"
      assert session.user_agent == "Chrome/120"
      assert session.geo_city == "Portland"
      assert session.geo_country_code == "US"
      # Raw token is present on create
      assert is_binary(session.token) and byte_size(session.token) > 0
      assert is_binary(session.hashed_token) and byte_size(session.hashed_token) == 32
    end
  end

  describe "create/3 with active_organization_id" do
    test "passes active_organization_id through to the stored record" do
      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      metadata = %{type: :standard, ip: "10.0.0.1", active_organization_id: org_id}

      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        assert struct.__struct__ == Sigra.Test.UserSession
        assert struct.active_organization_id == org_id
        {:ok, Map.put(struct, :id, 99)}
      end)

      assert {:ok, %Session{} = session} = EctoStore.create(user_id, metadata, @opts)
      assert session.active_organization_id == org_id
    end

    test "defaults active_organization_id to nil when not provided" do
      user_id = Ecto.UUID.generate()
      metadata = %{type: :standard, ip: "10.0.0.1"}

      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        assert struct.active_organization_id == nil
        {:ok, Map.put(struct, :id, 100)}
      end)

      assert {:ok, %Session{} = session} = EctoStore.create(user_id, metadata, @opts)
      assert session.active_organization_id == nil
    end
  end

  describe "fetch/2" do
    test "finds session by hashed_token, returns Session struct without raw token" do
      hashed_token = :crypto.hash(:sha256, "test-token")
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 1,
        user_id: "user_123",
        hashed_token: hashed_token,
        type: "standard",
        ip: "10.0.0.1",
        user_agent: "Firefox/121",
        geo_city: nil,
        geo_country_code: nil,
        last_active_at: now,
        sudo_at: nil,
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)

      assert {:ok, %Session{} = session} = EctoStore.fetch(hashed_token, @opts)

      assert session.id == 1
      assert session.user_id == "user_123"
      assert session.type == :standard
      assert session.ip == "10.0.0.1"
      # Raw token is NOT present on fetch
      assert session.token == nil
    end

    test "round-trips active_organization_id through to_session" do
      hashed_token = :crypto.hash(:sha256, "org-token")
      org_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 10,
        user_id: "user_org",
        hashed_token: hashed_token,
        type: "standard",
        ip: "10.0.0.1",
        user_agent: "Chrome/120",
        active_organization_id: org_id,
        last_active_at: now,
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)

      assert {:ok, %Session{} = session} = EctoStore.fetch(hashed_token, @opts)
      assert session.active_organization_id == org_id
    end

    test "hydrates persisted mfa_pending sessions as mfa_pending atoms" do
      hashed_token = :crypto.hash(:sha256, "mfa-pending-token")
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 12,
        user_id: "user_mfa_pending",
        hashed_token: hashed_token,
        type: "mfa_pending",
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)

      assert {:ok, %Session{} = session} = EctoStore.fetch(hashed_token, @opts)
      assert session.type == :mfa_pending
    end

    test "preserves atom session types during hydration" do
      hashed_token = :crypto.hash(:sha256, "atom-type-token")
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 13,
        user_id: "user_atom_type",
        hashed_token: hashed_token,
        type: :remember_me,
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)

      assert {:ok, %Session{} = session} = EctoStore.fetch(hashed_token, @opts)
      assert session.type == :remember_me
    end

    test "keeps unknown persisted string session types fail-closed as standard" do
      hashed_token = :crypto.hash(:sha256, "unknown-type-token")
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 14,
        user_id: "user_unknown_type",
        hashed_token: hashed_token,
        type: "owner",
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)

      assert {:ok, %Session{} = session} = EctoStore.fetch(hashed_token, @opts)
      assert session.type == :standard
    end

    test "defaults active_organization_id to nil in to_session when not set" do
      hashed_token = :crypto.hash(:sha256, "no-org-token")
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 11,
        user_id: "user_no_org",
        hashed_token: hashed_token,
        type: "standard",
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)

      assert {:ok, %Session{} = session} = EctoStore.fetch(hashed_token, @opts)
      assert session.active_organization_id == nil
    end

    test "returns {:error, :not_found} for unknown token" do
      hashed_token = :crypto.hash(:sha256, "nonexistent")

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        nil
      end)

      assert {:error, :not_found} = EctoStore.fetch(hashed_token, @opts)
    end
  end

  describe "delete/2" do
    test "removes session record" do
      hashed_token = :crypto.hash(:sha256, "delete-me")
      now = DateTime.utc_now()

      record = %Sigra.Test.UserSession{
        id: 5,
        user_id: "user_123",
        hashed_token: hashed_token,
        type: "standard",
        inserted_at: now
      }

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        record
      end)
      |> expect(:delete!, fn ^record -> record end)

      assert :ok = EctoStore.delete(hashed_token, @opts)
    end

    test "returns :ok even if session not found" do
      hashed_token = :crypto.hash(:sha256, "already-gone")

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.Test.UserSession, [hashed_token: ^hashed_token] ->
        nil
      end)

      assert :ok = EctoStore.delete(hashed_token, @opts)
    end
  end

  describe "list_by_user/2" do
    test "returns all sessions for a user as Session structs" do
      user_id = "user_456"
      now = DateTime.utc_now()

      records = [
        %Sigra.Test.UserSession{
          id: 1,
          user_id: user_id,
          hashed_token: <<1::256>>,
          type: "standard",
          ip: "10.0.0.1",
          user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          inserted_at: now
        },
        %Sigra.Test.UserSession{
          id: 2,
          user_id: user_id,
          hashed_token: <<2::256>>,
          type: "remember_me",
          ip: "10.0.0.2",
          user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
          inserted_at: DateTime.add(now, -3600)
        }
      ]

      Sigra.MockRepo
      |> expect(:all, fn query ->
        # Verify it's querying the right schema
        assert inspect(query) =~ "UserSession"
        records
      end)

      sessions = EctoStore.list_by_user(user_id, @opts)

      assert length(sessions) == 2
      assert [%Session{id: 1}, %Session{id: 2}] = sessions
      # Verify parsed_ua is populated
      assert sessions |> Enum.at(0) |> Map.get(:parsed_ua) |> Map.get(:browser) == "Chrome"
      assert sessions |> Enum.at(1) |> Map.get(:parsed_ua) |> Map.get(:browser) == "Firefox"
    end
  end

  describe "delete_all_for_user/2" do
    test "deletes all sessions, returns count" do
      user_id = "user_789"

      Sigra.MockRepo
      |> expect(:delete_all, fn query ->
        assert inspect(query) =~ "UserSession"
        {3, nil}
      end)

      assert {3, nil} = EctoStore.delete_all_for_user(user_id, @opts)
    end

    test "accepts :except_token option to exclude current session" do
      user_id = "user_789"
      except_token = :crypto.hash(:sha256, "keep-this")

      Sigra.MockRepo
      |> expect(:delete_all, fn query ->
        query_string = inspect(query)
        assert query_string =~ "UserSession"
        {2, nil}
      end)

      assert {2, nil} = EctoStore.delete_all_for_user(user_id, Keyword.merge(@opts, except_token: except_token))
    end
  end

  describe "update_activity/3" do
    test "updates last_active_at" do
      hashed_token = :crypto.hash(:sha256, "active-session")

      Sigra.MockRepo
      |> expect(:update_all, fn query, updates ->
        assert inspect(query) =~ "UserSession"
        assert Keyword.has_key?(updates[:set], :last_active_at)
        {1, nil}
      end)

      assert :ok = EctoStore.update_activity(hashed_token, %{}, @opts)
    end

    test "returns {:error, :not_found} when no rows updated" do
      hashed_token = :crypto.hash(:sha256, "gone-session")

      Sigra.MockRepo
      |> expect(:update_all, fn _query, _updates ->
        {0, nil}
      end)

      assert {:error, :not_found} = EctoStore.update_activity(hashed_token, %{}, @opts)
    end
  end

  describe "update_active_organization/3" do
    test "writes the column and returns refreshed Session for a valid session + org_id" do
      hashed_token = :crypto.hash(:sha256, "org-write-session")
      org_id = Ecto.UUID.generate()

      session = %Session{
        id: 1,
        user_id: Ecto.UUID.generate(),
        hashed_token: hashed_token,
        type: :standard,
        active_organization_id: nil
      }

      Sigra.MockRepo
      |> expect(:update_all, fn query, set: updates ->
        assert inspect(query) =~ "UserSession"
        assert updates == [active_organization_id: org_id]
        {1, nil}
      end)

      assert {:ok, %Session{active_organization_id: ^org_id}} =
               EctoStore.update_active_organization(session, org_id, @opts)
    end

    test "clears the column when passed nil org_id" do
      hashed_token = :crypto.hash(:sha256, "org-clear-session")
      previous_org_id = Ecto.UUID.generate()

      session = %Session{
        id: 2,
        user_id: Ecto.UUID.generate(),
        hashed_token: hashed_token,
        type: :standard,
        active_organization_id: previous_org_id
      }

      Sigra.MockRepo
      |> expect(:update_all, fn _query, set: updates ->
        assert updates == [active_organization_id: nil]
        {1, nil}
      end)

      assert {:ok, %Session{active_organization_id: nil}} =
               EctoStore.update_active_organization(session, nil, @opts)
    end

    test "is a no-op when org_id equals the current value (no DB write)" do
      hashed_token = :crypto.hash(:sha256, "noop-session")
      org_id = Ecto.UUID.generate()

      session = %Session{
        id: 3,
        user_id: Ecto.UUID.generate(),
        hashed_token: hashed_token,
        type: :standard,
        active_organization_id: org_id
      }

      # MockRepo gets NO expect(:update_all, ...) call — if the impl tries to
      # write, verify_on_exit! will fail the test.
      assert {:ok, ^session} = EctoStore.update_active_organization(session, org_id, @opts)
    end

    test "no-op short-circuit also covers the nil → nil case" do
      hashed_token = :crypto.hash(:sha256, "nil-noop-session")

      session = %Session{
        id: 4,
        user_id: Ecto.UUID.generate(),
        hashed_token: hashed_token,
        type: :standard,
        active_organization_id: nil
      }

      # No repo expectation — the short-circuit must skip the write.
      assert {:ok, ^session} = EctoStore.update_active_organization(session, nil, @opts)
    end

    test "returns {:error, :not_found} when the underlying row is gone" do
      hashed_token = :crypto.hash(:sha256, "gone-org-session")
      org_id = Ecto.UUID.generate()

      session = %Session{
        id: 5,
        user_id: Ecto.UUID.generate(),
        hashed_token: hashed_token,
        type: :standard,
        active_organization_id: nil
      }

      Sigra.MockRepo
      |> expect(:update_all, fn _query, _updates -> {0, nil} end)

      assert {:error, :not_found} =
               EctoStore.update_active_organization(session, org_id, @opts)
    end
  end

  describe "update_sudo/3" do
    test "updates sudo_at timestamp" do
      hashed_token = :crypto.hash(:sha256, "sudo-session")
      sudo_at = DateTime.utc_now()

      Sigra.MockRepo
      |> expect(:update_all, fn query, updates ->
        assert inspect(query) =~ "UserSession"
        assert Keyword.has_key?(updates[:set], :sudo_at)
        {1, nil}
      end)

      assert :ok = EctoStore.update_sudo(hashed_token, sudo_at, @opts)
    end

    test "returns {:error, :not_found} when no rows updated" do
      hashed_token = :crypto.hash(:sha256, "no-sudo-session")
      sudo_at = DateTime.utc_now()

      Sigra.MockRepo
      |> expect(:update_all, fn _query, _updates ->
        {0, nil}
      end)

      assert {:error, :not_found} = EctoStore.update_sudo(hashed_token, sudo_at, @opts)
    end
  end
end
