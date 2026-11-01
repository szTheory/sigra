---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 15
subsystem: install-templates
tags: [gap-closure, golden-fixture, re-bless, measurement-hygiene, d29]
status: complete
requires:
  - "239-14 (batch-4 template retraction 7592e760 + mirror a13c40bc)"
  - "D-09, D-19, D-26, D-29, D-30, D-31 (239-CONTEXT.md)"
  - "239-comment-only-diff-check.sh + 239-v3-vocabulary-check.sh + 239-v3-allowlist.tsv (frozen instruments)"
provides:
  - "batch-4 re-bless commit 5f7ae9d7 — the golden fixture now carries the WR-01 retraction"
  - "239-golden-expected-4.txt (round-4 frozen expected-removed set, 2 N: records, 0 T:)"
  - "fixtures/239-golden-rebless4-code-change.diff (round-4 known-bad fixture)"
  - "239-EVIDENCE.md § REFREEZE-LEDGER-4 and § REBLESS-COMMIT-4"
  - "the D-29 batch-4 justification, discharged greppably"
affects:
  - "plan 239-13 (wave 16 — re-runs last, re-checks SURF-03 alone)"
tech-stack:
  added: []
  patterns:
    - "freeze-then-bless: the expected set committed as a strict ancestor of the re-bless it validates"
    - "RED before GREEN: the classifier proven able to fail before any of its greens are believed"
    - "disclose a disabled floor rather than manufacture one"
key-files:
  created:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-golden-expected-4.txt
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-rebless4-code-change.diff
  modified:
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
decisions:
  - "Round 4's generator hardens all five bare `grep` invocations to `/usr/bin/grep` and moves the rationale prose onto its own `#` lines above the command — the only two byte-level departures from round 3's generator, both recorded in the header and in REFREEZE-LEDGER-4 (c)."
  - "`expected_t_count = 0` is disclosed with its derivation and its consequence rather than compensated for by a manufactured floor: batch 4's removals are ordinary English that V3 structurally cannot match, so both non-vacuity floors are off this round and four non-floor proofs carry the verdict instead."
metrics:
  duration: ~25m
  completed: 2026-09-18
actuals:
  tokens: 8036
  tasks: 2
  commits: 3
---

# Phase 239 Plan 15: Batch-4 Re-bless of the Install Golden Fixture Summary

The false `mix sigra.install generates no tests` claim is gone from the golden fixture — the tier
that models an adopter's bytes and the tier plan 239-12 blessed it into — carried there by one
batched, comment-only-proven, path-isolated re-bless whose justification and expected set were both
frozen in a strictly earlier commit.

## What Was Built

Three atomic commits, in the D-19 freeze-then-bless topology:

| # | Commit | What |
|---|---|---|
| 1 | `b7113488` | D-29 batch-4 justification discharged; `239-golden-expected-4.txt` frozen; round-4 known-bad fixture committed; § `REFREEZE-LEDGER-4` written |
| 2 | `5f7ae9d7` | The re-bless — **one path**, `tree/…/live/invitation_accept_live.ex`, and nothing else |
| 3 | `40a3a6b4` | § `REBLESS-COMMIT-4` (the shas neither earlier commit could carry) |

### The D-29 discharge, mechanical rather than asserted

The `BATCH-4-JUSTIFICATION-PENDING` marker plan 239-14 opened is gone from `239-EVIDENCE.md` —
`/usr/bin/grep -c` → **0**, paired with `/usr/bin/grep -c '^## BATCH-JUSTIFICATION'` → **1** as the
live control on the same file. The marker appeared **twice** (the slot itself plus a
`BATCH-4-SWEEP-COMMIT` closing note); both were rewritten, the second preserving its historical
statement without the literal token.

The filled slot names the composition (the single `@moduledoc` retraction `7592e760`, mirrored by
`a13c40bc`, two removed template lines rendering into one golden file), the not-foldable argument
(*batch 3 is what made batch 4 necessary — an edit that corrects a prior batch cannot, by
construction, have been folded into that batch*), and the running count with shas: **3 before**
(`38c9bd9a`, `265f7195`, `87581665`), **4 after**.

### The floor situation, disclosed before the green

Round 4's expected set is **2 `N:` records, 0 `T:`, 1 distinct path**. That makes
`expected_t_count = 0` (the classifier prints `removed_lines_floor=0`) and `GOLDEN_MIN_FILES = 1` on a
one-file batch — **both** non-vacuity floors effectively off. Rather than manufacture a floor, the
ledger records the derivation, the reason (the retracted clause carries no identifier of any shape V3
matches — the same structural fact that made batch 3's sentences invisible to V2), the four
compensating proofs that depend on neither floor (the empty-input guard, the per-line containment
classification, `--check` exit 0, and the golden-tier fixed-string zero with its live control), and
the residual stated plainly.

`GOLDEN_MIN_FILES=1` is also the RED demonstration's floor. The two `1`s coincide **arithmetically** —
one measured from the expected set's distinct-path count, one a deliberate bypass for a one-hunk
fixture — and the ledger says so, because a reused number is indistinguishable from a disabled one.

### Measurement hygiene, applied

- The round-4 generator was **extracted from round 3's header line programmatically**, never retyped,
  with the inline `#` stripped and all five bare `grep` calls hardened to `/usr/bin/grep` (verified:
  5 hardened, 0 bare residue). The command line carries no inline `#`.
- The `T:` pass returning **0** is paired with `control_defmodule=78` over the same 84-file list — the
  zero is a finding about the tree, not a dead grep.
- The generated set has **2** records; a record-less file would have been treated as a broken
  generator and a halt.

## Verification Results

| Gate | Result |
|---|---|
| Precondition `--check` | exit **2**, `DRIFT DETECTED:` on exactly 1 file |
| Classifier RED (known-bad fixture) | exit **1**, `nonconforming=1`, offending line named (`-  defp render_mismatch(assigns) do`) |
| Classifier fail-closed on empty input | exit **1**, `refusing to report success` |
| Classifier GREEN (real diff, `GOLDEN_MIN_FILES=1`) | exit **0** — `changed_lines=4 removed_lines=2 files=1 nonconforming=0 nonconforming_removed=0 nonconforming_files=0 nonconforming_addonly_hunks=0 removed_lines_floor=0` |
| Determinism | the two captured re-bless diffs are byte-identical |
| Post-commit `--check` | exit **0**, `OK: fixture is up-to-date (check mode).`; `git diff --quiet` → 0 |
| Golden-tier retraction | retracted clause **0** files / control `by construction, not by convention` **1** / corrected clause **1** |
| Security lines byte-intact | imperative **1**, `Jetstream #907 / CVE-2026-1529` **1** |
| `STDOUT.txt` under V3 | hits **0**, control (`sigra`) **83**, 186 lines |
| `239-v3-vocabulary-check.sh golden` | exit **0** — `hits=0 allowlisted=0 hits_outside_allowlist=0 control_defmodule=78 files_measured=84` |
| Commit topology | `git merge-base --is-ancestor b7113488 5f7ae9d7` → **0**; `git log … b7113488..HEAD -- test/fixtures/install_golden \| wc -l` → **1**; re-bless paths outside the fixture → **0**; freeze commit fixture paths → **0** |
| Instruments byte-unchanged | `git diff --name-only b7113488~1..HEAD --` classifier + V3 script + allowlist → **empty** |
| Forbidden paths | `git diff --name-only b7113488~1..HEAD -- .github/ .planning/REQUIREMENTS.md 239-13-PLAN.md` → **empty** |
| SURF-03 | still `[ ]` — `/usr/bin/grep -c '^- \[ \] \*\*SURF-03\*\*'` → **1**, roll-up row at `:160` still `Pending` |
| 239-13 sequencing | `wave: 16`, `depends_on: ["239-15"]` — intact |
| Guards | `refusing to report success` → **4**; `floor_removed="$expected_t_count"` → **1** |

Exit 3 (instrument cannot answer) was never raised.

## Deviations from Plan

**1. [Rule 1 — Plan prose] The `--check` success string is transposed in the plan**

- **Found during:** Task 2.
- **Issue:** the plan quotes `OK: fixture is up-to-date (check mode.)`. The task prints
  `OK: fixture is up-to-date (check mode).` — period outside the parenthesis.
- **Fix:** none needed in code. The verbatim task output is recorded in § `REBLESS-COMMIT-4` (d) with
  the discrepancy named, so a later reader is not misled into thinking the string was matched loosely.
- **Commit:** `40a3a6b4`.

**2. [Rule 3 — Blocking] The pending marker appeared twice, not once**

- **Found during:** Task 1.
- **Issue:** the acceptance criterion greps `239-EVIDENCE.md` as a whole for **0** occurrences, but
  the literal also sat in § `BATCH-4-SWEEP-COMMIT`'s closing note (plan 239-14's own record that the
  slot was left open). Discharging only the slot would have left the count at 1 and failed the gate.
- **Fix:** the second occurrence was rephrased to preserve its historical claim ("the slot was left
  open, carrying a greppable pending marker … plan 239-15 discharged it") without the literal token.
- **Commit:** `b7113488`.

**3. [Rule 3 — Measurement hygiene, pre-emptive] Round 3's generator hardened**

Round 3's generator used bare `grep` five times. Copied verbatim into this environment that is the
exact shape of a confident false negative this phase has already been burned by. All five were
substituted programmatically (`sed` over the extracted header tail), verified 5-for-5 with a
zero-residue control, and both departures from round 3's bytes are recorded in the frozen file's
header and in § `REFREEZE-LEDGER-4` (c).

## Deliberate Non-Actions

- **No `MIX_ENV=test mix ci`**, no generated app, no tarball, no `scripts/ci/install-smoke.sh`, no
  SC-5 re-proof — every live external observation stays plan 239-13's.
- **SURF-03 not re-checked.** `.planning/REQUIREMENTS.md` untouched.
- **`239-13-PLAN.md` untouched** — its `T-239-12-03` amendment landed in plan 239-14 Task 4.
- **`.github/` untouched** (D-23); the three measurement instruments untouched (D-16, D-30).
- **No hand-edit under `test/fixtures/install_golden/`** — only `mix sigra.fixture.rebless_golden`
  wrote there (D-09).

## Known Stubs

None. The only source-tree change is a regenerated fixture file; no module, function, route or config
key was created or altered.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern, or schema change. The one
security-relevant surface in scope — the Jetstream #907 structural defense in the golden counterpart —
is asserted byte-intact (imperative **1**, attribution **1**).

## For The Next Phase

**Plan 239-13** (`wave: 16`, `depends_on: ["239-15"]`) is now unblocked and is the closure's last act:
the live observations on a freshly generated app, the tarball under the D-27 scope, `MIX_ENV=test mix
ci`, SC-5's re-proof, the `## HONEST-CLAIMS` extension, and the SURF-03 re-check — last and alone.
Every line number in this plan's evidence was invalidated by re-bless `5f7ae9d7`; re-derive, never
cite.

## Self-Check: PASSED

Both created files and all three commits verified present at the final HEAD on a clean tree
(Standing Constraint 2). No missing items.
