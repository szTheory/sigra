---
phase: 141-seed-data-layer
plan: "02"
subsystem: example-app-seed-data
tags:
  - seed-data
  - argon2
  - persona
  - pure-data
  - demo
dependency_graph:
  requires:
    - "141-01 (user_identity schema + migration, if run in parallel)"
  provides:
    - "dev.exs Argon2 dev cost override (D-04) — consumed by seeds.exs at mix setup time"
    - "Example.Demo.Personas module (D-01, D-05) — consumed by plan 03 Seeds orchestrator and plan 04 DemoCredentialsLive"
  affects:
    - "test/example/config/dev.exs — Argon2 cost context for all dev-mode password hashing"
    - "test/example/lib/example/demo/ — new namespace (first Example.Demo.* module)"
tech_stack:
  added: []
  patterns:
    - "Pure-data module pattern: no DB calls, no cross-module deps; deterministic at compile time"
    - "Module attribute SHA-256 derivation for deterministic demo TOTP secret"
    - "Dev-only config isolation: cost override in dev.exs only, explicitly not prod/test"
key_files:
  created:
    - test/example/lib/example/demo/personas.ex
  modified:
    - test/example/config/dev.exs
decisions:
  - "Passwords use DemoAdmin1! format (12+ chars, mixed case, digit, symbol) — public-by-design; each persona has a distinct password"
  - "TOTP derivation is a module attribute evaluated at compile time — deterministic, zero runtime cost, 20-byte binary stored directly as encrypted_secret"
  - "No analog in codebase for Example.Demo.*; created new namespace under lib/example/demo/"
  - "Argon2 override comment explicitly states 'Do NOT copy this override to production' to prevent misuse"
metrics:
  duration_seconds: 205
  completed_date: "2026-05-30"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
---

# Phase 141 Plan 02: Persona Data + Dev Argon2 Cost Summary

**One-liner:** Argon2 dev cost override (`t_cost: 2, m_cost: 12`) in dev.exs and a pure-data `Example.Demo.Personas` module with six `@demo.sigra.dev` personas, deterministic TOTP secret, and policy-passing passwords.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add Argon2 dev cost override to dev.exs (D-04) | fa2e792 | test/example/config/dev.exs |
| 2 | Create Example.Demo.Personas pure-data module (D-01, D-05) | cff3116 | test/example/lib/example/demo/personas.ex |

## What Was Built

### Task 1: Argon2 dev cost override (D-04, SEED-05, SEED-06)

Appended to `test/example/config/dev.exs`:
- `config :argon2_elixir, t_cost: 2, m_cost: 12`
- Comment explaining: real Argon2id at reduced DEV cost for fast seeds (~20-50ms/hash)
- Explicit "Do NOT copy this override to production" warning
- test.exs still has `t_cost: 1, m_cost: 8` (unchanged)
- prod.exs has no argon2 line (unchanged)

### Task 2: Example.Demo.Personas (D-01, D-05, SEED-02)

Created `test/example/lib/example/demo/personas.ex` as the first `Example.Demo.*` module:
- Pure-data: no DB calls, no cross-module deps
- Module attribute `@demo_totp_secret` derived exactly as `D-05` mandates:
  - Exact label: `# Demo-only — intentionally deterministic. Never use in production.`
  - Exact derivation: `:crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)`
- Six personas on `@demo.sigra.dev`: admin, alice, bob, carol, dave, frank
- Each persona carries: `email`, `display_name` (per UI-SPEC), `password`, and auth-state metadata flags (`confirmed`, `totp`, `passkey`, `locked`, `scheduled_deletion`, `identity_github`, `org_owner`, `org_member`)
- `demo_totp_secret/0` accessor for Seeds module
- All six passwords satisfy `Sigra.PasswordPolicy` (verified via changeset API)
- Zero `@example.test` occurrences

## Verification Results

All success criteria met:

| Check | Result |
|-------|--------|
| `dev.exs` contains `config :argon2_elixir, t_cost: 2, m_cost: 12` | PASS |
| `test.exs` Argon2 posture unchanged (`t_cost: 1, m_cost: 8`) | PASS |
| `prod.exs` has no argon2 config | PASS |
| `Example.Demo.Personas` compiles with `--warnings-as-errors` | PASS |
| Exact TOTP derivation present | PASS |
| Exact "Never use in production" label present | PASS |
| Six `@demo.sigra.dev` emails (8 occurrences incl. moduledoc) | PASS |
| Zero `@example.test` occurrences | PASS |
| All passwords pass `Sigra.PasswordPolicy` (via changeset API) | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's verify command used wrong PasswordPolicy API**

- **Found during:** Task 2 verification
- **Issue:** The plan's acceptance criteria stated: `Sigra.PasswordPolicy.validate(p.password)` — but `Sigra.PasswordPolicy.validate/1` takes an `Ecto.Changeset.t()`, not a raw string. Calling it with a plain string would raise a function clause error.
- **Fix:** Verified passwords using the correct API: built a minimal changeset with `Ecto.Changeset.cast/3` then called `Sigra.PasswordPolicy.validate/1`. All six passwords verified as `changeset.valid? == true`. The personas data is correct; only the verify command in the plan was incorrect.
- **Files modified:** None (passwords were already policy-compliant; only the verification approach was adapted)
- **Impact:** None on plan artifacts — passwords satisfy the policy, which is the intent.

## Known Stubs

None. Both artifacts are complete and data-complete for their purpose.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This plan creates only:
1. A config value in a dev-only file
2. A pure-data Elixir module with no DB access

Threat mitigations verified:
- **T-141-04 (Argon2 dev cost leaking to prod):** Override is ONLY in `dev.exs`; prod.exs has no argon2 line; comment explicitly forbids copying to prod. MITIGATED.
- **T-141-05 (weak seed passwords):** All passwords satisfy `Sigra.PasswordPolicy.validate/1`, use DemoAdmin1! format, documented as public-by-design. MITIGATED.
- **T-141-06 (deterministic TOTP secret):** Carries exact "Never use in production" label (D-05). ACCEPTED.
- **T-141-07 (email domain contamination):** All persona emails use `@demo.sigra.dev`; zero `@example.test` occurrences verified. MITIGATED.

## Self-Check: PASSED

- [x] `test/example/config/dev.exs` exists and contains `config :argon2_elixir, t_cost: 2, m_cost: 12`
- [x] `test/example/lib/example/demo/personas.ex` exists with `defmodule Example.Demo.Personas`
- [x] Commit `fa2e792` exists (Task 1)
- [x] Commit `cff3116` exists (Task 2)
- [x] `mix compile --warnings-as-errors` passes in `test/example/`
