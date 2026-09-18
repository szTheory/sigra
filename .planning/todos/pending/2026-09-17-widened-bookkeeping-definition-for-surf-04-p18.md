---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "Phase 241's SURF-04 p18 guard must be built on the widened bookkeeping definition (V2), not the frozen V1 union regex"
area: ci
files:
  - scripts/ci/prohibitions/
  - priv/templates/
  - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md

source: "Phase 239 plan 05 (gap closure) — 239-VERIFICATION.md rated the phase's own instrument `failed`: the frozen union regex is structurally incapable of matching the bookkeeping that is still shipping."
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

Phase 241 SURF-04 builds a permanent `scripts/ci/prohibitions/p18-*.test.mjs` guard against
adopter-visible planning bookkeeping. It must be built on the **widened definition (V2)** recorded
below, not on the V1 union regex frozen in `239-EVIDENCE.md` § `## PREFLIGHT-UNION-LEDGER`.

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

`239-EVIDENCE.md` § `## WIDENED-UNION-LEDGER` carries V2 verbatim, a **per-alternation positive
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
