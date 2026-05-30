---
phase: 142-dev-credentials-page-app-framing
plan: "03"
subsystem: example-app
tags:
  - exunit
  - liveview
  - demo
  - credentials-page
  - seeds
  - testid

dependency_graph:
  requires:
    - "142-01: Example.Demo.Personas.feature_map/0 (D-02 single source)"
    - "142-01: ExampleWeb.Demo.CredentialsLive with render/1 + data-testid attributes"
    - "142-02: data-testid='app-name' + Vaultr string in Layouts.app"
  provides:
    - "Seeds.print_credentials/0 — D-11 stdout block using Personas.feature_map/0"
    - "credentials_live_test.exs — 404 env-guard + rendered HTML testid contract"
    - "Phase 142 VALIDATION.md marked nyquist_compliant: true, wave_0_complete: true"
  affects:
    - "Phase 143 Playwright: testid anchors established by this plan are the Phase 143 CSS selector targets"

tech_stack:
  added: []
  patterns:
    - "Phoenix.HTML.Safe.to_iodata/1 |> IO.iodata_to_binary/1 for LiveView render/1 → binary conversion"
    - "Direct CredentialsLive.render/1 call with minimal assigns map for router-free content assertion"
    - "build_conn() |> get/2 for compile-env-gated 404 assertion pattern"

key_files:
  created:
    - test/example/test/example_web/live/demo/credentials_live_test.exs
  modified:
    - test/example/lib/example/demo/seeds.ex
    - .planning/phases/142-dev-credentials-page-app-framing/142-VALIDATION.md

key-decisions:
  - "Used Phoenix.HTML.Safe.to_iodata/1 |> IO.iodata_to_binary/1 (not Phoenix.HTML.safe_to_string/1 directly) — safe_to_string expects a {:safe, iodata} tuple, not the Rendered struct; the Safe protocol impl on Rendered gives us iodata directly"
  - "Seeds.print_credentials/0 calls Personas.feature_map()[local] (Personas alias already at seeds.ex:33) — no ExampleWeb.Demo.CredentialsLive reference needed since feature_map/0 lives in Personas per D-02"

requirements-completed:
  - DEMO-01
  - DEMO-02

duration: "197s"
completed: "2026-05-30T13:17:00Z"
---

# Phase 142 Plan 03: Seeds stdout block + credentials LiveView test contract Summary

Seeds.print_credentials/0 wired to Personas.feature_map/0 (D-11, D-02), and credentials_live_test.exs covering the 404 env-guard and rendered HTML testid contract for DEMO-01/DEMO-02.

## Performance

- **Duration:** 197s (~3 minutes)
- **Started:** 2026-05-30T13:14:45Z
- **Completed:** 2026-05-30T13:17:00Z
- **Tasks:** 2
- **Files modified:** 2 (seeds.ex, credentials_live_test.exs created)

## Accomplishments

- Added `print_credentials/0` to `Example.Demo.Seeds` — prints `=== Demo Credentials ===` heading and one line per persona in format `[local]  email  password  (feature)`, calling `Personas.feature_map()[local]` as the D-02 single source (no local copy)
- Created `credentials_live_test.exs` with two describe blocks: a 404 env-guard test (D-12, T-142-01) and a rendered HTML contract test asserting all required testids + Vaultr branding (DEMO-01, DEMO-02)
- Conversion approach: `CredentialsLive.render/1` returns `%Phoenix.LiveView.Rendered{}`; converted via `Phoenix.HTML.Safe.to_iodata/1 |> IO.iodata_to_binary/1` — 2 tests, 0 failures on scoped run; 185 tests, 0 failures on full suite

## Task Commits

1. **Task 1: Seeds.print_credentials/0 — D-11 stdout block** - `926e095` (feat)
2. **Task 2: credentials_live_test.exs — 404 env-guard + rendered HTML testid contract** - `d52934c` (test)

## Files Created/Modified

- `test/example/lib/example/demo/seeds.ex` — Added `print_credentials()` call in `run/0` and private `print_credentials/0` function; calls `Personas.feature_map()[local]` via existing `Personas` alias
- `test/example/test/example_web/live/demo/credentials_live_test.exs` — New file; `use ExampleWeb.ConnCase, async: false`; two describe blocks: 404 env-guard + rendered HTML contract with 10 assertions
- `.planning/phases/142-dev-credentials-page-app-framing/142-VALIDATION.md` — Updated `nyquist_compliant: true`, `wave_0_complete: true`; filled real task IDs and green status

## Decisions Made

- Used `Phoenix.HTML.Safe.to_iodata/1 |> IO.iodata_to_binary/1` for Rendered→binary conversion: `Phoenix.HTML.safe_to_string/1` only accepts `{:safe, iodata}` tuples, not `%Phoenix.LiveView.Rendered{}` structs directly. The Safe protocol impl on Rendered provides `to_iodata/1` which gives us the raw iodata.
- Seeds calls `Personas.feature_map()[local]` (not `CredentialsLive.feature_map/0`) because `feature_map/0` was placed in `Example.Demo.Personas` in Plan 01 — the D-02 single source is already in the `Personas` module which `seeds.ex` already aliases at line 33.

## Deviations from Plan

None — plan executed exactly as written. The `Phoenix.HTML.Safe.to_iodata/1` conversion was explicitly anticipated by the plan as a fallback path (the plan noted to try it if `safe_to_string/1` raised a protocol error). The direct Safe protocol approach is cleaner than chaining through `html_escape/1`.

## Known Stubs

None — test uses real `Personas.all()` and `Personas.feature_map()` data; seeds prints real persona credentials. No hardcoded empty values or placeholder text.

## Threat Flags

No new threat surface beyond the plan's threat_model. T-142-01 mitigation is verified by the 404 test (route compiles out in test env). T-142-03 (seeds stdout printing demo passwords) is accepted per plan — seeds only runs in dev, demo passwords are public-by-design.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| test/example/lib/example/demo/seeds.ex — print_credentials call | FOUND (2 matches) |
| test/example/lib/example/demo/seeds.ex — Personas.feature_map call | FOUND |
| test/example/lib/example/demo/seeds.ex — Demo Credentials string | FOUND |
| test/example/test/example_web/live/demo/credentials_live_test.exs | FOUND |
| test/example/test/example_web/live/demo/credentials_live_test.exs — assert conn.status == 404 | FOUND |
| test/example/test/example_web/live/demo/credentials_live_test.exs — demo-credentials-table testid | FOUND |
| Commit 926e095 (Task 1) | FOUND |
| Commit d52934c (Task 2) | FOUND |
| 2 tests, 0 failures (scoped run) | PASSED |
| 185 tests, 0 failures (full suite) | PASSED |
