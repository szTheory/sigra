# Phase 22: `--passkeys` Generator Wiring - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 16
**Analogs found:** 16 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/mix/tasks/sigra.install.ex` | config | request-response | `lib/mix/tasks/sigra.install.ex` | exact |
| `lib/sigra/install/features/passkeys.ex` | service | file-I/O | `lib/sigra/install/features/organizations.ex` | exact |
| `lib/sigra/install/features/core.ex` | service | file-I/O | `lib/sigra/install/features/core.ex` | exact |
| `priv/templates/sigra.install/core/auth.ex` | service | CRUD | `priv/templates/sigra.install/core/scope.ex` | role-match |
| `priv/templates/sigra.install/core/session_controller.ex` | controller | request-response | `priv/templates/sigra.install/core/confirmation_controller.ex` | role-match |
| `priv/templates/sigra.install/core/login_html.ex` | component | request-response | `priv/templates/sigra.install/core/registration_html.ex` | role-match |
| `priv/templates/sigra.install/core/mfa_settings_live.ex` | component | event-driven | `priv/templates/sigra.install/core/mfa_challenge_live.ex` | exact |
| `priv/templates/sigra.install/core/mfa_challenge_live.ex` | component | event-driven | `priv/templates/sigra.install/core/mfa_challenge_live.ex` | exact |
| `priv/templates/sigra.install/core/registration_html.ex` | component | request-response | `priv/templates/sigra.install/core/registration_html.ex` | exact |
| `priv/templates/sigra.install/core/confirmation_controller.ex` | controller | request-response | `priv/templates/sigra.install/core/confirmation_controller.ex` | exact |
| `test/sigra/install/features/passkeys_test.exs` | test | transform | `test/sigra/install/features/organizations_test.exs` | exact |
| `test/sigra/install/features/passkeys_js_test.exs` | test | file-I/O | `test/sigra/install/features/passkeys_js_test.exs` | exact |
| `test/sigra/install/features/coverage_test.exs` | test | transform | `test/sigra/install/features/coverage_test.exs` | exact |
| `test/sigra/install/generator_passkeys_foundation_test.exs` | test | transform | `test/sigra/install/generator_passkeys_foundation_test.exs` | exact |
| `test/sigra/install/generator_passkey_management_test.exs` | test | transform | `test/sigra/install/generator_passkey_management_test.exs` | exact |
| `.github/workflows/ci.yml` | config | batch | `.github/workflows/ci.yml` | exact |

## Pattern Assignments

### `lib/mix/tasks/sigra.install.ex` (config, request-response)

**Analog:** `lib/mix/tasks/sigra.install.ex`

**Switch/default pattern** ([lib/mix/tasks/sigra.install.ex:41](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L41), [lib/mix/tasks/sigra.install.ex:51](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L51)):
```elixir
  @switches [
    live: :boolean,
    binary_id: :boolean,
    table: :string,
    api: :boolean,
    jwt: :boolean,
    organizations: :boolean,
    passkeys: :boolean,
    yes: :boolean
  ]
  @default_opts [
    live: true,
    api: false,
    jwt: false,
    binary_id: true,
    organizations: true,
    passkeys: false
  ]
```

**Binding threading pattern** ([lib/mix/tasks/sigra.install.ex:122](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L122)):
```elixir
      binary_id: Keyword.get(opts, :binary_id, true),
      live: opts[:live],
      api: opts[:api] || opts[:jwt] || false,
      jwt: opts[:jwt] || false,
      organizations?: Keyword.get(opts, :organizations, true),
      adapter: adapter,
      reset_password_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/reset-password",
      settings_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/settings",
      opts: opts
```

**Use this for:** default-on boolean flags, option-parser docs/help, and binding propagation of `passkeys?` alongside existing `organizations?`.

---

### `lib/sigra/install/features/passkeys.ex` (service, file-I/O)

**Analog:** `lib/sigra/install/features/organizations.ex`

**Feature boundary pattern** ([lib/sigra/install/features/organizations.ex:36](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L36), [lib/sigra/install/features/passkeys.ex:15](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex#L15)):
```elixir
  @impl true
  def enabled?(opts), do: Keyword.get(opts, :organizations, true)
```

```elixir
  @impl true
  def enabled?(opts), do: Keyword.get(opts, :passkeys, false)
```

**Whole-artifact ownership pattern** ([lib/sigra/install/features/organizations.ex:40](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L40)):
```elixir
  def files(binding) do
    otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
    web = "#{otp_app}_web"
    ctx = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

    [
      {:eex, "organizations/organization.ex",
       Path.join(["lib", otp_app, ctx, "organization.ex"])},
      ...
    ]
  end
```

**Injection-from-template pattern** ([lib/sigra/install/features/organizations.ex:225](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L225), [lib/sigra/install/features/passkeys.ex:38](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex#L38)):
```elixir
  defp router_injection(otp_app, binding) do
    content = eval_template!("organizations/router_injection.ex", binding)

    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra organizations",
      anchor: :before_last_end,
      content: content
    }
  end
```

```elixir
  def injections(_binding) do
    [
      %Injection{
        target: Path.join(["assets", "js", "app.js"]),
        marker: "// Sigra passkeys:start",
        anchor: :app_js_passkeys,
        content: read_template!("passkeys/app_js_passkeys_injection.js")
      }
    ]
  end
```

**Use this for:** expanding `Passkeys` to own passkey-only router blocks, `mix.exs`/`assets/package.json` injections, and any passkey-only generated files.

---

### `lib/sigra/install/features/core.ex` (service, file-I/O)

**Analog:** `lib/sigra/install/features/core.ex`

**Router injection pattern** ([lib/sigra/install/features/core.ex:340](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex#L340)):
```elixir
  defp router_injection(otp_app, web_module, live?) do
    ...
    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra authentication",
      anchor: :before_last_end,
      content: content
    }
  end
```

**Current passkey routes to gate/move** ([lib/sigra/install/features/core.ex:468](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex#L468)):
```elixir
      scope "/users", #{web_module} do
        pipe_through [:browser]
    #{mfa_challenge_routes}
        post "/mfa/passkey", SessionController, :complete_mfa_passkey
        post "/mfa/passkey/options", SessionController, :passkey_mfa_options
      end
...
        post "/log_in/passkey", SessionController, :complete_passkey
        post "/log_in/passkey/options", SessionController, :passkey_authentication_options
...
        post "/settings/mfa/passkeys/options", SessionController, :passkey_registration_options
        post "/settings/mfa/passkeys", SessionController, :complete_passkey_registration
        post "/settings/mfa/passkeys/:id/delete", SessionController, :delete_passkey
```

**Config injection pattern** ([lib/sigra/install/features/core.ex:514](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex#L514)):
```elixir
  defp config_injection(otp_app, context_module, schema_alias, repo_module) do
    content = """

    # Sigra authentication
    config :#{otp_app}, :sigra,
      repo: #{repo_module},
      user_schema: #{context_module}.#{schema_alias}
```

**Instruction-summary pattern** ([lib/sigra/install/features/core.ex:671](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex#L671)):
```elixir
  defp base_instruction_block(opts) do
    ...
    """

    Sigra authentication has been installed!
```

**Use this for:** removing passkey-only router/config/reporting from Core, keeping shared auth wiring in place, and adding `passkeys?` to the binding/summary flow without creating a second manifest system.

---

### Shared core templates (`auth.ex`, `session_controller.ex`, `login_html.ex`, `mfa_settings_live.ex`, `mfa_challenge_live.ex`, `registration_html.ex`, `confirmation_controller.ex`)

**Analog for local feature guards:** `priv/templates/sigra.install/core/scope.ex`

**Canonical local-guard pattern** ([priv/templates/sigra.install/core/scope.ex:28](/Users/jon/projects/sigra/priv/templates/sigra.install/core/scope.ex#L28)):
```eex
  @type t :: %__MODULE__{
          user: %<%= schema_alias %>{} | nil,
<%= if organizations? do %>
          active_organization: %<%= context_module %>.Organization{} | nil,
          membership: %<%= context_module %>.OrganizationMembership{} | nil,
<% else %>
          active_organization: nil,
          membership: nil,
<% end %>
          impersonating_from: %<%= schema_alias %>{} | nil
        }
```

**Fallback branch pattern when a feature is disabled** ([priv/templates/sigra.install/core/error_handler.ex:41](/Users/jon/projects/sigra/priv/templates/sigra.install/core/error_handler.ex#L41)):
```eex
<%= if organizations? do %>
  def auth_error(conn, :no_active_org, _opts) do
    conn
    |> put_flash(:info, "Pick or create an organization to continue.")
    |> redirect(to: ~p"/organizations")
  end
<% else %>
  def auth_error(conn, :no_active_org, _opts) do
    redirect(conn, to: ~p"/")
  end
<% end %>
```

**Passkey-heavy regions currently present:**
- `auth.ex`: aliases and wrappers ([priv/templates/sigra.install/core/auth.ex:588](/Users/jon/projects/sigra/priv/templates/sigra.install/core/auth.ex#L588), [priv/templates/sigra.install/core/auth.ex:648](/Users/jon/projects/sigra/priv/templates/sigra.install/core/auth.ex#L648))
- `session_controller.ex`: passkey options/completion endpoints ([priv/templates/sigra.install/core/session_controller.ex:70](/Users/jon/projects/sigra/priv/templates/sigra.install/core/session_controller.ex#L70))
- `login_html.ex`: passkey-primary branch and inline JS ([priv/templates/sigra.install/core/login_html.ex:31](/Users/jon/projects/sigra/priv/templates/sigra.install/core/login_html.ex#L31))
- `mfa_settings_live.ex`: passkey section renderer ([priv/templates/sigra.install/core/mfa_settings_live.ex:242](/Users/jon/projects/sigra/priv/templates/sigra.install/core/mfa_settings_live.ex#L242))
- `mfa_challenge_live.ex`: passkey-first challenge UI/hook ([priv/templates/sigra.install/core/mfa_challenge_live.ex:59](/Users/jon/projects/sigra/priv/templates/sigra.install/core/mfa_challenge_live.ex#L59))
- `registration_html.ex`: signup-time passkey opt-in ([priv/templates/sigra.install/core/registration_html.ex:30](/Users/jon/projects/sigra/priv/templates/sigra.install/core/registration_html.ex#L30))
- `confirmation_controller.ex`: `enroll_passkey` follow-through ([priv/templates/sigra.install/core/confirmation_controller.ex:49](/Users/jon/projects/sigra/priv/templates/sigra.install/core/confirmation_controller.ex#L49))

**Use this for:** keeping one canonical template file and wrapping only passkey-only aliases, assigns, actions, helpers, and UI branches with `passkeys?`.

---

### `test/sigra/install/features/passkeys_test.exs` (test, transform)

**Analog:** `test/sigra/install/features/organizations_test.exs`

**Enabled/default contract pattern** ([test/sigra/install/features/organizations_test.exs:25](/Users/jon/projects/sigra/test/sigra/install/features/organizations_test.exs#L25), [test/sigra/install/features/passkeys_test.exs:6](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_test.exs#L6)):
```elixir
  describe "enabled?/1" do
    test "returns true by default (ORG-01)" do
      assert Organizations.enabled?([]) == true
    end
```

```elixir
  describe "enabled?/1" do
    test "is opt-in" do
      refute Passkeys.enabled?([])
      assert Passkeys.enabled?(passkeys: true)
      refute Passkeys.enabled?(passkeys: false)
    end
  end
```

**Manifest-shape assertion pattern** ([test/sigra/install/features/passkeys_test.exs:14](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_test.exs#L14)):
```elixir
  test "emits the user_passkey schema plus passkey browser assets" do
    assert [
             {:eex, "passkeys/user_passkey.ex", "lib/my_app/accounts/user_passkey.ex"},
             {:eex, "passkeys/passkey_browser.js", "assets/js/passkey_browser.js"},
             {:eex, "passkeys/passkey_hooks.js", "assets/js/passkey_hooks.js"}
           ] = Passkeys.files(otp_app: :my_app, context_alias: "Accounts")
  end
```

**Use this for:** flipping default-on semantics, adding passkey-owned router/dependency/package injections, and asserting omission ownership at the feature-manifest level.

---

### `test/sigra/install/features/passkeys_js_test.exs` (test, file-I/O)

**Analog:** `test/sigra/install/features/passkeys_js_test.exs`

**Marker/idempotency harness** ([test/sigra/install/features/passkeys_js_test.exs:8](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs#L8), [test/sigra/install/features/passkeys_js_test.exs:33](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs#L33)):
```elixir
  @passkey_import ~s(import { PasskeyHooks } from "./passkey_hooks")
  @passkey_hooks_line ~s(hooks: { ...colocatedHooks, ...PasskeyHooks })
  @passkey_start_marker "// Sigra passkeys:start"
  @passkey_end_marker "// Sigra passkeys:end"
```

```elixir
  test "rerunning install keeps a single passkey marker block" do
    ...
    assert count_occurrences(app_js, @passkey_start_marker) == 1
    assert count_occurrences(app_js, @passkey_end_marker) == 1
  end
```

**Manual-fallback assertion pattern** ([test/sigra/install/features/passkeys_js_test.exs:65](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs#L65)):
```elixir
  test "leaves non-standard app.js untouched and prints exact manual instructions" do
    ...
    assert InstallFixture.read_asset_file(app_dir, "js/app.js") == custom_app_js
    assert stdout =~ @passkey_import
    assert stdout =~ @passkey_hooks_line
  end
```

**Use this for:** new `mix.exs` / `assets/package.json` blessed-path edit tests and exact manual-action fallback assertions.

---

### `test/sigra/install/features/coverage_test.exs` (test, transform)

**Analog:** `test/sigra/install/features/coverage_test.exs`

**Feature-ownership sweep** ([test/sigra/install/features/coverage_test.exs:65](/Users/jon/projects/sigra/test/sigra/install/features/coverage_test.exs#L65), [test/sigra/install/features/coverage_test.exs:137](/Users/jon/projects/sigra/test/sigra/install/features/coverage_test.exs#L137)):
```elixir
  @injection_whitelist %{
    Sigra.Install.Features.Core => [],
    Sigra.Install.Features.Organizations => [
      "organizations/router_injection.ex"
    ],
    Sigra.Install.Features.Passkeys => []
  }
```

```elixir
  @features [
    {Sigra.Install.Features.Core, "core"},
    {Sigra.Install.Features.Organizations, "organizations"},
    {Sigra.Install.Features.Passkeys, "passkeys"}
  ]
```

**Use this for:** registering any new passkey injection templates or documenting cross-feature drift if a passkey-related file intentionally stays outside `files/1`.

---

### `test/sigra/install/generator_passkeys_foundation_test.exs` and `test/sigra/install/generator_passkey_management_test.exs` (test, transform)

**Analog:** self

**Template-contract pattern** ([test/sigra/install/generator_passkeys_foundation_test.exs:41](/Users/jon/projects/sigra/test/sigra/install/generator_passkeys_foundation_test.exs#L41)):
```elixir
  test "contains passkey wrapper and discoverable-auth functions" do
    content = read_core_template("auth.ex")
    assert content =~ "alias <%= context_module %>.UserPasskey"
    assert content =~ "def passkeys_for_user(user)"
    ...
  end
```

**Route-contract pattern** ([test/sigra/install/generator_passkeys_foundation_test.exs:144](/Users/jon/projects/sigra/test/sigra/install/generator_passkeys_foundation_test.exs#L144)):
```elixir
  test "injects sudo pipeline and passkey POST routes" do
    source = File.read!(@features_core_path)
    for expected <- [
          "post \"/log_in/passkey\", SessionController, :complete_passkey",
          ...
        ] do
      assert source =~ expected
    end
  end
```

**Passkey-management surface assertions** ([test/sigra/install/generator_passkey_management_test.exs:6](/Users/jon/projects/sigra/test/sigra/install/generator_passkey_management_test.exs#L6)):
```elixir
  test "renders the passkeys card with exact enrollment and empty-state copy" do
    content = read_core_template("mfa_settings_live.ex")
    assert content =~ ~s(id="passkeys")
    ...
  end
```

**Use this for:** converting existing presence assertions into gated/omission assertions when `passkeys?` is false.

---

### `.github/workflows/ci.yml` (config, batch)

**Analog:** `.github/workflows/ci.yml`

**Matrix pattern** ([.github/workflows/ci.yml:198](/Users/jon/projects/sigra/.github/workflows/ci.yml#L198)):
```yaml
  install_matrix:
    name: Install matrix (flag combinations)
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        flags:
          - ""
          - "--no-organizations"
```

**Shared harness invocation** ([.github/workflows/ci.yml:246](/Users/jon/projects/sigra/.github/workflows/ci.yml#L246), [.github/workflows/ci.yml:270](/Users/jon/projects/sigra/.github/workflows/ci.yml#L270)):
```yaml
      - name: Scaffold fresh Phoenix app
        run: mix phx.new tmp_app --no-assets --no-install
...
      - name: Run Sigra installer
        run: mix sigra.install Accounts User users ${{ matrix.flags }} --yes
```

**Use this for:** expanding to the four-way matrix and adding a second, assets-enabled omission harness instead of bloating the existing no-assets smoke.

## Shared Patterns

### Feature-owned whole artifacts
**Source:** [lib/sigra/install/features/organizations.ex](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex#L40)

Copy the organizations shape for passkey-only files, migrations, and router injection blocks: `enabled?/1` gates the entire feature; `files/1` lists only owned artifacts; `injections/1` emits standalone `%Injection{}` records.

### Local guards inside canonical templates
**Source:** [priv/templates/sigra.install/core/scope.ex](/Users/jon/projects/sigra/priv/templates/sigra.install/core/scope.ex#L30), [priv/templates/sigra.install/core/error_handler.ex](/Users/jon/projects/sigra/priv/templates/sigra.install/core/error_handler.ex#L41)

Use `<%= if passkeys? do %>` around passkey-only aliases, types, helpers, UI sections, and route follow-through. Keep the rest of the template canonical.

### Deterministic injection + manual fallback
**Source:** [lib/sigra/install/features/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex#L38), [test/sigra/install/features/passkeys_js_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs#L65)

Blessed-path file edit first; if the host file is non-standard, leave it untouched and emit exact manual instructions that tests assert verbatim.

### Ownership/coverage lint
**Source:** [test/sigra/install/features/coverage_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/coverage_test.exs#L147)

Any new template or injection fragment added for passkeys must either be returned by `files/1`/`migrations/1` or be whitelisted as an injection template.

## No Analog Found

None.

## Metadata

**Analog search scope:** `lib/mix/tasks`, `lib/sigra/install`, `priv/templates/sigra.install`, `test/sigra/install`, `.github/workflows`
**Files scanned:** 24
**Pattern extraction date:** 2026-04-16
