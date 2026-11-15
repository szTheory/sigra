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
    * the tier-1 producers - pure renders of the eight library admin LiveViews
      with literal assigns (no database, no browser, no clock).
    * `write!/2` - the guarded writer for the `:after` catalog and, once, the
      committed `:before` catalog.

  Nothing here evaluates repo content beyond rendering library components with
  literal assigns. The writer is a local maintainer action:

      SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs

  It is requested only through `Sigra.Test.Brand.RegenGuard.requested?/3`, so it
  is refused when `CI` is `true`.
  """

  alias Sigra.Admin.Audit.Presenter
  alias Sigra.Admin.Live.UserShowLive
  alias Sigra.Admin.Scope
  alias Sigra.Test.Brand.RegenGuard

  @root Path.expand("../../..", __DIR__)
  @env_name "SIGRA_BRAND_CATALOG"
  @after_dir "tmp/catalog-after"
  @tier1_dir "tier1-library-admin"

  # Every lane directory the writer owns below an output directory.
  @lane_dirs [@tier1_dir]

  # Pinned data clock. Every data timestamp in a tier-1 literal is a constant on or
  # before this date; only wall-clock relative text is normalized.
  @registered_at ~U[2026-03-02 10:00:00Z]
  @confirmed_at ~U[2026-03-02 10:05:00Z]
  @last_active_at ~U[2026-05-14 08:12:00Z]
  @locked_at ~U[2026-05-13 17:45:00Z]
  @audit_at ~U[2026-05-14 08:12:30Z]

  # Fictional, readable personas. The UUIDs are literals, so every render of a state
  # is byte-stable; the normalizer maps them to `{{PERSONA:<key>}}` labels.
  @user_ids %{
    admin: "00000000-0000-4000-8000-000000000001",
    locked: "00000000-0000-4000-8000-000000000002"
  }

  @uuid ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/

  @type live :: module()
  @type state :: atom()
  @type entry :: {live(), state()}
  @type mode :: :before | :after

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
  def out_dir(:after), do: Path.join(@root, @after_dir)

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

  @doc "The `{live_module, state}` pairs rendered in tier 1, sorted."
  @spec tier1_states() :: [entry()]
  def tier1_states, do: Enum.sort([{UserShowLive, :locked}])

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
  def tier1_personas, do: Map.new(@user_ids, fn {key, id} -> {id, Atom.to_string(key)} end)

  defp tier1_assigns({UserShowLive, :locked}) do
    user = user(:locked, "locked.user@demo.tasklane.test", locked_at: @locked_at)

    %{
      admin_scope: admin_scope(),
      current_scope: %{},
      return_to: "/admin/users",
      detail:
        detail(user,
          sessions: [session(:standard, "203.0.113.24", @last_active_at, <<1, 2, 3, 4>>)],
          recent_audit: audit_rows(user, [{"auth.lockout.locked", "failure"}])
        )
    }
  end

  # -- literal data builders --------------------------------------------------

  defp admin_scope do
    admin = user(:admin, "admin@demo.tasklane.test", [])

    %Scope{
      mode: :global,
      scope: %{user: admin},
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  defp user(key, email, attrs) do
    Map.merge(
      %{
        id: Map.fetch!(@user_ids, key),
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

  # Presenter-shaped audit rows, built by the real presenter from literal events so
  # label and badge wording is whatever the shipped presenter says.
  defp audit_rows(user, actions) do
    events =
      actions
      |> Enum.with_index(1)
      |> Enum.map(fn {{action, outcome}, index} ->
        %{
          id: "00000000-0000-4000-8000-0000000000a#{index}",
          inserted_at: @audit_at,
          action: action,
          outcome: outcome,
          actor_id: user.id,
          effective_user_id: user.id,
          target_id: user.id
        }
      end)

    Presenter.present(events, %{user.id => user})
  end

  # -- writer -----------------------------------------------------------------

  @doc """
  Builds the catalog as `%{relative_path => bytes}`: tier 1 only until raw inputs
  are ingested.
  """
  @spec build(keyword()) :: %{String.t() => String.t()}
  def build(_opts \\ []), do: tier1_files()

  @doc """
  Writes the catalog for `mode` under the output directory and returns
  `%{dir: dir, files: sorted_relative_paths}`.

  The write is opt-in: `env` (default: the process environment) must set
  `SIGRA_BRAND_CATALOG` to `"after"`. Permission is read only through
  `Sigra.Test.Brand.RegenGuard.requested?/3`, which raises under `CI=true`, so a
  stray exported variable cannot rewrite a committed fixture.

  Options: `:env`, `:out_dir` (default `out_dir(mode)`).
  """
  @spec write!(mode(), keyword()) :: %{dir: Path.t(), files: [String.t()]}
  def write!(:after = mode, opts \\ []) do
    env = Keyword.get_lazy(opts, :env, &RegenGuard.environment/0)
    value = Atom.to_string(mode)

    unless RegenGuard.requested?(@env_name, value, env) do
      raise ArgumentError,
            "#{@env_name}=#{value} is not set. The catalog writer is opt-in; run: " <>
              regen_command(mode)
    end

    dir = Keyword.get(opts, :out_dir, out_dir(mode))
    files = build(opts)

    # Only directories this module owns are cleared, so a stale file from a removed
    # state cannot linger and an unrelated file in `dir` is never touched.
    for lane <- @lane_dirs, do: File.rm_rf!(Path.join(dir, lane))

    for {path, bytes} <- files do
      target = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, bytes)
    end

    %{dir: dir, files: files |> Map.keys() |> Enum.sort()}
  end

  @doc """
  Runs the writer for whichever mode the environment requests, or does nothing.

  Called from `setup_all` in the catalog test so a maintainer's
  `SIGRA_BRAND_CATALOG=after mix test ...` writes before any test reads the output.
  """
  @spec write_if_requested!(keyword()) :: :ok
  def write_if_requested!(opts \\ []) do
    env = Keyword.get_lazy(opts, :env, &RegenGuard.environment/0)

    case Enum.find([:after], &RegenGuard.requested?(@env_name, Atom.to_string(&1), env)) do
      nil -> :ok
      mode -> mode |> write!(Keyword.put(opts, :env, env)) |> then(fn _ -> :ok end)
    end
  end
end
