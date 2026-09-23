defmodule Sigra.Planning.Phase234ActionPinningContractTest do
  use ExUnit.Case, async: true

  @release_workflows [
    ".github/workflows/release-please.yml",
    ".github/workflows/hex-publish.yml"
  ]
  @release_please_path ".github/workflows/release-please.yml"
  @release_please_ref "45996ed1f6d02564a971a2fa1b5860e934307cf7"
  @forbidden_tag_object "0dfd8538845b8e92600d271a895a5372865d4062"
  @bare_uses_fixture "test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml"
  @dashed_uses_fixture "test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml"
  @composite_actions_glob ".github/actions/*/action.yml"
  @inventory_floor 16
  @pre_relaxation_inventory_pattern ~r/^\s*-\s+uses:\s+([^\s#]+)(?:\s+#\s*(.+))?\s*$/
  @inventory_pattern ~r/^\s*(?:-\s+)?uses:\s+([^\s#]+)(?:\s+#\s*(.+))?\s*$/

  test "release-critical workflows are an explicit, live universe" do
    assert @release_workflows == [
             ".github/workflows/release-please.yml",
             ".github/workflows/hex-publish.yml"
           ]

    for path <- @release_workflows do
      assert File.exists?(path),
             "release-critical workflow #{path} is missing from the repository"
    end
  end

  test "every third-party release action is immutable and version-annotated" do
    inventory = production_inventory()

    assert_inventory_floor!(inventory)

    assert_valid_inventory!(inventory)
  end

  test "composite action glob is a separate, non-empty universe" do
    composite_actions = discovered_composite_actions()

    assert composite_actions != [],
           "composite action glob #{@composite_actions_glob} returned no files; discovery broke, not the supply-chain surface"

    assert ".github/actions/example-playwright-boot/action.yml" in composite_actions
  end

  test "Release Please uses the reviewed dereferenced v5.0.0 commit" do
    workflow = File.read!(@release_please_path)

    assert workflow =~
             "uses: googleapis/release-please-action@#{@release_please_ref} # v5.0.0",
           "#{@release_please_path} must use the locked Release Please commit with its v5.0.0 comment"

    refute workflow =~ "googleapis/release-please-action@v5"
    refute workflow =~ @forbidden_tag_object
  end

  test "synthetic mutable or undocumented third-party actions fail with workflow and line diagnostics" do
    invalid_actions = [
      {"floating tag", "actions/checkout@v7 # v7.0.1", "non-immutable action ref"},
      {"short SHA", "actions/checkout@3d3c42e # v7.0.1", "non-immutable action ref"},
      {"uppercase SHA", "actions/checkout@3D3C42E5AAC5BA805825DA76410C181273BA90B1 # v7.0.1",
       "non-immutable action ref"},
      {"missing comment", "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
       "missing a same-line semantic version comment"},
      {"annotated tag object",
       "googleapis/release-please-action@#{@forbidden_tag_object} # v5.0.0",
       "annotated v5 tag object"}
    ]

    for {name, action, reason} <- invalid_actions do
      workflow_path = "synthetic/#{String.replace(name, " ", "-")}.yml"
      inventory = action_inventory("      - uses: #{action}\n", workflow_path)

      error =
        assert_raise ExUnit.AssertionError, fn ->
          assert_valid_inventory!(inventory)
        end

      assert error.message =~ workflow_path <> ":1"
      assert error.message =~ reason
    end
  end

  test "repository-local actions are deliberately outside third-party scope" do
    assert action_inventory(
             "      - uses: ./.github/actions/release-guard\n",
             "synthetic/local.yml"
           ) == []
  end

  test "bare uses references are inventoried and fail with fixture diagnostics" do
    inventory = @bare_uses_fixture |> File.read!() |> action_inventory(@bare_uses_fixture)

    floating_action = Enum.find(inventory, &(&1.ref == "v6"))

    assert floating_action,
           "bare uses reference in #{@bare_uses_fixture} was invisible to the action inventory"

    error =
      assert_raise ExUnit.AssertionError, fn ->
        assert_valid_inventory!(inventory)
      end

    assert error.message =~ @bare_uses_fixture <> ":#{floating_action.line}"
    assert error.message =~ "non-immutable action ref"
  end

  test "bare uses relaxation is necessary and an empty inventory fails closed" do
    fixture = File.read!(@bare_uses_fixture)

    pre_relaxation_inventory =
      action_inventory(fixture, @bare_uses_fixture, @pre_relaxation_inventory_pattern)

    relaxed_inventory = action_inventory(fixture, @bare_uses_fixture)

    refute Enum.any?(pre_relaxation_inventory, &(&1.ref == "v6")),
           "the pre-relaxation pattern unexpectedly sees the bare fixture reference"

    assert Enum.any?(relaxed_inventory, &(&1.ref == "v6")),
           "the relaxed pattern must see the bare fixture reference"

    error =
      assert_raise ExUnit.AssertionError, fn ->
        assert_inventory_floor!([])
      end

    assert error.message =~ "release action inventory has 0 entries"
  end

  test "dashed uses fixture proves the composite-action universe independently" do
    inventory = @dashed_uses_fixture |> File.read!() |> action_inventory(@dashed_uses_fixture)

    floating_action = Enum.find(inventory, &(&1.ref == "v6"))

    assert floating_action,
           "dashed uses reference in #{@dashed_uses_fixture} was not included in the inventory"

    error =
      assert_raise ExUnit.AssertionError, fn ->
        assert_valid_inventory!(inventory)
      end

    assert error.message =~ @dashed_uses_fixture <> ":#{floating_action.line}"
    assert error.message =~ "non-immutable action ref"
  end

  test "privileged Release Please boundaries remain byte-stable around the pin" do
    workflow = File.read!(@release_please_path)

    assert workflow =~ "on:\n  push:\n    branches:\n      - main\n  workflow_dispatch:"

    assert workflow =~
             "permissions:\n  actions: write\n  contents: write\n  issues: write\n  pull-requests: write"

    assert workflow =~ "release_created: ${{ steps.release.outputs.release_created }}"
    assert workflow =~ "tag_name: ${{ steps.release.outputs.tag_name }}"
    assert workflow =~ "version: ${{ steps.release.outputs.version }}"
    assert workflow =~ "sha: ${{ steps.release.outputs.sha }}"
    assert workflow =~ "if: ${{ steps.release-preflight.outputs.should_run == 'true' }}"
    assert workflow =~ "token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}"
  end

  defp production_inventory do
    composite_actions = composite_action_paths()

    assert composite_actions != [],
           "composite action glob #{@composite_actions_glob} returned no files; discovery broke, not the supply-chain surface"

    (@release_workflows ++ composite_actions)
    |> Enum.flat_map(fn path ->
      assert File.exists?(path), "action-pinning subject not found at #{path}"

      path |> File.read!() |> action_inventory(path)
    end)
  end

  defp composite_action_paths do
    case System.get_env("SIGRA_CONTRACT_SUBJECT") do
      nil -> discovered_composite_actions()
      "" -> discovered_composite_actions()
      path -> [path]
    end
  end

  defp discovered_composite_actions, do: Path.wildcard(@composite_actions_glob)

  defp action_inventory(workflow, workflow_path),
    do: action_inventory(workflow, workflow_path, @inventory_pattern)

  defp action_inventory(workflow, workflow_path, inventory_pattern) do
    workflow
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      case Regex.run(inventory_pattern, line) do
        [_, action, comment] -> action_entry(workflow_path, line_number, action, comment)
        [_, action] -> action_entry(workflow_path, line_number, action, nil)
        nil -> []
      end
    end)
  end

  defp assert_inventory_floor!(inventory) do
    assert length(inventory) >= @inventory_floor,
           "release action inventory has #{length(inventory)} entries; expected at least #{@inventory_floor} so a partial extractor cannot silently pass"
  end

  defp assert_valid_inventory!(inventory) do
    for action <- inventory do
      assert action.ref =~ ~r/^[0-9a-f]{40}$/,
             "#{action.workflow}:#{action.line} has non-immutable action ref #{inspect(action.ref)}"

      refute action.ref == @forbidden_tag_object,
             "#{action.workflow}:#{action.line} uses the annotated v5 tag object instead of its dereferenced commit"

      assert is_binary(action.comment) and
               action.comment =~ ~r/^v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/,
             "#{action.workflow}:#{action.line} is missing a same-line semantic version comment"
    end
  end

  defp action_entry(_workflow_path, _line_number, "./" <> _local_action, _comment), do: []

  defp action_entry(workflow_path, line_number, action, comment) do
    case String.split(action, "@", parts: 2) do
      [_repository, ref] ->
        [
          %{
            workflow: workflow_path,
            line: line_number,
            action: action,
            ref: ref,
            comment: comment
          }
        ]

      _ ->
        [%{workflow: workflow_path, line: line_number, action: action, ref: "", comment: comment}]
    end
  end
end
