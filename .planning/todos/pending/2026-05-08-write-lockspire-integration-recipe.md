---
created: 2026-05-08T00:00:00.000Z
title: Write Lockspire cross-link recipe (you-as-OAuth-provider)
area: docs
files:
  - guides/recipes/integration-lockspire.md
---

## Problem

Lockspire (`~/projects/lockspire`) is an embedded OAuth/OIDC provider library — it lets your Phoenix app *be* an OAuth provider to external services. Adopters frequently confuse this with Sigra ("isn't this duplication?"). No doc currently disambiguates the layering.

## Solution

Create `guides/recipes/integration-lockspire.md`:

- Sigra = your app's *own* user accounts (sessions, passwords, MFA, passkeys)
- Lockspire = your app *as* an OAuth provider to other apps (your Sigra users become OAuth identities for partners)
- They sit at different layers — complementary, not competing
- One-line recipe: "Use Sigra for your SaaS login. Use Lockspire if you want partners to OAuth-sign-in via your app."

~200 words. No code integration needed beyond the layering explanation.
