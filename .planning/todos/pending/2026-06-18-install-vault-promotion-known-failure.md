---
created: 2026-06-18T00:00:00.000Z
status: pending
title: vault_promotion_test.exs known failure — undefined attribute for CoreComponents.button/1 under --warnings-as-errors
area: test
files:
  - test/sigra/install/vault_promotion_test.exs
source: phase 192 quarantine (D-11/D-12)
---

## What

`test/sigra/install/vault_promotion_test.exs` fails because the installed app's
CoreComponents.button/1 does not accept a "type" attribute under --warnings-as-errors.
The installer template emits code using an attribute that the generated host's
CoreComponents does not expose. Reproduces identically on clean `origin/main`.

## Fix direction

Update the installer template for the passkeys vault path: either (a) remove the
`type` attribute from the generated button call, or (b) align with the CoreComponents
API in the target Phoenix/LiveView version. Confirm fix against phx_new 1.8.7
(SEED-004 pinned version).

## Quarantine

Tagged `@moduletag known_failure: "..."` in phase 192. Remove the tag when the
template is fixed and the test is green on both local and CI.
