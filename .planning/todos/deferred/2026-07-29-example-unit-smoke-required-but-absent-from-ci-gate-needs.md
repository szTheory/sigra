---
created: 2026-07-29T00:00:00.000Z
status: pending
title: "example_unit_smoke is one of the five ruleset-14941512-required checks, yet ci-gate.needs does not include it, so ci-gate can conclude success while that lane is red"
area: ci
files:
  - .github/workflows/ci.yml
  - MAINTAINING.md
severity: medium
source: Phase 231 planning (231-CONTEXT.md § Deferred Ideas) — filed per plan 231-09, GATE-03's own honesty gap fell out of scope
---

## What

`ci-gate` (`.github/workflows/ci.yml:1793-1802`) aggregates nine lanes and reports the merge-affecting
verdict for the whole DAG. `MAINTAINING.md:104-110` records that ruleset 14941512 enforces exactly five
job `name:` strings as required status checks — one of them, `Example unit smoke (ExUnit + ConnTest)`
(the `example_unit_smoke` job), is **not** among `ci-gate`'s nine `needs:` entries.

The practical consequence: `example_unit_smoke` can fail on a PR and `ci-gate` — the job this repo's own
GATE-03 verdict now audits for honesty — has no way to notice, because `example_unit_smoke` never
appears in its `needs:` block at all. `ci-gate` concluding `success` says nothing about whether that
lane passed. This is the same "green gate, red lane, nobody notices" shape GATE-03 exists to remove, one
level up: GATE-03 audits whether a `needs:`-declared lane's *skip* was legitimate, but it cannot audit a
lane that was never declared as a dependency in the first place.

Ruleset 14941512 enforces `example_unit_smoke` independently of `ci-gate` (GitHub blocks the merge on
the job's own status context, not through `ci-gate`), so a red `example_unit_smoke` still blocks a PR
merge today. The gap is specifically that `ci-gate`'s own aggregate verdict — and, by extension, any
future consumer that trusts `ci-gate` as *the* single release-lane signal (e.g. `gate-ci-green` in
`release-please.yml`, which polls `ci-gate` and nothing else) — is blind to this lane.

## Evidence

- `.github/workflows/ci.yml:1793-1802` — `ci-gate`'s `needs:` list. `example_unit_smoke` is absent from
  the nine (now ten, after plan 231-09 added `changes` as an input provider) entries.
- `MAINTAINING.md:104-110` — the five ruleset-14941512-required check-name strings, including
  `Example unit smoke (ExUnit + ConnTest)`. The same section states plainly: "`ci-gate` is NOT an
  enforced required check. It is an internal aggregator job that gates the rest of the DAG; it does not
  appear in ruleset 14941512's `required_status_checks`."

## Already visible, not silent

Phase 231's GATE-03 honest-skip verdict script (`scripts/ci/honest-skip-verdict.sh`, shipped by plan
231-08, wired into `ci-gate` by plan 231-09) already emits an advisory `NOTE` naming this exact gap on
**every** run of `ci-gate`:

> `NOTE: example_unit_smoke is a ruleset-required check name absent from ci-gate.needs / this script's
> fixed lane set (Phase 231 GATE-03 todo, filed by plan 231-09). Advisory only -- never fails the
> verdict.`

That NOTE is advisory **by construction** — it is emitted unconditionally alongside every verdict,
`PASS` or `FAIL`, and never contributes to the script's exit code. It makes the gap visible in every
gate log rather than only in this file, but it does not close the gap: the deferral recorded here
remains a deferral until a phase that owns a requirement for it acts on one of the fix options below.

## Fix options (neither chosen here)

1. **Add `example_unit_smoke` to `ci-gate.needs`.** Makes `ci-gate`'s aggregate verdict cover all five
   ruleset-required lanes, not four of five. Requires re-verifying `scripts/ci/prohibitions/_lib.mjs`'s
   `NEVER_DOCS_GATED` set and GATE-03's own honest-skip-verdict.sh lane list stay in sync with the
   change (the same three-way parity discipline `honest-skip-parity.test.mjs` already enforces for the
   other nine lanes).
2. **Add `ci-gate` itself as a required ruleset context** (repo-admin action on ruleset 14941512). This
   is the adjacent SEED-005 P1-2 idea already deferred by `231-CONTEXT.md` § Deferred Ideas, and it is
   **explicitly out of scope for Phase 231** — CONTEXT places ruleset changes outside every GATE-0x
   requirement's boundary. Noted here for completeness, not as a recommendation.

Both are repo-shape decisions rather than code fixes in the ordinary sense, and both belong to a phase
that scopes and owns a requirement for them — no GATE-0x requirement in Phase 231 covers either.

## Sibling deferral

Filed alongside `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md` § Deferred Ideas'
first bullet, "Add `ci-gate` as a required ruleset context" (SEED-005 P1-2) — the two are the same
underlying gap (ruleset 14941512 and `ci-gate`'s `needs:` disagree about which lanes gate a merge),
described from opposite ends. A future reader closing one should read the other.
