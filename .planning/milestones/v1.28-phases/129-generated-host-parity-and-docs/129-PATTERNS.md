# Phase 129: Generated Host Parity And Docs - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 18
**Analogs found:** 18 / 18

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/templates/sigra.install/core/auth.ex` | service/context template | request-response | `priv/templates/sigra.install/core/auth.ex` lifecycle wrappers | exact |
| `test/example/lib/example/accounts.ex` | service/context | request-response | `test/example/lib/example/accounts.ex` lifecycle wrappers | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` | fixture/generated context | request-response | `priv/templates/sigra.install/core/auth.ex` + golden rebless task | exact |
| `priv/templates/sigra.install/core/settings_live.ex` | component/LiveView template | event-driven | `priv/templates/sigra.install/core/settings_live.ex` deletion flow | exact |
| `priv/templates/sigra.install/core/reactivation_live.ex` | component/LiveView template | event-driven | `priv/templates/sigra.install/core/reactivation_live.ex` cancel flow | exact |
| `priv/templates/sigra.install/core/emails.ex` | component/email template | transform | `priv/templates/sigra.install/core/emails.ex` finalized email | exact |
| `test/example/lib/example_web/live/settings_live.ex` | component/LiveView | event-driven | `priv/templates/sigra.install/core/settings_live.ex` | role-match |
| `test/example/lib/example_web/live/reactivation_live.ex` | component/LiveView | event-driven | `priv/templates/sigra.install/core/reactivation_live.ex` | exact |
| `test/example/lib/example/accounts/emails.ex` | component/email | transform | `priv/templates/sigra.install/core/emails.ex` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex` | fixture/generated LiveView | event-driven | `priv/templates/sigra.install/core/settings_live.ex` + `test/sigra/install/golden_diff_test.exs` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reactivation_live.ex` | fixture/generated LiveView | event-driven | `priv/templates/sigra.install/core/reactivation_live.ex` + `test/sigra/install/golden_diff_test.exs` | exact |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/emails.ex` | fixture/generated email | transform | `priv/templates/sigra.install/core/emails.ex` + rebless task | exact |
| `guides/flows/account-lifecycle.md` | documentation | transform | existing lifecycle guide strategy section | exact |
| `guides/flows/audit-logging.md` | documentation | streaming/export | existing audit export guide | role-match |
| `guides/recipes/testing.md` | documentation | request-response/test | existing testing recipe helper list | exact |
| `test/sigra/templates/settings_live_test.exs` | test | file-I/O | existing template content tests | exact |
| `test/sigra/guides_dx02_test.exs` | test | file-I/O/transform | existing guide drift tests | role-match |
| `test/sigra/data_export_test.exs` | test | CRUD/transform | existing export contract tests | exact |

## Pattern Assignments

### Generated/export context wrappers (service/context, request-response)

**Applies to:** `priv/templates/sigra.install/core/auth.ex`, `test/example/lib/example/accounts.ex`, golden `accounts.ex`.

**Primary analog:** `priv/templates/sigra.install/core/auth.ex`

**Imports pattern** (lines 10-18):
```elixir
import Ecto.Query, warn: false
alias <%= repo_module %>, as: Repo
alias <%= context_module %>.<%= schema_alias %>
alias <%= context_module %>.UserToken
alias Sigra.Auth, as: SigraAuth
```

**Thin lifecycle wrapper pattern** (lines 1034-1069):
```elixir
def schedule_deletion(user, opts \\ []) do
  Sigra.Auth.schedule_deletion(sigra_config(), user,
    Keyword.merge(
      [
        changeset_fn: &User.deletion_changeset/2,
        user_token_schema: UserToken,
        session_store: Sigra.SessionStores.Ecto
      ],
      opts
    )
  )
end

def cancel_deletion(user, opts \\ []) do
  Sigra.Auth.cancel_deletion(sigra_config(), user,
    Keyword.merge([changeset_fn: &<%= schema_alias %>.deletion_changeset/2], opts)
  )
end

def deletion_status(user) do
  Sigra.Account.deletion_status(user)
end
```

**Example-app guard pattern** (lines 1233-1262):
```elixir
def schedule_deletion(user, opts \\ []) do
  with :ok <- forbid_sensitive_operation(opts, user, "account.deletion_schedule") do
    Sigra.Auth.schedule_deletion(sigra_config(), user, Keyword.merge([...], opts))
  end
end

def cancel_deletion(user, opts \\ []) do
  with :ok <- forbid_sensitive_operation(opts, user, "account.deletion_cancel") do
    Sigra.Auth.cancel_deletion(sigra_config(), user, Keyword.merge([...], opts))
  end
end
```

**Export contract to call, not rebuild:** `lib/sigra/data_export.ex` lines 84-176:
```elixir
@spec export_auth_data(module(), struct(), keyword()) :: {:ok, map()}
def export_auth_data(repo, user, opts \\ []) do
  data = %{
    schema_version: 1,
    exported_at: DateTime.utc_now() |> DateTime.truncate(:second),
    account: %{id: user.id, email: user.email, lifecycle_status: lifecycle_status(user)},
    enterprise: %{connections: [], exported: false, reason: "..."},
    omissions: omissions(opts)
  }

  {:ok, data}
end
```

**Planner instruction:** Add `export_auth_data(user, opts \\ [])` beside lifecycle helpers. It should call `Sigra.DataExport.export_auth_data(Repo, user, Keyword.merge([schema opts], opts))`. Do not construct `schema_version`, `account`, `sessions`, `audit`, `mfa`, `enterprise`, or `omissions` in generated/example code.

### Thin controller/export seam (controller, request-response)

**Analog:** `priv/templates/sigra.install/admin/audit_export_controller.ex`

**Core pattern** (lines 10-17, 30-39):
```elixir
def index(conn, %{"id" => user_id} = params) do
  case Sigra.Admin.Audit.Export.subject_csv(export_config(), conn.assigns.admin_scope, user_id, params) do
    {:ok, csv} -> send_csv(conn, csv)
    {:error, _reason} -> send_resp(conn, 400, "Invalid audit export filters")
  end
end

defp export_config do
  %{Accounts.sigra_config() | scope_module: <%= app_module %>.Accounts.Scope}
end
```

**Planner instruction:** If an auth-export route/controller is added, copy this shape: host controller gathers scope/config and delegates to library code. Do not add payload serialization in controllers.

### Lifecycle LiveView copy and events (component, event-driven)

**Analog:** `priv/templates/sigra.install/core/settings_live.ex`

**Imports/assigns pattern** (lines 17-35):
```elixir
use <%= web_module %>, :live_view
alias <%= context_module %>, as: Auth

def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  deletion_status = Auth.deletion_status(user)

  {:ok, assign(socket, deletion_status: deletion_status, scheduled_deletion_date: scheduled_deletion_date(user))}
end
```

**Deletion event pattern** (lines 270-307):
```elixir
def handle_event("confirm_delete", _params, socket) do
  user = socket.assigns.current_scope.user

  case Auth.schedule_deletion(user) do
    {:ok, updated_user, scheduled_date} ->
      {:noreply,
       socket
       |> put_flash(:info, "Your account is scheduled for deletion on #{scheduled_date}. You can cancel this from your settings.")
       |> assign(current_scope: %{socket.assigns.current_scope | user: updated_user},
                 deletion_status: Auth.deletion_status(updated_user),
                 scheduled_deletion_date: to_string(scheduled_date))}
    {:error, reason} -> ...
  end
end
```

**Copy to soften** (lines 171-179):
```elixir
Permanently delete your account and all associated data.
This action cannot be undone after the grace period expires.
data-confirm="Are you sure? Your account will be deactivated immediately and permanently deleted. All sessions will be signed out."
```

**Planner instruction:** Preserve event names and wrapper calls. Replace broad permanent-removal copy with strategy-neutral language such as scheduled according to configured deletion strategy.

### Reactivation LiveView copy and errors (component, event-driven)

**Analog:** `priv/templates/sigra.install/core/reactivation_live.ex`

**Core pattern** (lines 40-72):
```elixir
<p>
  Your account and data will be permanently removed on <%= "{@scheduled_deletion_date}" %>.
</p>

def handle_event("cancel_deletion", _params, socket) do
  user = socket.assigns.current_scope.user

  case Auth.cancel_deletion(user, scope: socket.assigns.current_scope) do
    {:ok, _user} ->
      {:noreply, socket |> put_flash(:info, "Account deletion cancelled. Your account is active again.") |> push_navigate(to: ~p"/users/settings")}
    {:error, :impersonation_forbidden} -> ...
    {:error, _reason} -> ...
  end
end
```

**Planner instruction:** Keep the impersonation error branch and navigation. Only change the overbroad copy.

### Deletion finalized email copy (component/email, transform)

**Analog:** `priv/templates/sigra.install/core/emails.ex`

**Copy pattern to update** (lines 690-704):
```elixir
@doc "Builds a deletion finalized notification email. Accepts raw email since user may be anonymized."
def deletion_finalized_email(email) do
  html_content = """
  ...
    #{dgettext("sigra", "Your %{app_name} account and associated data have been permanently removed. ...", app_name: "<%= app_name %>")}
  """

  text_body = """
  #{dgettext("sigra", "Account Deleted")}

  #{dgettext("sigra", "Your %{app_name} account and associated data have been permanently removed. ...", app_name: "<%= app_name %>")}
  """
end
```

**Planner instruction:** Mirror wording changes in template, example email, and golden email after rebless. Preserve `dgettext/3`, `app_name`, and raw email argument.

### Golden fixture parity (fixture/test, file-I/O)

**Analog:** `lib/mix/tasks/sigra.fixture.rebless_golden.ex`

**Rebless workflow** (lines 15-25, 50-78, 178-182):
```elixir
MIX_ENV=test mix sigra.fixture.rebless_golden
MIX_ENV=test mix sigra.fixture.rebless_golden --check

{:ok, %{app_dir: tmp_dir, stdout: raw, baseline_paths: baseline}} =
  InstallFixture.setup_tmp_app()

tree = InstallFixture.normalize_tree(tmp_dir, baseline)
stdout = InstallFixture.normalize_stdout(raw, tmp_dir)
write_tree!(target_tree_dir, tree)

Mix.shell().info("  3. MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs")
```

**Golden diff assertion pattern:** `test/sigra/install/golden_diff_test.exs` lines 53-63 and 134-180:
```elixir
actual = InstallFixture.normalize_tree(app_dir, baseline)
expected = read_fixture_tree()
assert_tree_equal(actual, expected)

defp read_fixture_tree do
  @fixture_tree_dir
  |> Path.join("**")
  |> Path.wildcard(match_dot: true)
  |> Enum.filter(&File.regular?/1)
  |> Enum.map(fn abs_path -> ... end)
end
```

**Planner instruction:** Do not manually invent golden behavior. Change templates/example, run rebless, then review golden diffs.

### Template content tests (test, file-I/O)

**Analog:** `test/sigra/templates/settings_live_test.exs`

**Pattern** (lines 10-16, 81-94, 117-149):
```elixir
@templates_dir Path.expand("../../../priv/templates/sigra.install/core", __DIR__)

setup do
  content = File.read!(Path.join(@templates_dir, "settings_live.ex"))
  %{content: content}
end

test "contains deletion confirmation with data-confirm", %{content: content} do
  assert content =~ "confirm_delete"
  assert content =~ "data-confirm"
  assert content =~ "Delete my account"
end
```

**Planner instruction:** Add focused assertions for `export_auth_data` and absence of overbroad phrases. Use raw template content reads, not generated output, for template-specific invariants.

### Data export contract tests (test, transform)

**Analog:** `test/sigra/data_export_test.exs`

**Versioned payload and omissions pattern** (lines 256-277, 337-364):
```elixir
assert {:ok, data} = DataExport.export_auth_data(nil, user, [])

assert data.schema_version == 1
assert Map.has_key?(data, :account)
assert Map.has_key?(data, :enterprise)
assert Map.has_key?(data, :omissions)

assert data.omissions == [
  %{section: :sessions, schema_option: :session_schema},
  %{section: :identities, schema_option: :identity_schema},
  %{section: :audit, schema_option: :audit_schema},
  ...
]
```

**Planner instruction:** Use these tests as the library truth source. Generated-host tests should assert delegation/configuration, not duplicate every payload assertion.

### Documentation truth (documentation, transform/streaming)

**Account lifecycle analog:** `guides/flows/account-lifecycle.md`

**Existing strategy-specific pattern** (lines 142-153):
```markdown
The Oban worker (`Sigra.Workers.AccountDeletion`) calls `execute_deletion/3` which applies your configured strategy:

- `:hard_delete` — deletes the user row and Sigra token rows. Other row cleanup follows your DB constraints and host-owned schema design.
- `:soft_delete` — finalizes the deletion lifecycle while preserving the user row and its PII in the DB.
- `:anonymize` — clears Sigra-owned user PII fields while keeping the row for referential integrity. Recommended default.
```

**Audit/export analog:** `guides/flows/audit-logging.md` lines 122-150:
```markdown
Use `Sigra.Audit.list/2` for stable cursor-based pagination when you need
checkpointed export batches. Use `Sigra.Audit.stream/2` for database-backed
streaming inside a transaction when you want to process a large slice in one run.

The `Sigra.Workers.AuditCleanup` Oban worker runs nightly and deletes rows older than `retention_days`.
For regulatory compliance, export to cold storage before deletion.
```

**Testing docs analog:** `guides/recipes/testing.md` lines 70-80:
```markdown
- **`assert_deletion_scheduled(user)`** — `scheduled_deletion_at` is set.
- **`assert_deletion_cancelled(user)`** — inverse.
- **`assert_account_deleted(repo, user_schema, user_id)`** — the user row is gone (or anonymized).
```

**Planner instruction:** Add bounded language: Sigra-owned auth/account data, host-owned domain data, optional-section omissions, and strategy-specific deletion consequences. Update `assert_account_deleted/3` docs to avoid implying row absence for `:soft_delete`.

### Guide drift tests (test, file-I/O/transform)

**Analog:** `test/sigra/guides_dx02_test.exs`

**File-read and helper-sweep pattern** (lines 20-29, 383-394, 397-413):
```elixir
@testing_guide Path.join([@guides_root, "recipes", "testing.md"])
@templates_root Path.join(["priv", "templates", "sigra.install", "core"])

defp helper_in_templates?(helper_name) when is_binary(helper_name) do
  pattern = "def #{helper_name}"

  @templates_root
  |> Path.join("*.ex")
  |> Path.wildcard()
  |> Enum.any?(fn file ->
    case File.read(file) do
      {:ok, contents} -> String.contains?(contents, pattern)
      _ -> false
    end
  end)
end
```

**Planner instruction:** If adding docs verification, follow this direct markdown/template grep style. Keep checks narrow to the Phase 129 claims.

## Shared Patterns

### Library-owned truth, generated-host adapters
**Source:** `priv/templates/sigra.install/core/auth.ex` lines 1034-1069 and `lib/sigra/data_export.ex` lines 84-176.
**Apply to:** generated context, example context, golden context, any controller seam.

Generated code supplies repo/schema/config/scope context and delegates. Library code owns payload shape, safe serialization, omissions, enqueue/finalization, active-scheduled, stale-worker, and lifecycle status truth.

### Example app impersonation guard
**Source:** `test/example/lib/example/accounts.ex` lines 1233-1262.
**Apply to:** example sensitive lifecycle/export helpers if exposed through user/admin flows.

Preserve `forbid_sensitive_operation/3` around sensitive example operations; do not weaken existing guard style while adding parity.

### Golden is generated evidence
**Source:** `lib/mix/tasks/sigra.fixture.rebless_golden.ex` lines 15-25 and `test/sigra/install/golden_diff_test.exs` lines 53-63.
**Apply to:** all `test/fixtures/install_golden/tree/**` changes.

Golden fixture changes should be produced by `MIX_ENV=test mix sigra.fixture.rebless_golden`, then verified with `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs`.

### Copy truth boundary
**Source:** `guides/flows/account-lifecycle.md` lines 151-153 plus overbroad generated copy in `settings_live.ex` lines 171-179, `reactivation_live.ex` lines 40-43, and `emails.ex` lines 690-704.
**Apply to:** generated templates, example app, golden fixture, account lifecycle/audit/testing docs.

Use strategy-neutral generated copy and strategy-specific docs. Avoid unconditional "all associated data" and "permanently removed" unless specifically scoped to `:hard_delete` or the configured strategy.

### Optional-schema omissions
**Source:** `lib/sigra/data_export.ex` lines 340-351 and `test/sigra/data_export_test.exs` lines 337-364.
**Apply to:** export wrapper docs/tests.

Missing generated optional schemas are explicit omissions, not hidden completeness. Docs should describe `omissions` as partial-export truth for Sigra-owned optional sections.

## No Analog Found

No Phase 129 target lacks an analog. The closest-match caveat is documentation: `guides/flows/audit-logging.md` currently covers audit streaming/export but not auth/account data export, so planners should extend its existing export section using `lib/sigra/data_export.ex` and `test/sigra/data_export_test.exs` as truth sources.

## Metadata

**Analog search scope:** `lib/`, `priv/templates/sigra.install/`, `test/example/`, `test/fixtures/install_golden/tree/`, `test/sigra/`, `guides/`
**Files scanned:** 100+ via `rg --files`/`rg`
**Pattern extraction date:** 2026-05-27
