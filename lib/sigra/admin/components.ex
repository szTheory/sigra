defmodule Sigra.Admin.Components do
  @moduledoc """
  Lib-owned canonical admin component set for Sigra's admin LiveViews.

  Provides 13 flat, stateless `Phoenix.Component` function components that consolidate
  the duplicated admin chrome across LiveViews. Security-critical design and a11y fixes
  propagate to host apps via `mix deps.update` (D-05).

  Each component emits only `sg-*` CSS classes defined by the design contract.

  See the [Admin Design Contract](guides/reference/admin-design-contract.md) for the
  authoritative per-component markup, class, and ARIA specification.

  ## Components

    - `stat_link/1` — Numeric KPI with a nav destination (always `<a>`)
    - `stat/1` — Read-only numeric KPI, no nav
    - `task_card/1` — Verb-first action prompt with CTA
    - `summary_chip/1` — Non-interactive aggregate posture badge
    - `applied_chip/1` — Active filter indicator with remove affordance
    - `empty_state/1` — Dashed centred zero-rows placeholder
    - `page_back/1` — Single-step back to list
    - `scope_ribbon/1` — Persistent in-body scope indicator
    - `notice/1` — Block-level toned contextual alert
    - `notice_link/1` — Inline notice action link
    - `field_help/1` — Label-adjacent explanatory tooltip trigger
    - `skeleton/1` — Loading-shape placeholder
    - `audit_row/1` — Audit event card (sg-list-row) with unified tone and date formatting

  """
  use Phoenix.Component

  # ---------------------------------------------------------------------------
  # stat_link/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a numeric KPI stat with a navigation destination (always an `<a>` element).

  ## Examples

      <.stat_link label="Total users" value={1_234} href="/admin/users" />
  """
  attr :href, :string, required: true, doc: "the URL the stat link navigates to"
  attr :label, :string, required: true, doc: "the human-readable KPI label"
  attr :value, :integer, required: true, doc: "the numeric KPI value"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def stat_link(assigns) do
    ~H"""
    <a href={@href} class={["sg-metric-link", @class]} {@rest}>
      <span class="sg-metric-link__label">{@label}</span>
      <span class="sg-metric-link__value">{@value}</span>
    </a>
    """
  end

  # ---------------------------------------------------------------------------
  # stat/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a read-only numeric KPI with no navigation affordance.

  Unlike `stat_link/1`, this component renders no `<a>` element and introduces no
  dedicated component class. It reuses the existing `sg-metric*` utility classes.

  ## Examples

      <.stat label="Active sessions" value={42} />
  """
  attr :label, :string, required: true, doc: "the human-readable KPI label"
  attr :value, :integer, required: true, doc: "the numeric KPI value"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def stat(assigns) do
    ~H"""
    <dl class={["sg-metric", @class]} {@rest}>
      <dt class="sg-metric__label">{@label}</dt>
      <dd class="sg-metric__value">{@value}</dd>
    </dl>
    """
  end

  # ---------------------------------------------------------------------------
  # task_card/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a verb-first action prompt card with a call-to-action link.

  ## Examples

      <.task_card
        title="Invite your team"
        body="Add teammates so they can access the admin panel."
        href="/admin/users/invite"
        action="Send invitations"
      />
  """
  attr :title, :string, required: true, doc: "the card heading"
  attr :body, :string, required: true, doc: "the card description copy"
  attr :href, :string, required: true, doc: "the URL the CTA button navigates to"
  attr :action, :string, required: true, doc: "the CTA button label"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def task_card(assigns) do
    ~H"""
    <article class={["sg-card sg-card-hover sg-stack sg-stack--3", @class]} {@rest}>
      <div class="sg-stack sg-stack--2">
        <h2 class="sg-section-heading">{@title}</h2>
        <p class="sg-section-copy">{@body}</p>
      </div>
      <div class="sg-cluster">
        <a href={@href} class="sg-btn sg-btn--primary">{@action}</a>
      </div>
    </article>
    """
  end

  # ---------------------------------------------------------------------------
  # summary_chip/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a non-interactive aggregate posture badge using definition-list semantics.

  The basic form preserves the original compact `<dt>/<dd>` output. Optional
  icon, value_suffix, subvalue, tone, and help assigns opt into the richer
  posture-summary treatment used by list page headers.

  ## Examples

      <.summary_chip label="MFA enabled" value={7} />
      <.summary_chip
        id="users-metric-mfa"
        icon="mfa"
        label="MFA enrolled"
        value={42}
        value_unit="%"
        value_suffix="MFA coverage"
        subvalue="7 users with MFA"
        help="These users have multifactor authentication enabled. Higher coverage lowers account takeover risk."
      />
  """
  attr :id, :string, default: nil, doc: "optional root id; also seeds the help id"
  attr :label, :string, required: true, doc: "the term / KPI label"
  attr :value, :integer, required: true, doc: "the numeric KPI value"
  attr :icon, :string, default: nil, doc: "optional built-in metric icon name"
  attr :value_unit, :string, default: nil, doc: "optional unit rendered tight against the number"
  attr :value_suffix, :string, default: nil, doc: "optional second-line label for the number"
  attr :subvalue, :string, default: nil, doc: "optional secondary metric context"
  attr :help, :string, default: nil, doc: "optional short explanatory help copy"

  attr :open, :boolean,
    default: false,
    doc: "renders help open for deterministic design-gallery evidence"

  attr :tone, :string, default: nil, doc: "optional metric tone (risk, warn, ok, info)"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def summary_chip(assigns) do
    if summary_chip_enhanced?(assigns) do
      assigns =
        assigns
        |> assign(:help_id, summary_chip_help_id(assigns))
        |> assign(:caption, summary_chip_caption(assigns))
        |> assign(:icon_text, summary_icon_text(assigns.icon))

      ~H"""
      <div
        id={@id}
        class={["sg-metric", @class]}
        data-tone={@tone}
        data-sg-metric-enhanced="true"
        data-sg-metric-has-subvalue={if @subvalue, do: "true", else: nil}
        data-sg-metric-help-root={if @help, do: "true", else: nil}
        data-help-open={if @help && @open, do: "true", else: nil}
        tabindex={if @help, do: "0", else: nil}
        aria-describedby={if @help, do: @help_id, else: nil}
        {@rest}
      >
        <dt class="sg-metric__label">
          <span :if={@icon} class="sg-metric__icon" data-icon={@icon} aria-hidden="true">
            <span :if={@icon_text} class="sg-metric__icon-text">{@icon_text}</span>
            <svg
              :if={!@icon_text}
              class="sg-metric__icon-svg"
              viewBox="0 0 24 24"
              fill="none"
              focusable="false"
              aria-hidden="true"
            >
              <path
                :for={path <- summary_icon_paths(@icon)}
                d={path}
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </span>
          <span class="sg-metric__label-text">{@label}</span>
        </dt>
        <dd class="sg-metric__value">
          <span class="sg-metric__number">
            {@value}<span :if={@value_unit} class="sg-metric__unit">{@value_unit}</span>
          </span>
        </dd>
        <dd class="sg-metric__caption">{@caption}</dd>
        <dd :if={@subvalue} class="sg-metric__subvalue">{@subvalue}</dd>
        <dd :if={@help} id={@help_id} class="sg-metric__help" hidden={!@open}>
          <span role="tooltip">{@help}</span>
        </dd>
      </div>
      """
    else
      ~H"""
      <div id={@id} class={["sg-metric", @class]} {@rest}>
        <dt>{@label}</dt>
        <dd>{@value}</dd>
      </div>
      """
    end
  end

  defp summary_chip_enhanced?(assigns) do
    Enum.any?(
      [:icon, :value_unit, :value_suffix, :subvalue, :help, :tone],
      &present_assign?(assigns, &1)
    )
  end

  defp present_assign?(assigns, key), do: present_value?(Map.get(assigns, key))
  defp present_value?(value) when value in [nil, ""], do: false
  defp present_value?(_value), do: true

  defp summary_chip_help_id(%{id: id}) when is_binary(id) and id != "", do: id <> "-help"

  defp summary_chip_help_id(%{label: label}) do
    slug =
      label
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    "sg-metric-" <> slug <> "-help"
  end

  defp summary_chip_caption(%{value_suffix: value_suffix})
       when is_binary(value_suffix) and value_suffix != "",
       do: value_suffix

  defp summary_chip_caption(%{label: label}), do: label

  defp summary_icon_text("mfa"), do: "MFA"
  defp summary_icon_text(_icon), do: nil

  defp summary_icon_paths("users") do
    [
      "M7.5 11.25a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z",
      "M2.75 21a4.75 4.75 0 0 1 9.5 0",
      "M16.5 10.75a3.25 3.25 0 1 0 0-6.5",
      "M14.75 15.5A4.5 4.5 0 0 1 21.25 21"
    ]
  end

  defp summary_icon_paths("check") do
    [
      "m6.75 12.25 3.5 3.5 7-8"
    ]
  end

  defp summary_icon_paths("check-circle") do
    [
      "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z",
      "m8.75 12.25 2.25 2.25 4.5-5"
    ]
  end

  defp summary_icon_paths("shield-check") do
    [
      "M12 21.5s7.5-4 7.5-10V5.75L12 3 4.5 5.75v5.75c0 6 7.5 10 7.5 10Z",
      "m8.75 12 2.15 2.15 4.35-4.9"
    ]
  end

  defp summary_icon_paths("phone-check") do
    [
      "M9 2.75h6a1.75 1.75 0 0 1 1.75 1.75v15A1.75 1.75 0 0 1 15 21.25H9a1.75 1.75 0 0 1-1.75-1.75v-15A1.75 1.75 0 0 1 9 2.75Z",
      "M10.25 17.75h3.5",
      "m9.75 11.75 1.45 1.45 3.05-3.4"
    ]
  end

  defp summary_icon_paths("fingerprint") do
    [
      "M7 11.25a5 5 0 0 1 10 0v1.25",
      "M9.25 14.75v-3.5a2.75 2.75 0 0 1 5.5 0v2.5",
      "M12 11.25v3.25",
      "M6.25 15.75c.9-1.15 1.25-2.6 1.25-4.5",
      "M9.5 20.75c1.4-1.65 2.25-3.75 2.5-6.25",
      "M14.75 20.25c.85-1.55 1.25-3.35 1.25-5.25",
      "M17.75 16.75c.35-1.4.5-2.85.5-4.25"
    ]
  end

  defp summary_icon_paths("lock") do
    [
      "M7 10.5V8a5 5 0 0 1 10 0v2.5",
      "M5.75 10.5h12.5v9.75H5.75z",
      "M12 15v2"
    ]
  end

  defp summary_icon_paths("clock") do
    [
      "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z",
      "M12 7.5v5l3.25 2"
    ]
  end

  defp summary_icon_paths("sparkles") do
    [
      "M12 3.75 13.8 9.7 19.75 12 13.8 14.3 12 20.25 10.2 14.3 4.25 12 10.2 9.7 12 3.75Z",
      "M18.5 3.75v3",
      "M20 5.25h-3",
      "M5.5 16.75v2.5",
      "M6.75 18H4.25"
    ]
  end

  defp summary_icon_paths("activity") do
    [
      "M3.5 12h3.25l2.1-5 4.3 10 2.1-5H20.5"
    ]
  end

  defp summary_icon_paths(_), do: ["M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z"]

  # ---------------------------------------------------------------------------
  # applied_chip/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders an active-filter indicator with a remove affordance.

  The chip label is displayed inline; the remove link carries an `aria-label` for
  screen readers and a visually hidden fallback. The `&times;` glyph is `aria-hidden`.

  ## Examples

      <.applied_chip label="Active" remove_href="/admin/users?status=" />
  """
  attr :label, :string, required: true, doc: "the filter label shown inside the chip"

  attr :remove_href, :string,
    required: true,
    doc: "the URL to navigate to in order to remove this filter"

  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def applied_chip(assigns) do
    ~H"""
    <span class={["sg-applied-chip", @class]} {@rest}>
      <span>{@label}</span>
      <a
        class="sg-applied-chip__remove"
        href={@remove_href}
        aria-label={"Remove filter " <> @label}
      >
        <span aria-hidden="true">&times;</span>
        <span class="sr-only">remove</span>
      </a>
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # empty_state/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a centred zero-rows placeholder with a variable body block.

  The `title` attr provides the primary heading. The `inner_block` slot accepts the
  variable body (e.g., filter-specific messaging or a CTA).

  ## Examples

      <.empty_state title="No users match this view">
        <p class="sg-muted sg-text-sm">Try adjusting your filters.</p>
      </.empty_state>
  """
  attr :title, :string, required: true, doc: "the primary heading shown in the empty state"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  slot :inner_block, doc: "the variable body rendered below the title (e.g., CTA or filter copy)"

  def empty_state(assigns) do
    ~H"""
    <div class={["sg-empty-state sg-stack sg-stack--3", @class]} {@rest}>
      <p class="sg-empty-state__title">{@title}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # page_back/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a single-step back-to-list ghost button with a fixed `&larr;` glyph prefix.

  The label (e.g., "Back to users") is supplied by the caller. The arrow glyph is
  always rendered `aria-hidden` so screen readers read only the label text.

  ## Examples

      <.page_back return_to={~p"/admin/users"} label="Back to users" />
  """
  attr :return_to, :string, required: true, doc: "the URL the button navigates back to"
  attr :label, :string, required: true, doc: "the visible button label (e.g., \"Back to users\")"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def page_back(assigns) do
    ~H"""
    <a class={["sg-btn sg-btn--ghost sg-btn--sm", @class]} href={@return_to} {@rest}>
      <span aria-hidden="true">&larr;</span> {@label}
    </a>
    """
  end

  # ---------------------------------------------------------------------------
  # scope_ribbon/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a persistent in-body scope indicator as a decorative inline span.

  The copy is caller-supplied (e.g., the result of `scope_copy/1`). The component
  emits the stable hook class `sg-scope-ribbon` (consumed by Playwright, per D-07)
  alongside the visual utility classes `sg-muted sg-text-sm`.

  ## Examples

      <.scope_ribbon copy={scope_copy(@admin_scope)} />
  """
  attr :copy, :string, required: true, doc: "the scope indicator copy (e.g., \"Platform admin\")"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def scope_ribbon(assigns) do
    ~H"""
    <span class={["sg-scope-ribbon sg-muted sg-text-sm", @class]} {@rest}>{@copy}</span>
    """
  end

  # ---------------------------------------------------------------------------
  # notice/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a block-level toned contextual alert.

  Ships the final `sg-notice` form per the design contract (D-07). The `data-tone` attribute
  drives visual treatment via CSS. No live-region role is applied by default (D-08):
  Load-present content makes any live-region role inert (WAI-ARIA APG), and adding one
  risks duplicate announcements on LiveView re-render. A live-region role is opt-in
  per call site via `:rest` for genuinely post-load dynamic notices.

  See the [Admin Design Contract](guides/reference/admin-design-contract.md) for the
  full rationale (D-07/D-08/D-09).

  ## Examples

      <.notice tone={:warn}>
        Password reset email could not be delivered.
      </.notice>

      <.notice tone={:ok}>
        Email address verified successfully.
      </.notice>
  """
  attr :tone, :atom,
    values: [:ok, :warn, :risk, :info, nil],
    default: nil,
    doc: "the visual tone applied via data-tone; renders as a string in the HTML attribute"

  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"

  attr :rest, :global,
    doc: "arbitrary HTML attributes (e.g., a live-region role for opt-in post-load notices)"

  slot :inner_block, required: true, doc: "the notice message content"

  def notice(assigns) do
    ~H"""
    <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
      <div class="sg-text-sm">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # notice_link/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders an inline navigation action for use inside `notice/1` copy.

  This remains a native link and keeps notice content sentence-shaped. Use it
  when the notice names a concrete next step; use `task_card/1` or `sg-btn`
  variants for standalone primary actions.

  ## Examples

      <.notice tone={:risk}>
        3 accounts need review —
        <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
      </.notice>
  """
  attr :href, :string, required: true, doc: "the URL the notice action navigates to"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root link"

  slot :inner_block, required: true, doc: "the notice action label"

  def notice_link(assigns) do
    ~H"""
    <a href={@href} class={["sg-notice__action", @class]} {@rest}>
      {render_slot(@inner_block)}
    </a>
    """
  end

  # ---------------------------------------------------------------------------
  # field_help/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a compact label-adjacent help trigger with a non-interactive tooltip.

  Use this for admin form fields whose effect is not obvious from the label alone.
  Keep the tooltip copy brief and plain-language; the panel should not contain
  links or other interactive content.

  ## Examples

      <span class="sg-field-label-row">
        <label class="sg-field-label" for="branding-logo-url">Logo URL</label>
        <.field_help id="branding-logo-url-help" label="Logo URL">
          Shown on generated auth screens and email headers when set.
        </.field_help>
      </span>
  """
  attr :id, :string, required: true, doc: "stable id for the tooltip panel"
  attr :label, :string, required: true, doc: "field label used in the trigger's accessible name"

  attr :open, :boolean,
    default: false,
    doc: "renders the tooltip open for deterministic design-gallery evidence"

  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  slot :inner_block, required: true, doc: "plain explanatory tooltip copy"

  def field_help(assigns) do
    ~H"""
    <span
      class={["sg-field-help", @class]}
      data-sg-field-help-root="true"
      data-help-open={if @open, do: "true", else: nil}
      {@rest}
    >
      <button
        type="button"
        class="sg-field-help__trigger"
        aria-label={"Help: #{@label}"}
        aria-controls={@id}
        aria-describedby={@id}
        aria-expanded={to_string(@open)}
        data-sg-field-help-trigger="true"
      >
        <svg
          class="sg-field-help__icon"
          viewBox="0 0 24 24"
          fill="none"
          focusable="false"
          aria-hidden="true"
        >
          <path
            d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M12 11.25v5"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M12 7.75h.01"
            stroke="currentColor"
            stroke-width="2.3"
            stroke-linecap="round"
          />
        </svg>
      </button>
      <span id={@id} class="sg-field-help__panel" role="tooltip" hidden={!@open}>
        {render_slot(@inner_block)}
      </span>
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # skeleton/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders a loading-shape placeholder.

  Shimmer motion is owned entirely by the CSS layer (`app.css`) and is stripped by
  the universal `prefers-reduced-motion` rule. No inline motion or transition style
  is added by this component.

  ## Examples

      <.skeleton class="h-8 w-32" />
  """
  attr :class, :any,
    default: nil,
    doc: "additional CSS classes merged onto the root element (e.g., height/width)"

  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def skeleton(assigns) do
    ~H"""
    <div class={["sg-skeleton", @class]} {@rest}></div>
    """
  end

  # ---------------------------------------------------------------------------
  # audit_row/1
  # ---------------------------------------------------------------------------

  @doc """
  Renders an audit event card (`sg-list-row`) with a pill cluster, actor summary,
  optional detail lines, and a formatted timestamp.

  This is the single shared component for all three audit surfaces:
  - `AuditIndexLive` mobile card list (`show_detail: true`, `show_codes: true`)
  - `AuditUserLive` mobile card list (`show_detail: true`, `show_codes: true`)
  - `UserShowLive` "Recent Audit" compact block (defaults: `show_detail: false`, `show_codes: false`)

  Tone is derived from `row.outcome` and `row.action_badge` via the single internal
  `audit_tone/1` helper, which is the authoritative source replacing the divergent
  `row_tone/1` helpers previously present in `AuditIndexLive` and `AuditUserLive`.

  The `format_date/1` helper handles `%DateTime{}` and `%NaiveDateTime{}` values,
  renders `nil` as `"—"`, and raises `ArgumentError` on any other type (D-09 fix).

  ## Examples

      <.audit_row row={row} />

      <.audit_row row={row} show_detail show_codes />

  """
  attr :row, :map, required: true, doc: "the presenter row map for the audit event"

  attr :show_detail, :boolean,
    default: false,
    doc:
      "renders the Actor and Effective user detail lines (on in explorers, off in compact block)"

  attr :show_codes, :boolean,
    default: false,
    doc: "renders the event id and action code lines (on in explorers, off in compact block)"

  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def audit_row(assigns) do
    ~H"""
    <article class={["sg-list-row sg-stack sg-stack--2", @class]} data-tone={audit_tone(@row)} {@rest}>
      <div class="sg-cluster sg-cluster--2">
        <span class="sg-status-pill" data-tone={audit_tone(@row)}>{@row.action_label}</span>
        <span :if={@row.action_badge} class="sg-status-pill" data-tone="info">{@row.action_badge}</span>
      </div>
      <span class="sg-muted sg-text-sm">{@row.actor_summary}</span>
      <span :if={@show_detail} class="sg-muted sg-text-sm">Actor: {@row.actor_label}</span>
      <span :if={@show_detail and @row.action_badge} class="sg-muted sg-text-sm">Effective user: {@row.effective_user_label}</span>
      <span class="sg-muted sg-text-xs">{format_date(@row.inserted_at)}</span>
      <code :if={@show_codes} class="sg-code">{@row.id}</code>
      <code :if={@show_codes} class="sg-code">{@row.action}</code>
    </article>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers for audit_row/1
  # ---------------------------------------------------------------------------

  # Single source of truth for audit tone derivation (D-10).
  # Retires the divergent row_tone/1 (×2) in AuditIndexLive/AuditUserLive and
  # the old audit_tone/1 in UserShowLive.
  defp audit_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
  defp audit_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
  defp audit_tone(_row), do: nil

  # Date formatting helper for audit timestamps (D-09 fix).
  # Handles %DateTime{} and %NaiveDateTime{} (formats as "%Y-%m-%d %H:%M", no seconds).
  # nil → "—" (explicit nil placeholder).
  # Any other value raises ArgumentError — the catch-all must NOT silently render
  # a populated-but-wrong-typed value into user-facing HEEx (T-158-01 mitigation).
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_date(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%Y-%m-%d %H:%M")
  defp format_date(nil), do: "—"

  defp format_date(value) do
    raise ArgumentError,
          "format_date/1 expected %DateTime{}, %NaiveDateTime{}, or nil, got: #{inspect(value)}"
  end
end
