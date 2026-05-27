---
type: quick-plan
slug: phase130-docs-oauth-callback
date: 2026-05-27
status: in-progress
---

# Phase 130 docs gate fix — Sigra.OAuth.callback/4 references

## Problem

`guides/flows/oauth.md` references `Sigra.OAuth.callback/4` at lines 15 and 58.
That function does not exist. The real public API is `Sigra.OAuth.handle_callback/4`
(defined at `lib/sigra/oauth.ex:136`). The broken references trip
`mix docs --warnings-as-errors`, which is a Phase 130 release gate.

## Scope

- Edit two lines in `guides/flows/oauth.md` to point at the real callback name.
- Re-run `mix docs --warnings-as-errors` until clean.
- No code changes outside the guide.

## Tasks

1. Replace `Sigra.OAuth.callback/4` → `Sigra.OAuth.handle_callback/4` at:
   - `guides/flows/oauth.md:15`
   - `guides/flows/oauth.md:58`
2. Run `mix docs --warnings-as-errors`; iterate until clean.
3. Commit the doc fix.
4. Write SUMMARY.md for Phase 130 re-execution context.

## Verification

- `mix docs --warnings-as-errors` exits 0.
- No remaining references to `Sigra.OAuth.callback` in `guides/`, `lib/`, or `docs/`.
