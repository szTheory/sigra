---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 07
subsystem: testing
tags: [css-conformance, awk, grep, gnu-userland, shrink-only-baseline, bgen-04, bgen-05]

requires:
  - phase: 260
    provides: "Plan 05 immutable before catalog and the 56-class CSS gap finding (260-deferred-items.md plan 05 item 2); plan 06 asset parity (no shipped byte changes here either)"
provides:
  - "admin-css-conformance.sh accepts explicit-theme token blocks (html[data-sg-admin-theme=light|dark] .sg-admin-shell and .sg-admin-shell[data-theme=light|dark]) as protected scopes for CHECK 2 and CHECK 3, with only --sg-* and color-scheme declarations exempt"
  - "CHECK 3 (raw px) fires on GNU grep: the backslash-d line filter that made it a no-op on the ubuntu runner is now [0-9]+"
  - "Self-test cases H, I, I2, J, K (24 assertions in total), observed failing against the old guard and passing on darwin plus mawk and gawk under ubuntu:24.04"
  - "Sigra.Test.Brand.CssGap and a shrink-only baseline of 56 shipped-CSS-undefined sg-* classes, checked in both directions"
affects: [260-09, 260-10, 260-11]

actuals:
  tokens: 8123
  tasks: 2
  commits: 2

plan_head_before: 38f723e1501245d3e75a012dcd195d1fb744bd21
plan_head_after: fd4e3d287700d07ca05168c4e054b151b74fc50d

tech-stack:
  added: []
  patterns:
    - "One awk scope stripper shared by CHECK 2 and CHECK 3 so the two checks cannot drift"
    - "Guard scope is an exact-selector allow-list with a body classifier that emits everything except a single --sg-* or color-scheme declaration (or its continuation, blank line, comment, closing brace)"
    - "Shrink-only baseline: growth and stale-entry checks are pure functions that return {:error, message}, so a planted control can call the same function the real assertion calls"
    - "A bash guard is proven under the CI userland (ubuntu:24.04 container, repo mounted read-only), not only on darwin"

key-files:
  created:
    - test/support/brand/css_gap.ex
    - test/sigra/install/css_undefined_classes_test.exs
    - test/fixtures/brand/css-undefined-classes.txt
  modified:
    - scripts/ci/admin-css-conformance.sh
    - scripts/ci/admin-css-conformance.test.sh

key-decisions:
  - "CHECK 2 and CHECK 3 share one strip_protected_scopes awk function instead of two edited copies, so the explicit-theme rule cannot be extended in one check and forgotten in the other"
  - "The explicit-theme scope matches the whole selector list against four exact strings, never a prefix, so brand-mark and theme-switch rules (which also start with html[data-sg-admin-theme...]) cannot enter it"
  - "The theme-switch active rule with raw hex stays a violation: plan 09 must tokenise it, the guard does not exempt it"
  - "The baseline records 56 classes (53 defined only in example app.css, 3 nowhere), not the RESEARCH figure of 59, because the prescribed extraction copies the frozen-surface class-attribute helpers"

patterns-established:
  - "A red run of a guard on real data is produced before the change (the real explicit Light/Dark blocks, 41 violation rows), then the same data tokenised only where the guard says it must be"
  - "A new bash case that depends on the userland (CHECK 3 on GNU grep) is reproduced red in a container before it is trusted"

requirements-completed: [BGEN-04, BGEN-05]

coverage:
  - id: D1
    description: "The conformance guard accepts the real explicit Light/Dark token blocks and nothing wider: the real excerpt failed CHECK 2 before (41 rows) and, with only the raw-hex theme-switch rule tokenised, exits 0 after; hex in a normal rule beside a block, in a brand-mark rule sharing the html[data-sg-admin-theme] prefix, in a non-explicit token block, in a mixed selector list, in a non-token declaration and in a declaration smuggled onto a --sg-* line all still fail"
    requirement: BGEN-05
    verification:
      - kind: other
        ref: "bash scripts/ci/admin-css-conformance.test.sh (24 passed, 0 failed) on darwin and under ubuntu:24.04 with mawk 1.3.4 and gawk 5.2.1"
        status: pass
      - kind: other
        ref: "bash scripts/ci/admin-css-conformance.sh on the real shipped sigra_admin.css exits 0; bash scripts/ci/admin-token-completeness.sh and its self-test pass unchanged on darwin and in the container"
        status: pass
    human_judgment: false
  - id: D2
    description: "CHECK 3 (raw px) fires on GNU grep: planted 'padding: 13px' passed the unfixed guard under ubuntu:24.04 (exit 0) and failed on darwin; after the [0-9]+ fix it fails under both, and the 1px/0px/negative allowlist is unchanged"
    requirement: BGEN-05
    verification:
      - kind: other
        ref: "case K in admin-css-conformance.test.sh; new self-test against the old guard in ubuntu:24.04: 6 failures including both K assertions (red), against the new guard: 0"
        status: pass
      - kind: other
        ref: "grep -c backslash-d scripts/ci/admin-css-conformance.sh prints 0 (was 1)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The shipped-CSS gap is a committed shrink-only baseline of 56 classes: growth fails with the new class names, a baseline entry that became defined fails with 'remove from baseline'; both seen failing on the real file and on planted in-memory controls"
    requirement: BGEN-04
    verification:
      - kind: unit
        ref: "test/sigra/install/css_undefined_classes_test.exs (12 tests, 0 failures); mix format --check-formatted on both new .ex/.exs files"
        status: pass
      - kind: other
        ref: "real-baseline mutations: deleting sg-toolbar failed only the growth test; adding sg-admin-shell failed only the stale test; both restored, 12 tests green"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 07: Explicit-Theme Guard Scope and Shipped-CSS Gap Baseline Summary

**The CSS conformance guard now accepts the real explicit Light/Dark token blocks (exact-selector scope, only `--sg-*` and `color-scheme` exempt) and its raw-px check actually fires on the GNU grep that CI runs, and the 56-class shipped-CSS gap is a committed baseline that can neither grow nor go stale.**

## Performance

- **Duration:** 7 min (start 2026-11-15T20:01:10Z, end 2026-11-15T20:08:10Z)
- **Tasks:** 2 (Task 1 tracer, Task 2 auto, tdd)
- **Files:** 3 created, 2 modified; nothing under `lib/`, `priv/`, `test/example/`, the golden fixture or the before catalog

## Accomplishments

- **The reproduced red (Task 1).** An excerpt of the real explicit light and dark token blocks plus the theme-switch active rule, cut from the example `app.css`, failed the unfixed guard at CHECK 2 ("raw hex color outside :root found", exit 1, 41 offending rows). With the new scope the same excerpt leaves only the three raw-hex lines of the theme-switch rule (`background: #fdba74`, `color: #151515`, `box-shadow ... #fdba74`). Replacing just those with `var(--sg-color-brand-solid)` and `var(--sg-color-on-brand-solid)` makes it exit 0. That is the contract plan 09 inherits: move the token blocks verbatim, tokenise the theme-switch rule.
- **Differential check on real CSS.** Old and new guard run on the shipped `sigra_admin.css`, the example copy, `sigra_auth.css` and the example `app.css`: identical results on the first three. On `app.css` the new guard drops 38 rows (lines 1572 to 1629, all inside the two token blocks) and adds none.
- **CHECK 3 was blind on CI (found and fixed).** Its first filter used a backslash-d shorthand that GNU `grep -E` does not support, so on the ubuntu runner it matched a literal `d` and could never fire. Measured before the edit: planted `padding: 13px` exited 0 under `ubuntu:24.04` and exited 1 on darwin. The filter is now `[0-9]+`. The real shipped stylesheet passes CHECK 3 under GNU (it was never actually checked there before). Neither guard is wired into `mix ci` yet; plan 10 wires them, so this was latent.
- **The guard is exercised under the CI userland.** The self-test, the guard on the real file, `admin-token-completeness.sh` and its self-test all pass inside `ubuntu:24.04` (linux/amd64, mawk 1.3.4 and GNU grep 3.11, repo mounted read-only), and the self-test also passes under gawk 5.2.1 installed in the same image. Run against the OLD guard in the same container, the new self-test fails 6 assertions (case H, the two isolation checks of I and J, and every case K and px-in-theme-block assertion); on darwin against the old guard it fails 3 (K passes there because BSD grep supports the shorthand). That pair is the red evidence for the new cases.
- **Cases H, I, I2, J, K.** H: explicit blocks in both selector shapes (multi-line list with a trailing comma, one-line list in either order), a multi-line `--sg-elev-2` declaration, a trailing comment, a `--sg-space-1: 4px` token and an `@media` `:not()` look-alike exit 0. I: `.foo { color: #fff; }` after an explicit block fails with exactly that one row (scope does not leak). I2: hex in a brand-mark rule that shares the `html[data-sg-admin-theme="dark"]` prefix, in a `--sg-*` block under a non-explicit selector, in a mixed selector list, and in the real-shaped theme-switch rule all fail. J: a non-token declaration with hex inside a block fails with exactly one row, a declaration smuggled onto a `--sg-*` line fails, and `padding: 13px` inside a block fails CHECK 3 while the `--sg-space-1: 4px` token stays exempt. K: planted raw px fails, and `border-width: 1px`, `padding: 0px`, `width/height: 1px`, a negative margin and a `var()` still pass.
- **Baseline of 56 (Task 2).** `Sigra.Test.Brand.CssGap` copies the frozen-surface extraction (class attributes in `lib/sigra/admin/**` and `priv/templates/sigra.install/admin/**`; selectors in the shipped `sigra_admin.css`). Measured: 153 classes emitted, 112 defined in the shipped file, 56 undefined = 53 defined only in the example `app.css` plus 3 defined nowhere (`sg-branding-editor`, `sg-cluster--2`, `sg-stack--4`). The brand-mark (`sg-brand-mark*`, 6 entries) and `sg-theme-switch` classes are in the list, which is what plan 09 removes.
- **Both directions seen failing.** On the real baseline: deleting `sg-toolbar` failed only the growth test ("grew by 1 class(es): sg-toolbar"); adding `sg-admin-shell` failed only the stale test ("remove from baseline ... sg-admin-shell"); both restored. The in-memory controls (a planted used class, a defined class planted into an exactly-right baseline, one real entry dropped) pass because the checks fail as intended.

## Task Commits

1. **Task 1: tracer, explicit-theme scope, portable CHECK 3, cases H/I/I2/J/K** - `cf80fd06b` (test)
2. **Task 2: shrink-only baseline, `CssGap`, test** - `fd4e3d287` (test)

**Plan metadata:** docs commit (this SUMMARY, STATE, ROADMAP).

Commit ledger (measured from the persisted base): `plan_head_before` `38f723e1501245d3e75a012dcd195d1fb744bd21`, `plan_head_after` `fd4e3d287700d07ca05168c4e054b151b74fc50d`, `git rev-list --count` = 2. `actuals.tokens` is characters of added lines over the realized diff divided by 4 (32,495 / 4), against a plan estimate of 45,000; not rounded toward the estimate.

## Tracer gate

The tracer `<verify>` is automated-only (no `<human-check>`), so under `end-of-phase` the gate re-ran it: self-test, guard on the real file and token-completeness on darwin, then the same four commands in `ubuntu:24.04`. Both passed before expansion to Task 2.

## Test-first notes

Task 1 was written test-first against real data: the red was the unfixed guard failing on the real explicit-block excerpt and, separately, the unfixed guard passing a planted `13px` under GNU. Task 2's tests were written before the baseline file existed (7 of 12 failed on the missing file, the support module already existed because the tests compile against it), then the baseline was generated from the module and the tests went green. The more meaningful red, mutations of the real baseline, is recorded above. ExUnit and bash output are not formats `gsd_run check tdd-red-evidence` classifies, so the assessment is semantic.

## Deviations from Plan

### Implementation choices that differ from the plan's literal wording

- **One shared awk function, not two edited copies.** The plan says to edit both copy-pasted awk blocks and keep them in step. Both checks now call `strip_protected_scopes`, which makes "in step" structural. The differential run on the real CSS files shows the :root behaviour is unchanged. The unusual `break`-on-scope-exit quirk of the original loop is kept as is.
- **More cases than the three named.** Besides H, I, J and K, case I2 (look-alike selectors) and extra assertions in J (smuggled declaration, raw px inside a block) were added because the threat register item T-260-17 is about scope width, and a prefix-sharing brand-mark rule is the likeliest leak.
- **Baseline count is 56, not about 59.** RESEARCH gave 59 (56 plus 3). The prescribed extraction (a copy of the frozen-surface helpers) yields 56 in total, of which 53 are in the example `app.css` and 3 nowhere. The three defined-nowhere names match RESEARCH exactly. A looser "any `sg-` token anywhere in the roots" scan gives 75 (it picks up cascade-layer names, JS-referenced `sg-cmdk*` and toast classes), so 59 cannot be reproduced from either method; the class-attribute method is the one the plan names, and the baseline lists the actual set so it is correct whatever the count.
- **Test G is vacuous inside the container.** `ubuntu:24.04` has no `git`, so Test G passes there without checking anything. It does check on darwin, where the tree was clean after the commits.
- **Decoupled controls (fixed before commit).** The first draft of the planted growth control asserted "grew by 1" against the committed baseline, so mutating the real baseline (control A) also broke the planted control. The controls now start from an exactly-right in-memory baseline (the real undefined set), so only the real test fails when the file is mutated.

**Total deviations:** 0 Rule 1 to 4 deviations; the choices above. **Impact on plan:** none on scope or acceptance criteria.

## Issues Encountered

- The shell used by the tool is zsh, so a `${PIPESTATUS[0]}` in a one-off check printed an empty exit code; exit codes were re-captured with `$?` or `pipestatus`. No product effect.
- `mix run -e` was first called without the `OUT` environment variable and failed on `File.write!(nil, ...)`; re-run with the variable set. No product effect.

## Handoffs

- **Plan 09 (L1):** move the token blocks verbatim; the selectors must stay the four exact strings above (the D-11 test and this guard both match them literally). The theme-switch active rule must use tokens, not `#fdba74`/`#151515`, or CHECK 2 fails on the real file. Remove from the baseline exactly the classes plan 09 defines (the `sg-brand-mark*` entries and `sg-theme-switch`); the stale check fails if any is left.
- **Plan 10 (BGEN-05 wiring):** the guards are not in `mix ci`. When wired, the first PR run is the first time CHECK 3 runs on the ubuntu runner outside this plan's container proof. `admin-css-conformance.test.sh` Test G fails on a dirty tracked tree outside `scripts/ci` and `.planning`; wire the guard scripts, not the twin, or scope Test G first (PATTERNS finding 5).

## Known Stubs

None.

## Threat Flags

None. T-260-17 (guard scope too broad) is mitigated and evidenced: scope is exact-selector, the body classifier emits everything except a single `--sg-*` or `color-scheme` declaration, and cases I, I2 and J are planted controls seen failing against the old and passing against the new guard.

## Self-Check: PASSED

- Created files exist: `test/support/brand/css_gap.ex`, `test/sigra/install/css_undefined_classes_test.exs`, `test/fixtures/brand/css-undefined-classes.txt` (FOUND); modified: both conformance scripts (FOUND).
- Commits `cf80fd06b` and `fd4e3d287` are ancestors of HEAD; `check evaluation-scope --plan 260-07 --commits-only` resolved both.
- Acceptance criteria re-run on the committed tree: self-test 24 passed, 0 failed (darwin and container); guard on the real file exit 0; token-completeness and its self-test pass; `grep -c` of the backslash-d shorthand prints 0; `git diff --name-only 38f723e15..HEAD -- lib priv` is empty; baseline duplicate-free; `mix format --check-formatted` clean on the new `.ex`/`.exs`; `regen_guard_test.exs` plus the new test 22 tests, 0 failures; `test/sigra/brand` plus `test/sigra/planning` 596 tests, 0 failures.
