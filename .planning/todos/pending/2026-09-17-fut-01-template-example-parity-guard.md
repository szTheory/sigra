---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "FUT-01: no guard keeps priv/templates and test/example from silently drifting apart"
area: testing
files:
  - priv/templates/sigra.install/
  - test/example/
  - test/sigra/install/golden_diff_test.exs

source: "Phase 239 plan 03/04 (priv/templates/ sweep + mirror) — the mirror had to be reconciled by hand against a checklist because nothing mechanical compares the two trees"
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

`priv/templates/sigra.install/` (what adopters generate) and `test/example/` (the hand-maintained
demo app the browser suites run against) hold parallel copies of the same modules, and nothing
checks that they stay in agreement. Phase 239 mirrored its sweep by hand via
`239-MIRROR-CHECKLIST.md`; correctness there rested on a human reading two trees.

## Why it matters

This is the mechanism behind the existing "installer template drift" pattern: the example app
gets fixed during demo work, the template does not, and the divergence surfaces only when a
generated-host check fails while the example passes. The reverse also happened inside phase 239
itself — commit `2a34e1c8` edited four templates without touching their example counterparts,
and the drift was invisible until someone diffed them.

## Not fixed here

Standing Constraint 4: found while cleaning, so it is filed rather than built. A parity guard is
a new test surface with real design questions (below), not a line change.

## Why this is harder than a byte diff

The two trees are *deliberately* different and byte parity is the wrong contract:

- the template carries EEx bindings (`<%= web_module %>`, `<%= app_module %>`) that the example
  has already resolved to `ExampleWeb` / `Example`
- the example is `--no-tailwind` and uses the `vt-*` demo design system, so class attributes
  differ by design (`class="modal"` vs `class="vt-modal"`)
- the example carries features the template does not (auth-policy assigns, break-glass
  exemptions, `Layouts.app` wrappers)
- phase 239 added a permanent, constraint-driven prose divergence: two template comments are
  locked into awkward line breaks because the golden fixture pins their neighbour lines
  byte-for-byte, and the example has no such constraint

So the guard has to compare *something narrower* than the file — most plausibly the set of
public function heads and moduledoc first sentences, or an explicit allowlist of known
divergences that the guard forces you to update deliberately.

## Suggested shape

Start with the cheapest useful version: a test that renders each template through its EEx binding
with the example's own module names and compares the resulting function-head set against the
example's. That catches the "example gained a function the template never got" class, which is
the one that has actually bitten, without pretending the trees are byte-identical.
