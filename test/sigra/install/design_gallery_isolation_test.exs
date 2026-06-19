defmodule Sigra.Install.DesignGalleryIsolationTest do
  @moduledoc """
  D-04 contract guard: asserts that no design gallery artifacts exist in the
  installer template tree.

  The design gallery (ExampleWeb.Admin.DesignGalleryLive) is example-only and
  must never be generated into host applications via `mix sigra.install`. This
  guard enforces the trust boundary between test/example/ and
  priv/templates/sigra.install/.

  Runs as a pure filesystem glob — no Postgres, no DB start required.
  Included in the default `mix test` suite (no @moduletag filtering).
  """
  use ExUnit.Case, async: true

  @installer_template_root "priv/templates/sigra.install"

  test "no design gallery artifact exists in installer template tree (D-04)" do
    # Precondition: guard against a false green if the template root is renamed,
    # missing, or the suite runs from the wrong CWD — Path.wildcard would return
    # [] and the assertion below would pass vacuously, silently disabling D-04.
    assert File.dir?(@installer_template_root),
           "installer template root #{@installer_template_root} not found — " <>
             "run from the repo root; D-04 guard cannot verify isolation"

    offenders =
      Path.wildcard("#{@installer_template_root}/**/*")
      |> Enum.filter(&String.contains?(&1, "design"))

    assert offenders == [],
           "Design gallery artifacts found in installer template tree (D-04 violation):\n" <>
             Enum.join(offenders, "\n")
  end
end
