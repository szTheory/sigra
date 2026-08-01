defmodule Sigra.Planning.Phase198ContributorDxContractTest do
  @moduledoc """
  Fail-closed DX-01 contract for the one contributor command and its PR owner.
  """

  use ExUnit.Case, async: true

  defp root, do: Path.expand("../../..", __DIR__)
  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()

  defp aliases_region(mix_exs) do
    case Regex.run(~r/defp aliases do\s*\[(.*?)\]\s*end/s, mix_exs) do
      [_, body] -> body
      _ -> flunk("missing aliases/0 body")
    end
  end

  defp ci_entry(mix_exs) do
    case Regex.run(~r/ci:\s*\[(.*?)\](?=,\s*\n\s*"?[a-z]|\s*\n\s*\])/s, aliases_region(mix_exs)) do
      [_, body] -> body
      _ -> flunk("missing ci alias entry")
    end
  end

  test "198-01: mix ci has the ordered seven-leg contributor gate exactly once" do
    entry = ci_entry(read!("mix.exs"))

    expected = [
      "format --check-formatted",
      "deps.get --check-locked",
      "deps.unlock --check-unused",
      "compile --warnings-as-errors",
      "test",
      "ci.install_golden",
      "sigra.dep_off"
    ]

    assert Enum.map(Regex.scan(~r/"([^"]+)"/, entry), fn [_, leg] -> leg end) == expected
    assert Enum.all?(expected, &(length(Regex.scan(~r/#{Regex.escape(&1)}/, entry)) == 1))
  end

  test "198-02: mix ci excludes non-gating tool families" do
    entry = ci_entry(read!("mix.exs"))

    refute entry =~ "credo"
    refute entry =~ "dialyzer"
    refute entry =~ "mix_audit"
  end

  test "198-03: formatter covers intended tests but excludes generated golden bytes" do
    formatter = read!(".formatter.exs")

    assert formatter =~ "test/{sigra,support,mix,fixtures}/**/*.{ex,exs}"
    refute formatter =~ "test/fixtures/install_golden/tree/**"
    refute formatter =~ "test/{sigra,support,mix,fixtures}/**/*.{ex,exs}"
  end

  test "198-04: library_tests_shard directly owns the one PR alias invocation" do
    workflow = read!(".github/workflows/ci.yml")
    shard = job_body(workflow, "library_tests_shard")

    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, workflow)) == 1
    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
