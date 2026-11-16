---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 06
subsystem: testing
tags: [installer, byte-parity, golden, determinism, scaffold, ci-install-golden, bgen-01, bgen-02]

requires:
  - phase: 260
    provides: "Plan 05 immutable before catalog (this plan changes no shipped byte, so the before still reads as captured)"
provides:
  - "Sigra.Install.AssetParityTest: one table classifying all 8 .css/.svg/.js template assets, with a completeness check and planted controls"
  - "Example sigra_auth.css refreshed to byte equality with the installer template (was 13,867 B against 32,072 B)"
  - "Sigra.Install.DoubleInstallTest: two fresh installs have equal normalized trees and stdout, and a raw installer delta confined to migration filenames and config/ salts"
  - "ci.install_golden lists the double-install file; the new scaffold test is proven to execute inside the alias"
affects: [260-09, 260-10, 260-11, 262]

actuals:
  tokens: 13625
  tasks: 3
  commits: 3

plan_head_before: ad878767f0766a1583b0ff1cded6f749f340d516
plan_head_after: c40a376941508a4bfeaad8a32cd4cddf64ad7b24

tech-stack:
  added: []
  patterns:
    - "Asset table with three relations (byte_identical, documented_divergence, injected_snippet) and a completeness function over the on-disk file set"
    - "Shrink-only guard for a documented divergence: must-have markers in both copies, a ceiling on template-only lines, and only-in-one-side markers that keep the reason string honest"
    - "Planted controls for pure helpers live in a second, non-scaffold module in the same file so they run under plain mix test --exclude scaffold"
    - "Raw determinism leg compares the installer delta (hash differs from the pre-install baseline), never the whole tree"

key-files:
  created:
    - test/sigra/install/asset_parity_test.exs
    - test/sigra/install/double_install_test.exs
  modified:
    - test/example/priv/static/assets/sigra_auth.css
    - mix.exs
    - test/support/ci/library_test_partitions.exs
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-deferred-items.md

key-decisions:
  - "The literal 'template lines are a subset of example lines' guard for admin_hooks.js does not hold (5 non-blank template lines differ), so the guard is the plan's fallback (the marker pairs installer_drift_test.exs pins as fixes 20, 21 and 22) plus a shrink-only ceiling of 5 template-only lines"
  - "Each documented-divergence reason is kept true by only-in-template and only-in-example markers, so a stale reason fails instead of silently outliving the difference"
  - "Pure helpers (compare_trees/2, raw_differences/2, allowed_raw_path?/1) are public in the scaffold module and exercised by a second module with no :scaffold tag, because ci.install_golden is the only receiver of scaffold-tagged files"
  - "Completeness controls start from the files on disk, never from the real table, so they stay able to fail whatever the table says"

patterns-established:
  - "Failure messages name the exact resync command: cp template example for the example copy, mix sigra.fixture.rebless_golden for the golden copy"
  - "A red run of a completeness guard is produced on the real tree by omitting one row, then restored, before any planted control is trusted"

requirements-completed: [BGEN-01, BGEN-02]

coverage:
  - id: D1
    description: "All 8 .css/.svg/.js files under priv/templates/sigra.install/ are classified in one table; an unclassified file, a stale row or a duplicate fails; the table was seen red on the real tree (injected-snippet row omitted) and four planted controls report an extra file, an omitted file, a stale row and a duplicate"
    requirement: BGEN-01
    verification:
      - kind: unit
        ref: "test/sigra/install/asset_parity_test.exs#completeness (6 tests)"
        status: pass
      - kind: other
        ref: "find priv/templates/sigra.install \\( -name '*.css' -o -name '*.svg' -o -name '*.js' \\) returns 8 files; the red run named priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js as unclassified"
        status: pass
    human_judgment: false
  - id: D2
    description: "The stale example sigra_auth.css was caught red (first differing byte 172, 32,072 B template against 13,867 B example) and refreshed by byte copy; template, example and golden copies of sigra_admin.css, sigra_auth.css and both logos are byte-identical, and passkey_hooks.js template equals the example"
    requirement: BGEN-01
    verification:
      - kind: unit
        ref: "test/sigra/install/asset_parity_test.exs#byte-identical assets (10 tests: 5 example comparisons, 4 golden comparisons, sigra_auth counterpart check)"
        status: pass
      - kind: other
        ref: "cmp -s priv/templates/sigra.install/core/sigra_auth.css test/example/priv/static/assets/sigra_auth.css exits 0; git diff --stat shows only that asset changed"
        status: pass
    human_judgment: false
  - id: D3
    description: "The two documented divergences (admin_hooks.js, passkey_browser.js) carry a reason string and a shrink-only guard; each guard was shown able to fail by mutating the real example copy and restoring it"
    requirement: BGEN-01
    verification:
      - kind: unit
        ref: "test/sigra/install/asset_parity_test.exs#documented divergences (5 tests plus 2 pure ceiling controls)"
        status: pass
      - kind: other
        ref: "mutation run: appended byte to example sigra_admin.css, deleted installFieldHelp( from example admin_hooks.js, renamed attachPasskeyLogin( in example passkey_browser.js; 4 tests failed, files restored, git status clean"
        status: pass
    human_judgment: false
  - id: D4
    description: "Two fresh installs have identical normalized trees and stdout, and the raw installer delta differs only under priv/repo/migrations/ and config/ (observed: config/config.exs, config/dev.exs, config/test.exs and 18 migration filenames across two timestamp sets; nothing under lib/)"
    requirement: BGEN-02
    verification:
      - kind: integration
        ref: "test/sigra/install/double_install_test.exs#two fresh installs (4 tests, :scaffold)"
        status: pass
      - kind: unit
        ref: "test/sigra/install/double_install_test.exs Sigra.Install.DoubleInstallControlsTest (10 tests, runs under mix test --exclude scaffold)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The new scaffold test executes inside mix ci.install_golden: a deliberately failing assertion failed through the alias (34 tests, 1 failure, exit 2), was removed, and the alias is green with the file included (33 tests, 0 failures); the phase 233 contract test that cross-checks the scaffold path lists is green"
    requirement: BGEN-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix ci.install_golden (probe run exit 2, final run exit 0); mix test test/sigra/planning/phase_233_library_economics_contract_test.exs (6 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D6
    description: "mix sigra.fixture.rebless_golden --check is clean under phx_new 1.8.8 and the golden fixture is untouched by this plan"
    requirement: BGEN-02
    verification:
      - kind: other
        ref: "MIX_ENV=test mix sigra.fixture.rebless_golden --check printed 'OK: fixture is up-to-date (check mode).'; git status --porcelain -- test/fixtures/install_golden is empty"
        status: pass
    human_judgment: false
  - id: D7
    description: "Pixel consequence of the refreshed example sigra_auth.css on the example home page (its auth preview block links the stylesheet)"
    requirement: BGEN-01
    verification: []
    human_judgment: true
    rationale: "The example suite (419 tests, 0 failures) asserts no pixels and no PNG is recaptured locally. Whether the refresh moves the home page is decided by the PR example Playwright lanes (PNG comparison is parked on the PR path by plans 01 and 04), not by a local assertion."

duration: 24min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 06: Asset Parity and Double Install Summary

**A byte-parity table that classifies all 8 installer-template assets (caught the example `sigra_auth.css` 18,205 bytes short, red first, then refreshed) and a two-fresh-installs proof that agrees after normalization and differs raw only in migration filenames and config salts, wired into `mix ci.install_golden` at about one minute of shard cost.**

## Performance

- **Duration:** 24 min (start 2026-11-15T19:32:09Z), most of it waiting on five scaffold-heavy runs
- **Tasks:** 3 (Task 1 tracer, Tasks 2 and 3 auto, tdd)
- **Files:** 2 created, 3 modified plus the phase deferral log; nothing under `lib/`, `priv/`, the golden fixture or the before catalog

## Accomplishments

- **BGEN-01 guard, seen red first.** `Sigra.Install.AssetParityTest` compared the template `core/sigra_auth.css` with the example copy and failed: first differing byte 172, 32,072 bytes against 13,867. The failure message names the resync command. The refresh was then a byte copy and the test went green. The example suite after the refresh: 419 tests, 0 failures.
- **No asset can escape the table.** All 8 `.css/.svg/.js` files are classified (5 `byte_identical`, 2 `documented_divergence`, 1 `injected_snippet`). With the injected-snippet row deliberately omitted, the completeness test named `passkeys/app_js_passkeys_injection.js` as unclassified on the real tree; the row was restored.
- **Golden counterparts are checked.** `sigra_admin.css`, `sigra_auth.css` and both logos are compared template to example and template to golden; `passkey_hooks.js` template to example. The golden failure message names `mix sigra.fixture.rebless_golden`.
- **Divergences are bounded, not waved through.** `admin_hooks.js` (example superset: demo chips, password fill, persona switch) and `passkey_browser.js` (template imports `@simplewebauthn/browser`, example inlines the helpers) each have a reason, must-have markers in both copies and markers that keep the reason true. Each guard failed when the real example copy was mutated.
- **BGEN-02 proof.** Two independent installs: equal normalized trees, equal normalized stdout, and a raw installer delta whose only differences are `config/config.exs`, `config/dev.exs`, `config/test.exs` and 18 migration filenames (two timestamp sets of nine). Nothing under `lib/` differs, so the `endpoint.ex` salt trap (it is not in the delta) is avoided. A non-vacuity assertion fails if the raw leg sees no variance at all.
- **It runs in CI.** The file is listed in `ci.install_golden`; a deliberately failing assertion failed through the alias, then was removed.

## Shard budget (`Library tests shard`, 20-minute ceiling)

`mix ci` runs `ci.install_golden` inside the shard. Wall clock, same machine, warm cache:

| Run | Wall clock | ExUnit time | Tests |
| --- | --- | --- | --- |
| `ci.install_golden` without the new file (baseline) | 298 s | 296.5 s | 19, 0 failures |
| `ci.install_golden` with the file and the failing probe | 349 s | n/a | 34, 1 failure (the probe) |
| `ci.install_golden` with the file, final | 301 s | 299.8 s | 33, 0 failures |
| the new file alone (`mix test test/sigra/install/double_install_test.exs`) | 61 s | 60.1 s | 14, 0 failures |

The measured delta across alias runs is 3 s to 51 s; run-to-run noise on the existing scaffold tests is about 50 s, so the cleanest number is the file in isolation: 60 s for two scaffolds. All of it is far under the 4-minute limit (a fifth of the shard ceiling), so the plan did not stop and report.

## Task Commits

1. **Task 1: tracer, parity red on `sigra_auth.css`, planted-byte control, refresh to green** - `d1f0d2ac7` (test)
2. **Task 2: full asset table, completeness check, golden counterparts, documented divergences** - `a5fdd7d60` (test)
3. **Task 3: double-install determinism test, `ci.install_golden` wiring, golden `--check`** - `c40a37694` (test)

**Plan metadata:** docs commit (this SUMMARY, deferral log, STATE, ROADMAP, REQUIREMENTS).

Commit ledger (measured from the persisted base): `plan_head_before` `ad878767f0766a1583b0ff1cded6f749f340d516`, `plan_head_after` `c40a376941508a4bfeaad8a32cd4cddf64ad7b24`, `git rev-list --count` = 3. `actuals.tokens` is characters of added lines over the realized diff divided by 4 (54,500 / 4), against a plan estimate of 60,000; it is not rounded toward the estimate.

## Test-first notes

Task 1 was written test-first: the `sigra_auth.css` test failed with the size evidence before the refresh. Task 2 was written with the full table; its red was produced on the real tree by omitting the injected-snippet row (6 failures, the real completeness test naming the missing file), and that red also exposed two defects in the first draft that were fixed before the green run: the planted completeness controls were coupled to the real table (they now start from the on-disk file set) and a duplicate row was double-counted as stale. Task 3's helpers were written with their planted controls in the same file; the end-to-end wiring red is the failing-assertion run through the alias. ExUnit console output is not a format `gsd_run check tdd-red-evidence` classifies, so the assessment is semantic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The scaffold-path contract test required two edits the plan did not list**
- **Found during:** Task 3, the broad `mix test` leg after wiring the alias
- **Issue:** `test/sigra/planning/phase_233_library_economics_contract_test.exs` requires the `@moduletag :scaffold` file set, the `@scaffold_paths` allow-list in `test/support/ci/library_test_partitions.exs` and the `ci.install_golden` file list to be equal, and compares the alias list in lexical order. Adding the file to the alias alone, and in the order the plan implied, turned that test red (1 failure in 6).
- **Fix:** added `test/sigra/install/double_install_test.exs` to `@scaffold_paths` and placed it first in the alias list (it sorts before `features/`). No other edit.
- **Files modified:** `test/support/ci/library_test_partitions.exs`, `mix.exs` (already in scope)
- **Verification:** contract test 6 tests, 0 failures; `mix ci.install_golden --only describe:"compare_trees/2"` still loads the file through the reordered alias; full `mix test --exclude scaffold` 3094 tests, 0 failures
- **Commit:** `c40a37694`

### Implementation choices that differ from the plan's literal wording

- **admin_hooks.js guard.** The plan allowed the line-subset guard only if it held on the real files; it does not (5 non-blank template lines are absent from the example: two header comment lines, a hint comment and two chip selectors that the example widens). Per the plan's fallback, the guard is the marker pairs `installer_drift_test.exs` pins as fixes 20, 21 and 22, cited in the test. A shrink-only ceiling of 5 template-only lines was added on top, because marker pairs alone are not shrink-only and the truth statement asks for a shrink-only guard.
- **`compare_trees/2` returns a numeric offset.** The plan said to copy `first_mismatch_offset/2` verbatim; that helper returns a formatted string, and the control needs `{:error, path, offset}`. A numeric first-differing-offset function replaces it, with the surrounding bytes rendered only in the failure message.
- **Two modules in one file.** The scaffold tests and the public pure helpers are in `Sigra.Install.DoubleInstallTest`; the controls are in `Sigra.Install.DoubleInstallControlsTest` with no scaffold tag, so they run under `mix test --exclude scaffold`.
- **Temporary instrumentation.** A one-line `IO.puts` of the raw differing paths was added for one alias run to record them here, and removed with the failing probe before the commit.
- **Local gate legs.** `format --check-formatted` (whole repo), `test --exclude scaffold` (3094 tests), `ci.install_golden` (33 tests) and the golden `--check` were run. `deps.get --check-locked`, `compile --warnings-as-errors` and `sigra.dep_off` were not (no dependency, `lib/` or `priv/` change, and `sigra.dep_off` rewrites the dependency state in the shared tree).

**Total deviations:** 1 auto-fixed (Rule 3) plus the choices above. **Impact on plan:** none on scope or acceptance criteria; one extra test-support file edit.

## Issues Encountered

- The first Task 2 run printed a type-checker warning for `assert @table != []` (a literal list against `[]`); replaced with `refute Enum.empty?/1` and a completeness test that asserts the on-disk set is non-empty.
- Shared-tree runs were strictly sequential (the example suite, five alias or scaffold runs, the broad suite), as the phase guardrails require; no run was parallel.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. No endpoint, auth path, file access pattern or schema was added. T-260-15: the byte-parity table has a completeness check and planted controls, and every failure message names the resync command. T-260-16: the new scaffold test is in `ci.install_golden` and in the contract-checked allow-list, and was proven to execute by a failing assertion that was removed.

## Verification Run

| Check | Result |
| --- | --- |
| `source tmp/db.env && mix test test/sigra/install/asset_parity_test.exs` | 30 tests, 0 failures |
| `MIX_ENV=test mix test test/sigra/install/double_install_test.exs` | 14 tests, 0 failures (61 s) |
| `mix test --exclude scaffold test/sigra/install/double_install_test.exs` | 10 tests (controls only), 0 failures |
| `cmp -s` template and example `sigra_auth.css` | exit 0 |
| `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | `OK: fixture is up-to-date (check mode).` |
| `mix format --check-formatted` (whole repo) | exit 0 |
| `mix test --exclude scaffold` | 33 doctests, 3 properties, 3094 tests, 0 failures, 12 skipped |
| `cd test/example && MIX_ENV=test mix test --include example_app` (after the refresh) | 419 tests, 0 failures |
| `git diff <plan base>..HEAD -- lib priv test/fixtures/install_golden test/fixtures/brand/before` | empty |
| `test -z "$(grep -n 'assert false' test/sigra/install/double_install_test.exs)"`; `grep -c double_install_test.exs mix.exs` | passes; 1 |

## Handoff for Plans 09, 10 and 11

- **Plan 09 (the single golden rebless).** Any edit to a template stylesheet or logo now needs three things in step: the template, the example copy (`cp <template> <example>`, named in the failure) and the golden fixture (rebless). The parity test reds until all three agree. `features/admin_test.exs` DIST-05 is untouched and now redundant.
- **Plan 10.** `mix ci` now includes the double-install file, about one minute of shard time (see the table). `.github/workflows/ci.yml` is unchanged; the path-gated `install_golden_contract` job does not run the new file (deferred item 2).
- **Plan 11.** BGEN-01 and BGEN-02 are also declared by plan 11, so the requirements are marked complete only when its SUMMARY exists. The `MAINTAINING.md` sentence about the golden alias is stale (deferred item 1).

## Next Phase Readiness

Ready for plans 07 and 08 (the other wave-3 plans, run sequentially). Nothing here blocks them.

## Self-Check: PASSED

- Created and modified files exist (`[ -f ]`): `asset_parity_test.exs`, `double_install_test.exs`, the refreshed example `sigra_auth.css`, `mix.exs`, `library_test_partitions.exs`, the deferral log and this SUMMARY.
- All three production commits (`d1f0d2ac7`, `a5fdd7d60`, `c40a37694`) are ancestors of HEAD (`git merge-base --is-ancestor`).
- Task 1, 2 and 3 acceptance criteria re-run and passing; plan-level verification re-run after the last production commit.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
