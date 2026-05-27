# ARCHITECTURE.md — v1.29 SUITE-INTEGRATION integration points

**Domain:** Elixir/Phoenix authentication library, hybrid lib+generator
**Researched:** 2026-05-27
**Overall confidence:** HIGH (all integration points verified against current code)

## Executive summary

The orchestrator's framing carries three assumptions that don't match the repo on the current release branch. Correcting them first, because the roadmap will be sturdier on the real precedents.

1. **There is no `Sigra.Mailers.Adapters.Mailglass` adapter on the v1.28 release branch.** `lib/sigra/mailer.ex` is a thin behaviour (`@callback deliver/3`). EMAIL-RAILS (v1.25, Phases 111–114) shipped the override seam, preview catalog, bounce/complaint normalizer, async-delivery telemetry, and a Mailglass *recipe*. Mailglass integration in the example app is via a generated host `Example.Accounts.Mailer` that the host wires to Mailglass — no library adapter exists. There is no `--with-mailglass` flag in `lib/mix/tasks/sigra.install.ex` (verified against the `@switches` list). Apparent Mailglass adapter modules referenced in some milestone narratives live only on wip/backup branches.
2. **There is no `Sigra.OptionalDeps` module.** The "HARD-02 SOT" mentioned in v1.21 narrative is implemented as a scattered pattern: `if Code.ensure_loaded?(Oban.Worker)` module guards (e.g., `lib/sigra/workers/account_deletion.ex:1`, `audit_cleanup.ex:1`), `no_warn_undefined` whitelist in `mix.exs:65-87`, and one-shot boot warnings in `lib/sigra/application.ex` (`maybe_warn_audit_cleanup_fallback/0`, `verify_vault!/0`).
3. **There is no `mix sigra.doctor` task.** Referenced in narrative but not present as a task (`lib/mix/tasks/` has only `install`, `upgrade`, `gen.oauth`, `fixture.rebless_golden`).

Once those corrections land, the recipe + adapter shape becomes much smaller and matches Sigra's "minimal coupling, host owns wiring" philosophy.

## Real precedents (verified file paths)

### Optional-dep extension pattern (the strongest match)

**Behaviour + impl + Noop fallback triad:**

| Surface | File | Role |
|---|---|---|
| Behaviour | `lib/sigra/rate_limiter.ex` | `@callback check_rate/3` |
| Real impl | `lib/sigra/rate_limiters/hammer.ex` | Uses optional `:hammer` dep |
| Noop | `lib/sigra/rate_limiters/noop.ex` | `@behaviour Sigra.RateLimiter`, always `{:allow, 1}` |
| Boot warning | `lib/sigra/application.ex:68-88` | `Code.ensure_loaded?(Oban)`-style guard, one-shot `Logger.warning` |
| Mix.exs guard | `mix.exs:65-87` | `no_warn_undefined: [Bcrypt, Hammer, ...]` whitelist |

The hashers triad (`lib/sigra/hasher.ex`, `lib/sigra/hashers/argon2.ex`, `lib/sigra/hashers/bcrypt.ex`) follows the same pattern.

### Optional Oban worker pattern

`lib/sigra/workers/account_deletion.ex:1` wraps the entire module in `if Code.ensure_loaded?(Oban.Worker) do`. The companion `lib/sigra/workers.ex` (the `Sigra.Workers` behaviour) is pure (no Oban compile-time dep) and validates required args. Precedent workers: `account_deletion.ex`, `audit_cleanup.ex`, `email_delivery.ex`, `token_cleanup.ex`.

### Audit emission surface (Threadline subscribes here)

`Sigra.Audit.emit_telemetry/1` (`audit.ex:304-310`) fires `[:sigra, :audit, :log]` with `%{count: 1}` and `%{action, actor_id, outcome}`. Fired from three callsites that all gate on successful DB commit:

- `log/3` `{:ok, event}` branch — standalone insert
- `emit_telemetry_from_changes/2` — invoked by callers from `{:ok, changes}` branch of their `repo.transaction/1`
- `log_safe/3` `{:ok, event}` branch — best-effort no-op-on-disable path

**This is the cleanest forwarding point.** No new behaviour callback is needed in `Sigra.Audit` itself.

### Generated-host audit wiring (host owns it)

`test/example/lib/example/accounts.ex:607-609` shows the precedent host wiring:

```elixir
audit: [audit_schema: Example.Accounts.AuditEvent]
```

This is the ONLY audit configuration surface in `Sigra.Config`. There is no current concept of "audit destinations" — the schema is the destination.

### Install feature pattern (the only way to add installer surface)

`lib/sigra/install/feature.ex` defines a 5-callback behaviour: `enabled?/1`, `files/1`, `migrations/1`, `injections/1`, `post_instructions/2`. Adding installer surface = adding a module to the `@features` list in `lib/mix/tasks/sigra.install.ex:41-46`. There is no `--with-*` flag pattern in this codebase; existing flags are either negative (`--no-admin`, `--no-organizations`, `--no-passkeys`) or feature-enables (`--api`, `--jwt`). Feature modules read `enabled?/1` from the parsed opts.

### Recipe wiring (for non-adapter integrations)

`mix.exs:163-202` ExDoc `extras:` list plus `groups_for_extras: [..., Recipes: ~r{guides/recipes/.?}]`. Adding a recipe = drop a Markdown file in `guides/recipes/` AND add an entry to the `extras:` list. The regex group_for assignment is automatic. Existing recipes: `companion-oauth-provider.md`, `custom-user-fields.md`, `deployment.md`, `multi-tenant.md`, `passkeys.md`, `subdomain-auth.md`, `testing.md`. `companion-oauth-provider.md` is the precedent for "ecosystem/companion-lib recipe" tone — sister-lib by role-table, "when not to use," "see also" cross-links.

### Reference example pattern

`test/example/` is a full Phoenix app with its own `mix.exs` (`{:sigra, path: "../..", override: true}`). It is wired into CI via `.github/workflows/ci.yml` at `working-directory: test/example` jobs: compile + test with `--include example_app`, dev test, `example_playwright_smoke` Playwright job. The example app is auth-focused but its tests are the only place real `Sigra.Auth.*` round-trip flows exercise against a live Phoenix server. There is no top-level `examples/` directory.

### Suite-narrative entry-point precedent

`guides/introduction/` contains `installation.md`, `getting-started.md`, `first-hour.md`, `intermediate-production-path.md`, `troubleshooting-install.md`, and upgrade stubs. `getting-started.md` is `main:` in `mix.exs:158`. Adding a suite-narrative landing page = drop a Markdown file under `guides/introduction/` and add to `extras:`.

### Hook seam (alternative integration surface, not used here)

`lib/sigra/hooks.ex` provides a `{module, function}` hook callable via `Sigra.Hooks.maybe_run_hook/4` inside an `Ecto.Multi`. Hooks run **inside** the auth operation's transaction. For Threadline (audit-forwarding), this is *too coupled* — auth must not fail because Threadline is down. Telemetry, not hooks, is the right seam.

## Integration architecture for v1.29

### 1. Threadline audit adapter

**Decision:** Build it as a telemetry handler, not as a pluggable destination inside `Sigra.Audit`. Sigra.Audit's contract stays untouched.

**File:** `lib/sigra/audit/forwarders/threadline.ex` (NEW)

Naming: `forwarders/` (not `adapters/`) because it forwards *already-committed* events to a sink, not selects an alternative storage backend.

**Module shape (mirrors `Sigra.RateLimiters.Hammer`):**

```elixir
if Code.ensure_loaded?(Threadline) do
  defmodule Sigra.Audit.Forwarders.Threadline do
    @behaviour Sigra.Audit.Forwarder
    require Logger

    def attach(opts) do
      :telemetry.attach(
        {__MODULE__, opts[:id] || :default},
        [:sigra, :audit, :log],
        &__MODULE__.handle_event/4,
        opts
      )
    end

    def handle_event(_event, _measurements, metadata, opts) do
      # dispatch path: inline call vs Oban async — see #2 below
    end
  end
end
```

**Behaviour:** `lib/sigra/audit/forwarder.ex` (NEW) — `@callback attach(keyword) :: :ok | {:error, term}`. Tiny — single callback. Mirrors `Sigra.RateLimiter`.

**Dispatch path:** Two-tier, matches `Sigra.Delivery` precedent (`lib/sigra/delivery.ex:103-115`):

- `:auto` (default) — `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil` ⇒ async via `Sigra.Workers.AuditForward` (NEW Oban worker), else inline `Threadline.publish/2`
- `:async` — always Oban (raises if Oban absent at boot)
- `:sync` — always inline (host accepts the latency cost)

**Co-fate semantics:** Threadline forwarding is **post-commit, fire-and-forget**. The telemetry event itself only fires on successful commit, so any audit row Threadline receives is a row that already persisted in Sigra's table. Failures in the forwarder MUST NOT roll back the auth operation. Errors land on a `[:sigra, :audit, :forward_error]` telemetry event for observability (mirrors `:log_safe_error`).

**Config shape (runtime struct, NOT `Application.get_env`):**

Extend `Sigra.Config` (`lib/sigra/config.ex`) with a new `:forwarders` field on the audit keyword:

```elixir
audit: [
  audit_schema: MyApp.Accounts.AuditEvent,
  forwarders: [
    {Sigra.Audit.Forwarders.Threadline,
       endpoint: System.get_env("THREADLINE_URL"),
       api_key: {:system, "THREADLINE_API_KEY"},
       dispatch: :auto}
  ]
]
```

Validate via `NimbleOptions` schema in `Sigra.Config`. Host-attached at boot in `Sigra.Application.start/2`.

**Boot-time optional-dep validation:** Extend `Sigra.Application.start/2`:

- If a forwarder is configured but its module is not loaded ⇒ `Logger.warning`
- If dispatch `:async` and Oban absent ⇒ raise

**Mix.exs guard:** Add `Threadline` and `Sigra.Workers.AuditForward` to the `no_warn_undefined:` list in `mix.exs:65-87`.

### 2. Optional Oban worker for async forwarding

**File:** `lib/sigra/workers/audit_forward.ex` (NEW)

Wrap entire module in `if Code.ensure_loaded?(Oban.Worker) do`. Mirrors `lib/sigra/workers/audit_cleanup.ex` and `account_deletion.ex`. Queue: `:sigra_audit_forward` (new — document in recipe). `max_attempts: 5` with exponential backoff.

### 3. Installer integration — opt-in via config, NOT `--with-threadline`

**Decision:** No `--with-threadline` flag. The codebase has zero `--with-*` flags today. Adding one creates a precedent that will multiply. Forwarders are pure runtime config — no generated host files, no migrations, no router injections. The recipe owns wiring.

**Install golden assertions:** None required — golden tree (`test/fixtures/install_golden/`) does not change.

### 4. Generated-host emissions

**Decision:** Zero. Threadline is pure-library + pure-runtime-config. The host's only generated artifact is what `mix sigra.install` already produces; adopters add the forwarder config block to their existing `sigra_config/0` function. The recipe shows the literal lines to paste.

### 5. Recipes for non-adapter companion libs (Accrue, Lockspire, Mailglass cross-link, Relyra, Rulestead)

**Location convention:** `guides/recipes/companion-libs/<name>.md` (NEW subdirectory).

Rationale: the flat `guides/recipes/` is starting to mix integration patterns with feature recipes. A `companion-libs/` subdir signals "these are integrations with sister libs, not Sigra feature primers."

**mix.exs wiring:**

```elixir
# in extras: list, add:
"guides/recipes/companion-libs/threadline.md",
"guides/recipes/companion-libs/accrue.md",
"guides/recipes/companion-libs/lockspire.md",
"guides/recipes/companion-libs/mailglass.md",
"guides/recipes/companion-libs/relyra.md",
"guides/recipes/companion-libs/rulestead.md",

# in groups_for_extras, add:
"Companion Libraries": ~r{guides/recipes/companion-libs/.?},
# and adjust Recipes regex to ~r{guides/recipes/[^/]+\.md$}
```

**Lockspire recipe note:** `companion-oauth-provider.md` already covers Lockspire at the architecture-pattern level. The new `companion-libs/lockspire.md` should be the *concrete* recipe (mix.exs deps, AccountResolver stub, walkthrough) and cross-link back.

**Mailglass recipe:** Cross-link page summarizing "Mailglass is the default preview/diagnostics adapter; here are the host config lines" and linking to the EMAIL-RAILS docs. 1–2 pages.

**Recipe content template (match `companion-oauth-provider.md`):**

- "What this is + role table"
- Prerequisites
- Architecture sketch (ASCII)
- Rules of thumb
- Concrete config + code block(s)
- "When not to use"
- "See also" cross-links

### 6. Suite narrative landing page

**File:** `guides/introduction/suite-integration.md` (NEW). Add to `mix.exs` `extras:` list.

**Companion ecosystem diagram:** ASCII (not Mermaid) for ExDoc compatibility.

```
                ┌─────────────────────────────────┐
                │       Sigra (auth core)         │
                │  sessions · MFA · passkeys ·    │
                │  audit · webhooks · SSO         │
                └────────┬────────────────────────┘
                         │
    ┌────────────────────┼───────────────────────────┐
    │                    │                           │
┌───▼────┐          ┌────▼─────┐               ┌─────▼─────┐
│ Email  │          │  Audit   │               │  OAuth    │
│ outbox │          │  sink    │               │  AS       │
│Mailglass│         │Threadline│               │ Lockspire │
└────────┘          └──────────┘               └───────────┘

Other adopter-side companions (recipe-only):
Accrue (billing webhook consumer) · Relyra (relationships)
Rulestead (rule engine)
```

**Diminishing Returns Wall connection:** Open the narrative by quoting `MILESTONE-ARC.md`'s wall (no authz engine, no billing, no UI components). Then frame suite-integration as "the seams you bring your own companion library through."

**No separate `ecosystem.md`** — fold the diagram and "who owns what" table into `suite-integration.md`.

### 7. Reference example

**Decision:** Extend `test/example/`, do not create top-level `examples/`.

| Factor | `test/example/` | new `examples/` |
|---|---|---|
| CI wired | YES — 3 jobs in `ci.yml` | NO — new wiring needed |
| Auth focus | YES — already exercises Sigra | Greenfield |
| Playwright smoke | YES | NO |
| Risk to existing tests | Additive only | Zero |
| Hex package size | Excluded (`files:` allowlist) | Same |

**What changes in `test/example/`:**

- `test/example/mix.exs` — add `{:threadline, "~> X.Y", only: [:dev, :test]}` (when published) or path dep if pre-release
- `test/example/lib/example/accounts.ex:607-609` — add the `forwarders:` block under the `audit:` keyword
- `test/example/test/example_web/threadline_forwarder_test.exs` — new test asserting that an audit event triggers a Threadline call (mock via Bypass or Mox)
- `test/example/AGENTS.md` — note the Threadline demo wiring

### 8. Build order — phase sequence with dependencies

Numbered from Phase 131.

**Phase 131 — Threadline forwarder behaviour + library scaffolding**

Why first: it's the only new library code. Phases 132+ depend on it existing.

Artifacts:
- `lib/sigra/audit/forwarder.ex` (behaviour, 1 callback)
- `lib/sigra/audit/forwarders/threadline.ex` (impl, wrapped in `Code.ensure_loaded?`)
- `lib/sigra/audit/forwarders/noop.ex` (fallback for tests)
- `lib/sigra/workers/audit_forward.ex` (optional Oban worker)
- `lib/sigra/config.ex` — extend `:audit` NimbleOptions schema with `:forwarders`
- `lib/sigra/application.ex` — `maybe_warn_missing_forwarder_deps/1` + `attach_forwarders/1`
- `mix.exs:65-87` no_warn_undefined updates
- Tests: `test/sigra/audit/forwarders/threadline_test.exs`, `test/sigra/audit/forwarder_test.exs`
- `CHANGELOG.md` [Unreleased] entry

**Phase 132 — Threadline recipe + Mailglass cross-link recipe**

Why second: recipes depend on Phase 131's config shape being finalized.

Artifacts:
- `guides/recipes/companion-libs/threadline.md`
- `guides/recipes/companion-libs/mailglass.md` (cross-link, ~1 page)
- `mix.exs` extras: list updates + groups_for_extras adjustment
- `mix docs --warnings-as-errors` exit 0 (gate)

**Phase 133 — Suite narrative + ecosystem diagram**

Why third: narrative refers to Phase 131 + Phase 132 artifacts.

Artifacts:
- `guides/introduction/suite-integration.md`
- `mix.exs` extras: update
- `README.md` — add a "Suite integration" link
- `mix docs --warnings-as-errors` exit 0

**Phase 134 — Recipe-only companion libs (Accrue, Lockspire concrete, Relyra, Rulestead)**

Why fourth: pure documentation. Parallelizable with Phase 133.

Artifacts:
- `guides/recipes/companion-libs/accrue.md`
- `guides/recipes/companion-libs/lockspire.md`
- `guides/recipes/companion-libs/relyra.md`
- `guides/recipes/companion-libs/rulestead.md`
- `mix.exs` extras: 4 new entries
- `mix docs --warnings-as-errors` exit 0

**Phase 135 — Reference example wiring (Threadline demo in `test/example/`)**

Artifacts:
- `test/example/mix.exs` — add Threadline dep
- `test/example/lib/example/accounts.ex` — wire the forwarder
- `test/example/test/example_web/threadline_forwarder_test.exs`
- `test/example/AGENTS.md` — note the demo
- CI passes

**Phase 136 — Verification proof bundle + milestone audit**

Artifacts:
- Forwarder unit + integration tests passing
- `mix test test/sigra/audit/` clean
- `mix test` in `test/example/` clean
- `mix docs --warnings-as-errors` exit 0
- `mix credo --strict` clean
- `131-VERIFICATION.md` through `135-VERIFICATION.md` filed
- `.planning/milestones/v1.29-ROADMAP.md`, `v1.29-REQUIREMENTS.md`, `v1.29-MILESTONE-AUDIT.md`

**Critical dependency chain:**

```
131 (library code)
  ↓
  ├─→ 132 (Threadline recipe needs config shape)
  │     ↓
  │     ├─→ 133 (narrative refs recipe)
  │     ├─→ 134 (recipe-only siblings, parallelizable with 133)
  │     ↓
  │     135 (example app demos adapter, refs recipe)
  │       ↓
  └────→ 136 (verification gates all of above)
```

## Architecture decision summary

| Decision | What | Why |
|---|---|---|
| Threadline is a forwarder, not a destination | New `Sigra.Audit.Forwarders.*` namespace; attach to existing `[:sigra, :audit, :log]` telemetry | Preserves single-table audit invariant; post-commit fire-and-forget |
| No `--with-threadline` flag | Runtime config only; no installer feature | Zero precedent for `--with-*`; would cascade to 5+ flags |
| Recipes go in `guides/recipes/companion-libs/` subdir | New subdir | Separates feature recipes from integration recipes |
| Reference example extends `test/example/` | Not new `examples/` directory | CI is already wired; auth-focused example is the right demo |
| Suite narrative lives in `guides/introduction/suite-integration.md` | Single file | One canonical entry point |
| Diagram is ASCII | Not Mermaid | Matches existing precedent |

## Files: new vs modified

### New files (Phase 131)

- `lib/sigra/audit/forwarder.ex`
- `lib/sigra/audit/forwarders/threadline.ex`
- `lib/sigra/audit/forwarders/noop.ex`
- `lib/sigra/workers/audit_forward.ex`
- `test/sigra/audit/forwarder_test.exs`
- `test/sigra/audit/forwarders/threadline_test.exs`
- `test/sigra/audit/forwarders/noop_test.exs`

### Modified files (Phase 131)

- `lib/sigra/config.ex` — extend `:audit` NimbleOptions schema (`:forwarders`)
- `lib/sigra/application.ex` — `maybe_warn_missing_forwarder_deps/1`, `attach_forwarders/1`
- `mix.exs` — add `Threadline`, `Sigra.Workers.AuditForward` to `no_warn_undefined`
- `CHANGELOG.md` — [Unreleased] section

### New files (Phase 132–134, docs)

- `guides/recipes/companion-libs/threadline.md`
- `guides/recipes/companion-libs/mailglass.md`
- `guides/recipes/companion-libs/accrue.md`
- `guides/recipes/companion-libs/lockspire.md`
- `guides/recipes/companion-libs/relyra.md`
- `guides/recipes/companion-libs/rulestead.md`
- `guides/introduction/suite-integration.md`

### Modified files (Phase 132–134)

- `mix.exs` — `extras:` list (+7 entries), `groups_for_extras` (add `"Companion Libraries"` group)

### New files (Phase 135)

- `test/example/test/example_web/threadline_forwarder_test.exs`

### Modified files (Phase 135)

- `test/example/mix.exs` — add Threadline dep
- `test/example/lib/example/accounts.ex` — add `forwarders:` block to `sigra_config/0`
- `test/example/AGENTS.md` — document Threadline demo

## Open architecture questions (escalate to user)

1. **Forwarder vs Sink naming.** Recommend **Forwarders** because Sigra's audit table is not being swapped out.
2. **Should `forwarders` be a list, or a single forwarder?** Recommend **list** — matches Phoenix's `pipelines:` ergonomic, future-proofs without cost.
3. **Telemetry event payload extension.** Today `[:sigra, :audit, :log]` carries `%{action, actor_id, outcome}` only. Recommend extending metadata to include the full event struct (backwards-compatible). Document as a public telemetry contract extension.
4. **Failure semantics for the inline dispatch path.** Recommend **log + telemetry**, do not re-raise.
5. **`mix sigra.doctor` task.** Referenced in v1.21 narrative but not present. Recommend **defer to a separate quick after v1.29 ships** — keep this milestone bounded.

## Confidence levels

| Area | Level | Evidence |
|---|---|---|
| Existing audit emission surface | HIGH | Direct read of `lib/sigra/audit.ex` |
| Optional-dep extension precedent | HIGH | `rate_limiter.ex` + `rate_limiters/{hammer,noop}.ex` + `application.ex` warnings all read |
| Install feature pattern | HIGH | `feature.ex` + `features/passkeys.ex` + `mix/tasks/sigra.install.ex` all read |
| ExDoc extras/groups wiring | HIGH | `mix.exs:163-218` read directly |
| Reference example CI wiring | HIGH | `.github/workflows/ci.yml` grepped at `test/example` paths |
| Mailglass shipped state | HIGH | No `Sigra.Mailers.Adapters.Mailglass` exists on v1.28-data-lifecycle |
| `Sigra.OptionalDeps` claim | HIGH (against) | Module does not exist; pattern is scattered `Code.ensure_loaded?` |
| Threadline as a library | MEDIUM-HIGH | Confirmed by STACK research at hex.pm/packages/threadline 0.5.0 |
| Recipe TODO file existence | HIGH | STATE.md references them; `find` shows files do not exist on disk |

## Sources

- `/Users/jon/projects/sigra/lib/sigra/audit.ex`
- `/Users/jon/projects/sigra/lib/sigra/rate_limiter.ex`, `rate_limiters/hammer.ex`, `rate_limiters/noop.ex`
- `/Users/jon/projects/sigra/lib/sigra/workers/account_deletion.ex`, `audit_cleanup.ex`
- `/Users/jon/projects/sigra/lib/sigra/application.ex`
- `/Users/jon/projects/sigra/lib/sigra/mailer.ex`
- `/Users/jon/projects/sigra/lib/sigra/install/feature.ex`, `features/passkeys.ex`
- `/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex`
- `/Users/jon/projects/sigra/mix.exs`
- `/Users/jon/projects/sigra/guides/recipes/companion-oauth-provider.md`
- `/Users/jon/projects/sigra/.github/workflows/ci.yml`
- `/Users/jon/projects/sigra/test/example/mix.exs` and `lib/example/accounts.ex`
- `/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md`, `PROJECT.md`, `STATE.md`
