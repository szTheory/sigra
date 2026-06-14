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
    offenders =
      Path.wildcard("#{@installer_template_root}/**/*")
      |> Enum.filter(&String.contains?(&1, "design"))

    assert offenders == [],
           "Design gallery artifacts found in installer template tree (D-04 violation):\n" <>
             Enum.join(offenders, "\n")
  end
end
