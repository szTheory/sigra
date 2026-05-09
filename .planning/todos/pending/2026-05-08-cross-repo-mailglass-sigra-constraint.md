---
created: 2026-05-08T00:00:00.000Z
title: Cross-repo — widen Mailglass's Sigra version constraint
area: cross-repo
files:
  - ~/projects/mailglass/mix.exs
---

## Problem

Mailglass declares `{:sigra, "~> 0.2", optional: true}` at `~/projects/mailglass/mix.exs:154`. Current Sigra is v1.24 — the constraint is stale by ~22 minor versions. As-is, any host that pulls in both libraries can't resolve dependencies, blocking the Mailglass adapter path described in SEED-005.

This is a **Mailglass-side fix**, not a Sigra task, but tracked here so it doesn't get lost while EMAIL-RAILS is being planned.

## Solution

In the mailglass repo (separate working tree at `~/projects/mailglass`):

- Widen the constraint to `~> 1.0` or `~> 1.20 or ~> 1.0`
- Re-test the optional integration path with both libs present
- Open a release for mailglass once the constraint widens and any code-side adjustments are made
- Cross-link to SEED-005 in the commit message

This unblocks the Mailglass adapter evaluation in EMAIL-RAILS.
