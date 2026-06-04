defmodule Sigra.Admin.Components do
  @moduledoc """
  Lib-owned canonical admin component set for Sigra's admin LiveViews.

  Provides 11 flat, stateless `Phoenix.Component` function components that consolidate
  the duplicated admin chrome across LiveViews. Security-critical design and a11y fixes
  propagate to host apps via `mix deps.update` (D-05).

  Each component emits only existing `sg-*` CSS classes as defined by the design contract.
  No component introduces new CSS classes.

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

  ## Examples

      <.summary_chip label="MFA enabled" value={7} />
  """
  attr :label, :string, required: true, doc: "the term / KPI label"
  attr :value, :integer, required: true, doc: "the numeric KPI value"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def summary_chip(assigns) do
    ~H"""
    <div class={["sg-metric", @class]} {@rest}>
      <dt>{@label}</dt>
      <dd>{@value}</dd>
    </div>
    """
  end

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
  attr :remove_href, :string, required: true, doc: "the URL to navigate to in order to remove this filter"
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

  The copy is caller-supplied (e.g., the result of `scope_copy/1`). No dedicated
  class is added; the component reuses `sg-muted sg-text-sm`.

  ## Examples

      <.scope_ribbon copy={scope_copy(@admin_scope)} />
  """
  attr :copy, :string, required: true, doc: "the scope indicator copy (e.g., \"Platform admin\")"
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
  attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

  def scope_ribbon(assigns) do
    ~H"""
    <span class={["sg-muted sg-text-sm", @class]} {@rest}>{@copy}</span>
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

  attr :rest, :global, doc: "arbitrary HTML attributes (e.g., a live-region role for opt-in post-load notices)"

  slot :inner_block, required: true, doc: "the notice message content"

  def notice(assigns) do
    ~H"""
    <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
      <p class="sg-text-sm">{render_slot(@inner_block)}</p>
    </div>
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
  attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element (e.g., height/width)"
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
    doc: "renders the Actor and Effective user detail lines (on in explorers, off in compact block)"

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
