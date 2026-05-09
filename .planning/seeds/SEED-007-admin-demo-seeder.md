---
id: SEED-007
status: deferred
planted: 2026-05-08
planted_during: post v1.24 demo-DX gap surfacing
trigger_when: Bundled with EMAIL-RAILS milestone, OR triggered when adopter feedback says "I can't tell what the admin dashboard looks like populated"
scope: Medium
---

# SEED-007: Realistic admin demo seeder for example app

## Why This Matters

Sigra ships 10 admin LiveViews (users index, user detail, audit, webhook subscriptions, webhook delivery failures, org-scoped admin, etc.). They live under `/admin/*` in `test/example/`. But `test/example/priv/repo/seeds.exs` is a 12-line empty stub — there is no realistic demo data.

A new adopter who runs `cd test/example && mix phx.server` and visits `/admin/users` sees an empty list. They cannot tell whether the audit explorer is useful, what the webhook failures page looks like under load, or how the user-detail view paints when a user has MFA + passkeys + OAuth identities + a recent suspicious login. The dashboard's quality only becomes visible under realistic data.

This seed captures the work to produce a believable SaaS scenario that *shows* what the admin surface delivers — addressing the same gap as the upcoming `guides/recipes/run-the-admin-dashboard.md` recipe (which can only point at the empty seeder today).

## When to Surface

Trigger this seed when:

- EMAIL-RAILS milestone planning starts (natural pairing — email preview catalog + admin demo data are both "see what you're building" surfaces)
- Adopter feedback explicitly says "I can't tell what the admin looks like populated"
- A demo-recording or screencast is being prepared for marketing

It should stay deferred during pure feature-build work.

## Scope Estimate

Medium — the *quality* matters more than the LOC:

- New `mix sigra.example.seed` task in `test/example/lib/mix/tasks/`
- At least two scenarios:
  - `--scenario=healthy` — 50 users in 3 orgs, mixed MFA/passkey adoption, plausible time-distributed audit events, healthy webhook deliveries
  - `--scenario=mixed` — same shape plus active impersonation, dead-lettered webhook deliveries (showcases the Webhook Failures page), one suspended account, one churning org
- `--reset` flag to truncate before seeding (idempotent demo refresh)
- Plausible IP / user-agent / geographic distribution (use a small lookup table; don't fake geo per-row)
- Seeded admin user with known credentials documented in the recipe (A3) so adopters can log in
- Lift fixture patterns from `test/example/test/support/fixtures/auth_fixtures.ex` rather than re-deriving

The challenge is *believability* — bad demo data (everyone created "now", same IP, sequential emails) makes the admin surface look worse than it is.

## Breadcrumbs

- [`test/example/priv/repo/seeds.exs`](/Users/jon/projects/sigra/test/example/priv/repo/seeds.exs) — empty 12-line stub today
- [`test/example/test/support/fixtures/auth_fixtures.ex`](/Users/jon/projects/sigra/test/example/test/support/fixtures/auth_fixtures.ex) — existing test fixtures (lift patterns)
- [`lib/sigra/admin/live/`](/Users/jon/projects/sigra/lib/sigra/admin/live/) — the 10 admin LiveViews this work makes visible
- [`guides/recipes/run-the-admin-dashboard.md`](/Users/jon/projects/sigra/guides/recipes/run-the-admin-dashboard.md) — the recipe that points at this gap (lands as quick-win A3)

## Notes

- Keep the seeder example-app-only. The library should not ship a generic seeder for hosts — they have their own users.
- Avoid PII shapes that look real-real (no actual email domains, no real names from a list). Use clearly-fake patterns that still distribute realistically.
- Pair with SEED-008 (email preview catalog) — both unlock the "show me what I'm getting" DX.
