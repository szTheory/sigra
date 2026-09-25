---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "SURF-02 is marked Complete in REQUIREMENTS.md but does not hold at HEAD — three @moduledoc blocks still carry bookkeeping onto HexDocs"
area: docs
files:
  - lib/sigra/account.ex
  - lib/sigra/audit.ex
  - lib/sigra/plug/put_active_organization.ex
  - .planning/REQUIREMENTS.md

source: "Phase 239 verification (cross-requirement observation), carried forward by plan 05"
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## For the milestone owner

`SURF-02` is checked `[x]` Complete in `.planning/REQUIREMENTS.md`:

> **SURF-02**: No planning bookkeeping remains in `@moduledoc`/`@doc` ranges that render on HexDocs
> (starting with `lib/sigra/audit.ex:5`), and `mix docs` is warning-free **as a gate** …

It does not hold at HEAD. Three `@moduledoc` blocks — all of which render on hexdocs.pm *and* ship
inside the downloaded Hex tarball — still carry Sigra-internal planning bookkeeping:

| Site | What is still there |
|---|---|
| `lib/sigra/account.ex:16` | `## Email Change (D-01 to D-10)` — a decision-ID range as a published section heading |
| `lib/sigra/audit.ex:7-14` | six `D-NN` references (`D-01`, `D-02`, `D-17..D-18`, `D-20`, `D-23`, `D-13`, `D-24`) |
| `lib/sigra/plug/put_active_organization.ex:9` | `(Phase 18)` |

A `[x]` on a requirement that does not hold is worse than an unchecked one: it removes the item
from every subsequent audit's field of view.

## Not fixed in Phase 239 — deliberately

Phase 239's contract is SURF-01/SURF-03, and **SURF-01 scopes `lib/` to `.planning/` path
references only** — which measure 0, genuinely. Sweeping `lib/` moduledocs is a different surface
with a different requirement. Phase 239 fixing it would silently widen the phase, which its own
overflow rule forbids (Standing Constraint 4: found while cleaning becomes a todo, never an
in-phase fix).

## Where it belongs

**Phase 241's SURF-04 ratchet.** SURF-04 already owns "a monotonic-decrease ratchet on remaining
inline `lib/` comments" and explicitly hard-fails on "HexDocs-rendering doc ranges". These three
sites are that requirement's first three ratchet decrements — and unlike the 472-line tarball `lib/`
body, they are doc-ranges, which SURF-04 gates at zero rather than ratchets.

## The decision this needs from the owner

Either (a) uncheck SURF-02 in `REQUIREMENTS.md` so it re-enters the audit surface and is closed by
Phase 241, or (b) leave it checked and narrow its wording to what was actually achieved (the
`mix docs` warning-free gate and the `audit.ex:5` starting point), filing the three sites above as
SURF-04 scope. Silently leaving the `[x]` against the current wording is the one option that loses
the finding.
