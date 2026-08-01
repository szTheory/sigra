defmodule Sigra.Planning.Phase234PlaywrightInventoryContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @config_path "test/example/priv/playwright/playwright.config.ts"
  @inventory_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json"

  test "admin_behavior explicitly owns both useful orphan specs on retry-zero chromium" do
    workflow = File.read!(@workflow_path)
    config = File.read!(@config_path)
    shard = job_body(workflow, "example_playwright_shard")
    admin_behavior = run_block(shard, "Run admin behavior browser truth")

    for spec <- ["admin-theme.spec.ts", "admin-coherence-sweep.spec.ts"] do
      assert occurrences(admin_behavior, "tests/#{spec}") == 1,
             "admin_behavior must name tests/#{spec} exactly once"
    end

    assert admin_behavior =~ "--project=chromium"
    assert admin_behavior =~ "--retries=0"
    assert shard =~ "uses: ./.github/actions/example-playwright-boot"
    assert shard =~ "seam: admin_behavior"
    assert config =~ "admin-theme"
    assert config =~ "admin-coherence-sweep"
  end

  test "the terminal Playwright aggregate remains the full-lifecycle guard" do
    terminal = job_body(File.read!(@workflow_path), "example_playwright_smoke")

    assert terminal =~ "name: Example Playwright smoke (full lifecycle)"
    assert terminal =~ "needs.example_playwright_shard.result"
    assert terminal =~ "exit 1"
  end

  test "the Phase 235 inventory exactly reconciles live specs and executable lane seams" do
    inventory = inventory!()

    assert inventory["phase_235_gate_input"] == true
    assert inventory["schema_version"] == "sigra.playwright-ownership/v1"
    assert validate_inventory!(inventory) == :ok
  end

  test "inventory validation rejects missing, stale, duplicate, unowned, and broken lane tokens" do
    inventory = inventory!()
    [first | rest] = inventory["specs"]

    assert_raise ArgumentError, ~r/missing live specs: #{Regex.escape(first["spec"])}/, fn ->
      validate_inventory!(Map.put(inventory, "specs", rest))
    end

    stale = Map.put(first, "spec", "test/example/priv/playwright/tests/stale.spec.ts")

    assert_raise ArgumentError, ~r/stale inventory specs: .*stale\.spec\.ts/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [stale | inventory["specs"]]))
    end

    assert_raise ArgumentError, ~r/duplicate inventory spec: #{Regex.escape(first["spec"])}/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [first | inventory["specs"]]))
    end

    assert_raise ArgumentError, ~r/has no lane owners: #{Regex.escape(first["spec"])}/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [Map.put(first, "lanes", []) | rest]))
    end

    assert_lane_mutation_fails(inventory, "job", "missing_playwright_job", ~r/missing workflow job/)
    assert_lane_mutation_fails(inventory, "command_marker", "missing command marker", ~r/missing command marker/)
    assert_lane_mutation_fails(inventory, "config_seam", "MISSING_CONFIG_SEAM", ~r/missing config seam/)
  end

  defp assert_lane_mutation_fails(inventory, field, value, message) do
    [first | rest] = inventory["specs"]
    [lane | lanes] = first["lanes"]
    mutated = Map.put(first, "lanes", [Map.put(lane, field, value) | lanes])

    assert_raise ArgumentError, message, fn ->
      validate_inventory!(Map.put(inventory, "specs", [mutated | rest]))
    end
  end

  defp inventory! do
    @inventory_path
    |> File.read!()
    |> JSON.decode!()
  end

  defp validate_inventory!(%{"specs" => specs} = inventory) when is_list(specs) and specs != [] do
    unless inventory["schema_version"] == "sigra.playwright-ownership/v1" do
      raise ArgumentError, "unsupported inventory schema"
    end

    live_specs = live_specs()
    inventory_specs = Enum.map(specs, &Map.fetch!(&1, "spec"))

    duplicate_specs = inventory_specs -- Enum.uniq(inventory_specs)

    if duplicate_specs != [] do
      raise ArgumentError, "duplicate inventory spec: #{Enum.sort(duplicate_specs) |> hd()}"
    end

    missing = MapSet.difference(MapSet.new(live_specs), MapSet.new(inventory_specs))
    stale = MapSet.difference(MapSet.new(inventory_specs), MapSet.new(live_specs))

    if MapSet.size(missing) > 0 do
      raise ArgumentError, "missing live specs: #{format_paths(missing)}"
    end

    if MapSet.size(stale) > 0 do
      raise ArgumentError, "stale inventory specs: #{format_paths(stale)}"
    end

    workflow = File.read!(@workflow_path)
    config = File.read!(@config_path)

    Enum.each(specs, &validate_spec!(&1, workflow, config))
    :ok
  end

  defp validate_inventory!(_), do: raise(ArgumentError, "inventory must contain non-empty specs")

  defp validate_spec!(%{"spec" => spec, "lanes" => lanes}, workflow, config)
       when is_binary(spec) and is_list(lanes) and lanes != [] do
    Enum.each(lanes, &validate_lane!(&1, workflow, config))
  end

  defp validate_spec!(%{"spec" => spec, "lanes" => []}, _workflow, _config),
    do: raise(ArgumentError, "spec has no lane owners: #{spec}")

  defp validate_spec!(spec, _workflow, _config), do: raise(ArgumentError, "malformed inventory spec: #{inspect(spec)}")

  defp validate_lane!(lane, workflow, config) do
    for field <- ["workflow", "job", "seam", "events", "command_marker", "project", "config_seam"] do
      unless Map.has_key?(lane, field), do: raise(ArgumentError, "missing lane field: #{field}")
    end

    workflow_path = lane["workflow"]

    unless workflow_path == @workflow_path do
      raise ArgumentError, "unsupported workflow path: #{workflow_path}"
    end

    job = job_body(workflow, lane["job"])

    unless job =~ "seam: #{lane["seam"]}" do
      raise ArgumentError, "missing workflow seam: #{lane["seam"]}"
    end

    unless Enum.all?(lane["events"], &String.contains?(workflow, &1)) do
      raise ArgumentError, "missing workflow event: #{Enum.join(lane["events"], ", ")}"
    end

    unless job =~ lane["command_marker"] do
      raise ArgumentError, "missing command marker: #{lane["command_marker"]}"
    end

    unless config =~ "name: '#{lane["project"]}'" do
      raise ArgumentError, "missing Playwright project: #{lane["project"]}"
    end

    unless config =~ lane["config_seam"] do
      raise ArgumentError, "missing config seam: #{lane["config_seam"]}"
    end
  end

  defp live_specs do
    "test/example/priv/playwright/tests/*.spec.ts"
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp format_paths(paths), do: paths |> MapSet.to_list() |> Enum.sort() |> Enum.join(", ")

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end

  defp run_block(job, name) do
    pattern =
      ~r/^      - name: #{Regex.escape(name)}\n(?<body>(?:(?!^      - name:|^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, job) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow step #{name}")
    end
  end

  defp occurrences(source, marker), do: source |> String.split(marker) |> length() |> Kernel.-(1)
end
