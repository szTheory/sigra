---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 09
subsystem: ui
tags: [shipped-css, brand-mark, explicit-theme, theme-switch, golden-rebless, playwright, generated-host, bgen-04]

requires:
  - phase: 260
    provides: "Plan 05 immutable before catalog; plan 06 asset parity table and byte-equality contract; plan 07 explicit-theme guard scope and the shrink-only gap baseline; plan 08 catalog-diff report"
provides:
  - "priv/templates/sigra.install/admin/sigra_admin.css carries the version stamp (/* sigra-admin-css: 1 */), the explicit light and dark token blocks (base layer), the brand-mark rules and the theme-switch rules (components layer); purely additive, 239 added lines, 0 deleted"
  - "The theme-switch active rule has no raw hex: fill and ring read var(--sg-logo-rail-accent), text reads var(--sg-color-ink) in Light and var(--sg-color-on-brand-solid) in Dark, with the explicit-attribute and prefers-color-scheme selectors; computed colours unchanged (rgb(253, 186, 116) on rgb(21, 21, 21))"
  - "Computed-style Playwright assertions in the generated-host shell test: lockup swap, explicit light vs dark --sg-color-panel, active theme-switch colours, in four states (system light, explicit light, explicit dark, system dark); seen red against the pre-L1 template, green after"
  - "D-11 parity reads both explicit blocks from the shipped file, plus a light twin; a stamp test over the template, example and golden copies; gap baseline 56 -> 49"
  - "One reviewed, additive, separately committed golden rebless; golden copy byte-identical to the template"
affects: [260-10, 260-11, 261, 262]

actuals:
  tokens: 10487
  tasks: 3
  commits: 4

plan_head_before: 896428d3cccc40bfebe9ef41fa40b1d747376e98
plan_head_after: 756d5b941a55d8fb79d5d4e49e8803fc7bff562c

tech-stack:
  added: []
  patterns:
    - "Computed-style assertions with expect.soft and a bounded per-assertion timeout so a red run reports every drifted rule and still finishes inside the test timeout"
    - "A rule that must resolve to one colour in every theme but has no single token is emitted per resolved theme (explicit html attribute, explicit shell attribute, prefers-color-scheme pair), each at higher specificity than the light default, so no source-order dependence"
    - "Stamp reader is a pure function; the planted bad-stamp controls call the same function the real assertions call"

key-files:
  created: []
  modified:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/playwright/tests/admin-generated.spec.ts
    - test/sigra/install/features/admin_test.exs
    - test/sigra/install/asset_parity_test.exs
    - test/fixtures/brand/css-undefined-classes.txt
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-deferred-items.md

key-decisions:
  - "Theme-switch fill and ring use --sg-logo-rail-accent, not --sg-color-brand-solid: brand-solid is #9a3412 in Light and would change the computed colour, which the plan's must-have truth forbids. This departs from the 260-07 hand-off sentence that named brand-solid; the plan text is the contract"
  - "The Dark text colour needs nine extra selectors (3 preference values x explicit html attribute, explicit shell attribute and the prefers-color-scheme pair) because no single token is #151515 in both themes and the inactive segments must keep the theme ink"
  - "The explicit token blocks sit at the end of the sg-base layer, ahead of every other rule that contains the explicit dark selector; the comment above them avoids that literal substring so the D-11 first-match extraction lands on the token block"
  - "The rest of the 49-class gap is not moved (plan OQ2); the missing .sg-admin-shell surface rule is logged, not fixed"

patterns-established:
  - "A shipped-CSS move is proven in three places: a real generated host (computed style, red then green), the example itself (unmodified specs against a booted dev server after the duplicates are deleted), and the CI userland for the guard (ubuntu:24.04 with mawk and GNU grep)"
  - "A guard is shown able to fail on the real file shape: the raw hex put back into the theme-switch active rule failed CHECK 2 at that line"

requirements-completed: [BGEN-04]

coverage:
  - id: D1
    description: "In a real generated host (phx_new 1.8.8 plus mix sigra.install, booted, real login) the brand mark swaps lockups, the explicit Light/Dark attribute changes resolved --sg-* values and the theme switch keeps its exact colours, all from the shipped sigra_admin.css alone; the same assertions were red against the pre-L1 template"
    requirement: BGEN-04
    verification:
      - kind: e2e
        ref: "scripts/ci/admin-acceptance-smoke.sh --test chrome, test 'generated host admin shell renders on desktop and mobile': red before (9 soft assertions failed, 29.7 s), green after (1 passed, 1.3 s)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The shipped file gained the stamp, explicit light/dark token blocks, brand-mark rules and theme-switch rules additively (0 deleted lines), the moved blocks are gone from the example app.css (no duplicates) and the example copy is byte-identical to the template"
    requirement: BGEN-04
    verification:
      - kind: other
        ref: "head -n 1 prints /* sigra-admin-css: 1 */; git diff --numstat 239 0; cmp -s template example exit 0; rule-only counts of sg-brand-mark and sg-theme-switch in app.css are 0 and 0 (HEAD was 15 and 11)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The theme-switch active rule contains no raw hex and resolves the same computed colours in Light and Dark; the guard passes on the real file under darwin and under ubuntu:24.04 (mawk 1.3.4, GNU grep 3.11) and fails when the raw hex is planted back"
    requirement: BGEN-04
    verification:
      - kind: other
        ref: "bash scripts/ci/admin-css-conformance.sh exit 0 (darwin and container); planted '#fdba74' in the active rule failed CHECK 2 at that row; the extracted rule has 0 hex and 3 var( colours; admin-token-completeness 100 tokens PASS"
        status: pass
    human_judgment: false
  - id: D4
    description: "The example itself still behaves after the moved rules became layered and the duplicates were deleted"
    requirement: BGEN-04
    verification:
      - kind: e2e
        ref: "unmodified tests/admin-theme.spec.ts --project=chromium --retries=0: 19 passed; tests/admin-design.spec.ts --project=admin-design-chromium --grep-invert '@snapshot' --retries=0: 14 passed; extra: admin-design-mobile and admin-design-dark 28 passed; no --update-snapshots"
        status: pass
    human_judgment: false
  - id: D5
    description: "D-11 parity reads both explicit blocks from the shipped file and pins both light and dark; the stamp is guarded on all three copies; the gap baseline shrank by exactly the seven classes now defined; the pinned dark brand-strong value is still asserted"
    requirement: BGEN-04
    verification:
      - kind: unit
        ref: "mix test test/sigra/install/features/admin_test.exs test/sigra/install/css_undefined_classes_test.exs test/sigra/brand/frozen_surface_test.exs: 83 tests, 0 failures; three mutations of the shipped file each failed the intended D-11 test"
        status: pass
    human_judgment: false
  - id: D6
    description: "Exactly one golden rebless ran; its delta is one file, purely additive, committed alone, and rebless_golden --check is clean; the text catalog for tier 1 and tier 2 is unchanged"
    requirement: BGEN-04
    verification:
      - kind: other
        ref: "delta report: added 0, modified 1, removed 0 (tree/priv/static/assets/sigra_admin.css); git diff --stat on the golden commit lists one file, 239 insertions; --check prints 'OK: fixture is up-to-date'; catalog-diff.sh tier1 and tier2 print 'no differences'"
        status: pass
    human_judgment: false
  - id: D7
    description: "Whether the generated host's explicit Dark theme looks right (the shipped stylesheet still has no .sg-admin-shell surface rule, so the page background and body text keep the root values while panels go dark)"
    requirement: BGEN-04
    verification: []
    human_judgment: true
    rationale: "The plan scope is the roadmap minimum and the computed-style assertions pass; the visual result is what the unasserted screenshots (admin-light.png, admin-dark.png, admin-system-dark.png) are for. Logged in 260-deferred-items.md plan 09 item 2 for plan 11 and Phase 261."

duration: 23min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 09: L1, the brand mark, explicit theme and theme switch in the shipped stylesheet Summary

**The generated admin shell's lockup swap, explicit Light/Dark tokens and theme-switch colours now come from the shipped `sigra_admin.css` alone (239 added lines, 0 deleted, a `/* sigra-admin-css: 1 */` stamp, no raw hex), proven red-then-green in a real generated host, with one additive golden rebless and the text catalog unchanged.**

## Performance

- **Duration:** 23 min (start 2026-11-15T20:31:13Z, end about 20:54Z), most of it waiting on three generated-host boots, an example dev boot and the install golden alias
- **Tasks:** 3 (Task 1 tracer, Task 2 auto tdd, Task 3 auto)
- **Files:** 8 product and test files plus the phase deferral log; nothing under `lib/`; under `priv/` only the one template stylesheet

## Accomplishments

- **Red first, in a real generated host (Task 1, step 1).** The new assertions were added to the existing test `generated host admin shell renders on desktop and mobile` and run against the unmodified template with `admin-acceptance-smoke.sh --test chrome`. The host booted and the login worked; the failures are on the new assertions only. First attempt: the test hit its 60 s timeout because every soft assertion waited the default 5 s (the run is kept as evidence of why a bounded timeout was added). Second attempt (3 s bound, 29.7 s): nine soft assertions failed. Lockups: `system light: dark lockup opacity` (expected 0, received 1), `explicit light: dark lockup opacity`, `explicit dark: light lockup opacity`, `system dark: light lockup opacity`. Theme switch: `active theme-switch background` in all four states (expected `rgb(253, 186, 116)`; received `rgb(239, 239, 239)` or `rgba(0, 0, 0, 0)`), and `system dark: active theme-switch text` (expected `rgb(21, 21, 21)`, received `rgb(244, 241, 235)`). Tokens: `explicit dark and explicit light resolve different --sg-color-panel` (both `#ffffff`). That is every rule the move supplies, observed missing.
- **The move (step 2).** Copied mechanically with `sed` from the example `app.css` (so "copy, not rewrite" is literal), then edited only where the plan says. In `sigra_admin.css`: the stamp as line 1; the explicit light and dark token blocks at the end of the `sg-base` layer (the dark block is the first occurrence of the explicit dark selector, the D-11 trap); brand-mark rules (with the `prefers-color-scheme` pair) and the theme-switch rules in the `sg-components` layer after the scope and topbar rules. The example copy is a `cp` of the template. Exactly the moved blocks were deleted from the example `app.css`: 195 deleted lines, none added.
- **No raw hex, no changed pixel.** The active-segment rule is `background: var(--sg-logo-rail-accent); color: var(--sg-color-ink); box-shadow: 0 10px 20px -16px var(--sg-logo-rail-accent);` plus nine selectors that set `color: var(--sg-color-on-brand-solid)` for the resolved Dark theme (explicit html attribute, explicit shell attribute, `prefers-color-scheme: dark` with neither attribute), each more specific than the default. Computed-style assertions in four states agree with the pre-move values. No token was added and no token value changed.
- **Green (step 2 end).** `--test chrome`: 1 passed (1.3 s); the smoke script's follow-on test also passed and the script printed `success`. The conformance guard, token completeness and corruption check pass. The conformance guard also passes in `ubuntu:24.04` (mawk 1.3.4, GNU grep 3.11), the CI userland. Planting `background: #fdba74` back into the active rule failed CHECK 2 at that row, so the pass is not vacuous.
- **The example itself (step 3).** The moved rules used to be unlayered (and beat layered shipped rules); they are now layered and their duplicates are gone, so the example was booted (`MIX_ENV=dev`, `PORT=4021`, throwaway database, compile `--force` because the build had another port baked in, create, migrate, seed) and the unmodified specs run: `admin-theme.spec.ts` on chromium **19 passed**, `admin-design.spec.ts` non-`@snapshot` on admin-design-chromium **14 passed**; extra, `admin-design-mobile` and `admin-design-dark` **28 passed** (the `mobile` project has no admin-theme tests: "No tests found"). No `--update-snapshots`. The server was stopped and the database dropped.
- **Tests (Task 2).** D-11 reads the explicit dark block from the shipped file and compares it with the `@media` dark block, with the `--sg-color-brand-strong: #fdba74;` pin kept; a light twin asserts every `--sg-*` value the explicit light block declares equals the root value; three mutations of the shipped file (explicit dark panel only, explicit light muted only, dark brand-strong in both blocks) each failed the intended D-11 test and were restored. The stamp tests (template, example, golden as three tests, plus a pure reader with planted bad stamps) failed only on the golden copy before Task 3 (the byte-parity row for the golden copy failed too, as it should). The baseline stale-entry test listed exactly seven classes (`sg-brand-mark`, `__image`, `__image--dark`, `__image--light`, `__lockup`, `__section`, `sg-theme-switch`) and nothing else; they were removed (56 to 49; used 153, defined 119). The frozen-surface ratchet passed without the extend writer.
- **The one rebless (Task 3).** `--check` first reported drift in exactly one file. `MIX_ENV=test mix sigra.fixture.rebless_golden` then ran once: added 0, modified 1, removed 0; the diff is 239 insertions and no deleted line; the golden copy equals the template (`cmp`); committed on its own. Afterwards `--check` is clean, `golden_diff_test` plus `asset_parity_test` pass (37 tests), and the stamp tests pass.
- **Text catalog unchanged.** Tier 1 and tier 2 re-captured in after mode (62 files): `catalog-diff.sh` prints `no differences` for each lane directory (and for the whole catalog, where the generated-host lane is the reused raw, not re-captured; plan 11 re-captures it).
- **Wider gates.** Root `mix test --exclude scaffold`: 33 doctests, 3 properties, 3132 tests, 0 failures, 12 skipped. Example `MIX_ENV=test mix test --include example_app`: 433 tests, 0 failures. `MIX_ENV=test mix ci.install_golden`: 33 tests, 0 failures. `test/sigra/brand`, `planning` and `templates`: 737 tests, 0 failures. `mix format --check-formatted`: clean.

## Task Commits

1. **Task 1 (tracer): CSS move, stamp, example resync, Playwright assertions** - `6fc5e2ccc` (feat)
2. **Task 2: D-11 reads the shipped CSS, stamp tests, baseline 56 to 49** - `fb85d241c` (test)
3. **Task 3: the single golden rebless, committed alone** - `6e8a00dff` (test)
4. **Deferral log: shell-surface gap, layering effect, rebless `--help` footgun** - `756d5b941` (docs)

**Plan metadata:** docs commit (this SUMMARY, STATE, ROADMAP, REQUIREMENTS).

Commit ledger (measured from the persisted base): `plan_head_before` `896428d3cccc40bfebe9ef41fa40b1d747376e98`, `plan_head_after` `756d5b941a55d8fb79d5d4e49e8803fc7bff562c`, `git rev-list --count` = 4. `actuals.tokens` is characters of added lines over the realized diff divided by 4 (41,951 / 4, golden copy included), against a plan estimate of 70,000; not rounded toward the estimate.

## Tracer gate

The tracer `<verify>` is automated-only (no `<human-check>`), so under `end-of-phase` the gate re-ran it before expansion: `--test chrome` green plus the three CSS guards, and the example specs against the booted dev server. All passed before Task 2 started.

## Test-first notes

Task 1 is red-first at the system level (above). Task 2 followed the TDD protocol on the existing files: the three test files were run before editing and were seen red on the intended assertions (the stale-entry test named seven classes; D-11 failed with "Could not find CSS block" because the explicit block had left the example `app.css`), then the tests were rewritten and went green, then mutated (above). ExUnit and Playwright output are not formats `gsd_run check tdd-red-evidence` classifies, so the assessment is semantic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The first red run ended in a test timeout, not a clean list of failures**
- **Found during:** Task 1 step 1
- **Issue:** each failing `expect.soft` waited the default 5 s, so the test hit its 60 s timeout partway (the token assertion was never reached) and Playwright closed the page mid-assertion.
- **Fix:** a 3 s bound (`THEME_RULE_TIMEOUT`) on the soft theme assertions (the transitions are 140 ms); the red run was repeated and listed all nine drifted rules in 29.7 s. The first run is kept as `smoke-red-1.log` evidence only.
- **Files modified:** `test/example/priv/playwright/tests/admin-generated.spec.ts`
- **Commit:** `6fc5e2ccc`

### Implementation choices that differ from the plan's literal wording

- **Generated-host smoke ran with the `PG*` and `SIGRA_TEST_PG_*` variables unset.** The plan's verify command sources `tmp/db.env`; with it exported, the generated host's `Repo` still connects to `localhost:5432` while the Ecto tasks follow `PGPORT` (the pre-existing script behavior recorded as plan 03 deferred item 2, and how plan 05 ran it). Same three commands, reaching 5432.
- **Fill and ring use `--sg-logo-rail-accent`, not `--sg-color-brand-solid`.** The orchestrator hand-off quoted plan 07's example substitution (`brand-solid` and `on-brand-solid`). That example made the guard exit 0 but would change the Light colour from `#fdba74` to `#9a3412`, which violates this plan's must-have ("resolve to exactly the same computed values as before"). The plan text (`--sg-logo-rail-accent`; ink per resolved theme) was followed.
- **Four assertion states, not two.** System light and system dark were added to explicit light and dark, because the `prefers-color-scheme` pair is a distinct code path in both the lockup rules and the new text rules; the pre-L1 red run failed in all four.
- **Light twin as a subset check.** The explicit light block states a subset of the root tokens (it is there so a Light choice beats a dark system scheme), so the twin asserts every declaration of the block equals the root declaration, plus a non-empty guard on both sides; an equality of the two sets would be false by construction.
- **Placement and comments.** Explicit blocks at the end of `sg-base`; brand-mark and theme-switch rules after the topbar block in `sg-components`, under a section comment. The comments were written to avoid the literal explicit-dark selector substring (D-11 first-match trap) and any hex literal or `px` value.
- **Verification beyond the plan.** Root suite, example suite, `ci.install_golden`, the brand/planning/templates directories, the mobile and dark gallery projects, and the guard under `ubuntu:24.04`, because the example `app.css`, the golden tree and a shipped stylesheet all changed.
- **A mistaken `mix sigra.fixture.rebless_golden --help` call** (the task's `OptionParser` is `strict` and drops `--help`, so it parses as the writer). Inferred not to have written anything (modification times of the golden files are those of the intended rebless; `--check` and `git status` clean), so the count of writer runs that wrote the tree is one. Logged as a footgun in the deferral log.

**Total deviations:** 1 auto-fixed (Rule 1) plus the choices above. **Impact on plan:** none on scope or acceptance criteria.

## Issues Encountered

- `playwright test tests/admin-theme.spec.ts --project=mobile` reports "No tests found": that spec is chromium-only. Not an error of this plan.
- The local environment exports `tmp/db.env` through direnv, so the smoke commands needed `env -u` (above). The example `_build/dev` is left compiled with `PORT=4021` and a database that no longer exists; the next `scripts/uat/up.sh --dev` self-heals a frozen-port mismatch, a plain `mix phx.server` in `test/example` needs `mix compile --force` with the intended port first.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. No endpoint, auth path, file-access pattern or schema was added. T-260-20 (moved rules change precedence or pixels): rules copied by `sed`, layer placement stated, computed-style assertions red then green in a generated host, the unmodified example specs green against the booted example after the duplicates were deleted, theme-switch colours asserted equal to the pre-move values in four states. T-260-21 (stamp carrying personal data): the stamp is a fixed integer comment; no path, name or address was added to any shipped or committed file (the screenshots stay in the gitignored Playwright output directory and are not committed).

## Remaining app.css-only rules and open findings

- No rule keyed on `data-sg-admin-theme` or on the shell's `data-theme` remains in the example `app.css`. The remaining `data-theme` rules are demo-only (`data-demo-*` and `vt-*` surfaces) and stay in the example (`260-deferred-items.md`, plan 09 item 1).
- **For plan 11 and Phase 261:** the explicit Dark theme in a generated host re-resolves tokens and swaps lockups but still does not paint a dark page: the shipped stylesheet has no `.sg-admin-shell { background; color; min-height }` rule (one of the 49 baseline classes). The unasserted screenshots `admin-light.png`, `admin-dark.png` and `admin-system-dark.png` are in the Playwright output directory of the last green `--test chrome` run (gitignored, not baselines) so plan 11 can look. Item 2 of the deferral log.
- The example's mobile theme-switch segments should now be narrower than before (the shipped small-screen override finally applies; by layer order, not measured). Item 3.

## Verification Run

| Check | Result |
| --- | --- |
| `--test chrome` against the unmodified template | RED: nine soft assertions failed on the new rules (29.7 s) |
| `--test chrome` against the modified template | GREEN: 1 passed (1.3 s); script `success` |
| `admin-css-conformance.sh`, `admin-token-completeness.sh`, `app-css-corruption-check.sh` | all pass (conformance also under ubuntu:24.04, mawk and GNU grep); planted hex in the active rule fails CHECK 2 |
| `admin-theme.spec.ts` (chromium) / `admin-design.spec.ts` non-`@snapshot` (admin-design-chromium) | 19 passed / 14 passed; mobile and dark gallery projects 28 passed |
| `mix test` admin_test, css_undefined_classes_test, frozen_surface_test | 83 tests, 0 failures (before the rebless, as the plan allows); three D-11 mutations each failed the intended test |
| `rebless_golden --check` before / after the one rebless | drift in 1 file / `OK: fixture is up-to-date` |
| `mix test` golden_diff_test, asset_parity_test (after the rebless) | 37 tests, 0 failures |
| `catalog-diff.sh` tier 1 and tier 2 after-mode vs before | `no differences` on both lane directories (and the whole catalog) |
| `mix test --exclude scaffold` / example `--include example_app` / `mix ci.install_golden` | 3132 / 433 / 33 tests, 0 failures |
| `git diff --numstat` on the template; `git status --porcelain -- lib`; `git diff --name-only -- priv` | `239 0`; empty; the one template file |
| Golden commit: `git diff --stat "$GOLDEN_SHA^..$GOLDEN_SHA"`; deleted lines | one file, 239 insertions; none deleted |

## Handoff for Plans 10 and 11

- **Plan 10 (BGEN-05 wiring):** the guards now pass on the real file with the explicit blocks inside a cascade layer, under darwin and ubuntu:24.04. The `.test.sh` twin's Test G still fails on a dirty tracked tree outside `scripts/ci` and `.planning`; wire the guard scripts, not the twin (plan 07 handoff).
- **Plan 11:** BGEN-04 is also declared by plan 11, so the requirement is marked complete only when its SUMMARY exists. Re-capture the generated-host catalog lane with a fresh host (this plan did not). Re-run the whole non-`@snapshot` gallery spec after seeding the dev database (deferral log plan 08 item 2) and look at the three screenshots (item 2 above). The dark accent contrast finding (plan 08 item 1) is still Phase 261 BTOK-03; the four `data-theme="light"` gallery pins stay until then.
- **Phase 261:** the two explicit blocks and the `@media` dark block are pinned equal by D-11; change a dark token in both. The dark `--sg-color-brand-strong` stays `#fdba74` until a token phase changes it deliberately (the pin test names the parity surfaces to update).

## Self-Check: PASSED

- Modified files exist (`[ -f ]`): the template and example `sigra_admin.css`, the example `app.css`, `admin-generated.spec.ts`, `admin_test.exs`, `asset_parity_test.exs`, `css-undefined-classes.txt`, the golden `sigra_admin.css`, `260-deferred-items.md`; the template and example and golden copies are byte-identical (`cmp`).
- All four commits (`6fc5e2ccc`, `fb85d241c`, `6e8a00dff`, `756d5b941`) are ancestors of HEAD.
- Task 1, 2 and 3 acceptance criteria re-run on the committed tree and passing; plan-level verification re-run after the last code commit (golden `--check` clean, guards pass, tests above).

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
