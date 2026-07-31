defmodule Sigra.Planning.Phase232PlaywrightEconomicsTest do
  use ExUnit.Case, async: true

  @config_path "test/example/priv/playwright/playwright.config.ts"
  @setup_path "test/example/priv/playwright/tests/admin-design.setup.ts"
  @spec_path "test/example/priv/playwright/tests/admin-design.spec.ts"

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
    [before_each] = Regex.run(~r/test\.beforeEach\(async \(\{ page \}\) => \{(.*?)\n  \}\);/s, spec, capture: :all_but_first)

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
end
