defmodule Sigra.Organizations.InvitationsTest do
  @moduledoc """
  Phase 17 Plan 03 unit tests for `Sigra.Organizations.Invitations`.

  Follows the Mox-based unit-test style established in
  `Sigra.Organizations.ContextTest` — inline test schemas, `Sigra.MockRepo`
  for DB calls, `Sigra.MockRateLimiter` for rate-limit layer, in-memory
  `TestEmailsModule` that forwards to the test process mailbox.
  """

  use ExUnit.Case, async: true

  import Mox
  import ExUnit.CaptureLog

  alias Sigra.Organizations.Invitations

  # ---------- Inline schemas ----------

  defmodule TestOrg do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "organizations" do
      field :name, :string
      field :slug, :string
      timestamps(type: :utc_datetime)
    end
  end

  defmodule TestUser do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "users" do
      field :email, :string
    end
  end

  defmodule TestMembership do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "organization_memberships" do
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :organization_id, :binary_id
      field :user_id, :binary_id
    end
  end

  defmodule TestInvitation do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "organization_invitations" do
      field :email, :string
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
      field :hashed_token, :binary
      field :expires_at, :utc_datetime
      field :accepted_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :organization_id, :binary_id
      field :invited_by_id, :binary_id
      field :revoked_by_id, :binary_id
      timestamps(type: :utc_datetime)
    end

    def changeset(invitation, attrs) do
      invitation
      |> cast(attrs, [
        :email,
        :role,
        :hashed_token,
        :expires_at,
        :accepted_at,
        :revoked_at,
        :organization_id,
        :invited_by_id,
        :revoked_by_id
      ])
      |> validate_required([:email, :role, :expires_at, :organization_id])
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership]
  end

  defmodule TestEmailsModule do
    def organization_invitation(inv, org, inviter, url) do
      send(self(), {:email_sent, inv, org, inviter, url})
      :ok
    end
  end

  # ---------- Fixtures ----------

  setup :verify_on_exit!

  defp build_user(attrs \\ %{}) do
    Map.merge(
      %TestUser{id: Ecto.UUID.generate(), email: "user@example.com"},
      attrs
    )
  end

  defp build_org(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Map.merge(
      %TestOrg{
        id: Ecto.UUID.generate(),
        name: "Acme Corp",
        slug: "acme-corp",
        inserted_at: now,
        updated_at: now
      },
      attrs
    )
  end

  defp owner_scope(user, org) do
    %TestScope{
      user: user,
      active_organization: org,
      membership: %TestMembership{
        id: Ecto.UUID.generate(),
        role: :owner,
        organization_id: org.id,
        user_id: user.id
      }
    }
  end

  defp admin_scope(user, org) do
    %TestScope{
      user: user,
      active_organization: org,
      membership: %TestMembership{
        id: Ecto.UUID.generate(),
        role: :admin,
        organization_id: org.id,
        user_id: user.id
      }
    }
  end

  defp member_scope(user, org) do
    %TestScope{
      user: user,
      active_organization: org,
      membership: %TestMembership{
        id: Ecto.UUID.generate(),
        role: :member,
        organization_id: org.id,
        user_id: user.id
      }
    }
  end

  defp base_config(overrides \\ %{}) do
    allow_rate_limiter = Map.get(overrides, :allow_rate_limiter?, true)

    if allow_rate_limiter do
      Sigra.MockRateLimiter
      |> stub(:check_rate, fn _key, _limit, _window -> {:allow, 1} end)
    end

    Map.merge(
      %{
        repo: Sigra.MockRepo,
        schemas: %{
          organization: TestOrg,
          membership: TestMembership,
          invitation: TestInvitation,
          user: TestUser,
          scope: TestScope
        },
        roles: [:owner, :admin, :member],
        owner_role: :owner,
        audit_schema: nil,
        hooks: [],
        invitation_ttl: :timer.hours(24 * 7),
        invitation_rate_limit_per_user: {20, :timer.hours(24)},
        invitation_rate_limit_per_org: {50, :timer.hours(24)},
        invitation_cleanup_retention_days: 30,
        emails_module: nil,
        secret_key_base: String.duplicate("a", 64),
        url_builder: fn encoded -> "https://example.com/invites/" <> encoded <> "/accept" end,
        rate_limiter: Sigra.MockRateLimiter
      },
      Map.drop(overrides, [:allow_rate_limiter?])
    )
  end

  # ---------- create/2 ----------

  describe "create/2" do
    test "happy path returns {:ok, invitation} with hashed_token and expires_at set" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      Sigra.MockRepo
      |> expect(:transact, fn %Ecto.Multi{} = _multi ->
        inv = %TestInvitation{
          id: Ecto.UUID.generate(),
          email: "a@b.com",
          role: :member,
          organization_id: org.id,
          invited_by_id: owner.id,
          hashed_token: :crypto.hash(:sha256, "fake"),
          expires_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
          accepted_at: nil,
          revoked_at: nil
        }

        {:ok, %{invitation: inv, revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, invitation} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })

      assert %TestInvitation{} = invitation
      assert is_binary(invitation.hashed_token)
      assert byte_size(invitation.hashed_token) == 32
      assert invitation.accepted_at == nil
      assert invitation.revoked_at == nil
      assert Map.get(invitation, :__encoded_token__) |> is_binary()
    end

    test "raw token is never persisted — only hashed_token goes to DB" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      Sigra.MockRepo
      |> expect(:transact, fn %Ecto.Multi{} = multi ->
        # Inspect the insert changeset for the :invitation step.
        ops = Ecto.Multi.to_list(multi)
        {_, {:insert, cs, _}} = Enum.find(ops, fn {name, _} -> name == :invitation end)
        assert is_binary(cs.changes.hashed_token)
        assert byte_size(cs.changes.hashed_token) == 32
        # The raw token must not appear anywhere in the changeset's changes.
        refute Map.has_key?(cs.changes, :raw_token)
        {:ok, %{invitation: struct!(TestInvitation, cs.changes), revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "default TTL sets expires_at ~7 days in the future" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      Sigra.MockRepo
      |> expect(:transact, fn %Ecto.Multi{} = multi ->
        ops = Ecto.Multi.to_list(multi)
        {_, {:insert, cs, _}} = Enum.find(ops, fn {name, _} -> name == :invitation end)
        now = DateTime.utc_now()
        expires_at = cs.changes.expires_at
        delta_s = DateTime.diff(expires_at, now, :second)
        # 7 days - small drift
        assert delta_s >= 7 * 86_400 - 5
        assert delta_s <= 7 * 86_400 + 5
        {:ok, %{invitation: struct!(TestInvitation, cs.changes), revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "custom TTL is respected" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      # 3 hours
      ttl_ms = :timer.hours(3)
      config = base_config(%{invitation_ttl: ttl_ms})

      Sigra.MockRepo
      |> expect(:transact, fn %Ecto.Multi{} = multi ->
        ops = Ecto.Multi.to_list(multi)
        {_, {:insert, cs, _}} = Enum.find(ops, fn {name, _} -> name == :invitation end)
        now = DateTime.utc_now()
        delta_s = DateTime.diff(cs.changes.expires_at, now, :second)
        assert delta_s >= div(ttl_ms, 1000) - 5
        assert delta_s <= div(ttl_ms, 1000) + 5
        {:ok, %{invitation: struct!(TestInvitation, cs.changes), revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "long TTL (>30d) emits Logger.warning via __warn_long_invitation_ttl__" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{invitation_ttl: :timer.hours(24 * 60)})

      Sigra.MockRepo
      |> expect(:transact, fn %Ecto.Multi{} = _multi ->
        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 0}}}
      end)

      log =
        capture_log(fn ->
          assert {:ok, _} =
                   Invitations.create(config, %{
                     organization_id: org.id,
                     email: "a@b.com",
                     role: :member,
                     invited_by_id: owner.id,
                     actor: scope
                   })
        end)

      assert log =~ "exceeds"
      assert log =~ "30-day"
    end

    test "actor with :member role returns {:error, :unauthorized}" do
      owner = build_user()
      org = build_org()
      scope = member_scope(owner, org)
      config = base_config()

      # No :transact expected — authorization must fail before Multi runs.
      assert {:error, :unauthorized} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "actor with :owner role succeeds" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      Sigra.MockRepo
      |> expect(:transact, fn _multi ->
        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "actor with :admin role succeeds" do
      admin = build_user()
      org = build_org()
      scope = admin_scope(admin, org)
      config = base_config()

      Sigra.MockRepo
      |> expect(:transact, fn _multi ->
        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: admin.id,
                 actor: scope
               })
    end

    test "per-user rate limit denied → {:error, :rate_limited_user}, no Multi runs" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{allow_rate_limiter?: false})

      Sigra.MockRateLimiter
      |> expect(:check_rate, fn key, _limit, _window ->
        assert key =~ "sigra:org_invite_create:user:"
        {:deny, 20}
      end)

      # :transact must NOT be called
      assert {:error, :rate_limited_user} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "per-org rate limit denied → {:error, :rate_limited_org}, no Multi runs" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{allow_rate_limiter?: false})

      parent = self()

      Sigra.MockRateLimiter
      |> expect(:check_rate, 2, fn key, _limit, _window ->
        cond do
          String.starts_with?(key, "sigra:org_invite_create:user:") ->
            send(parent, :user_allowed)
            {:allow, 1}

          String.starts_with?(key, "sigra:org_invite_create:org:") ->
            {:deny, 50}

          true ->
            flunk("unexpected rate-limit key: #{inspect(key)}")
        end
      end)

      assert {:error, :rate_limited_org} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })

      assert_received :user_allowed
    end

    test ":infinity disables user rate limit layer" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{
        allow_rate_limiter?: false,
        invitation_rate_limit_per_user: :infinity
      })

      # Only the org key should be checked — user layer is skipped entirely.
      Sigra.MockRateLimiter
      |> expect(:check_rate, fn key, _limit, _window ->
        assert key =~ "sigra:org_invite_create:org:"
        {:allow, 1}
      end)

      Sigra.MockRepo
      |> expect(:transact, fn _multi ->
        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test ":infinity on both rate limits skips rate limiter entirely" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{
        allow_rate_limiter?: false,
        invitation_rate_limit_per_user: :infinity,
        invitation_rate_limit_per_org: :infinity
      })

      # Rate limiter stub should see ZERO calls.
      Sigra.MockRepo
      |> expect(:transact, fn _multi ->
        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "D-05 re-invite Multi contains :revoke_prior step before :invitation" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      Sigra.MockRepo
      |> expect(:transact, fn %Ecto.Multi{} = multi ->
        names = Enum.map(Ecto.Multi.to_list(multi), fn {name, _} -> name end)
        assert :revoke_prior in names
        assert :invitation in names
        revoke_idx = Enum.find_index(names, &(&1 == :revoke_prior))
        insert_idx = Enum.find_index(names, &(&1 == :invitation))
        assert revoke_idx < insert_idx

        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 1}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :admin,
                 invited_by_id: owner.id,
                 actor: scope
               })
    end

    test "after-commit email delivery apply-calls emails_module" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{emails_module: TestEmailsModule})

      inv_id = Ecto.UUID.generate()

      Sigra.MockRepo
      |> expect(:transact, fn _multi ->
        {:ok,
         %{
           invitation: %TestInvitation{
             id: inv_id,
             email: "a@b.com",
             role: :member,
             organization_id: org.id,
             invited_by_id: owner.id,
             hashed_token: :crypto.hash(:sha256, "fake"),
             expires_at: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
           },
           revoke_prior: %{revoked_count: 0}
         }}
      end)
      |> expect(:get!, fn TestOrg, _id -> org end)
      |> expect(:get!, fn TestUser, _id -> owner end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })

      assert_received {:email_sent, _inv, _org, _inviter, url}
      assert String.starts_with?(url, "https://example.com/invites/")
    end

    test "nil emails_module skips email delivery gracefully" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{emails_module: nil})

      Sigra.MockRepo
      |> expect(:transact, fn _multi ->
        {:ok, %{invitation: %TestInvitation{id: Ecto.UUID.generate()}, revoke_prior: %{revoked_count: 0}}}
      end)

      assert {:ok, _} =
               Invitations.create(config, %{
                 organization_id: org.id,
                 email: "a@b.com",
                 role: :member,
                 invited_by_id: owner.id,
                 actor: scope
               })

      refute_received {:email_sent, _, _, _, _}
    end

    test "nil secret_key_base raises RuntimeError with clear message" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config(%{secret_key_base: nil})

      assert_raise RuntimeError, ~r/secret_key_base/, fn ->
        Invitations.create(config, %{
          organization_id: org.id,
          email: "a@b.com",
          role: :member,
          invited_by_id: owner.id,
          actor: scope
        })
      end
    end
  end

  # ---------- revoke/3 ----------

  describe "revoke/3" do
    test "happy path: owner revokes pending invitation → {:ok, inv} with revoked_at set" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      inv_id = Ecto.UUID.generate()

      inv = %TestInvitation{
        id: inv_id,
        email: "a@b.com",
        role: :member,
        organization_id: org.id,
        invited_by_id: owner.id,
        accepted_at: nil,
        revoked_at: nil
      }

      revoked_inv = %{inv | revoked_at: DateTime.utc_now() |> DateTime.truncate(:second), revoked_by_id: owner.id}

      Sigra.MockRepo
      |> expect(:get, fn TestInvitation, ^inv_id -> inv end)
      |> expect(:transact, fn %Ecto.Multi{} = _multi ->
        {:ok, %{invitation: revoked_inv}}
      end)

      assert {:ok, ^revoked_inv} = Invitations.revoke(config, inv_id, scope)
    end

    test "admin can revoke" do
      admin = build_user()
      org = build_org()
      scope = admin_scope(admin, org)
      config = base_config()

      inv_id = Ecto.UUID.generate()

      inv = %TestInvitation{
        id: inv_id,
        email: "a@b.com",
        role: :member,
        organization_id: org.id,
        accepted_at: nil,
        revoked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get, fn TestInvitation, ^inv_id -> inv end)
      |> expect(:transact, fn _multi -> {:ok, %{invitation: inv}} end)

      assert {:ok, _} = Invitations.revoke(config, inv_id, scope)
    end

    test "already-accepted invitation returns {:error, :not_pending}" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      inv_id = Ecto.UUID.generate()

      inv = %TestInvitation{
        id: inv_id,
        email: "a@b.com",
        role: :member,
        organization_id: org.id,
        accepted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        revoked_at: nil
      }

      Sigra.MockRepo
      |> expect(:get, fn TestInvitation, ^inv_id -> inv end)

      # :transact NOT expected — guard rejects before Multi runs.
      assert {:error, :not_pending} = Invitations.revoke(config, inv_id, scope)
    end

    test "already-revoked invitation returns {:error, :not_pending}" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      inv_id = Ecto.UUID.generate()

      inv = %TestInvitation{
        id: inv_id,
        email: "a@b.com",
        role: :member,
        organization_id: org.id,
        accepted_at: nil,
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      Sigra.MockRepo
      |> expect(:get, fn TestInvitation, ^inv_id -> inv end)

      assert {:error, :not_pending} = Invitations.revoke(config, inv_id, scope)
    end

    test "member actor returns {:error, :unauthorized}, no DB call" do
      member = build_user()
      org = build_org()
      scope = member_scope(member, org)
      config = base_config()

      inv_id = Ecto.UUID.generate()

      # No :get and no :transact expected.
      assert {:error, :unauthorized} = Invitations.revoke(config, inv_id, scope)
    end

    test "missing invitation returns {:error, :not_found}" do
      owner = build_user()
      org = build_org()
      scope = owner_scope(owner, org)
      config = base_config()

      inv_id = Ecto.UUID.generate()

      Sigra.MockRepo
      |> expect(:get, fn TestInvitation, ^inv_id -> nil end)

      assert {:error, :not_found} = Invitations.revoke(config, inv_id, scope)
    end
  end

  # ---------- list_pending/2 ----------

  describe "list_pending/2" do
    test "delegates to config.repo.all/1 with a query" do
      org = build_org()
      config = base_config()

      inv1 = %TestInvitation{id: Ecto.UUID.generate(), email: "a@b.com", organization_id: org.id}

      Sigra.MockRepo
      |> expect(:all, fn %Ecto.Query{} = _query -> [inv1] end)

      assert Invitations.list_pending(config, org) == [inv1]
    end

    test "accepts a bare id" do
      org = build_org()
      config = base_config()

      Sigra.MockRepo
      |> expect(:all, fn %Ecto.Query{} = _query -> [] end)

      assert Invitations.list_pending(config, org.id) == []
    end
  end

  describe "list_pending_for_user/2" do
    test "delegates to config.repo.all/1 with user email filter" do
      user = build_user(%{email: "alice@example.com"})
      config = base_config()

      Sigra.MockRepo
      |> expect(:all, fn %Ecto.Query{} = _query -> [] end)

      assert Invitations.list_pending_for_user(config, user) == []
    end
  end
end
