---
phase: 31-automation-first-verification
fixed_at: 2026-04-16T00:00:00Z
review_path: .planning/phases/31-automation-first-verification/31-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 31: Code Review Fix Report

**Fixed at:** 2026-04-16
**Source review:** `.planning/phases/31-automation-first-verification/31-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (Critical + Warning only)
- Fixed: 4
- Skipped: 0
- Info findings (IN-01 through IN-06) deferred by scope; see REVIEW.md for details.

All four warnings were in `.github/workflows/ci.yml`. Each fix was applied in isolation, verified with `python3 -c 'import yaml; yaml.safe_load(...)'`, and committed atomically.

## Fixed Issues

### WR-01: GitHub Actions workflow has no `permissions:` block

**Files modified:** `.github/workflows/ci.yml`
**Commit:** `66e0c94`
**Applied fix:** Added a top-level `permissions: { contents: read }` block with a 4-line comment explaining the least-privilege rationale and noting that jobs needing more scope must opt in explicitly. No per-job overrides were required since every current job only reads the repo and uploads artifacts.

### WR-02: `${{ matrix.flags }}` interpolated directly into `run:` shell command

**Files modified:** `.github/workflows/ci.yml`
**Commit:** `13622fe`
**Applied fix:** Moved `${{ matrix.flags }}` into the step's `env:` block as `MATRIX_FLAGS` and switched the `run:` line to reference `$MATRIX_FLAGS`. Preserved the intentional unquoted word-splitting (for multi-flag values) with an inline `# shellcheck disable=SC2086` justification. Added a comment tying the change to GitHub's "Security hardening for GitHub Actions" guidance so future maintainers understand why the indirection matters.

### WR-03: `find -exec cp` silently overwrites on basename collisions

**Files modified:** `.github/workflows/ci.yml`
**Commit:** `5c07176`
**Applied fix:** Both admin-checkpoint collection blocks (`example_playwright_smoke` ~line 569 and `generated_admin_playwright_smoke` ~line 688) now:
1. Count matching source PNGs with `find … | wc -l` and echo the count to the step log before copying.
2. Use `cp -n` (no-clobber) so basename collisions surface as cp warnings rather than silent overwrites.
Paired with the existing `ls -la artifacts/admin-checkpoints/` tail, reviewers can now eyeball source-count vs collected-count from the step log.

### WR-04: `example_playwright_smoke` backgrounds the example app with no log capture

**Files modified:** `.github/workflows/ci.yml`
**Commit:** `8d9a6b0`
**Applied fix:** The same pattern was applied to both backgrounded `mix phx.server` invocations:
- `example_http_smoke`: boot redirects to `/tmp/example-http-server.log`; new `if: failure()` step dumps the log immediately after the HTTP smoke step.
- `example_playwright_smoke`: boot redirects to `/tmp/example-playwright-server.log`; new `if: failure()` dump step inserted right after the final Playwright test step (before curated screenshot collection), so CI failure investigation doesn't require pulling the retained-video artifact first.
Both new blocks reference `install_matrix:291` and `admin-acceptance-smoke.sh:207` in inline comments, pointing future contributors at the canonical pattern that already existed elsewhere in the repo.

## Skipped Issues

None — all four in-scope warnings were fixed successfully.

## Verification

- After each edit, ran `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'` — YAML parsed cleanly on every iteration.
- Each commit contains only `.github/workflows/ci.yml`; no pre-existing dirty files from other phases were swept in.
- Pre-commit hooks ran successfully on all four commits (no `--no-verify` bypass used).
- No `mix test` run was required — all changes are CI workflow configuration (no Elixir source touched).

---

_Fixed: 2026-04-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
