# Phase 23: docs-ci-smoke-upgrade-guide - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 19
**Analogs found:** 19 / 19

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/introduction/getting-started.md` | utility | transform | `guides/introduction/getting-started.md` | exact |
| `guides/introduction/upgrading-to-v1.1.md` | utility | batch | `guides/introduction/installation.md` + `test/upgrade_test.exs` | partial |
| `guides/recipes/testing.md` | utility | transform | `guides/recipes/testing.md` | exact |
| `guides/recipes/multi-tenant.md` | utility | transform | `guides/recipes/multi-tenant.md` | exact |
| `guides/recipes/passkeys.md` | utility | transform | `guides/flows/mfa.md` | partial |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `lib/sigra/testing.ex` | utility | CRUD | `lib/sigra/testing.ex` | exact |
| `priv/templates/sigra.install/core/auth_fixtures.ex` | utility | CRUD | `priv/templates/sigra.install/core/auth_fixtures.ex` | exact |
| `test/example/test/support/fixtures/auth_fixtures.ex` | utility | CRUD | `test/example/test/support/fixtures/auth_fixtures.ex` | exact |
| `test/sigra/testing_test.exs` | test | transform | `test/sigra/testing_test.exs` | exact |
| `test/sigra/testing/assert_audit_logged_test.exs` | test | transform | `test/sigra/testing/assert_audit_logged_test.exs` | exact |
| `test/sigra/auth_fixtures_scenario_test.exs` | test | transform | `test/sigra/auth_fixtures_scenario_test.exs` | exact |
| `test/sigra/guides_dx02_test.exs` | test | file-I/O | `test/sigra/guides_dx02_test.exs` | exact |
| `test/fixtures/install_golden/tree/test/support/fixtures/auth_fixtures.ex` | test | file-I/O | `test/fixtures/install_golden/tree/test/support/fixtures/auth_fixtures.ex` | exact |
| `test/upgrade_test.exs` | test | batch | `test/upgrade_test.exs` | exact |
| `test/support/install_fixture.ex` | utility | batch | `test/support/install_fixture.ex` | exact |
| `test/example/priv/playwright/tests/organizations.spec.ts` | test | request-response | `test/example/priv/playwright/tests/organizations.spec.ts` | exact |
| `test/example/priv/playwright/tests/passkey-login.spec.ts` | test | request-response | `test/example/priv/playwright/tests/passkey-login.spec.ts` + `test/example/priv/playwright/tests/passkey-options.spec.ts` | exact |
| `.github/workflows/ci.yml` | config | batch | `.github/workflows/ci.yml` | exact |

## Pattern Assignments

### `guides/introduction/getting-started.md` (utility, transform)

**Analog:** `guides/introduction/getting-started.md`

**Narrative shape** (lines 3-18):
```md
This guide takes you from a fresh Phoenix app with Sigra installed to a working auth experience...

## Prerequisites

- Phoenix 1.8+ app named `MyApp`
- PostgreSQL running
- `{:sigra, "~> 0.1"}` in `mix.exs`
- `mix sigra.install && mix ecto.migrate` already run
```

**Step-by-step walkthrough contract** (lines 20-24, 26-31):
```md
## 1. Start the server

    mix phx.server

## 2. Register your first user

Visit <http://localhost:4000/users/register>.
```

**End-of-guide summary / related links** (lines 186-215):
```md
## 10. What you just built

In under 30 minutes you:

1. Registered a user...

## What's next

- **[Testing auth flows](testing.html)**
- **[Deployment](deployment.html)**
```

Use this same shape for the new org/passkeys continuation: numbered steps, runnable commands, generated-file references, then short related links.

---

### `guides/introduction/upgrading-to-v1.1.md` (utility, batch)

**Analog:** `guides/introduction/installation.md` for voice and terminal-runbook shape; `test/upgrade_test.exs` for the exact command sequence

**Operational doc voice** from `guides/introduction/installation.md` (lines 3-4, 35-39, 57-71):
```md
Sigra installs into an existing Phoenix 1.8+ application in four commands.

## Run the generator

    mix sigra.install

## Migrate

    mix ecto.migrate

## Smoke test

    mix phx.server
```

**Exact tested upgrade path** from `test/upgrade_test.exs` (lines 21-31, 40-66, 121-154):
```elixir
{:ok, _install_out} = InstallFixture.run_sigra_install(app_dir, ["--no-organizations"])
seed_users!(app_dir, 3)
{:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])
{:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])

{:ok, _upgrade_out} =
  InstallFixture.run_sigra_upgrade(app_dir, ["--backfill-personal-orgs"])
```

**Reusable helper API for docs-aligned automation** from `test/support/install_fixture.ex` (lines 174-237):
```elixir
@spec run_sigra_install(Path.t(), [String.t()]) :: {:ok, String.t()}
def run_sigra_install(app_dir, flags) when is_list(flags) do
  args = ["sigra.install", "Accounts", "User", "users"] ++ flags ++ ["--yes"]
end

@spec run_sigra_upgrade(Path.t(), [String.t()]) :: {:ok, String.t()}
def run_sigra_upgrade(app_dir, flags) when is_list(flags) do
  args = ["sigra.upgrade"] ++ flags ++ ["--allow-dirty", "--yes"]
end
```

Planner note: the guide should copy the imperative terminal style from `installation.md`, but every command sequence should mirror `upgrade_test.exs`.

---

### `guides/recipes/testing.md` (utility, transform)

**Analog:** `guides/recipes/testing.md`

**Setup + imports pattern** (lines 5-20):
```md
## Setup

    using do
      quote do
        import Sigra.Testing
        import MyApp.AuthFixtures
        import MyAppWeb.ConnCase
      end
    end
```

**Helper inventory style** (lines 65-82):
```md
## Assertions

- **`assert_password_hashed(user)`**
- **`assert_email_sent(to:, subject:)`**
- **`assert_audit_event(expected, opts)`**
```

**Pitfall honesty pattern** (lines 180-185):
```md
## Pitfalls

- **Scenario fixtures return different keys.**
- **`locked_fixture` does not set a conn.**
- **Swoosh test mailbox is per-test-process.**
```

Use this exact pattern when documenting new org/passkey helpers: short setup block, explicit helper bullets, then caveats about what the helper bypasses.

---

### `guides/recipes/multi-tenant.md` (utility, transform)

**Analog:** `guides/recipes/multi-tenant.md`

**Recipe structure with explicit model comparison** (lines 1-10, 109-152):
```md
# Multi-Tenant Apps

## Model 1: Row-based tenancy
...
## Model 2: Schema-based tenancy
...
## Which model to choose
```

**Query-scoping warning tone** (lines 82-107):
```md
### Step 5: Scope all queries

Use `Sigra.Scope` ... to scope every subsequent query

Forgetting the scope is a data leak.
```

For Phase 23, keep the recipe format, but replace the pre-v1.1 posture with the shipped organization model and `for_org/2` discipline.

---

### `guides/recipes/passkeys.md` (utility, transform)

**Analog:** `guides/flows/mfa.md`

**Feature inventory pattern** (lines 5-14):
```md
## What Sigra gives you

- **`MyAppWeb.MfaSettingsLive`**
- **`Sigra.MFA.enroll/2`**
- **`Sigra.MFA.verify_totp/4`**
```

**Happy-path lifecycle sections** (lines 15-49, 51-105):
```md
## Happy path: enrollment
...
## Happy path: challenge
...
## Trust this browser
```

**Testing section style** (lines 125-142):
```md
## Testing

    test "MFA-enabled user sees challenge on login" do
      ...
    end
```

Planner note: there is no dedicated passkeys guide yet, so treat `mfa.md` as a structural analog only. Fill content from the shipped passkey routes/tests, especially RP ID and origin recovery details.

---

### `mix.exs` (config, transform)

**Analog:** `mix.exs`

**Docs extras/groups wiring** (lines 122-160):
```elixir
defp docs do
  [
    main: "getting-started",
    extras: [
      "guides/introduction/installation.md",
      "guides/introduction/getting-started.md",
      "guides/recipes/testing.md",
      "guides/recipes/multi-tenant.md"
    ],
    groups_for_extras: [
      Introduction: ~r{guides/introduction/.?},
      Flows: ~r{guides/flows/.?},
      Recipes: ~r{guides/recipes/.?}
    ]
  ]
end
```

Any new guide file must be added to `extras` in the same change. Do not invent a new docs group for this phase.

---

### `lib/sigra/testing.ex` (utility, CRUD)

**Analog:** `lib/sigra/testing.ex`

**Narrow assertion style** (lines 36-50, 199-212):
```elixir
@spec assert_password_hashed(map()) :: true
def assert_password_hashed(%{hashed_password: hashed}) when is_binary(hashed) do
  if String.starts_with?(hashed, "$argon2id$") do
    true
  else
    raise ExUnit.AssertionError,
      message: "Expected hashed_password to start with \"$argon2id$\", got: #{inspect(hashed)}"
  end
end
```

**Repo-backed audit helper pattern** (lines 1149-1201, 1235-1237):
```elixir
@spec assert_audit_event(map(), keyword()) :: true
def assert_audit_event(expected, opts) when is_map(expected) and is_list(opts) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  ...
  event = repo.one(query)
  ...
  Enum.each(expected, fn
    {:metadata, expected_meta} when is_map(expected_meta) -> ...
    {key, expected_value} -> ...
  end)
  true
end

def assert_audit_logged(expected, opts) when is_map(expected) and is_list(opts) do
  assert_audit_event(expected, opts)
end
```

Add `assert_scope_has_org/2`, `assert_membership/3`, and `assert_audit_logged_for_org/2` as small, direct helpers in this style. Avoid DSL-style wrappers.

---

### `priv/templates/sigra.install/core/auth_fixtures.ex` (utility, CRUD)

**Analog:** `priv/templates/sigra.install/core/auth_fixtures.ex`

**Imports and alias pattern** (lines 9-13):
```elixir
import Phoenix.ConnTest, only: [build_conn: 0]
import <%= web_module %>.ConnCaseHelpers, only: [log_in_user: 2]

alias <%= context_module %>
```

**Primitive fixture composition pattern** (lines 44-70, 100-123):
```elixir
def session_fixture(user, attrs \\ %{}) do
  token = :crypto.strong_rand_bytes(32)
  hashed_token = :crypto.hash(:sha256, token)
  ...
  %<%= context_module %>.UserSession{}
  |> Ecto.Changeset.change(Map.put(session_attrs, :user_id, user.id))
  |> <%= repo_module %>.insert!()
end

def mfa_pending_session_fixture(attrs \\ %{}) do
  %{user: user, totp_secret: secret} = mfa_user_fixture(attrs)
  session = session_fixture(user, %{type: "mfa_pending"})
  %{user: user, session: session, totp_secret: secret}
end
```

**Scenario-helper caveat pattern** (lines 179-188):
```elixir
# These are UNIT-level helpers — they bypass real CSRF, rate limiting,
# and session-renewal flows. Integration tests exercising auth gates
# must drive real register/log_in controllers, not these fixtures.
```

Phase 23 helper additions should extend this file rather than split the API unless readability breaks down badly.

---

### `test/example/test/support/fixtures/auth_fixtures.ex` (utility, CRUD)

**Analog:** `test/example/test/support/fixtures/auth_fixtures.ex`

**Concrete passkey-fixture pattern** (lines 75-100):
```elixir
def passkey_fixture(user, attrs \\ %{}) do
  now = DateTime.utc_now()

  defaults = %{
    credential_id: "credential-" <> Integer.to_string(System.unique_integer([:positive])),
    public_key: <<1, 2, 3, 4>>,
    sign_count: 0,
    nickname: "Test passkey",
    rp_id: "localhost"
  }

  struct(Example.Accounts.UserPasskey, Map.merge(defaults, attrs))
  |> Repo.insert!()
end
```

**Deterministic response/stub pattern** (lines 102-174):
```elixir
def encoded_passkey_response(attrs \\ %{}) do
  ...
  |> JSON.encode!()
end

def stub_passkey_ceremony(result_fun) when is_function(result_fun, 1) do
  ...
  Application.put_env(:example, :passkey_ceremony_module, __MODULE__.PasskeyCeremonyStub)
  ExUnit.Callbacks.on_exit(fn -> ... end)
end
```

Use this file as the concrete analog when extending generated passkey helpers in the template.

---

### `test/sigra/testing_test.exs` (test, transform)

**Analog:** `test/sigra/testing_test.exs`

**Module export / focused helper test style** (lines 1-21, 126-206):
```elixir
defmodule Sigra.TestingTest do
  use ExUnit.Case, async: true

  alias Sigra.Testing

  describe "generate_totp_code/1" do
    test "generates a 6-digit TOTP code from a raw secret" do
      ...
    end
  end
```

Add new unit tests for helper exports and direct behavior here when they do not require fake repos or file-content assertions.

---

### `test/sigra/testing/assert_audit_logged_test.exs` (test, transform)

**Analog:** `test/sigra/testing/assert_audit_logged_test.exs`

**Fake-repo assertion test pattern** (lines 12-24, 26-85):
```elixir
defmodule FakeRepo do
  def one(_query), do: Process.get(:fake_repo_next_event)
end

setup do
  Process.delete(:fake_repo_next_event)
  :ok
end

assert_raise ExUnit.AssertionError, ~r/Expected action/, fn ->
  assert_audit_logged(%{action: "other.event"}, repo: FakeRepo, audit_schema: AuditEvent)
end
```

Use this exact pattern for org-aware audit assertion helpers that only need a fake repo result.

---

### `test/sigra/auth_fixtures_scenario_test.exs` (test, transform)

**Analog:** `test/sigra/auth_fixtures_scenario_test.exs`

**Template-content verification pattern** (lines 37-45, 87-139, 142-215):
```elixir
@template_path Path.expand("../../priv/templates/sigra.install/core/auth_fixtures.ex", __DIR__)

setup do
  content = File.read!(@template_path)
  %{content: content}
end

test "mfa_pending_fixture does NOT build a conn", %{content: content} do
  body = extract_function(content, "mfa_pending_fixture")
  refute body =~ "log_in_user"
end
```

Use this file to lock new generated org/passkey fixture helper names, return shapes, and caveat text.

---

### `test/sigra/guides_dx02_test.exs` (test, file-I/O)

**Analog:** `test/sigra/guides_dx02_test.exs`

**Guide file path constants + budget checks** (lines 20-37, 89-143):
```elixir
@guides_root "guides"
@getting_started Path.join([@guides_root, "introduction", "getting-started.md"])
@testing_guide Path.join([@guides_root, "recipes", "testing.md"])

@budget_seconds 30 * 60

test "estimated reading time is under 30 minutes" do
  raw = File.read!(@getting_started)
  {prose, code_block_count} = strip_code_blocks_and_frontmatter(raw)
  ...
end
```

**Structural checks for docs config** (lines 205-239):
```elixir
test "mix.exs docs config sets main: \"getting-started\"" do
  mix_contents = File.read!("mix.exs")
  assert mix_contents =~ ~r/main:\s*"getting-started"/
end

test "all 15 expected guide files exist" do
  expected = [...]
  missing = Enum.reject(expected, &File.exists?/1)
  assert missing == []
end
```

Extend this file, or follow this pattern in a sibling guide regression test, for new upgrade/passkeys/multi-tenant page assertions.

---

### `test/fixtures/install_golden/tree/test/support/fixtures/auth_fixtures.ex` (test, file-I/O)

**Analog:** `test/fixtures/install_golden/tree/test/support/fixtures/auth_fixtures.ex`

**Golden fixture mirror pattern** (lines 1-10, 179-232):
```elixir
defmodule SigraInstallGoldenTmp.AccountsFixtures do
  ...
  import Phoenix.ConnTest, only: [build_conn: 0]
  import SigraInstallGoldenTmpWeb.ConnCaseHelpers, only: [log_in_user: 2]

  def mfa_complete_fixture(attrs \\ %{}) do
    %{user: user, totp_secret: secret} = mfa_user_fixture(attrs)
    session = session_fixture(user, %{type: "standard"})
    conn = log_in_user(build_conn(), user)
    %{user: user, session: session, conn: conn, totp_secret: secret}
  end
```

If the template changes, the golden copy must stay byte-aligned with the rendered output.

---

### `test/upgrade_test.exs` (test, batch)

**Analog:** `test/upgrade_test.exs`

**Describe/test organization for upgrade modes** (lines 19-21, 70-72, 121-123):
```elixir
describe "upgrade after --no-organizations install ..." do
  @tag :tmp_dir
  test "mix sigra.upgrade --yes on a --no-organizations install ..." do
```

**Prove commands, then assert boot/runtime behavior** (lines 28-31, 89-117, 135-154):
```elixir
{:ok, _install_out} = InstallFixture.run_sigra_install(app_dir, [])
{:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])
{:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
{:ok, migrate_out} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])

assert login_result.final_path in ["/", "/organizations"]
assert Enum.all?(login_result.status_codes_seen, &(&1 < 500))
```

Use this as the executable source of truth for any upgrade commands documented in the guide.

---

### `test/support/install_fixture.ex` (utility, batch)

**Analog:** `test/support/install_fixture.ex`

**Narrow helper API for tmp apps** (lines 130-172, 184-263):
```elixir
@spec setup_tmp_app_without_install(keyword()) :: {:ok, %{app_dir: Path.t()}}
def setup_tmp_app_without_install(opts \\ []) do
  ...
  {:ok, %{app_dir: app_dir}}
end

@spec run_mix(Path.t(), [String.t()]) :: {:ok, String.t()}
def run_mix(app_dir, args) when is_list(args) do
  {out, status} = System.cmd("mix", args, ...)
  ...
end
```

If Phase 23 needs extra upgrade automation, add it here as another focused helper rather than embedding more shell logic in the test.

---

### `test/example/priv/playwright/tests/organizations.spec.ts` (test, request-response)

**Analog:** `test/example/priv/playwright/tests/organizations.spec.ts`

**Shared helper pattern at top of spec** (lines 15-17, 31-54):
```ts
import { test, expect } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';

const waitForLiveViewReady = async () => {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
};
```

**Real-browser journey style** (lines 56-67, 83-103, 243-260):
```ts
await page.goto('/users/register');
await waitForLiveViewReady();
await page.fill('input[name="user[email]"]', email);
await page.click('button:has-text("Create an account")');

const confirmHref = await extractConfirmationLink(page, email);
await page.goto(confirmHref);

await page.goto(`/organizations/${renamedSlug}/members`);
await expect(membersSection).toContainText(email);
await expect(inviteButton).toBeEnabled();
```

Phase 23 org smoke should extend this real-server pattern for switcher and invitation acceptance. Do not use route fulfillment shortcuts.

---

### `test/example/priv/playwright/tests/passkey-login.spec.ts` (test, request-response)

**Analog:** `test/example/priv/playwright/tests/passkey-login.spec.ts` with helper support from `test/example/priv/playwright/tests/passkey-options.spec.ts`

**Reusable Playwright helper style** (lines 3-29, 42-67):
```ts
async function waitForLiveViewReady(page: Parameters<typeof test>[0]["page"]) { ... }

async function registerAndAuthenticateUser(page, email, password) { ... }

async function addVirtualAuthenticator(page) {
  const client = await page.context().newCDPSession(page);
  await client.send("WebAuthn.enable");
  const { authenticatorId } = await client.send("WebAuthn.addVirtualAuthenticator", { options: { ... } });
  return { async close() { ... } };
}
```

**Real-options / real-completion assertions** (lines 75-96, 202-227):
```ts
const [optionsResponse, completionResponse] = await Promise.all([
  page.waitForResponse((response) =>
    response.url().includes("/users/settings/mfa/passkeys/options") &&
    response.request().method() === "POST"),
  page.waitForResponse((response) =>
    response.url().includes("/users/settings/mfa/passkeys") &&
    !response.url().includes("/options") &&
    response.request().method() === "POST"),
  page.locator("#add-passkey-button").click(),
]);

expect(optionsResponse.status()).toBe(200);
expect(completionResponse.status()).toBe(302);
```

**Smaller focused spec analog** from `passkey-options.spec.ts` (lines 58-89):
```ts
test("enrollment requests real passkey options from the served MFA settings page", async ({ page }) => {
  ...
  const [optionsResponse] = await Promise.all([
    page.waitForResponse((response) =>
      response.url().includes("/users/settings/mfa/passkeys/options") &&
      response.request().method() === "POST"),
    page.locator("#add-passkey-button").click(),
  ]);
});
```

Use this exact style for passkey registration and authentication smoke: real WebAuthn CDP setup, real options endpoint, and real server responses.

---

### `.github/workflows/ci.yml` (config, batch)

**Analog:** `.github/workflows/ci.yml`

**Docs hard gate** (line 54):
```yml
run: mix docs --warnings-as-errors
```

**Existing Playwright job structure** (lines 412-499):
```yml
example_playwright_smoke:
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
  steps:
    - uses: actions/checkout@...
    - uses: erlef/setup-beam@...
    - uses: actions/setup-node@...
    - name: Fetch example deps
      working-directory: test/example
      run: mix deps.get
    - name: Install Playwright deps
      working-directory: test/example/priv/playwright
      run: npm ci
    - name: Run Playwright golden-path spec
      working-directory: test/example/priv/playwright
      run: npx playwright test
```

Keep Phase 23 browser smoke in this job family. Preserve the split between docs/library tests and browser smoke.

## Shared Patterns

### HexDocs Taxonomy
**Source:** `mix.exs` lines 122-160  
**Apply to:** `guides/introduction/upgrading-to-v1.1.md`, `guides/recipes/passkeys.md`, any new guide file

```elixir
extras: [
  "guides/introduction/installation.md",
  "guides/introduction/getting-started.md",
  ...
  "guides/recipes/testing.md",
  "guides/recipes/multi-tenant.md",
  "guides/recipes/deployment.md"
],
groups_for_extras: [
  Introduction: ~r{guides/introduction/.?},
  Flows: ~r{guides/flows/.?},
  Recipes: ~r{guides/recipes/.?}
]
```

### Narrow Assertion Helpers
**Source:** `lib/sigra/testing.ex` lines 36-50, 1149-1201  
**Apply to:** `lib/sigra/testing.ex`, `test/sigra/testing_test.exs`, `test/sigra/testing/assert_audit_logged_test.exs`

```elixir
@spec assert_password_hashed(map()) :: true
def assert_password_hashed(%{hashed_password: hashed}) when is_binary(hashed) do
  ...
  raise ExUnit.AssertionError, message: ...
end

@spec assert_audit_event(map(), keyword()) :: true
def assert_audit_event(expected, opts) when is_map(expected) and is_list(opts) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  ...
end
```

### Generated Fixture Growth in One Module
**Source:** `priv/templates/sigra.install/core/auth_fixtures.ex` lines 44-70, 179-188  
**Apply to:** `priv/templates/sigra.install/core/auth_fixtures.ex`, mirrored golden fixture, template-content tests

```elixir
def session_fixture(user, attrs \\ %{}) do
  ...
end

# These are UNIT-level helpers — they bypass real CSRF, rate limiting,
# and session-renewal flows.
```

### Example App as Concrete Fixture Reference
**Source:** `test/example/test/support/fixtures/auth_fixtures.ex` lines 75-174  
**Apply to:** generated org/passkey helper design and examples in docs/tests

```elixir
def passkey_fixture(user, attrs \\ %{}) do
  ...
end

def stub_passkey_ceremony(result_fun) when is_function(result_fun, 1) do
  ...
end
```

### Guide Regression Tests Read Files Directly
**Source:** `test/sigra/guides_dx02_test.exs` lines 89-143, 205-239  
**Apply to:** any new or extended guide assertions

```elixir
raw = File.read!(@getting_started)
...
mix_contents = File.read!("mix.exs")
assert mix_contents =~ ~r/main:\s*"getting-started"/
```

### Upgrade Docs Must Follow Executed Harness
**Source:** `test/upgrade_test.exs` lines 21-66, 121-154; `test/support/install_fixture.ex` lines 184-237  
**Apply to:** `guides/introduction/upgrading-to-v1.1.md`, any upgrade automation additions

```elixir
{:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])
{:ok, _upgrade_out} =
  InstallFixture.run_sigra_upgrade(app_dir, ["--backfill-personal-orgs"])
```

### Playwright Uses Real Routes and WebAuthn
**Source:** `test/example/priv/playwright/tests/organizations.spec.ts` lines 56-67; `test/example/priv/playwright/tests/passkey-login.spec.ts` lines 42-67, 202-227  
**Apply to:** all browser smoke additions

```ts
await page.goto('/users/register');
...
await client.send("WebAuthn.addVirtualAuthenticator", { options: { ... } });
...
page.waitForResponse((response) =>
  response.url().includes("/users/log_in/passkey/options") &&
  response.request().method() === "POST")
```

## No Analog Found

None. Every Phase 23 file has at least a workable repo analog, though two are only partial matches:

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `guides/introduction/upgrading-to-v1.1.md` | utility | batch | No existing shipped upgrade guide; combine `installation.md` doc voice with `test/upgrade_test.exs` command truth. |
| `guides/recipes/passkeys.md` | utility | transform | No dedicated passkeys guide yet; use `guides/flows/mfa.md` structure and passkey tests/routes for content. |

## Metadata

**Analog search scope:** `guides/`, `lib/`, `priv/templates/`, `test/`, `.github/workflows/`  
**Files scanned:** 563  
**Pattern extraction date:** 2026-04-16
