# Phase 214: Debt & Robustness Clear — Research

**Researched:** 2026-07-02
**Domain:** Elixir/Phoenix library hardening — Oban guard, session security, CSS cleanup, version wart, test-env noise
**Confidence:** HIGH (all findings from direct live-codebase reads)

---

## Summary

This research is a ground-truth audit of the live codebase against the CONTEXT.md's factual
claims. The decisions in CONTEXT.md (D-01..D-20) are locked; this document verifies that each
decision's stated code context is accurate and surfaces discrepancies the planner must account
for.

All six items (DEBT-01..DEBT-05, HEALTH-03) were verified against the live files. Four
discrepancies from CONTEXT.md's stated context were found and are flagged in their respective
sections below.

**Primary recommendation:** The planner can write concrete, file-precise tasks for all six items.
No decision changes are needed; the discrepancies are implementation-detail corrections that
affect task wording but not scope.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All D-01 through D-20 are locked. See the full 214-CONTEXT.md for text. Summary:

- D-01..D-04: DEBT-01 Oban guard — centralize to `oban_running?/0` in `OptionalDeps`, call from all three sites, add regression test.
- D-05..D-07: DEBT-02 — retire `panel-schema-check.sh` with rationale; WR-01/IN nits are won't-fix.
- D-08..D-11: DEBT-03 — harden `delete_session/3` with user_id check; deny-path test; drop `@return_to` or wire it; promote duplicated session helpers to shared module.
- D-12..D-14: DEBT-04 — delete git tag `v1.20.0`; correct `contract.md:9`; write hex retire runbook.
- D-15..D-17: DEBT-05 — delete orphaned `:root` value fragments in `app.css`; add CI regex guard.
- D-18..D-20: HEALTH-03 — suppress Chimeway.Repo startup noise; graceful preflight-skip for UpgradeIntegrationTest.

### Claude's Discretion
- Exact refactor shape of `oban_running?/0` SOT (D-02)
- Local vs shared module for promoted session helpers (D-11)
- Drop vs wire `@return_to` (D-10)
- Whether app.css CI guard lives in an existing lint step or a new tiny script (D-17)

### Deferred Ideas (OUT OF SCOPE)
Playwright per-shard DB isolation, UAT demo-DX polish nits, `mix sigra.migrate_schema`, runtime auth-prefix override, Vaultr/Tasklane rebrand residuals, white-label auth/email theming.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEBT-01 | Oban enqueue paths degrade safely when Oban is compiled but unsupervised | Guard confirmed at `deletion.ex:308`; correct patterns confirmed at `delivery.ex:113-115` and `forwarders.ex:89-101` |
| DEBT-02 | Deferred phase-209 code-review items resolved | `panel-schema-check.sh` confirmed present; ci.yml confirmed has zero references |
| DEBT-03 | Deferred phase-200 code-review items resolved | `delete_session/3` at lines 1495-1526 has no user_id guard; duplicated helpers confirmed in both LiveView files |
| DEBT-04 | Stray Hex 1.20.0 version-ranking wart resolved | `mix.exs:4` = `"1.1.0"` confirmed; `contract.md:9` cites `1.20.0`; git tag `v1.20.0` confirmed to exist |
| DEBT-05 | Demo app.css orphaned-comment corruption cleaned up | Orphan ranges confirmed; CONTEXT.md scope is accurate for `:root` orphans; no templates copy confirmed |
| HEALTH-03 | Zero spurious non-product failures in local `mix test` | Chimeway.Repo unconditionally supervised; no Sigra test uses Chimeway.Repo; UpgradeIntegrationTest structure confirmed |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Oban enqueue guard | Library (Sigra.OptionalDeps) | Account Deletion module | Cross-cutting optional-dep concern; centralizes in OptionalDeps |
| Session user_id guard | Library (Sigra.Auth) | Session store callback | Guards all callers at the public API entry point |
| Session render helpers | Admin LiveView shared module | Sigra.Admin.Components | Shared admin render concern |
| CSS corruption cleanup | Demo app (test/example) | None | Build-free demo only; no installer template copy |
| Version wart | mix.exs / git tags / docs | Hex registry (manual) | Repo-automatable parts done in-phase; Hex retire is manual |
| Test-env startup noise | Test config / test_helper | Chimeway Application | Config-layer suppression for chimeway; preflight skip for upgrade test |

---

## DEBT-01 Ground Truth — Oban Enqueue Guard

### The Buggy Site: `lib/sigra/account/deletion.ex`

**Line 207** (in `do_schedule/3`, after `repo.transaction(multi)` commits):
```elixir
maybe_enqueue_deletion_job(repo, updated_user, scheduled_deletion_at, opts)
```
[VERIFIED: live codebase]

**Lines 307-330** — `maybe_enqueue_deletion_job/4` with the bare guard:
```elixir
defp maybe_enqueue_deletion_job(repo, user, scheduled_at, opts) do
  with true <- Sigra.OptionalDeps.oban_available?(),
       true <- Code.ensure_loaded?(Sigra.Workers.AccountDeletion),
       {:ok, args} <- deletion_job_args(repo, user, opts),
       {:ok, changeset} <-
         build_deletion_job_changeset(args, scheduled_at),
       {:ok, _job} <- repo.insert(changeset) do
    :ok
  else
    false ->
      :ok
    {:error, :missing_job_context} ->
      :ok
    {:error, reason} ->
      Logger.warning("Sigra account deletion job was not enqueued: #{inspect(reason)}")
      :ok
  end
rescue
  error ->
    Logger.warning("Sigra account deletion job enqueue crashed: #{Exception.message(error)}")
    :ok
end
```
[VERIFIED: live codebase]

The `rescue` block (lines 326-329) means a `42P01` crash is caught and logged, NOT a transaction-poisoning crash. CONTEXT.md D-03 is accurate: "today's failure is a logged warning, not a poisoned transaction." The remaining defect is the wasted insert attempt + warning on unsupervised hosts.

### The Correct Pattern 1: `lib/sigra/delivery.ex:113-115`

```elixir
defp oban_running? do
  Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
end
```
This is a zero-argument private function. [VERIFIED: live codebase]

### The Correct Pattern 2: `lib/sigra/audit/forwarders.ex:89-101`

**DISCREPANCY FROM CONTEXT.MD:** CONTEXT.md (canonical_refs) cites this as "second correct pattern" but the actual implementation is MORE complex than delivery.ex's pattern. `forwarders.ex` has a 1-arity `oban_running?/1` that accepts an opts keyword list to support test injection of a mock process name:

```elixir
@spec oban_running?(keyword()) :: boolean()
def oban_running?(opts) do
  case Keyword.fetch(opts, :oban) do
    {:ok, oban_override} ->
      # Test override: skip Code.ensure_loaded? (override is a named process, not a module)
      Process.whereis(oban_override) != nil
    :error ->
      # Production path: mirrors lib/sigra/delivery.ex oban_running?/0:
      Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
  end
end
```
[VERIFIED: live codebase, lines 89-101]

The `oban_running?/1` in `forwarders.ex` is already PUBLIC (has `@spec`). It is NOT a private function like `delivery.ex`'s `oban_running?/0`.

### Implication for D-02 (Centralized SOT)

When the planner creates `Sigra.OptionalDeps.oban_running?/0`:
- `delivery.ex` can simply call `Sigra.OptionalDeps.oban_running?()` and delete its private `oban_running?/0`
- `forwarders.ex` CANNOT simply replace its `oban_running?/1` with the SOT — it needs the opts override path for test injection. The planner must decide: (a) keep `forwarders.ex`'s `oban_running?/1` as a wrapper that calls `Sigra.OptionalDeps.oban_running?()` in the `:error` branch, or (b) move the opts-override variant to `OptionalDeps` as `oban_running?/1` alongside the new `oban_running?/0`.
- `deletion.ex`'s `maybe_enqueue_deletion_job/4` should call `Sigra.OptionalDeps.oban_running?()` (the no-opts SOT) since deletion doesn't use test-injection of mock processes.

### `lib/sigra/optional_deps.ex:79` — Host for New SOT

```elixir
@spec oban_available?() :: boolean()
def oban_available?, do: Code.ensure_loaded?(Oban)
```
[VERIFIED: live codebase]

Add `oban_running?/0` directly below this, as the same-module complement:
```elixir
@spec oban_running?() :: boolean()
def oban_running?, do: oban_available?() and Process.whereis(Oban) != nil
```

### Existing Test Coverage

`test/sigra/account/deletion_test.exs` has TWO deletion tests:
1. "enqueues account deletion worker when generated-host job context is present" (line 85)
2. "safely degrades without enqueue when job context is missing" (line 158)

Neither test proves the guard for "Oban compiled but unsupervised." The regression test (D-04) is genuinely new work. The existing test on line 158 uses mock-based testing; the new test needs a setup where `oban_available?()` returns true but `Process.whereis(Oban)` returns nil.

---

## DEBT-02 Ground Truth — panel-schema-check.sh

**File exists:** `scripts/ci/panel-schema-check.sh` [VERIFIED: live codebase]

**What it validates:** Phase 209 persona-JTBD panel schema — validates YAML frontmatter, surface/rubric_version/disposition fields, verdicts structure, and markdown body headings against `.planning/uat-evidence/v1.42-persona-jtbd/*.md` files. [VERIFIED: live codebase]

**CI reference check:** Zero matches for `panel-schema-check` or `panel_schema` in `.github/workflows/ci.yml`. [VERIFIED: live codebase]

**Retire premise confirmed:** The script validates frozen v1.42 milestone deliverables that never change. Wiring it into CI would guard historical docs against a corruption that cannot occur. CONTEXT.md D-05 rationale is accurate.

---

## DEBT-03 Ground Truth — delete_session/3 and Session Helpers

### `Sigra.Auth.delete_session/3` — Lines 1495-1526

```elixir
@spec delete_session(Sigra.Config.t(), binary(), keyword()) :: :ok
def delete_session(config, hashed_token, opts \\ []) do
  {session_store, store_opts} = session_store_and_opts(config, opts)

  result =
    Telemetry.span([:sigra, :session, :delete], %{}, fn ->
      session_store.delete(hashed_token, store_opts)
    end)

  # D-26: session.delete audit row (standalone, D-28).
  user_id = Keyword.get(opts, :user_id)
  actor_id = Keyword.get(opts, :actor_id, user_id)
  target_id = Keyword.get(opts, :target_id, user_id)
  effective_user_id = Keyword.get(opts, :effective_user_id, user_id)
  scope = audit_scope_from_opts(config, opts, effective_user_id)

  Sigra.Audit.log_safe(
    "session.delete",
    ...
  )

  result
end
```
[VERIFIED: live codebase]

The `user_id` from opts is ONLY used for audit purposes; it is NOT checked against the session's owner before deletion. The D-08 guard must be inserted between fetching `{session_store, store_opts}` and calling `session_store.delete/2`.

### The Session Struct Has `user_id`

`Sigra.Session` struct includes `:user_id` as a field (confirmed in `lib/sigra/session.ex`). The session store's `fetch/2` returns `{:ok, Sigra.Session.t()}`. [VERIFIED: live codebase]

### Guard Implementation Pattern for D-08

The D-08 guard requires fetching the session first, checking user_id, then proceeding or no-oping:
```elixir
# Insert before session_store.delete call:
case Keyword.get(opts, :user_id) do
  nil ->
    # No user_id constraint — proceed (backward compatible, e.g. self-logout)
    session_store.delete(hashed_token, store_opts)
  user_id ->
    case session_store.fetch(hashed_token, store_opts) do
      {:ok, %{user_id: ^user_id}} -> session_store.delete(hashed_token, store_opts)
      {:ok, _} -> :ok   # user_id mismatch — no-op
      {:error, :not_found} -> :ok  # already gone
    end
end
```
This must still call the Telemetry span and Audit.log_safe regardless. The planner must decide whether to only gate the `delete` call or also gate the audit log.

### `Sigra.SessionStores.Ecto.delete/2` — Lines 64-72

```elixir
@impl true
def delete(hashed_token, opts) do
  repo = Keyword.fetch!(opts, :repo)
  schema = Keyword.fetch!(opts, :session_schema)

  case repo.get_by(schema, hashed_token: hashed_token) do
    nil -> :ok
    record -> repo.delete!(record) && :ok
  end
end
```
[VERIFIED: live codebase]

This fetches by `hashed_token` only — no `user_id` constraint. The D-08 decision is to guard in `Sigra.Auth.delete_session/3` (library layer) NOT in the store implementation, keeping the store's `@callback delete/2` signature unchanged. [VERIFIED: matches D-08]

### `@callback delete/2` in `Sigra.SessionStore` — Line 39

```elixir
@callback delete(hashed_token :: binary(), opts :: keyword()) :: :ok
```
[VERIFIED: live codebase — signature unchanged by D-08]

### `Actions.revoke_session/4` Call Chain — Lines 9-21

**DISCREPANCY FROM CONTEXT.MD:** CONTEXT.md (canonical_refs, D-08 text) describes this as `Actions.revoke_session/4` → `revoke_session/3` but the actual call chain is:

```elixir
@spec revoke_session(map(), Scope.t(), binary(), binary()) :: :ok
def revoke_session(config, %Scope{} = admin_scope, user_id, hashed_token)
    when is_binary(user_id) and is_binary(hashed_token) do
  user = Detail.load_user!(config, admin_scope, user_id)

  Sigra.Auth.revoke_session(config, hashed_token,
    user_id: user.id,
    actor_id: admin_scope.scope.user.id,
    ...
  )
end
```
[VERIFIED: live codebase]

`Actions.revoke_session/4` calls `Sigra.Auth.revoke_session/3` (NOT `revoke_session/3` which is a different internal). `Sigra.Auth.revoke_session/3` is just a 1-line delegate to `delete_session/3`:

```elixir
def revoke_session(config, hashed_token, opts \\ []) do
  delete_session(config, hashed_token, opts)
end
```
[VERIFIED: live codebase, line 1613-1615]

So the D-08 guard in `delete_session/3` covers `revoke_session/3` automatically.

### D-10 — `@return_to` Assign Analysis

The `assign(:return_to, nil)` on line 19 of `user_sessions_live.ex` IS used (line 34 sets it from params, passed to `sessions_breadcrumbs` on line 35 which computes `@admin_breadcrumbs`). However, `@return_to` is **never directly referenced in the HEEx template** (zero `@return_to` occurrences in the render function). The assign is intermediate state for computing breadcrumbs — once breadcrumbs are computed and stored as `@admin_breadcrumbs`, `@return_to` is not needed as a socket assign.

**Planner implication for D-10:** The cleanest fix is to keep `return_to` as a local variable inside `handle_params` (it already is — `return_to = sanitize_return_to(...)`) and remove the `assign(:return_to, ...)` call. The mount needs to initialize `@return_to` because `handle_params` always runs after mount and sets it, so the `nil` initialization is defensive. Removing the assign and not initializing it in mount is safe since `handle_params` always sets it before render. The planner should verify no LiveView event handlers access `socket.assigns.return_to` — a grep confirms none do.

### D-11 — Duplicated Session Helper Functions

Both files contain byte-identical implementations:

| Function | `user_sessions_live.ex` | `user_show_live.ex` |
|----------|------------------------|---------------------|
| `scope_copy/1` | lines 212-215 | lines 321-324 |
| `session_type/1` | line 217 | line 364 |
| `activity_value/1` | lines 219-221 | lines 366-368 |
| `relative_activity/1` | lines 224-235 | lines 405-416 |
| `pluralize/2` | lines 237-238 | lines 418-419 |

[VERIFIED: live codebase]

These are pure computation helpers (not HEEx function components), so they cannot simply be `import`ed from `Sigra.Admin.Components` (which uses `use Phoenix.Component`). The planner's options:
1. Add them as public functions to `Sigra.Admin.Components` and `import Sigra.Admin.Components` already exists in both LiveViews (line 6 in `user_sessions_live.ex`) — so they would be available immediately after promotion.
2. Create a dedicated `Sigra.Admin.SessionHelpers` module — more surgical but adds a module.

Option 1 is simpler and consistent with D-11 ("Sigra.Admin.Components (or a shared module)").

---

## DEBT-04 Ground Truth — Stray 1.20.0 Version

**`mix.exs:4`:** `@version "1.1.0"` [VERIFIED: live codebase]

**`.release-please-manifest.json`:** `{ ".": "1.1.0" }` [VERIFIED: live codebase]

**`guides/introduction/contract.md:9`:** "The current published package truth before the release PR is `1.20.0`" [VERIFIED: live codebase — stale, must be corrected to `1.1.0`]

**Git tag `v1.20.0`:** EXISTS. `git tag -l v1.20.0` returns `v1.20.0`. [VERIFIED: live codebase]

D-13's actions are confirmed correct:
1. `git tag -d v1.20.0` + `git push origin :refs/tags/v1.20.0` — deletes local and remote tag
2. Edit `guides/introduction/contract.md` line 9 — replace `1.20.0` with `1.1.0`

The Hex retire (`mix hex.retire sigra 1.20.0 invalid`) must be documented as a manual runbook step per D-14 — this cannot be automated in-phase because it requires Jon's Hex credentials.

---

## DEBT-05 Ground Truth — app.css Orphaned Comment Corruption

### Confirmed Orphan Ranges

**Light-mode `:root` block (lines 6-84):**

- **Lines 28-33** — Three multi-line box-shadow VALUE fragments (orphaned `--sg-elev-1`, `--sg-elev-2`, `--sg-elev-3` declaration bodies after their property names were removed):
  ```
  28:     0 0 0 1px rgba(21, 21, 21, 0.06), 0 1px 2px -1px rgba(21, 21, 21, 0.08),
  29:     0 10px 30px -24px rgba(21, 21, 21, 0.35);
  30:     0 0 0 1px rgba(21, 21, 21, 0.1), 0 3px 10px -8px rgba(21, 21, 21, 0.35),
  31:     0 18px 44px -30px rgba(21, 21, 21, 0.45);
  32:     0 0 0 1px rgba(21, 21, 21, 0.12), 0 12px 28px -12px rgba(21, 21, 21, 0.4),
  33:     0 30px 64px -32px rgba(21, 21, 21, 0.5);
  ```

- **Lines 39-43** — Two multi-line transition VALUE fragments (orphaned `--sg-transition-tone` and `--sg-transition-press` declaration bodies):
  ```
  39:     color var(--sg-motion-fast) var(--sg-ease),
  40:     background-color var(--sg-motion-fast) var(--sg-ease),
  41:     box-shadow var(--sg-motion-fast) var(--sg-ease);
  42:     opacity var(--sg-motion-medium) var(--sg-ease-out),
  43:     transform var(--sg-motion-medium) var(--sg-ease-out);
  ```

- **Line 46** — One single-line VALUE fragment (orphaned `--sg-focus-ring` declaration body):
  ```
  46:     color-mix(in oklab, var(--sg-color-brand) 35%, transparent);
  ```

**Dark-mode `:root` block (lines 86-111):**

- **Lines 88-91** — Orphaned comment fragments from removed `--sg-*` dark-mode declarations:
  ```
  88:      * (~1.88:1 → >=4.5:1). Supersedes the scoped chip fix at the .sg-filter-chip
  89:      * block below. */
  90:      * contrast (dark-mode tinted backgrounds need light tone text). */
  91:       0 0 0 1px rgba(255, 255, 255, 0.18), 0 24px 60px -28px rgba(0, 0, 0, 0.8);
  ```

[VERIFIED: live codebase — all ranges confirmed]

### IMPORTANT: `--sg-*` in the rest of the file is NOT corruption

The file contains hundreds of `var(--sg-*)` references throughout the selector rules (lines 175+). These are LEGITIMATE — the demo app's `.vt-*` components intentionally reference the `--sg-*` token layer defined in `sigra_admin.css`. These must NOT be removed.

**Only delete the orphaned VALUE fragments** in the `:root` block (lines 28-33, 39-43, 46) and the orphaned comment fragments in the dark-mode `:root` (lines 88-91). The empty comment headers that frame them (e.g., `/* Elevation ladder. ... */`, `/* Motion. ... */`, `/* Focus */`) should also be removed since they now frame nothing.

### No Templates Copy

`find priv/templates -name "app.css"` returns nothing. [VERIFIED: live codebase]

### CI Guard Design (D-17)

The corruption pattern is: orphaned value fragments as bare statements inside `:root {}` that look like CSS values but have no property name. A regex that catches `*/` on a line inside a `:root` block is imprecise. A more reliable guard: check for lines matching `^\s+[0-9]` (numeric values with no property name) or `^\s+color var\(` (transition fragment) inside `:root`. This is hard to make precise in a shell regex. A simpler approach: check that the count of `*/` lines inside `:root` matches `/*` — an unmatched close-comment fragment is the tell.

---

## HEALTH-03 Ground Truth — Spurious Test Failures

### D-18: Chimeway.Repo Startup Noise

**Chimeway is in `deps/` and IS compiled.** It has `mod: {Chimeway.Application, []}` in its own `mix.exs`, meaning it registers as an OTP application. When Sigra's `:test` env boots, Mix starts all deps in the app tree including `chimeway`. `Chimeway.Application.start/2` unconditionally adds `Chimeway.Repo` to its supervision tree (line 13-14 of `chimeway/application.ex`).

`Chimeway.Repo` reads config from `Application.get_env(:chimeway, Chimeway.Repo)`. Since `config/test.exs` has ZERO `:chimeway` stanzas, `Chimeway.Repo` starts with no database config → connection error → startup noise.

**No Sigra test uses `Chimeway.Repo`:** Confirmed by exhaustive grep — zero hits. [VERIFIED: live codebase]

**Fix for D-18 (planner's call per D-18, default to suppress-start):**

Option A — Config-DB (cleanest if Repo must boot): Add to `config/test.exs`:
```elixir
config :chimeway, Chimeway.Repo,
  hostname: System.get_env("SIGRA_TEST_PG_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("SIGRA_TEST_PG_PORT", "5432")),
  username: System.get_env("SIGRA_TEST_PG_USERNAME", "postgres"),
  password: System.get_env("SIGRA_TEST_PG_PASSWORD", "postgres"),
  database: System.get_env("SIGRA_TEST_PG_DATABASE", "sigra_test"),
  pool: Ecto.Adapters.SQL.Sandbox
```

Option B — Suppress-start (cleanest since Repo is never exercised): Add to Sigra's `mix.exs` `application/0`:
```elixir
included_applications: [:chimeway]
```
This makes Sigra responsible for starting Chimeway, but since Sigra's Application starts no children related to Chimeway, the Chimeway.Application supervisor never runs. **However**: this is a library — using `included_applications` in a library is unusual and may interfere with host apps that legitimately use Chimeway.

Option C — In-test suppression: Stop chimeway's Repo in `test_helper.exs` after boot:
```elixir
# Suppress Chimeway.Repo startup noise (not exercised by Sigra tests)
if Code.ensure_loaded?(Chimeway.Repo) do
  Supervisor.terminate_child(Chimeway.Supervisor, Chimeway.Repo)
end
```

**Recommendation (planner-facing):** Option A (config-DB) is the safest: it doesn't affect library behavior, it's the same test DB that's already required, and it silences the noise by giving the Repo valid config. The Repo won't be used by any test but it starts clean.

### D-19: `Sigra.UpgradeIntegrationTest` Graceful Preflight Skip

The test module (`test/upgrade_test.exs`):
- `@moduletag :upgrade` and `@moduletag timeout: 600_000` [VERIFIED: live codebase]
- Uses `Sigra.Test.InstallFixture` which shells out to `mix phx.new` — requires phx_new 1.8.8 archive
- `test/test_helper.exs` has NO tag exclusions currently [VERIFIED: live codebase]
- CI installs phx_new 1.8.8 at multiple job steps [VERIFIED: ci.yml]

**Preflight skip design:** Add a `setup_all` guard at the top of the test module (or use `ExUnit.configure(exclude: [:upgrade])` conditionally in `test_helper.exs`) that checks:
1. Whether the phx_new archive is installed at the right version
2. Whether a live database is reachable

If prerequisites are absent, call `ExUnit.skip("Upgrade test requires phx_new 1.8.8 and live DB")` (or set `@moduletag :skip` conditionally). This must NOT use blanket `:postgres` exclusion.

The archive check pattern:
```elixir
setup_all do
  # Graceful preflight skip — D-19
  phx_new_ok? = match?({_, 0}, System.cmd("mix", ["archive.list"], stderr_to_stdout: true))
                |> ... # check for "phx_new-1.8.8" in output
  db_ok? = # attempt a connection or check env
  if not phx_new_ok? or not db_ok? do
    IO.puts("Skipping UpgradeIntegrationTest: prerequisites absent (archive or DB)")
    :skip  # ExUnit interprets :skip from setup_all as module-level skip
  else
    :ok
  end
end
```

Note: in ExUnit, returning `{:ok, :skip}` from `setup_all` does NOT skip. The correct approach is to use `ExUnit.Case.register_module_attribute` patterns or wrap the test at the module level. The planner should use `@tag :skip` set conditionally in `setup_all` or use `ExUnit.configure(exclude: :upgrade)` in `test_helper.exs` when the archive is absent.

A cleaner ExUnit pattern: add to `test_helper.exs` BEFORE `ExUnit.start()`:
```elixir
upgrade_prereqs? = System.find_executable("mix") != nil &&
  # check phx_new archive exists at right version
  ...
unless upgrade_prereqs? do
  ExUnit.configure(exclude: [:upgrade])
end
ExUnit.start()
```
This is clean, not a blanket `:postgres` exclusion, and still runs `:upgrade` tests in CI where prerequisites exist.

---

## Standard Stack

No new packages in this phase. All work is refactoring, hardening, and configuration changes to existing code.

---

## Package Legitimacy Audit

Not applicable — no new external packages are added in this phase.

---

## Architecture Patterns

### Established Patterns Already in Use

**Optional-dep gating:** `Sigra.OptionalDeps` module with `Code.ensure_loaded?/1` guards. New `oban_running?/0` follows the same module pattern as `oban_available?/0`.

**Session store callback:** `@callback delete/2` in `Sigra.SessionStore` — public API; adding user_id check happens above the callback call in `Sigra.Auth`, not inside the store implementation.

**Shared admin components:** `Sigra.Admin.Components` — `use Phoenix.Component`. Session helpers promoted here become public functions (not HEEx components), accessible via `import Sigra.Admin.Components` which already exists in both LiveView files.

### Anti-Patterns to Avoid

- **Don't change `@callback delete/2` signature** — D-08 guard goes in `delete_session/3`, not the store callback.
- **Don't use blanket `:postgres` exclusion** — CLAUDE.md explicitly forbids this; use targeted preflight skip.
- **Don't remove `var(--sg-*)` selector references from app.css** — only remove orphaned `:root` VALUE fragments. The `var(--sg-*)` in `.vt-*` selectors are intentional.
- **Don't suppress all of Chimeway's Application** — use config-DB approach to let it start cleanly, or targeted Repo suppress if the planner chooses Option B/C.

---

## Common Pitfalls

### Pitfall 1: Confusing `oban_running?/1` in `forwarders.ex` with the New SOT

**What goes wrong:** Planner treats `forwarders.ex`'s `oban_running?/1` as a simple pattern to extract, but it has an opts-override path for test injection that `delivery.ex`'s `oban_running?/0` does not.
**How to avoid:** The new `Sigra.OptionalDeps.oban_running?/0` should implement the production path only. `forwarders.ex`'s `oban_running?/1` should wrap it (calling `oban_running?()` in the `:error` branch) while keeping its opts-override path for tests.

### Pitfall 2: D-08 Guard Creates a Double-Fetch

**What goes wrong:** The D-08 guard fetches the session to check user_id, then `delete/2` also does `repo.get_by` internally — two round-trips for every admin revoke.
**How to avoid:** This is acceptable (two queries vs. one is not a perf concern for admin session revocation). Alternatively, the guard could pass `user_id` into the store's delete opts and let the store filter — but that changes the `@callback delete/2` signature, which D-08 explicitly forbids.

### Pitfall 3: app.css CI Guard — Orphan Detection is Tricky

**What goes wrong:** A regex that fires on `*/` at line start also fires on legitimate multi-line comment ends.
**How to avoid:** The regex must target standalone `*/` that are NOT preceded by `/*` on the same line AND appear inside a `:root {}` block. A simple approach: grep for lines matching the known corruption patterns (bare shadow values, bare transition values with `var(--sg-...)`). Or: use `awk` to track brace depth and flag bare value-like lines at depth 1.

### Pitfall 4: Upgrade Test Skip — Wrong ExUnit API

**What goes wrong:** Returning `:skip` from `setup_all` doesn't actually skip the tests; the ExUnit API for module-level skip is `ExUnit.configure(exclude: ...)` before `ExUnit.start()`.
**How to avoid:** Use the `test_helper.exs` approach with `ExUnit.configure(exclude: [:upgrade])` when prerequisites are absent.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Oban supervision check | Custom process registry scan | `Process.whereis(Oban)` (already the established pattern) |
| Session user_id validation | Store-level constraint | Library-layer guard in `delete_session/3` using `session_store.fetch/2` |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir) |
| Config file | `mix.exs` (no separate test config file) |
| Quick run command | `mix test --exclude upgrade` |
| Full suite command | `mix test` (with test DB up per CLAUDE.md) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEBT-01 | Oban compiled-but-unsupervised deletion succeeds without crash | unit | `mix test test/sigra/account/deletion_test.exs` | ✅ (add new test case to existing file) |
| DEBT-03 | Admin cannot revoke foreign user's session (user_id mismatch → no-op) | unit | `mix test test/sigra/auth_test.exs` | ✅ (add test to existing auth_test or sessions test) |
| DEBT-05 | app.css CI guard fails if orphan pattern reappears | unit/lint | `bash scripts/ci/app-css-corruption-check.sh` (new) | ❌ Wave 0 |
| HEALTH-03 | `mix test` with only test-DB up = zero spurious failures | smoke | `mix test --exclude upgrade` | ✅ (config change; no new test file) |

### Wave 0 Gaps
- [ ] `scripts/ci/app-css-corruption-check.sh` (or equivalent lint step) — covers DEBT-05 D-17

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V3 Session Management | Yes | `delete_session/3` user_id guard (D-08) |
| V4 Access Control | Yes | Admin cannot revoke foreign session (D-09 regression test) |
| V5 Input Validation | Partial | user_id matching is a form of input validation on opts |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Admin revokes foreign session via known token | Elevation of Privilege | user_id guard in `delete_session/3` |
| Oban job insert bypasses supervision check | Denial of Service (noisy) | `oban_running?/0` centralization |

---

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x blessed path
- **Security:** OWASP throughout; all session operations must maintain token-scoping
- **Testing:** AAA style, flat, self-contained; `mix test` requires live Postgres — NO blanket `:postgres` tag exclusion
- **Test Postgres:** Credentials `postgres/postgres`, database `sigra_test`, or via `SIGRA_TEST_PG_*` env vars
- **phx_new pin:** `phx_new 1.8.8` required for golden tests (CI installs it; local dev must match)
- **GSD workflow:** All changes through GSD entry points (execute-phase here)
- **Admin UI:** Changes must follow `guides/reference/admin-ui-principles.md` and `guides/reference/admin-design-contract.md`; `sg-*` cascade layer must be preserved

---

## Runtime State Inventory

Not applicable — this is not a rename/refactor/migration phase.

---

## Environment Availability

No new external dependencies. All required tools (`mix`, `git`, `bash`) are standard.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL (test DB) | HEALTH-03, DEBT-01 regression test | ✓ (per CLAUDE.md setup) | — | None (required) |
| git | DEBT-04 tag deletion | ✓ | — | None |
| phx_new 1.8.8 | UpgradeIntegrationTest (HEALTH-03) | ✗ locally without setup | — | Preflight skip (D-19) |
| Hex CLI | DEBT-04 retire runbook | ✓ (Jon's env) | — | N/A — documented as manual step |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ExUnit.configure(exclude: [:upgrade])` before `ExUnit.start()` is the correct API for module-level conditional skip | HEALTH-03 preflight skip | Wrong API → upgrade tests still run locally and fail; minor |
| A2 | `included_applications: [:chimeway]` in a library's mix.exs would prevent Chimeway.Application from auto-starting in consumers | HEALTH-03 Chimeway | Could interfere with host apps that legitimately use Chimeway; prefer config-DB |

---

## Open Questions

1. **D-18 Chimeway fix: config-DB vs suppress-start**
   - What we know: No Sigra test uses `Chimeway.Repo`; the Repo starts with no config → noise
   - What's unclear: Whether config-DB (Option A) creates any sandbox/test-isolation issue with Chimeway.Repo sharing the same test DB but not being sandboxed
   - Recommendation: Use config-DB (Option A) — add `config :chimeway, Chimeway.Repo, ...` in `config/test.exs` pointing at `sigra_test`. The Repo will boot but never receive queries from Sigra tests.

2. **D-17 app.css CI guard placement**
   - What we know: The corruption is orphaned value fragments in `:root`; hundreds of `var(--sg-*)` selector references are legitimate
   - What's unclear: Whether an existing CI lint step (like `admin-css-conformance.sh`) can absorb this or a new script is needed
   - Recommendation: New minimal script (< 20 lines) that greps for the specific corruption patterns and fails if found; wire into the main `ci.yml` under a lint job.

---

## Sources

### Primary (HIGH confidence — direct live codebase reads)
- `lib/sigra/account/deletion.ex` — lines 207, 307-330 verified
- `lib/sigra/delivery.ex` — lines 103-115 verified
- `lib/sigra/audit/forwarders.ex` — lines 75-101 verified (DISCREPANCY noted)
- `lib/sigra/optional_deps.ex` — line 79 verified
- `lib/sigra/auth.ex` — lines 1495-1526, 1613-1615 verified
- `lib/sigra/session_stores/ecto.ex` — lines 64-72 verified
- `lib/sigra/session_store.ex` — line 39 verified
- `lib/sigra/admin/users/actions.ex` — lines 9-21 verified (DISCREPANCY: calls `revoke_session/3` not `delete_session/3` directly)
- `lib/sigra/admin/live/user_sessions_live.ex` — full file verified, helper duplication confirmed
- `lib/sigra/admin/live/user_show_live.ex` — helper duplication confirmed
- `lib/sigra/admin/components.ex` — confirmed no session helpers present
- `mix.exs` — line 4 `@version "1.1.0"` confirmed
- `.release-please-manifest.json` — `"1.1.0"` confirmed
- `guides/introduction/contract.md:9` — stale `1.20.0` citation confirmed
- `scripts/ci/panel-schema-check.sh` — file exists, validates v1.42 persona-JTBD artifacts
- `.github/workflows/ci.yml` — zero `panel-schema-check` references confirmed
- `test/example/priv/static/assets/css/app.css` — orphan ranges 28-33, 39-43, 46, 88-91 confirmed; hundreds of legitimate `var(--sg-*)` selector uses noted
- `deps/chimeway/lib/chimeway/application.ex` — unconditional `Chimeway.Repo` child confirmed
- `deps/chimeway/mix.exs` — `mod: {Chimeway.Application, []}` confirmed
- `config/test.exs` — zero `:chimeway` config confirmed
- `test/upgrade_test.exs` — `@moduletag :upgrade`, `@moduletag timeout: 600_000`, `InstallFixture` shell-out confirmed
- `test/test_helper.exs` — zero tag exclusions confirmed
- `git tag -l v1.20.0` — tag exists confirmed

### git tag verification
- `git tag -l "v1.20.0"` → `v1.20.0` [VERIFIED: live codebase]

---

## Metadata

**Confidence breakdown:**
- DEBT-01 Oban guard: HIGH — direct code reads; discrepancy in forwarders.ex complexity documented
- DEBT-02 retire rationale: HIGH — script contents and CI yml both verified
- DEBT-03 session security: HIGH — call chain fully traced; user_id guard absence confirmed
- DEBT-04 version wart: HIGH — tag existence, manifest, contract.md all verified
- DEBT-05 CSS corruption: HIGH — exact line ranges confirmed; scope of `var(--sg-*)` in selectors documented
- HEALTH-03 test noise: HIGH — chimeway boot confirmed; no Sigra test uses Chimeway.Repo confirmed
- ExUnit skip API: ASSUMED (A1) — standard ExUnit knowledge, not re-verified this session

**Research date:** 2026-07-02
**Valid until:** Indefinite (findings are against the live codebase; re-verify only if those files change before planning)
