defmodule Sigra.Install.Features.CoverageTest do
  @moduledoc """
  D-06.2 regression guard for Phase 24.

  For each `Sigra.Install.Feature` module, walks the on-disk subtree
  under `priv/templates/sigra.install/<subdir>/` and asserts every
  file is "owned" — meaning it is either:

  1. Referenced by `feat.files/1` as `{:eex, source_path, _}` / `{:text, source_path, _}`, OR
  2. Referenced by `feat.migrations/1` as `{_key, source_path, _}`, OR
  3. On the explicit `@injection_whitelist` for that feature (templates
     read via `read_template!/1` from inside `feat.injections/1`).

  Prevents the drift class that caused DEF-18-02 (template orphaned
  on disk with no feature owner) and DEF-18-01 Failures 2 & 3
  (injection templates missing on disk).
  """
  use ExUnit.Case, async: true

  @moduletag :install

  @template_root "priv/templates/sigra.install"

  # Fixture binding — matches `Features.*.files/1` argument contract.
  @binding [
    otp_app: :fixture_app,
    web_module: "FixtureAppWeb",
    app_module: "FixtureApp",
    context_module: "FixtureApp.Accounts",
    context_alias: "Accounts",
    schema_module: "FixtureApp.Accounts.User",
    schema_alias: "User",
    table_name: "users",
    app_name: "FixtureApp",
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    repo_module: "FixtureApp.Repo",
    binary_id: true,
    live: true,
    api: false,
    jwt: false,
    organizations?: true,
    adapter: :postgres,
    reset_password_url: "http://localhost:4000/users/reset-password",
    settings_url: "http://localhost:4000/users/settings",
    opts: [],
    migration_timestamps: %{}
  ]

  # Templates read by Features.*.injections/1 via read_template!/1.
  # Whitelisted here because they are NOT returned by files/1 — they
  # become injection *content*, not standalone generated files.
  @injection_whitelist %{
    Sigra.Install.Features.Core => [],
    Sigra.Install.Features.Organizations => [
      "organizations/router_injection.ex",
      "organizations/user_auth_on_mount_assign_user_organizations.ex"
    ]
  }

  @features [
    {Sigra.Install.Features.Core, "core"},
    {Sigra.Install.Features.Organizations, "organizations"}
  ]

  for {feature, subdir} <- @features do
    @feature feature
    @subdir subdir

    test "every file under #{@subdir}/ is owned by #{inspect(@feature)}" do
      on_disk =
        Path.wildcard(Path.join([@template_root, @subdir, "**", "*.{ex,exs}"]))
        |> Enum.map(&Path.relative_to(&1, @template_root))
        |> MapSet.new()

      from_files =
        @feature.files(@binding)
        |> Enum.map(fn
          {:eex, source, _target} -> source
          {:text, source, _target} -> source
        end)
        |> MapSet.new()

      from_migrations =
        @feature.migrations(@binding)
        |> Enum.map(fn {_key, source, _target} -> normalize(source) end)
        |> MapSet.new()

      from_whitelist = MapSet.new(Map.fetch!(@injection_whitelist, @feature))

      owned = from_files |> MapSet.union(from_migrations) |> MapSet.union(from_whitelist)

      orphans = MapSet.difference(on_disk, owned) |> MapSet.to_list() |> Enum.sort()

      assert orphans == [],
             "#{inspect(@feature)} has orphan templates under #{@subdir}/:\n" <>
               Enum.map_join(orphans, "\n", &"  - #{&1}") <>
               "\n\nEither register them in files/1, migrations/1, or add them to " <>
               "@injection_whitelist in this test if they are read via read_template!/1."
    end
  end

  # Migrations return tuples like `{:organizations, "organizations/migration.exs", "create_organizations.exs"}`
  # where the middle element is already relative to @template_root. Normalize defensively.
  defp normalize(path), do: Path.relative_to(path, ".")
end
