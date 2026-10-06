---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 09
subsystem: testing
tags: [bookkeeping-regex, measurement-instrument, fail-closed, allowlist, gap-closure, surf-03]

requires:
  - phase: 239 (plans 01–08)
    provides: "V2 widened-union definition and its per-alternation positive-control format (239-EVIDENCE.md § WIDENED-UNION-LEDGER); the SC-1 gap block in 239-VERIFICATION.md naming the two residual sentences"
provides:
  - "239-v3-vocabulary-check.sh — the runnable V3 bookkeeping definition, wired into nothing (D-04)"
  - "239-v3-allowlist.tsv — one committed, reasoned, non-vacuity-controlled triage entry"
  - "239-EVIDENCE.md § VOCABULARY-LEDGER — V3 verbatim, 8 positive controls, recall keep/drop record, 3 fixed tier file lists, 3-tier RED table, full per-hit triage, D-30 and D-28"
  - "An honest SURF-03 checkbox: [ ] with a Pending roll-up row"
  - "A measured and routed test/example remainder (482 lines / 157 files) + IN-06 disposition"
affects: [239-11, 239-12, 239-13, 241 SURF-04 p18 guard]

actuals:
  tokens: 13600
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Detection width separated from asserted surface (D-30): instrument stays maximally wide, criterion asserts hits_outside_allowlist=0 over a pre-committed file list"
    - "Distinct fail-closed exit code (3) so 'the instrument cannot answer' can never read as 'the surface is dirty' (1)"
    - "Allowlist entries keyed on (path, literal), each with a run-scoped non-vacuity control plus a once-computed union check"

key-files:
  created:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-allowlist.tsv
    - .planning/todos/pending/2026-09-18-test-example-remainder-outside-the-sc-4-counterpart-scope.md
  modified:
    - .planning/REQUIREMENTS.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md

key-decisions:
  - "D-30: the instrument's detection WIDTH and the criterion's asserted SURFACE are separate — V3 stays maximally wide and is never narrowed; the criterion asserts hits_outside_allowlist = 0 over pre-committed tier file lists, with the raw hits= total printed alongside every run"
  - "D-28: the widening is implemented as a measurement instrument only; Phase 241's SURF-04 p18 guard inherits V3 as its spec (Standing Constraint 5 / D-04 — Phase 239 builds no guard)"
  - "The example tier is scoped to the two SC-4 mirrored counterparts, never a tree walk; the unswept remainder is measured and routed, not swept"
  - "All 8 seeded vocabulary alternations kept — none dropped — each with a live positive control on a named surface"

patterns-established:
  - "Run-scoped allowlist non-vacuity control + a once-computed union check that closes the hole scoping opens"
  - "Fail-closed demonstrated live (empty input, vacuous entry, entry exercised by no tier) rather than asserted in prose"
  - "A routed remainder: an out-of-scope number is measured, named, and given an owner instead of being dropped"

requirements-completed: []

coverage:
  - id: D1
    description: "SURF-03 no longer asserts a state that does not hold — unchecked, with a Pending roll-up row; SURF-01 stays checked with its narrow-scope judgement written down"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "bash: grep -q '^- \\[ \\] \\*\\*SURF-03\\*\\*' .planning/REQUIREMENTS.md && grep -q '^- \\[x\\] \\*\\*SURF-01\\*\\*' && ! grep -qE '^\\| SURF-03 \\| Phase 239 \\| Complete' => SURF03_HONEST"
        status: pass
    human_judgment: false
  - id: D2
    description: "V3 vocabulary definition committed as a runnable phase artifact and demonstrated RED on all three tiers, with paired positive controls and both SC-1 sentences among the hits in each tier"
    requirement: SURF-01
    verification:
      - kind: other
        ref: "bash: for t in priv-templates example golden; do 239-v3-vocabulary-check.sh $t; done => exit 1 on all three, hits_outside_allowlist 2/2/2, control_defmodule 98/2/78 => V3_RED_ALL_THREE_TIERS"
        status: pass
    human_judgment: false
  - id: D3
    description: "Fail-closed behaviour (exit 3) demonstrated live for empty input, a vacuous allowlist entry, and an entry exercised by no tier — plus the scoping proof that a non-exercising tier still reports a result"
    verification:
      - kind: other
        ref: "bash: 239-v3-vocabulary-check.sh --files => 3; V3_ALLOWLIST=<corrupt-literal> ... priv-templates => 3; V3_ALLOWLIST=<corrupt-path> ... => 3; V3_ALLOWLIST=<corrupt-literal> ... example => 1"
        status: pass
    human_judgment: false
  - id: D4
    description: "The unswept test/example remainder measured (482 lines / 157 files) and routed to Phase 241 SURF-04, with review finding IN-06 named by file:line and proven unmatched by V3"
    verification:
      - kind: other
        ref: "bash: grep -nE \"$V3\" test/example/priv/playwright/tests/golden-path.spec.ts | grep -c '^59:' => 0; remainder counts recorded in 239-EVIDENCE.md § VOCABULARY-LEDGER (i)"
        status: pass
    human_judgment: false

duration: 34min
completed: 2026-09-18
status: complete
---

# Phase 239 Plan 09: V3 Vocabulary Instrument + Honest SURF-03 Summary

**The closure's measuring instrument can now see the class of bookkeeping that is still shipping — V3 is committed, wired into nothing, and demonstrated RED on `priv/templates/`, the SC-4 `test/example/` counterparts and the golden tree simultaneously, before a single template byte is edited.**

## Performance

- **Duration:** ~34 min
- **Tasks:** 2 of 2
- **Files modified:** 6 (3 created, 3 modified)

## Accomplishments

- **SURF-03 stops lying.** Flipped to `[ ]` with a `Pending (gap closure 239-09 … 239-13)` roll-up row, in a commit whose only file is `REQUIREMENTS.md`. SURF-01 stays `[x]` and now carries a written audit note explaining *why* its narrower wording still holds, citing `239-VERIFICATION.md`'s Requirements Coverage row — the judgement is recorded rather than left inferable.
- **V3 exists, runs, and is RED where it must be.** `239-v3-vocabulary-check.sh` extends V2 (copied mechanically out of `§ WIDENED-UNION-LEDGER`, never retyped) with an eight-alternation vocabulary class. Exit 1 on all three tiers with `hits_outside_allowlist` = **2 / 2 / 2** and `control_defmodule` = **98 / 2 / 78**; both SC-1 sentences appear by `path:line:` in every tier, neither allowlisted.
- **The criterion is reachable and honest (D-30).** `hits_outside_allowlist = 0`, never `hits = 0` — the raw total is printed on every run and the single allowlisted hit is marked `[ALLOWLISTED]` inline rather than deleted. A literal `hits = 0` was arithmetically unreachable at this base (V2 alone: 1 in `priv/templates/`, 390 across `test/example/`).
- **Fail-closed is proven, not claimed.** Exit 3 is distinct from exit 1 and was demonstrated live for three separate causes, plus a fourth run proving the allowlist control's tier-scoping does not fail closed on tiers that do not exercise an entry.
- **Nothing was dropped.** The unswept `test/example/` remainder is measured, its heavyweights named, and routed to Phase 241 SURF-04 in a new todo. Review finding **IN-06** — the one finding with no disposition anywhere else in this closure — is named by `file:line` with a *proof* that V3 cannot see it, making it an input to the `p18` spec instead of a dropped low-severity line.
- **Phase 241 now inherits V3, not V2.** The existing SURF-04 todo was amended in place: retitled, V3 added verbatim with its delta and controls, a "why V2 was not enough" diagnosis added, and the V2 text kept and marked superseded — the file's value is the audit trail of an instrument widened twice.

## Task Commits

1. **Task 1: Uncheck SURF-03 and correct its roll-up row** — `6bd8046d` (docs)
2. **Task 2: End-to-end V3 vocabulary instrument, demonstrated RED across all three tiers** — `23f3c711` (chore, tracer)

## Files Created/Modified

- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh` — the V3 definition, runnable. Tier dispatch, (path, literal)-keyed allowlist, run-scoped non-vacuity control, once-computed union check, distinct exit-3 fail-closed contract. Wired into nothing.
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-allowlist.tsv` — one record: the Facebook-logo SVG `path d=` geometry fragment in `sigra.gen.oauth/oauth_html.ex`, dispositioned FALSE-POSITIVE by name at this plan's time.
- `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` — new `## VOCABULARY-LEDGER` section (a)…(l): V3 verbatim, per-alternation controls, recall keep/drop record, fixed tier lists, allowlist + both controls, three-tier RED table, fail-closed demonstrations, per-hit triage, measured remainder, IN-06 proof, **D-30**, **D-28**.
- `.planning/REQUIREMENTS.md` — SURF-03 unchecked + roll-up row; SURF-01 audit note.
- `.planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md` — retitled to V3; V3 + delta + controls + "why V2 was not enough" added; V2 kept, marked superseded.
- `.planning/todos/pending/2026-09-18-test-example-remainder-outside-the-sc-4-counterpart-scope.md` — the routed remainder and the IN-06 disposition.

## Decisions Made

- **D-30** — detection width vs asserted surface, with three alternatives explicitly rejected (narrowing V3; sweeping `test/example/` repo-wide at 4.3× scope; silently dropping the false positive). Reversibility: costly. Implemented by plan 239-09.
- **D-28** — V3 is a measurement instrument only; Phase 241 SURF-04 owns mechanization. Proof of non-wiring recorded (`grep -rn '239-v3-vocabulary-check' mix.exs .github scripts/` → 0). Reversibility: reversible.
- **Keep all eight seeded alternations, drop none.** Three of them (`\bthis phase\b`, `\bre-?bless\b`, `\bROADMAP\b`) catch nothing on any shipped tier today and are kept deliberately as tripwires; their positive controls prove they are live vocabulary, not dead patterns.
- **`\bROADMAP\b` is uppercase-anchored** so it cannot fire on the ordinary English word in adopter-facing prose; **`v[0-9]+\.[0-9]+ concern`** is anchored on `concern` rather than on a bare version number, because a version number is legitimate in adopter prose and roadmap *sequencing* is not.

## Deviations from Plan

None on scope or method. Three measured results differ from the plan's stated expectations and are recorded as measured, not smoothed:

1. **The `test/example/` remainder is 482 lines across 157 files, not the expected ~392 across ~67.** The plan explicitly instructed reporting the measurement and flagging a material difference. The file count is 2.3× the estimate and the heavyweights are Playwright test tooling (`priv/playwright/…`), not the application code the estimate anticipated — a materially *lower*-severity surface, since that tooling is not adopter-shipped. Recorded in `§ VOCABULARY-LEDGER (i)` and in the routing todo.
2. **`priv/templates/` reports 3 raw V3 hits, not the 4 the earlier V2 ledger recorded** — plans 239-06/239-08 removed hits after that ledger row was written. The backstop recall pass reviewed all 3, not just the two known sentences; the third is the pre-existing SVG false positive. No previously unknown bookkeeping was found in `priv/templates/`.
3. **IN-06's single-file V3 invocation exits 3, not 1** — `control_defmodule=0` on a TypeScript file, so the paired positive control is inapplicable and the instrument correctly refuses a verdict. The hit list is still printed, which is what the line-59 measurement reads from. Documented in `§ (j)` as the guard working, not a defect.

## Issues Encountered

- **A `grep` shim nearly produced a confident false negative.** The interactive shell resolves `grep` to a `ugrep` wrapper, which silently returned **0 remainder hits** for a command that must return hundreds. Caught because the number contradicted an earlier V2 measurement of 390 — a negative result checked against a positive control rather than accepted. All measurements were re-run in a clean `/bin/bash` process. **The committed script is unaffected:** a bash script does not inherit interactive shell functions, which is confirmed by its correct three-tier output.
- **Acceptance criterion "git status --porcelain is empty after the commit" does not hold** — `.planning/STATE.md` was already modified by the execute-phase orchestrator before this plan started. Both commits are strictly path-scoped to their task's files; `git show --name-only` confirms exactly 1 and exactly 5 files respectively, with nothing under `priv/`, `test/`, `lib/` or `.github/` (`git diff --name-only HEAD~2 -- priv/ test/ lib/ .github/` → 0).

## User Setup Required

None.

## Next Phase Readiness

- **Plan 239-10** amends SC-1/SC-2 wording (D-27/D-28) and files IN-05 — unblocked; D-30 and D-28 are stated in the ledger and ready to be recorded into `239-CONTEXT.md`.
- **Plans 239-11/12/13** consume the instrument, the three tier file lists and the allowlist **byte-unchanged**. Their GREEN criterion is `hits_outside_allowlist = 0` per tier, with exit 3 always treated as a halt and never as a result. The plan-239-11 work list is the four BOOKKEEPING triage rows (#2–#5 in `§ (h)`); the golden rows (#6–#7) clear via the plan-239-12 re-bless.
- **No guard was built** (Standing Constraint 5 / D-04). Phase 241 SURF-04 inherits V3 through the amended todo, including the recorded case-sensitivity gap IN-06 exposes.

---
*Phase: 239-priv-templates-sweep-one-batched-re-bless*
*Completed: 2026-09-18*

## Self-Check: PASSED

All created artifacts exist on disk (`239-v3-vocabulary-check.sh`, `239-v3-allowlist.tsv`,
`239-09-SUMMARY.md`, the remainder routing todo) and both task commits (`6bd8046d`, `23f3c711`)
are present in `git log`.
