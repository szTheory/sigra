---
created: 2026-05-08T00:00:00.000Z
title: Write Threadline integration recipe (cross-link, until adapter ships)
area: docs
files:
  - guides/recipes/integration-threadline.md
---

## Problem

Threadline (`~/projects/threadline`, v0.5.0 on hex) already ships `Threadline.Integrations.Sigra` — a one-way capture path that ingests Sigra audit events. Adopters running both libraries today have no documented setup path. The bidirectional adapter is deferred (SEED-006), but the existing one-way path deserves a recipe now.

## Solution

Create `guides/recipes/integration-threadline.md`:

- What Threadline adds beyond `Sigra.Audit` (timeline querying, retention policies, incident-bundle export, LiveView explorer)
- How `Threadline.Integrations.Sigra` wires up — pointer to Threadline's docs for the host-side install steps
- What works today (one-way capture) and what's deferred (`Sigra.Audit.Adapters.Threadline` per SEED-006)
- When to choose Threadline vs the schema-local audit table

200–400 words. Cross-link to SEED-006 for the future bidirectional adapter.
