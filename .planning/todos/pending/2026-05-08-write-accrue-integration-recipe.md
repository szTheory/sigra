---
created: 2026-05-08T00:00:00.000Z
title: Write Sigra + Accrue starter-kit recipe
area: docs
files:
  - guides/recipes/integration-accrue.md
---

## Problem

Accrue is positioned as Sigra's billing companion in the szTheory OSS suite, but no recipe exists describing how the two compose. Adopters who want a complete SaaS starter (auth + billing) have no documented path. The user's broader narrative about an interoperable OSS suite needs a concrete entry point.

## Solution

Create `guides/recipes/integration-accrue.md` documenting the composition pattern:

- Sigra owns user identity, sessions, organizations, and audit
- Accrue owns billing state (subscriptions, invoices, metering)
- Stripe webhooks update Accrue; Sigra reads `org.subscription_tier` for feature gates
- 10-step checkout flow walkthrough (signup via Sigra → org auto-created → Accrue Stripe Checkout → webhook → tier set → Sigra LiveView feature gate)
- Example LiveView feature-gate snippet

No code integration in either library — just a documented recipe.

ExDoc placement: `guides/recipes/` is already wired into the Recipes group at `mix.exs:205–211`; the new file appears automatically.
