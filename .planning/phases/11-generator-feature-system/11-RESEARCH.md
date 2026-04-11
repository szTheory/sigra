# Phase 11: Generator Feature System — Research

**Researched:** 2026-04-11
**Domain:** Elixir/Mix code generators, behaviour-driven install manifests, golden-file regression testing
**Confidence:** HIGH (ecosystem conventions), MEDIUM (golden-diff tooling — bespoke path recommended), HIGH (migration-timestamp pattern — Sigra is ahead of upstream)

## Summary

Phase 11 is a **structural refactor**, not a feature add. Every design question of substance has already been locked in CONTEXT.md (D-01…D-08, CD-01…CD-05). Research focused on the narrow band of unknowns that the planner cannot get from training alone:

1. **Is the 5-callback behaviour shape idiomatic?** Yes — it mirrors the `Mix.Phoenix.Schema`/`Mix.Phoenix.Context` module-split pattern that `phx.gen.auth` uses, but codifies it as a formal `@behaviour`. Nothing in the Elixir ecosystem defines a better shape for "feature-of-an-installer." Igniter's `Igniter.Mix.Task` behaviour is the closest precedent and uses a single `igniter/1` callback over an imperative builder — that shape is not what Sigra wants, because Sigra needs **declarative** file/injection lists that a golden-diff test can compare. Keep 5 callbacks as specified.
2. **Is there a hex lib we should depend on instead?** No. Igniter is the only serious contender and is a whole-project-patching framework, not a pluggable install-feature system. Depending on it would add a large transitive dep surface and force Sigra's install task into Igniter's AST-rewriting model, which is a different pattern than "emit EEx templates + idempotent marker-injection." Stay bespoke.
3. **Is Phoenix's own migration-timestamp helper good enough?** **No — Phoenix's `timestamp/0` in both `phx.gen.schema` and `phx.gen.auth` is identical to Sigra's current `timestamp/0` and has the **exact same collision bug** when multiple migrations are emitted in one run `[VERIFIED: github.com/phoenixframework/phoenix/blob/main/lib/mix/tasks/phx.gen.auth.ex]`. Sigra's existing `offset_timestamp/1` is already ahead of upstream, and D-04's slot allocator is the right next step. This is load-bearing: Phases 18/22 each add more migrations, so the allocator MUST ship in Phase 11.
4. **Golden-file snapshot tooling.** Mneme is the only maintained Elixir snapshot lib and it is **not** the right tool here — it snapshots single-value assertions inside a test function, not file-tree diffs `[VERIFIED: github.com/zachallaun/mneme]`. A hand-rolled fixture-directory walker + `String.myers_difference/2` (or shelling out to `diff -ruN`) is the pragmatic path. Keep it small: ~80 lines of test support code.
5. **"Full decomposition" refactor risk.** The main failure mode on 785→~150 line refactors is **silent behavior drift** — a helper gets inlined slightly wrong and the golden diff catches it one commit too late. Mitigation: land the golden snapshot **before** the refactor starts (Wave 1), not after.

**Primary recommendation:** Execute CONTEXT.md's design as-is. Sequence the work so the golden-diff test is the FIRST thing that ships (against the pre-refactor monolith), making it a true regression net for every subsequent commit in the phase.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `Sigra.Install.Feature` behaviour with **five callbacks**: `enabled?/1`, `files/1`, `injections/1`, `migrations/1`, `post_instructions/2`. `Features.Core.enabled?/1` always returns `true`.
- **D-02:** `injections/1` returns structured `%Sigra.Install.Injection{target, marker, anchor, content}` records; the walker hands each to `Sigra.Install.Injector`. Features never call `Injector` directly.
- **D-03:** **Full decomposition** of `sigra.install.ex` — `Features.Core` owns all 44 non-migration files, all injections, all 3 migrations, and all post-install instructions. `sigra.install.ex` becomes ~150 lines: arg-parse, binding, walker, summary.
- **D-04:** `Sigra.Install.MigrationTimestamps.allocate(features, base_time)` returns `%{module() => %{slot_atom => "YYYYMMDDHHMMSS"}}`. Features return slot keys; allocator assigns timestamps. Canonical feature ordering drives allocation order.
- **D-05:** Byte-identical exception is **migration filename timestamps only**. Golden-diff test normalizes leading 14-digit prefixes on migration filenames. Migration file **contents** must be byte-identical.
- **D-06:** Post-install summary is a **4-column ASCII table**: `generated | modified | skipped | manual-action`. Paths relative to project root. No truncation.
- **D-07:** `Sigra.Install.Report` struct accumulator (not GenServer). `record_generated/2`, `record_skipped/3`, `record_modified/2`, `record_manual_action/2`. `render_summary/1` emits the table.
- **D-08:** CI golden-output diff test: `mix phx.new` → `mix sigra.install --yes` → normalize migration timestamps → diff against `test/fixtures/install_golden/`.

### Claude's Discretion

- **CD-01:** Host-app override path mirrors subdir layout (`priv/templates/sigra.install/core/user.ex` overrides library's `core/user.ex`). No flat-legacy fallback. Breaking change documented in Phase 23 upgrade guide.
- **CD-02:** `Sigra.Install.Report` struct field names — planner picks.
- **CD-03:** `%Sigra.Install.Injection{}` field names — planner may rename (`anchor` → `position`, etc.) as long as structured-data contract is preserved.
- **CD-04:** `Features.Core` submodule granularity — one module or split into `Features.Core.{Files, Injections, Migrations, Instructions}`. Planner's call.
- **CD-05:** Walker implementation location — `Mix.Tasks.Sigra.Install` directly or `Sigra.Install.Runner` helper. Planner's call.

### Deferred Ideas (OUT OF SCOPE)

- `Features.Organizations`, `Features.Passkeys`, `Features.Admin` — Phases 18, 22, v1.2.
- `--no-organizations` / `--no-passkeys` flag wiring — Phases 18/22.
- Combinatorial CI smoke matrix (GEN-03) — Phases 18/22.
- Backfill migration generator (X-2 full mitigation) — Phase 18.
- `mix sigra.install.check` dry-run task — deferred to v1.1 polish phase.
- `mix sigra.install.rollback` task — v1.2+ polish.
- Telemetry events for install operations — no current consumer.
- Per-feature override paths with flat-legacy fallback — explicitly rejected in CD-01.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GEN-01 | Subdirectory + feature manifest pattern with `Sigra.Install.Feature` behaviour | Behaviour shape validated against Igniter + phx.gen.auth precedent; bespoke behaviour confirmed as correct choice (see §Behaviour Idioms) |
| GEN-02 | Mechanical, content-preserving move of v1.0 templates into `core/` | Golden-diff harness is the mechanical proof (see §Validation Architecture) |
| GEN-04 | Idempotent re-run with marker comments | Existing `Sigra.Install.Injector` already implements marker-check pattern; `%Injection{}` wrapper preserves semantics (see §Injector Wrapper) |
| GEN-05 | Post-install summary (generated/modified/skipped/manual-action) | `Sigra.Install.Report` struct accumulator pattern is idiomatic — no external lib needed (see §Report Accumulator) |
| GEN-07 | Strictly-ordered migration timestamps | Upstream Phoenix has the same bug (see §Migration Timestamp Allocation); slot-allocator pattern is the correct fix |

## Project Constraints (from CLAUDE.md)

- Phoenix ~> 1.8 / Ecto ~> 3.12 / Elixir ~> 1.18 blessed path.
- **Minimal transitive deps. Copy-paste over deps when code is small and stable.** (Directly applies: do NOT add Igniter, Mneme, or any snapshot-lib dep for this phase.)
- All security-critical code in library (hashing, TOTP, WebAuthn, HMAC, rate-limit). Generated into host app: schemas, contexts, routes, LiveViews. **Phase 11 preserves this boundary — no security logic moves.**
- `mix docs --warnings-as-errors` stays clean (DX-08 is a Phase 23 gate but any new modules added in Phase 11 must have `@moduledoc`/`@doc` to avoid landmining).
- Comprehensive spec coverage, AAA style, flat, self-contained.
- `mix credo --strict` must stay clean.
- Ban macro-heavy `use Sigra.X` injection. **The Feature behaviour must be a `@behaviour`/`@callback` contract, not a `__using__/1` macro.**

## Standard Stack

This phase adds no new runtime deps. All tooling is stdlib or already present.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir `@behaviour`/`@callback` | stdlib | Define `Sigra.Install.Feature` contract | Language-native. `[VERIFIED: hexdocs.pm/elixir/Module.html#module-behaviour]`. No macro contortions. |
| `EEx.eval_file/2` | stdlib | Template evaluation (existing usage) | Already used at `sigra.install.ex:309`. Unchanged in this phase. `[VERIFIED: existing code]` |
| `Mix.Generator.create_file/2` | stdlib (mix) | File writer | Already used at `sigra.install.ex:310`. Wrapped by `Report.record_generated/2` but otherwise unchanged. `[VERIFIED: hexdocs.pm/mix/Mix.Generator.html]` |
| `String.myers_difference/2` | stdlib | Golden-diff rendering | Used by ExUnit internally for assertion diffs. Sufficient for per-file byte-level diff output in CI logs. `[VERIFIED: hexdocs.pm/elixir/String.html#myers_difference/2]` |
| `:calendar.datetime_to_gregorian_seconds/1` | stdlib (OTP) | Timestamp arithmetic for slot allocator | Already used in current `offset_timestamp/1`. The carry-into-minutes-correctly property is inherited. `[VERIFIED: existing sigra.install.ex:644-648]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ExUnit.CaseTemplate` | stdlib | Test-case templating for golden-diff harness | If golden-diff needs shared setup (`mix phx.new` once per suite run, then diff multiple fixtures) |

### Alternatives Considered (and rejected)
| Instead of | Could Use | Tradeoff | Decision |
|------------|-----------|----------|----------|
| Bespoke `Sigra.Install.Feature` behaviour | **Igniter** (`Igniter.Mix.Task`) | Igniter is a whole-project-patching framework with AST rewriting; it would reshape the entire install task. Pulls in a non-trivial transitive tree. `[CITED: github.com/ash-project/igniter]` | REJECT — incompatible with "EEx + marker injection" model; violates minimal-deps constraint. |
| Hand-rolled golden-diff harness | **Mneme** (`~> 0.4`) | Mneme snapshots per-assertion values in test source, not file trees. Wrong tool. `[VERIFIED: github.com/zachallaun/mneme README]` | REJECT — tool/problem mismatch. |
| Hand-rolled golden-diff harness | **snapshy** | Unmaintained (last commit >2yr). `[CITED: github.com/DCzajkowski/snapshy]` | REJECT — maintenance risk. |
| `Sigra.Install.MigrationTimestamps.allocate/2` | **Phoenix's `timestamp/0`** | Phoenix's upstream generator has no offset support and WILL collide on multi-migration runs. `[VERIFIED: github.com/phoenixframework/phoenix/blob/main/lib/mix/tasks/phx.gen.auth.ex]` | REJECT — upstream has the exact bug we're fixing. |
| Struct-accumulator `Report` | **Agent / GenServer** | Adds process-lifetime and concurrency surface for no reason — installer walker is strictly synchronous. CONTEXT.md D-07 already rules this out. | REJECT — already decided. |

**Installation:** None. Zero new hex deps in this phase.

**Version verification:** Not applicable — no new packages. Existing deps (argon2_elixir, swoosh, hammer, oban, cloak_ecto) are unchanged by this phase.

## Architecture Patterns

### Recommended Module Structure
```
lib/sigra/install/
├── feature.ex              # @behaviour Sigra.Install.Feature  (new — D-01)
├── features/
│   └── core.ex             # implements Feature, owns all v1.0 content  (new — D-03)
├── injection.ex            # defstruct %Injection{target, marker, anchor, content}  (new — D-02)
├── injector.ex             # EXISTING — gains a thin accept-%Injection{} wrapper
├── migration_timestamps.ex # allocate/2 slot allocator  (new — D-04)
├── report.ex               # defstruct + record_* + render_summary/1  (new — D-06/07)
└── runner.ex               # OPTIONAL per CD-05 — walker extracted from task

lib/mix/tasks/
└── sigra.install.ex        # shrinks ~785 → ~150 lines  (D-03)

priv/templates/sigra.install/
└── core/                   # all 44 v1.0 templates, mechanical move  (GEN-02)

test/
├── fixtures/install_golden/   # committed snapshot  (D-08)
└── sigra/install/
    ├── feature_test.exs
    ├── features/core_test.exs
    ├── migration_timestamps_test.exs
    ├── report_test.exs
    └── install_golden_diff_test.exs
```

### Pattern 1: Behaviour-Driven Feature Manifest

**What:** A `@behaviour` with 5 declarative callbacks. Each feature module is a plain Elixir module tagged with `@behaviour Sigra.Install.Feature`. The walker invokes callbacks — there is NO runtime registration, NO `use` macro, NO side-effecting init.

**Why this shape:** Phoenix's own `phx.gen.auth` does NOT use a behaviour — it uses module-split (`HashingLibrary`, `Injector`, `Migration` modules) with plain function calls `[CITED: github.com/phoenixframework/phoenix/blob/main/lib/mix/tasks/phx.gen.auth.ex]`. That works for phx.gen.auth because there is only ever ONE auth feature. Sigra needs to support N features (core → +orgs → +passkeys → +admin), which means the callback set must be contract-enforced at compile time to keep each future feature honest. A behaviour is the Elixir-idiomatic way to express "here is a slot you fill in; you must fill all 5 callbacks" `[VERIFIED: Elixir's own `Application`, `GenServer`, `Plug` all use this pattern]`.

**Example:**
```elixir
# lib/sigra/install/feature.ex
defmodule Sigra.Install.Feature do
  @moduledoc """
  Contract for an installable Sigra feature (core, organizations, passkeys, admin).

  The install task walks a canonical feature list, invokes the callbacks in order,
  and composes the results into a single declarative install plan that is then
  executed by the runner.
  """

  alias Sigra.Install.{Injection, Report}

  @type binding :: keyword()
  @type file_tuple :: {:eex, source :: String.t(), target :: String.t()}
  @type migration_spec :: {slot :: atom(), template :: String.t(), target_basename :: String.t()}

  @callback enabled?(keyword()) :: boolean()
  @callback files(binding()) :: [file_tuple()]
  @callback injections(binding()) :: [Injection.t()]
  @callback migrations(binding()) :: [migration_spec()]
  @callback post_instructions(binding(), Report.t()) :: [iodata()]
end
```

**Why 5 callbacks, not 3 or 7:**

- `enabled?/1` is separate from `files/1` because the walker short-circuits on `false` and never bothers computing the file list (important for expensive per-feature binding transforms later).
- `migrations/1` is separate from `files/1` because only migrations need slot-based timestamp allocation (D-04) — folding them into `files/1` would require ad-hoc "is this a migration?" pattern-matching on the tuple, which is exactly the hand-rolling anti-pattern.
- `post_instructions/2` takes `Report` as an argument (not just `binding`) because instructions sometimes need to reference what actually happened ("X files were skipped, run `mix sigra.install --force` to overwrite"). This is why it is a 2-arity callback in D-01.
- `injections/1` returns structured `%Injection{}` records (not IO callbacks) so that the walker — not the feature — owns idempotency. Any future feature that forgets to check the marker gets idempotency anyway.

Do NOT merge/split. Ship the 5 as specified.

### Pattern 2: Slot-Based Migration Timestamp Allocation

**What:** Features return `[{slot_atom, template, basename}]` — NOT pre-computed filenames. A central allocator runs once per install, assigns strictly-increasing timestamps to slots in canonical order, and returns a `%{Feature => %{slot => "YYYYMMDDHHMMSS"}}` map that the walker uses when computing target paths.

**Why this matters:** `[VERIFIED: github.com/phoenixframework/phoenix — phx.gen.schema.ex and phx.gen.auth.ex both define `timestamp/0` as `:calendar.universal_time()` with no offset parameter, so running either generator with multiple migrations in one call WILL collide at the second boundary]`. Sigra already works around this with `offset_timestamp/1` (`sigra.install.ex:644`), but that is a function-local hack. Phase 11 extracts it into a real module because:

1. Phase 12 adds 1 more migration (user_sessions ALTER).
2. Phase 13 adds 3+ more migrations (organizations, memberships, invitations).
3. Phase 15 adds 1 migration (audit_events ALTER).
4. Phase 19 adds 1 migration (user_passkeys).

Without a central allocator, every phase re-derives a different offset convention and they will collide in the middle of a busy run.

**Example allocator signature:**
```elixir
defmodule Sigra.Install.MigrationTimestamps do
  @spec allocate([module()], DateTime.t()) :: %{module() => %{atom() => String.t()}}
  def allocate(features, base_time \\ DateTime.utc_now()) do
    # Walk features in canonical order.
    # For each feature, walk slots in the order its migrations/1 callback returned them.
    # Assign sequential UTC timestamps, carrying across minute/hour/day boundaries
    # (reuse offset_timestamp's gregorian-seconds arithmetic from sigra.install.ex:644-648).
    # Return a nested map indexed by module then slot atom.
  end
end
```

**Idempotency interaction:** If a target migration filename already exists on disk (from a previous run), the allocator should prefer the existing filename over allocating a new timestamp. This is where CONTEXT.md's note about moving `:119-132`/`:212-226` idempotency logic into the allocator matters. Do this inside `allocate/2`, not inside each feature's `migrations/1` callback — keeps feature callbacks pure.

### Pattern 3: Walker as Generic Composition

**What:** A ~30-line loop over `features = [Features.Core, ...]` that:

1. Filters by `enabled?(opts)`.
2. Calls `MigrationTimestamps.allocate(enabled_features)` **once**.
3. For each enabled feature:
   - Collects `files(binding)`.
   - Collects `migrations(binding)` and resolves to filenames via the allocated map.
   - Collects `injections(binding)`.
   - For each file: check exists → `Report.record_skipped/3` | else `EEx.eval_file/2` + `Mix.Generator.create_file/2` + `Report.record_generated/2`.
   - For each injection: call `Sigra.Install.Injector.inject(%Injection{})` (new accept-struct wrapper), interpret `{:ok, _}` as modified, `{:already_injected, _}` as skipped. Record either way.
4. For each enabled feature: call `post_instructions(binding, report)` and buffer the output.
5. Print `Report.render_summary/1`.
6. Print buffered post-instructions.

**The purely-additive test:** Adding `Features.Organizations` in Phase 18 must require **zero** edits to the walker. If the planner finds themselves wanting to pattern-match on the feature module name or `case` on feature-specific behavior inside the walker, the design has failed the purely-additive test and should be re-thought. See §Runtime State Inventory for the specific code-shape markers that indicate failure.

### Pattern 4: Idiomatic Report Accumulator

**What:** A plain struct with functional update. `Report.record_generated(report, path)` returns a new `Report`. No mutation, no process, no GenServer.

```elixir
defmodule Sigra.Install.Report do
  @type entry :: String.t() | iodata()
  @type t :: %__MODULE__{
          generated: [entry()],
          modified: [entry()],
          skipped: [{entry(), reason :: String.t()}],
          manual_action: [entry()]
        }

  defstruct generated: [], modified: [], skipped: [], manual_action: []

  def new, do: %__MODULE__{}
  def record_generated(report, path), do: %{report | generated: [path | report.generated]}
  def record_modified(report, path), do: %{report | modified: [path | report.modified]}
  def record_skipped(report, path, reason), do: %{report | skipped: [{path, reason} | report.skipped]}
  def record_manual_action(report, message), do: %{report | manual_action: [message | report.manual_action]}

  def render_summary(%__MODULE__{} = report) do
    # 4-column ASCII table, green for generated, cyan for modified, yellow for skipped,
    # red for manual-action. Reverse each list before rendering (cons prepends).
    # Use IO-ANSI codes per the existing Mix.shell().info convention.
  end
end
```

**Why a struct, not a process:**

1. The walker is strictly synchronous — no parallel feature generation.
2. Functional accumulator means every step is testable as `record_* |> assert equals: %Report{...}`.
3. No process lifecycle to manage, no cleanup on error, no supervision concerns.
4. Matches how `Ecto.Multi` and `Plug.Conn` thread state — the established Elixir pattern `[VERIFIED: existing Elixir ecosystem convention]`.

### Pattern 5: The `%Injection{}` Wrapper Over Existing `Injector`

**What:** `Sigra.Install.Injection` is a new struct. `Sigra.Install.Injector` is **unchanged** in its core functions — it gains a SINGLE new entry point:

```elixir
# addition to lib/sigra/install/injector.ex
def apply(file_contents, %Sigra.Install.Injection{} = injection) do
  case injection.anchor do
    :before_last_end -> inject_router_plugs(file_contents, injection.content)  # existing fn
    :before_import_config -> inject_config(file_contents, injection.content)    # existing fn
    :after_conn_case_import -> inject_conn_case(file_contents, injection.content) # existing fn
    # ... one clause per current anchor
  end
end
```

This is a **thin adapter**, not a rewrite. Do NOT touch `find_last_end/1`, `find_import_config/1`, `find_conn_case_anchor/1`, or any of the existing `inject_*/2` functions. They are already idempotent, already tested, and already correct `[VERIFIED: lib/sigra/install/injector.ex]`. The `%Injection{}` struct is the new Feature-facing API; the existing functions are its private implementation.

**Planner decision:** The anchor-atom enum (`:before_last_end`, `:before_import_config`, etc.) is `CD-03` territory. Field naming and the exact enum set are planner discretion. The shape — thin adapter, not a rewrite — is non-negotiable for the risk budget.

### Anti-Patterns to Avoid

- **`use Sigra.Install.Feature` macro.** CLAUDE.md explicitly bans macro-heavy injection. Use `@behaviour` + `@impl true` instead.
- **Walker pattern-matches on feature module name.** If you see `case feature do Features.Core -> ... Features.Organizations -> ... end` inside the walker, the pattern is broken. Features must be interchangeable via the behaviour contract.
- **Features cross-referencing each other.** `Features.Core` cannot `alias Features.Organizations` — not even via generated templates. Pitfall X-3 leakage check enforces this.
- **Inline `Mix.shell().info(...)` calls in features.** Route everything through `Report`. The old code's direct `Mix.shell().info([:yellow, "* skipping ", ...])` at `:305-311` must not be duplicated in the new structure — that is the ad-hoc thing `Report` replaces.
- **Storing resolved migration filenames in `migrations/1`.** Features return slots; the allocator resolves. If a feature's callback computes `"#{timestamp()}_..."` itself, D-04 is defeated.
- **Fresh `Mix.Generator.create_file/2` call without recording.** The refactor must route every write through `Report` so the summary table is actually complete.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Template discovery / EEx evaluation | Custom `File.read!` + `EEx.eval_string` | `EEx.eval_file/2` (already used) + `Mix.Generator.create_file/2` | Already working, already handles binding substitution. No change. |
| File exists / overwrite prompting | Custom prompt loop | `Mix.Generator.create_file/2`'s built-in behavior | It already supports `force: true` and interactive overwrite prompts. `[VERIFIED: hexdocs.pm/mix/Mix.Generator.html]` |
| Byte-level file diff for golden test | Custom diff algorithm | `String.myers_difference/2` for rendering + `File.read!/1` byte equality for pass/fail | `myers_difference` is what ExUnit uses internally for `assert` diffs. `[VERIFIED: hexdocs.pm/elixir/String.html#myers_difference/2]` Pass/fail is a pure byte compare. Rendering is only needed on failure. |
| Marker-based injection | New injection engine | Existing `Sigra.Install.Injector` | 413 lines, already idempotent, already tested, already handles every current anchor case. `[VERIFIED: lib/sigra/install/injector.ex]` |
| Migration timestamp carry-over | Custom arithmetic | `:calendar.datetime_to_gregorian_seconds/1` + `gregorian_seconds_to_datetime/1` | Already the pattern `offset_timestamp/1` uses. Carries across minute/hour/day boundaries correctly — avoids the `min(ss + n, 59)` bug that was previously reviewed in 10.1 IN-01 `[VERIFIED: sigra.install.ex:644-648 comment]`. |
| ANSI-colored terminal output | Custom escape sequences | `Mix.shell().info([:green, ..., :reset, ...])` | Phoenix convention, already used throughout existing code. `[VERIFIED: existing sigra.install.ex]` |

**Key insight:** Phase 11 is structurally bounded. Every primitive it needs (file-write, template-eval, injection, timestamp-carry, colored output) already exists in stdlib or in Sigra's own `Injector`. The phase's output is new **structure** around existing **primitives** — not new primitives. Any task that proposes "write a new X helper" should be challenged against this row.

## Runtime State Inventory

This IS a refactor phase — the inventory MUST be explicit.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | **None.** No database or datastore references `sigra.install` state. The installer writes to host-app files; it reads nothing at runtime. Verified: `grep -r "Mix.Tasks.Sigra.Install" lib/` scopes only to test/ and the task file itself. | No data migration. |
| Live service config | **None.** The installer is not a long-running service, has no external config surface (no Datadog/Tailscale/Cloudflare integration). | No action. |
| OS-registered state | **None.** Not registered with Task Scheduler, launchd, systemd, or pm2. Runs on-demand via `mix sigra.install`. | No action. |
| Secrets/env vars | **None.** Installer reads no env vars or secrets. (Host-app config it INJECTS references `config :argon2_elixir, t_cost: 1, m_cost: 8` etc. but those are generated code, not installer runtime state.) | No action. |
| Build artifacts | **Template path references in host apps.** Per CD-01, any downstream app that has overrides at `priv/templates/sigra.install/user.ex` (flat layout) will silently stop being picked up after Phase 11 lands, because `find_template/1` will now look under `core/user.ex`. **Action:** Phase 23 upgrade guide must document the override-path break. Grep the Sigra-users channel/issues before release — if any public app has overrides, ship a transitional fallback. Otherwise, the break is acceptable per CD-01. | **Documentation in Phase 23 upgrade guide** (not Phase 11 scope, but must be tracked as an out-of-phase follow-up). |

**The canonical question answered explicitly:** After every file in the repo is updated, what runtime systems still have the old string cached? **Answer: zero runtime systems.** The only leakage surface is downstream host apps that MAY have overrides — and that is a Phase 23 docs issue, not a Phase 11 blocker.

## Common Pitfalls

### Pitfall 1: Refactor Introduces Silent Content Drift
**What goes wrong:** The 785→150 line decomposition inlines a helper slightly wrong. A single whitespace character changes in a generated template. The golden-diff test catches it, but only AFTER 4 other commits have landed on top — now the rollback blast radius is huge.

**Why it happens:** Engineers write the new `Features.Core` module from a fresh mental model and accidentally "clean up" cosmetic details that were actually meaningful (trailing newlines, specific indentation, comment placement).

**How to avoid:**
1. **Land the golden snapshot FIRST** — against the pre-refactor monolith, as Wave 1 Task 1 (see Validation Architecture).
2. **Only after the snapshot is green**, start moving templates and refactoring.
3. **Every subsequent commit runs the golden-diff test** — any commit that breaks it must either fix the break or be reverted before the next commit.
4. **Do not "clean up" templates during the move.** Even a trailing-newline change breaks byte-identity.

**Warning signs:** Commit message like "mechanical move + cleanup of whitespace in user.ex" — red flag. The move commit must be literally `git mv` equivalent.

### Pitfall 2: Walker Leaks Feature-Specific Logic
**What goes wrong:** Walker gains a `if feature == Features.Core, do: special_case, else: general_case` branch to preserve some v1.0 quirk. Phase 18 now has to either (a) duplicate the special-case for Organizations, or (b) refactor the walker again — which defeats the purely-additive guarantee.

**Why it happens:** One of the v1.0 callsites does something the 5-callback contract cannot naturally express, so the refactor punts by special-casing.

**How to avoid:**
1. **Audit every branch in current `generate/4` against the 5 callbacks BEFORE writing `Features.Core`.** Each branch must map cleanly to `files/1`, `injections/1`, `migrations/1`, or `post_instructions/2`. If it doesn't, the behaviour is wrong and needs a 6th callback — go back to discuss-phase.
2. **Code review gate: walker must contain zero `Features.Core` string or module references.** The feature list lives in one place (`@features [Features.Core]` in the task or runner); everywhere else the walker operates on `feature` as opaque.
3. **Write the "purely additive" test stub now** (see Validation Architecture V-PA-01) — even though it only has one feature to test, the harness is in place.

**Warning signs:** Any line in `sigra.install.ex` (post-refactor) that references `Features.Core` by name outside the `@features` constant.

### Pitfall 3: `%Injection{}` Becomes a Leaky Abstraction
**What goes wrong:** Feature authors need to inject something the existing `Injector` doesn't support (e.g., "inject at the top of file between `@moduledoc` and first `alias`"). They add a new `anchor: :after_moduledoc` atom, then realize the Injector's existing `inject_*` functions can't handle it, so they add `inject_after_moduledoc/2` — and now the `%Injection{}` contract is coupled to Injector internals.

**Why it happens:** Structured-data-as-contract patterns degrade when the enum of tags grows without discipline.

**How to avoid:**
1. **Phase 11 ships with exactly the anchor atoms currently used in `inject_into_files/2`** — no speculative extensibility.
2. The current injection sites are: router-plugs (before last end), config (before import_config), test-config (append), conn-case (after Phoenix.ConnTest import), api-routes (before last end), api-config (before import_config), oauth-routes (before last end), jwt-routes (before last end), lifecycle-routes (before last end), vault-child (after `children = [`). Map each to one anchor atom, reuse existing anchors where semantics match.
3. **Phase 18/22/v1.2 can extend the enum** if needed — but Phase 11 locks today's set.
4. **Future extension rule:** A new anchor requires a new `inject_*` function in `Injector` OR delegation to an existing one. No inline regex-matching inside the adapter.

**Warning signs:** An anchor atom in CODE but no corresponding existing function in `Injector`. Or an `Injector.apply/2` clause that does ad-hoc string manipulation instead of delegating.

### Pitfall 4: Migration Idempotency Moves But Breaks
**What goes wrong:** The existing `existing_migration` detection at `sigra.install.ex:119-132`, `:212-226` is duplicated three times for three migration types. The refactor consolidates it into `MigrationTimestamps.allocate/2`. In the process, the "which filenames do we consider 'existing'?" glob subtly changes and the test for "re-run the installer, it skips existing migrations" stops holding.

**Why it happens:** The existing detection uses `String.contains?(&1, "create_sigra_auth_tables")` — a substring match. A refactor to "scan priv/repo/migrations for any file matching this feature's slot basenames" needs careful mapping.

**How to avoid:**
1. **Write a test of the current idempotent re-run BEFORE the refactor.** `mix sigra.install --yes` twice on the same fixture; assert zero new migration files on the second run, same content.
2. Preserve the substring-match semantics in `MigrationTimestamps.allocate/2` — each slot has a known `target_basename` (e.g., `"create_sigra_auth_tables"`), and existence check is "does any file in `priv/repo/migrations` contain this basename substring?"
3. **Add the re-run idempotency case to the golden-diff harness.** Run the installer twice, diff the state after the second run against the state after the first — should be byte-identical (except for possible duplicate `* already injected` output, which goes into `Report.skipped`).

**Warning signs:** Tests pass on a clean install but fail on re-run. Or new migration files appearing on the second run.

### Pitfall 5: Golden Snapshot Goes Stale
**What goes wrong:** The golden fixture is committed, then a legitimate template change (e.g., security patch to `auth.ex`) lands, the fixture isn't regenerated, and CI red becomes the steady state until someone "just regenerates the snapshot to make CI green" and inadvertently snapshots a bug.

**Why it happens:** Golden-file testing has an inherent update step that, if not ceremonially enforced, becomes a rubber-stamp.

**How to avoid:**
1. **Provide a `mix sigra.test.update_golden` task** (or equivalent) that regenerates the fixture in a controlled way. Landing this task in Phase 11 means Phase 18 doesn't have to invent it.
2. **CI failure message must be explicit**: "Generated output differs from fixture. If this is intentional, run `mix sigra.test.update_golden` and commit the diff. If not, the refactor drifted." Include the unified diff in the failure output.
3. **PR template reminder** (Phase 23 polish): checkbox "if this PR changes a template, I regenerated the golden fixture and reviewed the diff."
4. **Review rule:** any PR that touches `test/fixtures/install_golden/` MUST explicitly call out the reason in the PR description.

**Warning signs:** PRs where the fixture diff is larger than the template diff (means unintended changes are hitchhiking). Or "update golden" commits with no template changes.

## Code Examples

### Existing-migration detection (to preserve in allocator)
```elixir
# CURRENT — from sigra.install.ex:119-132, to move into MigrationTimestamps
existing_migration =
  Path.join(["priv", "repo", "migrations"])
  |> File.ls()
  |> case do
    {:ok, files} -> Enum.find(files, &String.contains?(&1, "create_sigra_auth_tables"))
    _ -> nil
  end

migration_path =
  if existing_migration do
    Path.join(["priv", "repo", "migrations", existing_migration])
  else
    Path.join(["priv", "repo", "migrations", "#{timestamp()}_create_sigra_auth_tables.exs"])
  end
```

```elixir
# PROPOSED shape — inside MigrationTimestamps.allocate/2
defp resolve_slot(feature, slot, target_basename, base_time, index) do
  case find_existing_migration(target_basename) do
    nil -> {slot, offset_timestamp(base_time, index)}
    existing_filename -> {slot, extract_timestamp_prefix(existing_filename)}
  end
end
```

### Offset timestamp carry (preserve intact)
```elixir
# CURRENT — sigra.install.ex:644-648. This logic is CORRECT and must be preserved
# byte-for-byte when it moves into MigrationTimestamps.
defp offset_timestamp(n) do
  now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
  {{y, m, d}, {hh, mm, ss}} = :calendar.gregorian_seconds_to_datetime(now_secs + n)
  "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
end
```

### Existing marker-injection pattern (unchanged)
```elixir
# lib/sigra/install/injector.ex:25-40 — canonical idempotency shape
def inject_router_plugs(file_contents, plug_code) do
  if String.contains?(file_contents, @marker) do
    {:already_injected, file_contents}
  else
    case find_last_end(file_contents) do
      {:ok, position} ->
        {before, rest} = String.split_at(file_contents, position)
        {:ok, before <> "\n" <> plug_code <> "\n" <> rest}
      :error ->
        {:ok, file_contents <> "\n" <> plug_code <> "\n"}
    end
  end
end
```

**Source for all three:** `/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex`, `/Users/jon/projects/sigra/lib/sigra/install/injector.ex` `[VERIFIED: existing code]`.

## State of the Art

| Old Approach (v1.0) | Phase 11 Approach | When Changed | Impact |
|---------------------|-------------------|--------------|--------|
| 785-line `generate/4` with inline file lists, inline injection IO, inline instructions | 5-callback `Feature` behaviour with `Features.Core` as first implementation | Phase 11 | Makes Phase 18/22/v1.2 purely additive |
| Flat `priv/templates/sigra.install/*.ex` | Subdirectory layout `priv/templates/sigra.install/core/*.ex` | Phase 11 | Breaking change to host-app override path (documented in Phase 23 upgrade guide) |
| `offset_timestamp/1` local helper in `sigra.install.ex:644` | `Sigra.Install.MigrationTimestamps.allocate/2` with slot-based allocation | Phase 11 | Phase 12+ can add migrations without reinventing offset conventions |
| Ad-hoc `Mix.shell().info` prints for skipped files | `Sigra.Install.Report` struct accumulator + `render_summary/1` 4-column table | Phase 11 (GEN-05) | Developers SEE what was opted out of; catches "I forgot `--no-X`" errors |
| Multi-callback `inject_*` functions called directly from task | `%Sigra.Install.Injection{}` struct + thin `Injector.apply/2` adapter | Phase 11 | Features declare injections as data; walker enforces idempotency uniformly |

**Deprecated / replaced:**
- `offset_timestamp/1` inside `sigra.install.ex` → moves to `MigrationTimestamps`. Existing function body is preserved verbatim in the new module; the old location is deleted.
- Direct `Mix.shell().info([:yellow, "* skipping ", ...])` style inline prints at `:305-311` → replaced by `Report.record_skipped/3`.
- `print_instructions/1` at `:753` → becomes `Features.Core.post_instructions/2`.

**Not deprecated, continues as-is:**
- `Sigra.Install.Injector` core functions.
- `Mix.Generator.create_file/2` as the writer.
- `EEx.eval_file/2` as the template evaluator.
- `find_template/1` logic — just gets a `"core/"` prefix prepended.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Current Sigra test suite uses ExUnit (not another framework) | Validation Architecture | LOW — ExUnit is the Elixir default and no other framework has been seen in sigra's mix.exs research. Confirm in Wave 0. |
| A2 | `mix phx.new --no-assets --no-mailer` works in the CI environment for fixture generation | Validation Architecture | MEDIUM — Phase 10.1.1 smoke harness already exercises this path per ROADMAP.md, so existing infra proves it. Confirm by grepping `.github/workflows/ci.yml` during Wave 0. |
| A3 | All 44 existing v1.0 templates compile and produce byte-identical output TODAY (pre-refactor) — i.e., the 10.1.1 "baseline" is actually stable | Pitfall 1 / Validation | HIGH if wrong — if the current installer has non-determinism beyond migration timestamps, the golden-diff test will fail before the refactor even starts, and we'd be snapshotting an unstable target. **Mitigation: Wave 1 Task 1 is "build the golden harness and prove it green on the pre-refactor code." If it flaps, we have to investigate the non-determinism BEFORE touching any templates.** |
| A4 | Downstream Sigra users (if any exist today) do not rely on the flat template override path | CD-01 / Runtime State Inventory | LOW — Sigra is pre-1.0 per CLAUDE.md. CD-01 already accepts this as a breaking change. Phase 23 docs this in upgrade guide. |
| A5 | The existing `Injector` anchor semantics (`find_last_end`, `find_import_config`, etc.) cover 100% of current injection sites | Pitfall 3 | HIGH if wrong — the "adapter over existing `Injector`" recommendation depends on this. **Mitigation: Wave 0 Task — grep every callsite of `Sigra.Install.Injector.*` and verify the anchor set is complete. This is a 10-minute audit.** |
| A6 | `String.myers_difference/2` output is readable enough for CI log failure messages | Golden-Diff Tooling | LOW — it is literally what ExUnit uses when `assert ==` fails, which is the bar for readable diffs. Fallback: shell out to system `diff -u` if the output is poor; both are stdlib-available. |
| A7 | Running `mix phx.new` inside the test suite is acceptable latency (<30s) | Validation Architecture sampling rate | MEDIUM — if it's too slow to run per-commit, downgrade to "per-wave merge only" and run a cheaper structural check per-commit. Confirm during Wave 0 when the harness lands. |

**Confirm-before-execute:** A3, A5, A7. The plan's Wave 0 must include investigation tasks for each.

## Open Questions

1. **Is there non-determinism in the current (pre-refactor) generator beyond migration timestamps?**
   - What we know: `offset_timestamp/1` is the only obvious source. `user.ex`, `auth.ex`, etc. templates don't reference `System.unique_integer` or `:rand` during EEx eval.
   - What's unclear: whether any template uses `Mix.Phoenix.base()` in a way that differs between runs (e.g., if `otp_app` changes case), or whether file ordering in `File.ls/1` on different filesystems produces different output.
   - Recommendation: **Wave 0 investigative task** — run the installer twice on an identical fresh `phx.new` tree, diff, investigate any non-migration-filename differences. If any exist, they become additional `[D-05]` normalizations or get fixed in-place.

2. **Can the 5-callback behaviour really handle every current v1.0 quirk, or is a 6th callback needed?**
   - What we know: the current `inject_oban_queue/1` and `inject_swoosh_config/2` functions print instructions AND read host-app files without injecting — they are a hybrid "detect + report" that isn't cleanly in any of the 5 callbacks.
   - What's unclear: whether these belong in `injections/1` (with a new `:detect_only` anchor?) or in `post_instructions/2` (as conditional output computed from current file state).
   - Recommendation: **Wave 0 investigative task** — map each current `inject_*` / `print_*` callsite to a callback. If `inject_oban_queue` and `inject_swoosh_config` don't fit, the planner proposes either (a) running them as custom logic inside `Features.Core.post_instructions/2` (they already have the host-app-reads baked in) or (b) widening `Injection.anchor` to include `:detect_and_report_only`. **Recommend (a)** — simpler, no contract widening.

3. **How should the golden fixture handle `--live` vs `--no-live` divergence?**
   - What we know: the Phase 10.1.1 smoke suite runs at least one mode. ROADMAP.md doesn't specify which is canonical for byte-identity.
   - What's unclear: whether the golden fixture should snapshot ONE mode (simplest) or BOTH modes as separate fixtures (more coverage, more maintenance).
   - Recommendation: **Phase 11 snapshots `--live` only** (the default, covers more code). `--no-live` is verified by existing compile-check smoke but not byte-golden. Phase 18 adds the combinatorial matrix per GEN-03 and can extend the golden harness if needed. Trade maintenance cost against coverage until we need it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir ~> 1.18 | Entire phase | Must confirm in Wave 0 | — | None — phase is blocked if absent |
| Phoenix ~> 1.8 | Golden-diff harness runs `mix phx.new` | Must confirm | — | None |
| ExUnit | Test suite | stdlib, implicit | — | — |
| `mix phx.new` available to test suite (as `Mix.Task`) | Golden-diff fixture generation | Must confirm `:phoenix` is in test-env deps | — | Fall back to pre-built fixture tree checked into repo (lose currency guarantee) |
| Git (for `git diff --exit-code` in CI fallback path) | Optional diff renderer | Standard CI tool | — | `String.myers_difference/2` is always-available fallback |
| System `diff -u` (optional, for richer failure output) | CI log formatting | Standard Unix tool | — | `String.myers_difference/2` |

**Missing dependencies with no fallback:** None currently known. Wave 0 audit confirms before refactor starts.

**Missing dependencies with fallback:** System `diff` → `String.myers_difference/2`. No blocker.

## Validation Architecture

**Phase 11 validation is unusually central** because the phase's entire success criterion is "byte-identical output" — this IS a validation-first phase.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, Elixir ~> 1.18) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/sigra/install/ --max-failures 1` |
| Full suite command | `mix test` |
| Golden-diff command (new) | `mix test test/sigra/install/install_golden_diff_test.exs` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| GEN-01 | `Sigra.Install.Feature` behaviour defined with 5 callbacks; `Features.Core` implements it | unit | `mix test test/sigra/install/feature_test.exs test/sigra/install/features/core_test.exs -x` | ❌ Wave 0 |
| GEN-01 | Adding a new (test-only) feature module to a fake feature list works with ZERO edits to the walker (purely additive test) | unit | `mix test test/sigra/install/purely_additive_test.exs::test_additive -x` | ❌ Wave 0 |
| GEN-02 | All 44 v1.0 templates live under `priv/templates/sigra.install/core/` and none remain at the flat layout | unit | `mix test test/sigra/install/template_layout_test.exs -x` | ❌ Wave 0 |
| GEN-02 | Generated tree is byte-identical to phase 10.1.1 baseline (migration filenames normalized) | golden-diff | `mix test test/sigra/install/install_golden_diff_test.exs -x` | ❌ Wave 0 |
| GEN-04 | Re-running installer is idempotent: zero new files, same content, injections already-present | integration | `mix test test/sigra/install/install_golden_diff_test.exs::test_rerun_idempotent -x` | ❌ Wave 0 |
| GEN-05 | `Report.render_summary/1` produces the 4-column table; each record fn routes output correctly | unit | `mix test test/sigra/install/report_test.exs -x` | ❌ Wave 0 |
| GEN-05 | Installer run surfaces a final summary that lists every write, skip, modify, manual-action | integration | `mix test test/sigra/install/install_golden_diff_test.exs::test_summary_completeness -x` | ❌ Wave 0 |
| GEN-07 | `MigrationTimestamps.allocate/2` produces strictly-increasing timestamps across feature/slot order | unit | `mix test test/sigra/install/migration_timestamps_test.exs -x` | ❌ Wave 0 |
| GEN-07 | Timestamps carry across minute/hour/day boundaries (edge case: base_time = 23:59:58, 3 slots) | unit | `mix test test/sigra/install/migration_timestamps_test.exs::test_day_boundary_carry -x` | ❌ Wave 0 |
| GEN-07 | If a matching migration already exists on disk, the allocator reuses its timestamp | unit | `mix test test/sigra/install/migration_timestamps_test.exs::test_existing_file_reuse -x` | ❌ Wave 0 |
| Byte-identity (D-05) | Generated app compiles under `mix compile --warnings-as-errors` after install | smoke | `mix test test/sigra/install/install_golden_diff_test.exs::test_generated_app_compiles -x` | ❌ Wave 0 |
| Byte-identity (Success Criterion #1 ROADMAP.md) | Generated app passes existing v1.0 HTTP smoke routes | smoke | Reuse Phase 10.1.1 HTTP smoke harness — **command location TBD Wave 0** | ✅ assumed existing (Wave 0 verifies) |
| Pitfall X-3 (core template isolation) | No file under `priv/templates/sigra.install/core/` references `Organization*`, `UserPasskey*`, `OrganizationInvitation*` strings | unit (grep) | `mix test test/sigra/install/core_isolation_test.exs -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/ --max-failures 1` — fast unit tests only, skips the `phx.new` golden-diff harness. **Target: <5 seconds.**
- **Per wave merge:** `mix test` — includes golden-diff harness. **Target: <60 seconds** (`mix phx.new` dominates; A7 assumption).
- **Phase gate:** Full `mix test` + `mix compile --warnings-as-errors` + `mix credo --strict` + `mix dialyzer` all green before `/gsd-verify-work`.

### Wave 0 Gaps

All test files under `test/sigra/install/` are new. Wave 0 must create:

- [ ] `test/sigra/install/feature_test.exs` — covers GEN-01 behaviour-contract shape
- [ ] `test/sigra/install/features/core_test.exs` — covers GEN-01 `Features.Core` implementation
- [ ] `test/sigra/install/purely_additive_test.exs` — covers the "second feature added with zero walker edits" invariant (V-PA-01 below)
- [ ] `test/sigra/install/template_layout_test.exs` — covers GEN-02 subdir layout
- [ ] `test/sigra/install/install_golden_diff_test.exs` — golden-diff harness, covers GEN-02 byte-identity + D-05 + re-run idempotency + summary completeness + compile check
- [ ] `test/sigra/install/report_test.exs` — covers GEN-05 Report struct + `render_summary/1`
- [ ] `test/sigra/install/migration_timestamps_test.exs` — covers GEN-07 allocator (incl. day-boundary carry + existing-file reuse)
- [ ] `test/sigra/install/core_isolation_test.exs` — covers Pitfall X-3 leakage check (grep-based)
- [ ] `test/fixtures/install_golden/` — committed golden tree (created by first run of `mix sigra.test.update_golden`)
- [ ] `lib/mix/tasks/sigra.test.update_golden.ex` — mix task to regenerate the golden fixture (ensures update ceremony)
- [ ] **No framework install needed** — ExUnit is stdlib, present in any Elixir project.

### V-PA-01: The Purely Additive Test (custom dimension — critical)

This is the **load-bearing** validation check for Phase 11's entire reason for being. Without it, the refactor cannot claim success.

```elixir
# test/sigra/install/purely_additive_test.exs — sketch
defmodule Sigra.Install.PurelyAdditiveTest do
  use ExUnit.Case, async: true

  defmodule FakeFeature do
    @behaviour Sigra.Install.Feature
    def enabled?(_opts), do: true
    def files(_b), do: [{:eex, "fake/fake.ex.eex", "lib/fake.ex"}]
    def injections(_b), do: []
    def migrations(_b), do: [{:fake_slot, "fake_migration.exs", "create_fake"}]
    def post_instructions(_b, _r), do: ["fake added"]
  end

  test "adding a new feature to the feature list requires ZERO edits to sigra.install.ex or runner" do
    # Walker accepts `features: [...]` as a parameter (or reads from @features attribute
    # that is ONLY referenced once). Calling the runner directly with [Features.Core, FakeFeature]
    # must succeed without touching any other code.
    {:ok, report} = Sigra.Install.Runner.run([Features.Core, FakeFeature], binding_fixture(), opts_fixture())
    assert Enum.any?(report.generated, &String.contains?(&1, "fake.ex"))
    assert Enum.any?(report.generated, &String.contains?(&1, "create_fake"))
  end

  test "runner does not pattern-match or branch on feature module name" do
    # Grep-based: the source file must not contain `Features.Core` outside the @features declaration.
    source = File.read!("lib/sigra/install/runner.ex")  # or lib/mix/tasks/sigra.install.ex
    references =
      source
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "Features.Core"))
    # Only one line allowed: the @features constant.
    assert length(references) <= 1, "Runner must not reference Features.Core outside the feature list. Found: #{inspect references}"
  end
end
```

**This test is the nyquist-audit-friendly, mechanically checkable proof that Phase 11 achieved its structural goal.** If it's green, Phase 18 will be a clean drop-in. If it's red, Phase 18 will require walker surgery — which is exactly the retrofit cost Phase 11 exists to prevent.

### V-GOLDEN-01: Golden-Diff Harness Shape

```elixir
# test/sigra/install/install_golden_diff_test.exs — sketch
defmodule Sigra.Install.InstallGoldenDiffTest do
  use ExUnit.Case

  @moduletag :golden

  @fixture_dir "test/fixtures/install_golden"
  @tmp_app_name "sigra_install_golden_tmp"

  setup_all do
    tmp = Path.join(System.tmp_dir!(), @tmp_app_name)
    File.rm_rf!(tmp)
    {_, 0} = System.cmd("mix", ~w(phx.new #{@tmp_app_name} --no-assets --no-mailer --no-install), cd: System.tmp_dir!())
    {_, 0} = System.cmd("mix", ~w(sigra.install Accounts User users --yes), cd: tmp)
    {:ok, tmp_app: tmp}
  end

  test "generated tree matches committed fixture byte-for-byte (migration filenames normalized)", %{tmp_app: tmp} do
    actual = normalize_tree(tmp)
    expected = read_fixture_tree(@fixture_dir)
    assert_tree_equal(actual, expected)
  end

  test "re-running the installer produces no diff (idempotent)", %{tmp_app: tmp} do
    snapshot1 = normalize_tree(tmp)
    {_, 0} = System.cmd("mix", ~w(sigra.install Accounts User users --yes), cd: tmp)
    snapshot2 = normalize_tree(tmp)
    assert_tree_equal(snapshot1, snapshot2)
  end

  test "generated app compiles with --warnings-as-errors", %{tmp_app: tmp} do
    {output, status} = System.cmd("mix", ~w(compile --warnings-as-errors), cd: tmp, stderr_to_stdout: true)
    assert status == 0, "Compile failed:\n#{output}"
  end

  test "summary output contains every generated file path", %{tmp_app: tmp} do
    # Capture IO during install, parse the 4-column summary, assert file set matches walked tree.
    # (Run installer again on a separate fresh fixture to capture output.)
  end

  # --- helpers ---
  defp normalize_tree(root) do
    # Walk all files under `lib/`, `priv/repo/migrations/`, `config/`, `test/support/`
    # For each file:
    #   - path relative to root
    #   - if path matches priv/repo/migrations/<14-digit>_*.exs, replace timestamp with "TIMESTAMP"
    #   - read content; migration file CONTENTS are NOT normalized (only filenames)
    # Return sorted list of {normalized_path, content}
  end

  defp assert_tree_equal(actual, expected) do
    actual_paths = Enum.map(actual, &elem(&1, 0)) |> Enum.sort()
    expected_paths = Enum.map(expected, &elem(&1, 0)) |> Enum.sort()

    assert actual_paths == expected_paths,
           "File set differs:\nMissing: #{inspect(expected_paths -- actual_paths)}\nExtra: #{inspect(actual_paths -- expected_paths)}"

    for {path, expected_content} <- expected do
      {^path, actual_content} = Enum.find(actual, &(elem(&1, 0) == path))
      if actual_content != expected_content do
        diff = String.myers_difference(expected_content, actual_content)
        flunk("Content differs at #{path}:\n#{render_diff(diff)}")
      end
    end
  end
end
```

### V-ISOLATION-01: Core Template Leakage Check (Pitfall X-3)

```elixir
# test/sigra/install/core_isolation_test.exs — sketch
defmodule Sigra.Install.CoreIsolationTest do
  use ExUnit.Case, async: true

  @forbidden_symbols ~w(Organization OrganizationMembership OrganizationInvitation UserPasskey Features.Organizations Features.Passkeys Features.Admin)

  test "no core template references future-feature symbols" do
    core_dir = "priv/templates/sigra.install/core"

    violations =
      core_dir
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.flat_map(fn path ->
        content = File.read!(path)
        for sym <- @forbidden_symbols, String.contains?(content, sym), do: {path, sym}
      end)

    assert violations == [], "Core templates reference future-feature symbols: #{inspect violations}"
  end
end
```

### Validation Dimension Mapping

| Dimension | Check | Mechanism |
|-----------|-------|-----------|
| **1. Syntactic** | `mix compile --warnings-as-errors` on Sigra itself + on generated app | ExUnit setup_all + `System.cmd` |
| **2. Type / contract** | `@behaviour` enforcement catches missing callbacks at compile time | Elixir compiler (free) |
| **2. Type / contract** | `mix dialyzer` validates `%Injection{}`, `%Report{}`, `%Feature{}` typespecs | CI job (existing) |
| **3. Lint / style** | `mix credo --strict` on all new modules | CI job (existing) |
| **4. Unit** | Each new module has direct unit tests (Feature contract, Core callbacks, Report, MigrationTimestamps) | ExUnit |
| **5. Integration** | Golden-diff test runs full `mix sigra.install` on real `mix phx.new` output | V-GOLDEN-01 |
| **6. Regression** | Golden fixture committed in git — any future template drift fails CI | V-GOLDEN-01 + `test/fixtures/install_golden/` |
| **7. Smoke** | Generated app compiles + existing Phase 10.1.1 HTTP smoke routes still pass | Reuse 10.1.1 harness |
| **8. Nyquist (custom)** | "Purely additive" check — fake feature dropped into walker without walker edits + grep-check that walker contains no `Features.Core` special-cases | V-PA-01 |
| **8. Nyquist (custom)** | "Core isolation" check — no forbidden future-feature symbol appears under `core/` | V-ISOLATION-01 |
| **8. Nyquist (custom)** | "Idempotent re-run" check — run twice, byte-equal after the second run | V-GOLDEN-01 re-run test |
| **8. Nyquist (custom)** | "Summary completeness" check — parse `Report.render_summary/1` output, assert every walker operation is represented in a column | V-GOLDEN-01 summary test |

**For a downstream nyquist auditor:** Dimension 8 in this phase has FOUR mechanically-checkable custom assertions (V-PA-01 is two of them — the fake-feature run + the grep check). All four are unit/integration tests; all four run in CI; all four fail LOUD on regression. No manual verification required. The phase is nyquist-auditable without human judgment.

## Security Domain

Phase 11 is a pure generator refactor. **No new authentication code, no new cryptographic surface, no new secret-handling.** The existing security-critical primitives (argon2 hashing, HMAC tokens, TOTP, etc.) live in library modules that are untouched by this phase — Phase 11 only rearranges the installer that writes the schemas referencing those primitives.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase 11 does not change how passwords are hashed, sessions are tracked, or tokens are issued |
| V3 Session Management | no | Untouched |
| V4 Access Control | no | Untouched |
| V5 Input Validation | **partial** | Existing `validate_args!/3` regex checks on context/schema/table names are preserved byte-for-byte in the refactor. New modules (`Report`, `MigrationTimestamps`, `Runner`) take no external input — all inputs are library-internal binding keyword lists. |
| V6 Cryptography | no | No crypto added or removed |
| V7 Error Handling & Logging | **partial** | `Report.record_skipped/3` now logs skipped files via `Mix.shell().info` — same sink as today, just structured. No new logging of secrets (binding never contains secrets). |

### Known Threat Patterns for this Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Install-task path traversal via context/schema/table args (e.g., `"../../etc/passwd"`) | Tampering | Existing `validate_args!/3` regex allow-list — **must be preserved verbatim** in the refactor. Audit that the validator runs BEFORE any `Path.join` in `Features.Core.files/1`. |
| EEx template binding injection (a hostile binding key produces arbitrary code) | Tampering | Binding is built from validated args only. `Features.Core` must not accept user-controlled binding extensions in Phase 11 (that's a Phase 18+ concern). |
| Golden fixture poisoning (attacker commits a bad fixture that hides a regression) | Tampering | **Process control, not code control.** PR-review rule: any fixture change requires explicit justification + re-running the generator to prove the diff is intentional. Enforce via Phase 23 PR template. |
| Template override path escape (host override at `../../../etc/...`) | Tampering | `find_template/1` uses `Path.join([File.cwd!(), "priv", "templates", ...])` — bounded to cwd. Preserved in the refactor with the `core/` prefix added. |
| Marker-comment spoofing (host file contains the marker string but not the code) | Tampering | Existing Injector checks only for marker presence, which is a known limitation. **Not regressing, not fixing in Phase 11.** Document as an open issue for a future hardening phase. |

No new threat surface is introduced. Phase 11's security posture is "preserve-by-byte-identity-test."

## Sources

### Primary (HIGH confidence)
- **Existing Sigra code** — `/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex` (785 lines, the monolith) `[VERIFIED: direct read]`
- **Existing Sigra code** — `/Users/jon/projects/sigra/lib/sigra/install/injector.ex` (413 lines, existing Injector) `[VERIFIED: direct read]`
- **Existing Sigra code** — `/Users/jon/projects/sigra/priv/templates/sigra.install/` (44 files, verified by `ls`) `[VERIFIED: direct read]`
- **Phoenix `phx.gen.auth` source** — `https://github.com/phoenixframework/phoenix/blob/main/lib/mix/tasks/phx.gen.auth.ex` — confirms module-split pattern, NO behaviour, NO offset timestamps `[VERIFIED: WebFetch 2026-04-11]`
- **Phoenix `phx.gen.schema` source** — confirms `timestamp/0` has no collision handling `[VERIFIED: WebFetch 2026-04-11]`
- **CONTEXT.md** — user-locked decisions D-01…D-08, CD-01…CD-05 `[VERIFIED: direct read]`
- **ARCHITECTURE.md §C1 + Part D** — subdirectory + feature-manifest pattern, dependency order `[VERIFIED: direct read]`
- **PITFALLS.md §X-1, X-2, X-3** — partial-apply, migration ordering, conditional template leakage `[VERIFIED: direct read]`
- **REQUIREMENTS.md** — GEN-01, GEN-02, GEN-04, GEN-05, GEN-07 `[VERIFIED: direct read]`
- **CLAUDE.md** — Sigra project constraints (stack, dev patterns, minimal deps) `[VERIFIED: system context]`

### Secondary (MEDIUM confidence — ecosystem research)
- **Mneme** — `https://github.com/zachallaun/mneme` — confirmed as per-assertion snapshot lib, NOT file-tree snapshot lib. Rejected as wrong tool for Phase 11. `[VERIFIED: WebFetch 2026-04-11]`
- **Igniter** — `https://github.com/ash-project/igniter` — confirmed as whole-project-patching framework with `Igniter.Mix.Task` behaviour (single `igniter/1` callback, not declarative lists). Rejected as wrong abstraction for Sigra's EEx-based install. `[VERIFIED: WebFetch 2026-04-11]`
- **snapshy** — `https://github.com/DCzajkowski/snapshy` — unmaintained. Rejected. `[CITED: search results]`
- **`Mix.Generator`** — `https://hexdocs.pm/mix/Mix.Generator.html` — stdlib file-writer with overwrite-prompt support `[CITED: hexdocs]`
- **`String.myers_difference/2`** — `https://hexdocs.pm/elixir/String.html#myers_difference/2` — stdlib diff primitive, same algorithm ExUnit uses for `assert ==` failure output `[CITED: hexdocs]`

### Tertiary (context only)
- **Mix.Phoenix source** — no helper for sequential timestamps `[VERIFIED: WebFetch 2026-04-11]`
- **aaronrenner/phx_gen_auth** — legacy Phoenix 1.5 generator, historical context only `[CITED: github]`

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — zero new deps, all stdlib, matches CLAUDE.md minimal-deps constraint.
- **Architecture patterns:** HIGH — behaviour pattern is Elixir-idiomatic; slot allocator is ahead of Phoenix upstream and is a clear improvement; Report accumulator is a conservative struct-threading pattern; Injection wrapper is a 1-day adapter over an existing 413-line module.
- **Pitfalls:** HIGH — identified from current code structure + CONTEXT.md PITFALLS.md cross-reference. The refactor risk pitfalls (1-5) are LOW severity given the golden-diff-first mitigation.
- **Golden-diff tooling:** MEDIUM (implementation shape) — the harness is bespoke. Recommendation is mechanically specified in V-GOLDEN-01 but actual rendering polish is a Wave 0 task.
- **Validation architecture:** HIGH — every phase requirement maps to a mechanically-checkable test; four nyquist-dimension-8 custom assertions defined.
- **Runtime state inventory:** HIGH — zero runtime state to migrate; only concern is host-app overrides which are CD-01 accepted.

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (30 days — ecosystem is stable; no known in-flight changes to Phoenix generators, ExUnit, or Mix.Generator that would invalidate the recommendations)
