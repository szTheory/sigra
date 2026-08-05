---
phase: 237-canonical-b2c-generator-contract
plan: 01
subsystem: testing
tags: [phoenix, postgresql, oauth, cloak_ecto, generator, smoke-test]
requires: []
provides:
  - "B2C Alpha fresh-host smoke contract covering OAuth output and disabled feature residue"
  - "Fixture contract that generates Google OAuth after adding cloak_ecto"
affects: [b2c-alpha, generator-contracts, ci]
tech-stack:
  added: []
  patterns: [feature-owned negative sentinels, source-locked lifecycle smoke]
key-files:
  created: []
  modified:
    - scripts/ci/passkeys-opt-out-smoke.sh
    - test/sigra/install/generator_passkeys_opt_out_test.exs
key-decisions:
  - "Keep PostgreSQL/assets/root-boot proof exclusively in the authoritative shell smoke."
  - "Use explicit feature-owned paths, migrations, markers, assets, and dependencies instead of broad vocabulary bans."
requirements-completed: [B2C-01, B2C-02, B2C-03]
coverage:
  - id: D1
    description: "B2C smoke checks the canonical disabled-feature command, Google OAuth emission, assets, migration, and root boot stages."
    requirement: B2C-01
    verification:
      - kind: integration
        ref: "scripts/ci/passkeys-opt-out-smoke.sh"
        status: unknown
    human_judgment: false
  - id: D2
    description: "B2C fixture adds cloak_ecto, generates Google OAuth, and checks positive OAuth plus disabled feature surfaces."
    requirement: B2C-02
    verification:
      - kind: unit
        ref: "test/sigra/install/generator_passkeys_opt_out_test.exs"
        status: unknown
    human_judgment: false
metrics:
  duration: 12min
  completed: 2026-08-04
status: complete
---

# Phase 237 Plan 01: Canonical B2C Generator Contract Summary

**The canonical B2C smoke and fixture now require complete Google OAuth output while failing closed on admin, organization, and passkey residue.**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-08-04
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Extended the authoritative assets-enabled smoke with OAuth file, migration, route, configuration, and Vault-supervision assertions.
- Added feature-owned B2C absence checks for admin, organizations, and passkeys across routes, files, migrations, assets, dependencies, and configuration.
- Made the fixture generate Google OAuth only after idempotently adding direct `cloak_ecto`, then compile the emitted host with warnings as errors and source-lock the smoke lifecycle.
- Retained explicit B2C password and magic-link route/controller assertions so opt-out coverage proves core sign-in remains available.

## Task Commits

1. **Task 1: Prove the complete B2C host lifecycle in the authoritative fresh-Phoenix smoke** — `2ff867b8` (feat)
2. **Task 2: Lock the B2C generated-tree contract in the fast fixture suite** — `3ded1d6a` (test)
3. **WR-01 remediation: retain B2C core login coverage** — `4fe7dd35` (fix)
4. **CR-01 remediation: isolate smoke temporary files** — `a3645956` (fix)
5. **CI remediation: portable retained-core matcher** — `7d6ac87f` (fix)
6. **CR remediation: POSIX portable smoke regexes** — `e52ccf8b` (fix)

## Files Created/Modified

- `scripts/ci/passkeys-opt-out-smoke.sh` — B2C-only OAuth-positive and disabled-feature-negative smoke assertions.
- `test/sigra/install/generator_passkeys_opt_out_test.exs` — generated-host fixture assertions and smoke source-lock coverage.

## Decisions Made

- The full assets/PostgreSQL/migration/root-boot lifecycle remains one authoritative shell harness; the fixture only locks generated-tree and source-contract behavior.
- OAuth and disabled-feature assertions are scoped to stable generator-owned sentinels, avoiding false positives from generic words.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Retained-core B2C login contract**
- **Found during:** Post-plan code review (WR-01)
- **Issue:** The opt-out contract proved OAuth and disabled-feature boundaries but did not prove that password and magic-link sign-in remain generated.
- **Fix:** Added B2C-only route assertions for login/password/magic-link, SessionController assertions for password authentication and magic-link issuance/verification, and matching fixture source locks.
- **Files modified:** `scripts/ci/passkeys-opt-out-smoke.sh`, `test/sigra/install/generator_passkeys_opt_out_test.exs`
- **Verification:** formatter, Elixir parser, shell syntax, fixed-string source checks, and diff checks passed.
- **Committed in:** `4fe7dd35`

**2. [Rule 2 - Security] Invocation-owned smoke temporary directory**
- **Found during:** Final code review (CR-01)
- **Issue:** The smoke accepted an environment-controlled `TMP_ROOT` and recursively removed it without proving it was an isolated harness directory.
- **Fix:** The harness now creates an invocation-owned `mktemp -d` root, removes it through an EXIT trap only after a fixed-prefix check, and limits per-leg deletion to the three fixed generated app paths.
- **Files modified:** `scripts/ci/passkeys-opt-out-smoke.sh`
- **Verification:** shell syntax, cleanup source checks, and diff checks passed.
- **Committed in:** `a3645956`

**3. [Rule 3 - Blocking issue] Portable generated-host matcher**
- **Found during:** Exact-commit CI run `30968468626`
- **Issue:** The B2C smoke's assertions and diagnostics required `rg`, which is absent from the CI runner; the resulting false missing-route report did not establish a generated-host mismatch.
- **Fix:** Routed positive and negative assertions through a helper that uses `rg` when available and portable `grep -En` otherwise; retained the controller login/magic-link contract because the current Core router template emits those exact routes.
- **Files modified:** `scripts/ci/passkeys-opt-out-smoke.sh`, `test/sigra/install/generator_passkeys_opt_out_test.exs`
- **Verification:** formatter, Elixir parser, shell syntax, template/source agreement checks, and diff checks passed.
- **Committed in:** `7d6ac87f`

**4. [Rule 1 - Bug] POSIX-compatible fallback regex**
- **Found during:** Final code review
- **Issue:** The portable `grep -E` fallback could not reliably interpret the passkey configuration assertion's `\s*` whitespace token on BSD/POSIX grep.
- **Fix:** Replaced it with `[[:space:]]*` and extended the fixture source lock to require both `assert_match` and `assert_no_match` to delegate to the portable matcher.
- **Files modified:** `scripts/ci/passkeys-opt-out-smoke.sh`, `test/sigra/install/generator_passkeys_opt_out_test.exs`
- **Verification:** formatter, Elixir parser, shell syntax, POSIX character-class probe, source-lock static checks, and diff checks passed.
- **Committed in:** `e52ccf8b`

## Issues Encountered

- Local PostgreSQL is unavailable (`pg_isready` returned no response). The full `GITHUB_WORKSPACE="$PWD" scripts/ci/passkeys-opt-out-smoke.sh` lifecycle was not run locally and is **BLOCKED**, not passed. Exact-commit CI job `passkeys_opt_out_smoke` must supply the required PostgreSQL evidence.
- The targeted ExUnit invocation also cannot reach the repository's configured test PostgreSQL endpoint (`127.0.0.1:53988`), so it did not complete. Formatting, Elixir parsing, shell syntax, source-stage checks, and diff checks passed locally.

## Known Stubs

None.

## Next Phase Readiness

The commit pair is ready for the existing CI PostgreSQL service lane. Do not close B2C-01 lifecycle evidence until `passkeys_opt_out_smoke` succeeds for the exact commit.

## Self-Check: PASSED

- Both modified source files exist and all task/remediation commits are present in git history.
- `mix format --check-formatted test/sigra/install/generator_passkeys_opt_out_test.exs`, `elixir` parsing, `bash -n scripts/ci/passkeys-opt-out-smoke.sh`, retained-core/template agreement, cleanup, portable-matcher and POSIX-regex source checks, and `git diff --check` passed.
