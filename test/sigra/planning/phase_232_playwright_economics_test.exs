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
end
