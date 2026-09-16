---
created: 2026-09-15T00:00:00.000Z
status: pending
title: "The GET-form-in-a-connected-LiveView race Phase 236 fixed on /admin/audit is still live on /admin/users and the per-user audit view — and /admin/audit itself has two unconverted anchor pairs left over"
area: admin-ui
files:
  - lib/sigra/admin/live/audit_user_live.ex
  - lib/sigra/admin/live/users_index_live.ex
  - lib/sigra/admin/components.ex
severity: medium
source: "Phase 236 (Flake Root Cause — Reproduce, Name, Fix), D-30 scope boundary, filed by plan 236-04"
---

## What

Phase 236 diagnosed and fixed a genuine product race in
`lib/sigra/admin/live/audit_index_live.ex`: a plain `<form method="get">` submitted *inside a
connected LiveView* races LiveView JS's global `submit` listener, which calls the one-way-latch
`unload()` (`deps/phoenix_live_view/assets/js/phoenix_live_view/live_socket.js:247-260`, via
`destroyAllViews()`) whenever a form has **no** `phx-submit` binding
(`live_socket.js:1181-1187`). Under host CPU contention, that teardown races the browser's own
pending native GET submission and wins, silently dropping the navigation — the exact symptom that
produced the `admin-generated.spec.ts:459` flake (41/50 failures under contention, 0/50 without).
The fix: keep `method="get"`/`action=` as a progressive-enhancement fallback, but add
`phx-submit="apply_filters"` plus a `handle_event/3` that calls `push_patch/2`, so LiveView, not
the browser, owns the navigation while connected.

**Two other admin surfaces carry the identical shape and were NOT fixed:**

- `lib/sigra/admin/live/audit_user_live.ex:98` — `<form method="get"
  action={index_path(@admin_scope, @detail.user.id)}>`, no `phx-submit`, inside a connected
  LiveView (`mount/3` / `handle_params/3` render the same audit-explorer filter panel scoped to
  one user).
- `lib/sigra/admin/live/users_index_live.ex:126` — `<form method="get"
  action={index_path(@admin_scope)}>`, no `phx-submit`, inside a connected LiveView.

Both are exposed to the same `live_socket.js:1181-1187` (`bindForms`'s external-submit branch)
racing `live_socket.js:247-260` (`unload()`/`destroyAllViews()`) exactly as `audit_index_live.ex`
was before this phase's fix.

## Why these stayed out of Phase 236

- SC-2 named `audit_index_live.ex` alone, and the failing test's assertion is on `/admin/audit`
  alone — the phase's mandate was to fix the reproduced failure, not converge every admin filter
  panel.
- Widening to these two surfaces puts `user-audit-*.png` ×3 and the users-index Playwright/design
  baselines at recapture risk on top of the `audit-explorer-*.png` ×3 already re-verified for the
  `audit_index_live.ex` fix, against the v1.48 milestone's standing constraint that no PNG
  recapture lane opens without deliberate scoping.
- `users_index_live.ex` carries extra entanglement beyond the plain form: an existing
  `toggle_filters` `phx-click` handler (`users_index_live.ex:66`) and a `<.quick_filter>` component
  (`:153`, defined at `:350`) that already owns non-URL ephemeral UI state (the filter-panel
  disclosure toggle). Any conversion here has to reconcile the existing `phx-click` state
  management with a new `phx-submit`/`push_patch` URL-ownership path without the two colliding —
  more design work than a mechanical `<.link patch>` swap.
- Both `applied_chip` (`lib/sigra/admin/components.ex:372`) and `audit_pagination_nav` (`:827`) are
  **shared components** rendered by all three admin index/detail views
  (`audit_index_live.ex`, `audit_user_live.ex`, `users_index_live.ex`). Converting either shared
  component's internal anchor shape is a decision that touches every caller simultaneously, so any
  future convergence effort must plan the PNG consequence across all three surfaces up front,
  not discover it mid-conversion on the second or third surface.

## Residue Phase 236 left on `/admin/audit` itself

Stated plainly and separately from the deferral above: **after Phase 236, `/admin/audit` still has
three unconverted URL-transition anchors of its own**, despite being the surface the phase fixed.
They are:

1. `applied_chip`'s chip-remove anchor (`lib/sigra/admin/components.ex:378-380`), fed from
   `audit_index_live.ex:159-162` (`remove_chip_path/3`) — a plain `<a href>`, not `<.link patch>`.
2. `audit_pagination_nav`'s **previous**-page anchor (`components.ex:841`), fed from
   `audit_index_live.ex:211` (`page_path/3`) — a plain `<a href>`.
3. `audit_pagination_nav`'s **next**-page anchor (`components.ex:859`), fed from
   `audit_index_live.ex:212` (`page_path/3`) — a plain `<a href>`.

Each of these three is a plain `<a href>` and each still reaches `live_socket.js`'s document-nav
teardown path via `unload()`, so removing a filter chip or paging the audit table remains a full
document navigation with the same dead-render/rejoin-window shape Phase 236 removed from the
presets and the filter form. Phase 236 left them deliberately — the shared-component / PNG-blast-
radius reason above applies to these three exactly as it does to `audit_user_live.ex` and
`users_index_live.ex`, since `applied_chip` and `audit_pagination_nav` are the same shared
components those two views also render — and Phase 236's SC-2 claim is scoped to the failing
test's actual assertion path (`actorFilter.press("Enter")` → the filter form submit), which never
exercises chip-remove or pagination. This sentence is written into this todo, not left to the
Phase 236 plan files, because plan files get archived at milestone close while this todo survives.

## Fix direction (recorded, not implemented here)

Mirror the working template Phase 236 already shipped in `audit_index_live.ex`:

1. Keep every affected `<form method="get">` as-is for the no-JS/dead-render fallback; add
   `phx-submit="<event-name>"`.
2. Add a `handle_event/3` clause that whitelists client-controlled params (mirror
   `@filter_param_keys` + `Map.take/2` from `audit_index_live.ex`) and calls `push_patch/2` with a
   local path built through the view's own `index_path/1`-equivalent helper.
3. Convert `applied_chip`'s remove anchor and `audit_pagination_nav`'s prev/next anchors from plain
   `<a href>` to `<.link patch>` — this single shared-component change fixes the residue on all
   three admin views (`audit_index_live.ex`, `audit_user_live.ex`, `users_index_live.ex`)
   simultaneously, since all three render these two shared components.
4. For `users_index_live.ex` specifically: reconcile the existing `toggle_filters` `phx-click`
   ephemeral-UI-state handler with the new URL-owning `handle_event`, so the two do not race or
   double-patch.
5. Any conversion of `applied_chip` or `audit_pagination_nav` markup (even attribute-only, per
   Phase 236's D-11 "same tag, two added `data-phx-link*` attributes" precedent) requires a full
   `snapshot-canary-guard.sh` pass across ALL boards/pages that render these shared components —
   plan the recapture scope (`audit-explorer-*.png` ×3, `user-audit-*.png` ×3, users-index
   baselines, and any admin-design gallery boards using `applied_chip`/`audit_pagination_nav`)
   before starting, not after.

## Scope

Lib-owned admin surfaces (`lib/sigra/admin/**`) — any fix ships to adopters. Add ExUnit source
contracts mirroring `test/sigra/planning/phase_236_audit_url_ownership_test.exs` for whichever
surface(s) are converted. Not example-only.
