defmodule Example.Demo.Seeds do
  @moduledoc """
  Idempotent demo-database seed orchestrator.

  Calling `run/0` populates the development database with seven `@demo.sigra.dev`
  personas covering every notable auth state (admin with TOTP + passkey + multi-org,
  standard user, TOTP-enrolled org owner, GitHub OAuth identity, locked-out,
  scheduled-deletion, and a non-platform org admin). It also seeds the Acme Corp and
  Beta Labs organizations, memberships, a pending invitation, the Acme Corp SSO
  enterprise connection, multiple active admin sessions, and a rich audit trail
  (>=15 rows, >=6 distinct action values).

  Calling `run/0` twice is safe: all inserts use `on_conflict: :nothing` keyed on
  existing unique indexes (D-02), except audit events which use a count-threshold
  guard (the `audit_events` table has no unique index).

  Called from `priv/repo/seeds.exs`, which carries the `MIX_ENV == :test` raise-guard
  (plan 04) as a two-layer defence against contaminating the CI fixture database.
  """

  import Ecto.Query, warn: false

  alias Example.Repo
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
  alias Example.Demo.Personas

  # Fixed reference timestamp for deterministic seeds (D-02).
  # Using a pinned constant so `occurred_at` spread is reproducible across re-runs.
  @seed_reference_ts ~U[2026-05-15 12:00:00Z]

  @doc """
  Seeds the demo database idempotently.

  Safe to call multiple times: user/org/membership/invitation/association counts
  remain identical after repeated calls.
  """
  @spec run() :: :ok
  def run do
    users = seed_users()
    {acme, beta} = seed_organizations()
    seed_memberships(users, acme, beta)
    seed_invitation(acme)
    seed_mfa_credentials(users)
    seed_passkey(users)
    seed_sessions(users)
    seed_enterprise_connection(acme)
    seed_user_identity(users)
    seed_audit_events(users, %{acme: acme, beta: beta})
    print_credentials()
    :ok
  end

  defp print_credentials do
    IO.puts("\n=== Demo Credentials ===")

    Personas.all()
    |> Enum.each(fn p ->
      local = p.email |> String.split("@") |> hd()
      feature = Personas.feature_map()[local]
      IO.puts("[#{local}]  #{p.email}  #{p.password}  (#{feature})")
    end)
  end

  ## ── User creation + state patches ───────────────────────────────────────────

  defp seed_users do
    users =
      Enum.map(Personas.all(), fn persona ->
        user = upsert_user(persona)
        user = patch_user_state(user, persona)
        {persona.email, user}
      end)

    Map.new(users)
  end

  # Register through the context API so real Argon2id hashing + audit events fire.
  # On re-run, register_user/1 returns either:
  #   {:error, :email_taken}  — DB-level unique constraint (Sigra.Auth.register/3 path)
  #   {:error, changeset}     — unsafe_validate_unique fires before DB insert
  # Both indicate the user already exists; fetch the existing row.
  defp upsert_user(persona) do
    case Accounts.register_user(%{
           email: persona.email,
           display_name: persona.display_name,
           password: persona.password
         }) do
      {:ok, user} ->
        user

      {:error, :email_taken} ->
        Accounts.get_user_by_email(persona.email)

      {:error, %Ecto.Changeset{} = cs} ->
        # Check if this is an email-taken changeset (re-run scenario).
        email_errors = Keyword.get(cs.errors, :email, [])

        if Enum.any?(List.wrap(email_errors), fn
             {msg, _} -> String.contains?(msg, "taken")
             msg when is_binary(msg) -> String.contains?(msg, "taken")
             _ -> false
           end) do
          Accounts.get_user_by_email(persona.email)
        else
          raise "Failed to register #{persona.email}: #{inspect(cs.errors)}"
        end
    end
  end

  # Patch state-only lifecycle fields. The context API does not expose these;
  # use User changesets + Repo.update! directly (D-01).
  defp patch_user_state(user, persona) do
    user = maybe_confirm(user, persona)
    user = maybe_lock(user, persona)
    user = maybe_schedule_deletion(user, persona)
    user
  end

  defp maybe_confirm(user, %{confirmed: true}) do
    if user.confirmed_at do
      user
    else
      user
      |> User.confirm_changeset()
      |> Repo.update!()
    end
  end

  defp maybe_confirm(user, _persona), do: user

  defp maybe_lock(user, %{locked: true}) do
    lock_ts = ~U[2026-05-14 09:00:00Z]

    if user.locked_at do
      user
    else
      user
      |> Ecto.Changeset.change(failed_login_attempts: 5, locked_at: lock_ts)
      |> Repo.update!()
    end
  end

  defp maybe_lock(user, _persona), do: user

  defp maybe_schedule_deletion(user, %{email: "dave@demo.sigra.dev"}) do
    # Clear Dave's hashed_password (no context API for this — use deletion_changeset).
    if is_nil(user.hashed_password) do
      user
    else
      user
      |> User.deletion_changeset(%{hashed_password: nil})
      |> Repo.update!()
    end
  end

  defp maybe_schedule_deletion(user, %{scheduled_deletion: true}) do
    deleted_ts = ~U[2026-05-16 08:00:00Z]
    scheduled_ts = ~U[2026-05-30 08:00:00Z]

    if user.scheduled_deletion_at do
      user
    else
      user
      |> User.deletion_changeset(%{
        deleted_at: deleted_ts,
        scheduled_deletion_at: scheduled_ts
      })
      |> Repo.update!()
    end
  end

  defp maybe_schedule_deletion(user, _persona), do: user

  ## ── Organizations ────────────────────────────────────────────────────────────

  defp seed_organizations do
    acme = upsert_organization("Acme Corp", "acme-corp")
    beta = upsert_organization("Beta Labs", "beta-labs")
    {acme, beta}
  end

  defp upsert_organization(name, slug) do
    # organizations_slug_active_index is a partial unique index (WHERE deleted_at IS NULL).
    # Check-then-insert: fetch existing before attempting insert.
    # The slug is the natural key for active orgs.
    case Repo.get_by(Organization, slug: slug) do
      %Organization{} = org ->
        org

      nil ->
        changeset = Organization.changeset(%Organization{}, %{name: name, slug: slug})

        case Repo.insert(changeset, on_conflict: :nothing) do
          {:ok, %Organization{id: nil}} -> Repo.get_by!(Organization, slug: slug)
          {:ok, org} -> org
        end
    end
  end

  ## ── Memberships ──────────────────────────────────────────────────────────────

  defp seed_memberships(users, acme, beta) do
    admin = users["admin@demo.sigra.dev"]
    alice = users["alice@demo.sigra.dev"]
    carol = users["carol@demo.sigra.dev"]
    bob = users["bob@demo.sigra.dev"]
    dave = users["dave@demo.sigra.dev"]
    morgan = users["morgan@demo.sigra.dev"]

    # Acme Corp: admin=owner, morgan=admin (non-platform), alice=member, carol=member
    upsert_membership(admin.id, acme.id, :owner)
    upsert_membership(morgan.id, acme.id, :admin)
    upsert_membership(alice.id, acme.id, :member)
    upsert_membership(carol.id, acme.id, :member)
    upsert_membership(dave.id, acme.id, :member)

    # Beta Labs: admin=member, bob=owner
    upsert_membership(admin.id, beta.id, :member)
    upsert_membership(bob.id, beta.id, :owner)
  end

  defp upsert_membership(user_id, org_id, role) do
    %OrganizationMembership{}
    |> OrganizationMembership.changeset(%{user_id: user_id, organization_id: org_id, role: role})
    |> Repo.insert!(on_conflict: :nothing, conflict_target: [:user_id, :organization_id])
  end

  ## ── Pending invitation ───────────────────────────────────────────────────────

  defp seed_invitation(acme) do
    expires_ts = ~U[2026-06-30 00:00:00Z]
    invite_email = "invited@demo.sigra.dev"

    # organization_invitations_pending_index is a partial unique index
    # (WHERE accepted_at IS NULL AND revoked_at IS NULL).
    # Use is_nil/1 in the query — Repo.get_by does not accept nil values.
    existing =
      Repo.one(
        from(i in OrganizationInvitation,
          where:
            i.organization_id == ^acme.id and
              i.email == ^invite_email and
              is_nil(i.accepted_at) and
              is_nil(i.revoked_at)
        )
      )

    unless existing do
      %OrganizationInvitation{}
      |> OrganizationInvitation.changeset(%{
        email: invite_email,
        role: :member,
        expires_at: expires_ts,
        organization_id: acme.id
      })
      |> Repo.insert!()
    end
  end

  ## ── TOTP MFA credentials (D-06) ──────────────────────────────────────────────

  defp seed_mfa_credentials(users) do
    admin = users["admin@demo.sigra.dev"]
    bob = users["bob@demo.sigra.dev"]

    enabled_ts = ~U[2026-04-01 10:00:00Z]

    upsert_totp(admin.id, enabled_ts)
    upsert_totp(bob.id, enabled_ts)
  end

  defp upsert_totp(user_id, enabled_at) do
    %UserMFACredential{}
    |> UserMFACredential.create_changeset(%{
      user_id: user_id,
      type: "totp",
      encrypted_secret: Personas.demo_totp_secret(),
      enabled_at: enabled_at
    })
    |> Repo.insert!(on_conflict: :nothing, conflict_target: [:user_id, :type])
  end

  ## ── Admin passkey display row (D-07) ─────────────────────────────────────────

  defp seed_passkey(users) do
    admin = users["admin@demo.sigra.dev"]

    # display-only; will not authenticate
    # Fabricated binary credential_id and public_key — zero Wax validation,
    # so the insert succeeds. The row exists only to populate the admin UI panel.
    credential_id = :crypto.hash(:sha256, "sigra-demo-admin-passkey-credential-id-v1")
    public_key = :crypto.hash(:sha256, "sigra-demo-admin-passkey-public-key-v1")

    %UserPasskey{}
    |> UserPasskey.create_changeset(%{
      user_id: admin.id,
      credential_id: credential_id,
      public_key: public_key,
      nickname: "Demo Security Key"
    })
    |> Repo.insert!(on_conflict: :nothing, conflict_target: [:credential_id])
  end

  ## ── Multi-session evidence for the admin persona ─────────────────────────────
  #
  # Seed three active sessions for the admin persona so the user-detail Sessions
  # table renders populated. Each row carries a REQUIRED hashed_token (binary),
  # derived deterministically so re-runs are stable, with distinct IPs and
  # staggered last_active_at. UserSession timestamps use updated_at:false — only
  # inserted_at is set. The unique index user_sessions_hashed_token_index makes
  # on_conflict/conflict_target idempotency safe.

  @admin_sessions [
    %{n: "1", ip: "203.0.113.10", user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15", offset_days: 0},
    %{n: "2", ip: "198.51.100.22", user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0", offset_days: 1},
    %{n: "3", ip: "192.0.2.44", user_agent: "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0", offset_days: 3}
  ]

  defp seed_sessions(users) do
    admin = users["admin@demo.sigra.dev"]

    Enum.each(@admin_sessions, fn session ->
      hashed_token = :crypto.hash(:sha256, "sigra-demo-admin-session-" <> session.n)

      # UserSession timestamps are :utc_datetime_usec — coerce to microsecond
      # precision. @seed_reference_ts is second-precision, and DateTime.truncate/2
      # leaves precision at {0, 0} (which Ecto rejects), so set {0, 6} explicitly.
      active_at =
        @seed_reference_ts
        |> DateTime.add(-session.offset_days * 86_400, :second)
        |> Map.put(:microsecond, {0, 6})

      %UserSession{}
      |> Ecto.Changeset.change(%{
        user_id: admin.id,
        hashed_token: hashed_token,
        type: "standard",
        ip: session.ip,
        user_agent: session.user_agent,
        last_active_at: active_at,
        inserted_at: active_at
      })
      |> Repo.insert!(on_conflict: :nothing, conflict_target: [:hashed_token])
    end)
  end

  ## ── Acme Corp SSO EnterpriseConnection (D-08) ────────────────────────────────

  defp seed_enterprise_connection(acme) do
    # enterprise_connections_active_display_name_index is a partial unique index
    # on [:organization_id, :protocol, :display_name] WHERE status = 'active'.
    # Ecto's {:constraint, :name} conflict_target is not supported by the Postgres
    # adapter; use check-then-insert for idempotency. Scope the lookup to the
    # active row for this org so a non-active row with the same display_name can
    # never suppress the seed insert.
    existing =
      Repo.get_by(EnterpriseConnection,
        organization_id: acme.id,
        display_name: "Acme Corp SSO",
        status: :active
      )

    unless existing do
      %EnterpriseConnection{}
      |> EnterpriseConnection.changeset(%{
        organization_id: acme.id,
        status: :active,
        display_name: "Acme Corp SSO",
        oidc_settings: %{
          issuer: "https://sso.acme-demo.example",
          client_id: "acme-demo-client",
          encrypted_client_secret: "demo-secret-not-real",
          client_authentication_method: "client_secret_basic"
        }
      })
      |> Repo.insert!()
    end
  end

  ## ── Carol's GitHub OAuth identity (D-09) ─────────────────────────────────────

  defp seed_user_identity(users) do
    carol = users["carol@demo.sigra.dev"]

    %UserIdentity{}
    |> UserIdentity.changeset(%{
      user_id: carol.id,
      provider: "github",
      provider_uid: "carol-gh-demo-uid",
      provider_email: "carol@demo.sigra.dev"
    })
    |> Repo.insert!(on_conflict: :nothing, conflict_target: [:user_id, :provider])
  end

  ## ── Audit events (D-11) ──────────────────────────────────────────────────────
  #
  # Insert >=15 rows across >=6 distinct action values.
  # CORRECTION 1: auth.*/session.*/mfa.* are reserved prefixes — pass
  #   `allow_reserved: true` on every insert (AuditEvent.changeset/3 arg 3).
  # CORRECTION 2: Admin detail filters by effective_user_id OR target_id, NOT
  #   actor_id alone. Set effective_user_id: admin.id on admin-tied rows.
  # IDEMPOTENCY: No unique index on audit_events — use count-threshold guard.

  @audit_actions [
    {"auth.login.success", "success", 0},
    {"auth.login.success", "success", 1},
    {"auth.login.success", "success", 2},
    {"auth.login.failure", "failure", 3},
    {"auth.login.failure", "failure", 4},
    {"mfa.enroll.success", "success", 5},
    {"session.create", "success", 6},
    {"session.create", "success", 7},
    {"session.revoke_all", "success", 8},
    {"admin.impersonation.start", "success", 9},
    {"admin.impersonation.stop", "success", 10},
    {"mfa.disable", "success", 11},
    {"mfa.regenerate_backup_codes", "success", 12},
    {"auth.login.failure", "failure", 13},
    {"session.create", "success", 14},
    {"mfa.enroll.success", "success", 15},
    {"auth.login.success", "success", 16},
    {"session.revoke_all", "success", 17}
  ]

  @persona_audit_events [
    %{
      email: "alice@demo.sigra.dev",
      actor: "alice@demo.sigra.dev",
      action: "auth.login.success",
      outcome: "success",
      offset: 18,
      org: :acme
    },
    %{
      email: "alice@demo.sigra.dev",
      actor: "admin@demo.sigra.dev",
      action: "admin.impersonation.start",
      outcome: "success",
      offset: 19,
      org: :acme
    },
    %{
      email: "alice@demo.sigra.dev",
      actor: "admin@demo.sigra.dev",
      action: "admin.impersonation.stop",
      outcome: "success",
      offset: 20,
      org: :acme
    },
    %{
      email: "bob@demo.sigra.dev",
      actor: "bob@demo.sigra.dev",
      action: "mfa.enroll.success",
      outcome: "success",
      offset: 21,
      org: :beta
    },
    %{
      email: "bob@demo.sigra.dev",
      actor: "bob@demo.sigra.dev",
      action: "auth.login.success",
      outcome: "success",
      offset: 22,
      org: :beta
    },
    %{
      email: "carol@demo.sigra.dev",
      actor: "carol@demo.sigra.dev",
      action: "auth.oauth.link",
      outcome: "success",
      offset: 23,
      org: :acme
    },
    %{
      email: "carol@demo.sigra.dev",
      actor: "carol@demo.sigra.dev",
      action: "auth.login.success",
      outcome: "success",
      offset: 24,
      org: :acme
    },
    %{
      email: "dave@demo.sigra.dev",
      actor: "dave@demo.sigra.dev",
      action: "auth.login.failure",
      outcome: "failure",
      offset: 25,
      org: :acme
    },
    %{
      email: "dave@demo.sigra.dev",
      actor: "dave@demo.sigra.dev",
      action: "auth.lockout.start",
      outcome: "failure",
      offset: 26,
      org: :acme
    },
    %{
      email: "frank@demo.sigra.dev",
      actor: "frank@demo.sigra.dev",
      action: "account.deletion.schedule",
      outcome: "success",
      offset: 27,
      org: nil
    },
    %{
      email: "admin@demo.sigra.dev",
      actor: "admin@demo.sigra.dev",
      action: "session.create",
      outcome: "success",
      offset: 28,
      org: :acme
    },
    %{
      email: "admin@demo.sigra.dev",
      actor: "admin@demo.sigra.dev",
      action: "session.create",
      outcome: "success",
      offset: 29,
      org: :beta
    }
  ]

  defp seed_audit_events(users, organizations) do
    admin = users["admin@demo.sigra.dev"]
    demo_user_ids = users |> Map.values() |> Enum.map(& &1.id)

    # Count-threshold guard: only insert the demo batch if fewer than the full
    # deterministic demo audit rows exist. This makes a second run/0 call a no-op
    # while allowing older dev databases with the smaller admin-only batch to
    # receive the richer persona/org evidence batch on the next seed run.
    demo_tied_count =
      Repo.aggregate(
        from(a in AuditEvent, where: a.effective_user_id in ^demo_user_ids),
        :count
      )

    if demo_tied_count < length(@audit_actions) + length(@persona_audit_events) do
      insert_audit_batch(admin, users, organizations)
    end
  end

  defp insert_audit_batch(admin, users, organizations) do
    # Wrap the whole batch in a transaction: the count-threshold guard above is
    # only idempotent if the batch is all-or-nothing. A mid-batch crash would
    # otherwise leave <15 rows, so the next run/0 re-fires and accumulates
    # duplicates indefinitely.
    Repo.transaction(fn ->
      Enum.each(@audit_actions, fn {action, outcome, offset_days} ->
        # Spread occurred_at deterministically over a past-30-days window.
        # Use @seed_reference_ts as the fixed anchor — NOT DateTime.utc_now().
        occurred_at =
          DateTime.add(@seed_reference_ts, -offset_days * 86_400, :second)

        %AuditEvent{}
        |> AuditEvent.changeset(
          %{
            action: action,
            outcome: outcome,
            occurred_at: occurred_at,
            actor_id: admin.id,
            actor_type: "user",
            # TIE-TO-USER: effective_user_id (not just actor_id) so these rows
            # surface on admin's detail page (lib/sigra/admin/audit/query.ex:32).
            effective_user_id: admin.id
          },
          allow_reserved: true
        )
        |> Repo.insert!()
      end)

      Enum.each(@persona_audit_events, fn event ->
        subject = Map.fetch!(users, event.email)
        actor = Map.fetch!(users, event.actor)
        organization_id = event.org && Map.fetch!(organizations, event.org).id
        occurred_at = DateTime.add(@seed_reference_ts, -event.offset * 86_400, :second)

        %AuditEvent{}
        |> AuditEvent.changeset(
          %{
            action: event.action,
            outcome: event.outcome,
            occurred_at: occurred_at,
            actor_id: actor.id,
            actor_type: "user",
            target_id: subject.id,
            target_type: "user",
            organization_id: organization_id,
            effective_user_id: subject.id
          },
          allow_reserved: true
        )
        |> Repo.insert!()
      end)
    end)
  end
end
