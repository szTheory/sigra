---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "test/example SettingsLive ~p\"/dev/mailbox\" fails compile --warnings-as-errors under MIX_ENV=test"
area: example-app
files:
  - test/example/lib/example_web/live/settings_live.ex
  - test/example/lib/example_web/router.ex

source: "Phase 239 plan 03 (priv/templates/ sweep, mirror commit), Task 1 tracer — discovered while running `MIX_ENV=test mix compile --warnings-as-errors` inside test/example for the first time as part of an acceptance-criteria check"
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

`test/example/lib/example_web/live/settings_live.ex:133` renders a `~p"/dev/mailbox"`
verified-route link inside the pending-email-change notice:

```heex
<a href={~p"/dev/mailbox"} class="vt-link">dev mailbox</a>
```

`router.ex` only defines the `/dev/mailbox` scope when
`Application.compile_env(:example, :dev_routes)` is true, and that flag is set to
`true` only in `config/dev.exs` — it is unset (falsy) in `config/test.exs`. Phoenix's
`~p` sigil is verified at **compile time** against the router's route table
regardless of the runtime `:if` guard wrapping the `<a>` tag, so compiling the example
app under `MIX_ENV=test` with `--warnings-as-errors` fails:

```
warning: no route path for ExampleWeb.Router matches "/dev/mailbox"
  lib/example_web/live/settings_live.ex:133: ExampleWeb.SettingsLive.render/1

Compilation failed due to warnings while using the --warnings-as-errors option
```

Confirmed pre-existing via `git stash` (reproduces identically on unmodified HEAD,
`7a12e2e2`, with zero relation to any Phase 239 template-sweep edit).

## Why this wasn't caught before

`mix ci`'s `compile --warnings-as-errors` step compiles the **library root** only
(`lib/`) — `test/example/` is a separate nested Mix project with its own `mix.exs`,
and nothing in the standard `mix ci` alias chain compiles it directly with
`--warnings-as-errors`. The only place that combination is invoked is
`test/example/mix.exs`'s own `precommit` alias, which is a local developer
convenience never wired into CI. So this is a real, live compile-time issue that
simply has no automated gate watching for it today.

## Fix options (not decided — pick one when picked up)

1. Guard the anchor itself behind the same `dev_routes?` check used server-side
   (e.g. an assign computed from `Application.get_env(:example, :dev_routes, false)`
   passed into the LiveView), so the `~p` call itself only appears in code paths that
   exist when the route does. `~p` is still resolved at compile time regardless of
   runtime branching, so this alone does not fix the *compile-time* warning — only
   hides it from a reader who doesn't already know this. Combine with (2).
2. Replace the `~p"/dev/mailbox"` call with a plain string literal `"/dev/mailbox"`
   for this dev-only debug link, since verified-route compile-time checking adds
   little value for a route that is deliberately absent in two of three environments.
3. Add a permanently-present but env-gated stub route (e.g. `forward "/mailbox",
   Example.DevMailboxRedirect` in test/prod that 404s) so the route always exists at
   compile time and `~p` verification passes in every env.

## Scope note

Deliberately **not fixed in Phase 239** per the v1.48 milestone's standing constraint
("Found-while-cleaning → a new todo file, never an in-phase fix") and because
`settings_live.ex` is explicitly one of Phase 239's four already-absent-token
counterparts (`239-03-PLAN.md`'s mirror ledger, "0-line rows get no edit at all") —
touching it for an unrelated reason inside that same plan would blur the plan's own
audit trail for that row.
