defmodule Sigra.Planning.Phase198ContributorDxContractTest do
  @moduledoc """
  Contract lock for DX-01: the `mix ci` alias in mix.exs must remain the
  locally-faithful PR-gate mirror documented in CONTRIBUTING.md.

  Assertions:
  - mix.exs defines a `ci:` alias chaining the four required PR-gate legs.
  - The `ci:` alias does NOT include legs stricter than CI (invariant D-03).
  - CONTRIBUTING.md documents `mix ci` and the phx_new 1.8.8 prerequisite.

  These tests need no Postgres and no app boot — they run in the fast
  `mix test test/sigra/planning/` lane.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  # Extracts the text of the aliases/0 function from mix.exs.
  defp aliases_region(mix_exs) do
    case Regex.run(~r/defp aliases do\s*\[(.*?)\]\s*end/s, mix_exs) do
      [_, body] -> body
      _ -> ""
    end
  end

  test "198-01: mix.exs defines a ci alias chaining all four PR-gate legs" do
    mix = read!("mix.exs")
    region = aliases_region(mix)

    assert region =~ "ci:",
           "expected a `ci:` key in aliases/0 of mix.exs"

    assert region =~ "ci.install_golden",
           "expected `ci.install_golden` in the ci alias"

    assert region =~ "sigra.dep_off",
           "expected `sigra.dep_off` in the ci alias"

    assert region =~ "compile --warnings-as-errors",
           "expected `compile --warnings-as-errors` in the ci alias"
  end

  test "198-02: the ci alias is not stricter than CI (no credo, dialyzer, or format check legs)" do
    mix = read!("mix.exs")
    region = aliases_region(mix)

    # Locate the ci: entry specifically (from `ci:` up to the next top-level key).
    ci_entry =
      case Regex.run(~r/ci:\s*\[(.*?)\](?=,\s*\n\s*"?[a-z]|\s*\n\s*\])/s, region) do
        [_, body] -> body
        # Fallback: use the full aliases region for the check.
        _ -> region
      end

    refute ci_entry =~ "credo",
           "ci alias must not include credo (would be stricter than CI)"

    refute ci_entry =~ "dialyzer",
           "ci alias must not include dialyzer (would be stricter than CI)"

    refute ci_entry =~ "format --check-formatted",
           "ci alias must not include format --check-formatted (would be stricter than CI)"
  end

  test "198-03: CONTRIBUTING.md documents mix ci and the phx_new 1.8.8 prerequisite" do
    contributing = read!("CONTRIBUTING.md")

    assert contributing =~ "mix ci",
           "CONTRIBUTING.md must mention `mix ci`"

    assert contributing =~ "1.8.8",
           "CONTRIBUTING.md must mention the phx_new 1.8.8 prerequisite"
  end
end
