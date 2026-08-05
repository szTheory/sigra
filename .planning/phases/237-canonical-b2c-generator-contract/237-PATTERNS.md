# Phase 237: Canonical B2C Generator Contract - Pattern Map

**Mapped:** 2026-08-04  
**Files analyzed:** 2  
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/ci/passkeys-opt-out-smoke.sh` | test / CI smoke script | batch, file-I/O, request-response | `scripts/ci/passkeys-default-smoke.sh` and its existing B2C leg | exact lifecycle / existing target |
| `test/sigra/install/generator_passkeys_opt_out_test.exs` | test | batch, file-I/O | `test/sigra/install/oauth_generator_test.exs` and its existing parameterized opt-out cases | exact generated-contract / existing target |

## Pattern Assignments

### `scripts/ci/passkeys-opt-out-smoke.sh` (test / CI smoke script, batch + file-I/O + request-response)

**Primary analog:** `scripts/ci/passkeys-opt-out-smoke.sh` itself, lines 32-183. This is the authoritative three-leg fresh-Phoenix harness and must be extended in place. `scripts/ci/passkeys-default-smoke.sh` lines 32-150 confirms the same helper, failure, assets, migration, and bounded-boot conventions for an assets-enabled host.

**Assertion helper pattern** — `scripts/ci/passkeys-opt-out-smoke.sh:32-59`:

```bash
assert_file_missing() {
  local path="$1"

  if [[ -e "${path}" ]]; then
    echo "FAIL: expected file to be absent: ${path}"
    exit 1
  fi
}

assert_no_match() {
  local pattern="$1"
  local path="$2"

  if rg -n "${pattern}" "${path}" >/dev/null 2>&1; then
    echo "FAIL: unexpected match for pattern ${pattern} in ${path}"
    rg -n "${pattern}" "${path}" || true
    exit 1
  fi
}
```

Add positive OAuth checks with the adjacent `assert_file_present` helper (lines 52-59), and negative B2C checks with `assert_file_missing` / `assert_no_match`. Keep individual, feature-owned sentinels; do not add a broad tree-wide `admin` or `organization` ban.

**Canonical install → OAuth sequence** — `scripts/ci/passkeys-opt-out-smoke.sh:119-149`:

```bash
# shellcheck disable=SC2086 # flags are fixed literals supplied below.
MIX_ENV=dev mix sigra.install Accounts User users ${flags} --yes

if [[ "${label}" == "sigra_b2c_alpha" ]]; then
  add_cloak_ecto
  mix deps.get
  MIX_ENV=dev mix sigra.gen.oauth --providers google

  assert_file_present "lib/${label}/accounts/user_identity.ex"
  assert_file_present "lib/${label}_web/controllers/oauth_controller.ex"
  assert_file_present "lib/${label}_web/controllers/oauth_buttons.html.heex"
  assert_file_present "lib/${label}/vault.ex"
fi
```

Retain the fixed-literal flags plus the local direct `cloak_ecto` insertion. Expand this B2C-only block immediately after generation with all generator-owned OAuth files/injections and all admin/organization/passkey ownership sentinels. Do not move the OAuth generation before install.

**Fresh-host completion and error handling** — `scripts/ci/passkeys-opt-out-smoke.sh:152-183`:

```bash
MIX_ENV=dev mix compile --warnings-as-errors
MIX_ENV=dev mix assets.deploy
MIX_ENV=dev mix ecto.drop || true
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate

PHX_SERVER=true MIX_ENV=dev PORT="${port}" mix phx.server > "/tmp/${label}-server.log" 2>&1 &
local server_pid=$!
trap 'kill ${server_pid} 2>/dev/null || true' RETURN

for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${port}/" > /dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
    trap - RETURN
    return 0
  fi
  # On attempt 30, print the server log and exit 1; otherwise sleep one second.
done
```

Preserve this lifecycle verbatim: no fixed port, no unbounded wait, and no credentials besides the existing non-secret `CLOAK_KEY` environment default. Assertions belong before the compile/build/migration/boot proof so regressions fail with a specific generated-host diagnostic.

---

### `test/sigra/install/generator_passkeys_opt_out_test.exs` (test, batch + file-I/O)

**Primary analog:** `test/sigra/install/generator_passkeys_opt_out_test.exs:9-155`. It already parameterizes installer flag cases, scaffolds an isolated Phoenix host through `InstallFixture`, checks generated files and text ownership surfaces, and locks the smoke script contract. Use `test/sigra/install/oauth_generator_test.exs:8-139` for exact OAuth route/config injection strings.

**Fixture lifecycle and cleanup pattern** — `test/sigra/install/generator_passkeys_opt_out_test.exs:38-54`:

```elixir
for %{label: label, flags: flags} = install_case <- @cases do
  @tag flags: flags
  @tag b2c_alpha?: Map.get(install_case, :b2c_alpha?, false)
  test "#{label} omits passkey routes, files, dependencies, and residue", %{
    flags: flags,
    b2c_alpha?: b2c_alpha?
  } do
    {:ok, %{app_dir: app_dir}} =
      InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name())

    on_exit(fn -> File.rm_rf(Path.dirname(app_dir)) end)

    assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, flags)
    assert {:ok, _stdout} =
             InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
```

Keep the B2C assertions inside `if b2c_alpha?`, so passkey-only legs remain focused. The fixture test complements the shell smoke; it does not replace its assets build, PostgreSQL migration, or HTTP boot proof.

**Feature-owned generated-host absence pattern** — `test/sigra/install/generator_passkeys_opt_out_test.exs:56-99`:

```elixir
refute File.exists?(Path.join(app_dir, "assets/js/passkey_hooks.js"))
refute migration_present?(app_dir, "*_create_user_passkeys.exs")

router = File.read!(Path.join(app_dir, "lib/#{otp_app(app_dir)}_web/router.ex"))
mix_exs = File.read!(Path.join(app_dir, "mix.exs"))
config_exs = File.read!(Path.join(app_dir, "config/config.exs"))

refute router =~ "/users/log_in/passkey"
refute mix_exs =~ "{:wax_, \"~> 0.7\"}"
refute config_exs =~ "passkeys:"

if b2c_alpha? do
  refute router =~ "/admin"
  refute router =~ "/organizations"
  refute File.exists?(Path.join(app_dir, "lib/#{otp_app(app_dir)}_web/components/admin_shell.ex"))
  refute File.exists?(Path.join(app_dir, "lib/#{otp_app(app_dir)}/accounts/organization.ex"))
end
```

Extend the B2C branch using file and migration basenames actually owned by each disabled feature (listed in Shared Patterns), plus router markers. Prefer explicit `refute File.exists?`, `refute migration_present?`, and text assertions over a generic vocabulary ban, which can false-positive on legitimate core comments.

**Smoke source-lock pattern** — `test/sigra/install/generator_passkeys_opt_out_test.exs:113-122`:

```elixir
test "fresh-host smoke locks the B2C Alpha generator command and Google OAuth output" do
  source = File.read!("scripts/ci/passkeys-opt-out-smoke.sh")

  assert source =~ "--no-admin --no-organizations --no-passkeys"
  assert source =~ "mix sigra.gen.oauth --providers google"
  assert source =~ "sigra_b2c_alpha"
  assert source =~ "oauth_controller.ex"
  assert source =~ "assert_no_match '/admin'"
  assert source =~ "assert_no_match '/organizations'"
end
```

Update this lightweight source contract only for the newly required stable assertion strings. Its role is to prevent silent weakening or removal of the authoritative full smoke, not to duplicate every runtime assertion.

**OAuth injection contract to mirror** — `test/sigra/install/oauth_generator_test.exs:22-36, 97-105, 142-145`:

```elixir
# Sigra OAuth
scope "/auth", MyAppWeb do
  pipe_through [:browser]

  get "/:provider", OAuthController, :request
  get "/:provider/callback", OAuthController, :callback
end

assert String.contains?(injected, "Sigra OAuth providers")
assert String.contains?(injected, "MyApp.Vault")
```

In the B2C fixture case, add `cloak_ecto` through the fixture’s existing dependency helper (do not hand-edit a generated host from the test), run `mix sigra.gen.oauth --providers google`, then assert the emitted paths and the router/config/application injection content. Maintain `async: false`, `@moduletag :scaffold`, and the 180-second timeout.

## Shared Patterns

### Feature-owned optional-surface sentinels

**Sources:** `lib/sigra/install/features/passkeys.ex:19-105`, `lib/sigra/install/features/organizations.ex:40-95,183-255`, `lib/sigra/install/features/admin.ex:26-83,115-121`  
**Apply to:** both B2C branches in the shell smoke and fixture contract.

```elixir
# Passkeys owns these generated files, migration, routes, configuration, and dependencies.
{:eex, "passkeys/user_passkey.ex", ...}
{:eex, "passkeys/passkey_browser.js", ...}
{:eex, "passkeys/passkey_hooks.js", ...}
{:user_passkeys, "passkeys/create_user_passkeys.exs", "create_user_passkeys.exs"}
marker: "# Sigra passkeys"
marker: ~s({:wax_, "~> 0.7"})
marker: ~s("@simplewebauthn/browser")

# Organizations owns organization source/migrations and its router marker.
{:eex, "organizations/organization.ex", ...}
{:eex, "organizations/migration.exs", ... "create_organizations.exs"}
marker: "# Sigra organizations"

# Admin owns its shell/access files, admin migration, static assets, and marker.
{:eex, "admin/admin_access.ex", Path.join(["lib", otp_app, "sigra_admin_access.ex"])}
{:eex, "admin/components/admin_shell.ex", ...}
{:eex, "admin/sigra_admin.css", Path.join(["priv", "static", "assets", "sigra_admin.css"])}
{:platform_admin_grants, "admin/create_platform_admin_grants.exs", "create_platform_admin_grants.exs"}
marker: "# Sigra admin"
```

Use the marker plus a representative file and migration per feature; for passkeys retain assets, dependency, and config assertions because that feature owns those extra surfaces. For admin, assert `sigra_admin_access.ex`, `admin_shell.ex`, `*_create_platform_admin_grants.exs`, `priv/static/assets/sigra_admin.css`, and the router marker/path. For organizations, assert `organization.ex`, `*_create_organizations.exs`, and its router marker/path; it has no standalone JS dependency or config injection to assert.

### OAuth positive emission contract

**Source:** `lib/mix/tasks/sigra.gen.oauth.ex:114-176,241-316`  
**Apply to:** the B2C-only branch after `mix sigra.gen.oauth --providers google`.

```elixir
files = [
  {:eex, "oauth_migration.exs", migration_path},
  {:eex, "user_identity.ex", ...},
  {:eex, "oauth_controller.ex", ...},
  {:eex, "oauth_html.ex", ...},
  {:eex, "oauth_buttons.html.heex", ...}
]

vault_files = [
  {:eex, "vault.ex", vault_path},
  {:eex, "encrypted_binary.ex", encrypted_path}
]

# Sigra OAuth
scope "/auth", #{web_module} do
  pipe_through [:browser]
  get "/:provider", OAuthController, :request
  get "/:provider/callback", OAuthController, :callback
end
```

Require `user_identity.ex`, `vault.ex`, `encrypted/binary.ex`, `oauth_controller.ex`, `oauth_html.ex`, `oauth_buttons.html.heex`, and `*_create_user_identities.exs`; then assert `# Sigra OAuth`, both controller routes, `# Sigra OAuth providers`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and the generated vault child in `application.ex`. This is the positive counterpart to the disabled-feature checks.

### Isolated host and bounded boot probe

**Sources:** `scripts/ci/passkeys-opt-out-smoke.sh:61-93,152-183`; `scripts/ci/lib/free-port.sh:7-14`  
**Apply to:** keep unchanged while adding assertions.

```bash
local port="${!env_name:-$(find_free_port)}"
PHX_SERVER=true MIX_ENV=dev PORT="${port}" mix phx.server > "/tmp/${label}-server.log" 2>&1 &
trap 'kill ${server_pid} 2>/dev/null || true' RETURN

for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${port}/" > /dev/null; then
    return 0
  fi
done
```

Keep the local Sigra path-dependency patch anchor, direct `cloak_ecto` insertion, non-secret dummy `CLOAK_KEY`, free-port helper, process cleanup, and 30-attempt log-producing readiness probe.

## No Analog Found

None. Phase 237 extends two current, recently introduced (`0a939ff8`, 2026-08-04) generated-host contract artifacts. No new production module, configuration file, migration, or test harness is required.

## Metadata

**Analog search scope:** `scripts/ci/`, `scripts/ci/lib/`, `test/sigra/install/`, `test/support/`, `lib/mix/tasks/`, `lib/sigra/install/features/`  
**Files scanned:** 12  
**Pattern extraction date:** 2026-08-04
