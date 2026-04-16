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

  # Base fixture binding — feature-flag fields are overridden per
  # binding variant below to gather files/1 across every flag combo.
  @base_binding [
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
    organizations?: true,
    adapter: :postgres,
    reset_password_url: "http://localhost:4000/users/reset-password",
    settings_url: "http://localhost:4000/users/settings",
    opts: [],
    migration_timestamps: %{}
  ]

  # Every binding variant the installer can produce. files/1 is
  # conditional on :live / :api / :jwt for Features.Core, so we gather
  # the union of files/1 across all combinations and assert every
  # on-disk template is owned by AT LEAST ONE variant.
  @binding_variants for live <- [true, false],
                        api <- [true, false],
                        jwt <- [true, false],
                        mfa <- [true, false],
                        oauth <- [true, false],
                        do:
                          Keyword.merge(@base_binding,
                            live: live,
                            api: api,
                            jwt: jwt,
                            opts: [live: live, api: api, jwt: jwt, mfa: mfa, oauth: oauth]
                          )

  # Templates read by Features.*.injections/1 via read_template!/1.
  # Whitelisted here because they are NOT returned by files/1 — they
  # become injection *content*, not standalone generated files.
  @injection_whitelist %{
    Sigra.Install.Features.Core => [],
    Sigra.Install.Features.Organizations => [
      "organizations/router_injection.ex"
    ],
    Sigra.Install.Features.Passkeys => []
  }

  # Pre-existing orphan templates that exist on disk but are NOT yet
  # registered in their Feature's files/1. These predate Phase 24 and
  # are out of scope for this repair phase:
  #
  # - Features.Core orphans (8 files): Phase 8 lifecycle templates are
  #   generated via Sigra.Install.Injector.lifecycle_template_files/0
  #   and Phase 11 api_token templates are referenced from
  #   post_instructions but not from files/1 with the expected
  #   binding-variant flags. Both gaps predate the Feature manifest
  #   migration.
  #
  # - Features.Organizations orphans (4 files): the v1.1 organization
  #   schemas were created in Phase 13 but never wired into
  #   Features.Organizations.files/1 when Phase 18 Wave 1 populated
  #   the manifest.
  #
  # The test still catches NEW drift — any orphan that is NOT in this
  # allowlist fails immediately. New plans that wire these templates
  # in must shrink @known_drift accordingly.
  # @known_drift keeps Sigra.Install.Features.Passkeys tightly scoped to [].
  @known_drift %{
    Sigra.Install.Features.Core => [
      "core/api_token_controller.ex",
      "core/api_token_created_email.ex",
      "core/auth_api_token.ex",
      "core/auth_hooks.ex",
      "core/mfa_settings_html.ex",
      "core/registration_html.ex",
      "core/token_controller.ex",
      "core/user_api_token.ex",
      # Phase 24.1: cross-feature ownership. This template lives under
      # priv/templates/sigra.install/core/ alongside the other audit_events
      # migrations, but it is owned by a later feature's files/1 +
      # migrations/1 because it adds a hard FK to the organizations table
      # and must be skipped under --no-organizations. Listed here to
      # preserve the "every file has an owner" invariant without teaching
      # the coverage lint to chase cross-feature ownership.
      "core/alter_audit_events_add_org_columns.exs"
    ],
    Sigra.Install.Features.Organizations => [
      # Phase 24.1: on_mount clause was moved from an injection-fragment
      # template into core/user_auth.ex directly (gated on
      # `<%= if organizations? do %>`) to avoid the `clauses with the
      # same name and arity should be grouped together` compile warning
      # that --warnings-as-errors escalated. The fragment file remains on
      # disk as an orphan reference; it is not injected or generated.
      "organizations/user_auth_on_mount_assign_user_organizations.ex",
      # Phase 24 D-04.1/.2: reference-only fragment mirroring the canonical
      # organization_invitation/4 inlined into core/emails.ex. Intentionally
      # NOT registered in files/1 — the fragment uses bare `@font_family`
      # and `<%= app_name %>` interpolation that only resolve inside the
      # host emails.ex module, so copying it breaks
      # `mix compile --warnings-as-errors` with
      # `(ArgumentError) cannot invoke @/1 outside module`. See
      # lib/sigra/install/features/organizations.ex for the explicit
      # non-registration rationale. This entry is NOT pending future
      # repair — the fragment is meant to stay reference-only.
      "organizations/organization_invitation_email.ex"
    ],
    Sigra.Install.Features.Passkeys => []
  }

  @features [
    {Sigra.Install.Features.Core, "core"},
    {Sigra.Install.Features.Organizations, "organizations"},
    {Sigra.Install.Features.Passkeys, "passkeys"}
  ]

  for {feature, subdir} <- @features do
    @feature feature
    @subdir subdir

    test "every file under #{@subdir}/ is owned by #{inspect(@feature)}" do
      on_disk =
        Path.wildcard(Path.join([@template_root, @subdir, "**", "*.{ex,exs}"]))
        |> Enum.map(&Path.relative_to(&1, @template_root))
        |> MapSet.new()

      # Union files/1 across every binding variant so flag-conditional
      # templates (api/jwt/live: true|false) are all considered owned.
      from_files =
        @binding_variants
        |> Enum.flat_map(&@feature.files/1)
        |> Enum.map(fn
          {:eex, source, _target} -> source
          {:text, source, _target} -> source
        end)
        |> MapSet.new()

      # Migrations are likewise unioned across variants. Migration tuples
      # use {_key, source, _target}; the source path may be relative to
      # @template_root (e.g. "core/foo.exs") or to the feature subdir.
      # Normalize defensively.
      from_migrations =
        @binding_variants
        |> Enum.flat_map(&@feature.migrations/1)
        |> Enum.map(fn {_key, source, _target} -> normalize(source) end)
        |> MapSet.new()

      from_whitelist = MapSet.new(Map.fetch!(@injection_whitelist, @feature))
      from_known_drift = MapSet.new(Map.fetch!(@known_drift, @feature))

      owned =
        from_files
        |> MapSet.union(from_migrations)
        |> MapSet.union(from_whitelist)
        |> MapSet.union(from_known_drift)

      orphans = MapSet.difference(on_disk, owned) |> MapSet.to_list() |> Enum.sort()

      assert orphans == [],
             "#{inspect(@feature)} has orphan templates under #{@subdir}/:\n" <>
               Enum.map_join(orphans, "\n", &"  - #{&1}") <>
               "\n\nEither register them in files/1, migrations/1, or add them to " <>
               "@injection_whitelist (for read_template!/1 templates) or " <>
               "@known_drift (for documented pre-existing orphans pending future repair)."
    end
  end

  # Migrations return tuples like `{:organizations, "organizations/migration.exs", "create_organizations.exs"}`
  # where the middle element is already relative to @template_root. Normalize defensively.
  defp normalize(path), do: Path.relative_to(path, ".")
end
