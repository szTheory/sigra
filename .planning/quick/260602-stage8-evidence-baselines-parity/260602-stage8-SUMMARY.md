---
phase: quick-260602-stage8
type: summary
status: complete
---

# Stage 8 — Evidence, baselines, parity (Admin-UI Pass 2 final gate)

Executed directly by the orchestrator (mechanical validation + reconciliation, no planner/executor).

## Regressions caught by the full behavioral suite (and fixed)
The per-stage gates ran ExUnit + that stage's specs, not the full chromium suite. Stage 8's full
run surfaced two regressions from intentional earlier changes, both fixed in commit `2581fa4a`:
1. **Stage 1 tenant chip** — `expectScopeChrome` used an exact-text match; the org chip now renders
   `Org · {name}` (+ ⌂ glyph). Fix: `exact: false` substring match in the helper.
2. **Stage 7 Cmd-K trigger** — its label `Search…` collided with `button:has-text("Search")` (it
   sits earlier in the DOM), so the users-index search submit clicked the palette instead. Fix:
   relabel the trigger `Jump to…` in BOTH parity-identical shell files — also a UX win (removes a
   duplicate "Search" affordance; the palette is a jump-to/command accelerator, not a list search).

## Pre-existing failure ruled out
3 passkey specs (`passkey-login`, `passkey-options`, `passkeys-hooks`) fail with
`passkey-register:error`. A/B test confirmed they fail **identically on the pre-Stage-7 bundle** →
pre-existing local virtual-authenticator/CDP environment issue, NOT caused by the Stage-7 bundle
injection. The Stage-7 bundle is clean (LiveView connects, Cmd-K + copy work, node --check passes).

## Baselines regenerated (19)
Reseeded a clean persona DB (incl. Morgan + 3 admin sessions), deleted stale PNGs, `--update-snapshots`:
- 15 admin-checkpoint (global-user-index / user-detail / org-scoped-admin / impersonation-banner /
  audit-explorer × chromium/mobile/dark)
- 4 demo-showcase (demo-credentials / admin-user-list / admin-user-detail / audit-explorer)
Re-ran all 4 screenshot projects WITHOUT `--update` → 5/5 stable. Committed in the baselines commit.

## Final gate results (all green)
- Playwright behavioral (chromium project): 12/12 non-passkey pass (admin-user-ops, admin-audit,
  impersonation, golden-path, organizations). 3 passkey = pre-existing env (above).
- Screenshot + **axe** (chromium/mobile/dark): 5/5 pass, axe green on all three variants.
- Library admin tests (root): 55/55 (incl. 11 new org data-layer tests).
- Example admin ExUnit (live + shell + personas): 33/33.
- Shell template ≡ example copy: byte-identical (parity OK).
- `mix compile --warnings-as-errors`: clean (root).

## Deferred (optional, noted)
- Expand demo-showcase spec with dedicated org-overview / per-user-audit shots (org-scoped admin is
  already covered by the admin-checkpoint org-scoped baseline).
- `guides/assets` / `doc/assets` published-PNG sync.
- Generated-host installer wiring for the Cmd-K hook (template shipped; example wires it).
- Flash→sg-toast restyle + animated "More filters" collapse (Stage-7 optional Scope C).

## Env note
Recurring `validate_compile_env` mismatch on `ExampleWeb.Endpoint` after interleaved `mix compile`/
`mix test` runs: fixed for the session by recompiling **clean** (no `PHX_SERVER`/`PORT` at compile;
`runtime.exs` adds server/port at boot), then serving with those env vars.
