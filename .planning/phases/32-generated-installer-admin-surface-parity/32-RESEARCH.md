# Phase 32: Generated Installer Admin Surface Parity - Research

**Researched:** 2026-04-17
**Domain:** Elixir code generator (`mix sigra.install`) — template emission + router injection
**Confidence:** HIGH

## Summary

Phase 32 is a focused generator-parity phase with three surgical fixes concentrated in one
feature module and one directory:

1. `lib/sigra/install/features/admin.ex` — `files/1` must emit two additional templates.
2. `priv/templates/sigra.install/admin/router_injection.ex` — two EEx `live` lines must be
   added to the global block, two to the organization block.
3. `priv/templates/sigra.install/admin/impersonation_controller.ex` — new template file,
   parameterized from `test/example/lib/example_web/controllers/admin/impersonation_controller.ex`.

All runtime library wiring is already in place. `lib/sigra/admin/live/users_index_live.ex`
and `lib/sigra/admin/live/user_show_live.ex` exist; `Sigra.Impersonation.{start,stop,evaluate_timeout}`
is implemented; `<%= web_module %>.UserAuth.{begin_impersonation, restore_impersonation,
impersonation_return_to}` is already in the generated `core/user_auth.ex` template. Phase 32
is purely "connect the emission wiring the example app already proves works."

**Primary recommendation:** Three atomic changes in a single plan wave, guarded by a new
generator test that asserts (a) `Admin.files/1` emits both templates, (b) the
router_injection template contains the four required `live` lines, and (c) the existing
`admin-acceptance-smoke.sh` boot gate passes `mix compile --warnings-as-errors` plus new
runtime probes against `/admin/users` and `POST /admin/users/:id/impersonation`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Mount UsersIndexLive / UserShowLive routes in generated host | Router template (priv/templates/sigra.install/admin/router_injection.ex) | — | The router injection is applied to the host's `lib/<otp_app>_web/router.ex`; Sigra never owns the host router at runtime. |
| Emit ImpersonationController into generated host | Install feature template (priv/templates/sigra.install/admin/impersonation_controller.ex) + `Features.Admin.files/1` | Host web layer (controllers/admin/) | Sigra's "own your code" philosophy keeps controllers generated into the host so devs can customize flash copy, redirect logic, etc. |
| Emit AuditExportController into generated host | `Features.Admin.files/1` (template already exists) | Host web layer (controllers/admin/) | Identical pattern to ImpersonationController — host-owned controller with library-owned security primitives. |
| Start/stop impersonation server-side | `Sigra.Impersonation` (library) | Host ImpersonationController (thin seam) | Library owns authorization, session rotation, timeout eval, audit. Controller is a Plug.Conn adapter over the library API. |
| Admin authorization on the mounted live routes | `Sigra.Plug.RequireAdminAccess` + `Sigra.LiveView.AdminScope` | Host `SigraAdminPolicy` | These are already wired in the router_injection pipelines; mounting the LiveViews does not change the authorization tier. |
| Build/verify "it generates and compiles" | `scripts/ci/admin-acceptance-smoke.sh` (existing) | `generated_admin_playwright_smoke` CI job | The smoke scaffolds a fresh Phoenix app, runs `mix sigra.install`, runs `mix compile --warnings-as-errors`, boots the host, and curls routes. |

## Standard Stack

This phase does not introduce new runtime libraries — it wires existing ones. All mentioned
dependencies are already in `mix.exs`.

### Core (relevant to Phase 32)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| EEx | stdlib (Elixir 1.18+) | Template engine for `.ex`/`.exs` templates under `priv/templates/sigra.install/` | Standard Elixir templating; bindings passed as keyword list. `EEx.eval_file/2` and `EEx.eval_string/2` are used by `Sigra.Install.Runner` and `Features.Admin.eval_template!/2` respectively. [VERIFIED: lib/sigra/install/runner.ex:81, lib/sigra/install/features/admin.ex:152] |
| Phoenix | ~> 1.8 (1.8.5 current) | Router DSL, controllers, LiveView mounts | `scope "/", alias: false do` + `live_session` blocks are the canonical Phoenix 1.8 admin-routing pattern. [VERIFIED: test/example/lib/example_web/router.ex] |
| Phoenix LiveView | ~> 1.1 | `live_session` + `on_mount` hooks | The mounted routes use `{Sigra.LiveView.AdminScope, [...]}` on_mount, already declared in the router_injection pipelines. [VERIFIED: priv/templates/sigra.install/admin/router_injection.ex:30-34] |

### Supporting (consumed but not changed)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.Impersonation` (internal) | current | start/stop/evaluate_timeout for impersonation sessions | Called by the new ImpersonationController template; no changes to the library itself. [VERIFIED: lib/sigra/impersonation.ex:100] |
| `Sigra.Admin.Audit.Export` (internal) | current | `csv/3` + `subject_csv/4` producers | Called by the existing (un-emitted) audit_export_controller template; no library changes. [VERIFIED: priv/templates/sigra.install/admin/audit_export_controller.ex:11,21] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Separate plans for each INT (INT-01 / INT-02 / INT-03) | Single plan wave | Combining is correct: all three touch the same narrow surface (`Features.Admin.files/1` + `admin/router_injection.ex`) and share the same generator-test gate. The roadmap success criterion explicitly groups them. [CITED: .planning/ROADMAP.md Phase 32 success criteria] |
| Make the ImpersonationController purely library-owned (no template) | Follow existing hybrid pattern (template + host controller) | Sigra's `CLAUDE.md` philosophy is "own your code" — generated controllers allow devs to customize flash copy and redirect paths. The other admin controller (AuditExportController) is already template-based, so consistency wins. [CITED: CLAUDE.md "own your code" principle, verified in priv/templates/sigra.install/admin/audit_export_controller.ex] |
| Use an injection fragment (like org switcher) instead of a standalone controller template | Standalone `.ex` template emitted by `files/1` | The impersonation controller is a full module (~140 lines). An injection fragment is only appropriate for small additions to existing files. AuditExportController uses the standalone pattern; follow it. |

**Installation:** No new deps. The phase is template + file-emission work.

**Version verification:** All referenced libraries verified current via project `CLAUDE.md`
and `mix.exs` — `phoenix ~> 1.8`, `phoenix_live_view ~> 1.1`, Elixir 1.18+/OTP 27+. No
upstream registry check needed because this phase adds no deps.

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    mix sigra.install --yes Accounts User users               │
│                                                                              │
│ Mix.Tasks.Sigra.Install.run/1                                                │
│   │                                                                          │
│   ├─► build_binding/4 — assembles %Keyword{} with otp_app, web_module,       │
│   │                     app_module, context_module, organizations?, etc.     │
│   │                                                                          │
│   ▼                                                                          │
│ Sigra.Install.Runner.run/3                                                   │
│   │                                                                          │
│   ├─► Filter @features by feature.enabled?(opts)                             │
│   │   [Core, Organizations, Passkeys, Admin]                                 │
│   │                                                                          │
│   ├─► MigrationTimestamps.allocate/2 + overlay_existing_migrations           │
│   │                                                                          │
│   ├─► For each active feature:                                               │
│   │     │                                                                    │
│   │     ├─► run_files(feature, binding) ◄────── Features.Admin.files/1       │
│   │     │     │                                 returns [{:eex, src, tgt}]  │
│   │     │     │                                                              │
│   │     │     ▼                                                              │
│   │     │   EEx.eval_file(template, binding) ─► Mix.Generator.create_file    │
│   │     │                                                                    │
│   │     ├─► run_injections(feature, binding) ◄── Features.Admin.injections/1 │
│   │     │     │                                  returns [%Injection{}]     │
│   │     │     │                                                              │
│   │     │     ▼                                                              │
│   │     │   For each %Injection{target, marker, anchor, content}:            │
│   │     │     │                                                              │
│   │     │     └─► If marker already in target file: skip (idempotency).      │
│   │     │         Else: Sigra.Install.Injector.apply — splice content at     │
│   │     │         anchor position (:before_last_end, :after_use_block, …).   │
│   │     │                                                                    │
│   │     └─► run_post_instructions(feature, binding)                          │
│   │                                                                          │
│   ▼                                                                          │
│ Generated host app has:                                                      │
│   lib/<otp_app>_web/router.ex    ◄── rendered admin/router_injection.ex      │
│   lib/<otp_app>_web/controllers/admin/impersonation_controller.ex (NEW)      │
│   lib/<otp_app>_web/controllers/admin/audit_export_controller.ex (NEW)       │
│   lib/<otp_app>/sigra_admin_policy.ex                                        │
│   lib/<otp_app>_web/components/admin_shell.ex                                │
└──────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                 scripts/ci/admin-acceptance-smoke.sh (existing)              │
│                                                                              │
│   1. mix phx.new sigra_admin_smoke                                           │
│   2. mix deps.get                                                            │
│   3. mix sigra.install --yes Accounts User users --no-passkeys               │
│   4. Patch SigraAdminPolicy                                                  │
│   5. mix compile --warnings-as-errors   ◄── fails if template references     │
│                                            undefined modules (INT-02, -03)   │
│   6. mix ecto.create && mix ecto.migrate                                     │
│   7. Seed platform-admin + org-admin users                                   │
│   8. mix phx.server & boot loop                                              │
│   9. curl probes to /admin/audit, /admin/organizations/:slug/audit, …        │
│  10. Playwright admin-generated.spec.ts (chromium + mobile + dark)           │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Why this matters:** The generated-host smoke at step 5 is the failing gate for INT-02 and
INT-03 (modules referenced by the router but never emitted as templates). Step 9's curl
probes against `/admin/users` and a `POST /impersonation` (new probes added by Phase 32) are
the failing gate for INT-01 (unrouted) and INT-02 (runtime 500 even if compile passes for
the scope-aliased `delete "/impersonation"` path).

### Component Responsibilities

| Component | File | Responsibility |
|-----------|------|----------------|
| Feature manifest | `lib/sigra/install/features/admin.ex` | Declares which templates to emit (`files/1`), which injections to apply (`injections/1`), migrations (none), post-install hints. |
| Router template | `priv/templates/sigra.install/admin/router_injection.ex` | EEx text that is evaluated with `web_module`/`app_module` bindings, then injected into `lib/<otp_app>_web/router.ex` at `:before_last_end`. |
| ImpersonationController template (NEW) | `priv/templates/sigra.install/admin/impersonation_controller.ex` | EEx template emitted to `lib/<otp_app>_web/controllers/admin/impersonation_controller.ex`. Calls `Sigra.Impersonation.start/stop` + `UserAuth.begin_impersonation/restore_impersonation`. |
| AuditExportController template (exists, un-emitted) | `priv/templates/sigra.install/admin/audit_export_controller.ex` | Already parameterized (line 1: `defmodule <%= web_module %>.Admin.AuditExportController`). Emission is a one-line tuple add in `files/1`. |
| Generator test | `test/sigra/install/features/admin_test.exs` | Must be extended: assert `files/1` returns both new tuples; assert router template contains new `live` lines; assert template files exist on disk. |
| Generated-host boot smoke | `scripts/ci/admin-acceptance-smoke.sh` | Must be extended with `/admin/users` and `/admin/users/:id/impersonation` probes (status-only, non-5xx gate). |

### Recommended Project Structure

```
lib/sigra/install/features/
├── admin.ex                    # UPDATE: files/1 adds 2 tuples

priv/templates/sigra.install/admin/
├── audit_export_controller.ex  # EXISTS, will be emitted
├── impersonation_controller.ex # NEW
├── policy.ex                   # unchanged
├── router_injection.ex         # UPDATE: 4 live lines added
└── components/
    └── admin_shell.ex          # unchanged (Phase 33 territory — INT-04)

test/sigra/install/features/
├── admin_test.exs              # UPDATE: extend files/1 and template assertions
└── coverage_test.exs           # automatically passes once files/1 owns both templates

scripts/ci/
└── admin-acceptance-smoke.sh   # UPDATE: add /admin/users + impersonation probes
```

### Pattern 1: Feature `files/1` tuple shape

**What:** Every entry in `files/1` is `{:eex, source_relative_to_templates, target_relative_to_project_root}`.
**When to use:** Every template the feature owns that should be emitted (not an injection).
**Example:**
```elixir
# Source: lib/sigra/install/features/admin.ex (current)
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

# Source: Phase 32 target state (add two tuples)
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

### Pattern 2: EEx template parameterization

**What:** Templates use `<%= web_module %>`, `<%= app_module %>`, `<%= context_module %>`,
`<%= otp_app %>`. `organizations?` is a boolean flag for conditional blocks. The binding is
assembled in `Mix.Tasks.Sigra.Install.build_binding/4`.
**When to use:** Every reference to a host module name must be an EEx interpolation.
**Example (from existing audit_export_controller template):**
```elixir
# Source: priv/templates/sigra.install/admin/audit_export_controller.ex
defmodule <%= web_module %>.Admin.AuditExportController do
  use <%= web_module %>, :controller
  alias <%= app_module %>.Accounts

  defp export_config do
    %{Accounts.sigra_config() | scope_module: <%= app_module %>.Accounts.Scope}
  end
end
```

### Pattern 3: Router template structure

**What:** The `admin/router_injection.ex` template is a multi-section block that defines
pipelines, then scope-based route groups separated by `live_session` boundaries.
**Layout:**
1. Pipelines (`:admin_global`, `:admin_organization`).
2. Global non-live controller-based admin scope (POSTs, exports).
3. Global admin `live_session` block (where UsersIndexLive + UserShowLive go).
4. Organization-scoped non-live controller-based scope.
5. Organization-scoped admin `live_session` block (where scoped UsersIndexLive + UserShowLive go).
6. Impersonation stop scope (`delete "/impersonation"` outside admin-only scopes).

**Surgical diff required (lines relative to current template):**

| Location | Current | After |
|----------|---------|-------|
| Global live_session (line ~37, between AuditIndexLive and AuditUserLive) | 3 live lines | 5 live lines: add `live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` + `live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` |
| Organization live_session (line ~65-66, between AuditIndexLive and AuditUserLive) | 3 live lines | 5 live lines: add `live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` + `live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` |

These mirror `test/example/lib/example_web/router.ex:237-238` (global) and `:269,271` (org).

### Anti-Patterns to Avoid

- **Adding `<%= if organizations? do %>` guards around admin-only code:** The existing
  `admin/router_injection.ex` already unconditionally references `<%= app_module %>.Organizations`
  (line 13, 59). Admin already assumes organizations is present; matching that convention
  in the new impersonation controller keeps the "admin implies organizations" invariant
  without introducing a new code path. If a user runs `--no-organizations --admin`, that
  combination is already broken by existing code — not Phase 32's problem to solve.
- **Touching `Sigra.Install.Runner` or `Sigra.Install.Injector`:** The runner/injector is
  feature-agnostic. Phase 32 is purely about feature manifest and template content — zero
  runner changes.
- **Extending coverage_test.exs' `@known_drift` allowlist:** If Phase 32 succeeds,
  `audit_export_controller.ex` should move OUT of the "pre-existing orphan" bucket by
  being registered in `files/1`. Do NOT paper over INT-03 by adding the template to
  `@known_drift` in `test/sigra/install/features/coverage_test.exs:103-144` — that would
  defeat the drift-detection mechanism.
- **Hand-coding the ImpersonationController template:** The template should be a direct
  parameterization of `test/example/lib/example_web/controllers/admin/impersonation_controller.ex`.
  Rewriting any logic (sudo fresh-check, return_to safety, client_ip/user_agent helpers)
  risks drift from the example app's proven behavior.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Impersonation session rotation | New session-management logic in the controller | `<%= web_module %>.UserAuth.begin_impersonation/4` + `restore_impersonation/1` (already in generated `core/user_auth.ex` template) | The UserAuth template already handles session renewal, CSRF token delete, impersonator_user_token key storage, return_to path, and remember_me cookie interactions. Reimplementing risks CSRF/fixation bugs. [VERIFIED: priv/templates/sigra.install/core/user_auth.ex:23,89,98,187] |
| Target-user authorization | Manual policy check in controller | `Sigra.Impersonation.start/5` (calls `Admin.Authorizer.authorize_impersonation_target!/2` internally) | Library owns the authorization decision; controller just dispatches. [VERIFIED: lib/sigra/impersonation.ex:100] |
| CSV export | New CSV writer | `Sigra.Admin.Audit.Export.{csv/3, subject_csv/4}` (already in library) | AuditExportController template is already written against this API; it just needs to be emitted. [VERIFIED: priv/templates/sigra.install/admin/audit_export_controller.ex:11,21] |
| Sudo-fresh detection | New time window logic | Existing `@sudo_window 300` pattern in example controller (matches Sigra.Session `sudo_at` semantics) | Copy verbatim from the example controller; the `Sigra.Session` struct's `sudo_at` field is the canonical source. [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex:13,132] |
| Safe return_to validation | New URL validator | Copy `safe_return_to/1` from example controller (checks leading `/` but not `//`) | Matches the pattern used in `UserAuth.log_in_user/3`; change-averse. [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex:112] |
| Generator test assertion framework | New test harness | Extend `test/sigra/install/features/admin_test.exs` and rely on existing `coverage_test.exs` | The existing patterns already assert `files/1` tuple contents, template file existence on disk, and the `@known_drift` allowlist catches orphans. [VERIFIED: test/sigra/install/features/admin_test.exs:18-27, test/sigra/install/features/coverage_test.exs:103-144] |

**Key insight:** Every capability Phase 32 needs already exists elsewhere in the codebase.
The phase is integration, not invention. The delta is purely (a) template file content,
(b) one update to `files/1`, (c) regression tests.

## Common Pitfalls

### Pitfall 1: `mix compile --warnings-as-errors` does NOT catch unrouted modules

**What goes wrong:** Phoenix router DSL accepts any atom as a controller target. The
compiler does not verify the referenced module is defined. `router.ex` with
`post "/x", MyApp.DoesNotExist, :create` compiles cleanly.

**Why it happens:** Phoenix routes are resolved at request dispatch time, not compile time.
The router builds a dispatch table of atom tuples; if the atom resolves to an undefined
module at runtime, Phoenix raises `UndefinedFunctionError` on first request.

**How to avoid:** Do NOT rely on `mix compile --warnings-as-errors` as the gate for
INT-02 regression. The gate must be a real HTTP probe against the affected routes. The
existing `admin-acceptance-smoke.sh` boots the host and curls routes; extend it with
probes for `POST /admin/users/:id/impersonation` and `DELETE /impersonation` that assert
status is NOT 500.

**Warning signs:** If the generator test passes and `mix compile` is green but
`admin-acceptance-smoke.sh` fails on a curl probe, INT-02 has regressed.

### Pitfall 2: Orphan template allowlist drift

**What goes wrong:** `test/sigra/install/features/coverage_test.exs:103-144` maintains a
`@known_drift` allowlist of templates that exist on disk but aren't in any feature's
`files/1`. After Phase 32, `admin/audit_export_controller.ex` should be out of the
admin entry in `@known_drift` (which is currently `[]` — the orphan is not even
allowlisted, so coverage_test is currently red OR the orphan scan misses it).

**Why it happens:** `coverage_test.exs` walks `priv/templates/sigra.install/admin/**/*.{ex,exs}`
and compares against `Admin.files/1`. With the phase change, `audit_export_controller.ex`
will be listed in `files/1` — the orphan vanishes automatically.

**How to avoid:** Verify the coverage test runs green after Phase 32 changes land. If it's
already red (expected — see "Warning signs" below), the phase fixes it. If it's green
today, investigate why the orphan was not detected.

**Warning signs:** Run `mix test test/sigra/install/features/coverage_test.exs` before
Phase 32 starts. If it's green, the coverage test has a gap that should be noted but not
blocked on (fixing the gap is Phase 35's shift-left automation territory).

### Pitfall 3: Router template idempotency marker collision

**What goes wrong:** `Features.Admin.router_injection/2` uses marker `"# Sigra admin"`.
If a previous install wrote that marker into the host router, a re-run of
`mix sigra.install` will skip the entire block — meaning NEW routes added by Phase 32
will NOT land in hosts that were installed before Phase 32 shipped.

**Why it happens:** `Sigra.Install.Injector.apply/2` treats marker presence as "already
injected" and no-ops. This is the intended idempotency contract (GEN-04) but it means
upgrades to the router block require a different migration path (manual re-run with the
block removed, or a new marker).

**How to avoid:** Explicitly document that Phase 32 affects NEW installs only. Existing
hosts that need the new routes must either (a) re-run `mix sigra.install` after manually
removing the `# Sigra admin` block, or (b) manually add the two `live` lines per the
generated diff. Consider adding a note to `priv/sigra.upgrade.exs` or an upgrade-guide entry.

**Warning signs:** A user reports "I ran the upgrade but `/admin/users` still 404s."
Answer: their router has the pre-Phase-32 injection and the marker is preventing re-inject.

### Pitfall 4: EEx parameterization mistakes in the new ImpersonationController template

**What goes wrong:** The example controller uses `ExampleWeb`, `Example`, `Example.Accounts`,
`Example.Accounts.Scope`, `Example.Organizations`. The template must translate each
reference. Missing one leaves `Example.*` hard-coded in every generated host — tests pass
in the example app, generated host breaks.

**Mapping table (from example → template):**
| Example app reference | Template replacement |
|----------------------|---------------------|
| `ExampleWeb` | `<%= web_module %>` |
| `Example.Accounts` | `<%= context_module %>` |
| `Example.Accounts.Scope` | `<%= context_module %>.Scope` |
| `Example.Organizations` | `<%= app_module %>.Organizations` |
| `defmodule ExampleWeb.Admin.ImpersonationController` | `defmodule <%= web_module %>.Admin.ImpersonationController` |

**How to avoid:** After writing the template, render it with a fixture binding
(`web_module: "MyAppWeb", app_module: "MyApp", context_module: "MyApp.Accounts"`) and grep
for any `Example` literal — should be zero matches. The generator test MUST include this
grep-as-assertion.

**Warning signs:** `mix compile --warnings-as-errors` on the generated host fails with
`** (CompileError) module Example.Organizations is not loaded`.

### Pitfall 5: Router template — hand-editing breaks the example mirror

**What goes wrong:** Phase 32 Success Criterion #1 says "mirroring
`test/example/lib/example_web/router.ex:237-272`." If someone edits the example router
(Phase 33 is about admin_shell nav, but future phases may touch routes), the mirror
assertion silently drifts.

**How to avoid:** The generator test for Phase 32 should assert the template contains the
four specific `live` lines by literal string match, NOT by "matches the example router."
This makes the test independent of example-router evolution.

**Warning signs:** Generator test passes but `admin-acceptance-smoke.sh` fails on
`/admin/users` probe.

## Runtime State Inventory

> This is NOT a rename/refactor/migration phase. It is a greenfield-emission phase
> (new files + new lines in existing templates). No runtime state migration is required.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified by grep for "impersonation" / "audit_export" in migrations/: zero matches in `priv/templates/sigra.install/admin/`. No schema changes. | None |
| Live service config | None — verified: no n8n, no external services referenced. Phase is pure Elixir code generation. | None |
| OS-registered state | None — no scheduled tasks, systemd units, or pm2 processes. | None |
| Secrets/env vars | None — `admin-acceptance-smoke.sh` uses `SIGRA_ADMIN_PASSWORD` / `SIGRA_PLATFORM_ADMIN_EMAIL` (already in place). No new env vars introduced. | None |
| Build artifacts | None — `mix compile` rebuilds from source. No `.beam` caches to invalidate. `deps/sigra/priv/templates/` is refreshed when users run `mix deps.compile sigra`. | None for Phase 32; document in upgrade guide that users should `mix deps.update sigra && mix deps.compile sigra` to pick up template changes. |

**Idempotency edge case:** For EXISTING generated hosts running `mix sigra.install` again,
the router `"# Sigra admin"` marker already present will skip re-injection (Pitfall 3 above).
This is an "action required" but for the user, not for the phase — add to post-install
instructions if a doc task lands in Phase 32's plan scope. Deferred to Phase 33+ if out of
scope.

## Environment Availability

> Phase 32 is code-only changes. External dependencies (PostgreSQL, Node for Playwright,
> `mix phx.new`) are the same as every other admin-workflow phase and are already proven
> available on CI and documented in `CLAUDE.md` Local Development Prerequisites.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | admin-acceptance-smoke.sh boot | ✓ (verified in `CLAUDE.md`) | 16-alpine container OK | — |
| `mix phx.new` | smoke scaffold | ✓ (installed with Phoenix ~> 1.8 dep) | 1.8.5 | — |
| Node + Playwright | generated-host Playwright spec | ✓ | node_modules present under test/example/priv/playwright | — |
| Docker (optional) | disposable postgres container | ✓ (documented) | — | `brew services start postgresql` |

**No missing dependencies.** Every piece of infrastructure needed already exists and is
exercised by current CI.

## Validation Architecture

This phase has `nyquist_validation: true` per `.planning/config.json` and MUST prove the
generated host works at runtime — not merely that templates exist and parameterize.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18+) for generator unit tests + Bash smoke (`admin-acceptance-smoke.sh`) for integration |
| Config file | `test/test_helper.exs` (unit tests), `scripts/ci/admin-acceptance-smoke.sh` (smoke driver), `.github/workflows/ci.yml` (`generated_admin_playwright_smoke` job) |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs --max-failures 1` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/ && GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INT-01 / USER-01 | Router template contains `live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` in global block | unit (EEx render) | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/admin_test.exs -k "router template mounts UsersIndexLive"` | ❌ Wave 0 (new assertion) |
| INT-01 / USER-01 | Router template contains `live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` in org block | unit (EEx render) | same as above | ❌ Wave 0 |
| INT-01 / USER-03 | Router template contains `live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` in global block | unit (EEx render) | same as above | ❌ Wave 0 |
| INT-01 / USER-03 | Router template contains `live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` in org block | unit (EEx render) | same as above | ❌ Wave 0 |
| INT-01 / USER-01 | Generated host responds non-404 to `GET /admin/users` when authenticated as platform admin | runtime smoke | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` (extend script with probe) | ❌ Wave 0 (new probe) |
| INT-02 / IMPR-01 | `Features.Admin.files/1` returns tuple for `admin/impersonation_controller.ex` | unit | `mix test test/sigra/install/features/admin_test.exs -k "files/1 emits impersonation_controller"` | ❌ Wave 0 |
| INT-02 / IMPR-01 | Template file exists at `priv/templates/sigra.install/admin/impersonation_controller.ex` | unit (File.exists?) | same as above | ❌ Wave 0 (template file NEW) |
| INT-02 / IMPR-01 | Template renders with fixture binding and contains zero literal `Example` references | unit (EEx render + refute) | same as above | ❌ Wave 0 |
| INT-02 / IMPR-01 | Generated host responds non-5xx to `POST /admin/users/:id/impersonation` when authenticated as platform admin + sudo-fresh | runtime smoke | `admin-acceptance-smoke.sh --test all` (new probe + seed path) | ❌ Wave 0 |
| INT-02 / IMPR-05 | Generated host responds non-5xx to `DELETE /impersonation` while impersonating | runtime smoke | same as above | ❌ Wave 0 |
| INT-03 / AUD-04 | `Features.Admin.files/1` returns tuple for `admin/audit_export_controller.ex` | unit | `mix test test/sigra/install/features/admin_test.exs -k "files/1 emits audit_export_controller"` | ❌ Wave 0 |
| INT-03 / AUD-04 | Orphan coverage test passes (audit_export_controller no longer orphaned) | unit | `mix test test/sigra/install/features/coverage_test.exs` | ✅ existing (assertion tightens automatically) |
| INT-03 / AUD-04 | Generated host responds 200 or 3xx (auth redirect) on `GET /admin/audit/export.csv` | runtime smoke | already probed in existing `GENERATED_HOST_AUDIT_ROUTES` (admin-acceptance-smoke.sh:262-267) | ✅ existing — probe will transition from 5xx to non-5xx after fix |
| All 3 INT | Full generated-host boot + Playwright flows | runtime smoke + Playwright | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` | ✅ existing — admin-generated.spec.ts runs after smoke |

### Sampling Rate

- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs --max-failures 1` (< 10s)
- **Per wave merge:** Run quick command + `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` (~4 minutes on CI, includes `mix phx.new` + full boot)
- **Phase gate:** Full suite green. The `generated_admin_playwright_smoke` CI job is the
  canonical green signal before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] New template file: `priv/templates/sigra.install/admin/impersonation_controller.ex` — parameterized from `test/example/lib/example_web/controllers/admin/impersonation_controller.ex`.
- [ ] Extend `test/sigra/install/features/admin_test.exs` with:
  - `test "files/1 emits impersonation_controller"` — asserts tuple shape and path `lib/my_app_web/controllers/admin/impersonation_controller.ex`.
  - `test "files/1 emits audit_export_controller"` — asserts tuple shape and path `lib/my_app_web/controllers/admin/audit_export_controller.ex`.
  - `test "router template mounts UsersIndexLive in global block"` — renders template and greps for `live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index`.
  - `test "router template mounts UserShowLive in global block"` — greps for `live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show`.
  - `test "router template mounts UsersIndexLive in organization block"` — greps for `live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index`.
  - `test "router template mounts UserShowLive in organization block"` — greps for `live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show`.
  - `test "impersonation_controller template renders with no literal Example references"` — EEx render fixture + `refute content =~ "Example"`.
  - `test "impersonation_controller template exists on disk"` — `assert File.exists?("priv/templates/sigra.install/admin/impersonation_controller.ex")`.
- [ ] Extend `scripts/ci/admin-acceptance-smoke.sh`:
  - Add `/admin/users` to `GENERATED_HOST_AUDIT_ROUTES` (or a parallel `GENERATED_HOST_USER_ROUTES` array) with non-5xx assertion.
  - Add a POST probe for impersonation — requires a logged-in session cookie; simplest form: curl the sudo page first, then curl `POST /admin/users/<seeded-user-id>/impersonation` and assert non-5xx. If that's too complex for bash, defer to Playwright admin-generated.spec.ts and add a `test.describe("impersonation")` block there (Phase 34 territory per roadmap, but a minimal probe here reduces cross-phase dependency).
- [ ] No framework install needed — ExUnit, Phoenix, mix all already present.

### Nyquist check: Does "files exist" imply "works at runtime"?

No. Nyquist sampling requires proving the behavior, not just the artifact. This phase's
specific trap is that template files can exist AND be emitted AND parameterize correctly,
yet the generated host can still 500 at runtime if (a) a route references a controller
module with a typo, (b) a controller calls a library function that's been renamed, or
(c) the controller's session keys don't match what UserAuth expects.

The `admin-acceptance-smoke.sh` boot-and-probe gate is the Nyquist-satisfying signal:
real HTTP against a real generated host. Unit tests alone on `files/1` are NOT sufficient.

## Code Examples

### Example 1: Template file for ImpersonationController (new)

**Source derivation:** Copy `test/example/lib/example_web/controllers/admin/impersonation_controller.ex`
verbatim, then apply the 5-rule parameterization table from Pitfall 4.

```elixir
# priv/templates/sigra.install/admin/impersonation_controller.ex
defmodule <%= web_module %>.Admin.ImpersonationController do
  @moduledoc """
  Controller-owned impersonation start and stop endpoints.
  """

  use <%= web_module %>, :controller

  import Plug.Conn

  alias <%= context_module %>
  alias <%= web_module %>.AuthErrorHandler
  alias <%= web_module %>.UserAuth

  @sudo_window 300

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
          conn
          |> AuthErrorHandler.auth_error(:not_found, [])
          |> halt()

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

  def delete(conn, params) do
    current_scope = conn.assigns.current_scope
    current_session = conn.private[:sigra_session]
    admin_token = get_session(conn, :impersonator_user_token)

    case {current_scope, current_session, admin_token} do
      {%{impersonating_from: %_{}} = scope, %Sigra.Session{} = session, admin_token}
      when is_binary(admin_token) ->
        {:ok, _result} =
          Sigra.Impersonation.stop(
            impersonation_config(),
            scope,
            session,
            admin_token: admin_token,
            ip_address: client_ip(conn),
            user_agent: client_user_agent(conn)
          )

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

  defp impersonation_target(user_id) do
    user = <%= context_module %>.get_user!(user_id)

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

  defp client_ip(conn) do
    conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip))
  end

  defp client_user_agent(conn) do
    conn |> get_req_header("user-agent") |> List.first() || ""
  end

  defp impersonation_config do
    %{<%= context_module %>.sigra_config() | scope_module: <%= context_module %>.Scope}
  end

  defp sudo_fresh?(%Sigra.Session{sudo_at: %DateTime{} = sudo_at}) do
    DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= @sudo_window
  end

  defp sudo_fresh?(_session), do: false

  defp sudo_path(conn, params) do
    return_to = current_path(conn, Map.take(params, ["return_to"]))
    "/users/sudo?return_to=#{URI.encode_www_form(return_to)}"
  end
end
```

**Parameterization verified:** Zero literal `Example` tokens remain. Context module alias
(`alias <%= context_module %>`) is used bare because the example uses `alias Example.Accounts`
and then references `Accounts.get_user!/1`, `Accounts.sigra_config/0`, etc. — the alias
ceremony produces identical downstream usage.

### Example 2: Files/1 update

```elixir
# lib/sigra/install/features/admin.ex — AFTER Phase 32
@impl true
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

### Example 3: Router template diff

```diff
--- a/priv/templates/sigra.install/admin/router_injection.ex
+++ b/priv/templates/sigra.install/admin/router_injection.ex
@@ -34,6 +34,8 @@
     ] do
       live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index
       live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
+      live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
+      live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
       live "/admin/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show
     end
   end
@@ -62,6 +64,8 @@
     ] do
       live "/", Elixir.Sigra.Admin.Live.OrganizationLive, :show
       live "/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
+      live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
+      live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
       live "/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show
     end
   end
```

### Example 4: Extended generator test assertions

```elixir
# test/sigra/install/features/admin_test.exs — additions
describe "files/1 emission (Phase 32 parity closure)" do
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

  test "all four admin controllers emit to controllers/admin/ subdirectory" do
    files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

    controller_targets =
      files
      |> Enum.map(fn {:eex, _src, tgt} -> tgt end)
      |> Enum.filter(&String.contains?(&1, "controllers/admin/"))

    assert "lib/my_app_web/controllers/admin/impersonation_controller.ex" in controller_targets
    assert "lib/my_app_web/controllers/admin/audit_export_controller.ex" in controller_targets
  end
end

describe "router_injection.ex template (Phase 32 route mounts)" do
  @binding [
    otp_app: :my_app,
    web_module: "MyAppWeb",
    app_module: "MyApp",
    context_module: "MyApp.Accounts"
  ]

  test "mounts UsersIndexLive in global admin live_session" do
    content = render_admin_router_template()
    assert content =~ ~s|live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index|
  end

  test "mounts UserShowLive in global admin live_session" do
    content = render_admin_router_template()
    assert content =~ ~s|live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show|
  end

  test "mounts UsersIndexLive in organization-scoped live_session" do
    content = render_admin_router_template()
    assert content =~ ~s|live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index|
  end

  test "mounts UserShowLive in organization-scoped live_session" do
    content = render_admin_router_template()
    assert content =~ ~s|live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show|
  end

  defp render_admin_router_template do
    "priv/templates/sigra.install/admin/router_injection.ex"
    |> File.read!()
    |> EEx.eval_string(@binding)
  end
end

describe "impersonation_controller template (Phase 32)" do
  test "exists on disk" do
    assert File.exists?("priv/templates/sigra.install/admin/impersonation_controller.ex")
  end

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
  end

  test "renders with all expected Sigra.Impersonation integration points" do
    content =
      "priv/templates/sigra.install/admin/impersonation_controller.ex"
      |> File.read!()
      |> EEx.eval_string(
        web_module: "MyAppWeb",
        app_module: "MyApp",
        context_module: "MyApp.Accounts"
      )

    assert content =~ "Sigra.Impersonation.start("
    assert content =~ "Sigra.Impersonation.stop("
    assert content =~ "UserAuth.begin_impersonation"
    assert content =~ "UserAuth.restore_impersonation"
    assert content =~ ":impersonator_user_token"
  end
end
```

## State of the Art

This phase is unique to Sigra — there is no "state of the art" for auth-library installer
templates beyond project convention. Relevant internal art:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic `Mix.Tasks.Sigra.Install.inject_into_files/2` (v1.0) | Feature-manifest walker (`Sigra.Install.Runner` + `Feature` behaviour) | Phase 11 | Phase 32's three-line fix is possible because features are purely additive — no monolith edits needed. [VERIFIED: lib/sigra/install/runner.ex:11-31 docstring] |
| Router injection as manual string interpolation | EEx-templated `admin/router_injection.ex` read via `read_template!/1` + `eval_template!/2` | Phase 27 | Phase 32 edits template text directly; no code edits in Elixir. [VERIFIED: lib/sigra/install/features/admin.ex:152-159] |
| Orphan detection by hand | `test/sigra/install/features/coverage_test.exs` asserts every on-disk template is owned | Phase 24 | INT-03 was detectable by this test but the `@known_drift` was empty for Admin — the detection worked but the orphan existed silently. Phase 32 resolves by registering. |

**Deprecated/outdated:** None — all patterns touched by Phase 32 are current.

## Project Constraints (from CLAUDE.md)

These directives from `./CLAUDE.md` constrain the plan:

- **Hybrid lib+generator architecture:** Security-critical code (authorization, session
  rotation, audit) stays in the library; customizable code (controllers, routes) is
  generated. Phase 32 adds a generated controller — consistent.
- **"Own your code" philosophy:** Developers can edit the generated `impersonation_controller.ex`
  to customize flash copy, redirect destinations, sudo window duration. The template is the
  starting point, not a locked artifact.
- **Copy-paste over deps when code is small and stable:** Phase 32 does exactly this —
  the controller logic is copied from the example and parameterized; no new abstraction.
- **Phoenix 1.8+ as blessed path:** Router injection uses Phoenix 1.8 `alias: false`,
  `live_session` blocks, `on_mount` hooks. No Pow compatibility concerns.
- **Testing: comprehensive spec coverage — happy path, main error cases, boundary
  conditions. AAA style, flat, self-contained:** Generator tests must be flat `describe`
  blocks with arrange/act/assert. No shared setup mutation across tests.
- **OWASP standards: Argon2id default, all tokens HMAC-protected, enumeration prevention
  by default:** Not directly relevant to template emission, but the ImpersonationController
  template's sudo-fresh check and HMAC-protected impersonation tokens (owned by
  `Sigra.Impersonation`) must NOT be weakened by the template copy.
- **Local development prerequisites: `mix test` requires live Postgres at
  `localhost:5432` with `postgres`/`postgres`:** The generator tests themselves don't need
  Postgres, but `admin-acceptance-smoke.sh` does. This constrains local reproduction of
  the full validation gate.
- **GSD workflow enforcement: Do not make direct repo edits outside a GSD workflow:**
  Phase 32 execution will use `/gsd-execute-phase`; this research output respects that.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | *(none — all claims in this research are verified against the codebase or cited from project docs)* | — | — |

**The Assumptions table is empty.** Every factual claim in sections above is tagged
`[VERIFIED: …]` against a specific file/line or cited from `.planning/` or `CLAUDE.md`.

## Open Questions (RESOLVED)

1. **Should the POST impersonation probe be added to `admin-acceptance-smoke.sh` in Phase 32
   or deferred to Phase 34 (generated-host E2E)?**
   - What we know: Phase 32's success criteria say "closes INT-02" with "generator test
     asserts emission." This is achievable with unit tests alone.
   - What's unclear: Whether Nyquist "prove the behavior" demands a runtime HTTP probe in
     THIS phase or whether the Phase 32 smoke only needs to prove `mix compile
     --warnings-as-errors` passes (which it does NOT catch for the undeclared
     `ImpersonationController` in aliased scope — see Pitfall 1).
   - **RESOLVED:** Include a minimal probe in `admin-acceptance-smoke.sh` that at least
     requests `POST /admin/users/<bogus-id>/impersonation` without auth and asserts status
     is `302` (redirect to login) or `403` — NOT `500`. This distinguishes "controller
     exists and authorization runs" from "controller module missing → 500." Full-path
     impersonation testing waits for Phase 34. Implemented in Plan 02 Task 1.

2. **Should the `#  Sigra admin` marker in the router injection be bumped to force
   re-injection on existing hosts?**
   - What we know: Existing hosts that already installed Sigra pre-Phase-32 will skip the
     new routes due to the marker (Pitfall 3).
   - What's unclear: Whether Phase 32's scope includes an upgrade path for existing hosts,
     or whether this is punted to `mix sigra.upgrade` (Phase 23 artifact) or the upgrade
     guide (Phase 23).
   - **RESOLVED:** Do NOT bump the marker — that would break idempotency for users who ARE
     on the new version. Punt existing-host upgrade path to upgrade-guide documentation
     (Phase 33 or 35 pickup). Implemented in Plan 01 Task 2 (router_injection.ex marker
     left untouched; "Do NOT touch" section explicitly enumerated).

3. **Should the `<%= app_module %>.Organizations` references in the new
   `impersonation_controller.ex` be guarded with `<%= if organizations? do %>`?**
   - What we know: The existing `admin/router_injection.ex` references `<%= app_module
     %>.Organizations` unconditionally (lines 13, 59). Admin effectively assumes
     organizations is present.
   - What's unclear: Whether `--no-admin --no-organizations` was ever a supported combo,
     or whether admin has always been org-dependent.
   - **RESOLVED:** No guard. Match existing admin convention — "admin implies
     organizations" is the codebase invariant. If a future phase needs to support
     `--no-organizations --admin`, it becomes that phase's problem to solve across all of
     admin, not just the new impersonation controller. Implemented in Plan 01 Task 1
     critical invariant #5 ("Zero `<%= if organizations? do %>` guards").

## Sources

### Primary (HIGH confidence — verified via file read)

- `lib/sigra/install/features/admin.ex` — current `files/1`, `injections/1`, router
  injection structure
- `lib/sigra/install/features/core.ex` — reference implementation for full files/injections
  pattern (15+ templates, 7 injections)
- `lib/sigra/install/features/passkeys.ex` — reference for a feature that emits multiple
  templates under a subdir
- `lib/sigra/install/runner.ex` — walker semantics (enabled? filter, files render, injection
  apply, post_instructions)
- `lib/sigra/install/feature.ex` — behaviour contract (5 callbacks)
- `lib/sigra/install/injection.ex` — struct contract (target, marker, anchor, content)
- `lib/sigra/install/injector.ex` — marker-based idempotency implementation
- `lib/mix/tasks/sigra.install.ex` — binding assembly + feature list
- `priv/templates/sigra.install/admin/router_injection.ex` — current template (needs 4 new
  live lines)
- `priv/templates/sigra.install/admin/audit_export_controller.ex` — already parameterized,
  needs emission
- `priv/templates/sigra.install/core/user_auth.ex` — generated `begin_impersonation`,
  `restore_impersonation`, `impersonation_return_to` helpers
- `test/example/lib/example_web/router.ex:217-274` — canonical admin route wiring (mirror
  target)
- `test/example/lib/example_web/controllers/admin/impersonation_controller.ex` — example
  controller to parameterize (143 lines)
- `test/example/lib/example_web/controllers/admin/audit_export_controller.ex` — example
  controller the existing template mirrors
- `test/sigra/install/features/admin_test.exs` — existing generator test, extension target
- `test/sigra/install/features/coverage_test.exs` — orphan detection test
- `test/mix/tasks/sigra.install_test.exs` — template render test patterns
- `scripts/ci/admin-acceptance-smoke.sh` — existing generated-host boot smoke (extension
  target)
- `lib/sigra/impersonation.ex:100` — `authorize_impersonation_target!/2` internal call
- `lib/sigra/admin/live/users_index_live.ex` — library-owned LiveView (mount target)
- `lib/sigra/admin/live/user_show_live.ex` — library-owned LiveView (mount target)

### Secondary (HIGH confidence — project documentation)

- `.planning/ROADMAP.md` — Phase 32 success criteria and dependency chain
- `.planning/milestones/v1.2-REQUIREMENTS.md` — USER-01..04, IMPR-01/03/05, AUD-04 reassignment rationale
- `.planning/milestones/v1.2-MILESTONE-AUDIT.md` — INT-01/02/03 root-cause analysis
- `CLAUDE.md` — project tech stack, constraints, testing philosophy, local dev prerequisites
- `.planning/phases/29-secure-impersonation/29-02-PLAN.md` — prior plan that touched
  `admin/router_injection.ex` and `core/user_auth.ex` for impersonation wiring but did NOT
  create the controller template (the slip this phase closes)
- `.planning/phases/31-automation-first-verification/31-VALIDATION.md` — Nyquist validation
  contract format reference

### Tertiary (LOW confidence / not needed)

- None. This phase is entirely internal to the Sigra codebase. No external library, no
  API, no documentation lookup required.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — All libraries already in `mix.exs`; no new deps introduced.
- Architecture: HIGH — Pattern matches existing admin/passkeys/organizations/core features
  exactly; three files touch the same narrow surface.
- Pitfalls: HIGH — Pitfalls 1 (compile-warnings-not-catching-undefined-routes), 3 (marker
  idempotency), and 4 (EEx parameterization mistakes) are all verified failure modes in
  the existing codebase; Pitfall 2 is verified against `coverage_test.exs` code.
- Validation architecture: HIGH — Existing `admin-acceptance-smoke.sh` is the canonical
  Nyquist-satisfying gate; extending it with three probes is mechanical.
- Open questions: MEDIUM — questions 1 and 2 require discuss-phase decisions; question 3
  recommends matching existing convention.

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (30 days — stable template/installer surface, no upstream
dependency churn expected).
