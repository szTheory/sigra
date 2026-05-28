---
created: 2026-05-28T00:00:00.000Z
title: Phase 135 code-review deferred findings — Threadline demo polish + upstream note
area: test/example + docs + upstream
files:
  - test/example/priv/repo/migrations/20260528152137_threadline_audit_schema.exs
  - test/example/test/example_web/threadline_forwarder_test.exs
  - test/example/AGENTS.md
  - test/example/config/config.exs
  - test/example/lib/example/accounts.ex
---

## Context

Deferred during Phase 135 code review (135-REVIEW.md). CR-02/WR-02 were fixed
in commit d7e508e. The four items below were verified and intentionally NOT
fixed because they are upstream-owned or plan-mandated. Tracked here so they are
not lost.

## Items

### CR-01 — Threadline capture migration forward-references `actor_ref` (upstream)

Migration `20260528152137` defines `threadline_capture_changes()` whose body
inserts into `audit_transactions (... actor_ref)`, but `actor_ref` is only added
by migration `20260528152138`. A fresh `mix ecto.migrate` is safe (all three run
before any trigger fires); only a partial `mix ecto.rollback` to exactly
migration 1 leaves a broken trigger. This is **Threadline's generated DDL**,
committed verbatim per the locked plan decision. Options if it ever matters:
(a) file/track upstream with Threadline, or (b) add an AGENTS.md note that
"rollback to exactly migration 1 is unsupported for this demo." Not exercised by
the demo's `record_action/2` path.

### WR-01 — Test assertions on `actor_ref.id` / `.type` are version-brittle

If a Threadline upgrade renames `ActorRef` fields, the SC#1 assertions raise a
bare `KeyError` instead of a meaningful failure. Assertions are kept strong on
purpose (Success Criterion #1 asserts the actor shape). Low risk; revisit only
if a Threadline bump breaks them.

### WR-03 — AGENTS.md should clarify `only: [:dev, :test]` dep scope vs `:prod`

The `{:threadline, "~> 0.5", only: [:dev, :test]}` scope is correct for this app
(the only prod Threadline reference is `Sigra.Audit.Forwarders.Threadline`, which
is Sigra library code, not the `threadline` package). An adopter copying the
pattern who puts `Threadline.*` calls in a prod path would hit a compile error.
Add a one-line caveat to the AGENTS.md Threadline section.

### IN-01 — Forwarder config duplicated across `config.exs` and `accounts.ex`

Duplication is by design (the demo shows both config surfaces). A brief comment
noting that `sigra_config/0` is the authoritative runtime config and both blocks
must stay in sync would help adopters.
