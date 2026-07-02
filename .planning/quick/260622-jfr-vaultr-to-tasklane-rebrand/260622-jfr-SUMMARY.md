---
quick_id: 260622-jfr
status: complete
date: 2026-06-22
---

# Vaultr → Tasklane rebrand (framing-only) — SUMMARY

## Problem
The demo app's identity ("Vaultr — a team secrets/credential vault") was
**auth-adjacent**, blurring the line between the app and Sigra, the auth library it
consumes. Clicking around as a persona, it wasn't clear what the app's *own* domain
was vs. what Sigra provides.

## Decision (user-confirmed)
- Rebrand to **"Tasklane"**, a fictional **project/work tracker** (Linear/Asana/Jira
  space) — a relatable B2B domain plainly distinct from auth.
- **Framing only**: keep the demo a pure auth showcase. No invented product CRUD;
  `/app` + copy honestly read as "the account & security area of Tasklane."
- Keep `vt-*` CSS prefix + teal palette, `Example`/`ExampleWeb` modules, OTP app
  `:example`, persona local-parts + roles + org topology.

## What shipped (2 commits)
- **`ceba947a` — source rebrand:** product name → "Tasklane"; tagline "Team secrets
  vault" → "Work tracking for teams"; hero subtitle reframed to a project tracker;
  login/`/app`/credentials/reactivation/sudo/mfa-challenge copy + comments. Persona
  email domain `demo.vaultr.test` → `demo.tasklane.test` (single `@demo_domain`
  constant; `SigraAdminPolicy` gates via `Personas.email/1`, stays correct). Branding
  preset id/label/desc/subject + light+dark profiles → Tasklane; private `@vaultr_*`
  module attrs/functions → `@tasklane_*` (one file; `--vt-*` CSS output unchanged).
  Logo `vaultr-mark.svg` (shield+lock) → `tasklane-mark.svg` (task-lanes glyph, same
  teal palette); `data-testid="vaultr-login"` → `tasklane-login`; page `<title>` →
  Tasklane. Brand fallbacks in `config.exs` + `accounts.ex`. README rewritten.
- **`74f464ec` — tests + Playwright:** mechanical `Vaultr→Tasklane` / `vaultr→tasklane`
  swap across the 8 ExUnit + 6 Playwright files that asserted on the old
  brand/domain/id/logo/testid.

## Verification
- **ExUnit (full example suite): 216 tests, 0 failures.** The `page_controller_test`
  + `session_controller_test` + `credentials_live_test` render the actual server HTML
  and assert the new Tasklane copy / `tasklane-mark.svg` / `demo.tasklane.test` /
  brand-id — this is the live-render coverage.
- **Grep guard:** zero residual `vaultr`/`secrets vault`/`team secrets` in
  `test/example` source, tests, or Playwright (Cloak.Vault library term left as-is).
- **Scope:** all 37 changed files are under `test/example/`; **nothing** in
  `priv/templates/**`, Sigra core `lib/`, or `test/sigra/install` → no installer or
  golden-fixture impact.
- **Live `:4011` smoke:** dev server not running this session; superseded by the
  server-side ExUnit render tests above (booting adds the compile-env PORT risk for no
  extra coverage).

## Deferred
- **WS5 (multi-workspace on a non-admin persona)** deliberately skipped — adding Alice
  to a second org would break `seeds_test`'s exact-topology assertions for no real
  gain; the user's multi-org question was informational. Org topology unchanged (admin
  still demonstrates multi-org: Acme owner + Beta member).
- A future re-seed is needed for the running demo DB to carry `demo.tasklane.test`
  users (seed data is code; existing dev DB rows are still the old domain until
  `mix run priv/repo/seeds.exs` is re-run). Not a code-correctness issue.
