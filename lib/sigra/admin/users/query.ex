defmodule Sigra.Admin.Users.Query do
  @moduledoc """
  Canonical query contract for the admin user list surface.
  """

  import Ecto.Query

  alias Sigra.Admin.Authorizer
  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Hooks

  @allowed_params ~w(
    q
    organization
    page
    page_size
    order_by
    order_direction
    confirmed
    mfa
    passkeys
    locked
    deleted
    provider
    registered_from
    registered_to
  )

  @filter_fields [
    :q,
    :organization,
    :confirmed,
    :mfa,
    :passkeys,
    :locked,
    :deleted,
    :provider,
    :registered_from,
    :registered_to
  ]
  @filter_ops %{q: :ilike, organization: :ilike, registered_from: :>=, registered_to: :<=}
  defmodule Params do
    @moduledoc false
    use Ecto.Schema
    @primary_key false

    @derive {
      Flop.Schema,
      filterable: [
        :q,
        :organization,
        :confirmed,
        :mfa,
        :passkeys,
        :locked,
        :deleted,
        :provider,
        :registered_from,
        :registered_to
      ],
      sortable: [:id, :email, :inserted_at, :confirmed_at, :locked_at, :deleted_at],
      default_limit: 25,
      max_limit: 100,
      default_order: %{
        order_by: [:inserted_at],
        order_directions: [:desc]
      }
    }

    embedded_schema do
      field :id, :binary_id
      field :email, :string
      field :q, :string
      field :organization, :string
      field :confirmed, :boolean
      field :mfa, :boolean
      field :passkeys, :boolean
      field :locked, :boolean
      field :deleted, :boolean
      field :provider, :string
      field :registered_from, :date
      field :registered_to, :date
      field :inserted_at, :utc_datetime
      field :confirmed_at, :utc_datetime
      field :locked_at, :utc_datetime
      field :deleted_at, :utc_datetime
    end
  end

  @type row :: %{
          user: struct(),
          display_name: String.t() | nil,
          last_active_at: DateTime.t() | nil,
          has_mfa: boolean(),
          passkey_count: non_neg_integer(),
          organization_count: non_neg_integer(),
          organization_summary: String.t(),
          extra_badges: list(),
          extra_columns: list()
        }

  @spec normalize_params(map() | keyword() | nil) :: {:ok, map()} | {:error, Flop.Meta.t()}
  def normalize_params(params) do
    params
    |> stringify_map()
    |> Map.take(@allowed_params)
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new(fn
      {"q", value} -> {"q", String.trim(to_string(value))}
      {"organization", value} -> {"organization", String.trim(to_string(value))}
      {"provider", value} -> {"provider", String.trim(to_string(value))}
      {"order_by", value} -> {"order_by", normalize_order_field(value)}
      {"order_direction", value} -> {"order_direction", normalize_order_direction(value)}
      {"registered_from", value} -> {"registered_from", normalize_date(value)}
      {"registered_to", value} -> {"registered_to", normalize_date(value)}
      {key, value} -> {key, normalize_scalar(value)}
    end)
    |> then(fn normalized ->
      case Flop.validate(to_flop_params(normalized), for: Params) do
        {:ok, flop} -> {:ok, merge_flop_defaults(normalized, flop)}
        {:error, %Flop.Meta{} = meta} -> {:error, meta}
      end
    end)
  end

  @spec list_users(map(), Scope.t(), map() | keyword() | nil) ::
          {:ok, {[row()], Flop.Meta.t(), map()}} | {:error, Flop.Meta.t()}
  def list_users(config, %Scope{} = admin_scope, params \\ %{}) do
    hooks = Hooks.resolve(config)

    with {:ok, normalized} <- normalize_params(params),
         {:ok, %Flop{} = flop} <- Flop.validate(to_flop_params(normalized), for: Params) do
      helpers = helpers(config, hooks, admin_scope)
      base_query = base_query(config, admin_scope, helpers)
      filtered_query = apply_filters(base_query, flop.filters || [], helpers)
      pagination_flop = %Flop{flop | filters: []}

      meta = Flop.meta(filtered_query, pagination_flop, for: Params, repo: config.repo)

      rows =
        filtered_query
        |> Flop.query(pagination_flop, for: Params)
        |> select_row(helpers)
        |> config.repo.all()
        |> attach_organization_summaries(config, helpers)
        |> decorate_rows(hooks)

      {:ok, {rows, meta, normalized}}
    end
  end

  @spec summary_counts(map(), Scope.t()) :: map()
  def summary_counts(config, %Scope{} = admin_scope) do
    hooks = Hooks.resolve(config)
    helpers = helpers(config, hooks, admin_scope)
    repo = config.repo
    base = base_query(config, admin_scope, helpers)

    %{
      total: repo.aggregate(base, :count, :id),
      confirmed:
        repo.aggregate(where(base, [user: user], not is_nil(user.confirmed_at)), :count, :id),
      mfa: count_mfa(repo, base, helpers),
      passkeys: count_passkeys(repo, base, helpers),
      locked: repo.aggregate(where(base, [user: user], not is_nil(user.locked_at)), :count, :id),
      deleted: repo.aggregate(where(base, [user: user], not is_nil(user.deleted_at)), :count, :id)
    }
  end

  defp helpers(config, hooks, admin_scope) do
    user_schema = Map.fetch!(config, :user_schema)
    accounts_module = accounts_module(config)

    %{
      config: config,
      admin_scope: admin_scope,
      hooks: hooks,
      user_schema: user_schema,
      display_name_field: search_field(user_schema, safe_apply(hooks, :display_name_field, [])),
      extra_search_fields:
        hooks
        |> safe_apply(:extra_search_fields, [])
        |> List.wrap()
        |> Enum.map(&search_field(user_schema, &1))
        |> Enum.reject(&is_nil/1),
      accounts_module: accounts_module,
      membership_schema:
        Map.get(config, :membership_schema) ||
          optional_schema(accounts_module, :OrganizationMembership),
      organization_schema:
        Map.get(config, :organization_schema) || optional_schema(accounts_module, :Organization),
      mfa_schema: mfa_schema(config, accounts_module),
      passkey_schema: passkey_schema(config, accounts_module),
      session_schema: session_schema(config),
      identity_schema: identity_schema(config, accounts_module)
    }
  end

  defp base_query(_config, %Scope{} = admin_scope, helpers) do
    user_schema = helpers.user_schema

    scoped_users =
      if Scope.global?(admin_scope) do
        Authorizer.scope_query(user_schema, admin_scope)
      else
        org_id = admin_scope.organization_id
        Authorizer.authorize_organization!(admin_scope, org_id)

        if is_nil(helpers.membership_schema) do
          raise ArgumentError,
                "organization-scoped admin user queries require an organization membership schema"
        end

        from user in user_schema,
          where: user.id in subquery(membership_user_ids_query(helpers, org_id))
      end

    from(user in scoped_users, as: :user)
    |> maybe_join_session_summary(helpers)
    |> maybe_join_mfa_summary(helpers)
    |> maybe_join_passkey_summary(helpers)
  end

  defp apply_filters(query, filters, helpers) do
    Enum.reduce(filters, query, fn filter, acc -> apply_filter(acc, filter, helpers) end)
  end

  defp apply_filter(query, %Flop.Filter{field: :q, value: value}, helpers) do
    term = like_term(value)

    search_fields =
      [helpers.display_name_field | helpers.extra_search_fields] |> Enum.reject(&is_nil/1)

    dynamic =
      Enum.reduce(
        search_fields,
        dynamic([user: user], ilike(user.email, ^term) or ilike(type(user.id, :string), ^term)),
        fn field, acc ->
          dynamic([user: user], ^acc or ilike(type(field(user, ^field), :string), ^term))
        end
      )

    where(query, ^dynamic)
  end

  defp apply_filter(query, %Flop.Filter{field: :organization, value: value}, helpers) do
    org_term = like_term(value)

    if helpers.membership_schema && helpers.organization_schema do
      where(
        query,
        [user: user],
        user.id in subquery(organization_lookup_query(helpers, org_term))
      )
    else
      where(query, false)
    end
  end

  defp apply_filter(query, %Flop.Filter{field: :confirmed, value: value}, _helpers) do
    case value do
      true -> where(query, [user: user], not is_nil(user.confirmed_at))
      false -> where(query, [user: user], is_nil(user.confirmed_at))
    end
  end

  defp apply_filter(query, %Flop.Filter{field: :mfa, value: value}, helpers) do
    cond do
      helpers.mfa_schema && value == true ->
        where(query, [mfa_state: mfa], not is_nil(mfa.user_id))

      helpers.mfa_schema && value == false ->
        where(query, [mfa_state: mfa], is_nil(mfa.user_id))

      value == true ->
        where(query, false)

      true ->
        query
    end
  end

  defp apply_filter(query, %Flop.Filter{field: :passkeys, value: value}, helpers) do
    cond do
      helpers.passkey_schema && value == true ->
        where(query, [passkey_state: passkeys], coalesce(passkeys.passkey_count, 0) > 0)

      helpers.passkey_schema && value == false ->
        where(query, [passkey_state: passkeys], is_nil(passkeys.user_id))

      value == true ->
        where(query, false)

      true ->
        query
    end
  end

  defp apply_filter(query, %Flop.Filter{field: :locked, value: value}, _helpers) do
    case value do
      true -> where(query, [user: user], not is_nil(user.locked_at))
      false -> where(query, [user: user], is_nil(user.locked_at))
    end
  end

  defp apply_filter(query, %Flop.Filter{field: :deleted, value: value}, _helpers) do
    case value do
      true -> where(query, [user: user], not is_nil(user.deleted_at))
      false -> where(query, [user: user], is_nil(user.deleted_at))
    end
  end

  defp apply_filter(query, %Flop.Filter{field: :provider, value: value}, helpers) do
    provider = String.downcase(to_string(value))

    cond do
      provider == "local" and is_nil(helpers.identity_schema) ->
        query

      is_nil(helpers.identity_schema) ->
        where(query, false)

      provider == "local" ->
        where(
          query,
          [user: user],
          user.id not in subquery(provider_user_ids_query(helpers, :external))
        )

      true ->
        where(
          query,
          [user: user],
          user.id in subquery(provider_user_ids_query(helpers, provider))
        )
    end
  end

  defp apply_filter(
         query,
         %Flop.Filter{field: :registered_from, value: %Date{} = value},
         _helpers
       ) do
    start_at = DateTime.new!(value, ~T[00:00:00], "Etc/UTC")
    where(query, [user: user], user.inserted_at >= ^start_at)
  end

  defp apply_filter(query, %Flop.Filter{field: :registered_to, value: %Date{} = value}, _helpers) do
    end_at =
      value
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    where(query, [user: user], user.inserted_at < ^end_at)
  end

  defp apply_filter(query, _filter, _helpers), do: query

  defp select_row(query, helpers) do
    display_name_field = helpers.display_name_field

    if display_name_field do
      select(
        query,
        [user: user, session_state: session, mfa_state: mfa, passkey_state: passkeys],
        %{
          user: user,
          display_name_field: field(user, ^display_name_field),
          last_active_at: session.last_active_at,
          has_mfa: not is_nil(mfa.user_id),
          passkey_count: coalesce(passkeys.passkey_count, 0),
          organization_count: 0,
          organization_summary: "",
          extra_badges: [],
          extra_columns: []
        }
      )
    else
      select(
        query,
        [user: user, session_state: session, mfa_state: mfa, passkey_state: passkeys],
        %{
          user: user,
          display_name_field: nil,
          last_active_at: session.last_active_at,
          has_mfa: not is_nil(mfa.user_id),
          passkey_count: coalesce(passkeys.passkey_count, 0),
          organization_count: 0,
          organization_summary: "",
          extra_badges: [],
          extra_columns: []
        }
      )
    end
  end

  defp attach_organization_summaries([], _config, _helpers), do: []

  defp attach_organization_summaries(rows, config, helpers) do
    repo = config.repo

    summaries =
      case {helpers.membership_schema, helpers.organization_schema} do
        {membership_schema, organization_schema}
        when not is_nil(membership_schema) and not is_nil(organization_schema) ->
          user_ids = Enum.map(rows, & &1.user.id)

          from(
            membership in membership_schema,
            join: organization in assoc(membership, :organization),
            where: membership.user_id in ^user_ids,
            select: %{
              user_id: membership.user_id,
              organization_name: organization.name
            }
          )
          |> repo.all()
          |> Enum.group_by(& &1.user_id, & &1.organization_name)
          |> Map.new(fn {user_id, names} ->
            unique_names = names |> Enum.uniq() |> Enum.sort()

            {user_id,
             %{
               organization_count: length(unique_names),
               organization_summary:
                 if(unique_names == [],
                   do: "No organizations",
                   else: Enum.join(unique_names, ", ")
                 )
             }}
          end)

        _ ->
          %{}
      end

    Enum.map(rows, fn row ->
      Map.merge(
        row,
        Map.get(summaries, row.user.id, %{
          organization_count: 0,
          organization_summary: "No organizations"
        })
      )
    end)
  end

  defp decorate_rows(rows, hooks) do
    Enum.map(rows, fn row ->
      user = row.user

      display_name =
        safe_apply(hooks, :display_name, [user]) ||
          row[:display_name_field] ||
          Map.get(user, :email)

      Map.merge(row, %{
        display_name: display_name,
        extra_badges: safe_apply(hooks, :extra_list_badges, [user]) || [],
        extra_columns: safe_apply(hooks, :extra_list_columns, []) || []
      })
    end)
  end

  defp maybe_join_session_summary(query, %{session_schema: nil}), do: query

  defp maybe_join_session_summary(query, %{session_schema: session_schema}) do
    summary =
      from session in session_schema,
        group_by: session.user_id,
        select: %{
          user_id: session.user_id,
          last_active_at: max(session.last_active_at)
        }

    join(query, :left, [user: user], session in subquery(summary),
      as: :session_state,
      on: session.user_id == user.id
    )
  end

  defp maybe_join_mfa_summary(query, %{mfa_schema: nil}), do: query

  defp maybe_join_mfa_summary(query, %{mfa_schema: mfa_schema}) do
    summary =
      from credential in mfa_schema,
        where: not is_nil(credential.enabled_at),
        group_by: credential.user_id,
        select: %{user_id: credential.user_id}

    join(query, :left, [user: user], mfa in subquery(summary),
      as: :mfa_state,
      on: mfa.user_id == user.id
    )
  end

  defp maybe_join_passkey_summary(query, %{passkey_schema: nil}), do: query

  defp maybe_join_passkey_summary(query, %{passkey_schema: passkey_schema}) do
    summary =
      from passkey in passkey_schema,
        group_by: passkey.user_id,
        select: %{
          user_id: passkey.user_id,
          passkey_count: count(passkey.user_id)
        }

    join(query, :left, [user: user], passkey in subquery(summary),
      as: :passkey_state,
      on: passkey.user_id == user.id
    )
  end

  defp membership_user_ids_query(%{membership_schema: membership_schema}, org_id)
       when not is_nil(membership_schema) do
    from membership in membership_schema,
      where: membership.organization_id == ^org_id,
      select: membership.user_id
  end

  defp organization_lookup_query(
         %{
           membership_schema: membership_schema,
           organization_schema: organization_schema,
           admin_scope: admin_scope
         },
         term
       )
       when not is_nil(membership_schema) and not is_nil(organization_schema) do
    base =
      from membership in membership_schema,
        join: organization in assoc(membership, :organization),
        select: membership.user_id

    base =
      if Scope.organization?(admin_scope) and is_binary(admin_scope.organization_id) do
        where(base, [membership, organization], organization.id == ^admin_scope.organization_id)
      else
        base
      end

    where(
      base,
      [membership, organization],
      ilike(organization.slug, ^term) or ilike(organization.name, ^term)
    )
  end

  defp provider_user_ids_query(%{identity_schema: identity_schema}, :external)
       when not is_nil(identity_schema) do
    from identity in identity_schema,
      select: identity.user_id
  end

  defp provider_user_ids_query(%{identity_schema: identity_schema}, provider)
       when not is_nil(identity_schema) do
    from identity in identity_schema,
      where: fragment("lower(?)", field(identity, :provider)) == ^provider,
      select: identity.user_id
  end

  defp count_mfa(_repo, _base, %{mfa_schema: nil}), do: 0

  defp count_mfa(repo, base, _helpers),
    do: repo.aggregate(where(base, [mfa_state: mfa], not is_nil(mfa.user_id)), :count, :id)

  defp count_passkeys(_repo, _base, %{passkey_schema: nil}), do: 0

  defp count_passkeys(repo, base, _helpers) do
    repo.aggregate(
      where(base, [passkey_state: passkeys], coalesce(passkeys.passkey_count, 0) > 0),
      :count,
      :id
    )
  end

  defp to_flop_params(params) do
    params
    |> Flop.nest_filters(@filter_fields, operators: @filter_ops)
    |> stringify_deep()
    |> Map.update("order_by", nil, fn
      nil -> nil
      field -> [field]
    end)
    |> then(fn nested ->
      nested
      |> Map.delete("order_direction")
      |> maybe_put_order_directions(nested["order_direction"])
    end)
  end

  defp maybe_put_order_directions(params, nil), do: params

  defp maybe_put_order_directions(params, direction),
    do: Map.put(params, "order_directions", [direction])

  defp merge_flop_defaults(normalized, flop) do
    normalized
    |> maybe_put("page", flop.page)
    |> maybe_put("page_size", flop.page_size)
    |> maybe_put("order_by", list_first(flop.order_by))
    |> maybe_put("order_direction", list_first(flop.order_directions))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put_new(map, key, to_string(value))

  defp like_term(value), do: "%" <> escape_like(String.trim(to_string(value))) <> "%"

  defp escape_like(value) do
    String.replace(value, ["\\", "%", "_"], fn token -> "\\" <> token end)
  end

  defp stringify_map(nil), do: %{}

  defp stringify_map(params) when is_list(params),
    do: Enum.into(params, %{}, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map(params) when is_map(params),
    do: Map.new(params, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map(_), do: %{}

  defp stringify_deep(value) when is_list(value), do: Enum.map(value, &stringify_deep/1)

  defp stringify_deep(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), stringify_deep(v)} end)
    |> Map.new()
  end

  defp stringify_deep(value), do: value

  defp normalize_scalar(value) when is_binary(value), do: String.trim(value)
  defp normalize_scalar(value), do: value

  defp normalize_order_field(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_order_direction(value) do
    case value |> to_string() |> String.trim() |> String.downcase() do
      "asc" -> "asc"
      "desc" -> "desc"
      _ -> nil
    end
  end

  defp normalize_date(value) do
    value |> to_string() |> String.trim()
  end

  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(_value), do: false

  defp list_first([value | _]), do: value
  defp list_first(_), do: nil

  defp accounts_module(%{accounts_module: module}) when is_atom(module), do: module
  defp accounts_module(%{accounts: module}) when is_atom(module), do: module

  defp accounts_module(%{user_schema: module}) when is_atom(module) do
    module |> Module.split() |> Enum.drop(-1) |> Module.safe_concat()
  rescue
    ArgumentError -> nil
  end

  defp accounts_module(_), do: nil

  defp optional_schema(nil, _name), do: nil

  defp optional_schema(module, name) do
    schema = Module.concat(module, name)
    if Code.ensure_loaded?(schema), do: schema, else: nil
  end

  defp session_schema(%{session: session}) when is_list(session),
    do: Keyword.get(session, :session_schema)

  defp session_schema(_config), do: nil

  defp passkey_schema(%{passkeys: passkeys}, accounts_module) when is_list(passkeys) do
    Keyword.get(passkeys, :user_passkey_schema) || optional_schema(accounts_module, :UserPasskey)
  end

  defp passkey_schema(_config, accounts_module),
    do: optional_schema(accounts_module, :UserPasskey)

  defp mfa_schema(%{mfa: mfa}, accounts_module) when is_list(mfa) do
    Keyword.get(mfa, :mfa_credential_schema) ||
      optional_schema(accounts_module, :UserMFACredential)
  end

  defp mfa_schema(_config, accounts_module),
    do: optional_schema(accounts_module, :UserMFACredential)

  defp identity_schema(%{oauth: oauth}, accounts_module) when is_list(oauth) do
    Keyword.get(oauth, :user_identity_schema) || optional_schema(accounts_module, :UserIdentity)
  end

  defp identity_schema(_config, accounts_module),
    do: optional_schema(accounts_module, :UserIdentity)

  defp search_field(schema, field) when is_atom(field) do
    if field in schema.__schema__(:fields), do: field, else: nil
  end

  defp search_field(_schema, _field), do: nil

  defp safe_apply(module, function, args) when is_atom(module) do
    if function_exported?(module, function, length(args)) do
      apply(module, function, args)
    end
  end
end
