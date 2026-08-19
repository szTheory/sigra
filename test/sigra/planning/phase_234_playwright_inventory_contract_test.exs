defmodule Sigra.Planning.Phase234PlaywrightInventoryContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @config_path "test/example/priv/playwright/playwright.config.ts"
  @inventory_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json"
  @inventory_sha256 "c11853b270ffaa7c8f65c5aa1f9d620098813d71f236e01554087611ca970bc3"
  @harness_mappings %{
    "test/example/priv/playwright/tests/admin-eval.spec.ts" => %{
      "command_marker" => "scripts/ci/admin-eval-harness.sh",
      "harness_path" => "scripts/ci/admin-eval-harness.sh",
      "harness_spec_marker" => "tests/admin-eval.spec.ts"
    },
    "test/example/priv/playwright/tests/admin-generated.spec.ts" => %{
      "command_marker" => "scripts/ci/admin-acceptance-smoke.sh --test all",
      "harness_path" => "scripts/ci/admin-acceptance-smoke.sh",
      "harness_spec_marker" => "tests/admin-generated.spec.ts"
    }
  }

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

  test "the Phase 235 inventory preserves its captured specs and executable lane seams" do
    inventory = inventory!()

    assert inventory["phase_235_gate_input"] == true
    assert inventory["schema_version"] == "sigra.playwright-ownership/v1"
    assert inventory["generated_from"] == "test/example/priv/playwright/tests/*.spec.ts"
    assert inventory_sha256!() == @inventory_sha256
    assert validate_inventory!(inventory) == :ok

    assert inventory["specs"] |> Enum.map(& &1["spec"]) ==
             inventory["specs"] |> Enum.map(& &1["spec"]) |> Enum.sort()

    for spec <- [
          "test/example/priv/playwright/tests/admin-theme.spec.ts",
          "test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts"
        ] do
      assert %{
               "lanes" => [
                 %{
                   "job" => "example_playwright_shard",
                   "seam" => "seam: admin_behavior",
                   "project" => "chromium"
                 }
               ]
             } =
               Enum.find(inventory["specs"], &(&1["spec"] == spec))
    end
  end

  test "inventory validation rejects missing, stale, duplicate, unowned, and broken lane tokens" do
    inventory = inventory!()
    [first | rest] = inventory["specs"]

    assert_raise ArgumentError, ~r/missing captured specs: #{Regex.escape(first["spec"])}/, fn ->
      validate_inventory!(Map.put(inventory, "specs", rest))
    end

    stale = Map.put(first, "spec", "test/example/priv/playwright/tests/stale.spec.ts")

    assert_raise ArgumentError, ~r/stale inventory specs: .*stale\.spec\.ts/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [stale | inventory["specs"]]))
    end

    assert_raise ArgumentError,
                 ~r/duplicate inventory spec: #{Regex.escape(first["spec"])}/,
                 fn ->
                   validate_inventory!(Map.put(inventory, "specs", [first | inventory["specs"]]))
                 end

    assert_raise ArgumentError, ~r/has no lane owners: #{Regex.escape(first["spec"])}/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [Map.put(first, "lanes", []) | rest]))
    end

    assert_lane_mutation_fails(
      inventory,
      "job",
      "missing_playwright_job",
      ~r/missing workflow job/
    )

    assert_lane_mutation_fails(
      inventory,
      "command_marker",
      "missing command marker",
      ~r/missing command marker/
    )

    assert_lane_mutation_fails(
      inventory,
      "config_seam",
      "MISSING_CONFIG_SEAM",
      ~r/missing config seam/
    )
  end

  test "inventory validation rejects a direct lane borrowing a sibling spec marker" do
    inventory = inventory!()
    {admin_audit, other_specs} = pop_spec!(inventory["specs"], "admin-audit.spec.ts")
    [lane] = admin_audit["lanes"]

    swapped_audit =
      Map.put(admin_audit, "lanes", [Map.put(lane, "command_marker", "tests/admin-theme.spec.ts")])

    assert_raise ArgumentError,
                 ~r/admin-audit\.spec\.ts.*tests\/admin-theme\.spec\.ts/,
                 fn ->
                   validate_inventory!(Map.put(inventory, "specs", [swapped_audit | other_specs]))
                 end
  end

  test "inventory validation permits only the documented exact-spec harness mappings" do
    inventory = inventory!()

    assert_harness_lane!(inventory, "admin-eval.spec.ts", %{
      "harness_path" => "scripts/ci/admin-eval-harness.sh",
      "harness_spec_marker" => "tests/admin-eval.spec.ts"
    })

    assert_harness_lane!(inventory, "admin-generated.spec.ts", %{
      "harness_path" => "scripts/ci/admin-acceptance-smoke.sh",
      "harness_spec_marker" => "tests/admin-generated.spec.ts"
    })

    {admin_eval, other_specs} = pop_spec!(inventory["specs"], "admin-eval.spec.ts")
    [eval_lane] = admin_eval["lanes"]

    swapped_harness =
      Map.put(admin_eval, "lanes", [
        Map.put(eval_lane, "harness_spec_marker", "tests/admin-generated.spec.ts")
      ])

    assert_raise ArgumentError, ~r/admin-eval\.spec\.ts.*tests\/admin-eval\.spec\.ts/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [swapped_harness | other_specs]))
    end

    {admin_audit, remaining_specs} = pop_spec!(inventory["specs"], "admin-audit.spec.ts")
    [audit_lane] = admin_audit["lanes"]

    unauthorized_indirection =
      audit_lane
      |> Map.put("command_marker", "scripts/ci/admin-eval-harness.sh")
      |> Map.put("harness_path", "scripts/ci/admin-eval-harness.sh")
      |> Map.put("harness_spec_marker", "tests/admin-eval.spec.ts")

    unauthorized_audit = Map.put(admin_audit, "lanes", [unauthorized_indirection])

    assert_raise ArgumentError, ~r/admin-audit\.spec\.ts.*expected direct invocation/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [unauthorized_audit | remaining_specs]))
    end

    extra_harness_field = Map.put(eval_lane, "harness_extra", "not-allowed")
    extra_field_eval = Map.put(admin_eval, "lanes", [extra_harness_field])

    assert_raise ArgumentError, ~r/admin-eval\.spec\.ts.*unexpected harness metadata/, fn ->
      validate_inventory!(Map.put(inventory, "specs", [extra_field_eval | other_specs]))
    end

    assert_raise ArgumentError, ~r/admin-eval\.spec\.ts.*tests\/admin-eval\.spec\.ts/, fn ->
      validate_harness_spec_invocation!(
        "test/example/priv/playwright/tests/admin-eval.spec.ts",
        "scripts/ci/admin-eval-harness.sh",
        "tests/admin-eval.spec.ts",
        "npx playwright test tests/admin-theme.spec.ts"
      )
    end
  end

  defp assert_lane_mutation_fails(inventory, field, value, message) do
    [first | rest] = inventory["specs"]
    [lane | lanes] = first["lanes"]
    mutated = Map.put(first, "lanes", [Map.put(lane, field, value) | lanes])

    assert_raise ArgumentError, message, fn ->
      validate_inventory!(Map.put(inventory, "specs", [mutated | rest]))
    end
  end

  defp pop_spec!(specs, spec_name) do
    Enum.split_with(specs, &String.ends_with?(&1["spec"], spec_name))
    |> case do
      {[spec], others} -> {spec, others}
      _ -> raise "missing unique inventory spec: #{spec_name}"
    end
  end

  defp assert_harness_lane!(inventory, spec_name, expected_fields) do
    {spec, _others} = pop_spec!(inventory["specs"], spec_name)
    [lane] = spec["lanes"]

    for {field, expected} <- expected_fields do
      assert lane[field] == expected
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

    captured_specs = inventory!() |> Map.fetch!("specs") |> Enum.map(&Map.fetch!(&1, "spec"))
    inventory_specs = Enum.map(specs, &Map.fetch!(&1, "spec"))

    duplicate_specs = inventory_specs -- Enum.uniq(inventory_specs)

    if duplicate_specs != [] do
      raise ArgumentError, "duplicate inventory spec: #{Enum.sort(duplicate_specs) |> hd()}"
    end

    missing = MapSet.difference(MapSet.new(captured_specs), MapSet.new(inventory_specs))
    stale = MapSet.difference(MapSet.new(inventory_specs), MapSet.new(captured_specs))

    if MapSet.size(missing) > 0 do
      raise ArgumentError, "missing captured specs: #{format_paths(missing)}"
    end

    if MapSet.size(stale) > 0 do
      raise ArgumentError, "stale inventory specs: #{format_paths(stale)}"
    end

    missing_files = captured_specs |> Enum.reject(&File.regular?/1) |> MapSet.new()

    if MapSet.size(missing_files) > 0 do
      raise ArgumentError, "missing captured spec files: #{format_paths(missing_files)}"
    end

    workflow = File.read!(@workflow_path)
    config = File.read!(@config_path)

    Enum.each(specs, &validate_spec!(&1, workflow, config))
    :ok
  end

  defp validate_inventory!(_), do: raise(ArgumentError, "inventory must contain non-empty specs")

  defp validate_spec!(%{"spec" => spec, "lanes" => lanes}, workflow, config)
       when is_binary(spec) and is_list(lanes) and lanes != [] do
    Enum.each(lanes, &validate_lane!(spec, &1, workflow, config))
  end

  defp validate_spec!(%{"spec" => spec, "lanes" => []}, _workflow, _config),
    do: raise(ArgumentError, "spec has no lane owners: #{spec}")

  defp validate_spec!(spec, _workflow, _config),
    do: raise(ArgumentError, "malformed inventory spec: #{inspect(spec)}")

  defp validate_lane!(spec, lane, workflow, config) do
    for field <- ["workflow", "job", "seam", "events", "command_marker", "project", "config_seam"] do
      unless Map.has_key?(lane, field), do: raise(ArgumentError, "missing lane field: #{field}")
    end

    workflow_path = lane["workflow"]

    unless is_list(lane["events"]) and lane["events"] != [] and
             Enum.all?(lane["events"], &is_binary/1) and
             lane["events"] == Enum.sort(lane["events"]) do
      raise ArgumentError, "events must be a non-empty sorted list"
    end

    unless workflow_path == @workflow_path do
      raise ArgumentError, "unsupported workflow path: #{workflow_path}"
    end

    job = workflow_job!(workflow, lane["job"])

    unless job =~ lane["seam"] do
      raise ArgumentError, "missing workflow seam: #{lane["seam"]}"
    end

    unless Enum.all?(lane["events"], &String.contains?(workflow, &1)) do
      raise ArgumentError, "missing workflow event: #{Enum.join(lane["events"], ", ")}"
    end

    validate_invocation!(spec, lane, job)

    unless config =~ "name: '#{lane["project"]}'" do
      raise ArgumentError, "missing Playwright project: #{lane["project"]}"
    end

    unless config =~ lane["config_seam"] do
      raise ArgumentError, "missing config seam: #{lane["config_seam"]}"
    end
  end

  defp direct_command_marker!("test/example/priv/playwright/" <> spec), do: spec

  defp direct_command_marker!(spec),
    do: raise(ArgumentError, "unsupported Playwright spec path: #{spec}")

  defp validate_invocation!(spec, lane, job) do
    case Map.get(@harness_mappings, spec) do
      nil -> validate_direct_invocation!(spec, lane, job)
      mapping -> validate_harness_invocation!(spec, lane, job, mapping)
    end
  end

  defp validate_direct_invocation!(spec, lane, job) do
    if Map.has_key?(lane, "harness_path") or Map.has_key?(lane, "harness_spec_marker") do
      raise ArgumentError, "spec #{spec} expected direct invocation, not harness metadata"
    end

    expected_marker = direct_command_marker!(spec)

    unless lane["command_marker"] == expected_marker do
      raise ArgumentError,
            "spec #{spec} must use direct command marker #{expected_marker}, got #{lane["command_marker"]}"
    end

    unless job =~ expected_marker do
      raise ArgumentError, "missing command marker for #{spec}: #{expected_marker}"
    end
  end

  defp validate_harness_invocation!(spec, lane, job, mapping) do
    unexpected_harness_fields =
      lane
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "harness_"))
      |> Kernel.--(["harness_path", "harness_spec_marker"])

    if unexpected_harness_fields != [] do
      raise ArgumentError,
            "spec #{spec} has unexpected harness metadata: #{Enum.join(unexpected_harness_fields, ", ")}"
    end

    for {field, expected} <- mapping do
      unless lane[field] == expected do
        raise ArgumentError,
              "spec #{spec} must use harness #{mapping["harness_path"]} with #{field} #{expected}, got #{inspect(lane[field])}"
      end
    end

    unless job =~ mapping["command_marker"] do
      raise ArgumentError, "missing command marker for #{spec}: #{mapping["command_marker"]}"
    end

    harness_source = File.read!(mapping["harness_path"])

    validate_harness_spec_invocation!(
      spec,
      mapping["harness_path"],
      mapping["harness_spec_marker"],
      harness_source
    )
  end

  defp validate_harness_spec_invocation!(spec, harness_path, expected_marker, harness_source) do
    unless harness_source =~ expected_marker do
      raise ArgumentError,
            "spec #{spec} harness #{harness_path} must invoke #{expected_marker}"
    end
  end

  defp inventory_sha256! do
    @inventory_path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp workflow_job!(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> raise ArgumentError, "missing workflow job: #{job_id}"
    end
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
