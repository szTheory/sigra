defmodule Sigra.ImpersonationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Admin.Scope, as: AdminScope
  alias Sigra.Impersonation
  alias Sigra.Session

  defmodule TestUser do
    defstruct [:id, :email, :organization_ids]
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  setup :verify_on_exit!

  @config %Sigra.Config{
    repo: Sigra.MockRepo,
    user_schema: TestUser,
    scope_module: TestScope,
    session: [
      store: Sigra.MockSessionStore,
      idle_timeout: 1_800,
      absolute_timeout: 86_400,
      impersonation_idle_timeout: 900,
      impersonation_absolute_timeout: 1_800,
      session_schema: TestUser
    ]
  }

  defp admin_scope(mode, admin_user, organization_id \\ nil) do
    organization =
      case organization_id do
        nil -> nil
        id -> %{id: id, slug: "org-#{id}", name: "Org #{id}"}
      end

    %AdminScope{
      mode: mode,
      scope: %TestScope{user: admin_user, active_organization: nil, membership: nil, impersonating_from: nil},
      organization: organization,
      organization_id: organization_id,
      organization_slug: organization && organization.slug,
      platform_admin?: mode == :global,
      admin_org_ids: if(organization_id, do: [organization_id], else: [])
    }
  end

  defp session(user_id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    struct(
      %Session{
        id: attrs[:id] || 1,
        user_id: user_id,
        token: attrs[:token],
        hashed_token: attrs[:hashed_token] || "hashed-session-token",
        type: attrs[:type] || :standard,
        last_active_at: Map.get(attrs, :last_active_at, now),
        inserted_at: Map.get(attrs, :inserted_at, now),
        active_organization_id: Map.get(attrs, :active_organization_id),
        sudo_at: Map.get(attrs, :sudo_at)
      },
      Map.drop(attrs, [:id, :token, :hashed_token, :type, :last_active_at, :inserted_at, :active_organization_id, :sudo_at])
    )
  end

  describe "start/5" do
    test "platform admin may impersonate an allowed user and receives a restorable result" do
      admin = %TestUser{id: "admin-1", email: "admin@example.com"}
      target = %TestUser{id: "user-1", email: "user@example.com"}
      admin_session = session(admin.id, %{id: 11, hashed_token: "admin-hash"})
      impersonation_session = session(target.id, %{id: 22, token: "impersonation-raw", hashed_token: "impersonation-hash"})

      Sigra.MockSessionStore
      |> expect(:create, fn user_id, metadata, _opts ->
        assert user_id == target.id
        assert metadata.type == :standard
        assert metadata.impersonator_user_id == admin.id
        assert metadata.impersonator_session_id == admin_session.id
        {:ok, impersonation_session}
      end)

      assert {:ok, result} =
               Impersonation.start(
                 @config,
                 admin_scope(:global, admin),
                 admin_session,
                 target,
                 admin_token: "admin-raw-token"
               )

      assert result.session == impersonation_session
      assert result.restore == {:admin_session, "admin-raw-token"}
      assert result.mode == :impersonating
    end

    test "org admin may impersonate a user reachable in the resolved organization scope" do
      admin = %TestUser{id: "admin-2", email: "org-admin@example.com"}
      target = %TestUser{id: "user-2", email: "member@example.com", organization_ids: ["org-1"]}
      admin_session = session(admin.id, %{id: 12, hashed_token: "org-admin-hash"})
      impersonation_session = session(target.id, %{id: 23, token: "impersonation-raw", hashed_token: "impersonation-hash"})

      Sigra.MockSessionStore
      |> expect(:create, fn user_id, metadata, _opts ->
        assert user_id == target.id
        assert metadata.impersonator_user_id == admin.id
        {:ok, impersonation_session}
      end)

      assert {:ok, %{session: ^impersonation_session}} =
               Impersonation.start(
                 @config,
                 admin_scope(:organization, admin, "org-1"),
                 admin_session,
                 target,
                 admin_token: "admin-raw-token"
               )
    end

    test "org admin is denied when the target user is outside the resolved organization scope" do
      admin = %TestUser{id: "admin-3", email: "org-admin@example.com"}
      target = %TestUser{id: "user-3", email: "outsider@example.com", organization_ids: ["org-2"]}
      admin_session = session(admin.id, %{id: 13, hashed_token: "org-admin-hash"})

      assert {:error, :not_allowed} =
               Impersonation.start(
                 @config,
                 admin_scope(:organization, admin, "org-1"),
                 admin_session,
                 target,
                 admin_token: "admin-raw-token"
               )
    end

    test "denies nested impersonation when the current scope already carries impersonating_from" do
      admin = %TestUser{id: "admin-4", email: "admin@example.com"}
      target = %TestUser{id: "user-4", email: "user@example.com"}
      already_impersonating_scope = %AdminScope{
        admin_scope(:global, admin)
        | scope: %TestScope{
            user: target,
            active_organization: nil,
            membership: nil,
            impersonating_from: admin
          }
      }

      assert {:error, :already_impersonating} =
               Impersonation.start(
                 @config,
                 already_impersonating_scope,
                 session(admin.id, %{id: 14, hashed_token: "admin-hash"}),
                 target,
                 admin_token: "admin-raw-token"
               )
    end
  end

  describe "stop/3" do
    test "stops impersonation by deleting the effective-user session and returning an explicit restore decision" do
      target = %TestUser{id: "user-5", email: "user@example.com"}
      admin = %TestUser{id: "admin-5", email: "admin@example.com"}
      impersonation_session = session(target.id, %{id: 25, hashed_token: "impersonation-hash", impersonator_user_id: admin.id})
      scope = %TestScope{user: target, active_organization: nil, membership: nil, impersonating_from: admin}

      Sigra.MockSessionStore
      |> expect(:delete, fn "impersonation-hash", _opts -> :ok end)

      assert {:ok, %{restore: {:admin_session, "admin-raw-token"}, session_deleted?: true}} =
               Impersonation.stop(
                 @config,
                 scope,
                 impersonation_session,
                 admin_token: "admin-raw-token"
               )
    end
  end

  describe "evaluate_timeout/3" do
    test "returns an explicit restore decision when the impersonation session is idle-expired" do
      target = %TestUser{id: "user-6", email: "user@example.com"}
      admin = %TestUser{id: "admin-6", email: "admin@example.com"}

      expired_session =
        session(target.id, %{
          id: 26,
          hashed_token: "impersonation-hash",
          impersonator_user_id: admin.id,
          last_active_at: DateTime.utc_now() |> DateTime.add(-1_801, :second),
          inserted_at: DateTime.utc_now() |> DateTime.add(-1_000, :second)
        })

      scope = %TestScope{user: target, active_organization: nil, membership: nil, impersonating_from: admin}

      assert {:ok, %{expired?: true, action: :restore_admin, restore: {:admin_session, "admin-raw-token"}}} =
               Impersonation.evaluate_timeout(
                 @config,
                 scope,
                 expired_session,
                 admin_token: "admin-raw-token"
               )
    end
  end
end
