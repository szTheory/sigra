---
id: SEED-008
status: open
planted: 2026-07-18
planted_during: "quick task 260718-i1m — demo front-door get-started affordance"
trigger_when: An adopter-onboarding / installer-DX milestone, or an adopter reporting "how do I get into /admin after install."
scope: Medium
---

# SEED-008: Generated-host first-run admin-bootstrap gap

## Problem

After `mix sigra.install`, `/admin` is routable but the generated
`sigra_admin_policy.ex` is a stub returning `false`
(`priv/templates/sigra.install/admin/policy.ex:12-26`, verified present):

```elixir
@impl true
def platform_admin?(scope) do
  # TODO: Return true only when this scope should have global admin access.
  # Example: match on a host-owned role flag or query a trusted policy source.
  _ = scope
  false
end
```

There is no generated seed, mix task, or doc to (a) create the first user and
(b) mark them platform admin. The installer's final printed guidance
(`lib/sigra/install/features/admin.ex:65-86`) stops at "define
platform-admin access explicitly" and never closes the loop:

```
Next steps:

  1. Review `lib/<app>/sigra_admin_policy.ex` and define platform-admin
     and org-admin access explicitly for your host app.
  ...
```

Sigra deliberately will not infer admin from signup order/email domain —
that's the correct security posture — but the result is a fresh adopter
cannot reach their own `/admin` without reverse-engineering the policy
contract themselves. The installer also generates no landing/getting-started
surface: the rich Tasklane landing page built in this quick task
(`test/example/lib/example_web/controllers/page_html/home.html.heex`) is
demo-only, not generated into host apps via
`priv/templates/sigra.install/**`.

## Idea

A safe generated first-run affordance — e.g. an interactive
`mix sigra.gen.admin` (or a documented `mix run` snippet / generated seed
stub) to bootstrap the first operator, plus post-install "create your first
admin" guidance that actually closes the loop; optionally a minimal
generated getting-started section.

## Guardrails (from research)

- Must NEVER generate demo credentials or an auth-bypass into a host app
  (CWE-798 hardcoded credentials, CWE-489 leftover debug code).
- First-admin bootstrap must be explicit and safe — an interactive prompt or
  a clearly-labeled one-time mix task, never an implicit "first signup wins"
  fallback.
- Any convenience affordance must be compile-gated (mirrors the
  `Application.compile_env(:example, :dev_routes)` pattern already used
  throughout the demo) so it can never ship live in a production build.

## Trigger

An adopter-onboarding / installer-DX milestone, or an adopter reporting "how
do I get into /admin after install." Ties to the project North Star's "clear
integration path" and "great DX on the happy path AND the rough edges."

## Key Files (verified present at plant time)

- `lib/mix/tasks/sigra.install.ex`
- `lib/sigra/install/features/admin.ex`
- `lib/sigra/install/features/core.ex` (post-install text)
- `priv/templates/sigra.install/admin/policy.ex`
