---
phase: 11-generator-feature-system
plan: 01
subsystem: testing
tags: [golden-diff, regression-barrier, mix-phx-new, ex-unit, generator, install]

# Dependency graph
requires:
  - phase: 10.1.1
    provides: pre-refactor monolith at lib/mix/tasks/sigra.install.ex (785 lines) that this fixture captures
provides:
  - "test/support/install_fixture.ex: tmp-app scaffolding helper (mix phx.new -> path dep -> mix sigra.install) with normalize_tree/2 + normalize_stdout/2 + snapshot_paths/1"
  - "test/sigra/install/golden_diff_test.exs: 2-test harness proving tree + STDOUT byte-identity against committed fixture, fails loudly with runbook pointer if fixture missing/empty"
  - "test/fixtures/install_golden/: 42-file committed golden snapshot (41 tree files + STDOUT.txt)"
  - "Regression barrier for every Phase 11 wave 1+ commit"
affects: [11-02, 11-03, 11-04, 11-05, 11-06, 11-07, 11-08, 18-organizations, 22-passkeys]

# Tech tracking
tech-stack:
  added: []  # no new hex packages — bespoke harness uses only stdlib + existing mix
  patterns:
    - "Pre-refactor golden fixture captured before any decomposition work begins (RESEARCH.md §Refactor risk mitigation)"
    - "Baseline-diff tree capture: snapshot pre-install paths, only include files sigra.install created/modified in the fixture"
    - "Normalization pipeline: ANSI strip, absolute path placeholder, migration timestamp placeholder, Phoenix random-salt placeholder, dep compile noise filter"

key-files:
  created:
    - test/support/install_fixture.ex (280 lines)
    - test/sigra/install/golden_diff_test.exs (198 lines)
    - test/fixtures/install_golden/STDOUT.txt
    - test/fixtures/install_golden/tree/ (41 files)
  modified: []  # lib/mix/tasks/sigra.install.ex DELIBERATELY UNCHANGED

key-decisions:
  - "Bespoke harness over Mneme/snapshy per RESEARCH.md: Mneme snapshots per-assertion not file trees; snapshy is unmaintained. String.myers_difference/2 is the rendering primitive."
  - "Baseline-diff tree capture instead of whole-tree walk: eliminates need to normalize every phx.new generated file and keeps the fixture focused on installer-owned surface."
  - "Pre-compile deps before sigra.install run: ensures captured STDOUT only contains installer output, not dep compile noise from _build cache miss variance."
  - "Normalize /private-prefixed tmp paths (macOS symlink artifact) and scrub signing_salt/secret_key_base/live_view salt in config/*.exs (Phoenix-generated randomness)."
  - "Fixture captured with --live default + no --api/--jwt flags — matches RESEARCH.md recommendation to snapshot the default code path."

patterns-established:
  - "Regression barrier first: the harness + fixture land BEFORE any refactor commits so every subsequent commit is gated against byte-identity."
  - "Clear runbook-pointer error when fixture is missing: test raises with explicit regeneration instructions rather than cryptic assertion failure."

metrics:
  duration: ~45 minutes (including 3 iterative captures to tune normalization)
  completed_date: 2026-04-11
---

# Phase 11 Plan 01: Golden-Diff Harness + Pre-Refactor Snapshot Summary

Bespoke ExUnit harness that runs `mix sigra.install --yes` against a fresh `mix phx.new` tmp app, compares the resulting file tree and captured stdout against a committed golden fixture, and fails loudly on any byte-level drift — landed BEFORE any Phase 11 refactor work begins so every subsequent wave's commits are mechanically gated against the pre-refactor behavior.

## Scope

Three artifacts, three atomic commits, zero modifications to the installer itself:

1. **`test/support/install_fixture.ex`** — tmp-app scaffolding helper
2. **`test/sigra/install/golden_diff_test.exs`** — the regression barrier test
3. **`test/fixtures/install_golden/`** — committed pre-refactor snapshot

## Task Breakdown

### Task 1: `InstallFixture` helper
**Commit:** `e6c94c4`

Created `test/support/install_fixture.ex` exposing:
- `setup_tmp_app/1` — builds a fresh Phoenix app via `mix phx.new --no-assets --no-mailer --no-install`, patches its `mix.exs` to point `{:sigra, path: ...}` at the in-tree repo, runs `mix deps.get`, pre-compiles deps, snapshots the baseline tree, then runs `mix sigra.install Accounts User users --yes` and returns `{:ok, %{app_dir, stdout, baseline_paths}}`.
- `normalize_tree/2` — walks `lib/`, `priv/repo/migrations/`, `config/`, `test/support/` under the app_dir, filters out files byte-identical to the baseline (so only sigra.install-touched files remain), normalizes migration filename timestamps, and applies config-file content normalization.
- `normalize_stdout/2` — strips ANSI, replaces absolute app_dir paths (including macOS `/private` variant) with `<APP>`, replaces migration timestamps, and filters dep compile noise lines.
- `snapshot_paths/1` — produces a `%{rel_path => sha256_hash}` map used by `normalize_tree/2` to compute the installer delta.

### Task 2: Golden-diff test harness
**Commit:** `99e81e7`

Created `test/sigra/install/golden_diff_test.exs` with two tests:
- "generated tree matches committed fixture byte-for-byte (migration filenames normalized)"
- "captured stdout matches committed STDOUT.txt after normalization"

The `setup_all` callback enforces fixture presence via `ensure_fixture_present!/0`: if `test/fixtures/install_golden/tree/` is missing, empty, or `STDOUT.txt` is missing, the test raises a `RuntimeError` containing an explicit runbook pointer to this SUMMARY file. This prevents cryptic assertion failures when the fixture is out of date and gives future maintainers a clear remediation path.

Tests are tagged `:golden` and `:integration` with a 300s timeout (accommodating `mix phx.new` + `mix deps.get` + `mix compile` + `mix sigra.install`). Per-file diff rendering uses `String.myers_difference/2`.

### Task 3: Fixture capture + harness refinement
**Commits:** `3aa1fed`, `e21bc85`

Three iterations of capture-run-fail-normalize converged on:
- **41 delta files** under `tree/` (filtered from ~65 tracked files via baseline diff)
- **STDOUT.txt** 3.5KB of normalized installer output

Normalization refinements captured in `3aa1fed`:
- Pre-compile deps before `sigra.install` so stdout only shows installer output, not `==> phoenix / Compiling 74 files` noise.
- Filter dep compile lines from captured stdout as a belt-and-braces measure.
- Normalize Phoenix-generated `signing_salt`, `secret_key_base`, and `live_view` salt in `config/*.exs` files to deterministic placeholders.
- Handle macOS `/private`-prefixed variant of tmp paths.
- Baseline-diff capture so random files phx.new writes (LICENSE, mix.lock, asset manifests, etc.) do not appear in the fixture.

Final capture committed in `e21bc85`.

## Verification

Final green run:

```
$ mix test test/sigra/install/golden_diff_test.exs
..
Finished in 41.1 seconds (0.00s async, 41.1s sync)
2 tests, 0 failures
```

Install task integrity (per plan's hard constraint):

```
$ git diff 877d4ef..HEAD -- lib/mix/tasks/sigra.install.ex
(empty)
```

Fixture count:

```
$ find test/fixtures/install_golden -type f | wc -l
42   # 41 tree files + STDOUT.txt
```

## Deviations from Plan

### File Count Threshold (Spec Mismatch)

**Issue:** Plan success criterion stated "fixture contains >= 45 files + STDOUT.txt". Actual capture produced **41 delta files + STDOUT.txt = 42 files**.

**Root cause:** The installer has 45 EEx templates, but four of them (`api_token_controller.ex`, `api_token_created_email.ex`, `api_token_migration.exs`, `token_controller.ex`) are only rendered under `--api`/`--jwt` flags. The plan captures the `--live` default code path per RESEARCH.md Q3 recommendation ("Phase 11 snapshots `--live` only"), so those four templates legitimately do not participate. Hitting 45 would require also passing `--api --jwt`, which expands scope beyond the intended default-path snapshot.

**Resolution:** The functional requirement ("capture every file sigra.install touches on the --live default path") is fully satisfied. The 45 threshold in the success-criteria copy was an over-estimate. Noted here so future Phase 18/22 work can either (a) add `--api --jwt` variants as additional golden fixtures or (b) keep the current default-path snapshot and add combinatorial coverage via compile-check smokes (the research doc's recommendation).

### [Rule 2 - Missing critical functionality] Delta-based tree capture

**Found during:** First fixture capture produced byte-level differences in `config/config.exs` because Phoenix generates random `signing_salt`/`secret_key_base` values per `mix phx.new` run. The original plan spec said "walk the tree" without addressing this Phoenix-side nondeterminism.

**Fix:** Added `snapshot_paths/1` baseline capture before `sigra.install` runs, then filtered the post-install walk against that baseline so only installer-touched files enter the fixture. Additionally added `normalize_content/2` that replaces Phoenix-generated random salts in `config/*.exs` with deterministic placeholders (because sigra.install *modifies* config.exs by appending, so it appears in the delta but carries the random upstream content).

**Files modified:** `test/support/install_fixture.ex`, `test/sigra/install/golden_diff_test.exs`
**Commit:** `3aa1fed`

### [Rule 2 - Missing critical functionality] Dep compile noise filtering

**Found during:** First STDOUT capture contained ~100 lines of dep compilation noise (`==> mime`, `Compiling 74 files`, `cc -g -O3 ...` for argon2_elixir NIF, etc.) which varied between runs depending on `_build` cache state.

**Fix:** (a) Pre-compile deps before `sigra.install` so its stdout only contains installer output, (b) add a `dep_compile_noise?/1` filter in `normalize_stdout/2` as a safety net for any compile lines that still leak through, (c) strip macOS `/private`-prefixed tmp path variants in addition to the plain `app_dir`.

**Files modified:** `test/support/install_fixture.ex`
**Commit:** `3aa1fed`

## Known Stubs

None. All harness functions are fully implemented. The fixture is fully populated.

## Threat Flags

None. Phase 11 is a pure testing infrastructure plan. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `test/support/install_fixture.ex`: FOUND
- `test/sigra/install/golden_diff_test.exs`: FOUND
- `test/fixtures/install_golden/STDOUT.txt`: FOUND
- `test/fixtures/install_golden/tree/` with 41 files: FOUND
- Commit `e6c94c4` (helper): FOUND
- Commit `99e81e7` (harness): FOUND
- Commit `3aa1fed` (normalization refinement): FOUND
- Commit `e21bc85` (fixture): FOUND
- `mix test test/sigra/install/golden_diff_test.exs` exits 0: VERIFIED (2 tests, 0 failures, 41.1s)
- `lib/mix/tasks/sigra.install.ex` unmodified since pre-plan state: VERIFIED
