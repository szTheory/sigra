---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "Phase 241's SURF-04 p18 guard must be built on the twice-widened bookkeeping definition (V3 — vocabulary class), not on V2 and not on the frozen V1 union regex"
area: ci
files:
  - scripts/ci/prohibitions/
  - priv/templates/
  - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
  - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh

source: "Phase 239 plan 05 (gap closure) — 239-VERIFICATION.md rated the phase's own instrument `failed`: the frozen union regex is structurally incapable of matching the bookkeeping that is still shipping."
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

Phase 241 SURF-04 builds a permanent `scripts/ci/prohibitions/p18-*.test.mjs` guard against
adopter-visible planning bookkeeping. It must be built on the **twice-widened definition (V3)**
recorded below — not on V2, and not on the V1 union regex frozen in `239-EVIDENCE.md`
§ `## PREFLIGHT-UNION-LEDGER`.

> **Amended 2026-09-18 by gap-closure plan 239-09.** This file previously named **V2** as the
> definition Phase 241 must inherit. **That statement is superseded.** V2 is kept below in full,
> deliberately — the point of this file is the audit trail of an instrument that has now been
> widened *twice*, and each widening's diagnosis is what stops the next one from being needed.

**V3, verbatim — this is the definition Phase 241 inherits:**

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]|\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md
```

The **vocabulary class** V2 lacks — the eight alternations V3 adds:

```
\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md
```

V3 is V2 plus that class, appended — so V2 is a literal substring of V3 and "strictly wider" is a
mechanically checkable property, asserted at runtime by
`239-v3-vocabulary-check.sh` (fail-closed exit 3 if it ever stops holding).

**Per-alternation live positive controls** — a dead alternation returns a reassuring zero, so each
addition fires on a named surface with a non-zero count:

| Alternation | Control surface | Count |
|---|---|---|
| `\b[Pp]lan[- ]checker\b` | `239-VERIFICATION.md` | 4 |
| `\bthis phase\b` | `239-CONTEXT.md` | 4 |
| `\bthe plan\b` | `239-09-PLAN.md` | 2 |
| `v[0-9]+\.[0-9]+ concern` | `239-VERIFICATION.md` | 3 |
| `\bgap[- ]closure\b` | `.planning/ROADMAP.md` | 4 |
| `\bre-?bless\b` | `.planning/ROADMAP.md` | 4 |
| `\bROADMAP\b` | `.planning/ROADMAP.md` | 13 |
| `SUMMARY\.md` | `.planning/ROADMAP.md` | 1 |

## Why V2 was not enough

`239-VERIFICATION.md` failed SC-1 a second time. Two Sigra-internal sentences still ship into every
generated app, and **V2 is structurally blind to both**:

| Site (all three tiers) | Sentence |
|---|---|
| `…/organizations/live/invitation_accept_live.ex:326` | `# The plan-checker greps this function body and asserts zero matches.` |
| `…/organizations/live/organization_members_live.ex:24` | `Flop / sortable columns are a v1.2 concern.` |

V2 matches plan **identifiers** — `D-12`, `239-05`, 10-digit run ids, `UAT`. These two sentences are
plan **vocabulary** and contain no identifier of any shape V2 knows. That is V1's blind spot one
class up: widening the identifier set could never have caught them, however far it was widened.
Editing the two sentences without widening the instrument would have closed the symptom and left the
mechanism intact, so the next vocabulary-class leak would ship under a green measurement exactly as
these two did.

Measured consequence, V2 → V3, at the gap closure's base:

| Surface | V2 hits | V3 hits (raw) | V3 outside allowlist |
|---|---|---|---|
| `priv/templates/` | 1 | 3 | 2 |
| SC-4 `test/example/` counterparts | 0 | 2 | 2 |
| `test/fixtures/install_golden/tree/` | 0 | 2 | 2 |

**A third gap V3 still has, recorded rather than absorbed.** Review finding `IN-06`
(`test/example/priv/playwright/tests/golden-path.spec.ts:59`, `post plan 04`) matches **neither** V2
**nor** V3 — the plan reference is lowercase. Phase 241 should consider case-folding the
plan-reference alternations and block-aware rather than line-based matching. See
`.planning/todos/pending/2026-09-18-test-example-remainder-outside-the-sc-4-counterpart-scope.md`.

---

## V2 — kept as history, superseded by V3 above

**V2, verbatim:**

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]
```

The six alternations V1 lacks:

```
\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]
```

## Diagnosis

V1's plan-ID alternation is `[0-9]{3}-[A-Z0-9-]+\.md` — it **requires a trailing `.md`**, so a bare
plan ID such as `231-02` is unmatchable. V1 has no alternation at all for `round N`, for 10-digit
GitHub Actions run IDs, or for `UAT`. Measured consequence at Phase 239's HEAD:

| Surface | V1 lines | V2 lines |
|---|---|---|
| `priv/templates/` | 0 | 5 (4 after this plan's `login_html.ex` fix) |
| `test/fixtures/install_golden/tree/` | 0 | 4 |

V1 certified both surfaces clean. They were not clean. Every SC-1/SC-2 "greps clean" claim in Phase
239 inherits that blind spot.

## Consequence if ignored

Phase 241 depends on Phase 239 — "the surface must be clean before it is gated". A `p18` guard
built on V1 would *freeze the blind spot permanently*: the guard would report green forever on
exactly the bookkeeping class it exists to block, and the leak becomes invisible by construction.

## Where the evidence is

`239-EVIDENCE.md` § `## VOCABULARY-LEDGER` carries V3 verbatim, its eight per-alternation
positive controls, the recall-pass keep/drop record, the three fixed tier file lists, the committed
allowlist with its non-vacuity and union controls, the three-tier RED table, and the full per-hit
triage. § `## WIDENED-UNION-LEDGER` carries V2 verbatim, a **per-alternation positive
control** (each of the six proven to fire on a named surface with a non-zero count, so a zero on
`priv/templates/` is a real negative and not a dead alternation), the V1↔V2 delta table above, and
the per-hit triage of every V2 match.

Two things for the guard's author to inherit deliberately:

1. **Pair every zero with a positive control.** The ledger's own file-count control
   (`grep -lc defmodule $(git ls-files priv/templates) | wc -l` => 97) is what distinguishes "clean
   tree" from "empty file list"; `p03-no-green-on-empty-grep` applies directly.
2. **Line-based matching has a residual gap.** In `sigra_auth.css` the phrase `after rounds\n 1-2.`
   is split across two lines and matches nothing; so do `Live multi-run CI evidence` and `do not
   re-litigate this`. All three sit inside comment blocks the wider net *did* catch, so Phase 239
   loses nothing — but a line-based `p18` inherits the gap. Consider block/comment-aware matching.

## Not built here

Phase 239 Standing Constraint 5: this phase builds **no guard**. The widened definition is wired
into nothing — not `mix ci`, not `.github/workflows/`, not `scripts/ci/prohibitions/*.test.mjs`.
Phase 239 only measures with it and records it. The `p18` slot is Phase 241 SURF-04's work.
