---
id: SEED-008
status: deferred
planted: 2026-05-08
planted_during: post v1.24 demo-DX gap surfacing
trigger_when: EMAIL-RAILS milestone scope (the "preview rails" deliverable in MILESTONE-ARC)
scope: Medium
---

# SEED-008: Browser-accessible email preview catalog

## Why This Matters

Sigra sends 18 distinct emails. Today, the only ways to see them are:

1. **Trigger the flow in the example app** and visit `/dev/mailbox` (Plug.Swoosh.MailboxPreview) — works, but requires triggering each flow manually.
2. **Run `mix sigra.email.snapshot`** — regenerates frozen-fixture HTML in `test/example/priv/email_snapshots/` for Playwright visual-regression. Not designed for human browsing.

Neither lets an adopter answer "what does the lifecycle email catalog look like across light/dark mode and locales?" without a tedious per-flow walk.

The need is a **dev-only LiveView at `/dev/sigra/emails`** that lists all 18 email types with sample data, renders the HTML, and toggles dark mode / locale / variant. EMAIL-RAILS' MILESTONE-ARC entry already names "preview and snapshot rails" as in-scope; this seed is the concrete shape of that deliverable.

## When to Surface

Trigger this seed during EMAIL-RAILS planning. Specifically, EMAIL-RAILS' "preview rails" scope item resolves into one of two paths:

- **Path A (preferred):** Mailglass adapter (SEED-005) lands — Mailglass already ships a preview LiveView, so this seed is mostly absorbed into B1's wire-up work.
- **Path B (fallback):** Mailglass not adopted — Sigra builds a lighter native preview catalog itself (~150 LOC LiveView).

This seed exists so the EMAIL-RAILS planner doesn't forget the preview-catalog shape if Mailglass evaluation falls through.

## Scope Estimate

Medium. Sub-scopes:

- Dev-only mount-point at `/dev/sigra/emails` (gated by `Mix.env() == :dev`)
- LiveView lists the 18 email types with sample data fixtures
- Per-email view: rendered HTML + raw text fallback + signed-recipient context
- Dark-mode toggle, locale switcher (post-i18n work), responsive iframe preview
- Pointer from `guides/recipes/preview-auth-emails.md` (lands as quick-win A4) once shipped

If Path A: most of this is "wire Mailglass's preview to the 18 Sigra emails" — much smaller.

## Breadcrumbs

- [`lib/mix/tasks/sigra.email.snapshot.ex`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.email.snapshot.ex) — existing CI snapshot path (different goal)
- [`test/example/lib/example/accounts/emails.ex`](/Users/jon/projects/sigra/test/example/lib/example/accounts/emails.ex) — the 18 email types (the executable contract)
- [`test/example/priv/email_snapshots/`](/Users/jon/projects/sigra/test/example/priv/email_snapshots/) — frozen fixtures used today
- [`guides/recipes/preview-auth-emails.md`](/Users/jon/projects/sigra/guides/recipes/preview-auth-emails.md) — recipe pointing at this gap (lands as quick-win A4)
- See SEED-005 (Mailglass) for the preferred Path A

## Notes

- Keep dev-only. Production builds must not expose a preview route — leak risk.
- Pair with SEED-007 (admin demo seeder) — both are "see what you're building" deliverables that benefit from joint planning.
- If Mailglass adoption (SEED-005) is approved, this seed mostly merges into B1's scope.
