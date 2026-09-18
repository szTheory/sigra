---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "install-smoke change detector never exercises mix sigra.upgrade or mix sigra.gen.oauth"
area: ci
files:
  - .github/workflows/ci.yml
  - scripts/ci/install-smoke.sh

source: "Phase 239 plan 04 (single batched re-bless), SC-1 scoping — discovered while establishing which templates a freshly generated app can structurally reach"
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

`scripts/ci/install-smoke.sh` runs `mix sigra.install` and `mix sigra.gen.oauth`, but never
`mix sigra.upgrade`. The change detector at `.github/workflows/ci.yml:450` gates the smoke job
on the same narrow set.

The consequence is structural, not stylistic: 3 of the 46 templates edited in phase 239 are
reachable only through `mix sigra.upgrade`, so no generated-app assertion can ever observe them.
SC-1 in phase 239 was scoped around this — those three templates were covered by SC-2 (the built
tarball) instead, which is a weaker observation because it greps the shipped source rather than
generator output.

## Why it matters

Any defect that only manifests through the upgrade path — a broken EEx binding, a malformed
injection anchor, a template that no longer compiles after substitution — reaches adopters
without a single CI signal. The upgrade path is also the one adopters hit on every version bump,
so it carries more traffic than the install path it is currently invisible behind.

## Not fixed here

Standing Constraint 4: found while cleaning, so it is filed rather than built. Phase 239's scope
was a bookkeeping-token sweep; adding a third generator invocation to the smoke script changes
what CI executes and needs its own plan with its own runtime budget (the smoke job is already
the slowest member of `ci.install_golden`).

## Suggested shape

Extend `install-smoke.sh` with a `mix sigra.upgrade` leg against the app it already scaffolds,
and widen the `ci.yml:450` detector's path globs to match. Assert the same zero-hit token grep
on the upgraded tree that SC-1 asserts on the installed tree.
