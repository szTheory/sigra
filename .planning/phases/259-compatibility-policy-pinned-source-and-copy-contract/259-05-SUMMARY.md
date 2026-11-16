---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 05
subsystem: testing
tags: [exunit, ratchet, frozen-surface, branding, byte-identity, add-only]

requires:
  - phase: 259-01
    provides: policy docs that name the frozen and add-only lists this ratchet enforces
provides:
  - test/sigra/brand/frozen_surface_test.exs, an add-only ratchet over eleven frozen categories with a pure comparator, an extend-only baseline guard and planted-text extractor tests
  - test/fixtures/brand/frozen-surface.json, the committed baseline (schema sigra.brand-frozen-surface/v1, 735 lines, one name per line)
  - test/sigra/brand/legacy_profiles_test.exs and test/fixtures/brand/legacy-profiles.json, byte-identity for three legacy Branding profile shapes across six public functions
affects: [260, 261, 262, 263]

actuals:
  tokens: 15617
  tasks: 3
  commits: 3
commits: 3
plan_head_before: c963d6e10ffaa441e8e726ebb676e168c93824ce
plan_head_after: 6cd54afc65a97b3e155bad45a2fec3958807ceea

tech-stack:
  added: []
  patterns:
    - "Add-only ratchet: extract the current set from the source of truth, assert baseline SUBSET-OF current, and let the baseline grow only through an opt-in path that unions and is itself guarded by extend_only/2"
    - "Pretty one-element-per-line JSON written by a small private recipe so that a later addition is a pure-added diff and a deleted-line grep is a meaningful gate"
    - "Extractors never evaluate repo content: regex over text and Code.string_to_quoted/1 over config.ex, with planted-text unit tests proving each extractor and a planted `System.halt(1)` proving the AST walk does not run code"
    - "Fixture written once in setup_all behind an env var (never inside a test) so the write is ordered ahead of the async tests that read it"

key-files:
  created:
    - test/sigra/brand/frozen_surface_test.exs
    - test/fixtures/brand/frozen-surface.json
    - test/sigra/brand/legacy_profiles_test.exs
    - test/fixtures/brand/legacy-profiles.json
  modified: []

key-decisions:
  - "The baseline must carry exactly the module's known categories, and every category must have an extractor: a renamed or dropped extractor fails by name instead of silently skipping a check"
  - "Profile defaults are frozen with their values as key=inspect(value) strings, so a changed default is the removal of the old string and goes red"
  - "Markup class tokens ending in a hyphen are dropped: they are interpolation fragments such as sg-metric- before an interpolation, not class names, and freezing them would pin an accident"
  - "Only the Gettext domain is frozen, never msgids; preview HTML and admin copy are not frozen in the legacy test either, because Phase 262 rewords the branding workbench"
  - "The legacy fixture is generated once from current behaviour behind SIGRA_BRAND_LEGACY=write and is never overwritten by the test; the test only reads it"

patterns-established:
  - "Positive controls on the real artifacts: a planted removal in a copy of the real baseline and a one-character tamper of the real legacy fixture each went red with the expected named message, then the file was restored byte-identical"
  - "Non-vacuity at three levels: baseline category non-empty, extracted set non-empty, and the golden router wildcard must resolve to exactly one file"

requirements-completed: [BPOL-03]

coverage:
  - id: D1
    description: "A committed baseline freezes eleven categories (--sg-* and --sigra-auth-* custom properties, sg-* and sigra-auth classes, Profile keys and defaults, config option paths, route lines, verified-route helpers, the Gettext domain, data-testid values, installer targets for logos and the two stylesheets), and baseline SUBSET-OF current holds for each"
    requirement: "BPOL-03"
    verification:
      - kind: unit
        ref: "test/sigra/brand/frozen_surface_test.exs#ratchet"
        status: pass
    human_judgment: false
  - id: D2
    description: "The comparator is pure with unit tests (removal red, addition green) and an extend-only guard refuses to write a baseline that is not a superset of the committed one"
    requirement: "BPOL-03"
    verification:
      - kind: unit
        ref: "test/sigra/brand/frozen_surface_test.exs#comparator (pure)"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/frozen_surface_test.exs#extend-only guard (pure)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Each extractor is proven against planted text and the config walk never evaluates code; the golden router app alias is normalized to a neutral token"
    requirement: "BPOL-03"
    verification:
      - kind: unit
        ref: "test/sigra/brand/frozen_surface_test.exs#extractors (planted text)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Legacy Branding profiles (explicit, partial, defaults) render byte-identically across css_variables, color_tokens, logo, email_logo, dark_accent_source and Profile.to_map, with a positive control proving a one-character change is detected"
    requirement: "BPOL-03"
    verification:
      - kind: unit
        ref: "test/sigra/brand/legacy_profiles_test.exs#committed expected outputs"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/legacy_profiles_test.exs#positive control"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 05: Frozen-Surface Ratchet and Legacy Profile Byte-Identity Summary

**An add-only ratchet freezing 11 categories of host-visible names (100 `--sg-*` and 35 `--sigra-auth-*` properties, 168 `sg-*` and 66 `sigra-auth` classes, 25 Profile defaults, 170 config option paths, 60 route lines, 54 helpers, 25 test ids, 4 installer targets) plus a byte-identity test for three legacy Branding profile shapes, so later brand phases can add names but cannot remove or rename one.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-11-14T15:57:53Z
- **Completed:** 2026-11-14T16:03:02Z (task commits and verification; SUMMARY written immediately after)
- **Tasks:** 3
- **Files modified:** 4 (all created)

## Accomplishments

- **Tracer (Task 1):** `Sigra.Brand.FrozenSurfaceTest` with a pure `missing/2` comparator, an `extend_only/2` guard, a `union/2` writer and a one-element-per-line `pretty/1` serializer, proven end to end on Profile keys and defaults plus `--sg-*` properties. A planted bogus `--sg-` name in a copy of the real baseline produced the named failure ("Frozen surface removed in category css_custom_properties_sg") and the exact extend command; the file was restored byte-identical.
- **Widening (Task 2):** nine more categories added through the opt-in extend path, each with a non-vacuity assertion. Measured counts match research: 35 auth properties, 66 `sigra-auth` classes, 170 config paths across 33 top-level keys, 54 helpers, one Gettext domain (`sigra`), 25 test ids. Route lines came out at 60 (research estimated about 50) and `sg-*` classes at 168 (112 selectors unioned with 153 markup tokens). Installer targets are exactly the two logos and the two stylesheets via `Admin.files/1` and `Core.files/1`. Eight planted-text unit tests cover the extractors, including a `System.halt(1)` default inside a planted `@schema` that must never run.
- **Legacy byte-identity (Task 3):** `Sigra.Brand.LegacyProfilesTest` renders explicit, partial and defaults profiles through six public functions (18 generated tests) and compares with `==` against a committed fixture generated once. A one-character tamper of the real fixture failed two tests with expected-versus-actual output; the fixture was restored byte-identical.
- Zero bytes changed under `lib/`, `priv/`, `brandbook/`, `brand/`, `.github/`, `scripts/`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Comparator, extend-only guard and two categories end to end** - `9b1382731` (test)
2. **Task 2: Remaining categories** - `3ea240b79` (test)
3. **Task 3: Legacy Branding profile byte-identity** - `6cd54afc6` (test)

**Plan metadata:** committed separately as `docs(259-05)` (SUMMARY, STATE, ROADMAP, REQUIREMENTS).

## Files Created/Modified

- `test/sigra/brand/frozen_surface_test.exs` - ratchet, comparator, extend-only guard, extractors, planted-text tests (new, 653 lines)
- `test/fixtures/brand/frozen-surface.json` - committed baseline, 11 categories, 735 lines (new)
- `test/sigra/brand/legacy_profiles_test.exs` - byte-identity test with diff walker and positive controls (new, 291 lines)
- `test/fixtures/brand/legacy-profiles.json` - committed expected outputs for three shapes (new, 182 lines)

## Decisions Made

- The baseline must contain exactly the module's known categories and every category needs an extractor, so a renamed source path or a dropped extractor fails by name.
- Profile defaults are frozen as `key=inspect(value)` strings; a changed default removes the old string and fails.
- Hyphen-terminated markup tokens are treated as interpolation fragments and dropped. Freezing `sg-metric-` would pin an accident of string interpolation, not a class.
- Msgids, preview HTML and admin copy are deliberately not frozen (ADR 005 allows targeted msgid renames; Phase 262 rewords the branding workbench).
- Both fixtures are written only through opt-in env vars in `setup_all`. The legacy one is never overwritten. The frozen baseline is overwritten only with a guarded union.

## Deviations from Plan

None - plan executed exactly as written.

Three small choices go beyond the plan's wording and add no scope: the `explicit` legacy shape sets every profile field (not only colors and logos) so `Profile.to_map/1` is exercised on a fully explicit profile; the ratchet adds a test that the baseline's category list equals the module's category list; and extractor correctness is covered by planted-text unit tests (threat T-259-15 mitigation).

## Issues Encountered

None that remain. Three transient test-authoring slips were fixed inside Task 2 before its commit: the `css_selectors/2` helper passed arguments to `capture_all/2` in the wrong order, and a planted test-id control accidentally contained the substring `testid`. Both were caught by the first runs and corrected.

## Verification Results

Task acceptance criteria (all re-run after the task commits):

| Criterion | Result |
|-----------|--------|
| Task 1: baseline file exists; `grep -c '"--sg-'` is 100 (at least 90) | PASS |
| Task 1: `accent_color` default string shows `#c2410c` | PASS |
| Task 1: `grep -c '^      "'` element lines is 125 at Task 1 (at least 100) | PASS |
| Task 1 and 2: ratchet-only-grew gate against `aeda7273d` | PASS |
| Task 2: all 11 category keys present (count 11) | PASS |
| Task 2: both `sigra-logo-primary` installer targets present | PASS |
| Task 2: zero-shipped-bytes gate | PASS |
| Task 3: `"explicit"\|"partial"\|"defaults"` lines are 4 (at least 3) | PASS |
| Task 3: `--sigra-auth-` lines are 3 (at least 1) | PASS |
| Task 3: `grep preview_pair` on the legacy test prints nothing; `Branding.css_variables` control matches | PASS |
| Task 3: `mix test legacy_profiles_test.exs branding_test.exs` | PASS, 48 tests, 0 failures |

Plan-level verification:

| Check | Result |
|-------|--------|
| 1. `mix test` of frozen surface, legacy profiles, branding and auth UI contract | PASS, 98 tests, 0 failures (whole `test/sigra/brand` directory: 119 tests, 0 failures) |
| 2. Ratchet only grew (non-empty diff, no deleted lines, positive `+` control) | PASS |
| 3. Zero shipped bytes under lib, priv, brandbook, brand, .github, scripts (tracked sample non-empty, no untracked) | PASS |
| 4. Privacy gate with planted-failure control; also a username-derived word-boundary grep with a positive control on the four new files | PASS |
| 5. `mix format --check-formatted` and `mix compile --warnings-as-errors` | PASS |

## Known Stubs

None.

## Threat Flags

None. The plan's threat model is mitigated: T-259-12 by `extend_only/2` plus the deleted-line gate, T-259-13 by committed `==` outputs with a positive control, T-259-14 by `Code.string_to_quoted/1` only (proven with a planted `System.halt(1)`), T-259-15 by per-category non-vacuity assertions and the exactly-one-router wildcard check. No new network, auth, file-access or schema surface was introduced.

## Next Phase Readiness

Ready for 259-06. The baseline is now the contract Phases 260-262 are held to: they may add names and run `SIGRA_BRAND_BASELINE=extend mix test test/sigra/brand/frozen_surface_test.exs` to record them, but cannot remove or rename one. When a later phase appends a name after the last element of an array, the previous last line gains a trailing comma, so any deleted-line gate in a later phase must strip a trailing comma from both sides before comparing (the base-relative gate used here sees a pure addition because the file did not exist at `aeda7273d`). One observation carried forward: the `defaults` legacy shape freezes a derived dark accent of `#f05211` for the default light accent `#c2410c`, which is current behaviour and should stay stable unless a later phase deliberately changes dark-accent derivation (that would be a visible change to legacy hosts).

## Self-Check: PASSED

- FOUND: `test/sigra/brand/frozen_surface_test.exs`
- FOUND: `test/fixtures/brand/frozen-surface.json`
- FOUND: `test/sigra/brand/legacy_profiles_test.exs`
- FOUND: `test/fixtures/brand/legacy-profiles.json`
- FOUND: commits `9b1382731`, `3ea240b79`, `6cd54afc6` (ancestors of HEAD)
- `commits: 3` measured from the persisted ledger (`plan_head_before` `c963d6e10` to `plan_head_after` `6cd54afc6`)
