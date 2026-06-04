---
phase: 157-overview-landings-highest-effort
plan: "01"
subsystem: admin-ui
tags:
  - liveview
  - loading-state
  - connected-gate
  - admin-overview
  - accessibility
dependency_graph:
  requires: []
  provides:
    - Global Overview redesigned with connected?-gate deferred load
    - Front-door archetype: alarm before task grid, posture strip demoted
    - Skeleton loading state in posture strip (6 shapes matching stat_link footprint)
  affects:
    - lib/sigra/admin/live/index_live.ex
tech_stack:
  added: []
  patterns:
    - connected?(socket) gate in mount/3 for deferred DB query
    - aria-busy on containing section during loading
    - :if conditional on <.notice> to avoid inert live-region during skeleton
    - <.skeleton> shapes replacing stat_links 1:1 in posture strip cluster
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/index_live.ex
decisions:
  - connected?(socket) gate in mount/3 with runtime_config!() called before the gate — raises fast on misconfiguration regardless of mount type
  - alarm <.notice> uses :if={not @loading} so the live-region is absent during skeleton (avoids inert region announcement — D-02/Landmine 3)
  - role="status" passed via :rest on the notice (post-load dynamic count makes this valid; WAI-ARIA APG)
  - aria-busy="true" on posture strip section; attribute absent when loading=false (per D-02 contract — not set to "false", just absent)
  - 6 skeleton shapes in sg-cluster sg-cluster--3 matching the 6 stat_link footprints to prevent layout jump (LAND-04/Landmine 8)
metrics:
  duration: "3m 12s"
  completed: "2026-06-04T15:38:51Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
---

# Phase 157 Plan 01: Global Overview Redesign — Front-Door Archetype Summary

Global Overview (`index_live.ex`) redesigned with connected?-gate deferred load, front-door archetype alarm above task grid, and skeleton loading state replacing stat_links.

## Tasks Completed

| Task | Commit | Description |
|------|--------|-------------|
| Task 1: Split mount/3 with connected? gate | 29a72c42 | Two-branch mount/3: disconnected assigns loading=true+empty counts, connected calls Query.summary_counts/2 |
| Task 2: Redesign render/1 — front-door archetype, alarm, skeleton, delete old anchor | 0a7cdcee | Alarm notice above task grid, 6 skeleton shapes in posture strip, sg-posture-strip__risk anchor deleted |

## What Was Built

`lib/sigra/admin/live/index_live.ex` is fully redesigned:

**mount/3 split (Task 1):**
- `runtime_config!()` called before the `if connected?(socket)` gate — raises on misconfiguration on both mounts
- Disconnected path: assigns `loading: true`, `summary_counts: %{}` — no DB query
- Connected path: calls `Query.summary_counts(config, admin_scope)`, assigns `loading: false` with data
- Both branches return `{:ok, socket}`

**render/1 redesign (Task 2):**
- Archetype order: header → alarm `<.notice>` → task_card grid → posture strip → capability (LAND-02/D-04)
- Alarm `<.notice tone={...} role="status">` rendered only when `not @loading` (LAND-01/D-02/D-03/Landmine 3)
  - `tone={:risk}` when `@needs_review > 0`, `tone={:ok}` when 0
  - Inline slot content only: text + `<a>` anchor — no block `<p>` children (D-07/Landmine 1)
- `aria-busy="true"` on posture strip `<section>` during loading; attribute absent when `loading=false` (D-02)
- Skeleton state: 6 `<.skeleton class="sg-metric-link">` shapes replace the 6 `<.stat_link>` elements (LAND-04/Landmine 8)
- Old `sg-posture-strip__risk` anchor block (`<a class="sg-cluster sg-cluster--start sg-posture-strip__risk">`) fully deleted (LAND-04/Landmine 4)

## Verification

- `mix test test/example_web/admin_shell_test.exs` — 6 tests, 0 failures
- `grep -c "sg-posture-strip__risk" lib/sigra/admin/live/index_live.ex` — returns 0 (anchor deleted)
- `grep "connected?(socket)" lib/sigra/admin/live/index_live.ex` — match confirmed in mount/3

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — the skeleton loading state is intentional and correct behavior (not a stub). Real data loads on connected mount via `Query.summary_counts/2`.

## Threat Surface Scan

No new security-relevant surface introduced. The `<.notice>` alarm deep-links to `/admin/users?locked=true` — a read-only navigation within the existing authenticated admin scope (enforced by unchanged `on_mount` hooks). No new endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- [x] `lib/sigra/admin/live/index_live.ex` exists and is modified
- [x] Task 1 commit 29a72c42 exists in git log
- [x] Task 2 commit 0a7cdcee exists in git log
- [x] `sg-posture-strip__risk` absent from file
- [x] `connected?(socket)` present in mount/3
- [x] All 6 admin_shell_test assertions pass
