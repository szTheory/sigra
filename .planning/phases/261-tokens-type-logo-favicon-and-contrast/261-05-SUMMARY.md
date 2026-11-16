---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 05
subsystem: ui
tags: [brand, logo, svg, admin-shell, css-custom-properties, exunit, byte-parity]

# Dependency graph
requires:
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-04 token and type work in sigra_admin.css (the stylesheet whose brand-mark rules this plan edits) and the comment-stripped rule-reader pattern"
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-12 removal of the stray rail files and the demo preset repoint, so this plan touches only the four shipped lockup copies"
provides:
  - "The v2 lockups at the frozen filenames admin/sigra-logo-primary{,-dark}.svg and the two example copies: the brand/ bytes plus one inserted <title>sigra</title>"
  - "Shell lockup images sized 96 by 39 in the installer template and the example, alt and the labelled link unchanged"
  - ".sg-brand-mark__lockup 6rem by 2.5rem, .sg-brand-mark gap var(--sg-space-4), the translateY(-2px) removed, example topbar min-height 4rem"
  - "Sigra.Brand.LogoContractTest, 20 tests with planted controls, plus every old-logo pin rewritten to read the viewBox from brand/ at run time"
affects: [261-08, 261-09, 261-10, 261-11, 262]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the added lines of the realized diff)
actuals:
  tokens: 6631
  tasks: 2
  commits: 3
commits: 3
plan_head_before: fd6b6ccf46e93a96ee98f6891e4b442732ff5eb5
plan_head_after: 09903262fa83a2967e6664932cc9f3f9940c62ac

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Strip-one-string byte parity: a shipped copy equals its brand/ source after removing exactly one inserted string, so a hand edit to the path data cannot pass"
    - "Pins read the book, not a literal: a shipped logo's expected viewBox is read from the matching brand/ file at test time"
    - "Guard lists assembled from parts when the literals themselves would be hits for the repository's own home-path scan"

key-files:
  created:
    - test/sigra/brand/logo_contract_test.exs
  modified:
    - priv/templates/sigra.install/admin/sigra-logo-primary.svg
    - priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg
    - test/example/priv/static/images/sigra-logo-primary.svg
    - test/example/priv/static/images/sigra-logo-primary-dark.svg
    - priv/templates/sigra.install/admin/components/admin_shell.ex
    - test/example/lib/example_web/components/admin_shell.ex
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/example/priv/static/assets/css/app.css
    - test/sigra/install/features/admin_test.exs
    - test/example/test/example_web/admin_shell_test.exs

key-decisions:
  - "The contract test carries its own small rule reader (regex over comment-stripped CSS, whole-selector match after a rule boundary) instead of reusing the private reader in css_contract_test.exs; copying 25 lines is cheaper than promoting a private helper into shared support for one more consumer."
  - "The lockup rule check rejects any translate in a transform declaration, not only translateY(-2px), because the spec's point is that nothing may shift the lockup out of its clear space."
  - "The shell parity check compares the whole whitespace-collapsed lockup img tags of the template and the example, which is stricter than the plan's 'equal on those attributes' and costs nothing because the two are identical today."
  - "before/ and MANIFEST.json stay untouched. verify_manifest/1 re-hashes the committed before directory against its own files map, and the manifest's pinned css_sha256 (logo and CSS hashes) is written by the capture-time writer and read by no comparator, so it is a record, not a live pin."

patterns-established:
  - "A shipped asset that is a book file plus an inserted element is pinned by sha256 after stripping that element, plus a position check that the element sits directly after the opening tag"
  - "Assertion failures over whole stylesheets name the rule instead of printing the stylesheet (assert_declares/5)"

requirements-completed: [BTOK-04, BTOK-07]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "The four shipped lockup copies are the matching brand/assets/logo lockups plus exactly one inserted <title>sigra</title> directly after the opening svg tag (sha256 equal after stripping it; light with light, dark with dark; the two differ)"
    requirement: BTOK-04
    verification:
      - kind: unit
        ref: "test/sigra/brand/logo_contract_test.exs#byte parity with the brand book (BTOK-04)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each shipped copy has exactly one title, the v2 viewBox, path data only, no desc, metadata, tool or font markers, no absolute paths, none of the retired phrases and no EEx sequence; the guard is shown to fire on planted second titles, desc, metadata, text, retired phrases and a home path"
    requirement: BTOK-04
    verification:
      - kind: unit
        ref: "test/sigra/brand/logo_contract_test.exs#metadata and privacy guards (T-261-07)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both admin_shell.ex files size the two lockup images width 96 by height 39, keep alt empty and the aria-label=\"Sigra admin overview\" link, and render identical image tags"
    requirement: BTOK-04
    verification:
      - kind: unit
        ref: "test/sigra/brand/logo_contract_test.exs#shell markup (BTOK-04)"
        status: pass
      - kind: unit
        ref: "test/sigra/install/features/admin_test.exs#admin shell template exposes the auth branding nav item"
        status: pass
    human_judgment: false
  - id: D4
    description: "The lockup box is 6rem by 2.5rem and flex 0 0 auto with no translate, the brand-mark gap is var(--sg-space-4), the image keeps object-fit contain and left-center position (template and example stylesheet), and the example topbar min-height is 4rem"
    requirement: BTOK-04
    verification:
      - kind: unit
        ref: "test/sigra/brand/logo_contract_test.exs#lockup box and clearance (BTOK-04)"
        status: pass
      - kind: other
        ref: "bash scripts/ci/admin-css-conformance.sh, scripts/ci/app-css-corruption-check.sh and cmp of the template and example stylesheet (all pass)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Every old-logo pin is rewritten in this change set: the shell width/height pins (188 by 54 to 96 by 39), the retired viewBox and the retired-font phrase in admin_test.exs and the example admin_shell_test.exs; a git grep finds none of them; the before/ snapshot is untouched"
    requirement: BTOK-07
    verification:
      - kind: unit
        ref: "test/sigra/install/features/admin_test.exs#admin logo templates are the book's path-only lockups with one title"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/admin_shell_test.exs#ships the book's path-only Sigra lockup assets with one title (14 tests, MIX_ENV=test --include example_app)"
        status: pass
    human_judgment: false
  - id: D6
    description: "How the 96px lockup actually paints in a real browser in Light and Dark: painted width at least 96px, 2T clear space on every side, a 64px topbar, and no overflow at 375 and 390px"
    requirement: BTOK-04
    verification: []
    human_judgment: true
    rationale: "This plan asserts the declarations and attributes that produce the geometry, not the painted result. The real-DOM geometry test is plan 261-09's; the single human logo-distinctness gate is the phase-end contact sheet (plan 261-11)."

# Metrics
duration: 4min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 05: v2 Lockups Under the Frozen Filenames Summary

**The brand book's v2 lockup replaces the rail logo bytes at the frozen filenames (book file plus one inserted `<title>sigra</title>`, sha256-pinned), the shell images and the lockup box move to the book's 96px minimum with the 16px clearance and a 64px topbar, and every old-logo pin now reads its expectation from `brand/`.**

## Performance

- **Duration:** about 4 min timed (from the commit-ledger write to the last verification; the initial reading of the plan and its inputs was not timed)
- **Started:** 2026-11-16T00:39:30Z
- **Completed:** 2026-11-16T00:43:10Z
- **Tasks:** 2 (Task 1 is the tracer and TDD: RED and GREEN commits)
- **Files modified:** 12 (1 created, 11 modified; nothing under `lib/`, `brand/`, `.github/`, `test/fixtures/` or the core installer templates)

## Accomplishments

- **Tracer, one logo end to end.** The contract test was written first and committed red (12 of 20 failing, every failure on a pending shipped value; the planted controls and the rule reader passed by design). The four logo copies, both shells, the lockup rules and the example topbar then went green in one commit, and the plan's `<verify>` was re-run at the committed HEAD (tracer gate, default end-of-phase mode, automated-only verify): 20 tests, conformance PASS, corruption guard OK, `cmp` identical.
- **Bytes.** Each shipped lockup is `cp` of the matching `brand/assets/logo/sigra-lockup-{light,dark}.svg` with exactly one `<title>sigra</title>` inserted directly after the opening `<svg ...>` tag by one Edit per file. Path data is byte-identical (strip the title, sha256 equals the book file). No `<desc>`, metadata, tool or font marker, no absolute path, no retired phrase, no `<%`. The installer targets in `lib/sigra/install/features/admin.ex` are unchanged.
- **Shell and box.** Both `admin_shell.ex` files: the two lockup `<img>` tags are `width="96" height="39"` (was 188 by 54); `alt=""`, `decoding="async"` and the `aria-label="Sigra admin overview"` link are unchanged. `.sg-brand-mark__lockup` is `6rem` by `2.5rem` with `flex: 0 0 auto`, the object-fit and opacity-swap rules untouched and `transform: translateY(-2px)` deleted; `.sg-brand-mark` gap is `var(--sg-space-4)`. The example `.sg-admin-topbar-inner` `min-height` is `4rem` (12px padding twice plus the 40px lockup), one line in `app.css`.
- **Pins.** `admin_test.exs` (shell 96 and 39; logo templates read the viewBox from the matching `brand/` file and expect one title, the retired viewBox and the retired-font phrase are gone) and the example `admin_shell_test.exs` (same, reading `brand/` four directories up). The new contract test is the single owner of byte parity, title, metadata and CSS contract.

## Evidence recorded for the plan

**Old-pin grep after the change** (`git grep -n "Space Grotesk v2.0" -- test/sigra test/example/test` and `git grep -n -e 'width="188"' -e 'height="54"' -- test/sigra test/example/test`): no matches in either (HEAD before this plan: 2 each). `git diff --name-only -- test/fixtures/brand` prints nothing. (Retired-font phrases still appear in `brandbook/`, the old pre-book directory; it ships nothing and no test reads it, so it is out of scope.)

**Dependents of the old 56px topbar** (grep over the example app, Playwright specs, `scripts/`, `lib/`, `priv/` and the template stylesheet for `3.5rem`, `56px`, `topbar-inner`, `topbar` height and sticky offsets): none beyond the rule changed. What the grep did find and why each stays:

| Hit | Disposition |
|-----|-------------|
| `app.css` `.sg-admin-topbar-inner { min-height }` | changed 3.5rem to 4rem |
| `app.css` bottom-nav `min-height: 3.5rem` and `padding-bottom: calc(... + 3.5rem + env(...))` | unrelated (the bottom nav), unchanged |
| `sigra_admin.css` small-screen `.sg-admin-topbar-inner { align-items: flex-start }` | no height, unchanged |
| `admin_shell.ex` class use of `sg-admin-topbar-inner` | markup only |
| `admin-theme.spec.ts` test title "renders stable topbar controls..." | a name, no height assertion |
| `scripts/brand/critique-render.mjs` `54px-topbar` | a render-profile label for a brand critique, not a layout dependency |
| any sticky `top:` offset | all `top: 0`, none derives from the topbar height |

**Catalog evidence** (`git grep -n -e css_sha256 -e committed_status -e verify_manifest -e '"pinned"'` over `test`, `lib`, `scripts`): `verify_manifest/1` re-hashes every file under the committed `before/` directory against that manifest's own `files` map; `css_hashes/0` writes `pinned.css_sha256` (the CSS and the two logo hashes from `@css_pin_files`) when a catalog is captured and nothing compares it to the shipped bytes; the only readers of `pinned` check key names or planted values. So the before manifest's logo and CSS hashes are a capture-time record with no live comparator. Decision: `test/fixtures/brand/before/**` and `MANIFEST.json` stay untouched (not regenerated) and `test/support/brand/catalog.ex` `@css_pin_files` stays as the capture-time list. `catalog_test.exs` and `catalog_diff_test.exs` are green unchanged (the diff test's after-state is its copy-of-itself plus planted-byte cases, which read no shipped bytes), so no live comparator exists to describe or fix.

## Task Commits

1. **Task 1 (tracer): v2 lockup bytes, title, shell size and lockup box, proven by a contract test**
   - RED `fbc88c532` (test): 20 tests, 12 failures, each on a pending shipped value
   - GREEN `7544af6fd` (feat): four logo copies, two shells, two stylesheets, one `app.css` line; 20 tests pass, conformance PASS, corruption guard OK, `cmp` identical
2. **Task 2: rewrite every old logo pin** - `09903262f` (test)

**Plan metadata:** the docs commit that follows this file (SUMMARY, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `test/sigra/brand/logo_contract_test.exs` - `Sigra.Brand.LogoContractTest`, 20 tests with planted controls (created)
- `priv/templates/sigra.install/admin/sigra-logo-primary.svg`, `sigra-logo-primary-dark.svg` - the v2 lockups plus one title (frozen filenames)
- `test/example/priv/static/images/sigra-logo-primary.svg`, `sigra-logo-primary-dark.svg` - byte copies of the two above
- `priv/templates/sigra.install/admin/components/admin_shell.ex`, `test/example/lib/example_web/components/admin_shell.ex` - the two image `width` and `height` values only
- `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css` - brand-mark gap, lockup box, `translateY` removed; example copy is a byte-identical `cp`
- `test/example/priv/static/assets/css/app.css` - topbar `min-height` only (1 line added, 1 removed)
- `test/sigra/install/features/admin_test.exs`, `test/example/test/example_web/admin_shell_test.exs` - the enumerated pins rewritten

## Decisions Made

See `key-decisions` in the frontmatter. In short: a small local rule reader in the new test, a stricter no-translate check and whole-tag shell parity, and the before catalog kept as a capture-time record.

## Deviations from Plan

None - plan executed exactly as written.

Additions within the plan's goal, none weakening a criterion:

- **[Interpretation] More tests than the 8 the plan asks for.** The file has 20: the plan's five behaviours plus a title-position check, a light/dark distinctness check, an EEx-sequence check, an `object-fit` and `object-position` check, a topbar check, and controls for the rule reader and for `strip_title/1`.
- **[Interpretation] Intermediate commit state.** By the plan's task order, the GREEN commit changes the shell markup before Task 2 rewrites the two pins in `admin_test.exs`, so `admin_test.exs` is red at `7544af6fd` (the old 188 and 54 pins) and green again at `09903262f`. Task 1's own `<verify>` is green at its commit and Task 2's is green at its own; the intermediate commit was not run against `admin_test.exs`. The same shape plan 261-04 recorded.
- **[Interpretation] TDD gate evidence.** The plan type is `execute`, so the format-based RED classifier does not apply; RED evidence is the recorded 12 of 20 failures at `fbc88c532`, each on a real unshipped value.

**Total deviations:** 0 auto-fixed, 3 interpretations.
**Impact on plan:** none. Every acceptance criterion is met as written.

## Authentication Gates

None.

## Issues Encountered

- `MIX_ENV=test mix compile` in `test/example` still prints the pre-existing `/dev/mailbox` route warning (recorded in `deferred-items.md` by plan 261-12); the tests ran and passed, and the example compile check used `MIX_ENV=dev` as instructed (clean).
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started and were never staged.

## Verification

- `mix test test/sigra/brand/ test/sigra/install/features/admin_test.exs test/sigra/install/css_undefined_classes_test.exs`: 622 tests, 0 failures. `mix test test/sigra/brand/logo_contract_test.exs`: 20 tests, 0 failures. Task 2's own run (`admin_test.exs`, `catalog_test.exs`, `catalog_diff_test.exs`, `logo_contract_test.exs`): 133 tests, 0 failures.
- `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/admin_shell_test.exs`: 14 tests, 0 failures. `MIX_ENV=dev mix compile --warnings-as-errors` in `test/example`: clean.
- `bash scripts/ci/admin-css-conformance.sh` PASS; `admin-css-conformance.test.sh` PASS; `bash scripts/ci/app-css-corruption-check.sh` OK; `bash scripts/ci/admin-token-completeness.sh` PASS (112 tokens); `cmp` template and example stylesheet identical. `mix format --check-formatted` clean.
- Neighbouring suites (`asset_parity_test`, `test/sigra/templates`, `test/sigra/admin`, `branding_test`, `architecture_guides_contract_test`): 291 tests, 3 failures, all three the golden-copy legs of `asset_parity_test.exs` (`sigra_admin.css` and the two logos), stale by design until plan 261-11's single rebless. `golden_diff_test` was not run (golden-reading). No rebless was run here.
- Acceptance: `grep -c "<title>sigra</title>"` on the light template logo prints 1 (HEAD was 0); `git diff --stat -- brand` empty; `git diff --name-only` under `lib/sigra/install` empty; `app.css` numstat `1 1`; both old-pin greps empty.
- Privacy and scope: the added lines contain no home path, personal name or file URL (the only tool-marker words are the guard list and its planted-control strings in the new test); the four SVGs carry zero desc, metadata, generator, font or retired-phrase markers. The diff against the plan base under `brand`, `lib`, `.github`, `priv/templates/sigra.install/core` and `test/fixtures` is empty.

## Known Stubs

None.

## Threat Flags

None. The change is four byte-copied logos, two attribute values, CSS values and tests. T-261-07 (metadata, descriptions or absolute paths riding into the public repo and every adopter's host) is mitigated as planned by the contract test (one title, no desc, metadata or tool markers, no home paths, byte parity minus the title) and the diff privacy scan above; plan 261-11 re-scans the pushed diff. T-261-SC accepted: no package-manager install; the logos came from the pinned `brand/` tree.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 261-09 owns the real-DOM geometry test (painted width at least 96px, 2T clearance, topbar 63 to 65px, computed `transform` none). The declarations and attributes it depends on are in place; its 63 to 65px topbar bound matches the `4rem` min-height.
- Plan 261-08's theme matrix and the logo-square contrast read the fill from the shipped SVGs, which now hold the book's colors (`#C2410C` and `#F08A55` squares).
- Plan 261-11 owns the single `MIX_ENV=test mix sigra.fixture.rebless_golden`; until then the golden copies of `sigra_admin.css`, the two logos and `admin_shell.ex` are stale and the golden-reading legs fail by design. `STDOUT.txt` lists the logo creation lines by name only, so it should not change on its account.
- Phase 262 inherits a 96 by 40px lockup box and a 64px topbar in the example; the layout phase may revisit the topbar rhythm, but the clear-space arithmetic (12px padding plus the letterbox) is the contract it must keep.

## Self-Check: PASSED

- FOUND files: `test/sigra/brand/logo_contract_test.exs`, the four logo copies, both `admin_shell.ex` files, both stylesheets, `app.css`, `admin_test.exs`, `admin_shell_test.exs`
- FOUND commits (all ancestors of HEAD): `fbc88c532`, `7544af6fd`, `09903262f`
- Measured: 3 commits since `plan_head_before` `fd6b6ccf46e93a96ee98f6891e4b442732ff5eb5`
- Both tasks' acceptance criteria re-run at the final HEAD: Task 1 (20 tests in the file, `git diff --stat -- brand` empty, no `lib/sigra/install` change, title count 1); Task 2 (`admin_test.exs` green in a 622-test run, both old-pin greps empty, `test/fixtures/brand` diff empty, grep result and the retain-before decision recorded above)

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
