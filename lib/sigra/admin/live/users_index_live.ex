defmodule Sigra.Admin.Live.UsersIndexLive do
  @moduledoc """
  Admin user index for global and organization-scoped user operations.
  """

  use Phoenix.LiveView

  import Sigra.Admin.Components

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Hooks
  alias Sigra.Admin.Users.Query

  @quick_filter_keys ~w(confirmed mfa passkeys locked deleted needs_review)
  @more_filter_keys ~w(provider registered_from registered_to organization)

  @impl true
  def mount(_params, _session, socket) do
    config = runtime_config!()
    hooks = Hooks.resolve(config)

    {:ok,
     socket
     |> assign(:sigra_config, config)
     |> assign(:hooks_module, hooks)
     |> assign(:quick_filter_keys, @quick_filter_keys)
     |> assign(:more_filter_keys, @more_filter_keys)
     |> assign(:filters_open?, false)
     |> assign(:page_title, "Users")
     |> assign(:rows, [])
     |> assign(:summary_stats, empty_summary_stats())
     |> assign(:meta, nil)
     |> assign(:current_params, %{})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    admin_scope = socket.assigns.admin_scope
    config = socket.assigns.sigra_config

    with {:ok, {rows, meta, normalized}} <- Query.list_users(config, admin_scope, params) do
      {:noreply,
       socket
       |> assign(:rows, rows)
       |> assign(:meta, meta)
       |> assign(:summary_stats, Query.summary_stats(config, admin_scope))
       |> assign(:current_params, normalized)
       |> assign(:filters_open?, filters_open?(normalized))
       |> assign(:page_title, page_title(admin_scope))}
    else
      {:error, _meta} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't load this user data. Refresh the page, then try again."
         )
         |> assign(:rows, [])
         |> assign(:meta, nil)
         |> assign(:summary_stats, empty_summary_stats())
         |> assign(:current_params, %{})}
    end
  end

  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, update(socket, :filters_open?, &(!&1))}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:summary_posture, summary_group(assigns.summary_stats, :posture))

    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">User operations</p>
        <h1 class="sg-page-title">{page_heading(@admin_scope)}</h1>
      </header>

      <.scope_ribbon copy={scope_copy(@admin_scope)} />

      <% total_users = summary_count(@summary_posture, :total) %>
      <% confirmed_users = summary_count(@summary_posture, :confirmed) %>
      <% mfa_users = summary_count(@summary_posture, :mfa_enabled) %>
      <% passkey_users = summary_count(@summary_posture, :passkey_users) %>
      <% locked_users = summary_count(@summary_posture, :locked_out) %>
      <% deletion_scheduled_users = summary_count(@summary_posture, :deletion_scheduled) %>
      <section class="sg-stack sg-stack--3" aria-labelledby="users-health-heading">
        <h2 id="users-health-heading" class="sg-section-heading">User health</h2>
        <dl class="sg-metric-grid" aria-label="User health summary">
          <.summary_chip
            id="users-metric-total"
            icon="users"
            label="Total users"
            value={total_users}
            value_suffix="total users"
          />
          <.summary_chip
            id="users-metric-confirmed"
            icon="check"
            label="Confirmed users"
            value={confirmed_users}
            value_suffix="confirmed"
            subvalue={summary_percent(confirmed_users, total_users)}
            help="These users confirmed their email and can sign in normally."
          />
          <.summary_chip
            id="users-metric-mfa"
            icon="mfa"
            label="MFA enrolled"
            value={mfa_users}
            value_suffix="MFA enabled"
            subvalue={summary_percent(mfa_users, total_users)}
            help="These users have multifactor authentication enabled. Higher coverage lowers account takeover risk."
          />
          <.summary_chip
            id="users-metric-passkeys"
            icon="fingerprint"
            label="Passkey users"
            value={passkey_users}
            value_suffix="with passkeys"
            subvalue={summary_percent(passkey_users, total_users)}
            help="These users have at least one passkey. Passkeys make phishing attacks harder."
          />
          <.summary_chip
            id="users-metric-locked"
            icon="lock"
            label="Locked users"
            value={locked_users}
            value_suffix="locked out"
            subvalue={summary_percent(locked_users, total_users)}
            help="These users are locked out after failed sign-in attempts. Review the user before unlocking."
            tone={summary_tone(locked_users, "risk")}
          />
          <.summary_chip
            id="users-metric-deletion"
            icon="clock"
            label="Deletion scheduled"
            value={deletion_scheduled_users}
            value_suffix="pending deletion"
            subvalue={summary_percent(deletion_scheduled_users, total_users)}
            help="These users are scheduled for deletion. Access is disabled and active sessions are revoked."
            tone={summary_tone(deletion_scheduled_users, "warn")}
          />
        </dl>
      </section>

      <section class="sg-stack sg-stack--4" aria-labelledby="find-users-heading">
      <div class="sg-stack sg-stack--1">
        <h2 id="find-users-heading" class="sg-section-heading">Find users</h2>
      </div>

      <form method="get" action={index_path(@admin_scope)} class="sg-filter-panel sg-stack">
        <div class="sg-search-row">
          <label class="sg-field">
            <span class="sg-field-label">Search</span>
            <input
              type="text"
              name="q"
              value={param_value(@current_params, "q")}
              placeholder="Email, user id, or name"
              class="sg-input"
            />
          </label>

          <button type="submit" class="sg-btn sg-btn--primary">Search</button>
          <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost">Clear</a>
        </div>

        <div class="sg-cluster">
          <.quick_filter :for={key <- @quick_filter_keys} key={key} params={@current_params} />
        </div>

        <div class="sg-stack sg-stack--3">
          <button
            type="button"
            phx-click="toggle_filters"
            class="sg-btn sg-btn--ghost sg-btn--sm sg-self-start"
            aria-expanded={to_string(@filters_open?)}
          >
            More filters
            <span class="sg-chevron" aria-hidden="true">▾</span>
          </button>

          <div :if={@filters_open?} class="sg-form-grid sg-form-grid--cols">
            <label class="sg-field">
              <span class="sg-field-label">Organization</span>
              <input
                type="text"
                name="organization"
                value={param_value(@current_params, "organization")}
                class="sg-input"
              />
            </label>

            <label class="sg-field">
              <span class="sg-field-label">Provider</span>
              <select name="provider" class="sg-select">
                <option value="">Any</option>
                <option value="local" selected={param_value(@current_params, "provider") == "local"}>Local</option>
                <option value="google" selected={param_value(@current_params, "provider") == "google"}>Google</option>
                <option value="github" selected={param_value(@current_params, "provider") == "github"}>GitHub</option>
              </select>
            </label>

            <label class="sg-field">
              <span class="sg-field-label">Registered from</span>
              <input
                type="date"
                name="registered_from"
                value={param_value(@current_params, "registered_from")}
                class="sg-input"
              />
            </label>

            <label class="sg-field">
              <span class="sg-field-label">Registered to</span>
              <input
                type="date"
                name="registered_to"
                value={param_value(@current_params, "registered_to")}
                class="sg-input"
              />
            </label>
          </div>
        </div>

        <input type="hidden" name="page_size" value={param_value(@current_params, "page_size", "25")} />
        <input type="hidden" name="order_by" value={param_value(@current_params, "order_by", "inserted_at")} />
        <input type="hidden" name="order_direction" value={param_value(@current_params, "order_direction", "desc")} />
      </form>

      <div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--start">
        <.applied_chip
          :for={chip <- applied_chips(@current_params)}
          label={chip.label}
          remove_href={remove_chip_path(@admin_scope, @current_params, chip.key)}
        />
        <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
      </div>

      <div
        id="admin-users-desktop-results"
        data-testid="admin-users-desktop-results"
        class="sg-table-panel sg-show-desktop"
      >
        <table class="sg-table">
          <thead>
            <tr>
              <th><a href={sort_path(@admin_scope, @current_params, "inserted_at")}>User</a></th>
              <th>Status</th>
              <th>Organizations</th>
              <th>Activity</th>
              <th class="sg-cell-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <td>
                <div class="sg-stack sg-stack--1">
                  <span class="sg-strong">{primary_name(row)}</span>
                  <span class="sg-muted sg-text-sm sg-truncate" title={row.user.email}>{row.user.email}</span>
                  <code class="sg-code">{row.user.id}</code>
                </div>
              </td>
              <td>
                <div class="sg-cluster sg-cluster--2">
                  <span :for={{label, tone} <- status_pills(row)} class="sg-status-pill" data-tone={tone}>
                    {label}
                  </span>
                  <span :for={badge <- row.extra_badges} class="sg-status-pill">{badge_text(badge)}</span>
                </div>
              </td>
              <td>
                <div class="sg-stack sg-stack--1 sg-text-sm">
                  <span class="sg-truncate" title={row.organization_summary}>{row.organization_summary}</span>
                  <span class="sg-muted">{pluralize(row.organization_count, "organization")}</span>
                </div>
              </td>
              <td>
                <div class="sg-stack sg-stack--1 sg-text-sm">
                  <span>{activity_label(row)}</span>
                  <span class="sg-muted">{registered_label(row)}</span>
                  <span :for={column <- row.extra_columns} class="sg-muted">{column_text(column, row.user)}</span>
                </div>
              </td>
              <td class="sg-cell-right">
                <a class="sg-btn sg-btn--secondary sg-btn--sm" href={open_user_path(@admin_scope, row.user.id, @current_params)}>
                  Open user
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        id="admin-users-mobile-results"
        data-testid="admin-users-mobile-results"
        class="sg-stack sg-stack--3 sg-show-mobile"
      >
        <article :for={row <- @rows} class="sg-card sg-stack sg-stack--3">
          <div class="sg-stack sg-stack--1">
            <span class="sg-strong">{primary_name(row)}</span>
            <span class="sg-muted sg-text-sm sg-truncate" title={row.user.email}>{row.user.email}</span>
            <code class="sg-code">{row.user.id}</code>
          </div>

          <div class="sg-cluster sg-cluster--2">
            <span :for={{label, tone} <- status_pills(row)} class="sg-status-pill" data-tone={tone}>
              {label}
            </span>
            <span :for={badge <- row.extra_badges} class="sg-status-pill">{badge_text(badge)}</span>
          </div>

          <dl class="sg-kv">
            <div>
              <dt class="sg-meta-label">Organizations</dt>
              <dd class="sg-meta-value sg-truncate" title={row.organization_summary}>
                {row.organization_summary}
              </dd>
              <dd class="sg-muted sg-text-sm">{pluralize(row.organization_count, "organization")}</dd>
            </div>
            <div>
              <dt class="sg-meta-label">Activity</dt>
              <dd class="sg-meta-value">{activity_label(row)}</dd>
            </div>
            <div>
              <dt class="sg-meta-label">Registered</dt>
              <dd class="sg-meta-value">{registered_label(row)}</dd>
            </div>
            <div :for={column <- row.extra_columns}>
              <dd class="sg-muted sg-text-sm">{column_text(column, row.user)}</dd>
            </div>
          </dl>

          <div class="sg-cluster">
            <a class="sg-btn sg-btn--secondary sg-btn--block" href={open_user_path(@admin_scope, row.user.id, @current_params)}>
              Open user
            </a>
          </div>
        </article>
      </div>

      <.empty_state :if={@rows == []} title="No users match this view">
        <%= if any_filter_active?(@current_params) do %>
          <p class="sg-muted sg-text-sm">No users match the active filters. Clear them to widen the result set.</p>
          <div class="sg-cluster sg-cluster--center">
            <a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">Clear all filters</a>
          </div>
        <% else %>
          <p class="sg-muted sg-text-sm">Users appear here as people register and sign in. Once users exist, you can search, filter, and open any user.</p>
        <% end %>
      </.empty_state>

      <p
        :if={@meta && @rows != [] && not multi_page?(@meta)}
        class="sg-muted sg-text-sm sg-tabular"
      >
        {all_results_label(@meta)}
      </p>

      <nav :if={@meta && multi_page?(@meta)} class="sg-cluster sg-cluster--between">
        <a
          class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.previous_page, do: "", else: "is-disabled")]}
          href={page_path(@admin_scope, @current_params, @meta.previous_page)}
          aria-disabled={to_string(is_nil(@meta.previous_page))}
          aria-label="Previous page"
        >
          <span aria-hidden="true">&larr;</span>
          <span class="sr-only">Previous page</span>
        </a>
        <% {x, y, z} = showing_range(@meta, @rows) %>
        <span class="sg-muted sg-text-sm sg-tabular">
          Showing {x}&ndash;{y} of {z} users
          <span class="sg-muted">&middot; Page {@meta.current_page || 1} of {@meta.total_pages || 1}</span>
        </span>
        <a
          class={["sg-btn sg-btn--secondary sg-btn--icon", if(@meta.next_page, do: "", else: "is-disabled")]}
          href={page_path(@admin_scope, @current_params, @meta.next_page)}
          aria-disabled={to_string(is_nil(@meta.next_page))}
          aria-label="Next page"
        >
          <span aria-hidden="true">&rarr;</span>
          <span class="sr-only">Next page</span>
        </a>
      </nav>
      </section>
    </section>
    """
  end

  attr :key, :string, required: true
  attr :params, :map, required: true

  defp quick_filter(assigns) do
    ~H"""
    <label class="sg-filter-chip">
      <input
        type="checkbox"
        name={@key}
        value="true"
        checked={param_true?(@params, @key)}
        class="checkbox checkbox-sm"
      />
      <span>{String.replace(@key, "_", " ")}</span>
    </label>
    """
  end

  # Compact, scannable status as tone pills. Only decision-bearing signals are surfaced.
  # Confirmed is dropped (absence of Unconfirmed implies confirmed — green pills are noise).
  # Security cond is collapsed: only No MFA (warn) when unsecured; secured rows show no security pill.
  defp status_pills(row) do
    []
    |> maybe_append(is_nil(row.user.confirmed_at), {"Unconfirmed", "warn"})
    |> maybe_append(no_security?(row), {"No MFA", "warn"})
    |> maybe_append(row.user.locked_at, {"Locked", "risk"})
    |> maybe_append(row.user.deleted_at, {"Deletion scheduled", "warn"})
  end

  # True when the row has neither MFA nor any passkeys — the only unsecured state worth surfacing.
  defp no_security?(row), do: not row.has_mfa and row.passkey_count == 0

  defp maybe_append(pills, nil, _pill), do: pills
  defp maybe_append(pills, _present, pill), do: pills ++ [pill]

  defp runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError, "Sigra admin users requires Application.get_env(:sigra, :otp_app)"

    host_config =
      Application.get_env(otp_app, :sigra_config) ||
        raise ArgumentError,
              "Sigra admin users requires Application.get_env(#{inspect(otp_app)}, :sigra_config)"

    host_config
    |> Keyword.put_new(:otp_app, otp_app)
    |> Sigra.Config.new!()
  end

  defp page_title(%Scope{mode: :global}), do: "Users"
  defp page_title(%Scope{organization: %{name: name}}), do: "#{name} Users"
  defp page_title(_), do: "Users"

  defp page_heading(%Scope{mode: :global}), do: "Users"
  defp page_heading(%Scope{organization: %{name: name}}), do: "#{name} users"
  defp page_heading(_), do: "Users"

  defp scope_copy(%Scope{mode: :global}), do: "Global user operations"

  defp scope_copy(%Scope{organization: %{name: name}}),
    do: "Organization-scoped user operations for #{name}"

  defp scope_copy(_), do: "User operations"

  defp empty_summary_stats do
    %{
      posture: %{
        total: 0,
        confirmed: 0,
        mfa_enabled: 0,
        passkey_users: 0,
        locked_out: 0,
        deletion_scheduled: 0
      },
      growth: %{new_this_week: 0, new_this_month: 0},
      activity: %{available?: false, active_this_week: nil, active_this_month: nil}
    }
  end

  defp summary_group(stats, key) when is_map(stats), do: Map.get(stats, key, %{})
  defp summary_group(_stats, _key), do: %{}

  defp summary_count(counts, key) when is_map(counts), do: Map.get(counts, key, 0)
  defp summary_count(_counts, _key), do: 0

  defp summary_percent(count, total), do: "#{percent_of(count, total)}% of total users"

  defp percent_of(_count, total) when total in [nil, 0], do: 0

  defp percent_of(count, total) do
    (count / total * 100)
    |> Float.round()
    |> trunc()
  end

  defp summary_tone(count, tone) when count > 0, do: tone
  defp summary_tone(_count, _tone), do: nil

  defp filters_open?(params), do: Enum.any?(@more_filter_keys, &present_param?(params, &1))

  # {x, y, z} pagination readout derived from Flop.Meta. Zero case guarded.
  defp showing_range(meta, rows) do
    z = meta.total_count || 0

    if z > 0 do
      offset = meta.current_offset || 0
      {offset + 1, offset + length(rows), z}
    else
      {0, 0, 0}
    end
  end

  defp multi_page?(nil), do: false

  defp multi_page?(meta) do
    (meta.total_pages || 1) > 1 or not is_nil(meta.previous_page) or not is_nil(meta.next_page)
  end

  defp all_results_label(meta) do
    total = meta.total_count || 0
    "Showing all #{total} #{if total == 1, do: "user", else: "users"}"
  end

  defp any_filter_active?(params) do
    present_param?(params, "q") or
      Enum.any?(@quick_filter_keys, &param_true?(params, &1)) or
      Enum.any?(@more_filter_keys, &present_param?(params, &1))
  end

  # Ordered list of active-filter chips: %{key, label}. Non-filter keys are never iterated.
  defp applied_chips(params) do
    search_chips =
      if present_param?(params, "q") do
        [%{key: "q", label: "Search: " <> param_value(params, "q")}]
      else
        []
      end

    quick_chips =
      for key <- @quick_filter_keys, param_true?(params, key) do
        %{key: key, label: chip_label(key, nil)}
      end

    more_chips =
      for key <- @more_filter_keys, present_param?(params, key) do
        %{key: key, label: chip_label(key, param_value(params, key))}
      end

    search_chips ++ quick_chips ++ more_chips
  end

  # Humanized chip labels. Quick keys are flag chips (value ignored);
  # more keys read "Label: value".
  defp chip_label("mfa", nil), do: "MFA"
  defp chip_label("passkeys", nil), do: "Passkeys"
  defp chip_label("needs_review", nil), do: "Needs review"
  defp chip_label("deleted", nil), do: "Deletion scheduled"
  defp chip_label(key, nil), do: String.capitalize(key)
  defp chip_label("provider", value), do: "Provider: " <> value
  defp chip_label("registered_from", value), do: "Registered from: " <> value
  defp chip_label("registered_to", value), do: "Registered to: " <> value
  defp chip_label("organization", value), do: "Organization: " <> value
  defp chip_label(key, value), do: String.capitalize(key) <> ": " <> value

  # Drop a single filter key, preserve the rest, reset to page 1.
  defp remove_chip_path(admin_scope, params, key) do
    admin_scope
    |> index_path()
    |> append_query(
      params
      |> Map.delete(key)
      |> Map.put("page", "1")
    )
  end

  defp present_param?(params, key), do: param_value(params, key) not in [nil, ""]

  defp param_value(params, key, default \\ ""), do: Map.get(params, key, default)

  defp param_true?(params, key), do: Map.get(params, key) == "true"

  defp sort_path(admin_scope, params, field) do
    next_direction =
      if Map.get(params, "order_by") == field and Map.get(params, "order_direction") == "asc",
        do: "desc",
        else: "asc"

    admin_scope
    |> index_path()
    |> append_query(
      params
      |> Map.put("order_by", field)
      |> Map.put("order_direction", next_direction)
      |> Map.put("page", "1")
    )
  end

  defp page_path(_admin_scope, _params, nil), do: "#"

  defp page_path(admin_scope, params, page) do
    admin_scope
    |> index_path()
    |> append_query(Map.put(params, "page", to_string(page)))
  end

  defp open_user_path(admin_scope, user_id, params) do
    base =
      case admin_scope do
        %Scope{mode: :organization, organization_slug: slug} when is_binary(slug) ->
          "/admin/organizations/#{slug}/users/#{user_id}"

        _ ->
          "/admin/users/#{user_id}"
      end

    return_to =
      admin_scope
      |> index_path()
      |> append_query(params)

    base <> "?return_to=" <> URI.encode_www_form(return_to)
  end

  defp index_path(%Scope{mode: :organization, organization_slug: slug}) when is_binary(slug),
    do: "/admin/organizations/#{slug}/users"

  defp index_path(_admin_scope), do: "/admin/users"

  defp append_query(path, params) do
    cleaned =
      params
      |> Enum.reject(fn {_key, value} -> value in [nil, "", false] end)
      |> Enum.into(%{})

    case cleaned do
      empty when map_size(empty) == 0 -> path
      _ -> path <> "?" <> URI.encode_query(cleaned)
    end
  end

  defp primary_name(row) do
    Map.get(row.user, :display_name) || row.display_name || row.user.email
  end

  defp activity_label(row) do
    case row.last_active_at do
      %DateTime{} = at -> "Last activity: " <> Calendar.strftime(at, "%Y-%m-%d %H:%M")
      _ -> "Last activity: None recorded"
    end
  end

  defp registered_label(row) do
    "Registered: " <> Calendar.strftime(row.user.inserted_at, "%Y-%m-%d")
  end

  defp badge_text(%{label: label}) when is_binary(label), do: label
  defp badge_text(badge) when is_binary(badge), do: badge
  defp badge_text(_badge), do: ""

  defp column_text(%{label: label, value: value}, _user)
       when is_binary(label) and is_binary(value),
       do: "#{label}: #{value}"

  defp column_text(%{label: label, field: field}, user) when is_binary(label) and is_atom(field),
    do: "#{label}: #{Map.get(user, field)}"

  defp column_text(_column, _user), do: ""

  defp pluralize(1, singular), do: "1 #{singular}"
  defp pluralize(count, singular), do: "#{count} #{singular}s"
end
