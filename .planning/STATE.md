---
gsd_state_version: 1.0
milestone: v1.39
milestone_name: DS-COHERENCE
status: executing
last_updated: "2026-06-14T22:45:20.528Z"
last_activity: 2026-06-14
progress:
  total_phases: 39
  completed_phases: 3
  total_plans: 17
  completed_plans: 12
  percent: 8
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 187 — individual-components-l1

## Current Position

Phase: 187 (individual-components-l1) — EXECUTING
Plan: 3 of 7
Status: Ready to execute
Last activity: 2026-06-14

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
- [Phase ?]: opentype.parse(readFileSync(path).buffer) is the correct Node.js API for opentype.js v2.0 in ESM scripts; loadSync is deprecated and returns undefined
- [Phase ?]: playwright-core is reused from test/example/priv/playwright/ in critique-render.mjs to avoid duplicate install
- [Phase 179]: A3 crossbar-s reworked to rail-g after failing the render gate twice; B2 s-substitute is a serpentine rail-switchback; C1 mark set into line-1 negative space — Render-critique loop verdicts: planned geometries fought the chosen fonts' anatomy; reworked designs pass all rubric rows
- [Phase 179]: outline-wordmark.mjs: variation coords require font as 5th getPath arg; toPathData must use flipY:false on getPath output — Two latent Plan 01 toolchain bugs caught by visually reading renders; fixed before candidate work
- [Phase 180]: Human gate ratified **D4 Linked Rail** (round-4 refinement of A1 Rail-i): Space Grotesk v2.0 wght 700, ember rail-block tittle + g tail extended to x=557 aligning under the tittle as one bracketing rail system; favicon is the abstract rail glyph (no letter — round-3 "ig" crop read as Instagram and is retired). Palette fine-tuning allowed within hue 15–40° in Phase 181; light-surface favicon accent is ember-700. One budgeted round-4 loop used; decision recorded in brandbook/logo-options/round-3/README.md.
- [Phase 181]: Built 8 D4 production SVGs at brandbook/ (logo-primary{,-dark,-subtitle}, logo-mark, logo-monochrome, favicon, social-card{,-dark}); palette UNCHANGED from ratified (#c2410c / #fdba74 — 16px kill test passed on ratified values, no micro-tuning). 6 v1 Rail Accent assets archived to brandbook/logo-options/archive-v1/ (read from live tree before overwrite; deprecation README). Verified 4/4.
- [Phase 182]: index.html v2 (expanded #logo multi-lockup + typemark anatomy + clearspace/misuse; new #suite szTheory 7-lib section; #scorecard). tokens.json PATCH-bumped 1.0.0→1.0.1 + meta.changed; tokens.css provenance header (values unchanged); Token Change Policy section in README. Stale v1 staggered-bars mark (path M17 14v14) replaced with D4 geometry in examples/landing-hero.svg + readme-header.svg. Committed axe gate at scripts/brand/axe-brandbook.mjs (serves brandbook/ on :7743, AxeBuilder wcag2a/wcag2aa) — ZERO violations. Verified 4/4.
- [Phase 183]: D4 logo propagated to installer (priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg) + example (test/example/priv/static/images/) as a PURE viewBox reframe (viewBox="20 220 2361 1000", path-only, "Space Grotesk v2.0" provenance) — installer==example byte-identical. Companion rail-accent-mark{,-dark}.svg swapped to D4 abstract mark. Guard-test reality: the "parity" tests pinned v1 content (viewBox 20 12 188 54 + "Inter Display Black v4.1.") so 2 assertion strings/file were updated to D4 + the install golden fixture's 2 logo SVGs regenerated (documented SC1 deviation — invariant preserved). Token parity VERIFIED UNCHANGED (#c2410c/#fdba74). 21 admin Playwright baselines recaptured (7 slugs×3 projects) via snapshot-recapture-gate.sh on :4011; impersonation-banner canary untouched; allowlist reset to empty. 3 stale playwright spec selectors fixed (pre-existing UI drift). Verified 4/4 passed-with-notes.
- [RESOLVED 2026-06-13]: The two "pre-existing core-template failures" (auth.ex `app_name` binding + count 52 vs 49) were branch regressions, fixed in `232b4e35` (see `.planning/seeds/preexisting-core-template-failures.md`). The later red CI was a separate issue — upstream `phx_new` 1.8.8 dropping `type` from `<.button>` — fixed by pinning `phx_new 1.8.7` (forward-compat in `SEED-004`). All gates green; nothing outstanding.
- [Phase 183]: Recaptured 7 non-canary admin Playwright baselines for D4 logo; canary restored; allowlist returned to empty steady-state on main 2026-06-13.

### Pending Todos

- None.

### Blockers/Concerns

- None.

## Quick Tasks Completed

| Quick ID | Task | Status | Date |
| --- | --- | --- | --- |
| 260613-f1p | Pin phx_new to 1.8.7 in CI workflows (fix PR #52 red CI from phx_new 1.8.8 `<.button type>` drop). Verified: vault_promotion + golden_diff pass locally; SEED-004 filed for forward-compat. | complete ✓ | 2026-06-13 |

## Deferred Items

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| Brand exports | PNG/PDF exports for social/platform use | Deferred until a concrete platform target requires raster | v1.35 |
| Public docs | README/HexDocs visual adoption | Deferred to a separate focused change to avoid brand churn | v1.35 |
| Automation | Visual regression for `brandbook/index.html` | Nice-to-have | v1.35 |
| Playwright | `Phoenix.Ecto.SQL.Sandbox` for browser acceptance tests | Deferred | v1.33 |

## Session Continuity

Last session: 2026-06-14T22:45:20.522Z
Stopped at: Completed 187-02-PLAN.md
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
| Phase 179 P01 | 10m | 3 tasks | 6 files |
| Phase 179 P02 | ~40 minutes | 3 tasks | 25 files |
| Phase 183 P02 | 90 | 2 tasks | 24 files |
| Phase 187 P01 | 23 min | 3 tasks | 18 files |
| Phase 187 P02 | 26 min | 3 tasks | 8 files |

## Operator Next Steps

- **Start next milestone** when ready: `/gsd-new-milestone` (does the full PROJECT.md evolution + REQUIREMENTS reset + git tag that this lightweight archive deliberately deferred).
- **Forward-compat (deferred):** `SEED-004` — make Sigra robust to phx.new ≥1.8.8 button API, then bump/remove the `phx_new 1.8.7` pin.
- **Fast-follow (deferred):** README header + GitHub social-preview adoption (`/gsd-quick`).
- **Hex versioning wart (deferred, Jon's call):** stray `1.20.0` still outranks `1.1.0`/`1.0.0` as `latest_stable` on hex. Fix when desired: `mix hex.user auth` then `mix hex.retire sigra 1.20.0 …` (reversible via `--unretire`).
- **Done 2026-06-13:** v1.38 shipped + archived, `v1.1.0` on hex, CI green, PRs triaged, local git clean (only `main`), snapshot allowlist at steady-state.
