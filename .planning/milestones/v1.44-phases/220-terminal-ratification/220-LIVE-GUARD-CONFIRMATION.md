# Phase 220 Plan 03: Live Guard Confirmation (SC-1)

**Captured:** 2026-07-10T02:21:11Z
**Branch:** `gsd/phase-219-baseline-recapture-canary-reconciliation`
**HEAD:** `4b542a3806f41a03c1a06a9721d3fbf617b00b19`
**Resolved merge-base (`git merge-base origin/main HEAD`, mirrors `ci.yml:79-85`'s
`git merge-base "origin/${{ github.base_ref }}" HEAD`):**
`f2e54612350d96b73eda945eb3c228a1b596ec4a` (`Merge pull request #68 from
szTheory/chore/v1.43-milestone-close`, 2026-07-03)

This record proves SC-1 (the forward-only monotonic lock) holds LIVE against the real
terminal-PR merge-base, per D-01 (verify-then-confirm — no cell re-rendered/re-climbed, no
guard weakened) and D-02 (the lock is proven by live execution, not a doc assertion). It also
carries the PI-1 honesty note and the 216 SC-5 preview-vs-authoritative framing required by the
plan's must-haves.

## Command 1 of 4 — `quality-ledger-monotonic.sh --base <MB>`

```
$ bash scripts/ci/quality-ledger-monotonic.sh --base f2e54612350d96b73eda945eb3c228a1b596ec4a
quality-ledger-monotonic: PASS (36 cells checked vs f2e54612350d96b73eda945eb3c228a1b596ec4a)
```

**Exit code:** 0

This is the SUBSTANTIVE SC-1 forward-lock proof: 36 award sub-score cells in
`guides/reference/admin-quality-ledger.md` were diffed against the real `origin/main`
merge-base and none decreased. Matches the research preview exactly (`PASS (36 cells checked
...)`).

## Command 2 of 4 — `quality-ledger-monotonic.test.sh`

```
$ bash scripts/ci/quality-ledger-monotonic.test.sh
Test A: 2→1 decrease is caught by the guard (must exit non-zero)
  PASS: Guard exited non-zero (1) on 2→1 decrease
  PASS: Guard stderr contains 'tier decreased' on 2→1 decrease
Test B: no-change run exits 0 (guard is not trivially always-failing)
quality-ledger-monotonic: PASS (2 cells checked vs 4bc410ccabc2f861943a2d477d2f05f3677a6287)
  PASS: Guard exited 0 on no-change run
Test C: 1→2 increase exits 0 (guard allows monotonic tier promotion)
quality-ledger-monotonic: PASS (2 cells checked vs 4bc410ccabc2f861943a2d477d2f05f3677a6287)
  PASS: Guard exited 0 on 1→2 increase (monotonic promotion is allowed)
  PASS: Guard stderr has no 'tier decreased' on a 1→2 increase
Test D: decorated column-4 ('2*') is invisible to the guard parse (exits 0, row unprotected)
quality-ledger-monotonic: PASS (1 cells checked vs 4bc410ccabc2f861943a2d477d2f05f3677a6287)
  PASS: Test D: decorated '2*' is invisible to the guard parse (exits 0, not protected)

----------------------------------------
Results: 6 passed, 0 failed
----------------------------------------
quality-ledger-monotonic.test: PASS
```

**Exit code:** 0

Confirms the guard's decrease-detection mechanism itself is sound (hermetic self-test — not a
substitute for the live merge-base run above, which is why both are captured here).

## Command 3 of 4 — `award-guard.mjs --base <MB>`

```
$ node scripts/ci/award-guard.mjs --base f2e54612350d96b73eda945eb3c228a1b596ec4a
fatal: path 'guides/reference/admin-award-ledger.json' exists on disk, but not in 'f2e54612350d96b73eda945eb3c228a1b596ec4a'
award-guard: INFO: no base ledger at f2e54612350d96b73eda945eb3c228a1b596ec4a:guides/reference/admin-award-ledger.json — skipping comparison (initial commit)
```

**Exit code:** 0

## Command 4 of 4 — `award-guard.test.mjs`

```
$ node scripts/ci/award-guard.test.mjs

Case 1: axis A1→A2 with unchanged verified_at_sha → FAIL "climb without fresh render"
  PASS: Guard exits non-zero on climb-without-render
  PASS: Guard stderr contains "climb without fresh render"

Case 2: band typed A2 while axes min is A1 → FAIL "band != min"
  PASS: Guard exits non-zero on band != min(axes)
  PASS: Guard stderr contains "band != min(axes)"

Case 3: raised axis with rendered:false → FAIL "rendered is not true"
  PASS: Guard exits non-zero on raised axis with rendered:false
  PASS: Guard stderr contains "rendered is not true"

Case 3b: raised axis with bogus evidence_ref → FAIL "evidence_ref does not resolve"
  PASS: Guard exits non-zero on unresolved evidence_ref
  PASS: Guard stderr contains "evidence_ref does not resolve"

Case 4: axis A1→A0 (decrease) → FAIL "decreased vs merge-base"
  PASS: Guard exits non-zero on axis decrease
  PASS: Guard stderr contains "decreased vs merge-base"

Case 5a: no-change run → PASS
  PASS: Guard exits 0 on no-change run
  PASS: Guard stdout contains "PASS" on no-change run

Case 5b: legitimate climb (A1→A2 + fresh sha + valid evidence) → PASS
  PASS: Guard exits 0 on legitimate climb
  PASS: Guard stdout contains "PASS" on legitimate climb

----------------------------------------
Results: 14 passed, 0 failed
----------------------------------------
award-guard.test: PASS
```

**Exit code:** 0 (14 passed, 0 failed)

## PI-1 — Honesty note: award-guard's merge-base exit-0 is a skip, not a compare

`award-guard.mjs`'s exit 0 against the real `origin/main` merge-base is a **SKIP-PATH** exit,
not a substantive comparison. `guides/reference/admin-award-ledger.json` (the net-new award
sub-score ledger introduced in Phase 216) does not exist at `f2e54612` — `origin/main`
(the v1.43 close-out) predates the entire v1.44 award-gradient work. `git show <base>:<ledger>`
fails with "exists on disk, but not in `<base>`", and the guard correctly logs
`no base ledger ... skipping comparison (initial commit)` and exits 0.

This is correct guard behavior (an absent base ledger cannot regress), but it must not be
read as "award-guard proved the forward lock against the merge-base" — it did not compare
anything at the merge-base boundary. The chain of custody for award-guard's substantive
forward-lock guarantee is:

- **Intra-branch (216-218):** every award sub-score raise on this branch already passed
  award-guard's D-20 checks (climb-without-render, band != min, unresolved evidence, axis
  decrease) at the commit it was introduced — that is what let those commits land in the first
  place.
- **Self-test (this record, Command 4):** the 14/14 `award-guard.test.mjs` run proves the
  guard's detection logic itself is correct (all 5 violation classes caught, both legitimate
  no-op and legitimate-climb cases pass).

So for SC-1 ("Award sub-score cells locked forward under monotonic guard"):

- **`quality-ledger-monotonic.sh` (Command 1) is the SUBSTANTIVE proof** — it performed a real
  36-cell comparison against the real terminal-PR merge-base and passed.
- **`award-guard.mjs` (Command 3) is exit-0-via-skip** — not a merge-base comparison; its
  forward-lock guarantee rests on intra-branch enforcement plus the self-test, both of which
  are also captured in this record.

No overclaim: the record does not state "both guards compared and held" — it states precisely
what each guard did.

## 216 SC-5 trap — preview vs authoritative

This on-branch run is a **PREVIEW**, not the authoritative committed-HEAD proof. All four
commands above were executed on the local working tree at HEAD `4b542a38`, on branch
`gsd/phase-219-baseline-recapture-canary-reconciliation`, before that HEAD has been submitted
as a pull request and before GitHub Actions has evaluated it.

The 216 SC-5 trap (documented in `.planning/phases/216-harness-foundation-award-gradient/`) is
this: a green self-test run at a pre-commit or pre-PR sha is **not** valid evidence of a
committed-HEAD guarantee — `stale-render-guard` and equivalent mechanisms exist precisely to
reject a bundle whose `bundle_sha` does not match the actual committed HEAD being evaluated.
The same discipline applies here: this record is a reproducible LOCAL rehearsal of what the
guards will do, not a substitute for the real signal.

**The AUTHORITATIVE proof is deferred to the terminal PR:** the same four
invocations — `quality-ledger-monotonic.sh --base <mb>` and its self-test,
`award-guard.mjs --base <mb>` and its self-test — run inside the `fast_checks` job
(`ci.yml:120`, `ci.yml:122`, `ci.yml:133`, `ci.yml:135`) against the merge-base GitHub Actions
resolves at PR-open time (`ci.yml:79-85`, `git merge-base "origin/${{ github.base_ref }}"
HEAD`), evaluated at the PR's actual committed HEAD. That run is confirmed via
`gh pr checks <terminal-pr-number>` once the terminal PR is opened — not asserted here.

This record's value is: (a) it proves the guard commands, base-resolution method, and expected
outputs are exactly correct and reproducible right now, and (b) it gives the close-readiness
record (Plan 04) and the terminal PR a citable, honest, non-overclaiming rehearsal — while
explicitly deferring the binding proof to the on-PR `fast_checks` run.

## Summary

| # | Command | Result | Exit |
|---|---------|--------|------|
| 1 | `quality-ledger-monotonic.sh --base f2e54612` | `PASS (36 cells checked vs f2e54612...)` | 0 |
| 2 | `quality-ledger-monotonic.test.sh` | `6 passed, 0 failed` | 0 |
| 3 | `award-guard.mjs --base f2e54612` | `INFO: no base ledger ... skipping comparison (initial commit)` | 0 |
| 4 | `award-guard.test.mjs` | `14 passed, 0 failed` | 0 |

All four invocations exit 0. No guard code weakened. No cell re-rendered or re-climbed
(verify-then-confirm only, per D-01). SC-1 substantive lock proven by Command 1;
Commands 2-4 corroborate guard-logic soundness and honest skip-path framing. Authoritative
committed-HEAD proof deferred to the terminal PR's `fast_checks` job per the 216 SC-5 trap.
