---
phase: 231-gate-honesty-nightly-revival
plan: GAP-GATE02
subsystem: infra
tags: [css, reflow, wcag, playwright, ci, github-actions, sigra-auth, gap-closure]

requires:
  - phase: 231-02
    provides: "231-02-DIAGNOSIS.md's instrumented-run evidence (H1 killed, H2 operative) and the leaf-only min-width: 0 fix this task found insufficient"
provides:
  - "the complete WCAG 1.4.10 reflow containment fix for the generated-host auth shell at 320px / 32px root font, verified across four evidence-driven rounds"
  - "an extended reflow diagnostic (fontFamily, minWidth, rootFontSize) in admin-generated.spec.ts, used live to drive rounds 2-4"
  - "8/8 dispatched CI runs green on the final commit (70bed477), following two intermediate rounds that were red and diagnosed before being fixed"
  - "two reported-not-fixed defects: the audit-presets Actor-filter race, and test/example/priv/static/assets/sigra_auth.css's mirror drift"
affects: [231-07, 231-11]

tech-stack:
  added: []
  patterns:
    - "grid/flex item automatic-minimum-size containment (min-width: 0) must be applied at EVERY nested grid/flex layer independently -- a fix at one layer does not propagate to descendant or ancestor grid contexts"
    - "overflow-wrap: anywhere (not break-word) is required wherever a flex/grid item's own intrinsic min-content size must shrink -- break-word only affects render-time wrapping, not the intrinsic-sizing calculation used for track/basis sizing"
    - "CSS specificity conflicts between a broad new selector and a narrower pre-existing one can silently override an already-correct declaration -- verify with live evidence, not just visual review, when adding a broad selector alongside existing narrow ones on the same properties"

key-files:
  created:
    - .planning/phases/231-gate-honesty-nightly-revival/231-GAP-GATE02-SUMMARY.md
  modified:
    - priv/templates/sigra.install/core/sigra_auth.css
    - test/example/priv/static/assets/sigra_auth.css
    - test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css
    - test/example/priv/playwright/tests/admin-generated.spec.ts

key-decisions:
  - "Fixed the CSS across four evidence-driven rounds rather than stopping after round 1's plausible-looking fix -- each round's live CI evidence named the next offender, and round 3 introduced then round 4 fixed a genuine regression (CSS specificity silently overriding the wordmark's overflow-wrap), caught live before being reported as fixed."
  - "Did not declare victory on round 1's or round 2's samples (4/5 and 2/5 pass respectively) -- both were red enough on repeat sampling to disqualify a 'proven' verdict, matching this task's own mandate not to repeat 231-02's single-green-run error."
  - "Did not fix the audit-presets race or the full sigra_auth.css mirror-drift scope -- both are reported per the task's explicit instruction to report, not fix, defects outside the reflow containment mechanism."
  - "Left GATE-02's enable step (deleting ci.yml:1674's stale if: clause) untouched -- that remains 231-07's job under D-24's locked sequencing."

requirements-completed: []

coverage:
  - id: D1
    description: "Root cause verified directly against the generated markup and compiled CSS before any fix was written: .sigra-auth form is display:grid, Phoenix 1.8's default <.input> wraps every field in a grid-item <div class=\"fieldset mb-2\">, and DaisyUI's compiled .fieldset is itself display:grid"
    requirement: "GATE-02"
    verification:
      - kind: other
        ref: "priv/templates/sigra.install/core/sigra_auth.css:632-636 (form), test/example/lib/example_web/components/core_components.ex:277-297 (<.input> markup), test/example/priv/static/assets/default.css:1651-1658 (compiled .fieldset)"
        status: pass
    human_judgment: false
  - id: D2
    description: "CSS fix shipped across four rounds, each driven by a live CI failure payload naming the next offender; mirrored into the example twin and the re-blessed golden fixture at every round, byte-identical to the template each time"
    requirement: "GATE-02"
    verification:
      - kind: other
        ref: "mix sigra.fixture.rebless_golden --check (exit 0, byte-identical) + MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs (2 tests, 0 failures) run after every commit (34e7ddb8, 0e59f598, e4a2509d, 70bed477)"
        status: pass
    human_judgment: false
  - id: D3
    description: "reflow diagnostic extended with fontFamily/minWidth/rootFontSize per Task 3, without weakening the assertion; used live across rounds 2-4 to identify each successive offender and diagnose the round-3 regression"
    requirement: "GATE-02"
    verification:
      - kind: e2e
        ref: "test/example/priv/playwright/tests/admin-generated.spec.ts:185-228; npx playwright test --list tests/admin-generated.spec.ts (9 tests resolve, unchanged) after every commit"
        status: pass
    human_judgment: false
  - id: D4
    description: "multi-run CI proof: round 1 (5 runs, 4 pass / 1 fail) and round 2 (6 runs incl. PR-skip, 2 pass / 4 fail) diagnosed two further offenders; round 3 (7 runs, 0 pass / 7 fail) caught a self-introduced regression; round 4, the corrected commit, is 8/8 pass"
    requirement: "GATE-02"
    verification:
      - kind: e2e
        ref: "round 4 run IDs 30519167723/171389/175220/179013/182596/186296/190135/193712, all job \"Generated admin Playwright smoke\" conclusion success, log contains \"Running 9 tests using 1 worker\" -> \"8 passed\" -> \"1 passed\" with zero failed lines (confirmed directly for 30519167723 / job 90795579823)"
        status: pass
    human_judgment: false
  - id: D5
    description: "two defects reported, not fixed, per explicit task instruction: the audit-presets Actor-filter race and the sigra_auth.css mirror-drift scope"
    requirement: "GATE-02"
    verification:
      - kind: other
        ref: "test/example/priv/playwright/tests/admin-generated.spec.ts:454-458 (race); test/example/priv/static/assets/sigra_auth.css (412 lines) vs priv/templates/sigra.install/core/sigra_auth.css (1134 lines) diff (drift scope)"
        status: pass
    human_judgment: false

duration: ~3h
completed: 2026-07-30
status: complete
---

# Phase 231 GATE-02 Gap-Closure: 320px Reflow Containment (Rounds 1-4) Summary

**231-02's single leaf-only `min-width: 0` fix was proven insufficient by live evidence: this task fixed the same grid-item-automatic-minimum-width mechanism at three more nested layers (fieldset/label, the DaisyUI `.label` span, and h1-h3/p), caught and fixed a self-introduced CSS-specificity regression along the way, and only declared the lane proven after the fourth round landed 8 consecutive green dispatched runs.**

## Why this task existed

231-02 declared GATE-02's 320px reflow assertion fixed after **one** green dispatched
CI run (`30501223643`). That verdict was false: `Generated admin Playwright smoke` had
already failed 3 of 5 runs (~60%) with 231-02's fix (`d240ba28`) in the tree, and the
failure payload was byte-for-byte identical to the pre-fix sample recorded in
`231-02-DIAGNOSIS.md`. This task re-diagnosed the root cause from the actual generated
markup and compiled CSS (not inference), fixed it, and — per the task's explicit mandate
— proved it with a genuine multi-run sample rather than repeating 231-02's mistake.

## Verified mechanism (Task 1's root cause)

`.sigra-auth form` is `display: grid` (`sigra_auth.css:632-636`, unchanged by this task).
Phoenix 1.8's default `<.input>` core component wraps every non-checkbox field in
`<div class="fieldset mb-2"><label>...<span class="label mb-1">...</span>...</label></div>`
(`core_components.ex:277-297`), making that `<div class="fieldset">` a **grid item of the
form**. DaisyUI's compiled `.fieldset` class is *itself* `display: grid;
grid-template-columns: 1fr;` (`default.css:1651-1658`). A grid item's automatic minimum
width resolves to its own min-content unless explicitly zeroed — 231-02's fix zeroed the
leaf `input`/`.input`/button, but never the un-contained `.fieldset`/`label` ancestor, so
the ancestor's min-content floor still propagated the overflow to every descendant.

## The four rounds (each driven by live CI evidence, not inference)

### Round 1 — grid-item ancestor containment (commit `34e7ddb8`)

Added `.sigra-auth form :where(.fieldset, label) { min-width: 0; }`, matching 231-02's own
offender list (`DIV.fieldset`, `LABEL`, `SPAN.label`, `INPUT`, `BUTTON` all sharing right
edge `343.4375`). Dispatched 5 fresh CI runs at commit `6ab53947` (the diagnostic-extension
commit, same fix content): **4 pass, 1 fail** (`30516078319`). The failure's new payload
(`scrollWidth: 343`, only 3 offenders: `SPAN.label mb-1` at `343.4375`, `H2`/`P` at
`321.4375`) proved the fix *worked* — 5 of the original 8 offenders (fieldset, label,
input, button, one unlabeled span) no longer appeared — but was **incomplete**: the
`SPAN.label` itself, bit-identical to its pre-fix value, was still the true overflow
source, with the eliminated ancestors having only been *following* its min-content floor.

### Round 2 — label text containment (commit `0e59f598`)

DaisyUI's compiled `.label` utility sets `white-space: nowrap` on the `<span
class="label mb-1">` field-label wrapper — a nowrap span cannot shrink below its full
unbroken text width regardless of ancestor `min-width`. Added
`.sigra-auth .label { white-space: normal; }`, mirroring the existing
`.sigra-auth-action` button-text override for the identical reason. Dispatched 6 fresh
runs: **2 pass, 4 fail** (`30517148709`, `30517151963`, `30517155263`, `30517158617`, all
bit-identical: `scrollWidth: 321`, offenders narrowed to exactly `H2` and `P` sharing
right edge `321.4375`). The `SPAN.label` offender was gone — round 2 worked — but a
smaller (~1.4px), still-real residual remained.

### Round 3 — h1-h3/p containment, **with a self-introduced regression** (commit `e4a2509d`)

`H2` and `P` are themselves direct grid items of `.sigra-auth-stack--2` (a
single-implicit-column grid), and neither had `min-width: 0`. Because grid items in a
shared column track default to `stretch`, both were being widened to match whichever
sibling's min-content was largest (the `<p>` copy's longest unbreakable word, e.g.
"organization's" in the enterprise-sign-in description). Added `min-width: 0` plus
`overflow-wrap: break-word; word-break: normal;` to `.sigra-auth h1, h2, h3, p`.

Dispatched 7 fresh runs: **0 pass, 7 fail** — every single run — with a dramatically
different, much larger failure: `scrollWidth` 445-473px against `innerWidth` 320px
(runs `30518012012`, `30518015684`, and five more), offenders including
`.sigra-auth__brand`, `.sigra-auth__product` (the wordmark `<p>`), and the whole flow
stack sharing one edge. This offender set — the wordmark specifically — had never
appeared once across ~20 prior diagnostic runs (231-02's original sample nor rounds 1-2).
**Root cause of the regression:** the new `.sigra-auth p` selector (specificity 0,1,1)
is more specific than the pre-existing `.sigra-auth__product { overflow-wrap: anywhere;
}` rule (0,1,0) and appears later in the file, so it silently overrode the wordmark's
`overflow-wrap` from `anywhere` to `break-word`. Per the CSS Text spec, only `anywhere` —
not `break-word` — participates in a flex/grid item's automatic-minimum-size
calculation; `break-word` only affects actual render-time wrapping, not the intrinsic
min-content contribution used for track/basis sizing. Overriding it reintroduced an
un-contained min-content floor on the wordmark, at the exact mechanism this whole task
has been fixing.

### Round 4 — regression fix, confirmed (commit `70bed477`)

Changed the round-3 rule to `overflow-wrap: anywhere` (dropping `word-break: normal`,
which is redundant with `anywhere`), matching `.sigra-auth__product`'s already-proven
value so the cascade agrees everywhere instead of silently overriding it. Dispatched 8
fresh runs: **8 pass, 0 fail** (`30519167723`, `30519171389`, `30519175220`,
`30519179013`, `30519182596`, `30519186296`, `30519190135`, `30519193712` — every job
conclusion `success`, confirmed directly for `30519167723` / job `90795579823`:
`Running 9 tests using 1 worker` -> `8 passed` -> `1 passed`, zero `failed` lines).

## Multi-run tally (full record, all four rounds)

| Round | Commit | Fix | Runs dispatched | Pass | Fail | Run IDs (fail) |
|---|---|---|---|---|---|---|
| 1 | `34e7ddb8` (evidence via `6ab53947`) | `.fieldset`/`label` `min-width: 0` | 5 | 4 | 1 | `30516078319` |
| 2 | `0e59f598` | `.label` `white-space: normal` | 6 (+1 PR-skip, not counted) | 2 | 4 | `30517148709`, `30517151963`, `30517155263`, `30517158617` |
| 3 | `e4a2509d` | h1-h3/p `min-width:0` + `break-word` (buggy) | 7 (+1 PR-skip) | 0 | 7 | `30518012012`, `30518015684`, `30518019506`, `30518023143`, `30518027206`, `30518031191`, `30518035147` |
| 4 | `70bed477` | h1-h3/p `overflow-wrap: anywhere` (corrected) | 8 (+1 PR-skip) | **8** | **0** | none |

Total: 26 dispatched `workflow_dispatch` runs across four rounds (plus one automatic
PR-triggered run per push, correctly `skipped` on every round since `ci.yml:1674`'s
stale `if:` clause — untouched by this task — still gates the job off PRs; 231-07 owns
removing that clause). Every round's fix content was verified against live evidence
before moving to the next round; no round was declared "fixed" on fewer than 5
observations, and round 3 (which had none — its regression was caught within the first
2 of 7 completions) was never reported as a success.

**Dispatch mechanism:** every dispatch used
`gh workflow run "CI" --ref worktree-discuss-231 -f recapture_branch=worktree-discuss-231`
(231-02's documented escape hatch past `release_ref_guard`). Each dispatch also
triggers the two amd64 recapture jobs, which opened baseline-recapture PRs
(`#138`-`#163`, 26 total) targeting `worktree-discuss-231`; all were closed with an
explanatory comment and their branches deleted immediately after use. `gh pr list
--repo szTheory/sigra --base worktree-discuss-231 --state open` returns empty after
cleanup.

## Statistical confidence

Round 4's 8/8 is not being read as a bare coin-flip statistic — each of the four rounds
is a **causal** chain: every red run named a specific offender, that offender was fixed,
and the *next* round's red runs (if any) named a *different* offender that the previous
fix did not reach, never a recurrence of an already-fixed one. Round 3's 0/7 (the
regression) and round 4's 8/8 (the correction) are the sharpest evidence: an identical
diagnostic harness, one single-line CSS change apart, went from unanimous failure to
unanimous success. That said, taken as a pure frequentist sample: 8 consecutive passes
against the ~38-60% historical failure rate 230/231-02 measured would occur roughly
0.02%-1.7% of the time by chance if the true rate were unchanged — reasonable but not
absolute evidence, consistent with genuinely having removed the mechanism rather than
gotten lucky. **Residual honest uncertainty:** no CSS-only fix can rule out a genuine
font-rendering-timing race at the sub-pixel level with certainty from 8 samples alone;
if GATE-02's enable step (231-07) sees any red on the generated-host lane after this
fix lands on PRs, the diagnostic payload (now carrying `fontFamily`/`minWidth` on the
first offender and `rootFontSize`) is already in place to name the next offender rather
than requiring re-instrumentation.

## Font hypothesis: what the evidence now shows

The task's stated hypothesis was that sans-serif fallback resolution varies across CI
runners, shifting a text-metric-driven min-content floor across the 320px boundary. The
extended diagnostic captures `getComputedStyle(offender).fontFamily`, the offender's own
`minWidth`, and the root font-size on every failing run. **What was actually observed:**
`fontFamily` was **identical** (`ui-sans-serif, system-ui, -apple-system,
BlinkMacSystemFont, "Segoe UI", sans-serif`) on every single failing run across all four
rounds — because `getComputedStyle().fontFamily` returns the **authored** CSS
font-family stack, not the browser's **resolved** rendering font. This is a genuine
limitation of the diagnostic as specified: it cannot distinguish "the same font was used
every time" from "a different font in the fallback chain was silently substituted every
time," because the API does not expose which member of the stack the engine actually
selected. The hypothesis is therefore **neither confirmed nor killed** by this evidence —
it is **untestable with the instrumentation as specified**. What the evidence *does*
show, independent of the font-substitution question, is that the underlying overflow
was **fully explained by CSS containment gaps at three real, findable layers** (grid-item
ancestors, nowrap label text, and h1-h3/p intrinsic sizing) — every offender observed
across all four rounds was traceable to one of those three fixes, and none required
invoking font substitution as an explanation. Whatever residual sub-pixel variance drives
which specific runs flip pass/fail bit-for-bit-identically within a round (e.g. round
2's 2/6 vs 4/6 split on an identical commit) remains unexplained by this task, but its
*effect* is now fully contained by the CSS fixes regardless of its cause — a run-to-run
difference too small to matter once no single unbreakable content run can force overflow.

## Two defects reported, not fixed (per explicit instruction)

### 1. Audit-presets Actor-filter race

`test/example/priv/playwright/tests/admin-generated.spec.ts:454-458`:
```
await page.getByLabel("Actor", { exact: true }).fill(actorId);
await page.getByRole("button", { name: "Apply filters" }).click();
await expect(page).toHaveURL(new RegExp(`(?:\\?|&)actor=${actorId}(?:&|$)`));
```
Read-only investigation confirms the description exactly: `expect(page).toHaveURL(...)`
polls waiting for the URL to carry `actor=<uuid>`, but the URL stays pinned to the prior
preset's query string (`action_prefix=admin.impersonation&...&outcome=failure`) — the
"Actor" field fill does not reach submitted-filter state before or at the "Apply
filters" click. This is a distinct defect from the reflow bug, located in a completely
different test in the same file, and was **not** touched or bundled with the CSS fix
per the task's explicit instruction.

### 2. `sigra_auth.css` mirror drift (W-2, confirmed and scoped)

`test/example/priv/static/assets/sigra_auth.css` is **412 lines** against the
template's **1134 lines** (post this task's four rounds; it was 398 vs 1097 before).
`diff -u` between the two shows the template carrying ~735 lines of content the example
twin lacks entirely — confirmed missing: the `.sigra-auth .input` selector (only
`input[type="email"|"password"|"text"]` are covered, no `.input`/`textarea`/`select`/
`input[type="number"]`), the entire `.sigra-auth-action` / `:where(.btn, button)`
button-styling block (zero occurrences of `sigra-auth-action` in the example file), and
whole structural sections. The `generated_admin_playwright_smoke` job does **not** read
this file at runtime — it scaffolds a fresh app via `mix sigra.install`, which reads the
**template**, not the example's static assets — so this drift is confirmed **not** the
cause of any GATE-02 failure observed in this task. It is a real, pre-existing
correctness gap (this task's own three fixes were mirrored into it as targeted edits
only, following 231-02's own established pattern of not reconciling the full drift) that
will bite whichever lane eventually **does** read this file at runtime. **Not fixed
here** — the scope (~700 missing lines, entire missing sections) is too large to
reconcile safely and verifiably within this gap-closure task; flagged as a tracked
follow-up for whichever future plan owns `test/example`'s static-asset parity.

## Task Commits

1. **Round 1 — grid-item containment fix** - `34e7ddb8` (fix)
2. **Diagnostic extension (fontFamily/minWidth/rootFontSize)** - `6ab53947` (feat)
3. **Round 2 — label text wrap fix** - `0e59f598` (fix)
4. **Round 3 — h1-h3/p containment (introduced a regression)** - `e4a2509d` (fix)
5. **Round 4 — regression fix (corrected round 3)** - `70bed477` (fix)

## Files Modified

- `priv/templates/sigra.install/core/sigra_auth.css` — four rounds of containment fixes:
  `.sigra-auth form :where(.fieldset, label) { min-width: 0; }`,
  `.sigra-auth .label { white-space: normal; }`, and
  `.sigra-auth h1, h2, h3, p { min-width: 0; overflow-wrap: anywhere; }` (the last,
  corrected in round 4 from an initial `break-word` that regressed the wordmark).
- `test/example/priv/static/assets/sigra_auth.css` — all three fixes mirrored as
  targeted edits (not full reconciliation — see mirror-drift report above).
- `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css` — re-blessed via
  `mix sigra.fixture.rebless_golden` after every round; confirmed byte-identical to the
  template every time.
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — reflow diagnostic
  extended with `fontFamily`, `minWidth` (first offender only), and `rootFontSize`.
  Assertion strength unchanged: still `scrollWidth <= innerWidth` at 320px / 32px root
  font, still 9 tests resolve via `npx playwright test --list`.

## Verification Evidence (actually run, this task)

```
$ diff priv/templates/sigra.install/core/sigra_auth.css test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css
(no output — byte-identical, confirmed after every commit)

$ MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs
2 tests, 0 failures   (confirmed after every commit)

$ npx playwright test --list tests/admin-generated.spec.ts
Total: 9 tests in 1 file   (confirmed after every commit)
```

### Round 4 confirming run (commit 70bed477)

```
$ gh api repos/szTheory/sigra/actions/jobs/90795579823/logs | grep -E "Running 9 tests|passed|failed"
Running 9 tests using 1 worker
  8 passed (12.8s)
  1 passed (1.5s)
```

All 8 round-4 dispatched runs (`30519167723`, `30519171389`, `30519175220`,
`30519179013`, `30519182596`, `30519186296`, `30519190135`, `30519193712`) confirmed
`conclusion: success` for the `Generated admin Playwright smoke` job via
`gh run view <id> --json jobs`.

## Non-negotiable prohibitions — compliance

- No retries, `continue-on-error`, or assertion weakening were added anywhere. The
  assertion is still the unmodified `expect(reflowPayload.scrollWidth).toBeLessThanOrEqual(reflowPayload.innerWidth)`
  at 320px / 32px root font.
- No secret or `GH_TOKEN` was emitted in any output; no GitHub Actions context string
  was inlined into a `run:` body (`.github/workflows/ci.yml` was not touched at all by
  this task — confirmed via `git diff --stat .github/workflows/ci.yml` from
  `520338c5..HEAD` showing zero hunks for that file).
- GATE-02 was **not** marked complete and `ci.yml:1674`'s stale `if:` clause was **not**
  touched — that remains 231-07's job under D-24's locked sequencing, contingent on this
  fix's own multi-run proof (now delivered).
- `ci.yml`'s `continue-on-error` clauses were not touched anywhere.

## Self-Check

- FOUND: `priv/templates/sigra.install/core/sigra_auth.css`
- FOUND: `test/example/priv/static/assets/sigra_auth.css`
- FOUND: `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css`
- FOUND: `test/example/priv/playwright/tests/admin-generated.spec.ts`
- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-GAP-GATE02-SUMMARY.md`
- FOUND commit: `34e7ddb8`
- FOUND commit: `6ab53947`
- FOUND commit: `0e59f598`
- FOUND commit: `e4a2509d`
- FOUND commit: `70bed477`
- FOUND: 8/8 round-4 CI runs confirmed `conclusion: success` via `gh run view`
- FOUND: `gh pr list --repo szTheory/sigra --base worktree-discuss-231 --state open` returns `[]` (all 26 recapture PRs closed)

## Next Phase Readiness

- **231-07** (GATE-02 enable, D-06) can now proceed on a materially stronger evidentiary
  basis than 231-02 left it: 8 consecutive dispatched green runs on the corrected commit,
  following a genuine multi-round diagnose-fix-regress-refix cycle, rather than one green
  run. 231-07 should still budget for residual uncertainty (see "Statistical confidence"
  above) and watch the first several real PR runs once the `if:` clause is removed.
- The extended reflow diagnostic (fontFamily/minWidth/rootFontSize) is in place for
  231-07 (or any future plan) to self-diagnose without re-instrumenting, should any
  future red appear.
- Two tracked, unfixed defects for a future plan to pick up: the audit-presets
  Actor-filter race (`admin-generated.spec.ts:454-458`) and the `sigra_auth.css`
  mirror-drift reconciliation (`test/example/priv/static/assets/sigra_auth.css`, ~700
  lines behind the template).
- No blockers. `.github/workflows/ci.yml` was not touched by this task.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*
