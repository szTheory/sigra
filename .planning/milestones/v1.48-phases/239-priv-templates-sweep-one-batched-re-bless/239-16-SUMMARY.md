---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 16
subsystem: testing
tags: [measurement-instrument, allowlist, criterion-amendment, generated-app, v3-vocabulary]

requires:
  - phase: 239-priv-templates-sweep-one-batched-re-bless
    provides: "239-v3-vocabulary-check.sh, 239-v3-allowlist.tsv (frozen by D-16/D-30), D-32's created-or-modified generated-app scope, plan 239-13's halting probe record"
provides:
  - "D-33 in 239-CONTEXT.md — the generated-app V3 criterion matches committed allowlist records by (basename, literal) rather than (path, literal)"
  - "239-EVIDENCE.md § D-33-CRITERION-AMENDMENT — the re-derived defect, the commit-graph legitimacy proof, the measured bound, the golden-fixture zero with live controls, three scratch probes, and the runnable derivation"
  - "239-13-PLAN.md amended at exactly two sites so its acceptance criteria and D-33 agree"
affects: [239-13, phase-241-SURF-04]

actuals:
  tokens: 6250   # chars/4 over the realized diff across the three changed files (25,007 chars added)
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Criterion amendment over instrument edit: when a frozen instrument's matching key is the defect, move the criterion and apply the exclusion to the instrument's printed records, post-run"
    - "Amendment legitimacy proven from the commit graph (git merge-base --is-ancestor) rather than argued in prose"
    - "Exclusion-rule non-vacuity demonstrated by a probe that leaves a real hit surviving, before any of its passes are believed"

key-files:
  created: []
  modified:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-CONTEXT.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-13-PLAN.md

key-decisions:
  - "D-33: the generated-app V3 criterion asserts hits_outside_allowlist = 0 AFTER excluding hits whose (basename, literal) matches a committed allowlist record, with the exception enumerated by name and count and a halt clause for any survivor; the criterion moves, the frozen instrument does not"
  - "Rejected: editing the instrument's matching key or adding a rendered-path allowlist row — an instrument edit (D-30), and mechanically impossible besides (union guard raises exit 3 on every tier)"
  - "Rejected: dropping or softening the generated-app V3 measurement — the goalpost move this phase has twice refused"
  - "Rejected: widening D-32 to cover the generated oauth_html.ex — it is installer-created, squarely in D-32's scope, and excluding it there would hollow out D-32's own halt clause"

patterns-established:
  - "Measured bound over asserted bound: the exception's blast radius was established by `git ls-files -z | xargs -0 /usr/bin/grep -lF` over the whole tracked tree (three files, one of them the sole source file), converting a claim into a fact"
  - "Guard vacuity check: before trusting a verify gate, confirm the grep it runs would have failed at the pre-change base — two of this plan's own gates were vacuous and were replaced with unique-marker greps"

requirements-completed: []

coverage:
  - id: D1
    description: "D-33 recorded in 239-CONTEXT.md in D-32's format, with a runnable derivation, three reasoned rejected alternatives, the pre-amendment criterion quoted verbatim, and a Reversibility line"
    requirement: "SURF-01"
    verification:
      - kind: automated_ui
        ref: "bash: D-33 grep >= 1 paired with a live D-32 control on the same file; both ancestor shas recorded"
        status: pass
    human_judgment: false
  - id: D2
    description: "The amended criterion demonstrated non-vacuous and bounded: Probe A leaves a real bookkeeping hit surviving (criterion RED), Probes B and C show each half of the (basename, literal) key is load-bearing"
    requirement: "SURF-01"
    verification:
      - kind: integration
        ref: "239-v3-vocabulary-check.sh --files <scratch>/{a,b,c} — recorded in 239-EVIDENCE.md § D-33-CRITERION-AMENDMENT §7"
        status: pass
    human_judgment: false
  - id: D3
    description: "239-13-PLAN.md amended at both generated-app V3 sites, with plan 239-14's D-31 amendment and every other clause byte-identical"
    requirement: "SURF-03"
    verification:
      - kind: automated_ui
        ref: "bash: stale-assumption count 0 with a live hits_outside_allowlist control; unique-marker greps for all six required parts; D-31 citation and policy-test row intact; verify.plan-structure valid: true; diff 10+/2-"
        status: pass
    human_judgment: false

duration: 38min
completed: 2026-09-18
status: complete
---

# Phase 239 Plan 16: D-33 Criterion Amendment Summary

**The generated-app V3 criterion now recognises an already-triaged false positive after it crosses the
template-to-rendered boundary — matched by `(basename, literal)` instead of `(path, literal)` — with
the amendment's legitimacy proven from the commit graph, its bound measured rather than promised, and
its ability to still fail demonstrated live before any of its passes are believed.**

## Performance

- **Duration:** 38 min
- **Tasks:** 2/2
- **Commits:** 3 (two task commits + this metadata commit)

## Accomplishments

### Task 1 — D-33 recorded and demonstrated RED (`15e8079e`)

The defect was re-derived live rather than cited. The single committed allowlist record is keyed on
`priv/templates/sigra.gen.oauth/oauth_html.ex`; `239-v3-vocabulary-check.sh:217` compares
`h_path` to `AL_PATHS[i]` as whole strings, so the record provably cannot mark its own rendered
counterpart at `lib/<app>_web/controllers/oauth_html.ex`. A matching-key artifact, not a surface
finding.

Four facts established, each with a live positive control on the same surface:

| Fact | Result | Control on the same surface |
|------|--------|-----------------------------|
| Literal present in the template | `grep -cF` -> **1**, at **line 54** | `grep -c defmodule` -> 1 |
| Line number matches the rendered hit | template L54 vs the halting probe's `oauth_html.ex:54` | same alternation (`\b[0-9]{3}-[0-9]{2}\b` on `373-12`) |
| Golden fixture carries no `oauth_html` | **0** | `.ex$` -> 68, `router.ex$` -> 1, total -> 84 |
| Blast radius of the literal, whole tracked tree | **3 files** (evidence ledger, the record itself, one source file) | `defmodule Sigra` -> 510 files |

The goalpost question was answered from the commit graph, not argued:
`git merge-base --is-ancestor 1a85508e 23f3c711` -> 0 and
`git merge-base --is-ancestor 23f3c711 HEAD` -> 0. Plan 239-08's FALSE-POSITIVE disposition precedes
plan 239-09's allowlist record, which precedes this measurement. D-33 changes only *how an existing
disposition is matched across a rendering boundary* — never *what counts as bookkeeping*.

Three probes on a parse-controlled scratch surface outside the working tree, run against the
unmodified committed allowlist in `--files` mode, deleted afterwards:

| Probe | Surface | `hits` / `control_defmodule` / `files_measured` | Derivation | Verdict |
|-------|---------|-----------------------------------------------|------------|---------|
| A | `oauth_html.ex` with the allowlisted literal **and** a real V3 bookkeeping line | 2 / 1 / 1 | excluded=1, **surviving=1** | criterion **RED**, survivor named |
| B | `page_html.ex` with the allowlisted literal | 1 / 1 / 1 | excluded=0, surviving=1 | a literal alone buys nothing |
| C | `oauth_html.ex` with a non-allowlisted `ROADMAP` hit | 1 / 1 / 1 | excluded=0, surviving=1 | a basename alone buys nothing |

Probe A is the one that matters: an exclusion rule that cannot leave anything behind certifies
everything. This one can.

### Task 2 — the two-site amendment of `239-13-PLAN.md` (`46148b51`)

Sites were located by exhaustive re-grep, not by the plan's anchor line numbers: `allowlist|generated
app` returned **37** matching lines and `generated-app|over the generated app` a further **12**; every
hit was classified. Exactly two are the generated-app V3 criterion (the Task 1 action sentence and the
Task 1 acceptance criterion). The `<verification>` section was read and confirmed to carry no third
site. The diff is **10 insertions / 2 deletions**, confined to those two sites.

The amended criterion carries all six required parts, each independently greppable: the
post-exclusion assertion; the derivation transcribed runnable; the enumerate-by-name-and-count
requirement; the halt clause; the retained exit-3 rule; and the retained live `control_defmodule`
requirement on the same explicit file list. One sentence records why the replaced assumption was
wrong, so a later reader does not restore it.

## Deviations from Plan

**1. [Rule 2 — missing critical functionality] Two of this plan's own verify guards were vacuous and were replaced**

- **Found during:** Task 2 (flagged by the plan-checker, re-measured and confirmed here)
- **Issue:** the plan's `EXCLUSION_KEY_NOT_STATED` gate greps `basename` and its
  `CONTROL_REQUIREMENT_DROPPED` gate greps `control_defmodule` against `239-13-PLAN.md`. Both strings
  already occurred at the pre-amendment base — confirmed at `HEAD~2`: `basename` -> **2**,
  `control_defmodule` -> **5**. Both gates would have passed before any work was done and could never
  fire. A guard that cannot fail is precisely the defect this phase exists to repair.
- **Fix:** the amended criterion carries a unique marker phrase, `(basename, literal) exclusion per
  D-33`, and the executed gate greps that marker plus four further unique markers — `Enumerate the
  excluded records by name and count`, `**Halt clause:**`, the `sed -n '/^files_measured=/,$p'`
  derivation anchor, and `` control_defmodule` must be `>= 1` on that same explicit file list ``. All
  five return 0 at the base and >= 1 after the amendment, so every one of the six required parts now
  has a live check rather than two vacuous ones.
- **Files modified:** none beyond the planned amendment — this changed the gate that was run, not the
  deliverable.
- **Commit:** `46148b51`

**2. [Rule 2 — missing critical functionality] The bound is now a measured fact, not an assertion**

- **Found during:** Task 1
- **Issue:** truth ~L31 claims the exception "cannot widen to cover anything not already triaged".
  Strictly false as written: `(basename, literal)` is looser than `(path, literal)`, so a third file
  named `oauth_html.ex` carrying that literal would also be excluded. Probes B and C test each half of
  the key but neither tests "same basename, same literal, different untriaged file".
- **Fix:** rather than assert the bound, D-33 measures it —
  `git ls-files -z | xargs -0 /usr/bin/grep -lF -- '<literal>'` returns exactly three files across the
  whole tracked tree, of which exactly one is a source file (the template), with a 510-file live
  control on the same command shape. The record states the looseness honestly and then bounds it with
  that measurement.
- **Commit:** `15e8079e`

**3. [Informational — no action, erring safe]** the plan's `EXIT3_RULE_DROPPED` gate greps
`instrument failure, never a result`, whose only occurrence was inside the site being rewritten, so a
retained-but-reworded rule would false-red. The phrase was retained verbatim in the replacement, so
the gate passes; left as-is because it fails safe.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path, file access pattern, or schema change; no source file was
touched.

## Scope Discipline

- `239-v3-vocabulary-check.sh`, `239-v3-allowlist.tsv` and `239-comment-only-diff-check.sh` are
  byte-unchanged across both commits (`git diff --name-only HEAD~2..HEAD --` those paths is empty).
- `.planning/REQUIREMENTS.md` untouched; **SURF-03 remains `[ ]`** — plan 239-13 re-checks it last and
  alone.
- No `install-smoke.sh`, no scaffolded app, no `mix hex.build`, no `MIX_ENV=test mix ci`. Every live
  external observation stays plan 239-13's.
- `239-13-PLAN.md`'s frontmatter is untouched: `wave: 18` / `depends_on: ["239-16"]` asserted, not
  re-applied. Plan 239-14's D-31 amendment survives intact (`as amended by D-31` -> 4 occurrences,
  `sigra_admin_policy_test.exs` -> 5).
- Scratch surface lived outside the repo working tree, recorded by basename only (public repo), and
  was deleted; `git status --porcelain` empty at every commit.
- `verify.plan-structure` on the amended file: `valid: true`, 3 tasks.

## Next

Plan 239-13 re-runs at `wave: 18`, grading the generated-app surface against a criterion that is now
both satisfiable and still capable of failing.

## Self-Check: PASSED
