defmodule Sigra.Install.ScopeTemplateInvariantsTest do
  use ExUnit.Case, async: true

  @template_path Path.expand(
    "../../../priv/templates/sigra.install/core/scope.ex",
    __DIR__
  )

  describe "reserved :impersonating_from field (D-11)" do
    test "source-level grep — template defstruct mentions impersonating_from: nil" do
      source = File.read!(@template_path)

      assert source =~ ~r/impersonating_from:\s*nil/,
        """
        The generated Scope template at #{@template_path} must reserve
        the :impersonating_from field for v1.2 impersonation support.

        See UPGRADE-v1.2.md at the project root for the contract. If
        you intentionally removed this field, you are about to break
        the v1.1 -> v1.2 upgrade path for every Sigra-generated app.
        """
    end

    test "compile-and-introspect — rendered Scope module struct has :impersonating_from key" do
      # Pre-compile dummy User/Organization/OrganizationMembership modules so
      # the rendered scope can resolve `alias TestApp.Accounts.User`, plus the
      # Organization/OrganizationMembership references added in D-23 (Phase 13).
      # See Pitfall 7 in 12-RESEARCH.md.
      Code.compile_string("defmodule TestApp.Accounts.User, do: defstruct([:id])")
      Code.compile_string("defmodule TestApp.Accounts.Organization, do: defstruct([:id])")

      Code.compile_string(
        "defmodule TestApp.Accounts.OrganizationMembership, do: defstruct([:id])"
      )

      # The scope template uses PLAIN bindings (`<%= context_module %>`),
      # NOT @assigns. See Pitfall 6 in 12-RESEARCH.md. Pass a plain
      # keyword list as the second argument to EEx.eval_file/2.
      rendered =
        EEx.eval_file(@template_path,
          context_module: "TestApp.Accounts",
          schema_alias: "User",
          # Phase 24.1: scope.ex template gates its Organization / OrganizationMembership
          # struct references on `<%= if organizations? do %>` so the
          # --no-organizations install path compiles. Render this test
          # with organizations? = true to exercise the default shape.
          organizations?: true
        )

      # Compile the rendered scope module and introspect its struct keys.
      [{mod, _bytecode} | _] = Code.compile_string(rendered)
      struct_keys = mod.__struct__() |> Map.keys()

      assert :impersonating_from in struct_keys,
        """
        The rendered Scope struct must contain :impersonating_from.
        Got keys: #{inspect(struct_keys)}.

        This field is reserved for v1.2 impersonation. See
        UPGRADE-v1.2.md at the project root for the contract.
        """
    end
  end
end
