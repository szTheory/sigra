defmodule Example.Demo.SeedsTest do
  @moduledoc """
  Behavioral smoke + invariant tests for the demo seed orchestrator.

  Runs `Example.Demo.Seeds.run/0` directly inside the sandbox transaction
  (the orchestrator module has no env guard — only the seeds.exs SCRIPT does),
  so all writes roll back at end of test.

  Covers:
  - SEED-01 idempotency (run twice -> identical counts)
  - SEED-02 six personas + org/membership/invitation shape
  - SEED-03 rough-edge persona states (locked, scheduled-deletion, oauth identity, mfa, passkey)
  - SEED-04 audit liveness (>=15 rows, >=6 distinct actions, admin-tied)
  - SEED-06 security posture (argon2id hashes, deterministic totp secret)
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
  alias Example.Accounts.EnterpriseConnection
  alias Example.Accounts.UserIdentity
  alias Example.Accounts.AuditEvent

  @demo_domain "@demo.sigra.dev"

  defp demo_user!(email), do: Accounts.get_user_by_email(email)

  # Counts scoped to demo data so the assertions are unaffected by any
  # incidental rows another part of the suite might have left in a shared
  # (non-async) sandbox checkout.
  defp snapshot_counts do
    demo_user_ids =
      Repo.all(from u in User, where: like(u.email, ^"%#{@demo_domain}"), select: u.id)

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
          from(i in OrganizationInvitation, where: i.email == ^"invited@demo.sigra.dev"),
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
      assert first.demo_users == 6
      assert first.organizations == 2
    end
  end

  # PW-03: seeds-smoke check
  describe "six personas + states (SEED-02, SEED-03)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    test "seeds exactly six @demo.sigra.dev users matching the persona catalog" do
      count =
        Repo.aggregate(
          from(u in User, where: like(u.email, ^"%#{@demo_domain}")),
          :count
        )

      assert count == 6

      for persona <- Personas.all() do
        assert demo_user!(persona.email), "missing seeded user #{persona.email}"
      end
    end

    test "dave is the locked-out persona" do
      dave = demo_user!("dave@demo.sigra.dev")

      assert dave.failed_login_attempts == 5
      refute is_nil(dave.locked_at)
      assert is_nil(dave.hashed_password)
    end

    test "frank is the scheduled-deletion persona" do
      frank = demo_user!("frank@demo.sigra.dev")

      refute is_nil(frank.deleted_at)
      refute is_nil(frank.scheduled_deletion_at)
    end

    test "carol has a GitHub OAuth identity" do
      carol = demo_user!("carol@demo.sigra.dev")

      identity =
        Repo.one(
          from ui in UserIdentity,
            where: ui.user_id == ^carol.id and ui.provider == ^"github"
        )

      assert identity, "expected carol to have a github user_identity row"
    end

    test "admin and bob have a totp MFA credential with the deterministic secret" do
      for email <- ["admin@demo.sigra.dev", "bob@demo.sigra.dev"] do
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
      admin = demo_user!("admin@demo.sigra.dev")

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

    test "exactly one pending invitation to invited@demo.sigra.dev" do
      pending =
        Repo.all(
          from i in OrganizationInvitation,
            where:
              i.email == ^"invited@demo.sigra.dev" and
                is_nil(i.accepted_at) and is_nil(i.revoked_at)
        )

      assert length(pending) == 1
    end

    test "membership shape: admin in 2 orgs, alice+carol+dave in Acme, bob owns Beta" do
      acme = Repo.get_by!(Organization, slug: "acme-corp")
      beta = Repo.get_by!(Organization, slug: "beta-labs")

      admin = demo_user!("admin@demo.sigra.dev")
      alice = demo_user!("alice@demo.sigra.dev")
      carol = demo_user!("carol@demo.sigra.dev")
      dave = demo_user!("dave@demo.sigra.dev")
      bob = demo_user!("bob@demo.sigra.dev")

      admin_orgs =
        Repo.aggregate(
          from(m in OrganizationMembership, where: m.user_id == ^admin.id),
          :count
        )

      assert admin_orgs == 2

      assert membership_role(alice.id, acme.id) == :member
      assert membership_role(carol.id, acme.id) == :member
      assert membership_role(dave.id, acme.id) == :member
      assert membership_role(admin.id, acme.id) == :owner
      assert membership_role(admin.id, beta.id) == :member
      assert membership_role(bob.id, beta.id) == :owner
    end
  end

  describe "audit liveness (SEED-04)" do
    setup do
      assert :ok = Seeds.run()
      :ok
    end

    test "at least 15 audit events across at least 6 distinct actions, admin-tied" do
      admin = demo_user!("admin@demo.sigra.dev")

      admin_tied =
        Repo.aggregate(
          from(a in AuditEvent, where: a.effective_user_id == ^admin.id),
          :count
        )

      assert admin_tied >= 15

      distinct_actions =
        Repo.aggregate(
          from(a in AuditEvent,
            where: a.effective_user_id == ^admin.id,
            distinct: a.action,
            select: a.action
          ),
          :count
        )

      assert distinct_actions >= 6

      assert admin_tied >= 1,
             "expected at least one audit row tied to admin via effective_user_id"
    end

    test "persona and organization audit rows make non-admin detail screens useful" do
      acme = Repo.get_by!(Organization, slug: "acme-corp")
      alice = demo_user!("alice@demo.sigra.dev")
      dave = demo_user!("dave@demo.sigra.dev")

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
      alice = demo_user!("alice@demo.sigra.dev")

      assert is_binary(alice.hashed_password)

      assert String.starts_with?(alice.hashed_password, "$argon2id$"),
             "expected argon2id hash, got prefix #{inspect(String.slice(alice.hashed_password || "", 0, 12))}"
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
