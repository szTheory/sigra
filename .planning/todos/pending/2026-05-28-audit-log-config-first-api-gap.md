---
created: 2026-05-28T00:00:00.000Z
title: Audit-log config-first API gap — documented Sigra.Audit.log/3 does not exist
area: library + docs
files:
  - lib/sigra/audit.ex
  - guides/flows/audit-logging.md
  - guides/recipes/companion-libs/accrue.md
---

## Problem

Surfaced during Phase 134 code review (134-REVIEW.md, finding CR-01).

`guides/flows/audit-logging.md:93` documents the adopter form
`Sigra.Audit.log(config, "billing.subscription.upgraded", opts)` — a **config-first
arity-3** call. That function does not exist. The only public writer is
`Sigra.Audit.log/2` (`lib/sigra/audit.ex:55`): `log(action, opts)` where `opts` must
carry raw `:repo` and `:audit_schema` keys. There is NO `log/3` taking a `%Sigra.Config{}`.

Consequences:
1. `guides/flows/audit-logging.md:93` ships a snippet that raises `UndefinedFunctionError`.
2. Phase 134's `accrue.md:81` `log_audit/2` bridge has no clean correct form to point at —
   it currently shows `Sigra.Audit.log(event_map |> Map.put(...))` (arity-1 map), also wrong.
   It was left as-is and flagged here rather than guess-fixed (decision: fix-clean-ones,
   flag-rest).

This is a library/cross-doc gap, not a Phase 134 recipe issue — it predates the phase and
affects the canonical audit guide.

## Solution

Pick one and apply consistently:

- **Option A (preferred — close the gap in the library):** Add a config-first convenience
  `Sigra.Audit.log(%Sigra.Config{} = config, action, opts)` that derives `:repo` and
  `:audit_schema` from the config struct and delegates to `log/2`. Then both
  `audit-logging.md` and the `accrue.md` bridge become correct as written.
- **Option B (doc-only):** Fix `audit-logging.md:93` and the `accrue.md:81` bridge to use the
  real `log/2` form, threading `repo:`/`audit_schema:` from `MyApp.Auth.sigra_config()`.

After fixing, re-run `mix docs --warnings-as-errors` and grep the guides for any remaining
`Sigra.Audit.log(config,` arity-3 usages.
