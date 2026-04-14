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

  @auth_roles [:owner, :admin]

  # ---------- create/2 ----------

  @doc """
  Create a pending invitation for `email` to join `organization_id` with `role`.

  Requires the actor (passed via `attrs.actor`) to carry a membership with
  role in `#{inspect(@auth_roles)}`. Returns:

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
             | :already_member
             | Ecto.Changeset.t()}
  def create(config, %{actor: actor_scope} = attrs) do
    :ok = assert_secret_key_base!(config)
    :ok = Sigra.Organizations.__warn_long_invitation_ttl__(config)

    with :ok <- authorize_create(actor_scope),
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

  defp authorize_create(%{membership: %{role: role}}) when role in @auth_roles, do: :ok
  defp authorize_create(_scope), do: {:error, :unauthorized}

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

  # ---------- revoke/3 ----------

  @doc """
  Revoke a pending invitation.

  Requires the actor to carry a membership with role in
  `#{inspect(@auth_roles)}`. Already-accepted or already-revoked
  invitations return `{:error, :not_pending}` — the DB row is untouched.
  Missing invitation id → `{:error, :not_found}`.
  """
  @spec revoke(map(), integer() | binary(), map()) ::
          {:ok, struct()} | {:error, :not_pending | :unauthorized | :not_found}
  def revoke(config, invitation_id, %{membership: %{role: role}} = actor_scope)
      when role in @auth_roles do
    schema = config.schemas.invitation

    case config.repo.get(schema, invitation_id) do
      nil ->
        {:error, :not_found}

      %{accepted_at: nil, revoked_at: nil} = inv ->
        do_revoke(config, inv, actor_scope)

      _inv ->
        {:error, :not_pending}
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
    audit_opts = [
      repo: config.repo,
      audit_schema: Map.get(config, :audit_schema),
      actor_id: get_in_scope(scope, :user, :id),
      metadata: Keyword.get(extra, :metadata, %{})
    ]

    Sigra.Audit.log_multi_safe(multi, action, audit_opts)
  end

  defp get_in_scope(scope, :user, :id) do
    case scope do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end
end
