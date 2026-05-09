---
id: SEED-006
status: deferred
planted: 2026-05-08
planted_during: post v1.24 ecosystem-integration scan
trigger_when: A Sigra adopter asks about audit retention/export tooling, OR DATA-LIFECYCLE milestone planning surfaces audit-export needs
scope: Small
---

# SEED-006: Threadline audit adapter

## Why This Matters

Threadline (`~/projects/threadline`, v0.5.0 on hex) is a PostgreSQL-trigger-backed audit library with timeline querying, retention policies, incident-bundle export, and a LiveView explorer. It already ships `Threadline.Integrations.Sigra` — a *one-way* capture path that ingests Sigra's audit events into Threadline.

Today, Sigra's `Sigra.Audit` writes directly to a host-owned audit table and co-fates each write with the domain mutation in `Ecto.Multi`. That works well as a primary surface, but adopters who want richer query/retention/export tooling have to reach for Threadline separately.

The complementary direction — `Sigra.Audit.Adapters.Threadline` letting Sigra *delegate* its audit writes to Threadline's backend when the host opts in — would unify the two surfaces without forcing Threadline as a hard dep. Adopters already running both libs would get one audit log instead of two.

## When to Surface

Trigger this seed when:

- DATA-LIFECYCLE milestone planning starts (audit-export is one of its named scope items)
- An adopter explicitly asks about audit retention, timeline querying, or incident-bundle export
- Threadline ships a major release that materially changes the integration surface

It should stay deferred during EMAIL-RAILS and PK-LIFECYCLE work.

## Scope Estimate

Small first-class adapter:

- Add optional `Sigra.Audit.Adapters.Threadline` (~100 LOC) that maps `Sigra.Audit.record/3` → Threadline's trigger-backed insert path
- Preserve `Ecto.Multi` co-fate semantics — adapter must inherit, not replace, the atomicity guarantees
- Add `audit: [adapter: Sigra.Audit.Adapters.Threadline]` config option in `Sigra.Config`
- Verify-test confirming domain mutation + Threadline insert co-fate (rollback test)
- Cross-link from `guides/recipes/integration-threadline.md` (the doc-only TODO C2 ships first)

## Breadcrumbs

- [`~/projects/threadline/lib/threadline/integrations/sigra.ex`](/Users/jon/projects/threadline/lib/threadline/integrations/sigra.ex) — existing one-way capture path (the surface to mirror)
- [`lib/sigra/audit.ex`](/Users/jon/projects/sigra/lib/sigra/audit.ex) — current audit writer
- [`lib/sigra/audit/recorder.ex`](/Users/jon/projects/sigra/lib/sigra/audit/recorder.ex) — the Multi-aware insert path
- [`.planning/MILESTONE-ARC.md`](/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md) — DATA-LIFECYCLE candidate
- [`guides/flows/audit-logging.md`](/Users/jon/projects/sigra/guides/flows/audit-logging.md) — current audit guide (entry point for cross-link)

## Notes

- Threadline integration must remain optional. The default direct-write path stays the canonical Sigra audit surface.
- This is a *complement*, not a replacement. Hosts using only Sigra continue with the schema-local audit table.
- The cross-repo coordination is light (Threadline's Sigra integration is already shipped); the work is mostly Sigra-side.
