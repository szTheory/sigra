---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 08
subsystem: testing
tags: [brand, catalog, diff-report, design-gallery, status-pill, axe, bgen-07, bgen-08]

requires:
  - phase: 260
    provides: "Plan 05 immutable before catalog (test/fixtures/brand/before, 63 files with MANIFEST.json) and the after-mode writer to tmp/catalog-after"
provides:
  - "scripts/brand/catalog-diff.sh: per-file unified diff with relative paths plus a changed/added/removed summary, MANIFEST.json and .DS_Store ignored, 'no differences' for identical trees, --fail-on-diff, exit codes 0/1/2"
  - "Sigra.Brand.CatalogDiffTest: 20 tests over planted before/after trees and the real before directory, run by mix ci with no ci.yml edit"
  - "DesignGalleryLive 'Catalog states' section: nine catalog-* cards (two sign-in auth pages, two emails, five status words) in the host-owned neutral default look, dev-only, outside every Playwright board registry"
  - "ExampleWeb.Admin.DesignGalleryCatalogTest: 14 pure-render tests (no /admin/_design route exists in :test)"
affects: [260-09, 260-11, 262]

actuals:
  tokens: 9744
  tasks: 2
  commits: 4

plan_head_before: cce2cfb7c86ab88198bda63f9b58cb05e9c7837c
plan_head_after: 4bb9f11028aa13aa0a20afa7d4ab34a20e507a08

tech-stack:
  added: []
  patterns:
    - "A report script prints paths relative to each input directory (diff -u -L before/<rel> -L after/<rel> per file), so pasted output carries no absolute path"
    - "A LiveView render/1 of literal assigns is tested with rendered_to_string + LazyHTML queries, no route, no DB"
    - "A page-wide axe gate is shown to cover new markup by planting one violation in it and watching the gate go red"

key-files:
  created:
    - scripts/brand/catalog-diff.sh
    - test/sigra/brand/catalog_diff_test.exs
    - test/example/test/example_web/live/admin_design_gallery_catalog_test.exs
  modified:
    - test/example/lib/example_web/live/admin/design_gallery_live.ex
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-deferred-items.md

key-decisions:
  - "The report diffs file by file with diff -u -L before/<rel> -L after/<rel> instead of one diff -ru -x MANIFEST.json call: diff -ru prints the absolute input paths in every header, and the plan also requires the report to echo no absolute home path; file lists from find and comm give the changed/added/removed counts"
  - "The auth-page and email previews in the gallery are pinned to data-theme=light, not system: the shipped default dark palette draws accent text at 3.17:1 and the page-wide axe test runs in the dark project too; fixing the palette is Phase 261 BTOK-03"
  - "Suspended is a toneless sg-status-pill with the visible note 'Catalog only, not a product state'; the four product words use the tones the product already uses (ok, warn, risk, warn)"

patterns-established:
  - "A mutation of the script or markup is run against its own tests (6 script mutations, 6 markup/spec mutations), each failing the intended test, before the tests are trusted"

requirements-completed: [BGEN-07, BGEN-08]

coverage:
  - id: D1
    description: "scripts/brand/catalog-diff.sh reports changed (a -/+ pair under its relative path), added and removed files with counts, ignores MANIFEST.json and .DS_Store, prints 'no differences' for identical trees, exits 0 by default, 1 with --fail-on-diff on a difference, 2 on a usage error, and prints no absolute input path"
    requirement: BGEN-07
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_diff_test.exs (20 tests, 0 failures)"
        status: pass
      - kind: other
        ref: "6 script mutations each failed the intended tests (manifest not ignored, changed never detected, added list empty, --fail-on-diff ignored, usage exits 1, absolute labels); the same script run under ubuntu:24.04 with GNU diffutils 3.10 and bash 5.2.21 gave identical results"
        status: pass
    human_judgment: false
  - id: D2
    description: "Against the committed before directory the report prints 'no differences' for a copy of itself and, with defaults, for a fresh after-mode capture of unchanged sources (tier 2 raw re-captured, after mode re-written: 62 files)"
    requirement: BGEN-07
    verification:
      - kind: other
        ref: "bash scripts/brand/catalog-diff.sh test/fixtures/brand/before test/fixtures/brand/before | grep -q 'no differences'; bash scripts/brand/catalog-diff.sh (defaults) after SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs: 'no differences', rc 0"
        status: pass
      - kind: unit
        ref: "catalog_diff_test.exs: the real committed before directory compared with a copy of itself reports no differences; one planted byte in the copy is reported (+<!-- planted -->, changed: 1, exit 1 with --fail-on-diff)"
        status: pass
    human_judgment: false
  - id: D3
    description: "DesignGalleryLive draws nine catalog-* cards (sign-in and sign-in error auth pages, confirmation and reset email frames, five status words with the existing sg-status-pill); Suspended occurs only inside catalog-status-suspended; the section is inert (no form, no action, no phx binding) and carries only .test addresses and no home path"
    requirement: BGEN-08
    verification:
      - kind: unit
        ref: "test/example/test/example_web/live/admin_design_gallery_catalog_test.exs (14 tests, 0 failures; red 9 of 14 against the gallery before the markup, commit cae036833)"
        status: pass
      - kind: other
        ref: "6 markup/spec mutations each failed the intended tests (Suspended leaked, non-.test address, form with action, wrong tone, catalog id in CONFIG_BOARDS, home path in a card)"
        status: pass
    human_judgment: false
  - id: D4
    description: "No Playwright board array, baseline, Components markup, installer template or file under lib/ or priv/ changed; the page-wide axe test passes with the new markup in all three design projects, and the gate is shown to cover the section"
    requirement: BGEN-08
    verification:
      - kind: other
        ref: "git diff --stat cce2cfb7c..HEAD -- test/example/priv/playwright priv/templates lib priv is empty; mix test design_gallery_isolation_test.exs phase_230_design_gallery_split_test.exs: 9 tests, 0 failures"
        status: pass
      - kind: other
        ref: "npx playwright test tests/admin-design.spec.ts -g axe: admin-design-chromium 1 passed, admin-design-dark 1 passed, admin-design-mobile 1 passed (retries 0, no --update-snapshots); a planted img without alt inside catalog-status-active turned the chromium run red; whole non-@snapshot spec 42 passed across the three projects on a seeded dev database"
        status: pass
    human_judgment: false
  - id: D5
    description: "Drawing the auth-page and email previews in the light palette only (dark and system variants are not shown) until the shipped dark palette passes WCAG AA"
    requirement: BGEN-08
    verification: []
    human_judgment: true
    rationale: "A design call, not a test assertion: whether the catalog should show a dark variant of the generated auth page is a Phase 261 decision once the dark accent-on-surface pair (3.17:1) is fixed. Recorded in 260-deferred-items.md plan 08 section 1."

duration: 13min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 08: Catalog Diff Report and Gallery Catalog Section Summary

**A `catalog-diff.sh` before/after report (relative paths, changed/added/removed counts, `no differences` proven on the real before directory) and a dev-only "Catalog states" gallery section with nine `catalog-*` cards (sign-in pages, emails, five status words), tested by pure render and by the page-wide axe gate, with no board registry, baseline, shipped file or template touched.**

## Performance

- **Duration:** 13 min (start 2026-11-15T20:10:13Z, end about 20:23Z), including a dev-server axe run in three Playwright projects
- **Tasks:** 2 (Task 1 tracer, Task 2 auto, tdd)
- **Files:** 3 created, 2 modified; nothing under `lib/`, `priv/`, `priv/templates/`, the Playwright specs, the golden fixture or the before catalog; one new file under `scripts/`

## Accomplishments

- **The report (Task 1, tracer).** `scripts/brand/catalog-diff.sh [--fail-on-diff] [<before> <after>]` writes a unified diff per changed file labelled `before/<rel>` and `after/<rel>`, then `Changed files (n)`, `Added files (n)`, `Removed files (n)` lists and a `Summary: changed: 1, added: 0, removed: 0` line; identical trees print `no differences`. `MANIFEST.json` and `.DS_Store` are ignored at any depth. Defaults are `test/fixtures/brand/before` and `tmp/catalog-after`. Exit 0 is a produced report, 1 is differences with `--fail-on-diff`, 2 is a usage error (wrong argument count, unknown flag, missing directory), each with the usage text.
- **Real-flow evidence.** With the tier-2 raw re-captured and `SIGRA_BRAND_CATALOG=after` re-run on the current tree (62 files), `bash scripts/brand/catalog-diff.sh` printed `no differences`: the plan's "after-mode output of unchanged sources" truth, measured now rather than taken from plan 05's earlier run. The generated-host raw lane was reused (a phx_new host boot); `lib/` and `priv/` are byte-identical to the pin.
- **The report is proven able to fail.** 20 ExUnit tests run the real script over planted trees (identical, one changed line, removed, added, all three, manifest only, manifest on one side, `.DS_Store`, four usage errors, `--help`), then the real committed before directory against a copy of itself and against the same copy with one planted byte. Six mutations of the script each failed exactly the intended tests; the report is also verified under `ubuntu:24.04` (GNU diffutils 3.10, bash 5.2) because it runs under `mix ci` on the CI userland.
- **The gallery section (Task 2).** `render/1` needs only `%{__changed__: nil}`: the spike answer is that no extra assigns exist. The new section sits before the autofix fixture, which stays last. Auth cards use the shipped `sigra-auth-*` classes (stylesheet linked as `home.html.heex` links it), email cards the existing `sigra-auth-email-preview` frame with subject and copy taken from the host-neutral email templates and the address `catalog-user@example.test`, status cards the existing `sg-status-pill` (`ok`, `warn`, `risk`, `warn` as `user_show_live.ex` draws them; Suspended toneless with the visible note "Catalog only, not a product state").
- **The axe gate covers it, and was shown to.** `-g "axe"` passes in `admin-design-chromium`, `admin-design-dark` and `admin-design-mobile`. A planted `<img>` without `alt` in `catalog-status-active` turned the chromium run red (the section is inside the gate), the plant was restored, and the three runs were repeated green. The whole non-`@snapshot` gallery spec also passes (42 tests across the three projects) once the dev database is seeded.
- **Full suites.** Root `mix test --exclude scaffold`: 33 doctests, 3 properties, 3126 tests, 0 failures, 12 skipped. Example suite `--include example_app`: 433 tests, 0 failures. `mix format --check-formatted`: clean.

## Task Commits

1. **Task 1 (tracer): the report script and its planted-control tests** - `48a1b1c11` (feat)
2. **Task 2 RED: failing pure-render tests, 9 of 14 red on the missing section** - `cae036833` (test)
3. **Task 2 GREEN: the catalog section in the gallery** - `ec8a7d6a5` (feat)
4. **Deferral log: dark-palette contrast finding, seeded-DB note** - `4bb9f1102` (docs)

**Plan metadata:** docs commit (this SUMMARY, STATE, ROADMAP, REQUIREMENTS).

Commit ledger (measured from the persisted base): `plan_head_before` `cce2cfb7c86ab88198bda63f9b58cb05e9c7837c`, `plan_head_after` `4bb9f11028aa13aa0a20afa7d4ab34a20e507a08`, `git rev-list --count` = 4. `actuals.tokens` is characters of added lines over the realized diff divided by 4 (38,979 / 4), against a plan estimate of 40,000; not rounded toward the estimate.

## Tracer gate

The tracer `<verify>` is automated-only (no `<human-check>`), so under `end-of-phase` the gate re-ran it before expansion: `mix test test/sigra/brand/catalog_diff_test.exs` (20 tests, 0 failures) and the real-directory report printing `no differences`. Both passed; Task 2 started after that.

## Test-first notes

Task 1 was written script first (a spike run on the real before directory), then the tests; the tests went green at once, so they were not trusted until six mutations of the script each failed the intended tests (listed in D1). Task 2 followed the TDD protocol: the test file was committed first and seen red on its intended assertions (9 of 14 fail with the section missing; the other 5 are the board-registry and planted-control tests that hold before and after), then the markup made them green; six further mutations (D3) failed the intended tests. ExUnit output is not a format `gsd_run check tdd-red-evidence` classifies, so the assessment is semantic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] New gallery markup failed the page-wide axe test in the dark project**
- **Found during:** Task 2, local axe run (the plan names only the chromium project; all three run on the PR path)
- **Issue:** the first draft drew the auth previews at `data-theme="system"`. In `admin-design-dark` axe reported three `color-contrast` nodes (3.17:1 against 4.5:1): the link "Create an account" (twice) and the bold summary "Other ways to sign in", all accent text `#c2410c` on the dark surface `#211f1c`. The cause is the shipped default dark palette, not the new markup.
- **Fix:** the auth and email previews are pinned to `data-theme="light"` with a comment in the gallery naming the reason; the contrast defect is logged, not fixed (the plan may not change `priv/` or token values; Phase 261 BTOK-03 owns it). Per the plan, the new markup was fixed, not the gate.
- **Files modified:** `test/example/lib/example_web/live/admin/design_gallery_live.ex`, `260-deferred-items.md`
- **Verification:** `-g axe` green in chromium, dark and mobile; the failing dark run was observed before the change.
- **Commit:** `ec8a7d6a5` (markup), `4bb9f1102` (deferral log)

### Implementation choices that differ from the plan's literal wording

- **Per-file `diff -u -L` instead of one `diff -ru -x MANIFEST.json "$BEFORE" "$AFTER"`.** The plan names the single-call form and also requires paths relative to each input directory and no echoed absolute home path. `diff -ru` prints the absolute directory in every `diff`, `---` and `+++` header, so the two instructions conflict; the report uses relative labels. The changed/added/removed counts come from sorted `find` lists and `comm`, as the plan describes. Both Apple (FreeBSD) diff and GNU diffutils support `-L`.
- **`.DS_Store` is ignored besides `MANIFEST.json`.** macOS drops it into any directory a person opens in Finder; reporting it as an added file would make the report red for a reason unrelated to the catalog. Tested.
- **The gallery section has its own id, `catalog-states`,** so the privacy and inertness tests can extract the whole section. It is not a board id and is in no Playwright array.
- **The axe check ran in all three design projects, not only chromium,** because the untagged axe test runs in all three on the PR path (that is how the dark finding was found). The Task 2 acceptance wording ("1 passed") holds per project.
- **The dev server used a disposable database** (`example_dev_catalog_axe`, created, seeded for the behavior tests, dropped) so the shared test database was not touched, and a free port (4023) baked at compile time per the example Playwright boot practice.

**Total deviations:** 1 auto-fixed (Rule 1) plus the choices above. **Impact on plan:** none on scope; every acceptance criterion is met.

## Issues Encountered

- **First dev DB was unseeded.** Two gallery behavior tests (`MG-5 and MG-6 ... content-equivalent`, `filter form submits via real GET`) failed in all three projects with "admin users first Open user link is missing href". They are independent of the gallery markup: after `mix run priv/repo/seeds.exs` all 42 non-`@snapshot` tests passed. Logged in the deferral log for plan 11 Task 3 (it must seed before the local re-run).
- **Local build state.** The example `_build/dev` is now compiled with `PORT=4023` and `PGDATABASE=example_dev_catalog_axe` baked in (compile-time config). The next `scripts/uat/up.sh --dev` self-heals a frozen-port mismatch by wiping the stale example build; a plain `mix phx.server` in `test/example` needs `mix compile --force` with the intended port first. The server was stopped and the disposable database dropped.
- **The existing pre-compile warning** `no route path for ExampleWeb.Router matches "/dev/mailbox"` (`settings_live.ex:133`) is in the example test build and unrelated to this plan.

## Authentication Gates

None.

## Known Stubs

None. The gallery cards are intentional static literal markup (the gallery's moduledoc contract), not placeholders for missing wiring. The sign-in password field carries the fictional sample `catalog-sample`, a placeholder for a masked field, not a credential.

## Threat Flags

None. No endpoint, auth path, file-access pattern or schema was added. T-260-18: the rendered section is asserted to hold only `.test` addresses and no home-directory path (prefixes built from fragments, a planted control shows each scan can fail), and the report prints paths relative to each input directory (asserted, and the absolute-label mutation fails the test). T-260-19: no file under `priv/templates/` was added (`git ls-files priv/templates/sigra.install | grep -ci design` prints 0) and `design_gallery_isolation_test.exs` is green.

## Verification Run

| Check | Result |
| --- | --- |
| `mix test test/sigra/brand/catalog_diff_test.exs` | 20 tests, 0 failures |
| `bash scripts/brand/catalog-diff.sh test/fixtures/brand/before test/fixtures/brand/before` | `no differences` |
| `bash scripts/brand/catalog-diff.sh` (defaults) after a fresh `SIGRA_BRAND_CATALOG=after` capture | `no differences`, rc 0 |
| Script under `ubuntu:24.04` (GNU diff 3.10, bash 5.2): identical, changed/added/removed, leak check, usage | identical to darwin results, 0 absolute-path matches |
| `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/live/admin_design_gallery_catalog_test.exs` | 14 tests, 0 failures |
| `mix test test/sigra/install/design_gallery_isolation_test.exs test/sigra/planning/phase_230_design_gallery_split_test.exs` | 9 tests, 0 failures |
| `npx playwright test tests/admin-design.spec.ts -g "axe"` in admin-design-chromium / -dark / -mobile | 1 passed each (retries 0, no `--update-snapshots`) |
| Planted `<img>` without alt in the section | chromium axe red, restored, green again |
| `npx playwright test tests/admin-design.spec.ts --grep-invert '@snapshot'` (3 projects, seeded DB) | 42 passed |
| `mix test --exclude scaffold` (root) | 33 doctests, 3 properties, 3126 tests, 0 failures, 12 skipped |
| `cd test/example && MIX_ENV=test mix test --include example_app` | 433 tests, 0 failures |
| `mix format --check-formatted` | exit 0 |
| `git diff --stat cce2cfb7c..HEAD -- test/example/priv/playwright priv/templates lib priv`; `git status --porcelain -- lib priv` | both empty |
| `git diff --name-status cce2cfb7c..HEAD -- scripts` | exactly one new file, `scripts/brand/catalog-diff.sh` |

## Handoff for Plans 09 and 11

- **Plan 09 (L1)** can use `bash scripts/brand/catalog-diff.sh` (or `--fail-on-diff`) as its review artifact: capture `SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs` (tier 2 raw first with `SIGRA_CATALOG_RAW_DIR`), then diff against the before. A CSS-only change shows no catalog diff by design (the catalog is HTML text); a markup change shows as a `-`/`+` pair under its lane path.
- **Plan 11 Task 3** re-runs the whole non-`@snapshot` gallery spec against the final combined CSS: seed the dev database first (two behavior tests need a user row), and expect the new `catalog-*` section to be inside the axe scan in all three projects. If plan 09 or 261 changes the dark accent pair, the four `data-theme="light"` pins in the gallery can move back to `system`.
- **Phase 261** owns the dark accent contrast finding (`260-deferred-items.md`, plan 08 section 1).

## Self-Check: PASSED

- Created and modified files exist (`[ -f ]`): `scripts/brand/catalog-diff.sh`, `test/sigra/brand/catalog_diff_test.exs`, `test/example/lib/example_web/live/admin/design_gallery_live.ex`, `test/example/test/example_web/live/admin_design_gallery_catalog_test.exs`, `260-deferred-items.md`.
- All four commits (`48a1b1c11`, `cae036833`, `ec8a7d6a5`, `4bb9f1102`) are ancestors of HEAD; `gsd_run check evaluation-scope --plan 260-08 --commits-only` resolved them from plan subjects.
- Task 1 and 2 acceptance criteria re-run on the committed tree and passing; plan-level verification re-run after the last code commit.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
