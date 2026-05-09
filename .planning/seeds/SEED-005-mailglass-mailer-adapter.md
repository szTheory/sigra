---
id: SEED-005
status: deferred
planted: 2026-05-08
planted_during: post v1.24 ecosystem-integration scan
trigger_when: EMAIL-RAILS milestone planning starts; evaluate adopting Mailglass as the primary unlock
scope: Medium
---

# SEED-005: Mailglass adapter for Sigra mailer

## Why This Matters

Sigra ships 18 distinct auth-related emails (confirmation, reset, magic link, suspicious login, MFA enable/disable/lockout, backup-code-used, email-change confirmation/notification/changed, deletion lifecycle, password changed, organization invitation, plus passkey registration). The current path is a `Sigra.Mailer` behaviour that hosts implement on top of Swoosh. That works, but it leaves the rough edges EMAIL-RAILS is meant to address — preview, override seams, webhook-tracked delivery, unsubscribe semantics — entirely on the host.

Mailglass (`~/projects/mailglass`, v1.0.0 on hex) sits *atop* Swoosh and ships exactly those rough-edge fixes: HEEx components, LiveView preview/admin, an immutable webhook ledger, RFC 8058 unsubscribe, stream-aware routing. It already declares Sigra as an optional dependency in its mix.exs. Adopting a thin adapter would let EMAIL-RAILS' likely scope (override seam, preview rails, async delivery, bounce/complaint hooks) land mostly *for free* — Mailglass already implements most of it.

This seed exists so EMAIL-RAILS planning evaluates Mailglass before re-implementing the same surfaces inside Sigra.

## When to Surface

Trigger this seed when:

- EMAIL-RAILS milestone planning starts (default-next per MILESTONE-ARC.md)
- An adopter asks "how do I preview these emails before shipping?"
- An EMAIL-RAILS phase considers writing its own preview LiveView from scratch

It should stay deferred during unrelated core feature work and during PK-LIFECYCLE / DATA-LIFECYCLE.

## Scope Estimate

Medium adoption-evaluation slice:

- Verify Mailglass's optional `:sigra` dep constraint is widened (currently `~> 0.2`, Sigra is at v1.24 — see TODO `2026-05-08-cross-repo-mailglass-sigra-constraint.md`)
- Add `Sigra.Mailers.Adapters.Mailglass` shim (~80 LOC) that routes `Sigra.Mailer` callbacks through `Mailglass.Mailable`
- Add `--with-mailglass` flag to `mix sigra.install` that wires the adapter, generates a `MyApp.SigraMailer using Mailglass.Mailable`, and adds the preview/admin routes
- Document the override seam path: edit a generated `MyApp.SigraMailer.confirmation/1` to customize copy or layout
- Wire the example app under `--with-mailglass` to prove the install contract

If Mailglass is *not* adopted, this seed informs the alternative path: build a Sigra-native lighter version of preview catalog (see SEED-008).

## Breadcrumbs

- [`~/projects/mailglass/mix.exs`](/Users/jon/projects/mailglass/mix.exs) — line 154 declares `{:sigra, "~> 0.2", optional: true}` (stale constraint)
- [`lib/sigra/mailer.ex`](/Users/jon/projects/sigra/lib/sigra/mailer.ex) — current `Sigra.Mailer` behaviour
- [`priv/templates/sigra.install/core/emails.ex.eex`](/Users/jon/projects/sigra/priv/templates/sigra.install/core/emails.ex.eex) — current host override surface
- [`test/example/lib/example/accounts/emails.ex`](/Users/jon/projects/sigra/test/example/lib/example/accounts/emails.ex) — the 18 generated email functions (executable contract)
- [`.planning/MILESTONE-ARC.md`](/Users/jon/projects/sigra/.planning/MILESTONE-ARC.md) — EMAIL-RAILS scope (active milestone)

## Notes

- Adopting Mailglass should remain *optional* for hosts; the existing direct-Swoosh path must keep working unmodified.
- Mailglass adoption strengthens the szTheory OSS suite story (Sigra + Accrue + Mailglass + Threadline). See SEED-006 (Threadline adapter) and the SUITE-INTEGRATION candidate in MILESTONE-ARC for the broader arc.
- The Mailglass-side version-constraint widening is a pre-req — without it, `mix.exs` resolution fails when both libs are present.
