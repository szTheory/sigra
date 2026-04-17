# Phase 32: Generated Installer Admin Surface Parity - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 6 (3 modify, 1 create, 2 test modify/create)
**Analogs found:** 6 / 6 (every file has at least a role-match; most are exact)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/install/features/admin.ex` (MODIFY) | feature-manifest module (Install.Feature behaviour) | transform (binding -> file tuples + injections) | `lib/sigra/install/features/passkeys.ex` (multi-file `files/1`); self (preserve shape) | exact |
| `priv/templates/sigra.install/admin/router_injection.ex` (MODIFY) | EEx router-injection template | text transform at install time; injected into host `router.ex` | self (surgical additions); mirror `test/example/lib/example_web/router.ex:217-274` | exact |
| `priv/templates/sigra.install/admin/impersonation_controller.ex` (CREATE) | EEx controller template -> host Phoenix controller | request-response (POST create, DELETE stop) | `test/example/lib/example_web/controllers/admin/impersonation_controller.ex` (proven reference); `priv/templates/sigra.install/admin/audit_export_controller.ex` (EEx parameterization) | exact |
| `test/sigra/install/features/admin_test.exs` (MODIFY) | generator unit test (ExUnit, async) | test (EEx render + assertion) | self (extend `files/1` / template guards blocks); `test/sigra/install/features/passkeys_test.exs` (multi-file `files/1` assertion) | exact |
| `test/sigra/install/router_injection_test.exs` (CREATE, optional) | generator unit test (EEx render + string grep) | test | New `describe` block **inside** `admin_test.exs` is the stronger convention — see "Decisions" below | role-match |
| `scripts/ci/admin-acceptance-smoke.sh` (MODIFY) | bash CI smoke driver (fresh Phoenix scaffold + boot + curl probes) | request-response HTTP probe | self — extend `gen_expect_non_5xx` + `GENERATED_HOST_AUDIT_ROUTES` pattern | exact |

**Decision on router_injection_test.exs file:** The existing convention in this repo is to keep all admin-feature template assertions **inside `test/sigra/install/features/admin_test.exs`** (see the existing `describe "injections/1"` block that already asserts router content). There is no standalone `router_injection_test.exs` anywhere in `test/sigra/install/`; creating one would break convention. Recommend the planner add new `describe` blocks to `admin_test.exs` instead, and skip the standalone file.

## Pattern Assignments

### `lib/sigra/install/features/admin.ex` (feature-manifest module, transform)

**Analog:** `lib/sigra/install/features/admin.ex` itself (self-extension) + `lib/sigra/install/features/passkeys.ex` (multi-file `files/1` shape).

**Imports / module-header pattern** (admin.ex:1-20) — preserve as-is:
```elixir
defmodule Sigra.Install.Features.Admin do
  @moduledoc """ ... """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection
```

**`files/1` tuple-list pattern** (admin.ex:26-35 current → target state):
```elixir
# CURRENT
@impl true
def files(binding) do
  otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
  web = "#{otp_app}_web"

  [
    {:eex, "admin/policy.ex", Path.join(["lib", otp_app, "sigra_admin_policy.ex"])},
    {:eex, "admin/components/admin_shell.ex",
     Path.join(["lib", web, "components", "admin_shell.ex"])}
  ]
end

# TARGET (add two tuples)
def files(binding) do
  otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
  web = "#{otp_app}_web"

  [
    {:eex, "admin/policy.ex", Path.join(["lib", otp_app, "sigra_admin_policy.ex"])},
    {:eex, "admin/components/admin_shell.ex",
     Path.join(["lib", web, "components", "admin_shell.ex"])},
    {:eex, "admin/impersonation_controller.ex",
     Path.join(["lib", web, "controllers", "admin", "impersonation_controller.ex"])},
    {:eex, "admin/audit_export_controller.ex",
     Path.join(["lib", web, "controllers", "admin", "audit_export_controller.ex"])}
  ]
end
```

**Multi-file `files/1` reference** (passkeys.ex:19-30) — same `Path.join` + `{:eex, source, target}` shape:
```elixir
def files(binding) do
  otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
  context_slug = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

  [
    {:eex, "passkeys/user_passkey.ex",
     Path.join(["lib", otp_app, context_slug, "user_passkey.ex"])},
    {:eex, "passkeys/passkey_browser.js", Path.join(["assets", "js", "passkey_browser.js"])},
    ...
  ]
end
```

**What NOT to touch:** `enabled?/1`, `injections/1`, `migrations/1`, `post_instructions/2`, and the private helpers `router_injection/2`, `layouts_import_injection/2`, `layouts_admin_injection/1`, `error_handler_injection/3`, `eval_template!/2`, `read_template!/1`. Phase 32 is `files/1`-only within this module.

---

### `priv/templates/sigra.install/admin/router_injection.ex` (EEx router-injection template)

**Analog:** Self (surgical additions) + mirror `test/example/lib/example_web/router.ex:237-238` and `:269-271`.

**Current shape** (router_injection.ex:28-38, global live_session):
```elixir
    live_session :admin_global,
      layout: {<%= web_module %>.Layouts, :admin},
      on_mount: [
        {<%= web_module %>.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [mode: :global, policy: <%= app_module %>.SigraAdminPolicy, login_path: "/users/log_in"]}
      ] do
      live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index
      live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
      live "/admin/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show
    end
```

**Required additions** (two lines in global block, two in organization block):
```elixir
# Global block — insert between /admin/audit and /admin/users/:id/audit:
      live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
      live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show

# Organization block (router_injection.ex:63-67) — insert between /audit and /users/:id/audit:
      live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
      live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
```

**Reference (the example router already has these):**
- `test/example/lib/example_web/router.ex:237-238` (global)
- `test/example/lib/example_web/router.ex:269,271` (org-scoped; note the instructive `# Mounted at /admin/organizations/:org/users` comment above each)

**Anchor order invariant:** The two new lines MUST sit between the existing `AuditIndexLive` and `AuditUserLive` lines in both blocks, preserving URL-shape alphabetical ordering (`/admin/users` before `/admin/users/:id/audit`).

---

### `priv/templates/sigra.install/admin/impersonation_controller.ex` (EEx controller template, NEW)

**Analog:** `test/example/lib/example_web/controllers/admin/impersonation_controller.ex` (proven reference, 143 lines) + `priv/templates/sigra.install/admin/audit_export_controller.ex` (EEx parameterization conventions).

**Module-header parameterization pattern** (from audit_export_controller.ex:1-8):
```elixir
defmodule <%= web_module %>.Admin.AuditExportController do
  @moduledoc """
  Thin controller seam for admin audit CSV downloads.
  """

  use <%= web_module %>, :controller

  alias <%= app_module %>.Accounts
```

**Parameterization mapping table** (mandatory, from research Pitfall 4):

| Example app literal | EEx replacement |
|---------------------|-----------------|
| `ExampleWeb` | `<%= web_module %>` |
| `ExampleWeb.Admin.ImpersonationController` | `<%= web_module %>.Admin.ImpersonationController` |
| `ExampleWeb.AuthErrorHandler` | `<%= web_module %>.AuthErrorHandler` |
| `ExampleWeb.UserAuth` | `<%= web_module %>.UserAuth` |
| `Example.Accounts` (alias + uses) | `<%= context_module %>` |
| `Example.Accounts.Scope` | `<%= context_module %>.Scope` |
| `Example.Organizations` | `<%= app_module %>.Organizations` |
| `Accounts.get_user!`, `Accounts.sigra_config` (post-alias bare usage) | keep bare `Accounts.get_user!` / `Accounts.sigra_config` — the `alias <%= context_module %>` at the top resolves `Accounts` correctly in every host |

**Imports pattern** (example:6-12):
```elixir
use ExampleWeb, :controller           # -> use <%= web_module %>, :controller

import Plug.Conn

alias Example.Accounts                 # -> alias <%= context_module %>
alias ExampleWeb.AuthErrorHandler      # -> alias <%= web_module %>.AuthErrorHandler
alias ExampleWeb.UserAuth              # -> alias <%= web_module %>.UserAuth
@sudo_window 300
```

**Core `create/2` pattern** (example:15-62) — copy verbatim except module-name substitutions:
```elixir
def create(conn, %{"id" => user_id} = params) do
  admin_scope = conn.assigns.admin_scope
  admin_session = conn.private[:sigra_session]
  admin_token = get_session(conn, :user_token)
  target_user = impersonation_target(user_id)

  if sudo_fresh?(admin_session) do
    case Sigra.Impersonation.start(
           impersonation_config(),
           admin_scope,
           admin_session,
           target_user,
           admin_token: admin_token,
           ip_address: client_ip(conn),
           user_agent: client_user_agent(conn)
         ) do
      {:ok, %{session: session}} ->
        conn
        |> UserAuth.begin_impersonation(session.token, admin_token,
          return_to: safe_return_to(Map.get(params, "return_to"))
        )
        |> put_flash(:info, "Impersonation started.")
        |> redirect(to: ~p"/")

      {:error, :not_allowed} ->
        conn |> AuthErrorHandler.auth_error(:not_found, []) |> halt()

      {:error, :already_impersonating} ->
        conn
        |> put_flash(:error, "End the current impersonation session before starting another one.")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "We couldn't start impersonation.")
        |> redirect(to: ~p"/")
    end
  else
    conn
    |> put_flash(:error, "Please re-enter your password to continue.")
    |> redirect(to: sudo_path(conn, params))
  end
end
```

**Core `delete/2` pattern** (example:64-92) — copy verbatim except module-name substitutions:
```elixir
def delete(conn, params) do
  current_scope = conn.assigns.current_scope
  current_session = conn.private[:sigra_session]
  admin_token = get_session(conn, :impersonator_user_token)

  case {current_scope, current_session, admin_token} do
    {%{impersonating_from: %_{}} = scope, %Sigra.Session{} = session, admin_token}
    when is_binary(admin_token) ->
      {:ok, _result} =
        Sigra.Impersonation.stop(impersonation_config(), scope, session,
          admin_token: admin_token,
          ip_address: client_ip(conn),
          user_agent: client_user_agent(conn))

      conn
      |> UserAuth.restore_impersonation()
      |> put_flash(:info, "Impersonation ended.")
      |> redirect(to: stop_return_to(conn, Map.get(params, "return_to")))

    _ ->
      conn
      |> put_flash(:error, "No impersonation session is active.")
      |> redirect(to: ~p"/")
  end
end
```

**Private helpers** (example:94-141) — copy verbatim, only `Example.Organizations` -> `<%= app_module %>.Organizations` and `Example.Accounts.Scope` -> `<%= context_module %>.Scope` translations:
```elixir
defp impersonation_target(user_id) do
  user = Accounts.get_user!(user_id)

  organization_ids =
    user
    |> <%= app_module %>.Organizations.list_organizations_for_user()
    |> Enum.map(fn {organization, _role} -> organization.id end)

  Map.put(user, :organization_ids, organization_ids)
end

defp stop_return_to(conn, requested_return_to) do
  case safe_return_to(requested_return_to) do
    nil -> UserAuth.impersonation_return_to(conn) || ~p"/"
    path -> path
  end
end

defp safe_return_to(path) when is_binary(path) do
  if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
    path
  end
end

defp safe_return_to(_path), do: nil

defp client_ip(conn), do: conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip))

defp client_user_agent(conn) do
  conn |> get_req_header("user-agent") |> List.first() || ""
end

defp impersonation_config do
  %{Accounts.sigra_config() | scope_module: <%= context_module %>.Scope}
end

defp sudo_fresh?(%Sigra.Session{sudo_at: %DateTime{} = sudo_at}) do
  DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= @sudo_window
end

defp sudo_fresh?(_session), do: false

defp sudo_path(conn, params) do
  return_to = current_path(conn, Map.take(params, ["return_to"]))
  "/users/sudo?return_to=#{URI.encode_www_form(return_to)}"
end
```

**Error handling pattern to preserve from example:** The `{:error, :not_allowed}` branch calls `AuthErrorHandler.auth_error(:not_found, [])` — this is **intentional enumeration prevention** (library emits `:not_allowed` but the UI returns `:not_found` so attackers can't distinguish "user exists but you can't impersonate" from "user does not exist"). Do NOT "fix" this to return `:forbidden`.

**Validation pattern (sudo-fresh gate):** The `@sudo_window 300` + `sudo_fresh?/1` + early redirect to `/users/sudo` is a boundary-condition guard and must copy verbatim. The window is 5 minutes by design (matches `Sigra.Session.sudo_at` semantics).

**Post-render grep guard** (test assertion):
- `refute content =~ "Example"` — zero literal `Example*` tokens after render
- `assert content =~ "defmodule MyAppWeb.Admin.ImpersonationController"`
- `assert content =~ "MyApp.Organizations.list_organizations_for_user"`

---

### `test/sigra/install/features/admin_test.exs` (generator unit test, extend)

**Analog:** Self (existing `describe "files/1"`, `describe "template ownership guards"` blocks) + `test/sigra/install/features/passkeys_test.exs:18-27` (multi-file `files/1` match pattern).

**Imports / header pattern** (admin_test.exs:1-4) — preserve:
```elixir
defmodule Sigra.Install.Features.AdminTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Admin
```

**Existing `files/1` assertion shape** (admin_test.exs:18-26) — extend, don't replace:
```elixir
describe "files/1" do
  test "owns the generated admin policy and shell boundary files" do
    assert [
             {:eex, "admin/policy.ex", "lib/my_app/sigra_admin_policy.ex"},
             {:eex, "admin/components/admin_shell.ex",
              "lib/my_app_web/components/admin_shell.ex"}
           ] = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")
  end
end
```

**Pattern for new assertions** (follow passkeys_test.exs:18-27 for list-shape matching; or use `in files` membership for tuple-subset matching):
```elixir
# Option A — full list match (brittle against reordering; matches existing style)
test "emits the full admin template set including impersonation and audit export" do
  assert [
           {:eex, "admin/policy.ex", "lib/my_app/sigra_admin_policy.ex"},
           {:eex, "admin/components/admin_shell.ex",
            "lib/my_app_web/components/admin_shell.ex"},
           {:eex, "admin/impersonation_controller.ex",
            "lib/my_app_web/controllers/admin/impersonation_controller.ex"},
           {:eex, "admin/audit_export_controller.ex",
            "lib/my_app_web/controllers/admin/audit_export_controller.ex"}
         ] = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")
end

# Option B — membership-based (more robust; recommended for Phase 32)
test "emits impersonation_controller template" do
  files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")
  assert {:eex, "admin/impersonation_controller.ex",
          "lib/my_app_web/controllers/admin/impersonation_controller.ex"} in files
end

test "emits audit_export_controller template" do
  files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")
  assert {:eex, "admin/audit_export_controller.ex",
          "lib/my_app_web/controllers/admin/audit_export_controller.ex"} in files
end
```

**Pattern for router template content grep** (admin_test.exs:48-55 already greps router content):
```elixir
# Existing shape to mirror — reads the injection, asserts .content =~ ...
assert router.content =~ "Sigra.Plug.RequireAdminAccess"
assert router.content =~ ~s(live "/admin")
```

**New router-mount assertions — rendered via `EEx.eval_string` over the template file** (new pattern, but a minimal helper):
```elixir
describe "router_injection.ex template (Phase 32 route mounts)" do
  @binding [
    otp_app: :my_app,
    web_module: "MyAppWeb",
    app_module: "MyApp",
    context_module: "MyApp.Accounts"
  ]

  test "mounts UsersIndexLive in global admin live_session" do
    assert render() =~ ~s|live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index|
  end

  test "mounts UserShowLive in global admin live_session" do
    assert render() =~ ~s|live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show|
  end

  test "mounts UsersIndexLive in organization-scoped live_session" do
    assert render() =~ ~s|live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index|
  end

  test "mounts UserShowLive in organization-scoped live_session" do
    assert render() =~ ~s|live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show|
  end

  defp render do
    "priv/templates/sigra.install/admin/router_injection.ex"
    |> File.read!()
    |> EEx.eval_string(@binding)
  end
end
```

**Pattern for "template exists on disk" guard** (admin_test.exs:73-79 — extend the existing block):
```elixir
describe "template ownership guards" do
  test "admin templates exist on disk" do
    assert File.exists?("priv/templates/sigra.install/admin/policy.ex")
    assert File.exists?("priv/templates/sigra.install/admin/router_injection.ex")
    assert File.exists?("priv/templates/sigra.install/admin/components/admin_shell.ex")
    # Phase 32 additions:
    assert File.exists?("priv/templates/sigra.install/admin/impersonation_controller.ex")
    assert File.exists?("priv/templates/sigra.install/admin/audit_export_controller.ex")
  end
end
```

**Pattern for "template renders cleanly" (new describe block — Phase 32):**
```elixir
describe "impersonation_controller template (Phase 32)" do
  test "renders with no literal Example references" do
    content =
      "priv/templates/sigra.install/admin/impersonation_controller.ex"
      |> File.read!()
      |> EEx.eval_string(
        web_module: "MyAppWeb",
        app_module: "MyApp",
        context_module: "MyApp.Accounts"
      )

    refute content =~ "Example", "template still contains literal 'Example' reference"
    refute content =~ "ExampleWeb", "template still contains literal 'ExampleWeb' reference"
    assert content =~ "defmodule MyAppWeb.Admin.ImpersonationController"
    assert content =~ "MyApp.Organizations.list_organizations_for_user"
    assert content =~ "Sigra.Impersonation.start("
    assert content =~ "Sigra.Impersonation.stop("
    assert content =~ "UserAuth.begin_impersonation"
    assert content =~ "UserAuth.restore_impersonation"
    assert content =~ ":impersonator_user_token"
  end
end
```

**Testing convention (from project CLAUDE.md):** "AAA style, flat, self-contained." Each new `test` block is independent; no shared setup mutation. The `@binding` module attribute and `defp render/0` helper are acceptable because they are read-only.

---

### `scripts/ci/admin-acceptance-smoke.sh` (bash CI smoke driver, extend)

**Analog:** Self — the existing `gen_expect_non_5xx` helper + `GENERATED_HOST_AUDIT_ROUTES` loop pattern at lines 243-271.

**Existing helper pattern** (smoke.sh:246-257):
```bash
gen_expect_non_5xx() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 5 \
    "http://localhost:${PORT}${path}")
  if [[ "${code}" -ge 500 ]]; then
    echo "FAIL: ${path} returned ${code} on generated host"
    GEN_PARITY_FAIL=1
  else
    echo "OK:   ${path} -> ${code}"
  fi
}
```

**Extension pattern — add `/admin/users` + `/admin/users/:id` to `GENERATED_HOST_AUDIT_ROUTES`** (smoke.sh:262-267):
```bash
# CURRENT
GENERATED_HOST_AUDIT_ROUTES=(
  "/admin/audit"
  "/admin/audit/export.csv"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit/export.csv"
)

# TARGET (add UsersIndexLive + UserShowLive probes)
GENERATED_HOST_AUDIT_ROUTES=(
  "/admin/audit"
  "/admin/audit/export.csv"
  "/admin/users"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit/export.csv"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/users"
)
```

**Note on `:id` routes:** `/admin/users/:id` and `/admin/users/:id/audit/export.csv` cannot be probed without a real seeded user ID. The existing smoke already seeds `SIGRA_PLATFORM_ADMIN_EMAIL` / `SIGRA_ORG_ADMIN_EMAIL` users; if a user-ID is needed, look for the pattern around lines 119-125 where those emails are stored. The minimal-viable probe is the index-only pair above, which already proves "route exists + no 5xx."

**Pattern for POST impersonation probe** (new — unauthenticated minimum, distinguishes "controller module exists" from "500 on undefined module"):
```bash
# After the GENERATED_HOST_AUDIT_ROUTES loop, add:
echo "==> admin-acceptance: probing impersonation controller emission"
imp_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "http://localhost:${PORT}/admin/users/00000000-0000-0000-0000-000000000000/impersonation")
# Expect redirect (302) or auth-error (403/404) — NOT 500 (would mean controller
# module is undefined). This asserts INT-02 closure at the routing+module level
# without needing authenticated session cookies in bash.
if [[ "${imp_code}" -ge 500 ]]; then
  echo "FAIL: POST /admin/users/.../impersonation returned ${imp_code} (controller module likely missing)"
  GEN_PARITY_FAIL=1
else
  echo "OK:   POST /admin/users/.../impersonation -> ${imp_code}"
fi
```

**Anti-pattern warning:** Do NOT write the probe as a full authenticated session flow in bash. The existing smoke offloads authenticated flows to the Playwright spec (`admin-generated.spec.ts`). A status-only "is module loadable?" probe is sufficient for Phase 32's Nyquist gate.

---

## Shared Patterns

### Shared Pattern 1: EEx binding contract

**Source:** `lib/mix/tasks/sigra.install.ex` (binding assembly) + consumed by every `admin/*.ex` template.

**Apply to:** `priv/templates/sigra.install/admin/impersonation_controller.ex` (NEW)

Every host-module reference in an admin template resolves through exactly these binding keys (verified against `audit_export_controller.ex` and `router_injection.ex`):

```elixir
<%= web_module %>       # e.g. "MyAppWeb" — the Phoenix web module
<%= app_module %>       # e.g. "MyApp"    — the host OTP app module
<%= context_module %>   # e.g. "MyApp.Accounts" — the Ecto context module
<%= otp_app %>          # e.g. :my_app   — atom/string OTP app name
```

**Never use:** `<%= if organizations? do %>` guards in admin templates — the existing `admin/router_injection.ex` already references `<%= app_module %>.Organizations` unconditionally. Admin implies organizations by convention.

### Shared Pattern 2: Feature callback signature (Install.Feature behaviour)

**Source:** `lib/sigra/install/feature.ex` (behaviour) + `lib/sigra/install/features/{core,organizations,passkeys,admin}.ex` (implementations).

**Apply to:** `lib/sigra/install/features/admin.ex` (MODIFY — preserve all five callbacks).

```elixir
@behaviour Sigra.Install.Feature

@impl true
def enabled?(opts), do: Keyword.get(opts, :admin, true)

@impl true
def files(binding), do: [...]   # list of {:eex, source, target} or {:text, source, target}

@impl true
def injections(binding), do: [...]  # list of %Injection{}

@impl true
def migrations(_binding), do: []

@impl true
def post_instructions(_binding, _report), do: [...]
```

### Shared Pattern 3: Generator-test describe-block convention

**Source:** `test/sigra/install/features/{admin,passkeys,organizations,core}_test.exs`.

**Apply to:** `test/sigra/install/features/admin_test.exs` (extend).

Canonical ordering of describe blocks (follow existing file order):
1. `describe "enabled?/1"`
2. `describe "files/1"`
3. `describe "migrations/1"`
4. `describe "injections/1"`
5. `describe "template ownership guards"`
6. `describe "Mix.Tasks.Sigra.Install admin surface"`

New Phase 32 blocks slot between (4) and (5): `describe "router_injection.ex template (Phase 32 route mounts)"` and `describe "impersonation_controller template (Phase 32)"`.

### Shared Pattern 4: Coverage test ownership

**Source:** `test/sigra/install/features/coverage_test.exs:103-144` (`@known_drift`).

**Apply to:** No explicit edit needed. `coverage_test.exs` currently declares `Sigra.Install.Features.Admin => []` in `@known_drift` (line 143). Once `files/1` owns both controllers, the coverage test automatically passes for admin — no allowlist maintenance required. The test will fail loudly if `files/1` omits either new template.

**Anti-pattern** (from research Pitfall 2): Do NOT add `admin/impersonation_controller.ex` or `admin/audit_export_controller.ex` to `@known_drift` — that would defeat the purpose of Phase 32.

### Shared Pattern 5: Enumeration-prevention error mapping

**Source:** `test/example/lib/example_web/controllers/admin/impersonation_controller.ex:39-41` + `lib/sigra/admin/authorizer.ex` (library-side).

**Apply to:** `priv/templates/sigra.install/admin/impersonation_controller.ex` (NEW).

The pattern: library returns `{:error, :not_allowed}` (authorization failure), but the controller surfaces it as `AuthErrorHandler.auth_error(:not_found, [])` — 404, not 403. This prevents attackers from distinguishing "user exists but I can't impersonate them" from "user does not exist."

```elixir
{:error, :not_allowed} ->
  conn
  |> AuthErrorHandler.auth_error(:not_found, [])
  |> halt()
```

Copy this branch verbatim; do not "improve" by returning 403.

---

## No Analog Found

*(none — every file in this phase has an existing close analog in the codebase)*

## Metadata

**Analog search scope:**
- `lib/sigra/install/features/` (feature manifest modules)
- `priv/templates/sigra.install/admin/` (admin templates)
- `priv/templates/sigra.install/core/` (reference for EEx parameterization)
- `test/sigra/install/features/` (generator test patterns)
- `test/sigra/install/` (general install test patterns)
- `test/example/lib/example_web/controllers/admin/` (reference controllers to parameterize)
- `test/example/lib/example_web/router.ex` (router mount reference)
- `scripts/ci/` (CI smoke patterns)

**Files scanned:** ~25 files read in full, ~10 files greped.

**Pattern extraction date:** 2026-04-17

---

## PATTERN MAPPING COMPLETE

**Phase:** 32 - Generated Installer Admin Surface Parity
**Files classified:** 6 (3 modify, 1 create, 2 test modify with one recommendation to merge into existing test file)
**Analogs found:** 6 / 6 (every file has a close analog; five are exact matches)

### Coverage
- Files with exact analog: 5 (`admin.ex` self + passkeys; `router_injection.ex` self; `impersonation_controller.ex` example mirror; `admin_test.exs` self; `admin-acceptance-smoke.sh` self)
- Files with role-match analog: 1 (`router_injection_test.exs` — recommend merging into `admin_test.exs` per existing convention)
- Files with no analog: 0

### Key Patterns Identified
- **Feature manifest is purely additive:** `files/1` returns `[{:eex, source, target}]` tuples; two additions close INT-02 and INT-03 without touching `injections/1`, `migrations/1`, or the runner.
- **EEx parameterization mapping is strict:** 5-rule table (`ExampleWeb -> <%= web_module %>`, `Example -> <%= app_module %>`, `Example.Accounts -> <%= context_module %>`, etc.) with grep-assertion coverage (`refute content =~ "Example"`).
- **Generator test convention is self-contained ExUnit `describe` blocks** inside the feature-specific `*_test.exs`; no standalone `router_injection_test.exs` should be created.
- **CI smoke uses status-only `gen_expect_non_5xx` probes** — sufficient for Phase 32's Nyquist gate; full authenticated flows belong in Playwright.
- **Enumeration prevention invariant:** `{:error, :not_allowed}` maps to `:not_found` response, not `:forbidden`.

### File Created
`/Users/jon/projects/sigra/.planning/phases/32-generated-installer-admin-surface-parity/32-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference analog patterns in PLAN.md files.
