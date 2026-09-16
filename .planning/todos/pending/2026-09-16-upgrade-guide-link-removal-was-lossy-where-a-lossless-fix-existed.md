---
created: 2026-09-16T00:00:00.000Z
status: pending
title: Three upgrade-guide sentences lost their referent instead of gaining a working link
area: docs
severity: minor
source: phase 237 code review (WR-02, IN-01, IN-02)
files:
  - guides/introduction/upgrading-to-v1.10.md
  - guides/introduction/upgrading-to-v1.11.md
  - mix.exs
  - lib/sigra/audit.ex
---

## Problem

Phase 237 plan 05 removed three dead relative `.planning/` links from the upgrade guides and
kept each sentence's claim as prose. That cleared the ExDoc warnings and let two
`skip_undefined_reference_warnings_on` entries go (9 → 7), which was the plan's goal. The
review found the rewrite is lossy in three places where a lossless option was already
established in this same repository.

**WR-02 — a conditional now gates a non-action.** `guides/introduction/upgrading-to-v1.10.md:9`
reads:

> If you have not followed **v1.9** audit-atomicity work yet, note that **v1.10** builds on that
> shipped baseline

The imperative ("read the archived roadmap") was deleted but its conditional clause survived, so
the sentence makes a reader check a precondition for an action that is no longer there. Line 5
and `upgrading-to-v1.11.md:7` similarly name documents with no way to reach them.

All three targets are real files, tracked in this public repository. The ExDoc-safe pattern for
exactly this case is already used at `guides/introduction/intermediate-production-path.md:19` and
`guides/introduction/upgrading-to-v1.12.md:7-8`: an absolute GitHub blob URL, which ExDoc does
not try to resolve and which therefore needs no suppression entry. Using it here restores the
referent without reintroducing a warning or an entry.

**IN-01 — the corrected `mix.exs` comment is one clause short.** `mix.exs:190` still leads with
"ExDoc only autolinks extras by basename", which was the justification for the two *removed*
entries. The review's positive control (empty the list, re-run `mix docs --warnings-as-errors`)
produced 10 warnings, all hidden-function or undefined-callback — none basename-autolink. That
lead clause is the same false-comment defect 237-05 set out to fix.

**IN-02 — orphaned decision IDs.** `lib/sigra/audit.ex:5-9` still carries `(D-01)`, `(D-02)`,
`(D-17..D-18)` after the pointer that resolved them was deleted. `lib/sigra/testing.ex` handled
the identical case in the same diff by inlining the substance; `audit.ex` did not.

## Why it was not fixed in phase 237

All three are outside the plans' declared scope and none blocks the gate — `mix docs
--warnings-as-errors` exits 0 at HEAD. Filed rather than guess-fixed.
