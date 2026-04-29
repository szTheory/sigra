defmodule Sigra.Install.AuthzTemplateTest do
  @moduledoc """
  Phase 92 / B2B-02 (Plan 92-02) regression guard for the generated
  host-owned `Sigra.Authz` starter.

  Asserts that the install generator emits a host-owned authz module
  alongside the admin-policy stub. The generated starter:

    * declares `@behaviour Sigra.Authz`
    * implements `can?/3` returning `true` for every input (current
      roadmap contract — Plan 92-04 walks hosts to deny-by-default)
    * is registered in `Sigra.Install.Features.Core.files/1` so a fresh
      `mix sigra.install` writes it under `lib/<otp_app>/sigra_authz.ex`
    * mirrors the existing admin-policy stub posture so reviewers see
      the seam in the same place every time
  """
  use ExUnit.Case, async: true

  @moduletag :install

  @template_path Path.expand(
                   "../../../priv/templates/sigra.install/core/sigra_authz.ex",
                   __DIR__
                 )

  describe "generated host authz template" do
    test "exists on disk under priv/templates/sigra.install/core/sigra_authz.ex" do
      assert File.exists?(@template_path),
             """
             Phase 92 / Plan 92-02: the generator must emit a host-owned
             Sigra.Authz starter. Expected template at:

                 #{@template_path}

             The file should mirror priv/templates/sigra.install/admin/policy.ex
             in posture: a tiny @behaviour-implementing stub the host owns.
             """
    end

    test "declares @behaviour Sigra.Authz on the host-owned starter module" do
      source = File.read!(@template_path)

      assert source =~ "@behaviour Sigra.Authz",
             """
             The generated authz module must declare `@behaviour Sigra.Authz`
             so static analysis (and the host's own readers) can see the
             contract. Without this line the seam is invisible at the host.
             """
    end

    test "implements can?/3 returning true for every input (current roadmap contract)" do
      source = File.read!(@template_path)

      # The starter is allow-all so installed hosts compile and behave
      # identically to today's "no library defaults" world. Plan 92-04
      # walks hosts to deny-by-default semantics; until then, returning
      # `true` is the explicit contract documented in the moduledoc.
      assert source =~ ~r/def can\?\(\s*[a-z_]+\s*,\s*[a-z_]+\s*,\s*[a-z_]+\s*\)\s*do/,
             """
             The generated authz module must implement `can?/3` taking
             three positional arguments (action, subject, scope). Got:

                 #{Regex.run(~r/def can\?\([^)]*\)/, source) |> inspect()}
             """

      # The body must literally evaluate to `true` — not a guard, not a
      # fall-through, not a delegation. The host can edit later but the
      # generator-emitted starter is allow-all.
      assert source =~ ~r/def can\?\([^)]*\)\s*do\s*[^\n]*\n(?:[^d][^e][^f]?[^\n]*\n)*?\s*true\s*\n\s*end/,
             """
             The generated `can?/3` must return `true`. Plan 92-02 ships
             the seam as allow-all so installed hosts behave identically
             to today's no-defaults world; Plan 92-04 walks hosts to
             deny-by-default. If you change the starter to deny-by-default
             before Plan 92-04 lands, you break the migration guarantee.
             """
    end

    test "documents that this is a host-owned starter the recipe will harden" do
      source = File.read!(@template_path)

      # Mirrors the admin-policy stub's posture: the moduledoc tells the
      # reader the file is theirs and points at the deny-by-default recipe.
      assert source =~ "@moduledoc",
             "generated authz module must have a moduledoc"

      assert source =~ "host" or source =~ "Host",
             "moduledoc must call out that the file is host-owned"

      assert source =~ ~r/Phase 92|Plan 92-04|deny-by-default/,
             """
             The moduledoc must reference the Phase 92 seam contract or the
             Plan 92-04 deny-by-default recipe so the reader knows where
             to go to harden the starter.
             """
    end
  end

  describe "feature registration" do
    test "Sigra.Install.Features.Core.files/1 registers the authz template under lib/<otp_app>/sigra_authz.ex" do
      binding = [
        otp_app: :my_app,
        web_module: "MyAppWeb",
        app_module: "MyApp",
        context_module: "MyApp.Accounts",
        context_alias: "Accounts",
        schema_module: "MyApp.Accounts.User",
        schema_alias: "User",
        repo_module: "MyApp.Repo",
        binary_id: true,
        opts: [live: true, api: false, jwt: false, mfa: true, oauth: true]
      ]

      tuples = Sigra.Install.Features.Core.files(binding)

      sources = Enum.map(tuples, fn {:eex, src, _} -> src end)
      targets = Enum.map(tuples, fn {:eex, _src, t} -> t end)

      assert "core/sigra_authz.ex" in sources,
             """
             Sigra.Install.Features.Core.files/1 must register the
             core/sigra_authz.ex template so a fresh `mix sigra.install`
             emits the host-owned authz starter. Today the generator
             emits no host authz file at all, leaving Plan 92-04 with
             no anchor to walk hosts forward from.

             Sources returned: #{inspect(sources)}
             """

      assert "lib/my_app/sigra_authz.ex" in targets,
             """
             The generated authz module must land at
             `lib/<otp_app>/sigra_authz.ex` so it sits beside
             `lib/<otp_app>/sigra_admin_policy.ex` (the matching stub).
             Symmetrical placement makes the two host-owned policy
             modules discoverable as a pair.

             Targets returned: #{inspect(targets)}
             """
    end

    test "Features.Core source code references the sigra_authz template (grep anchor)" do
      core_source = File.read!("lib/sigra/install/features/core.ex")

      assert core_source =~ "sigra_authz",
             """
             The string "sigra_authz" must appear in
             lib/sigra/install/features/core.ex so the plan's verify
             grep anchors a stable reference. Without this the install
             walker won't pick up the new template.
             """
    end
  end
end
