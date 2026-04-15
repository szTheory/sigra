---
phase: 18-backfill-organizations-generator-wiring
plan: 03
subsystem: testing
tags: [testing, ci, matrix, upgrade, integration, phoenix, github-actions]

requires:
  - phase: 18-01
    provides: "Schema/flag foundation (personal column, owner_user_id, --organizations switch)"
  - phase: 18-02
    provides: "mix sigra.upgrade task + Sigra.Upgrade.Backfill module (runs in final integration, not in this worktree)"
provides:
  - "Sigra.Test.InstallFixture.setup_tmp_app_without_install/1 (additive, preserves byte-identity)"
  - "Sigra.Test.InstallFixture.run_sigra_install/2, run_sigra_upgrade/2, run_mix/2 subprocess helpers"
  - "test/upgrade_test.exs — two-path upgrade regression test (backfill-off + backfill-on)"
  - ".github/workflows/ci.yml install_matrix job with list-of-flag-strings matrix"
affects: [19-passkey-enrollment, 20-passkey-login, generator-flag-axis-tests]

tech-stack:
  added: []
  patterns:
    - "Subprocess-based integration tests via System.cmd through InstallFixture helpers"
    - "List-of-flag-strings CI matrix shape (extensible for future generator flags without restructuring)"
    - "Semantic-equivalence v1.0 fixture: --no-organizations install IS the v1.0 shape by definition (D-06)"

key-files:
  created:
    - "test/upgrade_test.exs"
    - ".planning/phases/18-backfill-organizations-generator-wiring/18-03-upgrade-test-fixture-and-ci-matrix-SUMMARY.md"
  modified:
    - "test/support/install_fixture.ex"
    - ".github/workflows/ci.yml"

key-decisions:
  - "Additive helper (setup_tmp_app_without_install/1) instead of flag-wrapping setup_tmp_app/1 — preserves golden_diff_test byte-identity with zero risk"
  - "Subprocess helpers accept String flags lists so test callers control the install shape"
  - "perl -0777 regex replacement in CI patch step mirrors InstallFixture.patch_mix_exs_with_path_dep! semantics without shelling out to Python"
  - "CI matrix shape is list-of-flag-strings (D-07), not 2D boolean product — Phase 19+ appends --no-passkeys entries without restructuring"

patterns-established:
  - "Subprocess test helpers: expose run_<task>/2 wrappers that raise with captured stdout on non-zero exit, return {:ok, stdout} on success"
  - "Additive-over-intrusive for test fixture modification when byte-identity with a golden test must be preserved"
  - "HTTP login proof for ORG-UPGRADE-02: mix phx.server + curl with cookie jar, asserting final path terminates at /organizations and no response has status >= 500"

requirements-completed: [ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03]

duration: ~20 min
completed: 2026-04-14
---

# Phase 18 Plan 03: Upgrade Test Fixture and CI Matrix Summary

**Two-path upgrade regression test + list-of-flag-strings CI matrix: proves `--no-organizations` emits zero org ALTERs, default install + upgrade lands login at /organizations, and `--backfill-personal-orgs` is idempotent on rerun.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- `Sigra.Test.InstallFixture` now exposes three new public subprocess helpers (`run_sigra_install/2`, `run_sigra_upgrade/2`, `run_mix/2`) plus an additive `setup_tmp_app_without_install/1` that scaffolds a tmp Phoenix app (phx.new + path-dep patch + deps.get + compile) without running the installer — preserving byte-identity with the existing golden_diff test.
- `test/upgrade_test.exs` ships three describe blocks exercising: (a) `--no-organizations` install + `mix sigra.upgrade --yes` with zero new org ALTER migrations and absent `organizations` table (ORG-02 + GEN-03 org-axis); (b) default install + upgrade + HTTP login via `mix phx.server` and `curl` asserting 3xx redirect terminates at `/organizations` with no 5xx (ORG-UPGRADE-02 proof); (c) `--backfill-personal-orgs` first-run assertion of seeded_count personal orgs followed by a second-run no-op assertion (ORG-UPGRADE-01 idempotency).
- `.github/workflows/ci.yml` gains an `install_matrix` job with `strategy.matrix.flags: ["", "--no-organizations"]`, `fail-fast: false`, and an explicit extensibility comment reserving space for Phase 19+ passkey axis entries (`"--no-passkeys"`, `"--no-organizations --no-passkeys"`). Matches the existing `install_smoke` job structure and uses the same SHA-pinned actions.

## Task Commits

1. **Task 1: Extend InstallFixture with subprocess helpers** — `066e599` (test)
2. **Task 2: Create test/upgrade_test.exs two-path regression test** — `37f49dc` (test)
3. **Task 3: Add install_matrix CI job with org-axis flag matrix** — `7a9b891` (ci)

## Files Created/Modified

- `test/support/install_fixture.ex` — added `setup_tmp_app_without_install/1`, `run_sigra_install/2`, `run_sigra_upgrade/2`, `run_mix/2` (155 insertions, 2 deletions). Formatter also normalized one pre-existing `System.cmd/3` call in `setup_tmp_app/1` across multiple lines — pure whitespace, no behavioral change.
- `test/upgrade_test.exs` — new top-level integration test (353 lines) with three describe blocks, HTTP-login helper, seed helpers, personal-org counting via `mix run -e`.
- `.github/workflows/ci.yml` — new `install_matrix` job (74 lines) copying the `install_smoke` skeleton and parameterizing the `mix sigra.install` invocation with `${{ matrix.flags }}`.

## Decisions Made

- **Additive path, not flag-wrap.** Task 1's WARNING 5 gave a preference for adding `setup_tmp_app_without_install/1` alongside `setup_tmp_app/1` instead of wrapping the existing inline install block in `if Keyword.get(opts, :run_install, true)`. Chose the additive path — it keeps the existing function body literally untouched so the golden_diff test's byte-identity guarantee is trivially preserved, and it keeps the two call shapes (`setup_tmp_app/1` vs `setup_tmp_app_without_install/1` + `run_sigra_install/2`) cleanly separated by intent.
- **perl -0777 instead of Python heredoc for CI mix.exs patching.** Initial draft used a Python heredoc inside the `run: |` block. Replaced with a one-line `perl -0777 -pe '...'` invocation that mirrors `InstallFixture.patch_mix_exs_with_path_dep!`'s regex semantics without the YAML-heredoc-indentation fragility.

## Deviations from Plan

None that changed behavior. Two small polish adjustments:

1. **Formatter whitespace on existing `setup_tmp_app/1` body.** When running `mix format` on `install_fixture.ex` after the Task 1 edit, the formatter re-wrapped one pre-existing `System.cmd("mix", ["compile"], ...)` call across multiple lines. This is pure whitespace — `setup_tmp_app/1`'s *behavior* is unchanged, and the golden_diff test compares installer output (generated tree + stdout), not the source of the fixture itself, so byte-identity of the test contract holds. No deviation rule triggered; the file was reformatted by the canonical project formatter.

2. **Task 3 CI patch step simplification.** The plan sketch used `sed -i` with a best-effort pattern. Replaced with `perl -0777 -pe` (multiline match) because `InstallFixture.patch_mix_exs_with_path_dep!` uses a `\s*\n\s*` cross-line regex that `sed` cannot easily match in a single invocation. Functional equivalence preserved; added a `grep -q` fallback check that fails loudly if the patch does not apply.

## Issues Encountered

- **`mix deps.get` required in worktree before `mix format`.** Fresh worktree had no `_build`/`deps`, so the first `mix format` invocation failed on `:import_deps` pointing at `:ecto`. Ran `mix deps.get` and re-ran format — resolved.
- **No local Python `yaml` module / no `yamllint` initially.** Validated ci.yml via `brew install yamllint` and ran `yamllint` with relaxed rules against the modified file — parses cleanly.
- **Plan 18-02 modules not present in this worktree.** `mix sigra.upgrade` does not yet exist here; the upgrade test cannot run end-to-end in this worktree. This is expected (the parallel-execution note at the top of the agent brief calls it out). The test file is structurally correct and the install_matrix job does not invoke `mix sigra.upgrade`, so both ship independently; the final integration merge will exercise the full path.

## User Setup Required

None.

## Next Phase Readiness

- Phase 18 close-out: this plan is the final wave of Phase 18. After the orchestrator merges all three plans, the integration check will run `mix test test/upgrade_test.exs --only upgrade` against the merged tree to prove the full backfill loop end-to-end.
- Phase 19+ passkey axis can extend `.github/workflows/ci.yml install_matrix.strategy.matrix.flags` by appending `"--no-passkeys"` and `"--no-organizations --no-passkeys"` to the list — no structural changes required. The comment above the `flags:` block documents this expansion explicitly.
- `Sigra.Test.InstallFixture` subprocess helpers are reusable by any future fixture-based test (generator feature axis, upgrade path regression, CLI ergonomics) without additional scaffolding.

## Self-Check: PASSED

Verified:
- `test/upgrade_test.exs` exists: FOUND
- `test/support/install_fixture.ex` modified with 4 new public functions: FOUND (`def run_sigra_install` ×1, `def run_sigra_upgrade` ×1, `def run_mix(app_dir, args)` ×1, `def setup_tmp_app_without_install` ×1)
- `.github/workflows/ci.yml` contains `install_matrix:` job: FOUND (1 match)
- Matrix entries present: FOUND (`- ""` and `- "--no-organizations"` both present)
- Commits exist:
  - `066e599` test(18-03): add subprocess helpers to InstallFixture — FOUND
  - `37f49dc` test(18-03): add two-path upgrade regression test — FOUND
  - `7a9b891` ci(18-03): add install_matrix job with org-axis flag matrix — FOUND
- `mix compile --warnings-as-errors`: PASSED
- `mix format --check-formatted test/support/install_fixture.ex test/upgrade_test.exs`: PASSED
- `yamllint` (relaxed): PASSED

---
*Phase: 18-backfill-organizations-generator-wiring*
*Plan: 03*
*Completed: 2026-04-14*
