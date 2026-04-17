---
phase: 31-automation-first-verification
fixed_at: 2026-04-16T00:00:00Z
review_path: .planning/phases/31-automation-first-verification/31-REVIEW.md
iteration: 2
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 31: Code Review Fix Report (iteration 2)

**Fixed at:** 2026-04-16
**Source review:** `.planning/phases/31-automation-first-verification/31-REVIEW.md`
**Iteration:** 2

## Summary

- Findings in scope: **6** (IN-01..IN-06)
- Fixed: **6**
- Skipped: **0**

All six Info items carried forward from iteration 1's 31-REVIEW.md are
now resolved. No findings were skipped. The four Warnings from
iteration 1 (WR-01..WR-04) were already resolved by commits 66e0c94,
13622fe, 5c07176, and 8d9a6b0 and are NOT re-fixed here — iteration 2
focused exclusively on the Info findings.

## Delta vs iteration 1

| Finding | Iter 1 status | Iter 2 action |
|---------|---------------|---------------|
| WR-01   | Fixed (66e0c94) | No change — verified already resolved |
| WR-02   | Fixed (13622fe) | No change — verified already resolved |
| WR-03   | Fixed (5c07176) | No change — verified already resolved |
| WR-04   | Fixed (8d9a6b0) | No change — verified already resolved |
| IN-01   | Open | Fixed this pass |
| IN-02   | Open | Fixed this pass |
| IN-03   | Open | Fixed this pass |
| IN-04   | Open | Fixed this pass |
| IN-05   | Open | Fixed this pass |
| IN-06   | Open | Fixed this pass |

## Fixed Issues

### IN-01: Fixed `/tmp` path for admin-acceptance seed file

**Files modified:** `scripts/ci/admin-acceptance-smoke.sh`
**Commit:** `e81d2b0`
**Applied fix:** Introduced `SEED_FILE="${TMP_APP_DIR}/sigra_admin_acceptance_seed.exs"`
and routed both the heredoc `cat` and the `mix run` invocation through
the per-run path. Concurrent local runs no longer collide on
`/tmp/sigra_admin_acceptance_seed.exs`.

### IN-02: Test-only credentials lack "test-only" markers

**Files modified:**
- `scripts/ci/admin-acceptance-smoke.sh`
- `test/example/priv/playwright/helpers/fixtures.ts` (new file)
- `test/example/priv/playwright/tests/admin-audit.spec.ts`
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts`
- `test/example/priv/playwright/tests/impersonation.spec.ts`
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`
- `test/example/priv/playwright/tests/admin-generated.spec.ts`

**Commit:** `e3d31ce`
**Applied fix:** (a) Added explicit `# test-only: …` comments above the
Cloak key and admin password defaults in the smoke script. (b) Created
`helpers/fixtures.ts` exporting `TEST_PASSWORD` with a "test-only"
rationale block comment, and imported it in each of the five
admin-scoped specs (four admin-* specs plus admin-generated),
replacing the inline `'CorrectHorseBatteryStaple123!'` literal.
Out-of-scope specs (golden-path, organizations, passkey-*) were
intentionally left alone per iteration-2 guidance.

### IN-03: Magic `+ 4` in http-smoke.sh pass-summary math

**Files modified:** `scripts/ci/http-smoke.sh`
**Commit:** `ddd4526`
**Applied fix:** Introduced `EXTRA_CHECKS=0` and incremented it at each
of the four non-array probes (cookie warmup, cookie presence, cookie
reuse, admin denial). The summary line now uses
`${#PUBLIC_ROUTES[@]} + ${#ADMIN_ROUTES_UNAUTH[@]} + EXTRA_CHECKS`, so
future edits to the probe set auto-update the count.

### IN-04: `impersonation_token_for/2` accepts-but-ignores its `_admin` arg

**Files modified:** `test/example/test/example_web/controllers/impersonation_controller_test.exs`
**Commit:** `0868af8`
**Applied fix:** Renamed helper to `impersonation_token_for/1` and
removed the trailing `_admin` parameter. Updated both call sites (lines
83 and 114) to pass only the target user. Did NOT attempt to persist
the impersonator relationship — that would require a schema change
outside the scope of this review.

### IN-05: CSV assertion on header name `organization_label` is tautological

**Files modified:** `test/example/priv/playwright/tests/admin-audit.spec.ts`
**Commit:** `8e009c0`
**Applied fix:** Replaced `expect(scopedCsv).toContain('organization_label')`
with `expect(scopedCsv).toContain(orgName)`. The `orgName` variable is
in scope at the assertion site (declared at the top of the same
`test(...)` callback). Added a comment explaining the header-vs-row
distinction so a future reader does not regress it.

### IN-06: Playwright specs use `page.locator('form').first()` instead of a stable id

**Files modified:**
- `test/example/priv/playwright/tests/admin-audit.spec.ts`
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts`
- `test/example/priv/playwright/tests/impersonation.spec.ts`
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`

**Commit:** `1968ebc`
**Applied fix:** Replaced `page.locator('form').first()` with
`page.locator('form:has(input[name="user[password]"])').first()` inside
the registration helper of all four admin-scoped specs. No template
change required — the selector tightens purely client-side so the
registration form is identified by its password input field rather
than by being first on the page.

## Skipped Issues

_None — all six in-scope findings were fixed._

## Verification notes

- `bash -n` passed on the two modified shell scripts
  (`scripts/ci/admin-acceptance-smoke.sh`, `scripts/ci/http-smoke.sh`).
- `elixir Code.string_to_quoted!` parsed the modified impersonation
  controller test file successfully; `mix format --check-formatted`
  reports clean.
- Playwright specs could not be type-checked in isolation
  (`tsconfig.json` is intentionally absent from `priv/playwright` — the
  Playwright test runner supplies its own TS loader). Verification
  relied on Tier 1 (re-read) plus targeted ripgrep scans to confirm
  selector/import replacements and to confirm no remaining literal
  `CorrectHorseBatteryStaple123!` in the five in-scope specs.

---

_Fixed: 2026-04-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
