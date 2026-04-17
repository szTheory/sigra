defmodule Sigra.Templates.GeneratorEmissionAuditTest do
  @moduledoc """
  Generator emission audit (Phase 35 / ROADMAP SC1).

  Every `<%= web_module %>.…` reference in `priv/templates/sigra.install/**/*.ex`
  must correspond to a module surface that Sigra’s install features actually emit:
  the derived template path fragment must appear in **at least one** `{:eex, tmpl, _}`
  tuple returned by `files/1` on **some** feature (`Core`, `Admin`, `Organizations`,
  `Passkeys`), using the same canonical binding shape as the feature unit tests.

  ## Path derivation

  - Parse the dotted suffix after `<%= web_module %>.` (e.g. `Admin.ImpersonationController`,
    `Auth.SessionLive`, `UserAuth`).
  - Build `rel` by joining underscored suffix segments with `/` and appending `.ex`
    (e.g. `admin/impersonation_controller.ex`, `auth/session_live.ex`).
  - Build `last = underscore(last_segment) <> ".ex"` (e.g. `session_live.ex`).
  - A reference is **covered** if any emitted template path `tmpl` from the four
    features’ `files/1` lists satisfies:
    `String.ends_with?(tmpl, last)` **or** `String.contains?(tmpl, rel)`.

  This catches “template mentions `ExampleWeb.SomeLive` but no feature lists the
  backing `.ex` template” drift (INT-01 / INT-02 / INT-03 class).

  ## Host-only allowlist

  References to Phoenix / host scaffolding that Sigra does **not** emit as installer
  templates (`Layouts`, `Endpoint`, `PubSub`, `ErrorHTML`, `Gettext`) are skipped —
  they are still validated indirectly by the host app and other tests.
  """

  use ExUnit.Case, async: true

  alias Sigra.Install.Features.{Admin, Core, Organizations, Passkeys}

  @repo_root Path.expand("../../..", __DIR__)

  # Stop before the first `.lowercase…` segment so docstrings like
  # `<%= web_module %>.UserAuth.begin_impersonation/4` only record the module chain.
  @web_module_ref ~r/<%= web_module %>\.((?:[A-Z][A-Za-z0-9_]*)(?:\.[A-Z][A-Za-z0-9_]*)*)/

  @host_only_suffixes MapSet.new([
                          "Layouts",
                          "Endpoint",
                          "PubSub",
                          "ErrorHTML",
                          "Gettext"
                        ])

  defp canonical_binding do
    [
      otp_app: :example,
      app_module: "Example",
      app_name: "Example",
      web_module: "ExampleWeb",
      context_module: "Example.Accounts",
      context_alias: "Accounts",
      schema_module: "Example.Accounts.User",
      schema_alias: "User",
      table_name: "users",
      repo_module: "Example.Repo",
      from_email: "noreply@example.com",
      log_in_url: "/users/log_in",
      reset_password_url: "http://localhost:4000/users/reset-password",
      settings_url: "http://localhost:4000/users/settings",
      binary_id: true,
      adapter: :postgres,
      opts: [live: true, api: false, jwt: false, binary_id: true]
    ]
  end

  defp all_feature_template_paths do
    # Union API/JWT-gated Core templates so `core/api_token_controller.ex` (on disk)
    # stays attributed even when the default canonical binding has `api: false`.
    base = canonical_binding()

    opts_expanded =
      base
      |> Keyword.get(:opts, [])
      |> Keyword.merge(api: true, jwt: true, live: true)

    expanded = Keyword.put(base, :opts, opts_expanded)

    opts_no_live =
      base
      |> Keyword.get(:opts, [])
      |> Keyword.merge(live: false, api: false, jwt: false)

    no_live = Keyword.put(base, :opts, opts_no_live)

    for binding <- [base, expanded, no_live],
        mod <- [Core, Admin, Organizations, Passkeys],
        {:eex, tmpl, _} <- mod.files(binding),
        into: MapSet.new(),
        do: tmpl
  end

  defp host_only?(suffix) do
    first = suffix |> String.split(".") |> hd()
    MapSet.member?(@host_only_suffixes, suffix) or MapSet.member?(@host_only_suffixes, first)
  end

  defp extra_path_hints(suffix) do
    case suffix |> String.split(".") |> List.last() do
      # Emitted as `core/error_handler.ex` → host `auth_error_handler.ex`
      "AuthErrorHandler" -> ["error_handler.ex"]
      # `core/login_html.ex` renders into `…/session_html.ex` on the host.
      "SessionHTML" -> ["login_html.ex", "session_html.ex"]
      # `PageLive` is a compile-time stub defined inside `user_auth.ex` (not a separate template).
      "PageLive" -> ["user_auth.ex"]
      _ -> []
    end
  end

  defp covered_by_emission?(suffix, template_paths) do
    if host_only?(suffix) do
      true
    else
      parts = String.split(suffix, ".")
      rel = parts |> Enum.map(&Macro.underscore/1) |> Path.join() |> Kernel.<>(".ex")
      last = parts |> List.last() |> Macro.underscore() |> Kernel.<>(".ex")
      hints = [last, rel] ++ extra_path_hints(suffix)

      Enum.any?(template_paths, fn t ->
        Enum.any?(hints, fn hint ->
          hint != "" and
            (String.ends_with?(t, hint) or String.contains?(t, hint))
        end)
      end)
    end
  end

  test "every <%= web_module %>.… reference is backed by a feature files/1 template" do
    templates_root = Path.join([@repo_root, "priv", "templates", "sigra.install"])
    assert File.dir?(templates_root)

    paths = all_feature_template_paths()
    refute MapSet.size(paths) == 0

    for path <- Path.wildcard(Path.join(templates_root, "**/*.ex")),
        String.ends_with?(path, ".ex"),
        content = File.read!(path),
        reduce: :ok do
      :ok ->
        for m <- Regex.scan(@web_module_ref, content) do
          [_, suffix] = m

          assert covered_by_emission?(suffix, paths),
                 """
                 Generator emission gap: `<%= web_module %>.#{suffix}` in #{Path.relative_to(path, @repo_root)}
                 is not covered by any template path in
                 Core|Admin|Organizations|Passkeys files/1 for the canonical binding.

                 If this references host-only Phoenix modules, add a precise allowlist
                 entry in #{__ENV__.file} (@host_only_suffixes).
                 """
        end

        :ok
    end
  end

  test "self-check: known emitted suffix resolves" do
    paths = all_feature_template_paths()
    assert covered_by_emission?("UserAuth", paths)
    assert covered_by_emission?("Admin.ImpersonationController", paths)
    refute covered_by_emission?("TotallyFakeSigraSurface", paths)
  end
end
