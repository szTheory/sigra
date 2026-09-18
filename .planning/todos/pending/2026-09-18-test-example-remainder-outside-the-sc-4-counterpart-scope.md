---
created: 2026-09-18T00:00:00.000Z
status: pending
title: "The unswept test/example/ remainder — 482 V3-matching bookkeeping lines across 157 files, outside the SC-4 counterpart scope Phase 239 cleans"
area: docs
files:
  - test/example/
  - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
  - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh

source: "Phase 239 gap-closure plan 09 (D-30) — measured while fixing the V3 tier file lists, deliberately routed rather than swept"
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-18
---

## What was measured

At Phase 239's gap-closure base, the **V3 vocabulary definition** (`239-EVIDENCE.md`
§ `## VOCABULARY-LEDGER` (a); runnable as
`.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh`) over
every tracked file in `test/example/` **except** the two SC-4 mirrored counterparts Phase 239 does
clean:

```bash
V3='<see 239-EVIDENCE.md § VOCABULARY-LEDGER (a) — V3 verbatim>'
REM=$(git ls-files test/example \
  | grep -vxF -e 'test/example/lib/example_web/live/invitation_accept_live.ex' \
              -e 'test/example/lib/example_web/live/organization_members_live.ex')
{ grep -HnE "$V3" $REM || true; } | grep -c '.'                       # => 482   lines
{ grep -HnE "$V3" $REM || true; } | cut -d: -f1 | sort -u | wc -l     # => 157   files
```

**482 lines across 157 files**, out of 344 scanned files. (V2 over the same set returns 480; the
vocabulary class adds 2 there.)

Top contributors by line count:

| File | Lines |
|---|---|
| `test/example/priv/playwright/lib/eval/probes.ts` | 38 |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` | 33 |
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | 29 |
| `test/example/lib/example/demo/seeds.ex` | 18 |
| `test/example/priv/playwright/playwright.config.ts` | 17 |
| `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` | 16 |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | 15 |
| `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` | 14 |
| `test/example/priv/playwright/tests/organizations.spec.ts` | 12 |
| `test/example/test/example_web/live/organization_members_live_test.exs` | 11 |

**Severity note, from the measurement rather than from the estimate.** The bulk of the remainder is
in `test/example/priv/playwright/` — browser-test tooling that is *not* adopter-shipped. That is a
materially lower-severity surface than the application code the planning estimate anticipated
(`seeds.ex`, `personas.ex`, `design_gallery_live.ex`, `config/*.exs`, `README.md` — only `seeds.ex`
appears in the measured top ten). Whoever triages this should weight it accordingly rather than
treating 482 lines as 482 lines of adopter-facing leakage.

## Why Phase 239 deliberately did not clean it

- **SC-4 scopes the phase's `test/example/` work to mirrored counterparts** — only the
  `test/example/` counterparts of edited templates are mirrored. The two counterpart files are the
  whole of Phase 239's contract inside that tree.
- **`239-RESEARCH.md` § 1.6** measures a repo-wide `test/example/` sweep at **4.3x** over the
  D-19/SC-4 scope, colliding with surfaces this milestone has not cleared.
- It cannot fit gap-closure plan 239-11's fixed two-file commit scope, and would break D-19's
  commit topology (sweep → mirror → re-bless, each alone in its commit).

Recorded as **D-30** in `239-EVIDENCE.md` § `## VOCABULARY-LEDGER` (k): the instrument's detection
width stays maximal, while the criterion asserts `hits_outside_allowlist = 0` over a scoped,
pre-committed tier file list. This number is the part deliberately left outside that surface — named
and routed, never dropped.

## Owner

**Phase 241 — SURF-04.** SURF-04 already owns the monotonic-decrease ratchet on remaining inline
comments and explicitly does not target zero for v1.48. This remainder is ratchet input, not a
zero-gate surface.

## Sibling todos — read these three as one cluster, not three unrelated notes

- `.planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md` — the
  definition Phase 241's `p18` guard must inherit (now V3, superseding V2).
- `.planning/todos/pending/2026-09-17-surf-02-marked-complete-but-does-not-hold-at-head.md` — three
  `@moduledoc` sites that render on HexDocs, also routed to SURF-04.
- this file — the `test/example/` remainder.

## Review finding IN-06 — routed by finding, because V3 cannot measure it

**`IN-06` = `test/example/priv/playwright/tests/golden-path.spec.ts:59`**

```
// The login page is a plain controller (post plan 04). If we are already
```

A lowercase plan reference inside a test-tooling comment; example-only, not adopter-shipped.
`239-REVIEW.md` records it with a one-line fix.

**It is named here by hand rather than found by measurement, because V3 does not match it.** The
reference is lowercase, so neither V2's `\bPlan [0-9]{2}\b` identifier alternation nor any V3
vocabulary alternation fires on it. Proven, not assumed (`239-EVIDENCE.md` § `## VOCABULARY-LEDGER`
(j)): V3 reports 6 hits in that file and line 59 is not among them —

```bash
{ grep -nE "$V3" test/example/priv/playwright/tests/golden-path.spec.ts || true; } | grep -c '^59:'
# => 0
```

This matters beyond one line. It is direct evidence of a **vocabulary class V3 still misses**
(case-insensitive plan references), and therefore a real input to Phase 241's `p18` spec — consider
case-folding the plan-reference alternations, or block-aware rather than line-based matching. IN-06
is the only Phase 239 review finding with no disposition elsewhere in the gap closure (IN-01 … IN-04
are explicitly deferred in plan 239-11; IN-05 is filed by plan 239-10), so without this entry it is
invisible to the executor.
