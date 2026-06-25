defmodule Example.Demo.SeedsTest do
  @moduledoc """
  Behavioral smoke + invariant tests for the demo seed orchestrator.

  Runs `Example.Demo.Seeds.run/0` directly inside the sandbox transaction
  (the orchestrator module has no env guard — only the seeds.exs SCRIPT does),
  so all writes roll back at end of test.

  Covers:
  - SEED-01 idempotency (run twice -> identical counts)
  - SEED-02 nine personas + org/membership/invitation shape
  - SEED-03 rough-edge persona states (locked, scheduled-deletion, oauth identity, mfa, passkey)
  - SEED-04 audit liveness (>=25 rows, >=6 distinct actions, admin-tied) [FIXT-01]
  - SEED-06 security posture (argon2id hashes, deterministic totp secret)
  - Bulk-cohort idempotency + exclusion (FIXT-02)
  - Multi-session/multi-org breadth on admin persona (FIXT-02, D-11)
  """
  use Example.DataCase, async: false

  alias Example.Demo.Seeds
  alias Example.Demo.Personas
  alias Example.Accounts
  alias Example.Accounts.User
  alias Example.Accounts.Organization
  alias Example.Accounts.OrganizationMembership
  alias Example.Accounts.OrganizationInvitation
  alias Example.Accounts.UserMFACredential
  alias Example.Accounts.UserPasskey
  alias Example.Accounts.UserSession
  alias Example.Accounts.EnterpriseConnection
  alias Example.Accounts.UserIdentity
  alias Example.Accounts.AuditEvent

  @demo_domain "@demo.tasklane.test"

  # Pitfall-3 resolution (FIXT-02): The bulk cohort uses emails with the
  # `loadtest-` local-part prefix on the same @demo.tasklane.test domain.
  # BOTH persona-count queries that glob `%@demo.tasklane.test` must exclude
  # `loadtest-%` emails so `demo_users == length(Personas.all())` stays green.
  # We apply `not like(u.email, "loadtest-%")` to the query in snapshot_counts/0
  # (line ~40) AND to the SEED-02/03 catalog count (line ~122), which are two
  # independent queries. The bulk cohort is counted separately in its own test.
  @bulk_cohort_size 36

  defp demo_user!(email), do: Accounts.get_user_by_email(email)

  # Counts scoped to demo data so the assertions are unaffected by any
  # incidental rows another part of the suite might have left in a shared
  # (non-async) sandbox checkout.
  # NOTE: `demo_users` counts only persona-domain users, EXCLUDING the loadtest-*
  # bulk cohort (Pitfall-3 fix: both glob queries apply `not like(u.email, "loadtest-%")`).
  defp snapshot_counts do
    demo_user_ids =
      Repo.all(
        from u in User,
          where: like(u.email, ^"%#{@demo_domain}") and not like(u.email, "loadtest-%"),
          select: u.id
      )

    %{
      demo_users: length(demo_user_ids),
      organizations:
        Repo.aggregate(
          from(o in Organization, where: o.slug in ^["acme-corp", "beta-labs"]),
          :count
        ),
      memberships:
        Repo.aggregate(
          from(m in OrganizationMembership, where: m.user_id in ^demo_user_ids),
          :count
        ),
      invitations:
        Repo.aggregate(
          from(i in OrganizationInvitation, where: i.email == ^"invited@demo.tasklane.test"),
          :count
        ),
      expired_invitations:
        Repo.aggregate(
          from(i in OrganizationInvitation,
            where: i.email == ^"expired-invite@demo.tasklane.test"
          ),
          :count
        ),
      mfa_credentials:
        Repo.aggregate(
          from(c in UserMFACredential, where: c.user_id in ^demo_user_ids),
          :count
        ),
      passkeys:
        Repo.aggregate(
          from(p in UserPasskey, where: p.user_id in ^demo_user_ids),
          :count
        ),
      enterprise_connections:
        Repo.aggregate(
          from(e in EnterpriseConnection, where: e.display_name == ^"Acme Corp SSO"),
          :count
        ),
      user_identities:
        Repo.aggregate(
          from(ui in UserIdentity, where: ui.user_id in ^demo_user_ids),
          :count
        ),
      audit_events:
        Repo.aggregate(
          from(a in AuditEvent, where: a.effective_user_id in ^demo_user_ids),
          :count
        )
    }
  end

  # PW-03: seeds-smoke check
  describe "idempotency (SEED-01)" do
    test "running run/0 twice yields identical counts and does not error" do
      assert :ok = Seeds.run()
      first = snapshot_counts()

      assert :ok = Seeds.run()
      second = snapshot_counts()

      assert first == second,
             "second run/0 changed counts: first=#{inspect(first)} second=#{inspect(second)}"

      # And the first run actually produced data (guards against a vacuous pass).
      assert first.demo_users == length(Personas.all())
      assert first.organizations == 2
    end
  end

  # PW-03: seeds-smoke check
  describe "persona catalog + states (SEED-02, SEED-03)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    test "seeds exactly the @demo.tasklane.test persona catalog of users" do
      # Pitfall-3 fix: exclude loadtest-* bulk cohort from this count so it
      # equals length(Personas.all()) — both domain-glob queries must apply
      # the same exclusion (see snapshot_counts/0 and this query).
      count =
        Repo.aggregate(
          from(u in User,
            where: like(u.email, ^"%#{@demo_domain}") and not like(u.email, "loadtest-%")
          ),
          :count
        )

      assert count == length(Personas.all())

      for persona <- Personas.all() do
        assert demo_user!(persona.email), "missing seeded user #{persona.email}"
      end
    end

    test "dave is the locked-out persona" do
      dave = demo_user!("dave@demo.tasklane.test")

      assert dave.failed_login_attempts == 5
      refute is_nil(dave.locked_at)
      assert is_nil(dave.hashed_password)
    end

    test "frank is the scheduled-deletion persona" do
      frank = demo_user!("frank@demo.tasklane.test")

      refute is_nil(frank.deleted_at)
      refute is_nil(frank.scheduled_deletion_at)
    end

    test "grace is a deletion-scheduled Acme member" do
      acme = Repo.get_by!(Organization, slug: "acme-corp")
      grace = demo_user!("grace@demo.tasklane.test")

      refute is_nil(grace.deleted_at)
      refute is_nil(grace.scheduled_deletion_at)

      assert membership_role(grace.id, acme.id) == :member,
             "grace should be an Acme Corp member so in-roster deletion pill renders"
    end

    test "pat has no MFA credential but has a passkey row" do
      pat = demo_user!("pat@demo.tasklane.test")

      mfa_count =
        Repo.aggregate(from(c in UserMFACredential, where: c.user_id == ^pat.id), :count)

      assert mfa_count == 0

      passkey_count =
        Repo.aggregate(from(p in UserPasskey, where: p.user_id == ^pat.id), :count)

      assert passkey_count >= 1
    end

    test "exactly one expired invitation for expired-invite@demo.tasklane.test" do
      expired =
        Repo.all(
          from i in OrganizationInvitation,
            where:
              i.email == ^"expired-invite@demo.tasklane.test" and
                is_nil(i.accepted_at) and is_nil(i.revoked_at)
        )

      assert length(expired) == 1
      expired_row = hd(expired)

      assert DateTime.compare(expired_row.expires_at, DateTime.utc_now()) == :lt,
             "expired invitation expires_at should be in the past"
    end

    test "carol has a GitHub OAuth identity" do
      carol = demo_user!("carol@demo.tasklane.test")

      identity =
        Repo.one(
          from ui in UserIdentity,
            where: ui.user_id == ^carol.id and ui.provider == ^"github"
        )

      assert identity, "expected carol to have a github user_identity row"
    end

    test "admin and bob have a totp MFA credential with the deterministic secret" do
      for email <- ["admin@demo.tasklane.test", "bob@demo.tasklane.test"] do
        user = demo_user!(email)

        credential =
          Repo.one(
            from c in UserMFACredential,
              where: c.user_id == ^user.id and c.type == ^"totp"
          )

        assert credential, "expected #{email} to have a totp MFA credential"

        assert credential.encrypted_secret == Personas.demo_totp_secret(),
               "#{email} totp secret should match the deterministic demo secret"
      end
    end

    test "admin has at least one passkey row" do
      admin = demo_user!("admin@demo.tasklane.test")

      passkey_count =
        Repo.aggregate(
          from(p in UserPasskey, where: p.user_id == ^admin.id),
          :count
        )

      assert passkey_count >= 1
    end

    test "Acme Corp and Beta Labs organizations exist" do
      assert Repo.get_by(Organization, slug: "acme-corp")
      assert Repo.get_by(Organization, slug: "beta-labs")
    end

    test "exactly one pending invitation to invited@demo.tasklane.test" do
      pending =
        Repo.all(
          from i in OrganizationInvitation,
            where:
              i.email == ^"invited@demo.tasklane.test" and
                is_nil(i.accepted_at) and is_nil(i.revoked_at)
        )

      assert length(pending) == 1
    end

    test "membership shape: admin in 2 orgs, alice+carol+dave in Acme, bob owns Beta" do
      acme = Repo.get_by!(Organization, slug: "acme-corp")
      beta = Repo.get_by!(Organization, slug: "beta-labs")

      admin = demo_user!("admin@demo.tasklane.test")
      alice = demo_user!("alice@demo.tasklane.test")
      carol = demo_user!("carol@demo.tasklane.test")
      dave = demo_user!("dave@demo.tasklane.test")
      bob = demo_user!("bob@demo.tasklane.test")

      admin_orgs =
        Repo.aggregate(
          from(m in OrganizationMembership, where: m.user_id == ^admin.id),
          :count
        )

      assert admin_orgs == 2

      grace = demo_user!("grace@demo.tasklane.test")

      assert membership_role(alice.id, acme.id) == :member
      assert membership_role(carol.id, acme.id) == :member
      assert membership_role(dave.id, acme.id) == :member
      assert membership_role(admin.id, acme.id) == :owner
      assert membership_role(admin.id, beta.id) == :member
      assert membership_role(bob.id, beta.id) == :owner

      assert membership_role(grace.id, acme.id) == :member,
             "grace should be an Acme member for the roster deletion pill to render"
    end
  end

  describe "audit liveness (SEED-04)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    # FIXT-01: raised from >=15 to >=25 to cross the @default_limit 25 page size,
    # making /admin/audit and the user-detail audit feed paginate for admin.
    test "at least 25 audit events across at least 6 distinct actions, admin-tied (FIXT-01)" do
      admin = demo_user!("admin@demo.tasklane.test")

      admin_tied =
        Repo.aggregate(
          from(a in AuditEvent, where: a.effective_user_id == ^admin.id),
          :count
        )

      assert admin_tied >= 25,
             "expected >=25 self-tied admin audit events for pagination (FIXT-01); got #{admin_tied}"

      distinct_actions =
        Repo.aggregate(
          from(a in AuditEvent,
            where: a.effective_user_id == ^admin.id,
            distinct: a.action,
            select: a.action
          ),
          :count
        )

      assert distinct_actions >= 6,
             "expected >=6 distinct audit action values for admin; got #{distinct_actions}"

      assert admin_tied >= 1,
             "expected at least one audit row tied to admin via effective_user_id"
    end

    test "persona and organization audit rows make non-admin detail screens useful" do
      acme = Repo.get_by!(Organization, slug: "acme-corp")
      alice = demo_user!("alice@demo.tasklane.test")
      dave = demo_user!("dave@demo.tasklane.test")

      alice_tied =
        Repo.aggregate(
          from(a in AuditEvent, where: a.effective_user_id == ^alice.id),
          :count
        )

      assert alice_tied >= 3

      dave_lockout =
        Repo.one(
          from(a in AuditEvent,
            where:
              a.effective_user_id == ^dave.id and
                a.organization_id == ^acme.id and
                a.action == ^"auth.lockout.start"
          )
        )

      assert dave_lockout,
             "expected Acme-scoped lockout evidence so org admin screens show risk state"
    end
  end

  describe "security posture (SEED-06)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    test "a confirmed persona's hashed_password is an argon2id hash" do
      # Alice is confirmed and (unlike dave) retains her hashed password.
      alice = demo_user!("alice@demo.tasklane.test")

      assert is_binary(alice.hashed_password)

      assert String.starts_with?(alice.hashed_password, "$argon2id$"),
             "expected argon2id hash, got prefix #{inspect(String.slice(alice.hashed_password || "", 0, 12))}"
    end
  end

  # FIXT-02: list-scale "ugly" bulk cohort (D-09, D-10)
  # Bulk users use the `loadtest-` local-part prefix on @demo.tasklane.test so
  # BOTH persona-count queries can exclude them via `not like(u.email, "loadtest-%")`.
  describe "bulk user cohort (FIXT-02)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    test "bulk cohort contains exactly @bulk_cohort_size users after run/0" do
      count =
        Repo.aggregate(
          from(u in User, where: like(u.email, "loadtest-%")),
          :count
        )

      assert count == @bulk_cohort_size,
             "expected #{@bulk_cohort_size} bulk cohort users; got #{count}"
    end

    test "bulk cohort emails are absent from Personas.all()" do
      persona_emails = Personas.all() |> Enum.map(& &1.email) |> MapSet.new()

      bulk_emails =
        Repo.all(from u in User, where: like(u.email, "loadtest-%"), select: u.email)

      for email <- bulk_emails do
        refute MapSet.member?(persona_emails, email),
               "loadtest user #{email} should not appear in Personas.all()"
      end
    end

    test "bulk count is stable across two run/0 calls (idempotency — SEED-01, FIXT-02)" do
      # First run already done in setup; run a second time and check count is unchanged.
      assert :ok = Seeds.run()

      count =
        Repo.aggregate(
          from(u in User, where: like(u.email, "loadtest-%")),
          :count
        )

      assert count == @bulk_cohort_size,
             "second run/0 changed bulk count; expected #{@bulk_cohort_size}, got #{count} (no-op idempotency violated)"
    end
  end

  # FIXT-02, D-11: multi-session + multi-org breadth on admin persona.
  # Admin must carry >=2 active UserSession rows AND >=2 OrganizationMembership rows
  # so /admin per-user Sessions and Organizations panels render multiple rows.
  # Breadth uses EXISTING schema fields only (no new columns — D-11).
  describe "multi-session/multi-org breadth (FIXT-02, D-11)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    test "admin persona has >=2 active UserSession rows and >=2 OrganizationMembership rows" do
      admin = demo_user!("admin@demo.tasklane.test")

      session_count =
        Repo.aggregate(
          from(s in UserSession, where: s.user_id == ^admin.id),
          :count
        )

      assert session_count >= 2,
             "admin should have >=2 UserSession rows for FIXT-02 multi-session breadth; got #{session_count}"

      membership_count =
        Repo.aggregate(
          from(m in OrganizationMembership, where: m.user_id == ^admin.id),
          :count
        )

      assert membership_count >= 2,
             "admin should have >=2 OrganizationMembership rows for FIXT-02 multi-org breadth; got #{membership_count}"
    end
  end

  defp membership_role(user_id, org_id) do
    Repo.one(
      from m in OrganizationMembership,
        where: m.user_id == ^user_id and m.organization_id == ^org_id,
        select: m.role
    )
  end
end
