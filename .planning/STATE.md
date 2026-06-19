---
gsd_state_version: 1.0
milestone: v1.39
milestone_name: DS-COHERENCE
current_phase: 39
status: Awaiting next milestone
stopped_at: Completed 192-01-PLAN.md
last_updated: "2026-06-19T16:16:25.291Z"
last_activity: 2026-06-19
last_activity_desc: Milestone v1.39 completed and archived
progress:
  total_phases: 15
  completed_phases: 9
  total_plans: 39
  completed_plans: 39
  percent: 60
current_phase_name: ratification-baseline-lock
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Between milestones — v1.39 DS-COHERENCE shipped & archived 2026-06-19. Run `/gsd-new-milestone` for the next cycle (phases continue from 193).

## Current Position

Phase: Milestone v1.39 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-06-19 — Completed quick task 260619-l1b: demo/admin-UI Docker DX overhaul (proxy+watch default, health-gated URL, auto-open, grouped routes)

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
- [Phase 188]: Kept Phase 186 token values unchanged; this plan hardened evidence only. — Phase 188 D-15/D-16 scoped the folded work to test-harness robustness and explicitly excluded token-value changes.
- [Phase 188]: Documented token completeness is enforced by ExUnit rather than manual review. — The admin-token-reference guard extracts canonical :root --sg-* token names and fails when a documented row is missing.
- [Phase 188]: Panel rhythm for sg-filter-panel and sg-detail-panel moved with the group selectors so generated hosts keep the same internal spacing. — Those panels are the L2 group surfaces; leaving their padding in app.css would keep generated-host evidence masked by the example layer.
- [Phase 188]: No --sg-* token declarations were changed; this was a selector migration and mirror sync only. — Phase 188 D-03 through D-05 required canonical shipped CSS migration without Phase 186 token retuning.
- [Phase 188]: MG-3 and MG-5 use unframed board wrappers where group content contains sg-card children. — This preserves the Phase 188 no card-in-card scoring rule while still rendering real task-card and mobile-card examples.
- [Phase 188]: MG-11 confirmation overlays are inline-scoped in the gallery so static evidence does not cover the full page. — The gallery must render all boards simultaneously; literal fixed overlays would obscure unrelated evidence.
- [Phase 188]: UserShowLive MG-11 confirmation state carries title, copy, confirm label, and cancel label while preserving revocation events. — The production destructive confirmation needed action-specific copy without changing existing session revocation flow.
- [Phase 188]: UserShowLive uses sg-confirm-overlay/sg-confirm-dialog instead of DaisyUI modal markup. — Phase 188 D-13/D-14 required production MG-11 evidence to match the Sigra-owned group contract.
- [Phase 188]: GROUP_BOARDS is the single 11-item catalog used by admin-design screenshots, responsive checks, and group assertions. — The L2 scorecard needs one source of truth for MG-1 through MG-11 across browser evidence.
- [Phase 188]: Only MG-1 through MG-11 design snapshot deltas remain after recapture; L1 churn and board-notice canary changes were restored. — Phase 188 required deliberate L2 visual evidence without broad baseline churn.
- [Phase 188]: Phase 188 L2 ledger remains Tier 1 for MG-1 through MG-11 rather than claiming award-grade Tier 2. — The phase established ratified executable evidence and visual baselines, but did not run a separate award-grade polish review.
- [Phase 188]: Phase 188 validation is ratified from passing ExUnit, admin-design, ledger, canary, allowlist, and example precommit gates. — The validation document should reflect reproducible command evidence rather than intent-only status.
- [Phase ?]: Phase 190 L4 tier rationale: weakest-link bounded by L3 Tier 1 constituents; flow-only criteria passing confirms Tier 1 = Ratified
- [Phase ?]: DOM-marker anchoring for branding_live.ex carve-out in glossary_test.exs (D-09)
- [Phase ?]: admin-glossary.md enforced by ExUnit test; ships with library so adopters inherit drift guard (D-07)
- [Phase ?]: account not in automated banned_terms (too many legitimate uses); handled per-line in Wave 2 (Pitfall 1)
- [Phase ?]: Auth-replica carve-out preserved: branding_live.ex lines 580-610 untouched
- [Phase ?]: COPY-03: chip_label deleted clause added for Deletion scheduled coherence
- [Phase ?]: WR-04 fixed: inspect(reason) replaced with generic error message
- [Phase ?]: branding-live L3 row appended at Tier 1 — compliance, not award-grade
- [Phase ?]: Quality ledger update
- [Phase 191]: admin-design MG-5/6 content-equivalence test failure is pre-existing data-state issue from Phase 188 (requires 25+ audit events for pagination); not a Phase 191 regression
- [Phase 191]: SIGRA_EXAMPLE_URL=http://localhost:4011 must be set for local Playwright runs; default 4000 collides with Rulestead Docker
- [Phase ?]: D-07: Widened axe withTags from wcag2a/wcag2aa to full WCAG 2.1/2.2 AA five-element array in both admin Playwright helpers
- [Phase ?]: D-09: best_practice tag-group excluded from both withTags calls; region exclusion rationale preserved
- [Phase ?]: GATE-01: all 6 admin Playwright projects pass
- [Phase ?]: GATE-01: all 6 admin Playwright projects pass compare-mode; target-size suppressed per D-08 for intentionally dense admin controls
- [Phase ?]: GATE-02: Generated admin Playwright smoke CI = success for origin/main SHA 07e15ca9; blocking suite green with quarantine (0 failures, 3 excluded)
- [Phase ?]: GATE-03: monotonic guard exits 0; ~35 ledger cells locked at Tier 1 in terminal ratification note (Phase 192 2026-06-18)
- [Phase ?]: Unicode curly-quote bug in 192-01 axe widening fixed (Edit tool artifact); target-size D-08 suppression applied

### Pending Todos

- None.

### Blockers/Concerns

- None.

## Quick Tasks Completed

| Quick ID | Task | Status | Date |
| --- | --- | --- | --- |
| 260613-f1p | Pin phx_new to 1.8.7 in CI workflows (fix PR #52 red CI from phx_new 1.8.8 `<.button type>` drop). Verified: vault_promotion + golden_diff pass locally; SEED-004 filed for forward-compat. | complete ✓ | 2026-06-13 |
| 260618-fch | Fix vault_promotion_test.exs known failure — strip unsupported `type` attr from `<.button>` across 7 installer templates (durable fix vs phx_new button `:rest` allowlist) + sync example/golden mirrors + lift known_failure quarantine. Verified: 1 test, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-gdf | Resolve golden_diff_test.exs known failure — root cause was local phx_new 1.8.8 vs CI-pinned 1.8.7 (spurious config.exs `root_tag_attribute` byte-diff), NOT a stale fixture. Installed 1.8.7, lifted known_failure tag (no fixture change), documented phx_new 1.8.7 dev prereq in CLAUDE.md. Verified: 2 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-gly | Harden phase-186 D-11 parity test extractors — WR-02 (structural `extract_css_block/2` for auth dark block, replacing `Enum.take(30)`) + WR-03 (`extract_token_value/2` scoped to correct CSS block via optional selector). WR-01/IN-02 already resolved by prior pass; IN-03 optional CI guard deferred to new todo. Verified: 27 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-grh | Narrow glossary drift-guard `action=` strip (phase 191 WR-01) — strip `action={…}` expressions but scan `action="…"` copy literals for banned terms; added regression test for the false-negative gap. Verified: 2 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 189-verify | Close phase-189 ConfirmDialog review todo — WR-01/02/03/04 found already fixed in source (admin_hooks.js + branding_live.ex); fixed the dormant PAGE-03 verification spec (stale `/cancel/i` → `[data-sg-confirm-cancel]`) and wired admin-modal-interaction.spec.ts into the chromium CI lane. Verified green locally: 7/7 APG gates. | complete ✓ | 2026-06-18 |
| 260619-l1b | Demo/admin-UI Docker DX overhaul — `scripts/uat/up.sh` (no flags) now defaults to the shared-Traefik proxy path WITH live reload, health-gates the URL (never prints a live URL until an HTTP 200 probe passes; `STARTING` otherwise), auto-opens `/demo/credentials`, and prints grouped auth/admin/ops routes. New flags `--dev`/`--host` (host-run, now actually starts+gates Phoenix), `--attach`/`--iex`, `--no-watch`, `--no-open`. New `docker-compose.watch.yml` bind-mount override (compile-env invariant preserved) + web healthcheck; `down.sh` kills the host-run Phoenix PID; `sigra.localhost` alias relaxed to claim-based (feature branches can win it). Docs refreshed. Static checks pass (bash -n, compose config -q, grep assertions); maintainer still runs the Docker end-to-end checklist. | complete ✓ | 2026-06-19 |

## Deferred Items

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| Brand exports | PNG/PDF exports for social/platform use | Deferred until a concrete platform target requires raster | v1.35 |
| Public docs | README/HexDocs visual adoption | Deferred to a separate focused change to avoid brand churn | v1.35 |
| Automation | Visual regression for `brandbook/index.html` | Nice-to-have | v1.35 |
| Playwright | `Phoenix.Ecto.SQL.Sandbox` for browser acceptance tests | Deferred | v1.33 |

### Acknowledged at v1.39 close (2026-06-19)

19 open artifact items acknowledged and deferred at milestone close. None are blockers; all are stale-resolved or deliberately tracked.

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| debug | platform-admin-flow-spec | stale-resolved — fixes landed in PR #54; session moved to `debug/resolved/` | v1.39 |
| quick_task | 260528-nwa-fix-rc-01-in-guides-recipes-companion-li | superseded by v1.39 work | v1.39 |
| quick_task | 260528-sbn-fix-v1-29-doc-debt-mailglass-corrigendum | superseded / stale | v1.39 |
| quick_task | 260602-gll-stage-0-admin-ui-pass-2-design-system-fo | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-gzc-stage-1-admin-ui-pass-2-shell-ia-chrome- | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-hao-stage-2-admin-ui-pass-2-landing-needs-le | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-hhr-stage-3-admin-ui-pass-2-users-index-craf | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-hoz-stage-4-admin-ui-pass-2-user-detail-summ | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-hvx-stage-5-admin-ui-pass-2-audit-explorer-i | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-i3m-stage-6-admin-ui-pass-2-org-overview-mad | superseded by v1.39 DS-COHERENCE | v1.39 |
| quick_task | 260602-ikd-stage-7-admin-ui-pass-2-motion-toast-cmd | superseded by v1.39 DS-COHERENCE | v1.39 |
| todo | 2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent | tracked — needs 25+ audit events for pagination fixture | v1.39 |
| todo | 2026-06-17-page04-branding-explicit-scoring | tracked | v1.39 |
| todo | 2026-06-18-token-reference-completeness-ci-guard | tracked | v1.39 |
| todo | 2026-06-19-demo-showcase-remember-checkbox-color-flaky | tracked | v1.39 |
| todo | recapture-gate-single-lane | tracked — shared `--require-all` slugs break single-lane recapture | v1.39 |
| seed | SEED-004-phx-new-button-forward-compat | dormant | v1.39 |
| seed | SEED-005-ci-cd-pipeline-performance-audit | dormant | v1.39 |
| seed | SEED-006-admin-design-gallery-ci-baseline-recapture | dormant | v1.39 |

## Session Continuity

Last session: 2026-06-18T07:18:09.153Z
Stopped at: Completed 192-01-PLAN.md
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
| Phase 187 P03 | 20 min | 2 tasks | 18 files |
| Phase 187 P04 | 55 min active | 2 tasks | 16 files |
| Phase 187 P05 | 12 min | 2 tasks | 10 files |
| Phase 187 P06 | 16 min | 2 tasks | 7 files |
| Phase 187 P07 | 7 min | 3 tasks | 1 files |
| Phase 188 P01 | 4 min | 3 tasks | 2 files |
| Phase 188 P02 | 4 min | 2 tasks | 4 files |
| Phase 188 P03 | 6 min | 2 tasks | 1 files |
| Phase 188 P04 | 3 min | 2 tasks | 1 files |
| Phase 188 P05 | 24 min | 3 tasks | 35 files |
| Phase 188 P06 | 14 min | 2 tasks | 26 files |
| Phase 190 P05 | 3 min | 2 tasks | 3 files |
| Phase 191 P01 | 235 | 2 tasks | 2 files |
| Phase 191 P02 | 20 | 2 tasks | 6 files |
| Phase 191 P03 | 3 min | 1 tasks | 1 files |
| Phase 191 P04 | 135 min | 1 tasks | 16 files |
| Phase 192 P01 | 1 | 2 tasks | 2 files |
| Phase 192 P02 | 10 | 2 tasks | 6 files |
| Phase 192 P03 | 1 min | 1 tasks | 1 files |
| Phase 192 P04 | 45 min | - tasks | - files |

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
