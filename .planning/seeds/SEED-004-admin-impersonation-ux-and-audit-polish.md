---
id: SEED-004
status: deferred
planted: 2026-05-08
planted_during: post v1.24 cleanup
trigger_when: When the next admin UX / audit polish milestone is planned, especially if generated-host admin navigation or audit preview surfaces are being revisited
scope: Small to Medium
---

# SEED-004: Polish impersonation discoverability and audit parity

## Why This Matters

Sigra already has a working impersonation path, so this is not a feature-gap seed. The useful follow-up work is polish: make the admin entry points easier to find, keep the impersonation banner and restore flow obvious, and make the audit surfaces continue to read like one coherent story.

This seed exists so we remember that impersonation is a good quality-of-life/admin-safety capability worth tightening at the edges, without treating it as a missing core feature.

## When to Surface

Trigger this seed when the next milestone includes one or more of:

- admin shell / navigation polish
- generated-host admin parity work
- audit preview / audit explorer visual coherence
- impersonation restore or blocked-action UX cleanup

It should stay deferred during unrelated core feature work.

## Scope Estimate

Small to medium polish slice:

- improve generated-host discoverability for impersonation start/stop
- keep banner, restore, and blocked-action copy aligned across example and generated hosts
- verify audit preview labels and impersonation visibility stay coherent
- add a lightweight UX/acceptance pass if any route or banner text changes

## Breadcrumbs

- [`lib/sigra/admin/live/user_show_live.ex`](/Users/jon/projects/sigra/lib/sigra/admin/live/user_show_live.ex)
- [`priv/templates/sigra.install/admin/impersonation_controller.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/impersonation_controller.ex)
- [`.planning/PROJECT.md`](/Users/jon/projects/sigra/.planning/PROJECT.md)
- [`.planning/MILESTONES.md`](/Users/jon/projects/sigra/.planning/MILESTONES.md)
- [`test/example/test/example_web/controllers/impersonation_controller_test.exs`](/Users/jon/projects/sigra/test/example/test/example_web/controllers/impersonation_controller_test.exs)

## Notes

- This seed should not reopen the core impersonation feature.
- If future work needs new impersonation behavior, that belongs in a new milestone phase, not this seed.
- Treat this as an admin UX/audit polish reminder only.
