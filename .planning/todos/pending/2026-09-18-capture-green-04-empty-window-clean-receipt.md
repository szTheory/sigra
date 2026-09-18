---
created: 2026-09-18T19:10:00.000Z
status: pending
title: "capture-green-04-evidence.sh emits a clean receipt at exit 0 for an empty main window: no MIN_RUNS floor and nothing binds the caller-supplied window to the dispatch run"
area: ci
files:

  - scripts/ci/capture-green-04-evidence.sh
  - scripts/ci/capture-green-04-evidence.test.sh

severity: high
source: Phase 240 code review (240-REVIEW.md, CR-02) — operator dispositioned as tracked follow-up 2026-09-18, confirmed by 240-VERIFICATION.md
---

## What

The `main`-window half of the collector (`scripts/ci/capture-green-04-evidence.sh:75-79`, `:229-231`, `:299-313`) accepts `--main-window-start` / `--main-window-end` from the caller and applies only an ordering check. There is no minimum-runs floor, and nothing ties the window to the dispatch run being captured.

Reproduced during review: a one-second window yields `run_count: 0`, every `ci_gate_conclusions` counter `0`, `flake_attributable_red_count: 0`, at **exit 0** — a receipt that looks clean because it observed nothing.

## Why it matters

This contradicts the script's own header contract at `:6-10`:

> a collector whose window the caller steers … is evidence forgery wearing a green receipt … the `main` window bounds (themselves bounded by the dispatch run)

The header states the invariant; the code does not enforce it. `flake_attributable_red_count: 0` over zero runs is indistinguishable in the receipt from the same value over a genuinely clean window, so a reader cannot tell a measurement from a non-measurement. That is the "green gate that verified nothing" pattern this milestone retires.

## Not a falsification of Phase 240's evidence

This did not fire on the shipped capture: `240-GREEN-04-EVIDENCE.json` records `sc2.run_count: 8` over a window whose start is the `created_at` of run `35052017063` (the oldest `main` `ci.yml` run at/after the Phase 236 flake fix `b6e889c4`) and whose end is the capture instant — both bounds recorded verbatim in `240-EVIDENCE.md` and in the issue-#231 closure comment. The GREEN-04 claim stands.

## Fix sketch

Two independent guards, both with named failure tokens and both asserted RED in the self-test:

1. **`insufficient_main_runs`** — a `MIN_RUNS` floor (>= 1, and arguably higher for the claim to mean anything), refusing to emit a receipt from an empty or near-empty window.
2. **Window/run binding** — assert the dispatch run's `created_at` falls inside `[start, end]`, so a caller cannot hand the collector a window unrelated to the run it is capturing. This is the invariant the header already claims.

Consider also recording in the receipt *how* the bounds were derived, not just their values.

## Related

- Sibling: `2026-09-18-capture-green-04-sc2-selectors-fail-open.md` (CR-01)
- Sibling: `2026-09-18-capture-green-04-selftest-has-no-ci-caller.md` — the natural home for the coverage
