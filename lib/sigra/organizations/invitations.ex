defmodule Sigra.Organizations.Invitations do
  @moduledoc """
  Phase 17 invitation lifecycle: `create/2`, `revoke/3`, `list_pending/2`,
  `list_pending_for_user/2`. `accept/3` and `accept_with_signup/3` land
  in Plan 17-05.

  All security-critical logic (HMAC token generation via
  `Sigra.Token.generate_invite_envelope/2`, `Ecto.Multi` atomicity,
  dual-key Hammer rate limiting, authorization) lives in this library
  module. The generated `OrganizationMembersLive` is a thin event-handler
  wrapper that delegates to `use Sigra.Organizations` re-exports.

  ## Key invariants

  - `organization_invitations.hashed_token` is SHA-256 of the raw
    base64 invite token. The raw token **never** touches the DB; it is
    only present in the signed envelope threaded into the accept URL
    (HMAC-bound to email via `Sigra.Token.generate_invite_envelope/2`).
  - Pending uniqueness is enforced by the partial-unique index
    `organization_invitations_pending_index` (IS-NULL-only predicate,
    IMMUTABLE-safe per D-03).
  - Re-invite on a pending email (D-05) revokes the old row and inserts
    a new row in a single `Ecto.Multi`, preserving the partial-unique
    invariant with zero windows where two rows are pending.
  - Rate limiting is dual-key:
    `"sigra:org_invite_create:user:<user_id>"` checked first, then
    `"sigra:org_invite_create:org:<org_id>"`. Fail-open per D-41 is
    handled inside `Sigra.RateLimiters.Hammer`.
  - Email delivery happens **after** successful `repo.transact/2`.
    Mailer failures are logged + telemetry-emitted and **never** roll
    back the committed DB row (D-12 discretion).

  ## Asymmetric error exposure (Pitfall 7)

  Creating an invite for an existing member returns `:already_member`
  while creating for a user with no account returns `{:ok, _}`. This is
  acceptable because the actor is already an admin who can
  `list_members/2` and see membership state directly — no new
  information is leaked.

  ## Telemetry events

  - `[:sigra, :invitation, :email_sent]` — after successful email send
  - `[:sigra, :invitation, :email_delivery_failed]` — after mailer raises
  - `[:sigra, :invitation, :email_skipped]` — when `emails_module` is nil
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Sigra.Token

  require Logger

  # ---------- create/2 ----------

  @doc """
  Create a pending invitation for `email` to join `organization_id` with `role`.

  Requires the actor (passed via `attrs.actor`) to carry a membership with
  a role listed in the host's configured `:invitation_admin_roles`
  (Phase 92 / B2B-02 — Plan 92-01 removed the implicit
  invitation-admin default; hosts must declare the authorized roles
  explicitly in `use Sigra.Organizations`). Returns:

    * `{:ok, %OrganizationInvitation{} = invitation}` — invitation row
      inserted, with an ephemeral `__encoded_token__` key on the struct
      carrying the signed envelope (useful if the caller wants to thread
      it somewhere beyond the built-in email delivery path).
    * `{:error, :unauthorized}` — actor lacks owner/admin role
    * `{:error, :rate_limited_user}` — per-user Hammer limit exceeded
    * `{:error, :rate_limited_org}` — per-org Hammer limit exceeded
    * `{:error, %Ecto.Changeset{}}` — invitation changeset invalid

  Raises `RuntimeError` when `config.secret_key_base` or
  `config.url_builder` is nil (Phase 17 runtime requirements).
  """
  @spec create(map(), map()) ::
          {:ok, struct()}
          | {:error,
             :rate_limited_user
             | :rate_limited_org
             | :unauthorized
             | :invalid_role
             | :already_member
             | Ecto.Changeset.t()}
  def create(config, %{actor: actor_scope} = attrs) do
    :ok = assert_secret_key_base!(config)
    :ok = Sigra.Organizations.__warn_long_invitation_ttl__(config)

    # Phase 92 / B2B-02 (CR-2-01 fix): role-universe validation runs
    # AFTER authorize_create so a non-admin caller does not learn
    # whether a role atom is or is not configured (info-disclosure
    # mitigation). The validation returns {:error, :invalid_role}
    # rather than raising, matching the documented @spec — this is
    # the request-handler-facing entry point, not an internal API.
    with :ok <- authorize_create(config, actor_scope),
         :ok <- Sigra.Organizations.validate_role_in_universe(attrs.role, config),
         :ok <- check_user_rate_limit(config, attrs.invited_by_id),
         :ok <- check_org_rate_limit(config, attrs.organization_id),
         {:ok, result} <- do_create(config, attrs) do
      deliver_invitation_email_async(config, result)

      {:ok,
       result.invitation
       |> Map.put(:__encoded_token__, result.encoded_token)}
    end
  end

  defp assert_secret_key_base!(%{secret_key_base: nil}) do
    raise """
    [Sigra] secret_key_base is required for Sigra.Organizations.Invitations.create/2
    but is nil. Set it in `use Sigra.Organizations, secret_key_base: ...` or
    pass the endpoint's secret_key_base into the config struct at runtime.
    """
  end

  defp assert_secret_key_base!(%{secret_key_base: s}) when is_binary(s), do: :ok

  defp authorize_create(config, %{membership: %{role: role}}) do
    if role in fetch_invitation_admin_roles!(config),
       do: :ok,
       else: {:error, :unauthorized}
  end

  defp authorize_create(_config, _scope), do: {:error, :unauthorized}

  # Phase 92-01: read the host-configured invitation admin role list. The
  # library no longer ships a built-in role constant — the host must
  # declare which configured roles confer invitation-admin privilege via
  # `use Sigra.Organizations`.
  defp fetch_invitation_admin_roles!(config) do
    case Map.fetch(config, :invitation_admin_roles) do
      {:ok, roles} when is_list(roles) and roles != [] ->
        roles

      _ ->
        raise ArgumentError,
              "Sigra.Organizations.Invitations requires :invitation_admin_roles in the " <>
                "Sigra.Organizations config (Phase 92 / B2B-02 — Plan 92-01 removed the " <>
                "implicit invitation-admin role default). Set " <>
                "`invitation_admin_roles: [...]` in `use Sigra.Organizations` listing the " <>
                "host roles authorized to create or revoke invitations."
    end
  end

  defp check_user_rate_limit(config, user_id) do
    case config.invitation_rate_limit_per_user do
      :infinity ->
        :ok

      {limit, window_ms} ->
        key = "sigra:org_invite_create:user:#{user_id}"

        case config.rate_limiter.check_rate(key, limit, window_ms) do
          {:allow, _} -> :ok
          {:deny, _} -> {:error, :rate_limited_user}
        end
    end
  end

  defp check_org_rate_limit(config, org_id) do
    case config.invitation_rate_limit_per_org do
      :infinity ->
        :ok

      {limit, window_ms} ->
        key = "sigra:org_invite_create:org:#{org_id}"

        case config.rate_limiter.check_rate(key, limit, window_ms) do
          {:allow, _} -> :ok
          {:deny, _} -> {:error, :rate_limited_org}
        end
    end
  end

  defp do_create(config, attrs) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(config.invitation_ttl, :millisecond)
      |> DateTime.truncate(:second)

    {encoded_token, hashed_token} =
      Token.generate_invite_envelope(config.secret_key_base, attrs.email)

    invitation_schema = config.schemas.invitation

    changeset =
      invitation_schema
      |> struct!()
      |> invitation_schema.changeset(%{
        organization_id: attrs.organization_id,
        email: attrs.email,
        role: attrs.role,
        hashed_token: hashed_token,
        expires_at: expires_at,
        invited_by_id: attrs.invited_by_id
      })

    Multi.new()
    |> maybe_revoke_prior_pending(config, attrs)
    |> Multi.insert(:invitation, changeset)
    |> append_audit(config, "organization.invitation.created", attrs.actor,
      metadata: %{email: attrs.email, role: to_string(attrs.role)}
    )
    |> config.repo.transact()
    |> case do
      {:ok, %{invitation: inv} = _changes} ->
        {:ok, %{invitation: inv, encoded_token: encoded_token}}

      {:error, :invitation, %Ecto.Changeset{} = cs, _} ->
        {:error, cs}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  defp maybe_revoke_prior_pending(multi, config, attrs) do
    schema = config.schemas.invitation

    Multi.run(multi, :revoke_prior, fn repo, _changes ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {count, _} =
        from(i in schema,
          where:
            i.organization_id == ^attrs.organization_id and
              i.email == ^attrs.email and
              is_nil(i.accepted_at) and is_nil(i.revoked_at)
        )
        |> repo.update_all(
          set: [revoked_at: now, revoked_by_id: attrs.invited_by_id, updated_at: now]
        )

      {:ok, %{revoked_count: count}}
    end)
  end

  defp deliver_invitation_email_async(%{emails_module: nil} = _config, %{invitation: inv}) do
    :telemetry.execute(
      [:sigra, :invitation, :email_skipped],
      %{count: 1},
      %{invitation_id: inv.id, reason: :emails_module_nil}
    )

    :ok
  end

  defp deliver_invitation_email_async(config, %{invitation: inv, encoded_token: encoded}) do
    accept_url = build_accept_url(config, encoded)

    org = config.repo.get!(config.schemas.organization, inv.organization_id)
    inviter = config.repo.get!(config.schemas.user, inv.invited_by_id)

    apply(config.emails_module, :organization_invitation, [inv, org, inviter, accept_url])

    :telemetry.execute(
      [:sigra, :invitation, :email_sent],
      %{count: 1},
      %{invitation_id: inv.id}
    )

    :ok
  rescue
    e ->
      Logger.warning("[Sigra] invitation email delivery failed: #{inspect(e)}")

      :telemetry.execute(
        [:sigra, :invitation, :email_delivery_failed],
        %{count: 1},
        %{invitation_id: Map.get(inv, :id), error: inspect(e)}
      )

      :ok
  end

  defp build_accept_url(%{url_builder: nil}, _encoded_token) do
    raise """
    [Sigra] url_builder is required for Sigra.Organizations.Invitations.create/2
    but is nil. Set it in `use Sigra.Organizations, url_builder: ...` — typically
    a closure over the host app's Phoenix.VerifiedRoutes endpoint, e.g.:

        url_builder: fn encoded ->
          Phoenix.VerifiedRoutes.unverified_url(
            MyAppWeb.Endpoint,
            "/invitations/" <> encoded <> "/accept"
          )
        end

    Generated by `mix sigra.install` into `use Sigra.Organizations`.
    """
  end

  defp build_accept_url(%{url_builder: fun}, encoded_token) when is_function(fun, 1) do
    fun.(encoded_token)
  end

  # ---------- accept/3 (signed-in-match path, INV-06) ----------

  @doc """
  Accept an invitation as an already-signed-in user whose email matches
  the invitation email (case-insensitive via citext + `String.downcase/1`
  belt-and-suspenders).

  Returns:

    * `{:ok, %{membership: _, invitation: _}}` — membership row inserted,
      invitation stamped with `accepted_at` + `accepted_by_id`, audit event
      emitted atomically via `repo.transact/1`.
    * `{:error, :invalid}` — HMAC verify failed, base64 decode failed,
      payload shape wrong, bound_email does not match DB row email, or
      invitation row missing for the looked-up hashed_token. Collapsed
      uniformly to `:invalid` to avoid information leakage.
    * `{:error, :expired}` — invitation envelope or DB `expires_at`
      is in the past.
    * `{:error, :revoked}` — `revoked_at IS NOT NULL`.
    * `{:error, :already_accepted}` — `accepted_at IS NOT NULL` (replay).
    * `{:error, :mismatch}` — `current_user.email != invitation.email`
      (Jetstream #907 / CVE-2026-1529 defense). ZERO DB writes.

  All non-`:ok` branches skip audit emission for `organization.invitation.accepted`.
  """
  @spec accept(map(), String.t(), struct()) ::
          {:ok, %{membership: struct(), invitation: struct()}}
          | {:error, :invalid | :expired | :revoked | :already_accepted | :mismatch}
  def accept(config, signed_token, %{email: _user_email} = current_user)
      when is_binary(signed_token) do
    :ok = assert_secret_key_base!(config)

    with {:ok, invitation, _bound_email} <- verify_and_load(config, signed_token),
         :ok <- assert_user_matches_invitation(current_user, invitation),
         {:ok, org} <- fetch_org(config, invitation),
         {:ok, result} <- run_accept_multi(config, invitation, current_user, org) do
      {:ok, result}
    end
  end

  def accept(_config, _signed_token, _user), do: {:error, :invalid}

  # ---------- accept_with_signup/3 (anonymous signup path, INV-05) ----------

  @doc """
  Accept an invitation as an anonymous visitor by atomically registering
  a new user, confirming them (HMAC-bound invite acceptance proves email
  ownership), inserting a membership, and stamping the invitation.

  All four Multi steps run inside a single `repo.transact/1`. Any step
  failure rolls back the entire transaction — zero orphan rows across
  the user, membership, and invitation tables (Pow #534 regression
  invariant).

  The caller-supplied `user_params["email"]` is rejected server-side if
  it does not match `invitation.email` case-insensitively, even though
  the UI locks the field via `disabled + readonly`. The locked email is
  also force-overwritten onto the registration params as a
  belt-and-suspenders defense against direct POST tampering.

  Raises `RuntimeError` when `config.user_registration_changeset_fn` is
  nil — the host app's installer must wire this to
  `&YourApp.Accounts.User.registration_changeset/1`.
  """
  @spec accept_with_signup(map(), String.t(), map()) ::
          {:ok, %{user: struct(), membership: struct(), invitation: struct()}}
          | {:error,
             :invalid
             | :expired
             | :revoked
             | :already_accepted
             | :email_mismatch
             | Ecto.Changeset.t()}
  def accept_with_signup(config, signed_token, user_params)
      when is_binary(signed_token) and is_map(user_params) do
    :ok = assert_secret_key_base!(config)
    :ok = assert_user_registration_changeset_fn!(config)

    with {:ok, invitation, _bound_email} <- verify_and_load(config, signed_token),
         :ok <- assert_signup_email_matches(user_params, invitation.email),
         {:ok, org} <- fetch_org(config, invitation),
         {:ok, result} <- run_accept_with_signup_multi(config, invitation, user_params, org) do
      {:ok, result}
    end
  end

  def accept_with_signup(_config, _signed_token, _params), do: {:error, :invalid}

  # ---------- load_for_view/3 (Plan 17-07 InvitationAcceptLive mount helper) ----------

  @doc """
  Load an invitation and classify it into a render-branch tuple for
  `InvitationAcceptLive` (Plan 17-07, D-06).

  Does NOT run any Multi — the caller invokes `accept/3` or
  `accept_with_signup/3` separately on user action. This function
  performs the HMAC verify + DB lookup + optional org/inviter load and
  returns a tuple the LV assigns directly to `:branch` + related assigns.

  The `current_user` argument is `nil` for anonymous visitors (signup
  branch) or a user struct for signed-in visitors (accept or mismatch
  branch depending on email match).

  Returned tuples:

    * `{:signup, invitation, org, inviter}` — anonymous visitor, token valid + pending
    * `{:accept, invitation, org, inviter, current_user}` — signed-in
      user's email matches invitation email
    * `{:mismatch, invitation, current_user}` — signed-in user's email
      does NOT match invitation email (Jetstream #907 mismatch branch).
      `org` and `inviter` are deliberately not returned — the mismatch
      branch does not render them.
    * `{:invalid, :invalid}` — HMAC verify fail, tampered token, garbage
      base64, or invitation row missing. Uniformly `:invalid` for zero
      info leakage.
    * `{:expired, invitation_or_nil}` — envelope age > TTL or DB
      `expires_at <= now()`. The row is reloaded without the pending
      guard so the view can display inviter context.
    * `{:revoked, invitation_or_nil}` — DB `revoked_at IS NOT NULL`.
    * `{:already_accepted, invitation_or_nil, maybe_member?}` — DB
      `accepted_at IS NOT NULL` (replay). The boolean is currently
      always `false` — future work may use it to auto-redirect
      members to their org dashboard.
  """
  @spec load_for_view(map(), String.t(), struct() | nil) ::
          {:signup, struct(), struct(), struct()}
          | {:accept, struct(), struct(), struct(), struct()}
          | {:mismatch, struct(), struct()}
          | {:invalid, :invalid}
          | {:expired, struct() | nil}
          | {:revoked, struct() | nil}
          | {:already_accepted, struct() | nil, boolean()}
  def load_for_view(config, signed_token, current_user)
      when is_binary(signed_token) do
    :ok = assert_secret_key_base!(config)

    ttl_seconds = div(config.invitation_ttl, 1_000)

    case Token.verify_invite_envelope(config.secret_key_base, signed_token, ttl_seconds) do
      {:ok, envelope} ->
        classify_envelope(config, envelope, current_user)

      {:error, :invalid} ->
        {:invalid, :invalid}

      {:error, :expired} ->
        # Envelope-age TTL blew; we cannot reach the DB row without the
        # raw token, so inviter context is unavailable for this branch.
        {:expired, nil}
    end
  end

  def load_for_view(_config, _signed_token, _current_user), do: {:invalid, :invalid}

  defp classify_envelope(config, envelope, current_user) do
    schema = config.schemas.invitation

    case config.repo.get_by(schema, hashed_token: envelope.hashed_token) do
      nil ->
        {:invalid, :invalid}

      %{} = inv ->
        # Belt-and-suspenders bound-email check. If it fails we collapse
        # to :invalid (no info leak) even though the HMAC is valid.
        if String.downcase(to_string(envelope.bound_email)) !=
             String.downcase(to_string(inv.email)) do
          {:invalid, :invalid}
        else
          classify_row(config, inv, current_user)
        end
    end
  end

  defp classify_row(_config, %{accepted_at: t} = inv, _user) when not is_nil(t),
    do: {:already_accepted, inv, false}

  defp classify_row(_config, %{revoked_at: t} = inv, _user) when not is_nil(t),
    do: {:revoked, inv}

  defp classify_row(config, %{expires_at: exp} = inv, user) do
    if DateTime.compare(exp, DateTime.utc_now()) != :gt do
      {:expired, inv}
    else
      classify_pending(config, inv, user)
    end
  end

  defp classify_pending(config, invitation, nil) do
    org = config.repo.get(config.schemas.organization, invitation.organization_id)
    inviter = config.repo.get(config.schemas.user, invitation.invited_by_id)

    if is_nil(org) or is_nil(inviter) do
      {:invalid, :invalid}
    else
      {:signup, invitation, org, inviter}
    end
  end

  defp classify_pending(config, invitation, %{email: user_email} = user) do
    if String.downcase(to_string(user_email)) ==
         String.downcase(to_string(invitation.email)) do
      org = config.repo.get(config.schemas.organization, invitation.organization_id)
      inviter = config.repo.get(config.schemas.user, invitation.invited_by_id)

      if is_nil(org) or is_nil(inviter) do
        {:invalid, :invalid}
      else
        {:accept, invitation, org, inviter, user}
      end
    else
      {:mismatch, invitation, user}
    end
  end

  # ---------- verify_and_load/2 (private helper) ----------

  @spec verify_and_load(map(), String.t()) ::
          {:ok, struct(), String.t()}
          | {:error, :invalid | :expired | :revoked | :already_accepted}
  defp verify_and_load(config, signed_token) do
    ttl_seconds = div(config.invitation_ttl, 1_000)
    schema = config.schemas.invitation

    with {:ok, envelope} <-
           Token.verify_invite_envelope(config.secret_key_base, signed_token, ttl_seconds),
         %{} = inv <- config.repo.get_by(schema, hashed_token: envelope.hashed_token),
         :ok <- assert_bound_email(envelope.bound_email, inv.email),
         :ok <- assert_pending_state(inv) do
      {:ok, inv, envelope.bound_email}
    else
      nil -> {:error, :invalid}
      {:error, :invalid} -> {:error, :invalid}
      {:error, :expired} -> {:error, :expired}
      {:error, :revoked} -> {:error, :revoked}
      {:error, :already_accepted} -> {:error, :already_accepted}
      # Collapse bound_email mismatch to :invalid — no info leak.
      {:error, :email_mismatch} -> {:error, :invalid}
    end
  end

  defp assert_bound_email(bound_email, row_email) do
    if String.downcase(to_string(bound_email)) == String.downcase(to_string(row_email)) do
      :ok
    else
      {:error, :email_mismatch}
    end
  end

  defp assert_pending_state(%{accepted_at: t}) when not is_nil(t),
    do: {:error, :already_accepted}

  defp assert_pending_state(%{revoked_at: t}) when not is_nil(t), do: {:error, :revoked}

  defp assert_pending_state(%{expires_at: exp}) do
    if DateTime.compare(exp, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp assert_user_matches_invitation(%{email: user_email}, %{email: inv_email}) do
    if String.downcase(to_string(user_email)) == String.downcase(to_string(inv_email)) do
      :ok
    else
      {:error, :mismatch}
    end
  end

  defp assert_signup_email_matches(user_params, inv_email) do
    posted_email =
      Map.get(user_params, "email") || Map.get(user_params, :email) || ""

    if String.downcase(to_string(posted_email)) == String.downcase(to_string(inv_email)) do
      :ok
    else
      {:error, :email_mismatch}
    end
  end

  defp fetch_org(config, invitation) do
    case config.repo.get(config.schemas.organization, invitation.organization_id) do
      nil -> {:error, :invalid}
      org -> {:ok, org}
    end
  end

  defp assert_user_registration_changeset_fn!(%{user_registration_changeset_fn: fun})
       when is_function(fun, 1),
       do: :ok

  defp assert_user_registration_changeset_fn!(_config) do
    raise """
    [Sigra] user_registration_changeset_fn is required for
    Sigra.Organizations.Invitations.accept_with_signup/3 but is nil.
    Set it in `use Sigra.Organizations, user_registration_changeset_fn: ...`
    to a 1-arity function that builds a User registration changeset, e.g.:

        user_registration_changeset_fn: &MyApp.Accounts.User.registration_changeset/1
    """
  end

  defp run_accept_multi(config, invitation, user, org) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    user_scope = %{user: user, membership: nil, active_organization: org}

    accept_changeset =
      Ecto.Changeset.change(invitation, %{accepted_at: now, accepted_by_id: user.id})

    Multi.new()
    |> Multi.append(
      Sigra.Organizations.add_member_multi(config, user_scope, org, user, invitation.role)
    )
    |> Multi.update(:accept_invitation, accept_changeset)
    |> append_audit(config, "organization.invitation.accepted", user_scope,
      metadata: %{invitation_id: invitation.id, role: to_string(invitation.role)},
      # add_member_multi already inserts an :audit step for "organization.member_add";
      # name this second audit distinctly so the composed Multi has unique step names.
      audit_multi_step: :accept_invitation_audit
    )
    |> config.repo.transact()
    |> case do
      {:ok, %{membership: m, accept_invitation: inv}} ->
        {:ok, %{membership: m, invitation: inv}}

      {:error, _step, %Ecto.Changeset{} = cs, _} ->
        {:error, cs}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  defp run_accept_with_signup_multi(config, invitation, user_params, org) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Force the registration email to the invitation email — belt-and-suspenders
    # even though assert_signup_email_matches/2 already guarded against mismatch.
    params_with_locked_email =
      user_params
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
      |> Map.put("email", invitation.email)

    register_opts = [changeset_fn: config.user_registration_changeset_fn]

    accept_stamp_fn = fn %{confirm_user: user} ->
      Ecto.Changeset.change(invitation, %{accepted_at: now, accepted_by_id: user.id})
    end

    signup_scope = %{user: nil, membership: nil, active_organization: org}

    Multi.new()
    |> Multi.append(Sigra.Auth.register_user_multi(params_with_locked_email, register_opts))
    |> Multi.run(:confirm_user, fn repo, %{user: user} ->
      repo.update(Ecto.Changeset.change(user, %{confirmed_at: now}))
    end)
    |> Multi.append(
      Sigra.Organizations.add_member_multi(
        config,
        signup_scope,
        org,
        {:changes_key, :confirm_user},
        invitation.role
      )
    )
    |> Multi.update(:accept_invitation, accept_stamp_fn)
    |> append_audit(config, "organization.invitation.accepted", signup_scope,
      metadata: %{
        invitation_id: invitation.id,
        role: to_string(invitation.role),
        path: "signup"
      },
      # add_member_multi already inserts an :audit step for "organization.member_add";
      # name this second audit distinctly so the composed Multi has unique step names.
      audit_multi_step: :accept_invitation_audit
    )
    |> config.repo.transact()
    |> case do
      {:ok, %{confirm_user: user, membership: m, accept_invitation: inv}} ->
        {:ok, %{user: user, membership: m, invitation: inv}}

      {:error, :user, %Ecto.Changeset{} = cs, _} ->
        {:error, cs}

      {:error, _step, %Ecto.Changeset{} = cs, _} ->
        {:error, cs}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  # ---------- revoke/3 ----------

  @doc """
  Revoke a pending invitation.

  Requires the actor to carry a membership with a role listed in the
  host's configured `:invitation_admin_roles` (Phase 92 / B2B-02 — Plan
  92-01 removed the implicit invitation-admin default). Already-accepted
  or already-revoked invitations return `{:error, :not_pending}` — the
  DB row is untouched. Missing invitation id → `{:error, :not_found}`.
  The lookup is scoped to `actor_scope.active_organization.id`;
  cross-tenant ids are collapsed to `{:error, :not_found}` to prevent
  enumeration.
  """
  @spec revoke(map(), integer() | binary(), map()) ::
          {:ok, struct()} | {:error, :not_pending | :unauthorized | :not_found}
  def revoke(
        config,
        invitation_id,
        %{membership: %{role: role}, active_organization: %{id: org_id}} = actor_scope
      ) do
    if role in fetch_invitation_admin_roles!(config) do
      schema = config.schemas.invitation

      query =
        from i in schema,
          where: i.id == ^invitation_id and i.organization_id == ^org_id

      case config.repo.one(query) do
        nil ->
          # Collapses two cases onto one response to prevent cross-tenant
          # enumeration: (a) id truly does not exist, (b) id exists in
          # another org. Per CR-01 / INV-08 gap closure.
          # No audit emission on the :not_found branch — cross-tenant
          # probes are observable via future telemetry, tracked separately.
          {:error, :not_found}

        %{accepted_at: nil, revoked_at: nil} = inv ->
          do_revoke(config, inv, actor_scope)

        _inv ->
          {:error, :not_pending}
      end
    else
      {:error, :unauthorized}
    end
  end

  def revoke(_config, _id, _scope), do: {:error, :unauthorized}

  defp do_revoke(config, invitation, actor_scope) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    actor_id = get_in_scope(actor_scope, :user, :id)

    changeset =
      invitation
      |> Ecto.Changeset.change(%{revoked_at: now, revoked_by_id: actor_id})

    Multi.new()
    |> Multi.update(:invitation, changeset)
    |> append_audit(config, "organization.invitation.revoked", actor_scope,
      metadata: %{invitation_id: invitation.id, email: invitation.email}
    )
    |> config.repo.transact()
    |> case do
      {:ok, %{invitation: inv}} -> {:ok, inv}
      {:error, _step, %Ecto.Changeset{} = cs, _} -> {:error, cs}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  # ---------- list_pending/2 ----------

  @doc """
  List pending invitations for `org` (struct or id). Returns the rows
  sorted by `inserted_at` descending with `:invited_by` preloaded.

  "Pending" means `accepted_at IS NULL AND revoked_at IS NULL AND
  expires_at > now()`. The expires_at filter is applied at query time
  so expired-but-not-yet-cleaned-up rows don't surface to the admin UI.
  """
  @spec list_pending(map(), struct() | integer() | binary()) :: [struct()]
  def list_pending(config, org_or_id) do
    org_id = extract_org_id(org_or_id)
    schema = config.schemas.invitation
    now = DateTime.utc_now()

    from(i in schema,
      where:
        i.organization_id == ^org_id and
          is_nil(i.accepted_at) and
          is_nil(i.revoked_at) and
          i.expires_at > ^now,
      order_by: [desc: i.inserted_at],
      preload: [:invited_by]
    )
    |> config.repo.all()
  end

  defp extract_org_id(%{id: id}), do: id
  defp extract_org_id(id) when is_integer(id) or is_binary(id), do: id

  # ---------- list_pending_for_user/2 ----------

  @doc """
  List pending invitations for a user (by email, case-insensitive via
  `citext`). Returns rows with `:organization` and `:invited_by`
  preloaded, sorted by `inserted_at` descending.
  """
  @spec list_pending_for_user(map(), struct()) :: [struct()]
  def list_pending_for_user(config, %{email: email}) do
    schema = config.schemas.invitation
    now = DateTime.utc_now()

    from(i in schema,
      where:
        i.email == ^email and
          is_nil(i.accepted_at) and
          is_nil(i.revoked_at) and
          i.expires_at > ^now,
      order_by: [desc: i.inserted_at],
      preload: [:organization, :invited_by]
    )
    |> config.repo.all()
  end

  # ---------- helpers ----------

  defp append_audit(multi, config, action, scope, extra) do
    audit_opts =
      [
        repo: config.repo,
        audit_schema: Map.get(config, :audit_schema),
        actor_id: get_in_scope(scope, :user, :id),
        metadata: Keyword.get(extra, :metadata, %{})
      ]
      |> maybe_put(:audit_multi_step, Keyword.get(extra, :audit_multi_step))

    Sigra.Audit.log_multi_safe(multi, action, audit_opts)
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  defp get_in_scope(scope, :user, :id) do
    case scope do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end
end
