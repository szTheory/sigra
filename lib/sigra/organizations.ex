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
        scope: [type: :atom, required: true, doc: "Scope struct module."]
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
    ]
  ]

  @doc false
  def __config_schema__, do: @org_config_schema

  @doc false
  def __validate_regex__(value) do
    if is_struct(value, Regex), do: {:ok, value}, else: {:error, "expected a Regex"}
  end

  @doc false
  def __validate_slug_length__({min, max}) when is_integer(min) and is_integer(max) and min > 0 and max >= min do
    {:ok, {min, max}}
  end

  def __validate_slug_length__(_), do: {:error, "expected a {min, max} tuple of positive integers"}

  @doc false
  @spec __validate_config__!(keyword()) :: map()
  def __validate_config__!(opts) do
    validated = NimbleOptions.validate!(opts, @org_config_schema)

    validated
    |> Map.new()
    |> Map.update!(:schemas, &Map.new/1)
  end

  # -- __using__ macro --

  @doc false
  defmacro __using__(opts) do
    quote do
      @sigra_org_config Sigra.Organizations.__validate_config__!(unquote(opts))
                        |> Map.put(:caller_module, __MODULE__)

      @behaviour Sigra.Organizations.Callbacks

      # Thin delegators
      def create_organization(scope, attrs),
        do: Sigra.Organizations.create_organization(@sigra_org_config, scope, attrs)

      def update_organization(scope, org, attrs),
        do: Sigra.Organizations.update_organization(@sigra_org_config, scope, org, attrs)

      def soft_delete_organization(scope, org),
        do: Sigra.Organizations.soft_delete_organization(@sigra_org_config, scope, org)

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
        do: Sigra.Organizations.list_organizations_for_user(@sigra_org_config, user)

      def get_membership(user, org),
        do: Sigra.Organizations.get_membership(@sigra_org_config, user, org)

      # Hook callbacks with no-op defaults (D-04)
      def before_create_organization(changeset, _scope), do: {:ok, changeset}
      def after_create_organization(_org, _scope), do: :ok
      def before_delete_organization(_org, _scope), do: :ok
      def after_delete_organization(_org, _scope), do: :ok
      def before_add_member(_org, _user, _role, _scope), do: :ok
      def after_add_member(_membership, _org, _scope), do: :ok
      def before_role_change(_membership, _role, _scope), do: :ok
      def after_member_remove(_membership, _scope), do: :ok

      defoverridable [
        before_create_organization: 2,
        after_create_organization: 2,
        before_delete_organization: 2,
        after_delete_organization: 2,
        before_add_member: 4,
        after_add_member: 3,
        before_role_change: 3,
        after_member_remove: 2
      ]
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
    org_schema = config.schemas.organization
    membership_schema = config.schemas.membership

    changeset = build_org_changeset(org_schema, attrs, config)

    with {:ok, changeset} <- run_before_hook(config, :before_create_organization, [changeset, scope]) do
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

  Runs `before_delete_organization` hook before the transaction and
  `after_delete_organization` after successful commit. Returns
  `{:ok, organization}` or `{:error, reason}`.
  """
  @spec soft_delete_organization(map(), map(), struct()) :: {:ok, struct()} | {:error, term()}
  def soft_delete_organization(config, scope, org) do
    with :ok <- run_before_hook(config, :before_delete_organization, [org, scope]) do
      result =
        Multi.new()
        |> Multi.update(:organization, Ecto.Changeset.change(org, %{deleted_at: DateTime.utc_now()}))
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
    end
  end

  @doc """
  Adds a user as a member of an organization with the given role.

  Runs `before_add_member` hook before insertion. Returns
  `{:ok, membership}` or `{:error, reason}`.
  """
  @spec add_member(map(), map(), struct(), struct(), atom()) :: {:ok, struct()} | {:error, term()}
  def add_member(config, scope, org, user, role) do
    membership_schema = config.schemas.membership

    with :ok <- run_before_hook(config, :before_add_member, [org, user, role, scope]) do
      result =
        Multi.new()
        |> Multi.insert(:membership, build_membership_changeset(membership_schema, org, user, role))
        |> append_audit(config, "organization.member_add", scope,
          metadata: %{role: to_string(role), user_id: user.id}
        )
        |> config.repo.transaction()
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
  Removes a membership from an organization.

  Guarded by the last-owner check: if the membership is the sole owner,
  returns `{:error, :last_owner}`. Hard-deletes the membership row (D-11).
  """
  @spec remove_member(map(), map(), struct()) :: {:ok, struct()} | {:error, term()}
  def remove_member(config, scope, membership) do
    result =
      Multi.new()
      |> guard_last_owner(membership.organization_id, membership.id, config)
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

  Returns organizations ordered by name.
  """
  @spec list_organizations_for_user(map(), struct()) :: [struct()]
  def list_organizations_for_user(config, user) do
    org_schema = config.schemas.organization
    membership_schema = config.schemas.membership

    from(o in org_schema,
      join: m in ^membership_schema,
      on: m.organization_id == o.id,
      where: m.user_id == ^user.id,
      where: is_nil(o.deleted_at),
      order_by: [asc: o.name]
    )
    |> config.repo.all()
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

  # -- Private Helpers --

  defp build_org_changeset(org_schema, attrs, config) do
    attrs = maybe_generate_slug(attrs)

    struct(org_schema)
    |> Ecto.Changeset.cast(attrs, [:name, :slug])
    |> Ecto.Changeset.validate_required([:name, :slug])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 255)
    |> Slug.validate_slug(slug_config(config))
    |> Ecto.Changeset.unique_constraint(:slug)
  end

  defp update_org_changeset(org, attrs, config) do
    attrs = maybe_generate_slug(attrs)

    org
    |> Ecto.Changeset.cast(attrs, [:name, :slug])
    |> Ecto.Changeset.validate_required([:name, :slug])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 255)
    |> Slug.validate_slug(slug_config(config))
    |> Ecto.Changeset.unique_constraint(:slug)
  end

  defp maybe_generate_slug(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    slug = Map.get(attrs, :slug) || Map.get(attrs, "slug")

    if is_nil(slug) && is_binary(name) do
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

      count =
        from(m in config.schemas.membership,
          where: m.organization_id == ^org_id,
          where: m.role == ^owner_role,
          where: m.id != ^membership_id,
          lock: "FOR UPDATE"
        )
        |> repo.aggregate(:count)

      if count > 0, do: {:ok, :safe}, else: {:error, :last_owner}
    end)
  end

  defp maybe_guard_last_owner_on_demote(multi, membership, new_role, config) do
    if membership.role == config.owner_role && new_role != config.owner_role do
      guard_last_owner(multi, membership.organization_id, membership.id, config)
    else
      multi
    end
  end

  defp normalize_multi_result({:ok, changes}), do: {:ok, changes}
  defp normalize_multi_result({:error, :guard_last_owner, :last_owner, _}), do: {:error, :last_owner}
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
