defmodule Sigra.Test.Brand.Catalog do
  @moduledoc """
  Test-only harness for the before/after text catalog of rendered output (BGEN-03).

  Phase 262 changes how Sigra looks and what it says. To review that change as a
  text diff, a "before" catalog is captured once while the shipped bytes are still
  identical to main, and an "after" catalog is regenerated on demand. This module
  owns the parts that do not depend on a database or a browser:

    * `normalize/2` - a pure function that removes every per-render volatile from
      rendered HTML (csrf tokens, phx ids, signed session values, asset `vsn`
      queries, per-render ids, UUIDs, wall-clock relative text) and canonicalizes
      whitespace so component reflow does not produce noisy diffs. Absolute
      timestamps are never normalized by pattern: a leaked absolute stamp means a
      data timestamp was not pinned at its source, and that must stay visible.
    * the tier-1 producers - pure renders of the library admin LiveViews with
      literal assigns (no database, no browser, no clock).
    * `build/1` - tier 1 plus the raw tier-2 and generated-host dumps that other
      plans leave under the raw directory, normalized into the committed layout.
    * `write!/2` - the guarded writer for the `:after` catalog and, once, the
      committed `:before` catalog with its `MANIFEST.json`.
    * `manifest/2`, `verify_manifest/1`, `privacy_violations/1` and
      `assert_main_identity!/1` - the integrity, privacy and pin checks.

  The committed "before" is protected by hash (`verify_manifest/1` re-hashes every
  committed file) and by refuse-to-overwrite, never by equality with current
  sources: that comparison would go red in Phase 261 by design.

  Nothing here evaluates repo content beyond rendering library components with
  literal assigns. The writer is a local maintainer action:

      SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs

  It is requested only through `Sigra.Test.Brand.RegenGuard.requested?/3`, so it
  is refused when `CI` is `true`.
  """

  alias Sigra.Admin.Audit.Presenter

  alias Sigra.Admin.Live.{
    AuditIndexLive,
    AuditUserLive,
    BrandingLive,
    IndexLive,
    OrganizationLive,
    UserSessionsLive,
    UserShowLive,
    UsersIndexLive
  }

  alias Sigra.Admin.Scope
  alias Sigra.Branding
  alias Sigra.Branding.Profile
  alias Sigra.Test.Brand.RegenGuard

  @root Path.expand("../../..", __DIR__)
  @env_name "SIGRA_BRAND_CATALOG"
  @before_dir "test/fixtures/brand/before"
  @after_dir "tmp/catalog-after"
  @raw_dir "tmp/catalog-raw"
  @manifest_file "MANIFEST.json"
  @schema "sigra.brand-catalog-before/v1"
  @provenance "brand book v2.0 (2026-11-13)"

  @tier1_dir "tier1-library-admin"

  # Committed lane directories, and where the raw dumps of plan 03 come from:
  # `{raw subdirectory, committed directory, extension, normalizer format}`.
  @raw_lanes [
    {"tier2-example-admin", "tier2-example-admin", ".html", :html},
    {"generated-host/pages", "generated-host-pages", ".html", :html},
    {"generated-host/emails", "generated-host-emails", ".txt", :text}
  ]
  @lane_dirs [@tier1_dir, "tier2-example-admin", "generated-host-pages", "generated-host-emails"]

  # Shipped stylesheet and logo bytes pinned in the manifest at capture time.
  @css_pin_files [
    "priv/templates/sigra.install/admin/sigra_admin.css",
    "priv/templates/sigra.install/core/sigra_auth.css",
    "priv/templates/sigra.install/admin/sigra-logo-primary.svg",
    "priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg"
  ]

  # Pinned data clock. Every data timestamp in a tier-1 literal is a constant on or
  # before `@clock_pin`; only wall-clock relative text is normalized.
  @clock_pin ~D[2026-05-15]
  @registered_at ~U[2026-03-02 10:00:00Z]
  @confirmed_at ~U[2026-03-02 10:05:00Z]
  @last_active_at ~U[2026-05-14 08:12:00Z]
  @older_active_at ~U[2026-05-12 16:40:00Z]
  @locked_at ~U[2026-05-13 17:45:00Z]
  @deleted_at ~U[2026-05-10 09:00:00Z]
  @invite_expires_at ~U[2026-05-15 00:00:00Z]
  @invite_expired_at ~U[2026-05-01 00:00:00Z]

  # Fictional, readable personas on the reserved `.test` TLD. The UUIDs are
  # literals, so every render of a state is byte-stable; the normalizer maps them
  # to `{{PERSONA:<key>}}` labels.
  @personas [
    {:admin, "00000000-0000-4000-8000-000000000001", "admin@demo.tasklane.test"},
    {:active, "00000000-0000-4000-8000-000000000002", "active.user@demo.tasklane.test"},
    {:unconfirmed, "00000000-0000-4000-8000-000000000003", "unconfirmed.user@demo.tasklane.test"},
    {:locked, "00000000-0000-4000-8000-000000000004", "locked.user@demo.tasklane.test"},
    {:scheduled_deletion, "00000000-0000-4000-8000-000000000005",
     "deletion.user@demo.tasklane.test"}
  ]

  # Copies of the private option lists the LiveViews read. They are literal render
  # inputs, not behavior under test: a change to a LiveView's own list shows up as
  # a diff in the "after" catalog only if the copy here is updated with it.
  @quick_filter_keys ~w(confirmed mfa passkeys locked deleted needs_review)
  @more_filter_keys ~w(provider registered_from registered_to organization)
  @light_color_fields [
    {"accent_color", "Accent"},
    {"accent_foreground", "On accent"},
    {"background_color", "Background"},
    {"surface_color", "Surface"},
    {"text_color", "Text"},
    {"muted_color", "Muted"},
    {"border_color", "Border"}
  ]
  @dark_color_fields [
    {"dark_accent_color", "Accent"},
    {"dark_accent_foreground", "On accent"},
    {"dark_background_color", "Background"},
    {"dark_surface_color", "Surface"},
    {"dark_text_color", "Text"},
    {"dark_muted_color", "Muted"},
    {"dark_border_color", "Border"}
  ]
  @branding_form_keys ~w(
    product_name logo_url logo_alt dark_logo_url theme
    accent_color accent_foreground background_color surface_color text_color muted_color border_color
    dark_accent_color dark_accent_foreground dark_background_color dark_surface_color
    dark_text_color dark_muted_color dark_border_color
    support_url privacy_url terms_url email_from_name email_from_address email_reply_to
  )

  @uuid ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/

  @slash "/"
  @users_dir @slash <> "Users" <> @slash
  @home_dir @slash <> "home" <> @slash

  @type live :: module()
  @type state :: atom()
  @type entry :: {live(), state()}
  @type mode :: :before | :after
  @type diff :: [{:added | :removed | :changed, String.t()}]
  @type git :: ([String.t()] -> {String.t(), non_neg_integer()})

  @doc "The environment variable that requests a catalog write (`before` or `after`)."
  @spec regen_env() :: String.t()
  def regen_env, do: @env_name

  @doc "The exact maintainer command that writes the catalog for `mode`."
  @spec regen_command(mode()) :: String.t()
  def regen_command(mode) when mode in [:before, :after] do
    "#{@env_name}=#{mode} mix test test/sigra/brand/catalog_test.exs"
  end

  @doc "Absolute default output directory for `mode`."
  @spec out_dir(mode()) :: Path.t()
  def out_dir(:before), do: Path.join(@root, @before_dir)
  def out_dir(:after), do: Path.join(@root, @after_dir)

  @doc "Absolute default directory of the raw tier-2 and generated-host dumps."
  @spec raw_dir() :: Path.t()
  def raw_dir, do: Path.join(@root, @raw_dir)

  # -- normalizer ------------------------------------------------------------

  @doc """
  Removes per-render volatiles from rendered text and canonicalizes whitespace.

  Options:

    * `:personas` - `%{uuid => key}`; each listed UUID becomes `{{PERSONA:<key>}}`
      before the generic UUID rule runs. Default `%{}`.
    * `:format` - `:html` (default) collapses whitespace and puts every tag on its
      own line; `:text` only trims trailing whitespace per line.

  Replaced: csrf token values (`{{CSRF}}`), `phx-` request ids, `data-phx-*` signed
  values, the asset `vsn` query (`{{VSN}}`), per-render `mg-<n>-...-<n>` ids
  (`{{N}}`), every UUID (`{{UUID}}`) and relative times such as `just now` or
  `3h ago` (`{{RELATIVE}}`).

  One shipped literal is masked rather than normalized: the placeholder address in
  the branding sign-in preview (`Sigra.Admin.Components.preview_pair/1`) is an
  `example.com` address, which `privacy_violations/1` correctly rejects and which
  `lib/` cannot change in this phase. It becomes `{{PREVIEW_EMAIL}}`, and the
  manifest coverage says so. Any other `example.com` address is left alone and
  still fails the privacy scan.

  Deliberately NOT replaced: absolute timestamps. Pin them at the source instead.
  """
  @spec normalize(String.t(), keyword()) :: String.t()
  def normalize(text, opts \\ []) when is_binary(text) do
    personas = Keyword.get(opts, :personas, %{})
    format = Keyword.get(opts, :format, :html)

    text
    |> String.replace("\r\n", "\n")
    |> replace_personas(personas)
    |> replace_volatiles()
    |> canonicalize(format)
  end

  defp replace_personas(text, personas) do
    personas
    |> Enum.sort()
    |> Enum.reduce(text, fn {uuid, key}, acc ->
      acc
      |> String.replace(uuid, "{{PERSONA:#{key}}}")
      |> String.replace(String.upcase(uuid), "{{PERSONA:#{key}}}")
    end)
  end

  defp replace_volatiles(text) do
    text
    |> sub(~r/(name="_?csrf[-_]token"[^>]*?(?:value|content)=")[^"]*"/, "\\1{{CSRF}}\"")
    |> sub(~r/((?:value|content)=")[^"]*("[^>]*?name="_?csrf[-_]token")/, "\\1{{CSRF}}\\2")
    |> sub(~r/(data-csrf=")[^"]*"/, "\\1{{CSRF}}\"")
    |> sub(~r/([?&;]_csrf_token=)[A-Za-z0-9_%=-]+/, "\\1{{CSRF}}")
    |> sub(~r/(\bid="phx-)[A-Za-z0-9_-]+"/, "\\1{{REQUEST_ID}}\"")
    |> sub(~r/(data-phx-(?:parent-id|root-id|id)=")[^"]*"/, "\\1{{PHX_ID}}\"")
    |> sub(~r/(data-phx-session=")[^"]*"/, "\\1{{PHX_SESSION}}\"")
    |> sub(~r/(data-phx-static=")[^"]*"/, "\\1{{PHX_STATIC}}\"")
    |> sub(~r/(request[-_]id["']?\s*[:=]\s*["']?)[A-Za-z0-9_=-]{8,}/i, "\\1{{REQUEST_ID}}")
    |> sub(~r/([?&]vsn=)[A-Za-z0-9]+/, "\\1{{VSN}}")
    |> sub(~r/\b(mg-\d+-[a-z][a-z-]*-)\d+\b/, "\\1{{N}}")
    |> sub(@uuid, "{{UUID}}")
    |> sub(~r/\balex@example\.com\b/, "{{PREVIEW_EMAIL}}")
    |> sub(~r/\bjust now\b/, "{{RELATIVE}}")
    |> sub(~r/\b\d+[mhd] ago\b/, "{{RELATIVE}}")
  end

  defp sub(text, regex, replacement), do: Regex.replace(regex, text, replacement)

  defp canonicalize(text, :html) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.replace("<", "\n<")
    |> String.replace(">", ">\n")
    |> lines()
  end

  defp canonicalize(text, :text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
    |> String.trim_trailing("\n")
    |> Kernel.<>("\n")
  end

  defp lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  # -- tier 1: pure renders of the library admin LiveViews --------------------

  # One entry per state worth reviewing as text. A state a pure render cannot reach
  # (it needs a database association, a connected socket, or is driven by a
  # LiveView event rather than by render assigns) is not faked: it is named in the
  # manifest `not_covered` text instead.
  @tier1_states [
    {AuditIndexLive, :empty},
    {AuditIndexLive, :populated},
    {AuditUserLive, :empty},
    {AuditUserLive, :populated},
    {BrandingLive, :default_profile},
    {BrandingLive, :explicit_profile},
    {IndexLive, :needs_review},
    {IndexLive, :overview},
    {OrganizationLive, :empty},
    {OrganizationLive, :populated},
    {UserSessionsLive, :empty},
    {UserSessionsLive, :populated},
    {UserShowLive, :active},
    {UserShowLive, :locked},
    {UserShowLive, :scheduled_deletion},
    {UserShowLive, :unconfirmed},
    {UsersIndexLive, :empty},
    {UsersIndexLive, :filtered_empty},
    {UsersIndexLive, :populated}
  ]

  @doc "The `{live_module, state}` pairs rendered in tier 1, sorted."
  @spec tier1_states() :: [entry()]
  def tier1_states, do: Enum.sort(@tier1_states)

  @doc "Repo-relative catalog paths of the tier-1 files, `tier1-library-admin/<live>--<state>.html`."
  @spec tier1_entries() :: [String.t()]
  def tier1_entries, do: tier1_states() |> Enum.map(&entry_path/1) |> Enum.sort()

  defp entry_path({live, state}) do
    slug = live |> Module.split() |> List.last() |> Macro.underscore()
    "#{@tier1_dir}/#{slug}--#{state}.html"
  end

  @doc "The raw (un-normalized) HTML of one tier-1 state, rendered from literal assigns."
  @spec tier1_raw(entry()) :: String.t()
  def tier1_raw({live, state} = entry) when is_atom(live) and is_atom(state) do
    entry
    |> tier1_assigns()
    |> Map.put(:__changed__, nil)
    |> live.render()
    |> Phoenix.LiveViewTest.rendered_to_string()
  end

  @doc "The normalized HTML of one tier-1 state."
  @spec tier1_html(entry()) :: String.t()
  def tier1_html(entry), do: entry |> tier1_raw() |> normalize(personas: tier1_personas())

  @doc "`%{path => normalized html}` for every tier-1 state."
  @spec tier1_files() :: %{String.t() => String.t()}
  def tier1_files, do: Map.new(tier1_states(), &{entry_path(&1), tier1_html(&1)})

  @doc "The `%{uuid => key}` persona map used to label ids in tier 1."
  @spec tier1_personas() :: %{String.t() => String.t()}
  def tier1_personas,
    do: Map.new(@personas, fn {key, id, _email} -> {id, Atom.to_string(key)} end)

  @doc "The fictional `.test` persona addresses used by tier 1, sorted."
  @spec persona_emails() :: [String.t()]
  def persona_emails, do: @personas |> Enum.map(fn {_key, _id, email} -> email end) |> Enum.sort()

  @doc "The latest date a data timestamp in a tier-1 literal may carry."
  @spec clock_pin() :: Date.t()
  def clock_pin, do: @clock_pin

  @doc """
  Absolute date tokens (`YYYY-MM-DD`) in `text` that are not pinned: later than
  `clock_pin/0`, or equal to `today` (default: the UTC date of the run).

  A data timestamp that was built from the wall clock fails this on the day it is
  introduced, not only across midnight. Sorted, unique; `[]` means clean.
  """
  @spec clock_violations(String.t(), Date.t()) :: [String.t()]
  def clock_violations(text, today \\ Date.utc_today()) when is_binary(text) do
    ~r/(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)/
    |> Regex.scan(text)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
    |> Enum.filter(fn token ->
      case Date.from_iso8601(token) do
        {:ok, date} -> Date.compare(date, @clock_pin) == :gt or date == today
        {:error, _reason} -> false
      end
    end)
    |> Enum.sort()
  end

  # -- tier 1: literal assigns per state ----------------------------------------

  defp tier1_assigns({UsersIndexLive, :populated}) do
    rows = [
      index_row(:active,
        mfa?: true,
        passkeys: 1,
        orgs: ["Tasklane Demo Org"],
        last_active_at: @last_active_at
      ),
      index_row(:unconfirmed, confirmed_at: nil),
      index_row(:locked, locked_at: @locked_at, last_active_at: @older_active_at),
      index_row(:scheduled_deletion, deleted_at: @deleted_at)
    ]

    users_index_assigns(
      rows,
      %{},
      posture(
        total: 4,
        confirmed: 3,
        mfa_enabled: 1,
        passkey_users: 1,
        locked_out: 1,
        deletion_scheduled: 1
      )
    )
  end

  defp tier1_assigns({UsersIndexLive, :empty}), do: users_index_assigns([], %{}, posture([]))

  defp tier1_assigns({UsersIndexLive, :filtered_empty}) do
    users_index_assigns(
      [],
      %{"q" => "nobody", "locked" => "true"},
      posture(
        total: 4,
        confirmed: 3,
        mfa_enabled: 1,
        passkey_users: 1,
        locked_out: 1,
        deletion_scheduled: 1
      )
    )
  end

  defp tier1_assigns({UserShowLive, state}) do
    %{
      admin_scope: admin_scope(),
      current_scope: %{},
      return_to: "/admin/users",
      detail: user_show_detail(state)
    }
  end

  defp tier1_assigns({UserSessionsLive, :populated}) do
    %{admin_scope: admin_scope(), confirm_action: nil, detail: user_show_detail(:active)}
  end

  defp tier1_assigns({UserSessionsLive, :empty}) do
    %{admin_scope: admin_scope(), confirm_action: nil, detail: user_show_detail(:unconfirmed)}
  end

  defp tier1_assigns({AuditIndexLive, :populated}) do
    %{
      admin_scope: admin_scope(),
      rows: audit_rows(audit_specs()),
      meta: %{previous_page: nil, next_page: "next-page-cursor", current_page: 1},
      current_params: %{}
    }
  end

  defp tier1_assigns({AuditIndexLive, :empty}) do
    %{
      admin_scope: admin_scope(),
      rows: [],
      meta: %{previous_page: nil, next_page: nil, current_page: 1},
      current_params: %{}
    }
  end

  defp tier1_assigns({AuditUserLive, :populated}) do
    active = user(:active, [])

    %{
      admin_scope: admin_scope(),
      detail: user_show_detail(:active),
      rows: audit_rows(audit_specs()),
      meta: %{previous_page: nil, next_page: nil, current_page: 1},
      current_params: %{},
      return_to: "/admin/users/#{active.id}"
    }
  end

  defp tier1_assigns({AuditUserLive, :empty}) do
    unconfirmed = user(:unconfirmed, [])

    %{
      admin_scope: admin_scope(),
      detail: user_show_detail(:unconfirmed),
      rows: [],
      meta: %{previous_page: nil, next_page: nil, current_page: 1},
      current_params: %{},
      return_to: "/admin/users/#{unconfirmed.id}"
    }
  end

  defp tier1_assigns({OrganizationLive, :populated}) do
    %{
      admin_scope: organization_scope(),
      organization_name: "Tasklane Demo Org",
      loading: false,
      summary_counts: %{locked: 1, deleted: 1},
      members: [
        member("Owner User", "owner", []),
        member("Admin User", "admin", []),
        member("Locked Member", "member", locked?: true),
        member("Leaving Member", "member", confirmed?: false, deletion_scheduled?: true)
      ],
      pending_invitations: [
        invitation("invitee.one@demo.tasklane.test", "member", false, @invite_expires_at),
        invitation("invitee.two@demo.tasklane.test", "admin", true, @invite_expired_at)
      ]
    }
  end

  defp tier1_assigns({OrganizationLive, :empty}) do
    %{
      admin_scope: organization_scope(),
      organization_name: "Tasklane Demo Org",
      loading: false,
      summary_counts: %{},
      members: [],
      pending_invitations: []
    }
  end

  defp tier1_assigns({IndexLive, :overview}) do
    index_assigns(posture(total: 42, confirmed: 40, mfa_enabled: 18, passkey_users: 9))
  end

  defp tier1_assigns({IndexLive, :needs_review}) do
    index_assigns(
      posture(
        total: 42,
        confirmed: 40,
        mfa_enabled: 18,
        passkey_users: 9,
        locked_out: 2,
        deletion_scheduled: 1
      )
    )
  end

  defp tier1_assigns({BrandingLive, :default_profile}),
    do: branding_assigns(Profile.default(), :config_defaults)

  defp tier1_assigns({BrandingLive, :explicit_profile}),
    do: branding_assigns(explicit_profile(), :admin_profile)

  # -- literal data builders --------------------------------------------------

  defp admin_scope do
    %Scope{
      mode: :global,
      scope: %{user: user(:admin, [])},
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  defp organization_scope do
    org_id = "00000000-0000-4000-8000-0000000000b1"

    %Scope{
      mode: :organization,
      scope: %{user: user(:admin, [])},
      organization: %{id: org_id, name: "Tasklane Demo Org", slug: "tasklane-demo"},
      organization_id: org_id,
      organization_slug: "tasklane-demo",
      platform_admin?: false,
      admin_org_ids: [org_id]
    }
  end

  defp user(key, attrs) do
    {^key, id, email} = List.keyfind!(@personas, key, 0)

    Map.merge(
      %{
        id: id,
        email: email,
        display_name: nil,
        confirmed_at: @confirmed_at,
        locked_at: nil,
        deleted_at: nil,
        inserted_at: @registered_at
      },
      Map.new(attrs)
    )
  end

  defp persona_id(key) do
    {^key, id, _email} = List.keyfind!(@personas, key, 0)
    id
  end

  defp session(type, ip, last_active_at, hashed_token) do
    %{type: type, ip: ip, last_active_at: last_active_at, hashed_token: hashed_token}
  end

  defp detail(user, opts) do
    sessions = Keyword.get(opts, :sessions, [])
    display_name = Map.get(user, :display_name) || user.email

    %{
      user: user,
      display_name: display_name,
      identities_available?: true,
      copy_overrides: %{},
      extra_detail_sections: [],
      scope_label: "Global scope",
      identity: %{
        email: user.email,
        display_name: display_name,
        confirmed?: not is_nil(user.confirmed_at),
        locked?: not is_nil(user.locked_at),
        deleted?: not is_nil(user.deleted_at),
        inserted_at: user.inserted_at
      },
      sessions: sessions,
      security: %{
        mfa_status: Keyword.get(opts, :mfa_status),
        passkeys: [],
        passkey_count: Keyword.get(opts, :passkey_count, 0)
      },
      identities: Keyword.get(opts, :identities, []),
      organizations: Keyword.get(opts, :organizations, []),
      recent_audit: Keyword.get(opts, :recent_audit, []),
      danger_zone: %{
        revoke_all_sessions?: sessions != [],
        impersonation_target_label: display_name
      }
    }
  end

  defp user_show_detail(:active) do
    user = user(:active, [])

    detail(user,
      sessions: [
        session(:standard, "203.0.113.10", @last_active_at, <<1, 2, 3, 4>>),
        session(:remember_me, "203.0.113.11", @older_active_at, <<5, 6, 7, 8>>)
      ],
      mfa_status: %{enabled: true},
      passkey_count: 1,
      identities: [%{provider: "github", provider_email: user.email}],
      organizations: [
        %{
          organization_name: "Tasklane Demo Org",
          organization_slug: "tasklane-demo",
          role: "owner"
        }
      ],
      recent_audit: audit_rows(Enum.take(audit_specs(), 2))
    )
  end

  defp user_show_detail(:unconfirmed) do
    detail(user(:unconfirmed, confirmed_at: nil), [])
  end

  defp user_show_detail(:locked) do
    detail(user(:locked, locked_at: @locked_at),
      sessions: [session(:standard, "203.0.113.24", @last_active_at, <<1, 2, 3, 4>>)],
      recent_audit: audit_rows([{"auth.lockout.locked", "failure", :locked, :locked, @locked_at}])
    )
  end

  defp user_show_detail(:scheduled_deletion) do
    detail(user(:scheduled_deletion, deleted_at: @deleted_at),
      sessions: [session(:standard, "203.0.113.31", @older_active_at, <<9, 8, 7, 6>>)]
    )
  end

  defp index_row(key, opts) do
    orgs = Keyword.get(opts, :orgs, [])

    %{
      user: user(key, Keyword.take(opts, [:confirmed_at, :locked_at, :deleted_at])),
      display_name: nil,
      last_active_at: Keyword.get(opts, :last_active_at),
      has_mfa: Keyword.get(opts, :mfa?, false),
      passkey_count: Keyword.get(opts, :passkeys, 0),
      organization_count: length(orgs),
      organization_summary: if(orgs == [], do: "No organizations", else: Enum.join(orgs, ", ")),
      extra_badges: [],
      extra_columns: []
    }
  end

  defp users_index_assigns(rows, params, posture) do
    %{
      admin_scope: admin_scope(),
      rows: rows,
      meta: %{
        total_count: length(rows),
        current_offset: 0,
        total_pages: 1,
        previous_page: nil,
        next_page: nil,
        current_page: 1
      },
      current_params: params,
      summary_stats: %{
        posture: posture,
        growth: %{new_this_week: 0, new_this_month: 1},
        activity: %{available?: false, active_this_week: nil, active_this_month: nil}
      },
      quick_filter_keys: @quick_filter_keys,
      more_filter_keys: @more_filter_keys,
      filters_open?: false
    }
  end

  defp index_assigns(posture) do
    %{
      admin_scope: admin_scope(),
      loading: false,
      summary_stats: %{
        posture: posture,
        growth: %{new_this_week: 3, new_this_month: 9},
        activity: %{available?: true, active_this_week: 17, active_this_month: 31}
      }
    }
  end

  defp posture(overrides) do
    Map.merge(
      %{
        total: 0,
        confirmed: 0,
        mfa_enabled: 0,
        passkey_users: 0,
        locked_out: 0,
        deletion_scheduled: 0
      },
      Map.new(overrides)
    )
  end

  defp member(display_name, role, flags) do
    Map.merge(
      %{
        display_name: display_name,
        role: role,
        locked?: false,
        deletion_scheduled?: false,
        confirmed?: true
      },
      Map.new(flags)
    )
  end

  defp invitation(email, role, expired?, expires_at) do
    %{email: email, role: role, expired?: expired?, expires_at: expires_at}
  end

  defp branding_assigns(%Profile{} = profile, profile_source) do
    %{
      admin_scope: admin_scope(),
      light_color_fields: @light_color_fields,
      dark_color_fields: @dark_color_fields,
      persisted_profile: profile,
      preview_profile: profile,
      draft_params: branding_draft_params(profile),
      profile_source: profile_source,
      dirty?: false,
      error: nil,
      restore_defaults_open?: false,
      active_panel: if(profile.theme == :dark, do: :dark, else: :light)
    }
  end

  # The form params BrandingLive derives from a profile on mount, built from the
  # same public functions (`Profile.to_map/1`, `Branding.color_tokens/2`).
  defp branding_draft_params(%Profile{} = profile) do
    dark = Branding.color_tokens(profile, :dark)

    merged =
      Map.merge(Profile.to_map(profile), %{
        "dark_accent_color" => dark.accent_color,
        "dark_accent_foreground" => dark.accent_foreground,
        "dark_background_color" => dark.background_color,
        "dark_surface_color" => dark.surface_color,
        "dark_text_color" => dark.text_color,
        "dark_muted_color" => dark.muted_color,
        "dark_border_color" => dark.border_color
      })

    Map.new(@branding_form_keys, fn key -> {key, to_string(Map.get(merged, key) || "")} end)
  end

  defp explicit_profile do
    Profile.new!(
      product_name: "Tasklane",
      logo_url: "https://assets.demo.tasklane.test/logo.svg",
      logo_alt: "Tasklane logo",
      dark_logo_url: "https://assets.demo.tasklane.test/logo-dark.svg",
      accent_color: "#2563eb",
      accent_foreground: "#ffffff",
      background_color: "#f8fafc",
      surface_color: "#ffffff",
      text_color: "#0f172a",
      muted_color: "#475569",
      border_color: "#e2e8f0",
      dark_accent_color: "#60a5fa",
      dark_accent_foreground: "#0b1020",
      dark_background_color: "#0b1020",
      dark_surface_color: "#111827",
      dark_text_color: "#e5e7eb",
      dark_muted_color: "#9ca3af",
      dark_border_color: "#1f2937",
      support_url: "https://support.demo.tasklane.test",
      privacy_url: "https://demo.tasklane.test/privacy",
      terms_url: "https://demo.tasklane.test/terms",
      email_from_name: "Tasklane",
      email_from_address: "hello@demo.tasklane.test",
      email_reply_to: "support@demo.tasklane.test",
      theme: :dark
    )
  end

  # Literal audit events: `{action, outcome, actor, effective_user, occurred_at}`,
  # newest first.
  defp audit_specs do
    [
      {"auth.login.success", "success", :active, :active, ~U[2026-05-14 08:12:30Z]},
      {"auth.login.failure", "failure", :active, :active, ~U[2026-05-14 08:10:05Z]},
      {"admin.impersonation.start", "success", :admin, :active, ~U[2026-05-14 08:05:00Z]}
    ]
  end

  # Presenter-shaped audit rows, built by the real presenter from literal events so
  # label and badge wording is whatever the shipped presenter says.
  defp audit_rows(specs) do
    events =
      specs
      |> Enum.with_index(1)
      |> Enum.map(fn {{action, outcome, actor, effective, at}, index} ->
        %{
          id: "00000000-0000-4000-8000-0000000000a#{index}",
          inserted_at: at,
          action: action,
          outcome: outcome,
          actor_id: persona_id(actor),
          effective_user_id: persona_id(effective),
          target_id: persona_id(effective)
        }
      end)

    users_by_id = Map.new(@personas, fn {key, id, _email} -> {id, user(key, [])} end)

    Presenter.present(events, users_by_id)
  end

  # -- build and write --------------------------------------------------------

  @doc """
  Builds the catalog as `%{relative_path => bytes}`: tier 1, plus the raw tier-2
  and generated-host dumps when the raw directory exists.

  A raw directory that exists but lacks one of its three lanes is an error naming
  the lane: there is no silent partial catalog. When no raw directory exists the
  result is tier 1 only.

  Options: `:raw_dir` (default `raw_dir/0`).
  """
  @spec build(keyword()) :: %{String.t() => String.t()}
  def build(opts \\ []) do
    raw = Keyword.get(opts, :raw_dir, raw_dir())
    Map.merge(tier1_files(), raw_files(raw))
  end

  defp raw_files(raw) do
    if File.dir?(raw) do
      @raw_lanes
      |> Enum.flat_map(fn {source, target, ext, format} ->
        case Path.wildcard(Path.join([raw, source, "*" <> ext])) do
          [] ->
            raise "raw lane #{source} has no #{ext} files under #{raw}; produce it before capturing " <>
                    "(a catalog with a missing lane is never written)"

          paths ->
            for path <- Enum.sort(paths) do
              {Path.join(target, Path.basename(path)),
               path |> File.read!() |> normalize(format: format)}
            end
        end
      end)
      |> Map.new()
    else
      %{}
    end
  end

  @doc """
  Writes the catalog for `mode` under the output directory and returns
  `%{dir: dir, files: sorted_relative_paths}`.

  The write is opt-in: `env` (default: the process environment) must set
  `SIGRA_BRAND_CATALOG` to the mode's value. Permission is read only through
  `Sigra.Test.Brand.RegenGuard.requested?/3`, which raises under `CI=true`, so a
  stray exported variable cannot rewrite a committed fixture.

  `:after` clears only the lane directories this module owns and writes tier 1
  plus any raw lanes. `:before` is the single immutable capture: it refuses when
  `MANIFEST.json` already exists, when the raw inputs are missing, and unless
  `assert_main_identity!/1` passes; it writes the manifest last.

  Options: `:env`, `:out_dir` (default `out_dir(mode)`), `:raw_dir`, `:git`
  (a runner in the shape of `System.cmd/3` results, for tests), and
  `:example_files_changed_vs_main`.
  """
  @spec write!(mode(), keyword()) :: %{dir: Path.t(), files: [String.t()]}
  def write!(mode, opts \\ []) when mode in [:before, :after] do
    env = Keyword.get_lazy(opts, :env, &RegenGuard.environment/0)
    value = Atom.to_string(mode)

    unless RegenGuard.requested?(@env_name, value, env) do
      raise ArgumentError,
            "#{@env_name}=#{value} is not set. The catalog writer is opt-in; run: " <>
              regen_command(mode)
    end

    dir = Keyword.get(opts, :out_dir, out_dir(mode))

    case mode do
      :after -> write_after!(dir, opts)
      :before -> write_before!(dir, opts)
    end
  end

  defp write_after!(dir, opts) do
    files = build(opts)

    # Only directories this module owns are cleared, so a stale file from a removed
    # state cannot linger and an unrelated file in `dir` is never touched.
    for lane <- @lane_dirs, do: File.rm_rf!(Path.join(dir, lane))

    write_files!(dir, files)
    %{dir: dir, files: files |> Map.keys() |> Enum.sort()}
  end

  defp write_before!(dir, opts) do
    manifest_path = Path.join(dir, @manifest_file)
    raw = Keyword.get(opts, :raw_dir, raw_dir())
    git = Keyword.get(opts, :git, &run_git/1)

    if File.exists?(manifest_path) do
      raise "the committed before catalog is immutable: #{@manifest_file} already exists in " <>
              "#{dir}. It is the baseline Phase 262 diffs against; write a new catalog with " <>
              "#{regen_command(:after)} instead."
    end

    unless File.dir?(raw) do
      raise ArgumentError,
            "the before catalog needs the raw tier-2 and generated-host inputs, but there is no " <>
              "raw directory at #{raw}. Produce them first; a tier-1-only baseline is never captured."
    end

    identity = assert_main_identity!(git)
    files = build(opts)

    meta = %{
      pinned: Map.put(identity, :css_sha256, css_hashes()),
      example_files_changed_vs_main:
        Keyword.get_lazy(opts, :example_files_changed_vs_main, fn ->
          example_files_changed(git)
        end)
    }

    write_files!(dir, files)
    File.write!(manifest_path, manifest(files, meta))

    %{dir: dir, files: Enum.sort([@manifest_file | Map.keys(files)])}
  end

  defp write_files!(dir, files) do
    for {path, bytes} <- files do
      target = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, bytes)
    end

    :ok
  end

  @doc """
  Runs the writer for whichever mode the environment requests, or does nothing.

  Called from `setup_all` in the catalog test so a maintainer's
  `SIGRA_BRAND_CATALOG=after mix test ...` writes before any test reads the output.
  """
  @spec write_if_requested!(keyword()) :: :ok
  def write_if_requested!(opts \\ []) do
    env = Keyword.get_lazy(opts, :env, &RegenGuard.environment/0)

    case Enum.find([:before, :after], &RegenGuard.requested?(@env_name, Atom.to_string(&1), env)) do
      nil -> :ok
      mode -> mode |> write!(Keyword.put(opts, :env, env)) |> then(fn _ -> :ok end)
    end
  end

  # -- main identity precondition ---------------------------------------------

  @doc """
  Asserts that shipped `lib/` and `priv/` are byte-identical to `origin/main` and
  returns the pin: the `origin/main` and merge-base SHAs plus the `lib`, `priv`
  and golden-tree hashes.

  `git` is an injectable runner returning `{output, exit_status}` as
  `System.cmd/3` does; the default runs real git in the repo root. Raises, naming
  the differing area, when `git diff --quiet origin/main -- lib priv` fails.
  """
  @spec assert_main_identity!(git()) :: %{atom() => String.t()}
  def assert_main_identity!(git \\ &run_git/1) when is_function(git, 1) do
    case git.(["diff", "--quiet", "origin/main", "--", "lib", "priv"]) do
      {_output, 0} ->
        %{
          origin_main_sha: rev!(git, ["rev-parse", "origin/main"]),
          merge_base_sha: rev!(git, ["merge-base", "origin/main", "HEAD"]),
          lib_tree: rev!(git, ["rev-parse", "HEAD:lib"]),
          priv_tree: rev!(git, ["rev-parse", "HEAD:priv"]),
          golden_tree: rev!(git, ["rev-parse", "HEAD:test/fixtures/install_golden/tree"])
        }

      {_output, _status} ->
        areas =
          case for(area <- ["lib", "priv"], differs?(git, area), do: area) do
            [] -> ["lib", "priv"]
            differing -> differing
          end

        raise "refusing to capture: shipped bytes differ from origin/main in: " <>
                "#{Enum.join(areas, ", ")}. The before catalog is only valid while lib/ and priv/ " <>
                "are byte-identical to origin/main (fetch and rebase first, do not capture from " <>
                "a changed tree)."
    end
  end

  defp differs?(git, area) do
    match?({_, status} when status != 0, git.(["diff", "--quiet", "origin/main", "--", area]))
  end

  defp rev!(git, args) do
    case git.(args) do
      {output, 0} -> String.trim(output)
      {output, status} -> raise "git #{Enum.join(args, " ")} failed (exit #{status}): #{output}"
    end
  end

  # Example-app sources that can change what the example renders. Playwright specs,
  # helpers and the README do not, so they are not part of the list.
  @example_render_paths [
    "test/example/lib",
    "test/example/config",
    "test/example/assets",
    "test/example/priv/static",
    "test/example/priv/repo",
    "test/example/priv/gettext"
  ]

  defp example_files_changed(git) do
    case git.(["diff", "--name-only", "origin/main", "--" | @example_render_paths]) do
      {output, 0} -> output |> String.split("\n", trim: true) |> Enum.sort()
      {output, status} -> raise "git diff --name-only failed (exit #{status}): #{output}"
    end
  end

  defp run_git(args), do: System.cmd("git", args, cd: @root, stderr_to_stdout: true)

  defp css_hashes do
    Map.new(@css_pin_files, fn path ->
      {path, @root |> Path.join(path) |> File.read!() |> sha256_hex()}
    end)
  end

  # -- manifest ----------------------------------------------------------------

  @doc "What the catalog covers and what it does not, as the manifest `coverage` field."
  @spec coverage() :: %{String.t() => term()}
  def coverage do
    %{
      "covered" => [
        "tier 1: pure renders of the eight library admin LiveViews with literal assigns, no database, browser or clock",
        "tier 2: example-app admin pages rendered on seeded .test personas, labelled library-admin (example-mirror shell)",
        "generated lane: anonymous generated auth pages and generated emails from one freshly generated host",
        "generated emails are built in the capture host with the branding email_from_address overridden to a seeded .test sender; the shipped default sender is therefore not part of the captured bytes, and no shipped template or default changes",
        "tier 0: copy inventories by reference (test/fixtures/brand/copy-inventory), not duplicated here"
      ],
      "not_covered" => [
        "authenticated generated screens: their markup is baselined by the golden install tree only, not by rendered HTML",
        "dark and System theme for admin HTML: the admin theme is client-side, so server HTML is identical across Light, Dark and System; contrast and axe belong to Phase 261 BTOK-03",
        "explicit light and dark branding-profile variants of the generated anonymous auth pages: only the default-profile value is captured",
        "anything rendered from CSS, and any PNG: the catalog is text only",
        "event-driven states: confirm dialogs (revoke session, revoke all sessions, restore branding defaults), unsaved-draft and validation-error states of the branding screen, and loading skeletons are assigned in LiveView events or on socket connect, not by render assigns, so a pure render cannot reach them without faking copy",
        "the sign-in preview placeholder address on the branding screen is masked to {{PREVIEW_EMAIL}}: the shipped literal is an example.com address that the privacy rule rejects and lib/ cannot change here, so a change to that literal surfaces as a privacy failure, not as a diff line"
      ],
      "theme_note" =>
        "Admin theme is client-side (data-sg-admin-theme is set by an inline script from local storage), so admin HTML is identical across Light, Dark and System. " <>
          "Generated anonymous auth pages emit a server-side data-theme taken from the branding profile (default system, see theme_attr/1 in the generated auth components): " <>
          "only the default-profile value is captured; explicit light and dark profile variants are not."
    }
  end

  defp deferred_shipped_byte_fixes do
    %{
      "fixes" => [
        "registration timing oracle",
        "passkey-options oracle",
        "generated confirm and reset-request fixes"
      ],
      "source" => "259-VERIFICATION.md, note 1 for the next phase planner",
      "rule" =>
        "These change generated output after this capture. If any lands before Phase 262, the generated-lane before must be re-captured first, or the Phase 262 before/after diff is polluted."
    }
  end

  @doc """
  Renders the manifest as pretty JSON: sorted keys, two-space indent, one object
  key and one array element per line, so a one-entry change is a one-line diff.

  `files` is `%{path => bytes}` (hashed here). `meta` must carry `:pinned`; it may
  carry `:personas` (default `persona_emails/0`) and
  `:example_files_changed_vs_main` (default `[]`).
  """
  @spec manifest(%{String.t() => binary()}, map()) :: String.t()
  def manifest(files, meta) when is_map(files) and is_map(meta) do
    pretty(%{
      "schema" => @schema,
      "provenance" => @provenance,
      "pinned" => stringify(Map.fetch!(meta, :pinned)),
      "capture_command" => regen_command(:before),
      "lanes" => %{
        @tier1_dir =>
          "library-admin: pure renders of the library admin LiveViews, literal assigns",
        "tier2-example-admin" =>
          "library-admin (example-mirror shell): example app admin pages on seeded personas",
        "generated-host-pages" =>
          "generated-host: anonymous generated auth pages from one generated host",
        "generated-host-emails" => "generated-host: generated emails built in the same host"
      },
      "personas" => Map.get(meta, :personas, persona_emails()),
      "coverage" => coverage(),
      "example_files_changed_vs_main" => Map.get(meta, :example_files_changed_vs_main, []),
      "deferred_shipped_byte_fixes" => deferred_shipped_byte_fixes(),
      "files" => Map.new(files, fn {path, bytes} -> {path, sha256_hex(bytes)} end)
    })
  end

  defp stringify(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), stringify(v)} end)

  defp stringify(other), do: other

  # The stdlib JSON module only emits compact single-line JSON. This recipe is the
  # sorted-keys, one-element-per-line serializer the frozen-surface baseline uses.
  defp pretty(term), do: pretty(term, 0) <> "\n"

  defp pretty(map, _level) when is_map(map) and map_size(map) == 0, do: "{}"

  defp pretty(map, level) when is_map(map) do
    pad = String.duplicate("  ", level + 1)

    body =
      map
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map_join(",\n", fn {key, value} ->
        pad <> JSON.encode!(to_string(key)) <> ": " <> pretty(value, level + 1)
      end)

    "{\n" <> body <> "\n" <> String.duplicate("  ", level) <> "}"
  end

  defp pretty([], _level), do: "[]"

  defp pretty(list, level) when is_list(list) do
    pad = String.duplicate("  ", level + 1)
    body = Enum.map_join(list, ",\n", fn element -> pad <> pretty(element, level + 1) end)

    "[\n" <> body <> "\n" <> String.duplicate("  ", level) <> "]"
  end

  defp pretty(scalar, _level), do: JSON.encode!(scalar)

  # -- integrity ---------------------------------------------------------------

  @doc """
  Reads every regular file under `dir` (except `MANIFEST.json` and `.DS_Store`)
  as `%{relative_path => bytes}`.
  """
  @spec read_dir!(Path.t()) :: %{String.t() => binary()}
  def read_dir!(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
    |> Enum.reject(&(&1 == @manifest_file or Path.basename(&1) == ".DS_Store"))
    |> Map.new(&{&1, File.read!(Path.join(dir, &1))})
  end

  @doc """
  Re-hashes every file under `dir` and compares with the `files` map of its
  `MANIFEST.json`. Returns `[]` when they agree, else sorted
  `{:added | :removed | :changed, path}` tuples.
  """
  @spec verify_manifest(Path.t()) :: diff()
  def verify_manifest(dir) do
    expected =
      dir |> Path.join(@manifest_file) |> File.read!() |> JSON.decode!() |> Map.fetch!("files")

    actual = dir |> read_dir!() |> Map.new(fn {path, bytes} -> {path, sha256_hex(bytes)} end)

    added = for {path, _} <- actual, not is_map_key(expected, path), do: {:added, path}
    removed = for {path, _} <- expected, not is_map_key(actual, path), do: {:removed, path}

    changed =
      for {path, hex} <- actual, is_map_key(expected, path), expected[path] != hex do
        {:changed, path}
      end

    Enum.sort(added ++ removed ++ changed)
  end

  @doc """
  `:absent` when `dir` has no `MANIFEST.json` (the catalog has not been captured
  yet), else `{:present, verify_manifest(dir)}`.
  """
  @spec committed_status(Path.t()) :: :absent | {:present, diff()}
  def committed_status(dir \\ out_dir(:before)) do
    if File.exists?(Path.join(dir, @manifest_file)),
      do: {:present, verify_manifest(dir)},
      else: :absent
  end

  defp sha256_hex(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  # -- privacy -----------------------------------------------------------------

  @doc """
  Scans catalog text for leaks. `files` is `%{path => text}`; the result is a
  sorted list of `{kind, path}` findings, `[]` when clean.

  Kinds: `:home_path`, `:windows_profile`, `:private_var_path`, `:file_url`,
  `:email` (any domain not ending `.test`), `:secret_key_base`, `:signing_salt`
  and `:csrf_token_value` (a csrf-keyed value that is not the `{{CSRF}}`
  placeholder). It is the Phase 259 source-pin text rule set plus the three
  catalog-specific rules; there is no allowlist, so a clean result is never
  obtained by weakening it. Personal names and the maintainer address cannot be
  written into test source; the phase gate derives them at run time instead.
  """
  @spec privacy_violations(%{String.t() => String.t()}) :: [{atom(), String.t()}]
  def privacy_violations(files) when is_map(files) do
    for({path, text} <- files, kind <- text |> text_kinds() |> Enum.uniq(), do: {kind, path})
    |> Enum.sort()
  end

  # Built at call time, never stored in module attributes, so the home-directory
  # prefixes stay fragment-built.
  defp text_kinds(text) do
    name = ~S{[^/\s"'<>]+}

    rules = [
      {:home_path, Regex.compile!(Regex.escape(@users_dir) <> name)},
      {:home_path, Regex.compile!(Regex.escape(@home_dir) <> name)},
      {:windows_profile,
       Regex.compile!(~S{[A-Za-z]:[\\/]+} <> "Users" <> ~S{[\\/]+[^\\/\s"'<>]+}, "i")},
      {:private_var_path, ~r{/private/var/}},
      {:file_url, ~r{file:///\S}},
      {:secret_key_base, ~r/secret_key_base/i},
      {:signing_salt, ~r/signing_salt/i},
      {:csrf_token_value,
       ~r/name="_?csrf[-_]token"[^>]*?(?:value|content)="(?!\{\{CSRF\}\})[^"]{8,}"/},
      {:csrf_token_value,
       ~r/(?:value|content)="(?!\{\{CSRF\}\})[^"]{8,}"[^>]*?name="_?csrf[-_]token"/},
      {:csrf_token_value,
       ~r/csrf[-_]?token["']?\s*[:=]\s*["']?(?!\{\{CSRF\}\})[A-Za-z0-9_+\/=-]{16,}/i}
    ]

    for({kind, regex} <- rules, Regex.match?(regex, text), do: kind) ++ email_kinds(text)
  end

  defp email_kinds(text) do
    ~r/[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})/
    |> Regex.scan(text)
    |> Enum.reject(fn [_, domain] -> String.ends_with?(String.downcase(domain), ".test") end)
    |> Enum.map(fn _ -> :email end)
  end
end
