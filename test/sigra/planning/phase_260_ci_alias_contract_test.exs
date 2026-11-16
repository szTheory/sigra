defmodule Sigra.Planning.Phase260CiAliasContractTest do
  use ExUnit.Case, async: true

  # Phase 260 (BGEN-05 / owner decision #13): the two shipped-CSS guards must run
  # inside the `ci` mix alias, which is what the PR-required Library tests shard
  # executes (`MIX_ENV=test mix ci`). A guard with no caller protects nothing, and a
  # guard that runs after the test steps reports its failure late. This pins both
  # the entries and their position, as string assertions over the raw mix.exs text
  # (no Code.eval of mix.exs, following the phase_230 string-contract idiom).
  @mix_path "mix.exs"

  @conformance "cmd bash scripts/ci/admin-css-conformance.sh"
  @completeness "cmd bash scripts/ci/admin-token-completeness.sh"
  @before_marker "compile --warnings-as-errors"
  @after_marker "test --exclude scaffold"

  @twins [
    "scripts/ci/admin-css-conformance.test.sh",
    "scripts/ci/admin-token-completeness.test.sh"
  ]

  # Returns the string entries of the `<alias_name>: [ ... ]` alias list from mix.exs
  # text, in source order. Pure (takes the source, reads no file) so a planted source
  # can be fed through the exact same extraction and assertion path as the real one.
  # Comment lines inside the list are dropped so a comment that merely mentions a
  # command is never mistaken for an entry.
  defp alias_entries(source, alias_name) do
    # Indent-agnostic and quote-tolerant: `ci: [` and `"ci.install_golden": [` both match,
    # and `ci: [` cannot match inside `"ci.install_golden": [`.
    case Regex.run(
           ~r/^[ ]*"?#{Regex.escape(alias_name)}"?: \[\n(.*?)^[ ]*\],?$/ms,
           source,
           capture: :all_but_first
         ) do
      [body] ->
        ~r/"((?:[^"\\]|\\.)*)"/
        |> Regex.scan(
          body
          |> String.split("\n")
          |> Enum.reject(&(&1 |> String.trim_leading() |> String.starts_with?("#")))
          |> Enum.join("\n"),
          capture: :all_but_first
        )
        |> List.flatten()

      nil ->
        []
    end
  end

  # The single assertion helper both the real-source test and the planted control use.
  # Returns :ok or {:error, reason} so the control can assert the failure instead of
  # raising out of the test.
  defp check_alias(entries) do
    idx = fn entry -> Enum.find_index(entries, &(&1 == entry)) end

    cond do
      idx.(@conformance) == nil ->
        {:error, "ci alias lacks `#{@conformance}`"}

      idx.(@completeness) == nil ->
        {:error, "ci alias lacks `#{@completeness}`"}

      idx.(@before_marker) == nil or idx.(@after_marker) == nil ->
        {:error, "ci alias lacks the `#{@before_marker}` or `#{@after_marker}` anchor"}

      idx.(@conformance) < idx.(@before_marker) or idx.(@completeness) < idx.(@before_marker) ->
        {:error, "a guard runs before `#{@before_marker}`"}

      idx.(@conformance) > idx.(@after_marker) or idx.(@completeness) > idx.(@after_marker) ->
        {:error, "a guard runs after `#{@after_marker}`, so its failure would be late"}

      Enum.any?(entries, fn entry -> Enum.any?(@twins, &String.contains?(entry, &1)) end) ->
        {:error,
         "a .test.sh self-test twin is in the ci alias (Test G fails on a dirty tracked tree)"}

      true ->
        :ok
    end
  end

  test "the ci alias runs both CSS guards after compile and before the test steps" do
    entries = alias_entries(File.read!(@mix_path), "ci")

    assert entries != [], "could not extract the `ci:` alias entries from #{@mix_path}"
    assert check_alias(entries) == :ok
  end

  test "the .test.sh self-test twins are not in the ci alias" do
    entries = alias_entries(File.read!(@mix_path), "ci")

    assert entries != [], "could not extract the `ci:` alias entries from #{@mix_path}"

    for twin <- @twins do
      refute Enum.any?(entries, &String.contains?(&1, twin)),
             "#{twin} must stay a separately run self-test, not a ci alias entry"
    end
  end

  test "alias_entries/2 reads the sibling aliases independently of ci" do
    source = File.read!(@mix_path)

    assert alias_entries(source, "ci.install_golden") != []
    assert @conformance not in alias_entries(source, "ci.install_golden")
  end

  describe "planted controls (the assertion helper must be able to fail)" do
    @planted_without_guards """
        defp aliases do
          [
            ci: [
              "format --check-formatted",
              "compile --warnings-as-errors",
              "test --exclude scaffold",
              "sigra.dep_off"
            ],
            other: ["noop"]
          ]
        end
    """

    @planted_guards_late """
        defp aliases do
          [
            ci: [
              "compile --warnings-as-errors",
              "test --exclude scaffold",
              "cmd bash scripts/ci/admin-css-conformance.sh",
              "cmd bash scripts/ci/admin-token-completeness.sh"
            ],
          ]
        end
    """

    @planted_commented_only """
        defp aliases do
          [
            ci: [
              "compile --warnings-as-errors",
              # "cmd bash scripts/ci/admin-css-conformance.sh"
              # "cmd bash scripts/ci/admin-token-completeness.sh"
              "test --exclude scaffold"
            ],
          ]
        end
    """

    @planted_twin_wired """
        defp aliases do
          [
            ci: [
              "compile --warnings-as-errors",
              "cmd bash scripts/ci/admin-css-conformance.sh",
              "cmd bash scripts/ci/admin-token-completeness.sh",
              "cmd bash scripts/ci/admin-css-conformance.test.sh",
              "test --exclude scaffold"
            ],
          ]
        end
    """

    @planted_ok """
        defp aliases do
          [
            ci: [
              "compile --warnings-as-errors",
              "cmd bash scripts/ci/admin-css-conformance.sh",
              "cmd bash scripts/ci/admin-token-completeness.sh",
              "test --exclude scaffold"
            ],
          ]
        end
    """

    test "a source without the guard entries is rejected" do
      entries = alias_entries(@planted_without_guards, "ci")

      assert entries != []
      assert {:error, reason} = check_alias(entries)
      assert reason =~ "lacks"
    end

    test "guards placed after the test steps are rejected" do
      assert {:error, reason} = check_alias(alias_entries(@planted_guards_late, "ci"))
      assert reason =~ "after"
    end

    test "a comment that only mentions the guard commands is not an entry" do
      assert {:error, reason} = check_alias(alias_entries(@planted_commented_only, "ci"))
      assert reason =~ "lacks"
    end

    test "a .test.sh twin wired into the alias is rejected" do
      assert {:error, reason} = check_alias(alias_entries(@planted_twin_wired, "ci"))
      assert reason =~ "twin"
    end

    test "the well-formed planted source is accepted (the control is not vacuous)" do
      assert check_alias(alias_entries(@planted_ok, "ci")) == :ok
    end
  end
end
