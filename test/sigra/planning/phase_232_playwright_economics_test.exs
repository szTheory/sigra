defmodule Sigra.Planning.Phase232PlaywrightEconomicsTest do
  use ExUnit.Case, async: true

  @config_path "test/example/priv/playwright/playwright.config.ts"
  @setup_path "test/example/priv/playwright/tests/admin-design.setup.ts"
  @spec_path "test/example/priv/playwright/tests/admin-design.spec.ts"
  @workflow_path ".github/workflows/ci.yml"
  @lockfile_path "test/example/priv/playwright/package-lock.json"
  @boot_action_path ".github/actions/example-playwright-boot/action.yml"
  @browser_command_path "scripts/ci/ci-browser-command.mjs"

  test "chromium design project depends on one setup project with a private state path" do
    config = File.read!(@config_path)

    assert config =~ "name: 'admin-design-setup-chromium'"

    assert config =~
             ~r/name: 'admin-design-chromium',[\s\S]*dependencies: \['admin-design-setup-chromium'\],[\s\S]*storageState: 'test-results\/\.auth\/admin-design-chromium\.json'/,
           "the chromium design project must have exactly its own setup dependency and state path"
  end

  test "chromium setup registers a policy-valid identity through the UI and persists state" do
    setup = File.read!(@setup_path)

    assert setup =~ "platform-admin+dg-chromium-"
    assert setup =~ "getByRole('button', { name: /Create an account/ })"
    assert setup =~ "getByRole('alert')"
    assert setup =~ "mkdir(dirname(statePath), { recursive: true })"
    assert setup =~ "storageState({ path: statePath })"
  end

  test "design spec uses readiness-only beforeEach" do
    spec = File.read!(@spec_path)

    [before_each] =
      Regex.run(~r/test\.beforeEach\(async \(\{ page \}\) => \{(.*?)\n  \}\);/s, spec,
        capture: :all_but_first
      )

    assert before_each =~ "page.goto('/admin/_design')"
    assert before_each =~ "waitForLiveViewReady(page)"
    refute before_each =~ "registerUser"
    refute before_each =~ "waitForTimeout"
    refute before_each =~ "retry"
  end

  test "every design project has its namesake setup, unique state, and preserved render context" do
    config = File.read!(@config_path)
    setup = File.read!(@setup_path)

    projects = ["chromium", "mobile", "dark"]

    for project <- projects do
      assert config =~ "name: 'admin-design-setup-#{project}'"

      assert config =~
               "name: 'admin-design-#{project}'",
             "admin-design-#{project} must remain an explicit project"

      assert config =~ "dependencies: ['admin-design-setup-#{project}']"
      assert config =~ "storageState: 'test-results/.auth/admin-design-#{project}.json'"
      assert setup =~ "platform-admin+dg-#{project}-"
    end

    assert length(Regex.scan(~r/name: 'admin-design-setup-[^']+'/, config)) == 3

    states = Regex.scan(~r/storageState: '([^']+)'/, config, capture: :all_but_first)
    assert states |> List.flatten() |> Enum.uniq() |> length() == 3

    assert config =~ "use: { ...devices['iPhone 13'] }"
    assert config =~ "...devices['Desktop Chrome'],\n        colorScheme: 'dark'"
    refute File.read!(@spec_path) =~ "registerUser"
  end

  test "one shared boot action owns the prelude for every example Playwright consumer" do
    workflow = File.read!(@workflow_path)

    consumers = [
      "example_playwright_shard",
      "admin_design_recapture",
      "admin_checkpoint_recapture",
      "admin_eval_render"
    ]

    assert File.exists?(@boot_action_path), "the shared example Playwright boot action must exist"
    action = File.read!(@boot_action_path)

    assert action =~ "using: composite"

    assert action =~
             "example-dev-port${{ inputs.app-port }}-otp",
           "cached compile output must be partitioned by the endpoint's compile-time port"

    preparation =
      Regex.scan(~r/^\s+(mix do .+)$/m, action, capture: :all_but_first)
      |> List.flatten()

    expected_preparation =
      "mix do deps.get + compile --warnings-as-errors + ecto.create + ecto.migrate + run priv/repo/seeds.exs"

    assert preparation == [expected_preparation, expected_preparation],
           "both recorder-enabled and direct paths must execute the same ordered Mix preparation"

    assert action =~ "ci-command-record.py"
    assert action =~ "--invocation \"${DIAGNOSTICS_PREFIX}-prepare\""

    for marker <- ["mix phx.server", "curl -sf"] do
      assert length(Regex.scan(Regex.compile!(Regex.escape(marker)), action)) == 1,
             "shared action must own #{marker} exactly once"
    end

    for consumer <- consumers do
      body = job_body(workflow, consumer)
      assert body =~ "uses: ./.github/actions/example-playwright-boot"
      refute body =~ "mix ecto.create"
      refute body =~ "mix run priv/repo/seeds.exs"
      refute body =~ "mix do deps.get"
      refute body =~ "mix phx.server"
      refute body =~ "for i in $(seq 1 30)"
    end
  end

  test "five isolated retry-zero shards converge on the protected terminal result" do
    workflow = File.read!(@workflow_path)
    browser_command = File.read!(@browser_command_path)
    shard = job_body(workflow, "example_playwright_shard")
    terminal = job_body(workflow, "example_playwright_smoke")

    expected_seams = [
      "admin_behavior",
      "admin_checkpoints",
      "design_gallery",
      "non_admin_smoke",
      "demo_showcase"
    ]

    assert shard =~ "fail-fast: false"
    assert shard =~ "image: postgres:15"
    assert shard =~ "uses: ./.github/actions/example-playwright-boot"

    actual_seams =
      Regex.scan(~r/^\s+- seam: ([a-z_]+)$/m, shard, capture: :all_but_first)
      |> List.flatten()

    assert actual_seams == expected_seams

    for seam <- expected_seams do
      assert shard =~ "seam: #{seam}"
      assert shard =~ "sigra_#{seam}"
      assert shard =~ "/tmp/example-playwright-#{String.replace(seam, "_", "-")}.log"
    end

    assert browser_command =~ "retries: 0"
    assert browser_command =~ "args.push('--retries=0')"
    assert browser_command =~ "grepInvert: '@snapshot'"
    assert browser_command =~ "grep: '@snapshot'"

    for seam <- expected_seams do
      assert length(Regex.scan(~r/ci-browser-command\.mjs list --seam #{seam} --event/, shard)) >=
               1

      assert length(Regex.scan(~r/ci-browser-command\.mjs run --seam #{seam} --event/, shard)) >=
               1

      [policy] = browser_policy!(seam, "pull_request")
      assert Enum.all?(policy["invocations"], &(&1["retries"] == 0))
    end

    [gallery_policy] = browser_policy!("design_gallery", "pull_request")
    [gallery_invocation] = gallery_policy["invocations"]
    assert gallery_invocation["grepInvert"] == "@snapshot"

    assert shard =~
             ~r/seam: non_admin_smoke.*?browsers: chromium webkit/s,
           "non-admin smoke includes the WebKit-backed mobile project"

    lockfile = @lockfile_path |> File.read!() |> Jason.decode!()
    version = get_in(lockfile, ["packages", "node_modules/@playwright/test", "version"])
    assert is_binary(version) and version =~ ~r/^\d+\.\d+\.\d+$/

    chromium_key =
      Regex.compile!("browser_cache_key: playwright-chromium-#{Regex.escape(version)}-v3")

    webkit_key =
      Regex.compile!("browser_cache_key: playwright-chromium-webkit-#{Regex.escape(version)}-v3")

    assert length(Regex.scan(chromium_key, shard)) == 2
    assert length(Regex.scan(webkit_key, shard)) == 3

    assert shard =~ "browser-cache-key: ${{ runner.os }}-${{ matrix.browser_cache_key }}"

    refute shard =~ "continue-on-error"
    refute shard =~ ~r/auth.*schema.*prefix/is

    assert terminal =~ "name: Example Playwright smoke (full lifecycle)"
    assert terminal =~ "example_playwright_shard"
    assert terminal =~ "if: always()"
    assert terminal =~ "needs.example_playwright_shard.result"
    assert terminal =~ "exit 1"
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end

  defp browser_policy!(seam, event) do
    script =
      "import { browserInvocations } from './#{@browser_command_path}'; " <>
        "process.stdout.write(JSON.stringify(browserInvocations('#{seam}', '#{event}')));"

    {output, 0} = System.cmd("node", ["--input-type=module", "-e", script])
    Jason.decode!(output)
  end
end
