---
phase: 260618-fch
plan: 01
status: complete
date: 2026-06-18
commits:
  - 16b1b36c: fix — remove type attr from <.button> calls in installer templates (4 files)
  - a7a57b44: fix — sync button-type fixes to example and golden fixture mirrors (7 files)
  - dc2c102c: fix — remaining .button type= in org members and organizations_live templates (10 files)
  - 11a236d9: fix — remove stale known_failure tag from vault_promotion_test
---

# Quick Task 260618-fch — Fix vault_promotion_test.exs known failure

## Goal

Lift the `@moduletag known_failure` quarantine on
`test/sigra/install/vault_promotion_test.exs` by fixing the installer template that
emitted a `CoreComponents.button/1` call with a `type` attribute the generated host
rejects under `--warnings-as-errors`.

## Root cause

phx_new 1.8.7 `CoreComponents.button/1` declares
`attr :rest, :global, include: ~w(href navigate patch method download name value disabled)`
— `type` is **not** in the allowlist. Every `<.button type=...>` in the installer
templates therefore produced a fatal warning under `--warnings-as-errors`. The blast
radius was wider than the passkeys vault path: **7 template files** carried the pattern.

## Fix

- `type="submit"` → dropped (an HTML `<button>` inside a `<.form>` defaults to submit, so
  behavior is unchanged).
- `type="button"` → converted to a raw `<button type="button" ...>` element. Verified
  byte-identical render: the generated `button/1` uses `assign_new(:class, ...)`, so it
  only injects default classes when no `class` is passed — and every converted call site
  passes an explicit `class="btn ..."`.
- Synced identical changes across all three trees: `priv/templates/sigra.install/`,
  `test/example/`, and `test/fixtures/install_golden/`.
- Removed the now-inaccurate `@moduletag known_failure` from the test.

## Deviations from plan

- Plan scoped 4 template files; execution found 3 more with the same pattern
  (`organization_members_live.ex`, `organizations_live/index.ex`, `organizations_live/new.ex`)
  plus example-only SSO buttons — all fixed for completeness.
- The executor ran in a worktree forked from `origin/main` (the phase-192 commits and the
  pre-dispatch plan commit are local/unpushed), so its branch based off `07e15ca9` rather
  than local HEAD. The orchestrator cherry-picked the 3 fix commits cleanly onto local main
  (one overlapping file, `example .../organization_settings_live.ex`, auto-merged with no
  conflict) and removed the worktree.
- The executor missed removing the `known_failure` tag and updating the tracked todo; the
  orchestrator completed both and re-verified.

## Verification

- `mix test test/sigra/install/vault_promotion_test.exs --timeout 600000` → **1 test, 0 failures** (tag removed).
- `grep -rn '<\.button[^>]*type=' priv/templates/sigra.install/ test/example/lib test/fixtures/install_golden/` → **0 matches**.
- Executor reported: example app compiles clean under `--warnings-as-errors`; full install
  suite 583/584 (the 1 remaining failure is the separate `golden_diff_test.exs` config.exs
  drift — tracked as the next quick task).

## Follow-up

- `golden_diff_test.exs` known failure is the next item in this batch (separate quarantine todo).
