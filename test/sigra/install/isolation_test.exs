defmodule Sigra.Install.IsolationTest do
  @moduledoc """
  V-ISOLATION-01: Pitfall X-1 / X-3 boundary enforcement.

  `Sigra.Install.Features.Core` and every template under
  `priv/templates/sigra.install/core/` must contain zero references
  to future-feature symbols (`Features.Organizations`,
  `Features.Passkeys`, `Features.Admin`, `UserPasskey`,
  `OrganizationMembership`, `AdminUser`, etc.). This is what makes
  `mix sigra.install --no-organizations` compile cleanly even when
  future phases have not yet shipped those features.

  Docstring content is stripped before scanning — the moduledoc of
  `Features.Core` *should* explain the isolation invariant by name
  (that's literally its documented contract); what we're checking
  is that no executable code references a future feature symbol.
  """
  use ExUnit.Case, async: true

  @moduletag :isolation

  @forbidden_symbols [
    "Features.Organizations",
    "Features.Passkeys",
    "Features.Admin",
    "OrganizationMembership",
    "OrganizationInvitation",
    "UserPasskey",
    "AdminUser",
    "Sigra.Passkeys",
    "Sigra.Organizations"
  ]

  # Passkey wiring lives in core templates behind `<%= if passkeys? do %>` so
  # `--no-passkeys` omits those branches at render time; the source still
  # names `UserPasskey` / `Sigra.Passkeys`. Cross-feature *installer* coupling
  # is what we ban — not the host passkey API surface itself.
  @forbidden_template_symbols @forbidden_symbols -- ["UserPasskey", "Sigra.Passkeys"]

  describe "lib/sigra/install/features/core.ex (source)" do
    test "has no forbidden future-feature references in executable code" do
      source = File.read!("lib/sigra/install/features/core.ex")
      code = strip_docstrings(source)

      Enum.each(@forbidden_symbols, fn symbol ->
        refute code =~ symbol,
               "Features.Core executable code contains forbidden reference to " <>
                 "#{inspect(symbol)} — Core must not know about other features " <>
                 "(Pitfall X-1). Docstring references are allowed and stripped " <>
                 "before this scan, so this failure means the symbol is in real code."
      end)
    end
  end

  # Per D-23, scope.ex contains forward-declared references to Organization
  # and OrganizationMembership so its typespec is real (not `struct()`).
  # Phase 18 will add conditionality for `--no-organizations`; until then,
  # scope.ex is the documented exception to the core isolation rule.
  @file_symbol_exceptions %{
    "scope.ex" => ["OrganizationMembership"],
    "auth_fixtures.ex" => ["OrganizationMembership"]
  }

  describe "priv/templates/sigra.install/core/*" do
    test "every template has no forbidden future-feature references" do
      template_dir = "priv/templates/sigra.install/core"

      template_dir
      |> File.ls!()
      |> Enum.each(fn filename ->
        path = Path.join(template_dir, filename)
        content = File.read!(path)

        allowed = Map.get(@file_symbol_exceptions, filename, [])
        forbidden = @forbidden_template_symbols -- allowed

        Enum.each(forbidden, fn symbol ->
          refute content =~ symbol,
                 "Template #{filename} contains forbidden reference to " <>
                   "#{inspect(symbol)} — core/ templates must compile with no " <>
                   "other features enabled (Pitfall X-3: conditional template leakage)."
        end)
      end)
    end

    test "contains exactly 56 templates" do
      # Phase 92 / Plan 92-02: +1 (core/sigra_authz.ex), the host-owned
      # `Sigra.Authz` starter wired into Features.Core.files/1.
      # Phase 93 / Plan 93-03: +1 (core/oauth_token_controller.ex),
      # the RFC 6749 §4.4 client_credentials grant controller, gated
      # on `--jwt --organizations` (D-93-18).
      # Phase 97/98: +5 webhook templates/migration in core.
      files = File.ls!("priv/templates/sigra.install/core")
      assert length(files) == 56
    end
  end

  # Strips heredoc-based doc attributes so symbol checks target
  # executable code only. Features.Core's moduledoc intentionally
  # names the forbidden symbols to explain the isolation contract —
  # we do not want that documentation to be a test failure.
  defp strip_docstrings(source) do
    source
    |> String.replace(~r/@moduledoc\s+"""[\s\S]*?"""/m, "")
    |> String.replace(~r/@doc\s+"""[\s\S]*?"""/m, "")
  end
end
