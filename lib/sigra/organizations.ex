defmodule Sigra.Organizations do
  @moduledoc """
  Context module for organization CRUD operations, membership management,
  and safety guards.

  This module implements the library-first architecture (D-01): all
  security-critical logic lives here and is updated via `mix deps.update`.
  The generated wrapper module uses `use Sigra.Organizations` to inject
  thin delegators and overridable hook callbacks.

  ## Usage

  In your generated organizations module:

      defmodule MyApp.Organizations do
        use Sigra.Organizations,
          repo: MyApp.Repo,
          schemas: [
            organization: MyApp.Accounts.Organization,
            membership: MyApp.Accounts.OrganizationMembership,
            invitation: MyApp.Accounts.OrganizationInvitation,
            user: MyApp.Accounts.User,
            scope: MyApp.Accounts.Scope
          ]
      end

  ## Configuration

  See `__config_schema__/0` for the full NimbleOptions schema.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Audit
  alias Sigra.Organizations.Slug

  @org_config_schema [
    repo: [
      type: :atom,
      required: true,
      doc: "The Ecto Repo module for database operations."
    ],
    schemas: [
      type: :keyword_list,
      required: true,
      doc: "Schema modules for organization entities.",
      keys: [
        organization: [type: :atom, required: true, doc: "Organization schema module."],
        membership: [type: :atom, required: true, doc: "OrganizationMembership schema module."],
        invitation: [type: :atom, required: true, doc: "OrganizationInvitation schema module."],
        user: [type: :atom, required: true, doc: "User schema module."],
        scope: [type: :atom, required: true, doc: "Scope struct module."],
        user_session: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc:
            "UserSession schema module. Required for `remove_member/3` force-logout (Phase 16 D-21)."
        ],
        organization_slug_alias: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc:
            "OrganizationSlugAlias schema module. Required for `update_slug/4` (Phase 16 D-13)."
        ]
      ]
    ],
    roles: [
      type: {:list, :atom},
      default: [:owner, :admin, :member],
      doc: "Valid membership roles."
    ],
    owner_role: [
      type: :atom,
      default: :owner,
      doc: "The role atom that designates an organization owner."
    ],
    reserved_slugs: [
      type: {:list, :string},
      default: Slug.default_reserved_slugs(),
      doc: "Base list of reserved slug strings."
    ],
    additional_reserved_slugs: [
      type: {:list, :string},
      default: [],
      doc: "Additional reserved slugs (additive to the base list)."
    ],
    slug_format: [
      type: {:custom, Sigra.Organizations, :__validate_regex__, []},
      default: ~r/^[a-z][a-z0-9-]*[a-z0-9]$/,
      doc: "Regex pattern for valid slugs."
    ],
    slug_length: [
      type: {:custom, Sigra.Organizations, :__validate_slug_length__, []},
      default: {3, 63},
      doc: "Tuple of `{min, max}` slug length."
    ],
    enforce_org_scope: [
      type: {:list, :atom},
      default: [],
      doc: "Additional app schemas to enforce org scoping via prepare_query."
    ],
    audit_schema: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc: "Audit event schema module. Nil disables audit logging."
    ],
    hooks: [
      type: :keyword_list,
      default: [],
      doc: "Runtime hooks as `{module, function}` tuples keyed by operation."
    ],
    invitation_ttl: [
      type: :pos_integer,
      default: :timer.hours(24 * 7),
      doc: """
      Lifetime of invitation tokens in milliseconds. Default 7 days
      (`:timer.hours(24 * 7)`). A dev-mode warning is logged on first use if
      the configured value exceeds 30 days (phishing window guidance).
      Does not block runtime.
      """
    ],
    invitation_rate_limit_per_user: [
      type: {:or, [{:tuple, [:pos_integer, :pos_integer]}, {:in, [:infinity]}]},
      default: {20, :timer.hours(24)},
      doc: """
      Per-user rate limit for invitation creation as `{limit, window_ms}` or
      `:infinity` to disable. Default `{20, :timer.hours(24)}` — 20 invites
      per 24-hour rolling window per user (INV-09).
      """
    ],
    invitation_rate_limit_per_org: [
      type: {:or, [{:tuple, [:pos_integer, :pos_integer]}, {:in, [:infinity]}]},
      default: {50, :timer.hours(24)},
      doc: """
      Per-organization rate limit for invitation creation as
      `{limit, window_ms}` or `:infinity` to disable. Default
      `{50, :timer.hours(24)}` — 50 invites per 24-hour rolling window per
      organization. Enforced independently of (and after) the per-user limit.
      """
    ],
    invitation_cleanup_retention_days: [
      type: :pos_integer,
      default: 30,
      doc: """
      Days to retain expired/accepted/revoked invitations past their
      `expires_at` before the optional
      `Sigra.Workers.CleanupExpiredInvitations` Oban worker hard-deletes them.
      Only consulted if the host app opts into the optional worker.
      """
    ],
    emails_module: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc: """
      Host-app module that implements the `organization_invitation/4`
      callback (Phase 17 D-12). When nil, invitation rows still commit but
      no email is sent and the admin sees a warning flash. Set by the
      generator to the host's `{AppName}.Auth.Emails` module.
      """
    ],
    secret_key_base: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: """
      Host-app `secret_key_base` used by `Sigra.Token.generate_invite_envelope/2`
      to sign invitation URLs. Required at runtime for Phase 17 invitation
      creation and acceptance; NimbleOptions does not mark it required
      because Phase 13–16 flows do not need it. First-use inside
      `Sigra.Organizations.Invitations.create/2` raises a clear error if nil.
      """
    ],
    rate_limiter: [
      type: :atom,
      default: Sigra.RateLimiters.Noop,
      doc: """
      Rate limiter module implementing the `Sigra.RateLimiter` behaviour.
      Used by `Sigra.Organizations.Invitations.create/2` for dual-key
      (per-user + per-org) rate limiting. Defaults to `Sigra.RateLimiters.Noop`
      (always-allow) so host apps that have not wired Hammer still see a
      functional — if unlimited — invitation flow. Production deployments
      should set this to `Sigra.RateLimiters.Hammer` (optional Hammer dep).
      """
    ],
    url_builder: [
      type: {:or, [{:fun, 1}, nil]},
      default: nil,
      doc: """
      1-arity function that takes an encoded invitation envelope token
      (`String.t()`) and returns the absolute accept URL (`String.t()`).
      The host app generator wires this to a closure over the app's
      `Phoenix.VerifiedRoutes` endpoint. Required at runtime for
      `Sigra.Organizations.Invitations.create/2`; nil raises a clear error
      at first-use. This avoids string concatenation against a
      `public_base_url` config and keeps route generation in Phoenix's
      blessed path (CLAUDE.md Stack).
      """
    ],
    user_registration_changeset_fn: [
      type: {:or, [{:fun, 1}, nil]},
      default: nil,
      doc: """
      1-arity function that builds the User registration changeset used by
      `Sigra.Organizations.Invitations.accept_with_signup/3`. Required at
      runtime for the anonymous-signup invitation acceptance path (Phase
      17 INV-05); nil raises a clear error at first-use. Generated by the
      installer to `&YourApp.Accounts.User.registration_changeset/1`.
      """
    ]
  ]

  @warn_ttl_threshold_ms :timer.hours(24 * 30)

  @doc false
  def __config_schema__, do: @org_config_schema

  @doc false
  def __validate_regex__(value) do
    if is_struct(value, Regex), do: {:ok, value}, else: {:error, "expected a Regex"}
  end

  @doc false
  def __validate_slug_length__({min, max})
      when is_integer(min) and is_integer(max) and min > 0 and max >= min do
    {:ok, {min, max}}
  end

  def __validate_slug_length__(_),
    do: {:error, "expected a {min, max} tuple of positive integers"}

  @doc false
  @spec __validate_config__!(keyword()) :: map()
  def __validate_config__!(opts) do
    validated = NimbleOptions.validate!(opts, @org_config_schema)

    validated
    |> Map.new()
    |> Map.update!(:schemas, &Map.new/1)
  end

  @doc false
  @spec __warn_long_invitation_ttl__(map()) :: :ok
  def __warn_long_invitation_ttl__(config) do
    if Map.get(config, :invitation_ttl, 0) > @warn_ttl_threshold_ms do
      days = div(config.invitation_ttl, :timer.hours(24))
      require Logger

      Logger.warning(
        "[Sigra] invitation_ttl configured to #{days} days, which exceeds " <>
          "the 30-day recommended phishing-window ceiling. Long-lived invites " <>
          "increase compromise risk. See Sigra.Organizations config docs."
      )
    end

    :ok
  end

  # -- __using__ macro --

  @doc false
  defmacro __using__(opts) do
    quote do
      @sigra_org_config Sigra.Organizations.__validate_config__!(unquote(opts))
                        |> Map.put(:caller_module, __MODULE__)

      @behaviour Sigra.Organizations.Callbacks

      @doc """
      Returns the validated organization config map.

      Exposed so Phase 14 plugs (`Sigra.Plug.LoadActiveOrganization`,
      `Sigra.Plug.PutActiveOrganization`) and the generated `on_mount`
      callback can reach into `Sigra.Organizations.select_active_organization/3`
      and `Sigra.Scope.Hydration.hydrate/3` without duplicating config
      plumbing.
      """
      def __sigra_org_config__, do: @sigra_org_config

      # Thin delegators
      def create_organization(scope, attrs),
        do: Sigra.Organizations.create_organization(@sigra_org_config, scope, attrs)

      def update_organization(scope, org, attrs),
        do: Sigra.Organizations.update_organization(@sigra_org_config, scope, org, attrs)

      def soft_delete_organization(scope, org, params),
        do: Sigra.Organizations.soft_delete_organization(@sigra_org_config, scope, org, params)

      def rename_organization(scope, org, params),
        do: Sigra.Organizations.rename_organization(@sigra_org_config, scope, org, params)

      def update_slug(scope, org, params),
        do: Sigra.Organizations.update_slug(@sigra_org_config, scope, org, params)

      def list_members_with_activity(scope, opts \\ []),
        do: Sigra.Organizations.list_members_with_activity(@sigra_org_config, scope, opts)

      def count_members(scope),
        do: Sigra.Organizations.count_members(@sigra_org_config, scope)

      def get_active_slug_alias(slug),
        do: Sigra.Organizations.get_active_slug_alias(@sigra_org_config, slug)

      def add_member(scope, org, user, role),
        do: Sigra.Organizations.add_member(@sigra_org_config, scope, org, user, role)

      def remove_member(scope, membership),
        do: Sigra.Organizations.remove_member(@sigra_org_config, scope, membership)

      def change_role(scope, membership, new_role),
        do: Sigra.Organizations.change_role(@sigra_org_config, scope, membership, new_role)

      def get_organization!(id),
        do: Sigra.Organizations.get_organization!(@sigra_org_config, id)

      def get_organization_by_slug(slug),
        do: Sigra.Organizations.get_organization_by_slug(@sigra_org_config, slug)

      def list_organizations_for_user(user),
        do: Sigra.Organizations.list_organizations_with_roles_for_user(@sigra_org_config, user)

      def list_pending_invitations_for_user(user),
        do: Sigra.Organizations.list_pending_invitations_for_user(@sigra_org_config, user)

      def get_membership(user, org),
        do: Sigra.Organizations.get_membership(@sigra_org_config, user, org)

      # Phase 17 invitation lifecycle delegators (accept/accept_with_signup
      # land in Plan 17-05).
      def create_invitation(attrs),
        do: Sigra.Organizations.Invitations.create(@sigra_org_config, attrs)

      def revoke_invitation(invitation_id, actor_scope),
        do: Sigra.Organizations.Invitations.revoke(@sigra_org_config, invitation_id, actor_scope)

      def list_pending_invitations(org),
        do: Sigra.Organizations.Invitations.list_pending(@sigra_org_config, org)

      def accept_invitation(signed_token, current_user),
        do: Sigra.Organizations.Invitations.accept(@sigra_org_config, signed_token, current_user)

      def accept_invitation_with_signup(signed_token, user_params),
        do:
          Sigra.Organizations.Invitations.accept_with_signup(
            @sigra_org_config,
            signed_token,
            user_params
          )

      # Hook callbacks with no-op defaults (D-04)
      def before_create_organization(changeset, _scope), do: {:ok, changeset}
      def after_create_organization(_org, _scope), do: :ok
      def before_delete_organization(_org, _scope), do: :ok
      def after_delete_organization(_org, _scope), do: :ok
      def before_add_member(_org, _user, _role, _scope), do: :ok
      def after_add_member(_membership, _org, _scope), do: :ok
      def before_role_change(_membership, _role, _scope), do: :ok
      def after_member_remove(_membership, _scope), do: :ok

      defoverridable before_create_organization: 2,
                     after_create_organization: 2,
                     before_delete_organization: 2,
                     after_delete_organization: 2,
                     before_add_member: 4,
                     after_add_member: 3,
                     before_role_change: 3,
                     after_member_remove: 2
    end
  end

  # -- Public API --

  @doc """
  Creates an organization and its initial owner membership atomically.

  The creating user (from `scope.user`) becomes the owner. Returns
  `{:ok, organization}` on success or `{:error, changeset}` on failure.
  """
  @spec create_organization(map(), map(), map()) :: {:ok, struct()} | {:error, term()}
  def create_organization(config, scope, attrs) do
    # D-00 (Phase 18): owner_user_id is the sticky origin owner of the org.
    # It must be set by library code via put_change/3 — NEVER from host-supplied
    # attrs — so that the audit invariant "host cannot spoof origin owner" holds
    # structurally. Raise loudly if scope.user is nil rather than silently
    # defaulting owner_user_id to nil, which would leave a team org with no
    # origin owner.
    case scope do
      %{user: %{id: user_id}} when not is_nil(user_id) ->
        do_create_organization(config, scope, attrs, user_id)

      _ ->
        raise ArgumentError,
              "create_organization/3 requires a scope with a loaded user (got: #{inspect(scope)})"
    end
  end

  defp do_create_organization(config, scope, attrs, owner_user_id) do
    org_schema = config.schemas.organization
    membership_schema = config.schemas.membership

    changeset =
      org_schema
      |> build_org_changeset(attrs, config)
      |> Ecto.Changeset.put_change(:owner_user_id, owner_user_id)

    with {:ok, changeset} <-
           run_before_hook(config, :before_create_organization, [changeset, scope]) do
      result =
        Multi.new()
        |> Multi.insert(:organization, changeset)
        |> Multi.insert(:membership, fn %{organization: org} ->
          build_membership_changeset(membership_schema, org, scope.user, config.owner_role)
        end)
        |> append_audit(config, "organization.create", scope)
        |> config.repo.transaction()
        |> normalize_multi_result()

      case result do
        {:ok, %{organization: org}} ->
          run_after_hook(config, :after_create_organization, [org, scope])
          {:ok, org}

        error ->
          error
      end
    end
  end

  @doc """
  Updates an organization's attributes.

  Returns `{:ok, updated_org}` or `{:error, changeset}`.
  """
  @spec update_organization(map(), map(), struct(), map()) :: {:ok, struct()} | {:error, term()}
  def update_organization(config, scope, org, attrs) do
    changeset = update_org_changeset(org, attrs, config)

    result =
      Multi.new()
      |> Multi.update(:organization, changeset)
      |> append_audit(config, "organization.update", scope)
      |> config.repo.transaction()
      |> normalize_multi_result()

    case result do
      {:ok, %{organization: org}} -> {:ok, org}
      error -> error
    end
  end

  @doc """
  Soft-deletes an organization by setting `deleted_at`.

  Requires both the current user's password AND a typed-confirm of the
  organization's name (Phase 16 D-11, D-15). Returns:

    * `{:ok, organization}` — success
    * `{:error, :invalid_password}` — password did not match
    * `{:error, %Ecto.Changeset{}}` — confirm_name mismatch or other
      validation failure

  The caller is responsible for refreshing sudo state after success
  (Phase 16 D-11, moved out of the library in 16-01 because the org
  config does not carry the session token). LiveViews ship this in Plan
  02 via `Sigra.Auth.confirm_sudo/3`.

  Runs `before_delete_organization` hook before the transaction and
  `after_delete_organization` after successful commit.
  """
  @spec soft_delete_organization(map(), map(), struct(), map()) ::
          {:ok, struct()} | {:error, :invalid_password | Ecto.Changeset.t() | term()}
  def soft_delete_organization(config, scope, org, params) do
    types = %{password: :string, confirm_name: :string}

    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(normalize_params(params), Map.keys(types))
      |> Ecto.Changeset.validate_required([:password, :confirm_name])
      |> validate_confirm(:confirm_name, org.name, "does not match organization name")

    with true <- changeset.valid? || {:error, changeset},
         true <- verify_user_password(scope, changeset) || {:error, :invalid_password},
         :ok <- run_before_hook(config, :before_delete_organization, [org, scope]) do
      result =
        Multi.new()
        |> Multi.update(
          :organization,
          Ecto.Changeset.change(org, %{
            deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
        )
        |> append_audit(config, "organization.delete", scope)
        |> config.repo.transaction()
        |> normalize_multi_result()

      case result do
        {:ok, %{organization: org}} ->
          run_after_hook(config, :after_delete_organization, [org, scope])
          {:ok, org}

        error ->
          error
      end
    else
      {:error, _} = err -> err
    end
  end

  @doc """
  Renames an organization. Only `:name` is updatable via this function;
  slug changes go through `update_slug/4` (Phase 16 D-15).

  Returns `{:ok, org}` or `{:error, changeset}`.
  """
  @spec rename_organization(map(), map(), struct(), map()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def rename_organization(config, scope, org, params) do
    params = normalize_params(params)

    changeset =
      org
      |> Ecto.Changeset.cast(params, [:name])
      |> Ecto.Changeset.validate_required([:name])
      |> Ecto.Changeset.validate_length(:name, min: 1, max: 100)

    if changeset.valid? do
      result =
        Multi.new()
        |> Multi.update(:organization, changeset)
        |> append_audit(config, "organization.rename", scope,
          metadata: %{old_name: org.name, new_name: Map.get(params, :name)}
        )
        |> config.repo.transaction()
        |> normalize_multi_result()

      case result do
        {:ok, %{organization: updated}} -> {:ok, updated}
        error -> error
      end
    else
      {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Updates an organization's slug under sudo + typed-confirm gates.

  Requires:
    * `:slug` — new slug (must match slug_format + non-reserved + unique)
    * `:password` — current user's password (sudo re-verification)
    * `:confirm_slug` — typed-back copy of the CURRENT slug (so users
      cannot slip and rename the wrong org)

  On success, atomically:
    1. Updates `org.slug`
    2. Inserts an `OrganizationSlugAlias` row with the previous slug
       and `expires_at = now + 7 days` so the load plug can redirect
       old URLs for the grace window (Phase 16 D-13).
    3. Appends audit event `"organization.slug_change"`.

  Returns:
    * `{:ok, org}`
    * `{:error, :invalid_password}`
    * `{:error, %Ecto.Changeset{}}`
  """
  @spec update_slug(map(), map(), struct(), map()) ::
          {:ok, struct()} | {:error, :invalid_password | Ecto.Changeset.t()}
  def update_slug(config, scope, org, params) do
    params = normalize_params(params)
    types = %{slug: :string, password: :string, confirm_slug: :string}
    reserved = Slug.default_reserved_slugs() ++ Map.get(config, :additional_reserved_slugs, [])

    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.validate_required([:slug, :password, :confirm_slug])
      |> Ecto.Changeset.validate_format(
        :slug,
        Map.get(config, :slug_format, ~r/^[a-z][a-z0-9-]*[a-z0-9]$/)
      )
      |> Ecto.Changeset.validate_exclusion(:slug, reserved, message: "is reserved")
      |> validate_confirm(:confirm_slug, org.slug, "does not match current slug")

    with true <- changeset.valid? || {:error, %{changeset | action: :update}},
         true <- verify_user_password(scope, changeset) || {:error, :invalid_password} do
      new_slug = Ecto.Changeset.get_change(changeset, :slug)
      old_slug = org.slug
      expires_at = DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
      org_changeset = Ecto.Changeset.change(org, %{slug: new_slug})

      alias_schema = Map.get(config.schemas, :organization_slug_alias)

      multi =
        Multi.new()
        |> Multi.update(:organization, org_changeset)
        |> maybe_insert_slug_alias(alias_schema, org.id, old_slug, expires_at)
        |> append_audit(config, "organization.slug_change", scope,
          metadata: %{
            old_slug: old_slug,
            new_slug: new_slug,
            alias_expires_at: DateTime.to_iso8601(expires_at)
          }
        )

      case multi |> config.repo.transaction() |> normalize_multi_result() do
        {:ok, %{organization: updated}} -> {:ok, updated}
        error -> error
      end
    else
      {:error, _} = err -> err
    end
  end

  @doc """
  Lists memberships for the active organization with the user's most
  recent session activity timestamp for that org (Phase 16 D-14, CD-06).

  Returns a list of `{membership, last_active_at | nil}` tuples, sorted
  by membership inserted_at descending. The `last_active_at` comes from
  a LATERAL subquery against `user_sessions` scoped to the current org
  (not a cross-org high-water mark).

  ## Options

    * `:limit` — default 100
    * `:offset` — default 0

  Raises `ArgumentError` if `scope.active_organization` is nil (source
  of O-1 cross-tenant leak protection).
  """
  @spec list_members_with_activity(map(), map(), keyword()) ::
          [{struct(), DateTime.t() | nil}]
  def list_members_with_activity(config, scope, opts \\ []) do
    org =
      scope.active_organization ||
        raise ArgumentError,
              "list_members_with_activity/3 requires scope.active_organization (cross-tenant leak guard)"

    membership_schema = config.schemas.membership
    user_schema = config.schemas.user
    user_session_schema = Map.get(config.schemas, :user_session)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query =
      if user_session_schema do
        last_active_sub =
          from(s in user_session_schema,
            where:
              s.user_id == parent_as(:membership).user_id and
                s.active_organization_id == ^org.id,
            order_by: [desc: s.last_active_at],
            limit: 1,
            select: %{last_active_at: s.last_active_at}
          )

        from(m in membership_schema,
          as: :membership,
          where: m.organization_id == ^org.id,
          join: u in ^user_schema,
          on: u.id == m.user_id,
          left_lateral_join: la in subquery(last_active_sub),
          on: true,
          order_by: [desc: m.inserted_at],
          limit: ^limit,
          offset: ^offset,
          preload: [user: u],
          select: {m, la.last_active_at}
        )
      else
        from(m in membership_schema,
          where: m.organization_id == ^org.id,
          join: u in ^user_schema,
          on: u.id == m.user_id,
          order_by: [desc: m.inserted_at],
          limit: ^limit,
          offset: ^offset,
          preload: [user: u],
          select: {m, nil}
        )
      end

    config.repo.all(query)
  end

  @doc """
  Returns the count of memberships in the current active organization.

  Unaffected by `:limit` / `:offset` options passed to
  `list_members_with_activity/3`.
  """
  @spec count_members(map(), map()) :: non_neg_integer()
  def count_members(config, scope) do
    org =
      scope.active_organization ||
        raise ArgumentError,
              "count_members/2 requires scope.active_organization"

    membership_schema = config.schemas.membership

    config.repo.aggregate(
      from(m in membership_schema, where: m.organization_id == ^org.id),
      :count
    )
  end

  @doc """
  Fetches a non-expired organization slug alias row for the given old
  slug. Used by `Sigra.Plug.LoadOrganizationFromSlug` to follow 7-day
  redirects from renamed-org URLs to the canonical slug.

  Returns the alias row or `nil`. Soft-expired rows (expires_at <= now)
  are treated as non-existent.
  """
  @spec get_active_slug_alias(map(), binary()) :: struct() | nil
  def get_active_slug_alias(config, slug) do
    case Map.get(config.schemas, :organization_slug_alias) do
      nil ->
        nil

      alias_schema ->
        now = DateTime.utc_now()

        from(a in alias_schema,
          where: a.old_slug == ^slug and a.expires_at > ^now,
          limit: 1
        )
        |> config.repo.one()
    end
  end

  @doc """
  Adds a user as a member of an organization with the given role.

  Runs `before_add_member` hook before insertion. Returns
  `{:ok, membership}` or `{:error, reason}`.
  """
  @spec add_member(map(), map(), struct(), struct(), atom()) :: {:ok, struct()} | {:error, term()}
  def add_member(config, scope, org, user, role) do
    with :ok <- run_before_hook(config, :before_add_member, [org, user, role, scope]) do
      result =
        config
        |> add_member_multi(scope, org, user, role)
        |> config.repo.transact()
        |> normalize_multi_result()

      case result do
        {:ok, %{membership: membership}} ->
          run_after_hook(config, :after_add_member, [membership, org, scope])
          {:ok, membership}

        error ->
          error
      end
    end
  end

  @doc """
  Pure `Ecto.Multi` builder for adding a user to an organization.

  Returns a multi with steps:

    * `:add_member_resolve_user` — resolves the user reference
    * `:membership` — inserts the membership changeset
    * audit step (when `:audit_schema` is configured)

  Accepts `user_ref` as either a `%User{}` struct or a
  `{:changes_key, atom}` tuple referencing a prior step in a composed
  multi. The `{:changes_key, _}` shape exists so this builder can be
  composed via `Ecto.Multi.append/2` with
  `Sigra.Auth.register_user_multi/2` inside
  `Sigra.Organizations.Invitations.accept_with_signup/3` (Phase 17 D-07).

  Makes ZERO Repo calls — construction is pure.

  ## Example — direct user

      config
      |> Sigra.Organizations.add_member_multi(scope, org, user, :member)
      |> config.repo.transact()

  ## Example — composed with register_user_multi/2

      register_multi =
        Sigra.Auth.register_user_multi(attrs, changeset_fn: &User.registration_changeset/1)

      member_multi =
        Sigra.Organizations.add_member_multi(
          config,
          scope,
          org,
          {:changes_key, :user},
          :member
        )

      register_multi
      |> Ecto.Multi.append(member_multi)
      |> config.repo.transact()

  """
  @doc since: "0.4.0"
  @spec add_member_multi(map(), map(), struct(), struct() | {:changes_key, atom()}, atom()) ::
          Ecto.Multi.t()
  def add_member_multi(config, scope, org, user_ref, role) do
    membership_schema = config.schemas.membership

    Multi.new()
    |> Multi.run(:add_member_resolve_user, fn _repo, changes ->
      user =
        case user_ref do
          {:changes_key, key} -> Map.fetch!(changes, key)
          %_{} = u -> u
        end

      {:ok, user}
    end)
    |> Multi.insert(:membership, fn %{add_member_resolve_user: user} ->
      build_membership_changeset(membership_schema, org, user, role)
    end)
    |> append_audit(config, "organization.member_add", scope,
      metadata: add_member_audit_metadata(user_ref, role)
    )
  end

  # Audit metadata built at Multi-construction time. For direct %User{}
  # references we can stamp user_id immediately; for {:changes_key, _}
  # the user isn't resolved until run-time, so user_id is intentionally
  # omitted (the membership row itself still carries user_id).
  defp add_member_audit_metadata({:changes_key, _key}, role) do
    %{role: to_string(role)}
  end

  defp add_member_audit_metadata(%_{} = user, role) do
    %{role: to_string(role), user_id: Map.get(user, :id)}
  end

  @doc """
  Removes a membership from an organization.

  Guarded by the last-owner check: if the membership is the sole owner,
  returns `{:error, :last_owner}`. Hard-deletes the membership row (D-11).
  """
  @spec remove_member(map(), map(), struct()) :: {:ok, struct()} | {:error, term()}
  def remove_member(config, scope, membership) do
    result =
      Multi.new()
      |> guard_last_owner(membership.organization_id, membership.id, config)
      |> purge_org_sessions(membership, config)
      |> Multi.delete(:membership, membership)
      |> append_audit(config, "organization.member_remove", scope,
        metadata: %{user_id: membership.user_id}
      )
      |> config.repo.transaction()
      |> normalize_multi_result()

    case result do
      {:ok, %{membership: membership}} ->
        run_after_hook(config, :after_member_remove, [membership, scope])
        {:ok, membership}

      error ->
        error
    end
  end

  @doc """
  Changes a membership's role.

  If demoting from the owner role, runs the last-owner guard. Returns
  `{:ok, membership}` or `{:error, :last_owner}` / `{:error, changeset}`.
  """
  @spec change_role(map(), map(), struct(), atom()) :: {:ok, struct()} | {:error, term()}
  def change_role(config, scope, membership, new_role) do
    with :ok <- run_before_hook(config, :before_role_change, [membership, new_role, scope]) do
      role_changeset = Ecto.Changeset.change(membership, %{role: new_role})

      multi =
        Multi.new()
        |> maybe_guard_last_owner_on_demote(membership, new_role, config)
        |> Multi.update(:membership, role_changeset)
        |> append_audit(config, "organization.member_role_change", scope,
          metadata: %{
            old_role: to_string(membership.role),
            new_role: to_string(new_role),
            user_id: membership.user_id
          }
        )

      result =
        multi
        |> config.repo.transaction()
        |> normalize_multi_result()

      case result do
        {:ok, %{membership: membership}} -> {:ok, membership}
        error -> error
      end
    end
  end

  @doc """
  Gets a non-deleted organization by ID.

  Raises `Ecto.NoResultsError` if not found or if soft-deleted.
  """
  @spec get_organization!(map(), binary()) :: struct()
  def get_organization!(config, id) do
    org_schema = config.schemas.organization

    from(o in org_schema, where: o.id == ^id and is_nil(o.deleted_at))
    |> config.repo.one!()
  end

  @doc """
  Gets a non-deleted organization by slug.

  Returns `nil` if not found or if soft-deleted.
  """
  @spec get_organization_by_slug(map(), String.t()) :: struct() | nil
  def get_organization_by_slug(config, slug) do
    org_schema = config.schemas.organization

    from(o in org_schema, where: o.slug == ^slug and is_nil(o.deleted_at))
    |> config.repo.one()
  end

  @doc """
  Lists non-deleted organizations for a user via their memberships.

  Returns organizations in **unspecified order**. Callers that need a stable
  UI listing (e.g. an org switcher) should sort the result themselves —
  typically by `name` for display or by `inserted_at` for recency. The
  library does not impose an order here because the only internal caller
  (`select_active_organization/3`) re-sorts by `inserted_at desc` anyway, and
  paying the DB sort cost twice is wasted work (IN-02).
  """
  @spec list_organizations_for_user(map(), struct()) :: [struct()]
  def list_organizations_for_user(config, user) do
    org_schema = config.schemas.organization
    membership_schema = config.schemas.membership

    from(o in org_schema,
      join: m in ^membership_schema,
      on: m.organization_id == o.id,
      where: m.user_id == ^user.id,
      where: is_nil(o.deleted_at)
    )
    |> config.repo.all()
  end

  @doc """
  Phase 16 Plan 03 variant that returns `{org, role}` tuples instead of bare
  orgs, ordered by `membership.inserted_at DESC` (most recently joined first).

  Used by:
    * the generated `on_mount :assign_user_organizations` hook, which
      assigns the tuple list as `@user_organizations` for the org switcher
      component to render with role badges
    * `OrganizationsLive.Index` Branch C (picker) to render each
      membership row with its role badge
    * the generated `/organizations/switch` controller to resolve a target
      organization from the current user's memberships (membership-before-
      write authz choke point)

  Soft-deleted orgs are filtered via `is_nil(o.deleted_at)` — T-16-03-04.
  """
  @spec list_organizations_with_roles_for_user(map(), struct()) :: [{struct(), atom()}]
  def list_organizations_with_roles_for_user(config, user) do
    org_schema = config.schemas.organization
    membership_schema = config.schemas.membership

    from(m in membership_schema,
      join: o in ^org_schema,
      on: o.id == m.organization_id,
      where: m.user_id == ^user.id,
      where: is_nil(o.deleted_at),
      order_by: [desc: m.inserted_at],
      select: {o, m.role}
    )
    |> config.repo.all()
  end

  @doc """
  Lists pending invitations for a user (by email, case-insensitive).

  Delegates to `Sigra.Organizations.Invitations.list_pending_for_user/2`.
  Phase 17 D-14 replaces the Phase 16 stub with the real query.
  """
  @spec list_pending_invitations_for_user(map(), struct()) :: [struct()]
  def list_pending_invitations_for_user(config, user) do
    Sigra.Organizations.Invitations.list_pending_for_user(config, user)
  end

  @doc """
  Gets a membership for a user in an organization.

  Returns `nil` if the user is not a member.
  """
  @spec get_membership(map(), struct(), struct()) :: struct() | nil
  def get_membership(config, user, org) do
    membership_schema = config.schemas.membership

    from(m in membership_schema,
      where: m.user_id == ^user.id and m.organization_id == ^org.id
    )
    |> config.repo.one()
  end

  @doc """
  Fetches a non-deleted organization by id without raising.

  Added in Phase 14 for the scope-hydration path, which must fail-closed on
  stale session pointers rather than propagating `Ecto.NoResultsError` into
  the request pipeline (PITFALLS O-6).

  Returns `{:ok, org}` or `{:error, :not_found}`. Soft-deleted rows
  (`deleted_at != nil`) are treated as not found.
  """
  @spec fetch_organization(map(), binary()) :: {:ok, struct()} | {:error, :not_found}
  def fetch_organization(config, id) do
    org_schema = config.schemas.organization

    case from(o in org_schema, where: o.id == ^id and is_nil(o.deleted_at))
         |> config.repo.one() do
      nil -> {:error, :not_found}
      org -> {:ok, org}
    end
  end

  @doc """
  Pure selector that returns the active organization to land a user on.

  Called from login (`Sigra.Auth.create_session/4`) and from the stale-pointer
  recovery path in `Sigra.Plug.LoadActiveOrganization`. No side effects — no
  session writes, no audit, no DB writes beyond the reads required to list
  memberships.

  ## Options

    * `:previous_active_organization_id` (binary_id | nil) — if the user has
      2+ orgs and one matches this pointer, return `{:ok, that_org}` (resume
      semantics). On stale recovery this is passed as `nil` — the stale
      pointer must NOT be resumed.

    * `:strategy` — reserved for v1.2, ignored in v1.1.

  ## Returns

    * `{:ok, org}` — user has exactly one org, or resume pointer matched.
    * `{:none, :zero_orgs}` — user has no memberships.
    * `{:multiple, orgs}` — 2+ memberships, no resume pointer match. `orgs`
      is sorted by `inserted_at` descending for stable UI ordering (CD-04).

  Added in Phase 14 (Plan 14-01, D-11). Covers ORG-SCOPE-06.
  """
  @spec select_active_organization(map(), struct(), keyword()) ::
          {:ok, struct()} | {:none, :zero_orgs} | {:multiple, [struct()]}
  def select_active_organization(config, user, opts \\ []) do
    previous = Keyword.get(opts, :previous_active_organization_id)

    case list_organizations_for_user(config, user) do
      [] ->
        {:none, :zero_orgs}

      [only] ->
        {:ok, only}

      orgs when is_list(orgs) ->
        sorted = Enum.sort_by(orgs, & &1.inserted_at, {:desc, DateTime})

        case previous && Enum.find(sorted, &(&1.id == previous)) do
          nil -> {:multiple, sorted}
          resumed -> {:ok, resumed}
        end
    end
  end

  @doc """
  Variant of `select_active_organization/3` that also returns the membership
  struct on the `{:ok, org}` branches, avoiding a second `get_membership/3`
  roundtrip on the stale-pointer recovery path.

  Internal to Phase 14+ plug recovery. Prefer `select_active_organization/3`
  for callers that don't need the membership struct.

  ## Returns

    * `{:ok, org, membership}` — user has exactly one org, or resume pointer
      matched.
    * `{:none, :zero_orgs}` — user has no memberships.
    * `{:multiple, orgs}` — 2+ memberships, no resume pointer match.
      Membership is intentionally NOT returned on this branch because the
      caller must still prompt the user; the picker doesn't know which org
      will be chosen.

  Added in Phase 14 (WR-03 fix). The single-query implementation joins the
  membership table once and reuses the rows for both org listing and
  membership resolution.
  """
  @spec select_active_organization_with_membership(map(), struct(), keyword()) ::
          {:ok, struct(), struct()}
          | {:none, :zero_orgs}
          | {:multiple, [struct()]}
  def select_active_organization_with_membership(config, user, opts \\ []) do
    previous = Keyword.get(opts, :previous_active_organization_id)

    case list_memberships_with_orgs_for_user(config, user) do
      [] ->
        {:none, :zero_orgs}

      [{only_org, only_membership}] ->
        {:ok, only_org, only_membership}

      pairs when is_list(pairs) ->
        sorted = Enum.sort_by(pairs, fn {org, _m} -> org.inserted_at end, {:desc, DateTime})

        case previous && Enum.find(sorted, fn {org, _m} -> org.id == previous end) do
          nil -> {:multiple, Enum.map(sorted, fn {org, _m} -> org end)}
          {resumed_org, resumed_membership} -> {:ok, resumed_org, resumed_membership}
        end
    end
  end

  # Lists `[{org, membership}]` tuples for a user via a single joined query.
  # Used by `select_active_organization_with_membership/3` to keep the
  # stale-pointer recovery path to exactly one DB roundtrip for the list.
  defp list_memberships_with_orgs_for_user(config, user) do
    org_schema = config.schemas.organization
    membership_schema = config.schemas.membership

    from(o in org_schema,
      join: m in ^membership_schema,
      on: m.organization_id == o.id,
      where: m.user_id == ^user.id,
      where: is_nil(o.deleted_at),
      select: {o, m}
    )
    |> config.repo.all()
  end

  # -- Private Helpers --

  defp build_org_changeset(org_schema, attrs, config) do
    attrs = maybe_generate_slug(attrs)

    struct(org_schema)
    |> Ecto.Changeset.cast(attrs, [:name, :slug])
    |> Ecto.Changeset.validate_required([:name, :slug])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 255)
    |> Slug.validate_slug(slug_config(config))
    |> Ecto.Changeset.unique_constraint(:slug, name: :organizations_slug_active_index)
  end

  defp update_org_changeset(org, attrs, config) do
    # Intentionally do NOT call maybe_generate_slug on update. Auto-generating
    # a slug from a renamed org would silently rewrite URLs. Host apps must
    # pass an explicit `:slug` attr to change the slug.
    org
    |> Ecto.Changeset.cast(attrs, [:name, :slug])
    |> Ecto.Changeset.validate_required([:name, :slug])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 255)
    |> Slug.validate_slug(slug_config(config))
    |> Ecto.Changeset.unique_constraint(:slug, name: :organizations_slug_active_index)
  end

  defp maybe_generate_slug(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    slug = Map.get(attrs, :slug) || Map.get(attrs, "slug")

    if is_nil(slug) && is_binary(name) && name != "" do
      Map.put(attrs, :slug, Slug.generate_slug(name))
    else
      attrs
    end
  end

  defp slug_config(config) do
    %{
      reserved_slugs: Map.get(config, :reserved_slugs, Slug.default_reserved_slugs()),
      additional_reserved_slugs: Map.get(config, :additional_reserved_slugs, []),
      slug_format: Map.get(config, :slug_format, ~r/^[a-z][a-z0-9-]*[a-z0-9]$/),
      slug_length: Map.get(config, :slug_length, {3, 63})
    }
  end

  defp build_membership_changeset(membership_schema, org, user, role) do
    struct(membership_schema)
    |> Ecto.Changeset.cast(%{role: role}, [:role])
    |> Ecto.Changeset.validate_required([:role])
    |> Ecto.Changeset.put_change(:organization_id, org.id)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Ecto.Changeset.unique_constraint([:user_id, :organization_id])
  end

  defp guard_last_owner(multi, org_id, membership_id, config) do
    Multi.run(multi, :guard_last_owner, fn repo, _changes ->
      owner_role = config.owner_role

      # Lock ALL owner rows for this org (including the row being acted on)
      # with FOR UPDATE, then filter in Elixir. This serializes concurrent
      # removals/demotions so two callers cannot each see the other as the
      # surviving owner. PostgreSQL does not allow FOR UPDATE with aggregate
      # functions, so we SELECT ids and filter.
      owner_ids =
        from(m in config.schemas.membership,
          where: m.organization_id == ^org_id,
          where: m.role == ^owner_role,
          select: m.id,
          lock: "FOR UPDATE"
        )
        |> repo.all()

      others = Enum.reject(owner_ids, &(&1 == membership_id))
      if others != [], do: {:ok, :safe}, else: {:error, :last_owner}
    end)
  end

  defp normalize_params(params) when is_map(params) do
    Enum.into(params, %{}, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> params
  end

  defp normalize_params(params), do: params

  defp validate_confirm(changeset, field, expected, message) do
    Ecto.Changeset.validate_change(changeset, field, fn _, typed ->
      if typed == expected, do: [], else: [{field, message}]
    end)
  end

  # Returns true if verification succeeds; returns the sentinel false
  # so the caller (a `with` expression) short-circuits to
  # {:error, :invalid_password}. Uses the user's :hashed_password field.
  defp verify_user_password(scope, changeset) do
    password =
      Ecto.Changeset.get_change(changeset, :password) ||
        Ecto.Changeset.get_field(changeset, :password)

    user = scope.user
    hashed = user && Map.get(user, :hashed_password)

    cond do
      is_nil(hashed) ->
        Sigra.Crypto.no_user_verify()
        false

      is_binary(password) ->
        Sigra.Crypto.verify_password(password, hashed)

      true ->
        false
    end
  end

  defp maybe_insert_slug_alias(multi, nil, _org_id, _old_slug, _expires_at), do: multi

  defp maybe_insert_slug_alias(multi, alias_schema, org_id, old_slug, expires_at) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    alias_attrs = %{
      organization_id: org_id,
      old_slug: old_slug,
      expires_at: expires_at,
      inserted_at: now
    }

    Multi.insert(multi, :slug_alias, fn _ ->
      struct(alias_schema) |> Ecto.Changeset.change(alias_attrs)
    end)
  end

  # Phase 16 D-21 / SC-4: purge all user_sessions rows for the removed user
  # whose active_organization_id == the org being left. Runs inside the same
  # Multi as the membership delete so last-owner rollback also reverts the
  # session purge. No-op if config.schemas.user_session is nil (pre-Phase 16
  # config; the thin-wrapper template is updated in Plan 02).
  defp purge_org_sessions(multi, membership, config) do
    case Map.get(config.schemas, :user_session) do
      nil ->
        multi

      user_session_schema ->
        Multi.delete_all(multi, :purge_org_sessions, fn _ ->
          from(s in user_session_schema,
            where:
              s.user_id == ^membership.user_id and
                s.active_organization_id == ^membership.organization_id
          )
        end)
    end
  end

  defp maybe_guard_last_owner_on_demote(multi, membership, new_role, config) do
    if membership.role == config.owner_role && new_role != config.owner_role do
      guard_last_owner(multi, membership.organization_id, membership.id, config)
    else
      multi
    end
  end

  defp normalize_multi_result({:ok, changes}), do: {:ok, changes}

  defp normalize_multi_result({:error, :guard_last_owner, :last_owner, _}),
    do: {:error, :last_owner}

  defp normalize_multi_result({:error, _step, %Ecto.Changeset{} = cs, _}), do: {:error, cs}
  defp normalize_multi_result({:error, _step, reason, _}), do: {:error, reason}

  defp append_audit(multi, config, action, scope, extra \\ []) do
    audit_opts = [
      repo: config.repo,
      audit_schema: config[:audit_schema],
      actor_id: get_in_scope(scope, :user, :id),
      metadata: Keyword.get(extra, :metadata, %{})
    ]

    Audit.log_multi_safe(multi, action, audit_opts)
  end

  defp get_in_scope(scope, :user, :id) do
    case scope do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end

  # Runs a before_* hook callback on the caller module.
  # When no caller_module is set (direct API usage), returns the appropriate
  # no-op default: {:ok, changeset} for before_create, :ok for others.
  defp run_before_hook(config, :before_create_organization, [changeset | _] = args) do
    case config[:caller_module] do
      nil -> {:ok, changeset}
      module -> apply(module, :before_create_organization, args)
    end
  end

  defp run_before_hook(config, hook_name, args) do
    case config[:caller_module] do
      nil -> :ok
      module -> apply(module, hook_name, args)
    end
  end

  defp run_after_hook(config, hook_name, args) do
    case config[:caller_module] do
      nil -> :ok
      module -> apply(module, hook_name, args)
    end
  end
end
