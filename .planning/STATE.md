---
gsd_state_version: 1.0
milestone: v1.37
milestone_name: AUTH-BRANDING-WHITELABEL
status: Complete
last_updated: "2026-06-07T16:38:59-04:00"
last_activity: 2026-06-07 — v1.37 shipped: branded auth shell, Light/Dark/System auth defaults, validated brand profile, admin customizer, branded emails, docs, golden parity, and generated-host smoke proof.
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 5
  completed_plans: 5
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** v1.37 AUTH-BRANDING-WHITELABEL complete; ready for next milestone selection.

## Current Position

Phase: 177 — Verification, Generated-Host Smoke, and Audit Closure
Plan: 177-01 complete
Status: v1.37 complete
Last activity: 2026-06-07 — milestone shipped after compile, docs, focused ExUnit, example LiveView tests, diff hygiene, and generated-host Playwright smoke verification.

## Accumulated Context

### Decisions

- Source material for v1.35 was intentionally repo evidence plus the supplied pressure-test prompt; no external AI-generated brand book was available in the repository.
- Process correction: the original v1.35 closeout was premature because it skipped human logo direction review. Phase 167 repaired that gap and ratified Option A Core Rails.
- Brand artifacts are self-contained under `brandbook/` to avoid churn in runtime code, generated templates, README, HexDocs, or existing docs.
- Asset policy is text/SVG-first: Markdown, HTML, JSON, CSS, and SVG are committed; PNG/PDF/raster exports are generated only for concrete distribution targets.
- The brand concept is "protected core framed by visible host-code rails", mapping directly to Sigra's library-owned security core plus generated host-owned Phoenix code.
- The existing README/launch/security posture remains the voice source of truth: boundary-first, technically exact, low hype.
- `brandbook/tokens.json` and `brandbook/tokens.css` are the brand collateral token source; they do not mutate admin/generated UI tokens by themselves.
- Phase 167 plan 01 generated five logo options and an options review page; Phase 167 plan 02 finalized Option A Core Rails after human selection.
- Human logo decision: Option A Core Rails is the ratified Sigra logo direction.
- v1.36 scope decision: admin UI only; do not polish non-admin demo/auth/organization screens unless required for admin evidence.
- v1.36 theme decision: expose Light, Dark, and System as an explicit shell control with local persistence and system fallback.
- v1.36 architecture decision: preserve the hand-authored `sg-*` BEM/cascade-layer CSS system and route reusable markup through `Sigra.Admin.Components` or the shell seam.
- v1.36 theme decision: use a namespaced `data-sg-admin-theme` root carrier plus `.sg-admin-shell[data-theme]`; do not set global DaisyUI `data-theme` from the admin switch.
- v1.36 visual-baseline decision: refreshed checkpoint PNGs are limited to `global-overview`, `org-overview`, `user-detail`, and `user-audit`.
- v1.37 architecture decision: auth branding is a structured token profile, not raw runtime CSS by default.
- v1.37 styling decision: generated auth defaults live in host-owned `SigraAuthComponents` and scoped `.sigra-auth` CSS, preserving full custom control without taking over the app design system.
- v1.37 theme decision: auth surfaces support Light, Dark, and System independently from the admin shell theme control.
- v1.37 persistence decision: global admin branding uses `sigra_brand_profiles` in the configured auth schema prefix and falls back to code/config defaults when the table or repo is unavailable.
- v1.37 email decision: transactional emails share the same branding profile as auth forms so product identity stays coherent across the auth journey.
- v1.37 generated-host fix: avoid Elixir boolean `not` against nullable assigns in templates; use `!` truthiness guards for generated HEEx conditions.
- v1.37 generated-host fix: runtime branding prefix detection must handle generated user schemas that need `Code.ensure_loaded?/1` before `__schema__(:prefix)`.

### Pending Todos

- None.

### Blockers/Concerns

- None.

## Deferred Items

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| Brand exports | PNG/PDF exports for social/platform use | Deferred until a concrete platform target requires raster | v1.35 |
| Public docs | README/HexDocs visual adoption | Deferred to a separate focused change to avoid brand churn | v1.35 |
| Automation | Visual regression for `brandbook/index.html` | Nice-to-have | v1.35 |
| Playwright | `Phoenix.Ecto.SQL.Sandbox` for browser acceptance tests | Deferred | v1.33 |

## Session Continuity

Last session: 2026-06-06T00:50:00.000Z
Stopped at: Phase 167 complete after logo ratification
Resume file: None

## Performance Metrics

| Phase | Plan | Duration | Notes |
| --- | --- | --- | --- |
| Phase 161 | 1 plan | same session | Repo evidence extraction + audit |
| Phase 162 | 1 plan | same session | Brand DNA + voice |
| Phase 163 | 1 plan | same session | Tokens + UI guidance |
| Phase 164 | 1 plan | same session | SVG logo/specimen assets |
| Phase 165 | 1 plan | same session | Static HTML brandbook |
| Phase 166 | 1 plan | same session | Verification + repo hygiene |
| Phase 167 P01 | 1 plan | same session | Logo option generation + presentation |
| Phase 167 P02 | 1 plan | same session | Option A logo ratification + final verification |
| Phase 168 | 1 plan | same session | Admin brand/theme audit with parallel agent findings |
| Phase 169 | 1 plan | same session | Durable admin UI principles + design contract update |
| Phase 170 | 1 plan | same session | Rail Accent shell + Light/Dark/System theme control |
| Phase 171 | 1 plan | same session | Scoped admin design-system touchpoint polish |
| Phase 172 | 1 plan | same session | ExUnit, Playwright, snapshot, and generated-host verification |
| Phase 173 | 1 plan | same session | Auth branding profile contract + config/runtime resolution |
| Phase 174 | 1 plan | same session | Generated auth shell + scoped Light/Dark/System CSS |
| Phase 175 | 1 plan | same session | Admin branding customizer + branded emails |
| Phase 176 | 1 plan | same session | Example, golden fixture, docs, and installer parity |
| Phase 177 | 1 plan | same session | Compile, docs, tests, diff hygiene, and generated-host smoke |

## Operator Next Steps

- Run `$gsd-new-milestone` to define fresh requirements and roadmap for the next milestone after v1.37.
