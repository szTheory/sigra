---
created: 2026-09-18T00:00:00.000Z
status: pending
title: "The packaged docs/ + README.md + CHANGELOG.md surface ships 58 `.planning/` references inside the Hex tarball"
area: docs
files:
  - mix.exs
  - CHANGELOG.md
  - README.md
  - docs/

source: "Phase 239 gap closure, plan 239-10 (D-27) — SC-2 was amended to claim only the tarball's lib/ and priv/. This file is the owner the narrowing leaves behind for everything outside that scope."
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-18
---

## What

`mix.exs:184` packages these paths into the Hex tarball:

```elixir
      files: ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
```

`lib/` and `priv/` are clean — Phase 239 closed them and SC-2 asserts exactly that. `docs/`,
`README.md` and `CHANGELOG.md` are **not**, and they are inside the same downloaded artifact.

Measured at Phase 239's close (`grep -roE '\.planning/'` for occurrences, `grep -c` for lines):

| File | `.planning/` occurrences | Matching lines |
|---|---|---|
| `CHANGELOG.md` | 43 | 19 |
| `docs/uat-ci-coverage.md` | 7 | 6 |
| `docs/ga-evidence.md` | 3 | 3 |
| `docs/nyquist-posture-matrix.md` | 3 | 2 |
| `docs/audit-semantics.md` | 1 | 1 |
| `README.md` | 1 | 1 |
| **Total** | **58** | **32** (6 files) |

Both numbers are recorded because they disagree and either one alone reads as the whole truth:
**58** is the occurrence total `239-VERIFICATION.md` reports for the SC-2 gap, and **32** is the
number of distinct lines a reviewer would actually have to look at.

## Why Phase 239 deliberately did not clean this

Recorded during discussion as **D-05 / D-06 / D-08** in
`.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-CONTEXT.md`, and ratified as
**D-27** in the same file:

- These references are **real provenance links** and deliberate maintainer prose, not leaked
  bookkeeping. `docs/nyquist-posture-matrix.md:11` explicitly states that the path it cites is *not*
  part of the tarball; `CHANGELOG.md:10` deliberately explains the planning-milestone vs SemVer axes.
- `CHANGELOG.md` is additionally **Phase 242's file** (REL-05 folds the `## Unreleased` block), so
  editing it in Phase 239 is a collision.
- Dropping `docs` from the `files:` list was considered and not taken: it removes documentation
  adopters legitimately read in order to make a grep count fall.

The developer's decision was therefore to **narrow the claim and route the surface**, not to clean
it here. Phase 239's SC-2 now says `lib/` and `priv/` explicitly and names this todo.

## Why it matters if ignored

Adopters keep downloading a tarball whose packaged documentation cites a `.planning/` directory that
does not exist in their project. A reader following one of those paths finds nothing, and the
documentation's authority degrades exactly where it is being used as authority. Nothing currently
reports on this surface — no gate greps the tarball's `docs/`, so the count can only grow.

## Owner

**Phase 241, SURF-04.** SURF-04's requirement text in `.planning/REQUIREMENTS.md` was extended by
plan 239-10 to name `docs/`, `README.md` and `CHANGELOG.md` as packaged surfaces its ratchet covers.
This is a **monotonic-decrease** obligation, not a zero target — the same posture SURF-04 already
takes for inline `lib/` comments.

## Related — one cluster, not three unrelated notes

- `.planning/todos/pending/2026-09-17-bookkeeping-leak-guard-on-distribution-boundary.md` — no CI gate
  keeps the generated-app / tarball surface clean once it is proven clean once.
- `.planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md` — the V3
  definition Phase 241's `p18` guard inherits as its spec.

All three are SURF-04 inheritance. A triager should read them together: this file supplies the
*surface*, the V3 file supplies the *definition*, and the leak-guard file supplies the *mechanism*.
