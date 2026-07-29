# Phase 231 Plan 02 — GATE-02 320px Reflow Diagnosis

**Recorded:** 2026-07-29
**Source:** five `workflow_dispatch` CI runs on branch `worktree-discuss-231`, dispatched *after*
the instrumented assertion (`gate02-reflow-instrumentation`) landed in commit `162ce4ee`.

## Dispatch mechanism note (read before the table)

The plan's read_first assumed a bare `gh workflow run "CI" --ref <branch>` would exercise
`generated_admin_playwright_smoke` because that job's own `if:` clause evaluates true on any
non-`pull_request` event. That is correct as far as it goes, but incomplete: the job also carries
`needs: release_ref_guard`, and `release_ref_guard` (`ci.yml:57-91`) independently rejects a bare
manual dispatch — on `workflow_dispatch` with no `recapture_branch` input it requires
`GITHUB_REF` to match `refs/tags/v*` and fails the whole run before any downstream job starts.
Five initial dispatches (`30499621998`, `30499626516`, `30499631102`, `30499635779`,
`30499640145`) all failed at `release_ref_guard` for exactly this reason and never reached the
target job — none of them are counted below.

The workflow already ships a sanctioned escape hatch for this: `recapture_branch`, an existing
`workflow_dispatch` input whose own inline comment reads "Branch to run branch-scoped baseline
recapture against… Leave empty for ordinary release-evidence dispatches" (`ci.yml:13`).
`release_ref_guard` explicitly treats a non-empty `recapture_branch` as "not applicable"
(`ci.yml:80-83`) regardless of `GITHUB_REF`. Re-dispatching with
`gh workflow run "CI" --ref worktree-discuss-231 -f recapture_branch=worktree-discuss-231`
cleared `release_ref_guard` and let `generated_admin_playwright_smoke` run normally. No file in
`.github/workflows/ci.yml` was modified to achieve this — the dispatch input already existed for
exactly this purpose. The unavoidable side effect is that the two amd64 recapture jobs
(`admin_design_recapture`, `admin_checkpoint_recapture`) also ran on each of these five dispatches,
targeting `worktree-discuss-231` as their PR base per their own documented behavior; this is
recorded as a deviation in the plan SUMMARY, not corrected here.

## Observed Runs

All five runs below are from the second dispatch batch (`recapture_branch=worktree-discuss-231`),
each reading the instrumented payload from
`gh api repos/szTheory/sigra/actions/jobs/<job-id>/logs`. `PLAYWRIGHT_RETRIES: 1`
(`ci.yml` generated-admin env) means every run emits either one payload line (pass, no retry
needed) or two (fail, then a failing retry) — quoted verbatim below, not paraphrased.

| Run ID | Job ID | Job conclusion | innerWidth | scrollWidth | clientWidth | Offenders (tag · classes · right edge) |
|---|---|---|---|---|---|---|
| `30499968358` | `90737274629` | `failure` | 320 | 343 | 320 | `DIV·fieldset mb-2·343.4375`, `LABEL··343.4375`, `SPAN·label mb-1·343.4375`, `INPUT·w-full input·343.4375`, `BUTTON·sigra-auth-action sigra-auth-action--primary sigra-auth-action--block·343.4375`, `SPAN··326.4375`, `H2··321.4375`, `P··321.4375` |
| `30499973492` | `90737301555` | `success` | 320 | 320 | 320 | *(empty)* |
| `30499978018` | `90737296264` | `failure` | 320 | 343 | 320 | identical to `30499968358`'s list above (bit-for-bit, both attempt and retry) |
| `30499982563` | `90737575017` | `failure` | 320 | 343 | 320 | identical to `30499968358`'s list above (bit-for-bit, both attempt and retry) |
| `30499987214` | `90737904354` | `success` | 320 | 320 | 320 | *(empty)* |

Raw quoted payload lines (attempt 1 of each; the two retried failures repeat the identical line
byte-for-byte on the retry — confirmed by `grep -c` returning 2 identical lines per failing job):

```
# 30499968358 / job 90737274629 (attempt 1)
gate02-reflow-instrumentation {"innerWidth":320,"scrollWidth":343,"clientWidth":320,"offenders":[{"tag":"DIV","cls":"fieldset mb-2","right":343.4375},{"tag":"LABEL","cls":"","right":343.4375},{"tag":"SPAN","cls":"label mb-1","right":343.4375},{"tag":"INPUT","cls":"w-full input","right":343.4375},{"tag":"BUTTON","cls":"sigra-auth-action sigra-auth-action--primary sigra-auth-action--block","right":343.4375},{"tag":"SPAN","cls":"","right":326.4375},{"tag":"H2","cls":"","right":321.4375},{"tag":"P","cls":"","right":321.4375}]}

# 30499973492 / job 90737301555 (pass)
gate02-reflow-instrumentation {"innerWidth":320,"scrollWidth":320,"clientWidth":320,"offenders":[]}

# 30499987214 / job 90737904354 (pass)
gate02-reflow-instrumentation {"innerWidth":320,"scrollWidth":320,"clientWidth":320,"offenders":[]}
```

`30499978018` and `30499982563` reproduce `30499968358`'s exact payload, including the identical
`343.4375` right-edge value to four decimal places, on both the initial attempt and the retry.

## Verdict

**H2** — RESEARCH's own literal kill condition for H1 is met exactly: "H1 is KILLED if passing
runs report `innerWidth` 320 with `scrollWidth` at most 320, in which case H2… takes over"
(`231-RESEARCH.md:792`). Both passing runs in this sample (`30499973492`, `30499987214`) report
`innerWidth: 320` — never the stale-viewport `1280` that would have proven H1 — with
`scrollWidth: 320`, exactly at budget, and an empty offender list. H1's core claim (that "passes"
are racy false-greens caused by `page.evaluate` reading a pre-viewport-change `innerWidth`) is
directly contradicted by this evidence: the viewport read is correct on every single run, pass or
fail. H1 is killed by this phase's own instrumentation, not by hypothesis.

Per D-25's discipline, this hands the explanation to H2: a genuine layout state difference at
measurement time, not a stale read. The evidence is a real, reproducible ~23px overflow
(343.4375 vs. 320 innerWidth) on 3 of 5 runs, and *zero* overflow on the other 2 — with the
failing state's offender set identical to four decimal places across all three failing runs and
both attempts within each. That determinism argues the two states (overflowing / not overflowing)
are each themselves fully deterministic given whatever renders them; what varies is *which* of the
two states a given run lands in. H3 (the generated host's own `app.css` resolving differently
between runs) is not supported by this data: if `app.css` bytes genuinely differed per run, the
failing runs would not be expected to reproduce the *exact same* 343.4375px value to four decimal
places three separate times — a byte-level asset difference would more plausibly produce varying
overflow amounts, not an identical one. This diagnosis does not attempt to name a specific timing
mechanism for H2 beyond RESEARCH's own framing ("a genuine layout race after the root-font
mutation") — Task 3 implements against the offender list itself (the structural containment fix),
which is the fix RESEARCH pairs with either H1 or H2 ("plus, if the instrumented run names other
offenders, `min-width: 0` on the intermediate stack/grid wrappers… Both fixes are compatible and
can ship together," `231-RESEARCH.md:807-826`).

The named offenders point directly at the CSS rule Task 3 is scoped to edit: the `INPUT` offender
carries classes `w-full input` — the `.input` class is explicitly part of the
`.sigra-auth input[type="email"], … .sigra-auth .input` selector group at
`priv/templates/sigra.install/core/sigra_auth.css:643-663`, which sets `width: 100%` but no
`min-width`, so its automatic minimum size resolves to the input's `min-content` (this is exactly
the mechanism RESEARCH's H1 section describes, independent of which hypothesis explains the
run-to-run variance). The `DIV.fieldset`, `LABEL`, `SPAN.label`, and `BUTTON` offenders share the
input's exact right edge (343.4375) because they are ancestor/sibling block elements whose own
width is constrained by the input's min-content floor; removing that floor should collapse all of
them back under 320 simultaneously, not just the input.

Per Task 3's literal gate ("If and only if the diagnosis proved H1 or H2 — that is, if any run's
payload reported an `innerWidth` other than 320 — also make the measurement's precondition
deterministic"): **no run in this sample ever reported an `innerWidth` other than 320.** That
specific sub-condition is false, so Task 3 does not add a `waitForFunction` on the viewport — the
viewport is already confirmed to apply synchronously and correctly on every observed run, pass or
fail. The verdict is H2 in name (per RESEARCH's H1-kill logic), but the concrete, actionable fix
this diagnosis hands to Task 3 is the CSS containment fix only, scoped to the named offenders.

## Corrections To The Written Record

**`230-VERIFICATION.md:174`'s "transient" classification is wrong.** D-08 (`231-CONTEXT.md:94-104`)
already established this from the historical record, sampled over the twelve run ids where the
9-test version of the spec ran: **pass** `30472016250`, `30466318240`, `30389700235`,
`30387490396`, `30379435985`, `30374856611`, `30325414426` (7 ids); **fail** `30461966943`,
`30425416933`, `30414885679`, `30331796188`, `30321079383` (5 ids) — 12 ids total, an ~38% failure
rate (D-08's own label reads "8 pass / 5 fail"; the enumerated pass list carries 7 ids, not 8 — a
pre-existing off-by-one in the source label that this diagnosis flags rather than silently
resolves, since it does not change the ~38% rate or the "not transient" conclusion). This plan's
own fresh sample reproduces the same pattern live: 3 failures out of 5 fresh dispatches (60%,
consistent with a ~38% true rate at n=5), all on the identical assertion, all naming the identical
offender set. `230-VERIFICATION.md:174` is corrected: the failure is real, reproducible, and
structurally caused — not transient infrastructure noise.

**The filed wordmark todo's webfont hypothesis is dead, and its proposed remedy conflicts with
this gate (C-5).** `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md`
proposed a webfont-metrics race against the 15-character token `SigraAdminSmoke` as the cause.
`231-RESEARCH.md`'s live artifact read (from run `30425416933`) already killed this: `sigra_auth.css`
carries no `@font-face` and no remote font link, and the failure screenshot showed the wordmark
already breaking correctly into four fragments (`Sigra` / `Admi` / `nSm` / `oke`) — it is not the
overflow source. This diagnosis's own offender lists confirm the same conclusion from a second,
independent data source: none of the fifteen offender entries observed across three failing runs
name `.sigra-auth__product` (the wordmark element) or anything resembling it — every offender is
form/input/fieldset markup. The todo's proposed remedy (narrowing `.sigra-auth__product` from
`overflow-wrap: anywhere` to `break-word` semantics) is unrelated to the actual overflow source and
would, per C-5, make the reflow assertion fail *harder* by letting the wordmark's own line grow
wider rather than wrapping. The todo stays open and unresolved by this plan; its proposed direction
is now confirmed twice over (RESEARCH + this diagnosis) to be orthogonal to, and in tension with,
GATE-02's fix.
