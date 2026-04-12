# Phase 11: Generator Feature System - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 11 introduces `Sigra.Install.Feature` (a behaviour) and `Sigra.Install.Features.Core` (its first implementation), and mechanically moves every v1.0 template from `priv/templates/sigra.install/` into `priv/templates/sigra.install/core/`. `mix sigra.install --yes` on a fresh `mix phx.new` project must produce content byte-identical to phase 10.1.1 (migration filename timestamps excepted — see D-05), compile, boot, and pass the existing HTTP smoke routes.

**In scope:**
- `Sigra.Install.Feature` behaviour definition (5 callbacks — see D-01)
- `Sigra.Install.Features.Core` module owning all v1.0 files, injections, migrations, and post-install instructions
- `sigra.install.ex` refactored into a generic walker over a `[Features.Core]` list
- Template subdirectory move (`core/`), preserving content byte-for-byte
- `Sigra.Install.Report` accumulator for the 4-column post-install summary
- `Sigra.Install.MigrationTimestamps` slot-based allocator (replaces `offset_timestamp/1`)
- CI golden-output diff test proving byte-identity across the refactor

**Out of scope (belongs in later phases):**
- `Features.Organizations`, `Features.Passkeys`, `Features.Admin` modules — Phases 18, 22, v1.2
- `--no-organizations` / `--no-passkeys` flag wiring — Phases 18, 22
- Combinatorial CI smoke matrix (GEN-03) — Phase 18 / 22
- Backfill migration generator (X-2 full mitigation) — Phase 18
- `mix sigra.install.check` dry-run task — deferred

</domain>

<decisions>
## Implementation Decisions

### Behaviour Contract

- **D-01:** `Sigra.Install.Feature` defines **five callbacks**:
  - `enabled?(opts :: keyword()) :: boolean()` — gates the feature on generator opts. `Features.Core.enabled?/1` always returns `true` (Success Criterion #4).
  - `files(binding :: keyword()) :: [{:eex, source :: String.t(), target :: String.t()}]` — non-migration EEx templates only. Migration templates route through `migrations/1`.
  - `injections(binding :: keyword()) :: [%Sigra.Install.Injection{}]` — structured injection descriptors (see D-02).
  - `migrations(binding :: keyword()) :: [{slot_key :: atom(), template :: String.t(), target_basename :: String.t()}]` — returns slots in intended execution order; the central allocator assigns timestamps (D-04). `Features.Core.migrations/1` returns slots `:primary`, `:api_token`, `:audit_events` (preserving today's 3 migration set).
  - `post_instructions(binding :: keyword(), report :: Sigra.Install.Report.t()) :: [iodata()]` — lines to append to the final post-install output. Features contribute their own instructions without touching `sigra.install.ex`.

- **D-02:** `injections/1` returns a list of structured `%Sigra.Install.Injection{}` records, not raw IO callbacks. Shape (draft — planner may refine names):
  ```elixir
  %Sigra.Install.Injection{
    target: Path.t(),           # e.g. "lib/my_app_web/router.ex"
    marker: String.t(),         # idempotency marker comment
    anchor: atom(),             # :before_last_end | :after_use_block | :at_top | ...
    content: String.t()         # rendered code block
  }
  ```
  The central walker passes each record to `Sigra.Install.Injector`, which owns marker checking and anchor resolution. Features never call `Injector` directly. This ensures every future feature inherits idempotency (GEN-04) for free.

### Refactor Depth

- **D-03:** **Full decomposition.** `Features.Core` owns everything v1.0-specific:
  - All 44 non-migration `{:eex, src, dst}` file tuples currently built across `lib/mix/tasks/sigra.install.ex:83-319` (subject to the subdir prefix change)
  - All router/config/runtime.exs injections currently emitted inline by `inject_into_files/2` (`:332-` in the same file)
  - The three Core migrations (`migration.exs`, `api_token_migration.exs`, `create_audit_events.exs`) via `migrations/1` slots
  - The full `print_instructions/1` content (currently at `:753`) via `post_instructions/2`

  After refactor, `sigra.install.ex` contains only:
  1. Arg parsing + `validate_args!` + binding construction
  2. A generic walker: `features = [Features.Core]; Enum.each(features, &run_feature(&1, binding, report))`
  3. Final `Report.render_summary/1` + concatenation of `post_instructions/2` output

  This is the biggest Phase 11 diff, and it is deliberate — it is the exact shape Phases 18 (`--no-organizations`), 22 (`--no-passkeys`), and v1.2 (`--no-admin`) plug into with zero further generator-task surgery. Load-bearing per ROADMAP.md Phase 11 description.

### Post-Install Summary (GEN-05)

- **D-06:** Summary is a **4-column ASCII table**: `generated | modified | skipped | manual-action`. Column contents are file paths (relative to project root) or, for `manual-action`, short instruction lines. Table wraps long paths; no truncation. Printed at the end of the walk, after every feature has contributed.

- **D-07:** Data is collected **record-as-you-go** via `Sigra.Install.Report` (a simple struct accumulator, not a GenServer — the walker is synchronous). Every file write, injection, and skip decision flows through `Report.record_generated/2`, `Report.record_skipped/3`, `Report.record_modified/2`, `Report.record_manual_action/2`. This replaces the ad-hoc `Mix.shell().info([:yellow, "* skipping ", ...])` inline prints at `lib/mix/tasks/sigra.install.ex:305-311`. `Mix.Generator.create_file/2` is still the underlying writer, but its output is captured into `Report` rather than printed directly.

### Migration Timestamps (GEN-07)

- **D-04:** `Sigra.Install.MigrationTimestamps` owns a slot-based allocator. Public shape (draft):
  ```elixir
  # Deterministic ordering: features listed in the canonical feature order
  # get earlier timestamps; slots within a feature get sequential offsets.
  MigrationTimestamps.allocate(features :: [module()], base_time :: DateTime.t())
    :: %{module() => %{atom() => String.t()}}
  # returns e.g. %{Features.Core => %{primary: "20260411120000",
  #                                    api_token: "20260411120001",
  #                                    audit_events: "20260411120002"}}
  ```
  The walker calls `allocate/2` once, then passes the resolved map through each feature's `run_feature`. Migration files are written with the allocated timestamp in the filename.

- **D-05:** **Byte-identical exception — migration filename timestamps.** Today's `offset_timestamp/1` (`lib/mix/tasks/sigra.install.ex:635-648`) already bases timestamps on wall-clock `:calendar.universal_time`, so migration filenames are non-deterministic between runs even on 10.1.1. The Phase 11 CI golden test (D-08) must therefore **normalize migration filenames** (replace the leading 14-digit timestamp with a placeholder) before diffing. Content inside migration files is subject to full byte-identity. The existing "skip if migration file already present" idempotency logic (`:119-132`, `:212-226`) moves into `Features.Core.migrations/1` or a helper — must still work on re-run so that slots resolve to an existing on-disk file instead of allocating a new one.

### Verification

- **D-08:** **CI golden-output diff test.** Extends the Phase 10.1.1 smoke harness:
  1. `mix phx.new tmp_app --no-assets --no-mailer` (or reuse the existing smoke fixture)
  2. `mix sigra.install --yes` in the fresh app
  3. Snapshot the generated tree into a normalized form (migration filenames normalized per D-05)
  4. Diff against a committed `test/fixtures/install_golden/` snapshot
  5. Zero diff → pass; any diff → fail with a unified diff in the CI log
  The snapshot is committed in this phase after the refactor lands and becomes the regression barrier for Phases 18/22/v1.2.

### Claude's Discretion

- **CD-01:** **Template override path semantics.** Host-app overrides at `priv/templates/sigra.install/...` (discovered by `find_template/1` at `lib/mix/tasks/sigra.install.ex:321-330`) will mirror the new subdir layout — `priv/templates/sigra.install/core/user.ex` overrides the library `core/user.ex`. No flat-legacy fallback. This is a breaking change to the override path for any downstream that has overrides, but (a) the library is pre-1.0, (b) the override mechanism is an escape hatch with no public-API stability guarantee, and (c) a stable subdir rule is what every future feature needs. Documented in the Phase 23 upgrade guide.

- **CD-02:** **`Sigra.Install.Report` struct shape.** Internal concern — planner picks concrete field names. Must support the four record functions in D-07 and a `render_summary/1` that emits the 4-column table in D-06.

- **CD-03:** **`%Sigra.Install.Injection{}` field names.** Draft in D-02 is suggestive; planner may rename (`anchor` → `position`, `target` → `path`, etc.) as long as the Injector contract is preserved and structured data is returned.

- **CD-04:** **`Features.Core` submodule granularity.** Whether `Features.Core` is one large module or is split into `Features.Core.{Files, Injections, Migrations, Instructions}` submodules is a style call — planner's discretion. Either is acceptable as long as `Sigra.Install.Feature` is implemented on a single public module named `Sigra.Install.Features.Core`.

- **CD-05:** **Walker implementation.** Whether the walker lives in `Mix.Tasks.Sigra.Install` directly or in a `Sigra.Install.Runner` helper — style call. Out of scope to over-specify.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Pattern
- `.planning/research/ARCHITECTURE.md` §C1 (lines 331–382) — Subdirectory + feature manifest hybrid pattern. The recommended behaviour shape, subdir layout, and migration plan for v1.1 Phase 1 (now Phase 11). Source of D-01.
- `.planning/research/ARCHITECTURE.md` §Part D (lines 399–418) — Build order; confirms Phase 11 is the foundation, blocks everything downstream.

### Requirements
- `.planning/REQUIREMENTS.md` GEN-01 (line 113) — subdirectory-based feature manifest. Load-bearing for v1.2 `--no-admin`.
- `.planning/REQUIREMENTS.md` GEN-02 (line 114) — mechanical, content-preserving move of v1.0 templates into `core/`.
- `.planning/REQUIREMENTS.md` GEN-04 (line 116) — idempotent re-run with marker comments. Informs D-02 (structured `%Injection{}` owns marker logic).
- `.planning/REQUIREMENTS.md` GEN-05 (line 117) — post-install summary (generated/modified/skipped/manual-action). Source of D-06/D-07.
- `.planning/REQUIREMENTS.md` GEN-07 (line 119) — strictly-ordered migration timestamps; pitfall X-2. Source of D-04.

### Pitfalls
- `.planning/research/PITFALLS.md` §X-1 (lines 641–664) — Generator partial-apply on conditional templates. The feature-manifest pattern is the structural mitigation; Phase 11 must not scatter `if opts[:feature]` branches across `generate/4`.
- `.planning/research/PITFALLS.md` §X-2 (lines 668–687) — Migration ordering. D-04 (slot allocator) and D-05 (normalization) address this.
- `.planning/research/PITFALLS.md` §X-3 (lines 691–714) — Conditional template leakage. Core templates must compile with zero other features enabled; nothing in `core/*` may reference `Organization*`, `UserPasskey`, etc.

### Roadmap Context
- `.planning/ROADMAP.md` Phase 11 entry (lines 48–59) — phase goal, depends-on, requirements, success criteria. The "byte-identical" hard constraint and the `Features.Core.enabled?/1 == true` requirement come from here.
- `.planning/ROADMAP.md` Phase 22 entry (lines 197–204) — Phase 22 is the "second consumer" validation of the Phase 11 pattern. Downstream planners should keep Phase 22's ergonomic needs in mind when finalizing the behaviour contract.

### Existing Code to Refactor
- `lib/mix/tasks/sigra.install.ex` (785 lines) — the monolith being decomposed. Key ranges:
  - `:83-319` `generate/4` — file list construction (D-03 target)
  - `:321-330` `find_template/1` — override path resolution (CD-01)
  - `:332-` `inject_into_files/2` — router/config/runtime.exs injections (D-03 target)
  - `:635-648` `offset_timestamp/1` — replaced by `MigrationTimestamps.allocate/2` (D-04)
  - `:753-` `print_instructions/1` — migrates into `Features.Core.post_instructions/2`
- `lib/sigra/install/injector.ex` — existing marker-based injector. Reused as-is by the walker; gains a thin wrapper that accepts `%Injection{}`.
- `priv/templates/sigra.install/*.ex` (44 files) — all move to `priv/templates/sigra.install/core/` unchanged.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Sigra.Install.Injector`** (`lib/sigra/install/injector.ex`) — idempotent marker-based code injection. The marker-check + already-injected pattern is exactly what `%Injection{}` needs; wire the walker to call `Injector.inject_router_plugs/2` (and siblings) via the struct's `anchor` tag.
- **`Mix.Generator.create_file/2`** — current writer in `sigra.install.ex:310`. Keep using it; wrap the call in `Report.record_generated/2` so the Report captures the decision.
- **`EEx.eval_file/2`** — current template eval in `sigra.install.ex:309`. Unchanged.
- **`Mix.Phoenix.base/0` + `Mix.Phoenix.web_module/1`** — binding construction helpers at `sigra.install.ex:84-85`. Unchanged.

### Established Patterns
- **Template path resolution with user override first** (`find_template/1` at `:321-330`). Subdir refactor preserves this pattern, just with `core/` prefix prepended. Planner must audit every call site to make sure subdir is applied consistently.
- **Existing-migration detection + reuse** (`:119-132`, `:212-226`) — today's idempotency for migrations (re-run doesn't create a duplicate). This logic moves into either `Features.Core.migrations/1` or the `MigrationTimestamps` allocator so that the slot-to-filename mapping prefers an existing on-disk migration over allocating a fresh timestamp.
- **`Mix.shell().info` with IO-ANSI colors** — current progress output style. `Report` should preserve the color convention in its final summary table (green for generated, yellow for skipped, etc.) to match existing UX.
- **Three-phase file-list build**: core files + api_files + jwt_files + ui_files → `all_files = files ++ ui_files ++ api_files ++ jwt_files` (`:301`). In the refactor, this entire merge moves into `Features.Core.files/1` — `--api`, `--jwt`, `--live` branches stay as `Keyword.get(opts, ...)` gates *inside* `Features.Core.files/1`, since those are Core-owned options.

### Integration Points
- `lib/mix/tasks/sigra.install.ex` — the task module itself. Becomes ~150 lines: arg parsing, binding, walker, summary print.
- `lib/sigra/install/` — new home for `feature.ex` (behaviour), `features/core.ex`, `injection.ex` (struct), `migration_timestamps.ex`, `report.ex`, and (later) `features/organizations.ex`, `features/passkeys.ex`.
- `priv/templates/sigra.install/core/` — new home for all 44 v1.0 templates (mechanical move).
- `test/fixtures/install_golden/` (new) — committed golden snapshot for the CI byte-identity test (D-08).
- `.github/workflows/ci.yml` — extend to run the golden-diff test.

### Creative Options
- The walker could emit **diagnostics as telemetry events** (`[:sigra, :install, :file_written]`, `[:sigra, :install, :injection_skipped]`) which `Report` consumes. This gives power-user apps a hook to observe the install. **Deferred** — not needed for Phase 11 success criteria, add if a later phase needs it.
- A future `mix sigra.install.check` dry-run task becomes trivial once the walker is generic: instantiate a `Report` in `:dry_run` mode, skip actual writes. **Deferred** to a later phase (explicit scope-creep rejection).

</code_context>

<specifics>
## Specific Ideas

- **"Purely additive" test for the behaviour contract.** After Phase 11 lands, adding a second `Features.Organizations` module in a later phase must require **zero** edits to `lib/mix/tasks/sigra.install.ex` — only a new entry in the feature list and a new module under `lib/sigra/install/features/`. If the Phase 11 design fails this check, it failed its job. Planner should explicitly think about this when finalizing the walker signature.

- **Deterministic feature ordering.** The feature list `[Features.Core, ...]` has a canonical order (currently single-entry; later `[Features.Core, Features.Organizations, Features.Passkeys, Features.Admin]`). This order drives `MigrationTimestamps.allocate/2` (D-04) and injection-emission order (so router routes appear in a stable sequence). The order is defined in `sigra.install.ex` (or a dedicated `Sigra.Install.FeatureRegistry`) — a constant list, not user-configurable.

- **Feature module isolation (Pitfall X-1 §6).** `Features.Core` must not reference `Features.Organizations`, `Features.Passkeys`, or any future feature symbols — even indirectly. Phase 11 only ships Core, but the boundary discipline needs to be established now so the compile-in-all-combos guarantee holds later.

</specifics>

<deferred>
## Deferred Ideas

- **`mix sigra.install.check` dry-run task** — useful rollback aid per Pitfall X-1 §4. Not in Phase 11 scope (success criteria don't require it). Candidate for a v1.1 polish phase or Phase 23.
- **Combinatorial CI smoke matrix** (`{--organizations, --no-organizations} × {--passkeys, --no-passkeys} × {--live, --no-live}`) — GEN-03, Pitfall X-1 §5. Cannot run until Phases 18/22 add the features being toggled. Belongs in Phase 18 (orgs smoke) and Phase 22 (combinatorial).
- **Telemetry events for install operations** — power-user hook. No current consumer; add when a phase needs it.
- **`mix sigra.install.rollback` task** — generator-undo for the "I picked wrong" path (Pitfall X-1 §7). Bigger feature, belongs in a v1.2+ polish milestone.
- **Per-feature override paths with flat-legacy fallback** — explicitly rejected in CD-01. Rediscussion only if a real user has v1.0 overrides in their repo and upgrade complaints surface.

</deferred>

---

*Phase: 11-generator-feature-system*
*Context gathered: 2026-04-11*
