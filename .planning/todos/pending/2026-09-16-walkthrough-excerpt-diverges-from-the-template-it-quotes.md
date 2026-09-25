---
created: 2026-09-16T00:00:00.000Z
status: pending
title: The code-walkthrough excerpt no longer matches the template it claims to quote, and nothing guards the pair
area: docs
severity: minor
source: phase 237 code review (WR-03)
files:
  - guides/introduction/code-walkthrough.md
  - priv/templates/sigra.install/core/session_controller.ex
  - test/sigra/architecture_guides_contract_test.exs
---

## Problem

Phase 237 plan 02 rewrote `guides/introduction/code-walkthrough.md:170-176` to extract
`query = %{routing_source: "local_policy"}` into its own binding. The motive is legitimate and
documented (commit `e0d98092`): the inline `{%{` sequence opens a Liquid tag and crashed the
Jekyll Pages build. Behavior is identical.

The cost is that `priv/templates/sigra.install/core/session_controller.ex:98` still emits the
inline form, in a guide whose entire premise is "this is the code you will read." The guide and
the template have silently diverged.

Nothing catches this: the `@source_anchors` list in
`test/sigra/architecture_guides_contract_test.exs:28-70` pins seven guide/source line pairs, and
this redirect is not one of them.

## Suggested fix

Either restore the excerpt to match the template using a Liquid-safe spelling, or add this pair
to `@source_anchors` so the divergence is asserted rather than assumed. The second option is the
one that prevents recurrence.

## Why it was not fixed in phase 237

Out of plan 02's declared scope, and the Pages build is green as-is. Filed rather than
guess-fixed.
