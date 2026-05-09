---
created: 2026-05-08T00:00:00.000Z
title: Write Rulestead recipe (feature-flag your auth flows)
area: docs
files:
  - guides/recipes/integration-rulestead.md
---

## Problem

Rulestead (`~/projects/rulestead`, v0.1.0 on hex) is feature-flag/typed-remote-config infrastructure. It pairs naturally with Sigra for staged auth-method rollouts (e.g. "magic link enabled for org_id in [...] only", "passkeys gated behind beta flag"). No doc currently shows the pattern.

## Solution

Create `guides/recipes/integration-rulestead.md`:

- Why feature-flag auth flows? Staged rollouts, A/B testing recovery UX, opt-in beta features
- Recipe: gate Sigra method availability on a Rulestead flag
- One snippet showing the wiring (`Sigra.magic_link_enabled?(conn) → Rulestead.enabled?("auth.magic_link", conn)`)
- Operational notes: flag changes don't invalidate live sessions; auditing flag flips via Sigra.Audit

~150 words plus one snippet. No code integration in either library.
