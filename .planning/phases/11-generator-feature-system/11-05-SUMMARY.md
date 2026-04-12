---
phase: 11
plan: 05
subsystem: installer-generator
tags:
  - generator
  - walker
  - runner
  - refactor
  - wave-4
requires:
  - lib/sigra/install/feature.ex (Wave 1 — 5-callback behaviour)
  - lib/sigra/install/injection.ex (Wave 1 — %Injection{} struct)
  - lib/sigra/install/injector.ex (Wave 1 — apply/2 + apply_anchor/3)
  - lib/sigra/install/report.ex (Wave 1 — 4-column accumulator)
  - lib/sigra/install/migration_timestamps.ex (Wave 1 — slot allocator)
  - priv/templates/sigra.install/core/ (Wave 2 — 45 relocated templates)
  - lib/sigra/install/features/core.ex (Wave 3 — Feature implementation)
  - test/fixtures/install_golden/ (Wave 0 — tree + STDOUT.txt barrier)
provides:
  - lib/sigra/install/runner.ex (187 LOC generic walker)
  - lib/mix/tasks/sigra.install.ex (139 LOC thin caller — down from 795)
  - test/sigra/install/idempotency_test.exs (GEN-04 proof)
  - extended Sigra.Install.Injector.apply_anchor/3 (new anchors:
    :elixir_config, :append_eof, :conn_case_helpers)
affects:
  - lib/sigra/install/features/core.ex (files/1 inlines migrations;
    post_instructions/2 reshaped into ordered info-call chunks;
    router_injection reindented for byte-identity)
  - test/sigra/install/features/core_test.exs (length asserts updated)
  - test/sigra/install/generator_{mfa,wiring}_test.exs (white-box
    greps re-pointed from sigra.install.ex to features/core.ex)
  - test/sigra/install/api_token_generator_test.exs (same)
tech-stack:
  added: []
  patterns:
    - feature-agnostic-walker
    - inline-migration-slots-for-byte-ordering
    - per-info-call-post-instructions-chunks
    - overlay-existing-migrations-for-rerun-idempotency
key-files:
  created:
    - lib/sigra/install/runner.ex
    - test/sigra/install/idempotency_test.exs
  modified:
    - lib/mix/tasks/sigra.install.ex
    - lib/sigra/install/features/core.ex
    - lib/sigra/install/injector.ex
    - test/sigra/install/features/core_test.exs
    - test/sigra/install/generator_mfa_test.exs
    - test/sigra/install/generator_wiring_test.exs
    - test/sigra/install/api_token_generator_test.exs
decisions:
  - "Migration slots are INLINED into Features.Core.files/1 (as
    `{:eex, source, resolved_target}` tuples using timestamps threaded
    through binding[:migration_timestamps]) so the walker's
    create_file loop emits migrations at their exact monolith positions.
    The alternative — separating migrations into their own Runner
    callback — loses the interleaved file-ordering required for STDOUT
    byte-identity. migrations/1 still exists for MigrationTimestamps."
  - "Features.Core.post_instructions/2 returns a LIST OF CHUNKS where
    each top-level element is ONE logical Mix.shell().info/1 call.
    The Runner iterates and calls info per chunk. This reproduces the
    monolith's trailing-newline topology (3 info calls → 3 inserted
    newlines at the joints). Squashing to a single info call would
    require pre-baking joint newlines into the iodata and is brittle."
  - "post_instructions chunk ORDER is oban → swoosh → base_instructions,
    matching the monolith's inject_into_files → print_instructions flow
    (oban detection and swoosh mutation happen inside inject_into_files
    before the big print_instructions heredoc)."
  - "Added 3 new Injector.apply_anchor anchors for non-Elixir-module
    targets: :elixir_config (config.exs import_config-before-or-append
    semantics), :append_eof (test.exs), :conn_case_helpers (find
    `import Phoenix.ConnTest`/`import Plug.Conn` then insert-after-line).
    The original :before_last_end anchor only worked on files ending in
    `end` and was a silent no-op on config.exs."
  - "Re-run idempotency is layered: (1) run_files skips any target file
    that already exists (matches monolith behavior), (2)
    overlay_existing_migrations/2 pre-scans priv/repo/migrations for any
    file whose basename (post 14-digit-prefix strip) matches a slot
    target, and swaps the allocated timestamp with the existing prefix
    so the subsequent files/1 resolution points at the same file that
    File.exists?/1 will then report as a skip."
  - "White-box source-grep tests in generator_mfa_test.exs,
    generator_wiring_test.exs, and api_token_generator_test.exs were
    re-pointed from lib/mix/tasks/sigra.install.ex to
    lib/sigra/install/features/core.ex rather than deleted, so the
    content assertions (MFA routes, Oban detection, API pipeline,
    etc.) still run — they just run against the module that now owns
    the content."
metrics:
  duration: ~55 minutes
  tasks_completed: 2
  golden_diff_iterations: 3
  sigra_install_ex_loc_before: 795
  sigra_install_ex_loc_after: 139
  runner_ex_loc: 187
  idempotency_test_runtime_sec: ~22
  new_anchor_types: 3
  tests_passing_test_sigra_install: 324
  install_tests_added: 2
---

# Phase 11 Plan 05: Walker Refactor Summary

Wave 4 of Phase 11's generator-feature-system refactor. Replace the
795-line `Mix.Tasks.Sigra.Install` monolith with a 139-line thin caller
that delegates to a new 187-line feature-agnostic walker
(`Sigra.Install.Runner`). The walker iterates the canonical feature list
(currently `[Sigra.Install.Features.Core]`), calls each feature's 5
callbacks, and routes every file render and code injection through the
primitives landed in Waves 1-3.

**The golden-diff regression barrier from Wave 0 stayed green throughout
— every byte of the rendered file tree AND every byte of captured
stdout is byte-identical to the pre-refactor monolith.** The fixture at
`test/fixtures/install_golden/` was not regenerated: `git diff` on that
path is empty.

## Outcomes

### 1. `lib/sigra/install/runner.ex` — 187 LOC generic walker

```elixir
@spec run([module()], keyword(), keyword()) :: {:ok, Report.t()}
def run(features, binding, opts) do
  active = Enum.filter(features, fn f -> f.enabled?(opts) end)
  allocated = MigrationTimestamps.allocate(active, DateTime.utc_now())
  resolved_ts = overlay_existing_migrations(active, allocated)

  report =
    Enum.reduce(active, Report.new(), fn feature, r ->
      feature_binding = Keyword.put(binding, :migration_timestamps, resolved_ts[feature] || %{})
      r
      |> run_files(feature, feature_binding)
      |> run_injections(feature, feature_binding)
      |> run_post_instructions(feature, feature_binding)
    end)

  {:ok, report}
end
```

The Runner contains ZERO references to `Sigra.Install.Features.Core` or
any other specific feature module. Adding `Features.Organizations`,
`Features.Passkeys`, or `Features.Admin` in a later phase requires only
one new entry in the caller's `@features` list.

Key internals:

- **`run_files/3`** — iterates `feature.files(binding)`, skips existing
  targets with the monolith's `* skipping <path> (already exists)` line,
  and uses `Mix.Generator.create_file/2` for the rest so the `* creating
  <path>` lines match monolith output byte-for-byte.
- **`run_injections/3`** — iterates `feature.injections(binding)`, calls
  `Injector.apply(injection)`, and prints `* injecting <path>` /
  `* already injected <path>` matching the monolith.
- **`run_post_instructions/3`** — iterates the list of chunks returned
  by `feature.post_instructions/2` and calls `Mix.shell().info/1` per
  chunk. This reproduces the monolith's pattern of 3-4 separate
  `info/1` calls with their implicit trailing newlines.
- **`overlay_existing_migrations/2`** — re-run idempotency primitive:
  pre-scans `priv/repo/migrations/` for any file whose basename (after
  stripping any 14-digit prefix) matches a slot target, and swaps the
  allocated timestamp with the existing prefix so the subsequent
  `files/1` resolution points at the same on-disk file that
  `File.exists?/1` will then skip. This is what makes GEN-04 work: the
  second run emits `* skipping priv/repo/migrations/20260411_..._create_sigra_auth_tables.exs`
  instead of writing a duplicate migration with a new timestamp.
- **`find_template/1`** — respects the host-app override convention:
  `priv/templates/sigra.install/<source>` in the host app takes
  precedence over the `:sigra` app-dir path.

### 2. `lib/mix/tasks/sigra.install.ex` — 139 LOC thin caller

```elixir
@features [Sigra.Install.Features.Core]

def run(args) do
  {opts, parsed, _} = OptionParser.parse(args, switches: @switches)
  opts = Keyword.merge(@default_opts, opts)

  case parsed do
    [context_name, schema_name, table_name] ->
      validate_args!(context_name, schema_name, table_name)
      binding = build_binding(context_name, schema_name, opts[:table] || table_name, opts)
      {:ok, _report} = Runner.run(@features, binding, opts)
    _ ->
      Mix.raise(...)
  end
end
```

Everything else in this module is: arg validation regex checks
(`validate_args!/3`), binding construction (`build_binding/4`), and the
`get_repo_module/1` + `detect_adapter/1` helpers that were already
there. Zero inline file tuples, zero inline injection logic, zero
`print_instructions`, zero `offset_timestamp`. The only reference to
`Sigra.Install.Features.Core` in the whole file is the `@features`
module attribute.

### 3. Features.Core adjustments for byte-identity

Three coordinated changes to `lib/sigra/install/features/core.ex` were
needed to satisfy the golden-diff byte-identity contract when the walker
replaced the monolith's bespoke output path:

**(a) Migration inlining into `files/1`.**

The monolith's `files` list embeds migration entries at specific
positions (primary at position 0, audit_events at position 23, api_token
at position 0 of the api block). The golden STDOUT fixture captures
those `* creating` lines in that exact interleaved order. Wave 3's
original `Features.Core` put all migrations in `migrations/1` and
non-migration files in `files/1`, which meant the walker would emit
migrations either all-before or all-after the regular files — diverging
from the monolith.

The fix: `files/1` now returns migration entries inline as regular
`{:eex, source, target}` tuples, where `target` is pre-resolved using
`migration_target(binding, slot_key, basename)` which reads timestamps
from `binding[:migration_timestamps]` (threaded in by the Runner after
it calls `MigrationTimestamps.allocate/2`). `migrations/1` remains
intact for the allocator's input.

A new public helper `Features.Core.migration_target/3` provides a
deterministic `"TIMESTAMP"` placeholder when the binding lacks the
timestamps map, so unit tests that construct a raw binding (without
going through the Runner) still work.

**(b) `post_instructions/2` chunk reordering + reshaping.**

The monolith's control flow calls `inject_into_files` BEFORE
`print_instructions`. Inside `inject_into_files`, the last two calls
are `inject_oban_queue/1` and `inject_swoosh_config/2` — so their
output appears BEFORE the big "Sigra authentication has been installed!"
heredoc.

Wave 3's original `Features.Core.post_instructions/2` returned
`base_instructions ++ oban ++ swoosh`, which would produce the base
heredoc first on the walker, diverging from the monolith. The fix
reorders to `oban ++ swoosh ++ [base_instruction_block]`.

Additionally, Wave 3's helpers returned flat iodata lists that assumed
a single `Mix.shell().info/1` call. But the monolith makes 3-4 separate
`info/1` calls (each of which prepends its own implicit trailing
newline), and collapsing them into one call would lose those joint
newlines. The fix: each top-level element of the returned list is ONE
logical `info/1` call. The Runner does
`Enum.each(chunks, &Mix.shell().info/1)`.

`base_instructions` was converted from a 6-element list to a single
binary block (`base_instruction_block/1`) so it stays one `info/1` call,
matching the monolith's `print_instructions/1` single-heredoc `info/1`.

**(c) router_injection heredoc reindentation.**

The monolith's `router_plug_code` heredoc uses content-indent=8,
closing-`"""`=6 (stripped to 2-space base) with interpolated nested
heredocs (`live_routes`, `mfa_challenge_routes`, etc.) that have
content-indent=14, closing-`"""`=10 (stripped to 4 spaces). Features.Core's
original version had mismatched nested-heredoc indentation that yielded
8-space stripped content, producing router.ex with 4 extra leading
spaces on every nested route line. The fix: rewrite every nested route
heredoc to strip to 4 spaces, matching the monolith.

### 4. `Injector.apply/2` anchor extensions

The original Wave 1 `apply_anchor/3` only supported `:before_last_end`,
`:after_use_block`, and `:at_top`. `:before_last_end` matches a regex
`~r/\nend\s*\z/` which only works for files that literally end in
`\nend`. Phoenix's `config/config.exs` doesn't — it ends with
`import_config "#{config_env()}.exs"` with no trailing `end`. And
`config/test.exs` usually ends mid-config too. Running the first walker
revealed that config.exs and test.exs injections were silent no-ops.

Three new anchors landed to handle these cases with byte-semantics
matching the monolith's specialized helpers:

- **`:elixir_config`** — mirrors `inject_config/2`: insert before the
  `import_config` line if present, otherwise append.
- **`:append_eof`** — mirrors `inject_test_config/2`: append to end of
  file.
- **`:conn_case_helpers`** — mirrors `inject_conn_case/2`: find
  `import Phoenix.ConnTest` (or `import Plug.Conn`) and insert the
  helper code on the line below; falls back to `:before_last_end`.

`Features.Core.config_injection`, `test_config_injection`,
`conn_case_injection`, and the API config injection were updated to
declare the appropriate anchors.

### 5. GEN-04 idempotency test

New `test/sigra/install/idempotency_test.exs` (130 LOC):

1. `setup_all` scaffolds a fresh Phoenix tmp app via
   `InstallFixture.setup_tmp_app/0` (which runs `mix sigra.install` as
   part of its flow).
2. First test: snapshots the tracked tree (sha256 per file) + mtimes,
   runs `mix sigra.install Accounts User users --yes` a second time,
   re-snapshots, and asserts:
   - Every file that existed before the second run has unchanged
     content hash afterward.
   - No new files appeared.
   - Every file's mtime is unchanged (stronger than byte-identity —
     proves the runner did not re-open).
   - Second-run stdout contains `already exists` or `already injected`.
3. Second test: a smoke floor asserting the first run actually wrote
   files (guards against harness drift).

Runtime ~22 seconds, dominated by the shared `setup_all` (phx.new +
deps.get + compile + first install).

## Task Breakdown

### Task 1: Extract walker + shrink monolith
**Commit:** `98d3816` — `refactor(11-05): extract generic walker into Sigra.Install.Runner`

Created `lib/sigra/install/runner.ex` (187 LOC), rewrote
`lib/mix/tasks/sigra.install.ex` from 795 LOC to 139 LOC, extended
`Injector.apply_anchor/3` with 3 new anchors, reshaped Features.Core's
`files/1` and `post_instructions/2`, reindented `router_injection/3`
nested heredocs, and updated 4 test files for the new contract.

**Golden-diff iteration log (3 attempts):**

1. **First run**: 2 failures.
   - Tree: `config/config.exs` and `config/test.exs` were filtered out
     of the delta (missing from generated output). Root cause: Wave 1's
     `:before_last_end` anchor silently no-oped on non-Elixir-module
     files.
   - STDOUT: oban detection went down the "not detected" branch because
     `File.read!("config/config.exs") =~ "Oban"` returned false (since
     the config injection had no-oped and the sigra block that contains
     the word "Oban" was never written).
   - Fix: added `:elixir_config` / `:append_eof` / `:conn_case_helpers`
     anchors to `Injector.apply_anchor/3` and updated Features.Core to
     use them.

2. **Second run**: 1 failure.
   - Tree: `router.ex` content diverged — 10 lines of "extra 4-space
     indents". STDOUT was already green.
   - Root cause: Features.Core's nested route heredocs (live_routes,
     mfa_challenge_routes, etc.) had content-indent=16, closing-indent=8
     yielding 8-space stripped content. The monolith had
     content-indent=14, closing-indent=10 yielding 4-space stripped.
   - Fix: rewrote every nested route heredoc in `router_injection/3` to
     strip to 4 spaces.

3. **Third run**: 2/2 green. Both byte-identity tests pass.

### Task 2: GEN-04 idempotency test
**Commit:** `75cdc02` — `test(11-05): add GEN-04 re-run idempotency proof`

Landed `test/sigra/install/idempotency_test.exs` (2 tests, both green
on first run).

## Deviations from Plan

### [Rule 3 - Blocking] Migration inlining into files/1

**Found during:** Task 1, during design-for-byte-identity analysis
before writing any code.

**Issue:** The plan's draft `Runner.run/3` separated file rendering from
migration rendering into distinct callbacks (`run_files` then
`run_migrations`). But the monolith's golden STDOUT.txt shows migrations
interleaved with other files at specific positions (primary at line 1,
audit_events at line 24) — they are NOT all-before or all-after the
regular files. A clean separation in the Runner would produce diverged
output.

**Fix:** Modified `Features.Core.files/1` to include migration entries
inline at their correct monolith positions, using `migration_target/3`
to resolve timestamps from `binding[:migration_timestamps]`. The Runner
threads the timestamp map into the binding before calling `files/1`.
`migrations/1` remains intact for the `MigrationTimestamps.allocate/2`
input. Three Wave 3 contract tests updated for the new file counts
(34→36 default, 28→30 `--no-live`) and the `refute "core/migration.exs"
in sources` assertions were inverted to `assert`.

**Files modified:** `lib/sigra/install/features/core.ex`,
`test/sigra/install/features/core_test.exs`.
**Commit:** `98d3816`

### [Rule 1 - Bug] `:before_last_end` anchor silently no-ops on config.exs / test.exs

**Found during:** Task 1, first golden-diff run. The tree test reported
that `config/config.exs` and `config/test.exs` were missing from the
generated delta, meaning those files were byte-identical to the
pre-install baseline — i.e. the config/test injections never took effect.

**Root cause:** `Injector.apply_anchor(:before_last_end, ...)` uses
`String.replace(content, ~r/\nend\s*\z/, ...)`. Phoenix's config files
end with `import_config "#{config_env()}.exs"` — no trailing `end`. The
regex doesn't match → `String.replace` returns the original content →
`File.write!` writes unchanged bytes → injection is a no-op.

The monolith worked around this by routing each target to a specialized
helper (`inject_config`, `inject_test_config`, `inject_conn_case`) with
different anchor-finding logic. Wave 1's generic `:before_last_end`
anchor was too narrow.

**Fix:** Added 3 new anchors to `Injector.apply_anchor/3`:
`:elixir_config`, `:append_eof`, `:conn_case_helpers`, each implementing
the exact byte-semantics of the corresponding monolith helper.
Features.Core's 4 default injections now declare the appropriate
anchor per target.

**Files modified:** `lib/sigra/install/injector.ex`,
`lib/sigra/install/features/core.ex`,
`test/sigra/install/features/core_test.exs` (anchor-support list).
**Commit:** `98d3816`

### [Rule 1 - Bug] router_injection heredoc indentation drift

**Found during:** Task 1, second golden-diff run. Tree test reported
`router.ex` content differed — 10 extra 4-space indents sprinkled
throughout the generated router.

**Root cause:** Features.Core's Wave 3 router_injection heredocs used
different indentation than the monolith's. The nested-heredoc stripping
math (content-indent minus closing-`"""`-indent) produced 8-space
content in Features.Core vs 4-space content in the monolith.

**Fix:** Rewrote every nested route heredoc in `router_injection/3`
(live_routes, confirmation_routes, reset_routes,
session_management_routes, mfa_challenge_routes, mfa_settings_routes,
account_lifecycle_routes) to use content-indent=12, closing-indent=8
yielding exactly 4-space stripped content. Matches monolith bytes.

**Files modified:** `lib/sigra/install/features/core.ex`
**Commit:** `98d3816`

### [Rule 2 - Missing critical functionality] post_instructions chunk shape

**Found during:** Task 1 planning (before first run). Analysis of the
golden STDOUT.txt showed that the monolith's `print_instructions`,
`inject_oban_queue`, and `inject_swoosh_config` each make separate
`Mix.shell().info/1` calls. `Mix.shell().info/1` appends an implicit
`\n` to its argument, so each call contributes one joint newline.

The draft Wave 3 `post_instructions/2` returned a flat iodata list,
assuming the walker would do ONE `info/1` call with the whole list.
That would collapse the 3 joint newlines into 1 — diverging from the
golden STDOUT.

**Fix:** Reshape `post_instructions/2` to return a list of CHUNKS where
each top-level element is one logical `info/1` call's payload. Also
reorder the chunks to `oban → swoosh → base_instructions` matching the
monolith's `inject_into_files → print_instructions` flow. The Runner
iterates the list and does one `info/1` per chunk.

`base_instructions(opts)` was converted from a 6-element list to a
single binary block (`base_instruction_block/1`).

**Files modified:** `lib/sigra/install/features/core.ex`,
`lib/sigra/install/runner.ex`
**Commit:** `98d3816`

### [Rule 3 - Blocking] Legacy white-box tests re-pointing

**Found during:** Task 1, final test suite pass. Three pre-refactor
tests were grepping `lib/mix/tasks/sigra.install.ex` for inline route
strings, file-list entries, Oban/Swoosh detection keywords, and API
pipeline markers. After the refactor, those strings live in
`lib/sigra/install/features/core.ex`, so the asserts broke.

**Fix:** Updated `test/sigra/install/generator_mfa_test.exs`,
`test/sigra/install/generator_wiring_test.exs`, and
`test/sigra/install/api_token_generator_test.exs` to grep
`lib/sigra/install/features/core.ex` instead. Also updated the
`--api`/`--jwt` flag-presence tests to keep reading the task file
(since switches stay there) and re-pointed the file-list content
assertions to Features.Core.

No test intent was changed — every test still asserts the same
functional behavior, just against the new module that owns it.

**Files modified:** as above.
**Commit:** `98d3816`

## Verification

### Golden-diff regression barrier (Wave 0)

```
$ mix test test/sigra/install/golden_diff_test.exs
..
Finished in 41.1 seconds (0.00s async, 41.1s sync)
2 tests, 0 failures
```

Both byte-identity tests (tree + STDOUT.txt) green.

### Fixture byte-identity (forbidden-regeneration invariant)

```
$ git diff test/fixtures/install_golden/
(empty)
```

The fixture directory is unchanged. No file was regenerated as a
workaround.

### Idempotency test

```
$ mix test test/sigra/install/idempotency_test.exs
..
Finished in 21.5 seconds (0.00s async, 21.5s sync)
2 tests, 0 failures
```

### Install subsystem tests

```
$ mix test test/sigra/install
...
Finished in 63.6 seconds (0.2s async, 63.4s sync)
324 tests, 0 failures
```

Up from 322 → 324 (+2 from the new idempotency test).

### Full library test suite

```
$ mix test test/sigra --seed 0
...
Finished in 43.2 seconds (1.8s async, 41.4s sync)
33 doctests, 3 properties, 1296 tests, 0 failures
```

### Compile + format

```
$ mix compile --warnings-as-errors
Compiling 1 file (.ex)
Generated sigra app

$ mix format --check-formatted
(clean)
```

### LOC targets

| File | Before | After | Target | Met |
|---|---|---|---|---|
| `lib/mix/tasks/sigra.install.ex` | 795 | **139** | ≤150 | yes |
| `lib/sigra/install/runner.ex` | 0 | 187 | — | — |
| `lib/sigra/install/features/core.ex` | 695 | 744 | — | — |
| `test/sigra/install/idempotency_test.exs` | 0 | 130 | — | — |

The Core module grew slightly (+49 LOC) because of the inlined
migration handling, the reshape of `post_instructions/2` chunks, and
the reindented router_injection heredocs.

### Anchor-only reference to Features.Core in the Mix task

```
$ grep -c "Features\.Core" lib/mix/tasks/sigra.install.ex
1
```

Exactly one reference, in the `@features` attribute.

## Known Stubs

None. Every file is fully wired and functional. The Report accumulator
is populated through the run but not rendered to stdout in the default
path (would diverge from the golden STDOUT); it is returned from
`Runner.run/3` for host tooling (CI smoke runners, the idempotency
test) to inspect. That's an intentional design choice, not a stub.

## Threat Flags

None. Phase 11 Wave 4 is a pure refactor: same generation output, same
file writes, same injections, same host-app overrides. No new network
endpoints, no new auth paths, no new file access patterns beyond what
the monolith already had. T-11-19 and T-11-20 (Tampering against
existing files / migration collisions) are mitigated by the
`File.exists?`-skip in `run_files/3` and the `overlay_existing_migrations/2`
pre-scan respectively — both locked in by the new GEN-04 idempotency
test.

## Self-Check: PASSED

- `lib/sigra/install/runner.ex`: FOUND
- `lib/mix/tasks/sigra.install.ex` at 139 LOC: VERIFIED (target ≤150)
- `test/sigra/install/idempotency_test.exs`: FOUND
- Commit `98d3816` (Task 1 walker refactor): FOUND
- Commit `75cdc02` (Task 2 idempotency test): FOUND
- `mix test test/sigra/install/golden_diff_test.exs` → 2/2 green: VERIFIED
- `git diff test/fixtures/install_golden/` → empty: VERIFIED
- `mix test test/sigra/install/idempotency_test.exs` → 2/2 green: VERIFIED
- `mix test test/sigra/install` → 324/324 green: VERIFIED
- `mix test test/sigra --seed 0` → 1296/1296 green: VERIFIED
- `mix compile --warnings-as-errors` clean: VERIFIED
- `mix format --check-formatted` clean: VERIFIED
- `@features [Sigra.Install.Features.Core]` is the only Core reference
  in `lib/mix/tasks/sigra.install.ex`: VERIFIED
