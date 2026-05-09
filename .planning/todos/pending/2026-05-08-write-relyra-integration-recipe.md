---
created: 2026-05-08T00:00:00.000Z
title: Write Relyra (SAML SSO) integration recipe
area: docs
files:
  - guides/recipes/integration-relyra.md
---

## Problem

Relyra (`~/projects/relyra`, v1.1.0 on hex) is a SAML 2.0 Service Provider library for federating enterprise IdPs (Okta, Entra, Google Workspace) into a Phoenix app. The B2B persona — a Sigra user shipping to enterprises — needs SAML SSO. There's no doc explaining how Relyra sits beside Sigra.

## Solution

Create `guides/recipes/integration-relyra.md`:

- Sigra = local user accounts + MFA + passwords + organizations
- Relyra = federate enterprise IdPs *into* Sigra users (enterprise customer's Okta admin SSOs their staff into the Sigra-backed app)
- Wiring outline: Relyra resolves a SAML assertion → upserts a Sigra user → completes session
- Useful for the B2B persona; not needed for prosumer/B2C apps

~200 words. Same shape as the Lockspire recipe (C3) — layered explanation, complementary positioning.
