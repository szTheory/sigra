---
phase: 139-recipe-contract-integrity-sister-repo-verification
plan: "02"
subsystem: docs
tags: [lockspire, rulestead, recipes, documentation, sister-repo, contracts]

# Dependency graph
requires:
  - phase: 139-01
    provides: "RCT-01 contract fixture that validates five required markers per companion-lib recipe"
provides:
  - "Fixed lockspire.md resolve_account/2 return shape: case expression returning {:ok, user} / {:error, :not_found} matching canonical AccountResolver callback contract (RCV-01)"
  - "Fixed rulestead.md policy example: @behaviour Rulestead.Admin.Policy + @impl on can?/4 + corrected prose attribution (policy.ex:121 not authorizer.ex) + optional-callback comment block (RCV-02)"
  - "Closed phase-134 residual findings todo: WR-02 resolved, WR-05 resolved (correct module name), IN-01 already done (D-17)"
affects: [phase-140, docs, companion-lib-recipes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Recipe contract verification: cite verified sister-repo git ref (def616d / 0a18360) in validated_against prose line alongside version constraint"
    - "Behaviour callback documentation: show @behaviour + @impl in recipe examples; document optional callbacks in a commented block"

key-files:
  created: []
  modified:
    - "guides/recipes/companion-libs/lockspire.md"
    - "guides/recipes/companion-libs/rulestead.md"
    - ".planning/todos/completed/2026-05-28-phase-134-recipe-residual-findings.md"

key-decisions:
  - "Fixed lockspire.md resolve_account/2 to wrap bare get_user/1 in a case expression ({:ok, user} / {:error, :not_found}) — matches canonical AccountResolver @callback contract at account_resolver.ex:17-18 (verified Lockspire v1.2.0 def616d)"
  - "Fixed rulestead.md to declare @behaviour Rulestead.Admin.Policy (not Admin.Authorizer — authorizer.ex:149 is the dispatch site, policy.ex:121 is the behaviour definition); added @impl and optional-callback comment block (Rulestead v0.1.3 0a18360)"
  - "Moved phase-134 residual findings todo to completed/ (not resolved/ — project uses completed/) with full WR-02/WR-05/IN-01 disposition narrative"
  - "mix docs --warnings-as-errors has pre-existing failures in lib/sigra/doctor.ex:63 (hidden function references); confirmed pre-existing before this plan's edits; no new warnings introduced by recipe changes; RCT-01 fixture passes 2/2"

patterns-established: []

requirements-completed:
  - RCV-01
  - RCV-02

# Metrics
duration: 15min
completed: 2026-05-29
---

# Phase 139 Plan 02: Recipe Contract Fixes (RCV-01/RCV-02) Summary

**Fixed Lockspire `resolve_account/2` return shape to `{:ok, user}/{:error, :not_found}` and corrected Rulestead policy to declare `@behaviour Rulestead.Admin.Policy` with `@impl`; both verified against sister-repo source; phase-134 residual todo closed.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-29T13:00:00Z
- **Completed:** 2026-05-29T13:15:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- RCV-01: Fixed `lockspire.md` so `resolve_account/2` wraps bare `get_user/1` in a `case` expression returning `{:ok, user}` / `{:error, :not_found}` — matches `@callback resolve_account/2` contract at `account_resolver.ex:17-18` (Lockspire v1.2.0 `def616d`), preventing MatchError in Lockspire's dispatch at `token_exchange.ex:1223` and `userinfo.ex:147`
- RCV-02: Fixed `rulestead.md` policy example to declare `@behaviour Rulestead.Admin.Policy` + `@impl Rulestead.Admin.Policy` before `can?/4`; corrected prose to attribute behaviour to `policy.ex:121` (not `authorizer.ex`, which is the dispatch site at `:149`); added commented optional-callback block for `change_request_required?/4` / `allow_self_approval?/4` (Rulestead v0.1.3 `0a18360`)
- D-17: Closed `2026-05-28-phase-134-recipe-residual-findings.md` — WR-02 resolved, WR-05 resolved with corrected module name (`Admin.Policy` not `Admin.Authorizer`), IN-01 confirmed already done; moved to `completed/`
- RCT-01 contract fixture (from plan 01) passes 2/2 after both recipe edits — all five required markers preserved in both files

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix lockspire.md resolve_account/2 return shape (RCV-01)** - `5ee9c43` (docs)
2. **Task 2: Fix rulestead.md @behaviour + @impl + close todo (RCV-02/D-17)** - `210e4de` (docs)

**Plan metadata:** (docs commit — see final_commit below)

## Files Created/Modified

- `guides/recipes/companion-libs/lockspire.md` — Fixed `resolve_account/2` to return `{:ok, user}` / `{:error, :not_found}`; updated `last_validated:` to 2026-05-29; added `def616d` ref to prose validation line
- `guides/recipes/companion-libs/rulestead.md` — Added `@behaviour Rulestead.Admin.Policy` + `@impl`; corrected prose attribution to `policy.ex:121`; added optional-callback comment block; updated `last_validated:` to 2026-05-29; added `0a18360` ref to prose validation line
- `.planning/todos/completed/2026-05-28-phase-134-recipe-residual-findings.md` — Added resolution section (WR-02/WR-05/IN-01 dispositions); moved from `pending/` to `completed/`

## Decisions Made

- Wrapped bare `get_user/1` call in `case` expression (not a bare `{:ok, get_user(...)}` wrapping) — this correctly handles both `nil` → `{:error, :not_found}` and `%User{}` → `{:ok, user}` matching the full `{:ok, account()} | {:error, :not_found | term()}` callback contract
- Used `@impl Rulestead.Admin.Policy` (not `@impl true`) in the recipe — module-qualified form gives better compile-time documentation of which behaviour is being implemented, and is the preferred style when the module is known
- Prose fix: stated `policy.ex:121` as the behaviour source and `authorizer.ex:149` as the dispatch site — preserves the original `authorizer.ex` reference (now contextualized correctly) while correcting the wrong attribution

## Deviations from Plan

None — plan executed exactly as written. The `mix docs --warnings-as-errors` failure noted in both tasks was confirmed pre-existing (present before my edits, in `lib/sigra/doctor.ex:63` referencing hidden functions; unrelated to recipe changes). The recipe files themselves generate without warnings.

## Issues Encountered

Pre-existing `mix docs --warnings-as-errors` failure in `lib/sigra/doctor.ex:63` (references to hidden functions `Sigra.Audit.Forwarders.oban_running?/1`, `Sigra.Application.verify_vault!/1`, `Sigra.Application.attach_forwarders/0`). Confirmed pre-existing by stash-test before my edits. Not caused by, and not fixable by, this plan's recipe changes. Out of scope per deviation-rule scope boundary.

Pre-existing `mix test` failures in install-generator tests (`argon2_elixir` compilation failure in generated host app context). Unrelated to recipe edits.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 139 is complete: RCT-01 fixture (plan 01) + RCV-01/RCV-02 recipe fixes + D-17 todo closure (plan 02)
- Phase 140 (deprecation-removal timelines + verification + docs close) can proceed without blockers

## Self-Check: PASSED

- FOUND: guides/recipes/companion-libs/lockspire.md
- FOUND: guides/recipes/companion-libs/rulestead.md
- FOUND: .planning/todos/completed/2026-05-28-phase-134-recipe-residual-findings.md
- FOUND: .planning/phases/139-recipe-contract-integrity-sister-repo-verification/139-02-SUMMARY.md
- FOUND: commit 5ee9c43 (Task 1)
- FOUND: commit 210e4de (Task 2)

---
*Phase: 139-recipe-contract-integrity-sister-repo-verification*
*Completed: 2026-05-29*
