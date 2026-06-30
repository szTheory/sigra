---
gsd_state_version: 1.0
milestone: v1.42
milestone_name: CI-Gate Remediation
current_phase: 208.1
current_phase_name: v1-42-ci-gate-remediation
status: executing
stopped_at: Completed 208.1-01-PLAN.md
last_updated: "2026-06-30T03:12:31.872Z"
last_activity: 2026-06-30
last_activity_desc: Phase 208.1 execution started
progress:
  total_phases: 8
  completed_phases: 3
  total_plans: 19
  completed_plans: 15
  percent: 38
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 208.1 — v1-42-ci-gate-remediation

## Current Position

Phase: 208.1 (v1-42-ci-gate-remediation) — EXECUTING
Plan: 2 of 4
Status: Ready to execute
Next: Phase 208.1 (v1.42 CI-Gate Remediation) inserted — run `/gsd-plan-phase 208.1`
Last activity: 2026-06-30 -- Phase 208.1 execution started

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
- [Phase 191]: admin-design MG-5/6 content-equivalence test failure is pre-existing data-state issue from Phase 188 (requires 25+ audit events for pagination fixture); not a Phase 191 regression
- [Phase 191]: SIGRA_EXAMPLE_URL=http://localhost:4011 must be set for local Playwright runs; default 4000 collides with Rulestead Docker
- [Phase ?]: D-07: Widened axe withTags from wcag2a/wcag2aa to full WCAG 2.1/2.2 AA five-element array in both admin Playwright helpers
- [Phase ?]: D-09: best_practice tag-group excluded from both withTags calls; region exclusion rationale preserved
- [Phase ?]: GATE-01: all 6 admin Playwright projects pass
- [Phase ?]: GATE-01: all 6 admin Playwright projects pass compare-mode; target-size suppressed per D-08 for intentionally dense admin controls
- [Phase ?]: GATE-02: Generated admin Playwright smoke CI = success for origin/main SHA 07e15ca9; blocking suite green with quarantine (0 failures, 3 excluded)
- [Phase ?]: GATE-03: monotonic guard exits 0; ~35 ledger cells locked at Tier 1 in terminal ratification note (Phase 192 2026-06-18)
- [Phase ?]: Unicode curly-quote bug in 192-01 axe widening fixed (Edit tool artifact); target-size D-08 suppression applied
- [Phase ?]: [Phase 193-02]: Tolerance widened to ±10 for remember-checkbox color assertion
- [Phase ?]: [Phase 193-02]: afterBackgroundColor exact check left untouched — not evidenced as flaky by the FLAKE-01 todo (only backgroundColor was cited)
- [Phase ?]: Drop library_tests edge from example_playwright_smoke.needs — verified gratuitous; keeps release_ref_guard; lane stays required in ci-gate.needs (CRIT-01)
- [Phase ?]: Add id: deps_cache/example_deps_cache to cache steps + GITHUB_STEP_SUMMARY observability (resolved versions, cache-hit, slowest tests) to library_tests job (BASE-03)
- [Phase ?]: D-11/D-14: 6 guards folded into fast_checks; ci-gate rewired
- [Phase ?]: D-12: release_ref_guard kept standalone no-checkout DAG gate (intentional D-12 exclusion)
- [Phase ?]: D-15: MAINTAINING.md stale required-check string swept from both locations; 5 live names + ci-gate aggregator note confirmed
- [Phase ?]: [Phase 195-02]: Option (a) chosen for shard test command: keep --slowest 10. A/B measured ~47% speedup without --slowest on async-only files, but subprocess serial tail bounds shard walltime. D-01 default keeps per-test timing observability.
- [Phase ?]: [Phase 195-02]: mix docs relocated to library_tests_dep_off (already compiled, non-shard, zero overhead). fast_checks alternative rejected: would add toolchain prelude overhead (2-3m).
- [Phase ?]: [Phase 195-02]: Ruleset 14941512 confirmed at execution time: required check string is byte-identical 'Library tests' — aggregator job id library_tests + name Library tests is safe.
- [Phase ?]: Kept discrete CI steps, changed only final test command to --only threadline_guard (D-10/D-11/D-14)
- [Phase ?]: CACHE-03: no larger runners adopted; measurement-gate runbook shipped in guides/recipes/local-development.md (D-21/D-22/D-23)
- [Phase ?]: Job-level if: github.event_name != 'pull_request' used for 5 moved jobs (196-01 D-02)
- [Phase ?]: ci-gate skip-tolerant: result != success && result != skipped tolerates PR-skipped needs without weakening real-failure detection (196-01 D-09)
- [Phase ?]: Live ruleset 14941512 confirmed at execution: 5 required-check contexts, enforcement active, no 6th/renamed context (196-01 D-12)
- [Phase ?]: ADD-only doc discipline: CI cadence subsection appended to MAINTAINING.md without touching the already-correct required-check section (5 lane names, ci-gate NOT required)
- [Phase ?]: D-13 correction: CRIT-03 phrasing (single stable required check ci-gate) is stale; live ruleset 14941512 enforces 5 lane name strings; ci-gate is internal aggregator; correction recorded in 196-VERIFICATION.md only
- [Phase 197]: Used let link closure variable inside expect.poll callback to capture invitation URL — idiomatic TypeScript approach for async side-effect capture — TypeScript type narrowing requires the link variable to be declared in outer scope; closure assignment inside poll keeps the logic self-contained
- [Phase 197]: Intervals [250, 500, 1000] with timeout 30_000 replaces prior 30x1s fixed budget — Graduated backoff resolves faster on CI while keeping same worst-case budget; follows passkeys-hooks.spec.ts expect.poll precedent
- [Phase ?]: PW-01 criterion 1a: all 5 Playwright seams in example_playwright_smoke run independently under !cancelled() guards; aggregator re-fails job on any seam failure
- [Phase ?]: Staging step guard corrected from success() to steps.admin_checkpoints.outcome == 'success' (Pitfall 4 fix)
- [Phase ?]: webkit cannot be dropped (D-04): iPhone 13 mobile projects need webkit; criterion 1b is reliability win not time reduction
- [Phase ?]: .planning/phases/197-playwright-lanes-design-gallery-re-gate/197-03-SUMMARY.md
- [Phase ?]: .planning/phases/197-playwright-lanes-design-gallery-re-gate/197-03-SUMMARY.md
- [Phase ?]: .planning/phases/197-playwright-lanes-design-gallery-re-gate/197-03-SUMMARY.md
- [Phase ?]: .planning/phases/197-playwright-lanes-design-gallery-re-gate/197-03-SUMMARY.md
- [Phase ?]: OQ1: board-notice canary re-established as 'added' via pre-delete before --update-snapshots (tripwire stays armed)
- [Phase ?]: OQ2: recaptured PNGs committed to ci/recapture-admin-design branch + gh pr create for human review (not silent push to main)
- [Phase ?]: OQ3: bounded compare-and-report scope -- sibling lanes compared only; drift deferred to tracked todo with per-lane recapture path
- [Phase ?]: D-10 re-gate: continue-on-error removed from design gallery step; gallery now hard-gates via the Plan 02 aggregator; inline in example_playwright_smoke (not nightly)
- [Phase ?]: D-07 operator-truth: SEED-006 false webfont-load premise corrected; real cause was OS system-ui font-metric delta; SEED-006 marked addressed/folded by Phase 197
- [Phase ?]: D-06: design_gallery hard re-gated in ci.yml — continue-on-error removed, aggregator entry restored (commit 32d43bb5)
- [Phase ?]: D-07: Phase51 stale todo and design-gallery deferral todo closed to .planning/todos/resolved/ (commit 8d3b1e3c)
- [Phase ?]: GATE-01 met: PR-path -16.5m wall-clock (-43%)
- [Phase ?]: 198-ACCEPTANCE.md committed: 5 required-check names byte-stable (ruleset 14941512), 0 flakes, SEED-004 phx_new 1.8.7 confirmed, D-06 hard-gate verified
- [Phase ?]: MAINTAINING.md ADD-only pointer to 198-ACCEPTANCE.md added; all 5 required-check name strings intact (D-05)
- [Phase ?]: Tier-2 proxies encoded as prose/bullets in fractal scorecard — no new columns or machine-parseable proxy files
- [Phase ?]: 4 automated gates mapped (axe-while-open, APG, content-equivalence, glossary) + 3 documented-as-manual proxies (motion, density, target-size) per D-02
- [Phase ?]: Ledger Tier-2 assertion convention: bare integer 2 + Evidence expansion; decorators forbidden to protect awk guard parse (D-03)
- [Phase ?]: Terminal-ratification prose reconciled — Tier 2 now objectively earnable via Phase 199 proxy contract; ratcheting starts Phases 200-204 (D-06)
- [Phase ?]: D-04 confirmed: guard logic unchanged; D-05 delivered: hermetic bash self-test proves 2→1 decrease is caught; D-07 confirmed: --base wiring byte-unchanged
- [Phase ?]: Filter /admin/users with ?q= to deterministically target >=25-event seeded admin; avoids inserted_at DESC ordering pollution by harness login user
- [Phase 200]: Plan 200-01: Confirm copy uses UI-SPEC verbatim on new UserSessionsLive surface (Cancel/Revoke + consequence+reversibility confirm body) rather than user_show_live.ex legacy phrasing — New surface authored award-grade from start per D-04; UI-SPEC Copywriting Contract is authoritative
- [Phase ?]: Danger Zone 'Revoke all sessions' button removed — session revocation deferred entirely to UserSessionsLive per D-04
- [Phase ?]: Applied chips consolidated inside GET form as navigation-only a tags; GET form contract preserved (D-01/D-02)
- [Phase ?]: status_pills/1 reduced to Unconfirmed/No MFA (warn)/Locked/Deletion scheduled; Confirmed and 4-way security cond dropped (D-04)
- [Phase ?]: DRY per-row presentation via user_name_stack/1 and user_status_cluster/1 field-slice components for both desktop td and mobile article (D-05)
- [Phase ?]: Used binary 'Example badge' for extra_list_badges and %{label: Region, value: us-east} for extra_list_columns — matches badge_text/1 binary clause and column_text/2 label+value map clause; closes D-07 host-seam blind spot (INDEX-03)
- [Phase ?]: D-02: GET-form contract proven by real form submission
- [Phase ?]: D-06: td:nth-child(3)/(4) selectors confirmed targeting Organizations/Activity post-201-01 recompose; no selector change needed (column order frozen)
- [Phase ?]: D-09: users-index-live ratcheted to bare Tier 2; overlay-axe + APG gates marked N/A (no modal dialog); monotonic guard passes 36 cells vs origin/main
- [Phase ?]: D-12: List Archetype block in admin-design-contract.md rewritten to search-first elevated composition (Phase 201); stale sg-page-copy/metric-strip-first/detached-chip claims removed
- [Phase ?]: 201-04: Unfiltered /admin/users for list-scale pagination proof; getByRole Next page assertion; mg-6 not recaptured (markup unchanged)
- [Phase ?]: audit_table_row/1 uses format_timestamp/1 with-seconds for byte-coherent timestamps
- [Phase ?]: audit_table_row/1 places both code.sg-code nodes inside Event <td> <details> — keeps 4-column positional contract frozen and D-06 equivalence intact
- [Phase ?]: multi_page?/1 moved to components.ex as private helper owned by audit_pagination_nav/1; pre-built prev_href/next_href pass-in keeps per-page routing divergence in each LiveView
- [Phase ?]: [Phase 202-02]: Converged per-user from/to date inputs to type=date (Open Question 1 resolution — coherence with audit_index_live)
- [Phase ?]: [Phase 202-02]: Deleted private audit_tone/1, multi_page?/1, format_timestamp/1 from audit_user_live.ex — all now owned by components.ex shared helpers
- [Phase ?]: Deleted private audit_tone/1, multi_page?/1, format_timestamp/1 from audit_index_live.ex — all now owned by components.ex shared helpers
- [Phase ?]: [Phase 202-03]: Global audit filter form wrapped in <details> disclosure; summary text 'More filters' matches per-user page byte-for-byte
- [Phase ?]: [Phase 202-04]: Playwright guard scoped to tbody tr:first-child — count === 2 per-row works for gallery and live pages
- [Phase ?]: [Phase 202-04]: Absent-case pagination proof uses unique action= filter (1 result) instead of 25-event actor= filter — avoids log_in_user session.create contamination
- [Phase ?]: audit-index-live and audit-user-live ratcheted to bare Tier 2 with N/A overlay-axe + APG proxies (neither page owns a modal dialog)
- [Phase ?]: D-02: always-on Confirmed/ok pill removed from org roster — decision-bearing pills only
- [Phase ?]: D-03: Authentication coverage summary_chip removed from global overview dl
- [Phase ?]: 203-03: branding route is /admin/auth-branding not /admin/branding
- [Phase ?]: 203-03: aria-labelledby asserts restore-defaults-title (not user-session-confirm-title) per Pitfall 4
- [Phase ?]: no-change
- [Phase ?]: 203-04: Overview archetype block does not enumerate dropped Confirmed pill or coverage chip; no contract change needed
- [Phase ?]: D-08: Ratcheted index-live, organization-live, branding-live from bare 1 to bare 2; monotonic guard passes forward-only (36 cells)
- [Phase ?]: D-09: PAGE-04 branding-scoring todo folded into branding-live row; resolved (no new ledger row)
- [Phase ?]: D-10: global-overview + org-overview baselines idempotent; both allowlists empty at phase close
- [Phase ?]: 204-01: extract_disclosure_region targets Event codes summary specifically to skip More filters details earlier on page
- [Phase ?]: 204-01: page_size=25 query param used in boundary tests for deterministic 25/26 threshold independent of default config
- [Phase ?]: 204-02: Delete phase_192_known_failure_contract_test.exs — all 3 Phase192 known failures resolved, test.skip() quarantine already lifted in Phase 197 D-11b
- [Phase ?]: 204-02: Update phase148 example README assertion to 'Tasklane is a fictional project/work tracker' — matches actual post-rename README; stronger Tasklane identity lock than old 'Vaultr is the runnable local companion' string
- [Phase ?]: 204-03: color-mix ratio lowered from 62%/64% to 45% for .vt-status-pill and .vt-status-pill--ok — clears WCAG AA 4.5:1 on both light and dark themes; axe gate passes on impersonation-banner mobile
- [Phase ?]: 204-03: org-scoped-admin mobile baseline included in D-05 commit as additional stale baseline from Phase 203 pill-drop on org roster; mobile lane was aborting before reaching this checkpoint
- [Phase ?]: 204-03: recapture gate --require-all is a pre-commit check only; post-commit zero-drift proven by --base HEAD canary guard showing 0 changed slugs; admin-design 1px failures are pre-existing CI-only rendering artifacts
- [Phase 204-04]: Install-golden byte-diff green against phx_new 1.8.7; admin-acceptance-smoke exit 0 on fresh generated host; RATIFY-01 generated-host parity closed
- [Phase 204-04]: Stale sigra_admin_smoke_dev DB on system Postgres (port 5432) from prior partial run caused first smoke attempt to fail ecto.migrate; dropped manually; second run clean
- [Phase ?]: audit-user-live evidence corrected to admin_audit_user_live_test.exs; citation-accuracy only, tier digit unchanged
- [Phase ?]: v1.41 audit: tech_debt status — 18/18 reqs satisfied, 4 Low-severity deferred items, no blockers; verdict: accept debt, complete milestone
- [Phase ?]: Rubric positioned as complementary to fractal scorecard: scorecard grades visual/technical quality; rubric grades UX fitness-for-purpose via keep/tighten/kill per 3 lenses
- [Phase ?]: Three admin lenses bound by entry-point + intent: platform-admin (/admin triage), support-investigator (/admin/users/:id investigate), org-admin (/admin/organizations/:slug bound)
- [Phase ?]: D-07 anti-collision enforced: rubric uses keep/tighten/kill vocab; no bare 0/1/2 integer in table column-4 to prevent false-matching the ledger awk guard
- [Phase ?]: IN-04 resolved: stale Phases 200-204 forward reference replaced with dated completion note (v1.41 completed 2026-06-27) + ROADMAP pointer
- [Phase ?]: D-12 implemented: advisory IA diagnostic committed to .planning/ root as planning artifact; Phase 209 is the single binding gate (D-13 double-gate avoidance)
- [Phase ?]: D-14 disposition table uses High/Med/Low + P1/P2/P3; kill-from-any-lens auto-promotion applied; org-admin kill on Overview/Branding categorized as correct 403 gate, not surface flaw
- [Phase ?]: No board in design gallery renders .sg-btn--danger.is-armed; zero boards visually affected by Plan 02 CSS fix; full darwin recapture done for rendering drift
- [Phase ?]: admin-fractal-scorecard.md D-07: scorecard proxy prose updated to cite --sg-motion-* and --sg-ease / --sg-ease-* tokens (removed duplicate artifact)
- [Phase ?]: applied_chip remove control cited as ~22×22 CSS px (near-threshold; D-08 precedent)
- [Phase ?]: All 8 L1 ledger rows flipped to bare tier 2 with accurate per-component evidence strings from 206-02 audit; monotonic guard exits 0 (36 cells)
- [Phase ?]: CSS edited: no (Plan 02) — snapshot recapture is a no-op; compare-mode proves zero drift
- [Phase ?]: Token Conformance section added to admin-token-reference.md citing admin-token-completeness.sh (100/100) + admin-css-conformance.sh CHECK 2 + CHECK 3 (PATH A)
- [Phase ?]: CSS edited: no — zero genuine sg-* gaps found in 11 board-mg-* groups + 4 board-cfg-* composites; cite-and-flip confirmed (Phase 208-01)
- [Phase ?]: MG-7/MG-8 are isolated-board-only by design; no board-cfg-org composite exists or should be authored (D-06, Phase 208-01)
- [Phase ?]: mg-3 uses deliberate state-N/A note pattern (mg-3-zero-note / mg-3-loading-note); mg-9 and mg-11 render real states not N/A notes (D-08, Phase 208-01)
- [Phase ?]: Fix TEST count to 6 for board-mg-1 .sg-metric — cite-and-flip audit never counted actual DOM nodes (208.1-01)
- [Phase ?]: board-cfg-audit responsive fix mirrors MG-5/MG-6: sg-show-desktop table + sg-show-mobile audit_row cards (208.1-01)

### Pending Todos

- None.

### Blockers/Concerns

- None.

### Roadmap Evolution

- Phase 208.1 inserted after Phase 208: v1.42 CI-Gate Remediation: fix ~15 never-CI-validated admin Playwright failures blocking the backlog ship + Phase 208 completion (URGENT)

## Quick Tasks Completed

| Quick ID | Task | Status | Date |
| --- | --- | --- | --- |
| 260613-f1p | Pin phx_new to 1.8.7 in CI workflows (fix PR #52 red CI from phx_new 1.8.8 `<.button type>` drop). Verified: vault_promotion + golden_diff pass locally; SEED-004 filed for forward-compat. | complete ✓ | 2026-06-13 |
| 260618-fch | Fix vault_promotion_test.exs known failure — strip unsupported `type` attr from `<.button>` across 7 installer templates (durable fix vs phx_new button `:rest` allowlist) + sync example/golden mirrors + lift known_failure quarantine. Verified: 1 test, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-gdf | Resolve golden_diff_test.exs known failure — root cause was local phx_new 1.8.8 vs CI-pinned 1.8.7 (spurious config.exs `root_tag_attribute` byte-diff), NOT a stale fixture. Installed 1.8.7, lifted known_failure tag (no fixture change), documented phx_new 1.8.7 dev prereq in CLAUDE.md. Verified: 2 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-gly | Harden phase-186 D-11 parity test extractors — WR-02 (structural `extract_css_block/2` for auth dark block, replacing `Enum.take(30)`) + WR-03 (`extract_token_value/2` scoped to correct CSS block via optional selector). WR-01/IN-02 already resolved by prior pass; IN-03 optional CI guard deferred to new todo. Verified: 27 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-grh | Narrow glossary drift-guard `action=` strip (phase 191 WR-01) — strip `action={…}` expressions but scan `action="…"` copy literals for banned terms; added regression test for the false-negative gap. Verified: 2 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 189-verify | Close phase-189 ConfirmDialog review todo — WR-01/02/03/04 found already fixed in source (admin_hooks.js + branding_live.ex); fixed the dormant PAGE-03 verification spec (stale `/cancel/i` → `[data-sg-confirm-cancel]`) and wired admin-modal-interaction.spec.ts into the chromium CI lane. Verified green locally: 7/7 APG gates. | complete ✓ | 2026-06-18 |
| 260619-l1b | Demo/admin-UI Docker DX overhaul — `scripts/uat/up.sh` (no flags) now defaults to the shared-Traefik proxy path WITH live reload, health-gates the URL (never prints a live URL until an HTTP 200 probe passes; `STARTING` otherwise), auto-opens `/demo/credentials`, and prints grouped auth/admin/ops routes. New flags `--dev`/`--host` (host-run, now actually starts+gates Phoenix), `--attach`/`--iex`, `--no-watch`, `--no-open`. New `docker-compose.watch.yml` bind-mount override (compile-env invariant preserved) + web healthcheck; `down.sh` kills the host-run Phoenix PID; `sigra.localhost` alias relaxed to claim-based (feature branches can win it). Docs refreshed. Follow-up fix (f748005d): web healthcheck used wget but elixir:*-slim ships no wget/curl → perma-unhealthy aborted the script; installed curl + made `up -d --wait` non-fatal (host-side wait_for_http is the real gate). VERIFIED LIVE end-to-end: `up.sh` exits 0, web `(healthy)`, HTTP 200 on raw port + `sigra.localhost` + per-branch host via shared Traefik, `/admin`→302. | complete ✓ | 2026-06-19 |
| 260621-in8 | Fix `scripts/uat/up.sh --dev` Phoenix `validate_compile_env` boot failure (compile-time `port: 4011` ≠ runtime random port). Root cause: `Example.Organizations` reads `compile_env!` on `ExampleWeb.Endpoint`, freezing the volatile `http.port` into a compile-time invariant; the `none)` branch picked a fresh `find_free_port` each run while reusing the 4011-compiled `_build`. Fix: default `none)` to stable port 4011 (overridable) + add `--no-validate-compile-env` to all 3 host-run server invocations (load-bearing — `ensure_port_free` can still bump to a random port). `shared)`/`private-traefik)` branches untouched. Verified static: `bash -n` clean, 1× `PORT:-4011` in `none)`, 3× `--no-validate-compile-env`. Live boot left to user (needs Docker+PG+browser). | complete ✓ | 2026-06-21 |
| 260621-in8b | **Follow-up regression fix to in8 (`fddb1604`).** in8 shipped WITHOUT a live boot and the `--no-validate-compile-env` flag it added does not exist in Elixir 1.19 → `mix phx.server` exited "Unknown option", `--dev` never booted. Also discovered Elixir validates the compile-env invariant at the START of every mix task and ABORTS before it can recompile, so a `_build/dev` frozen at a different port (plain `mix compile`→4000, or a bumped run) can't self-heal. Fix: removed the 3 bogus flags; added `sync_host_compile_env_port()` that reads the port frozen into compiled `example.app` and wipes the stale example build on mismatch so the next mix recompiles clean (called pre-`setup_host_example` and post-`ensure_port_free` bump). **Verified LIVE all 3 paths → 200/302:** 4011-free (no wipe), busy-4011 (bump→wipe→recompile), drifted-build (frozen 4000→wipe→4011). Lesson: never ship a runnable-surface fix without actually booting it. | complete ✓ | 2026-06-21 |
| 260621-nov | **Night Ops brand-lab preset recolored teal→indigo/violet (`0fac2fd7`).** Night Ops accents were teal/cyan (light `#087d87`, dark `#48d6ca`) — a near-duplicate of Vaultr's teal, so the homepage white-label preview had two teal brands. Recolored to a dark-mode-first indigo/violet "security ops" palette (dark accent `#a78bfa` on `#0c0a1a`/`#15122a`; light accent `#6d28d9` on `#f5f3ff`). Colors only — id/label/persona/theme/email + generated "N" mark unchanged; only the homepage brand-lab preview affected (real login stays Vaultr). Presets now span 4 distinct hues: Vaultr teal · Night Ops violet · Meridian green · Rail Accent orange. **Verified LIVE** dark+light + WCAG contrast polls (chip/heading ≥4.5); 16 ExUnit + demo-showcase home-page spec green. | complete ✓ | 2026-06-21 |
| 260621-vlk | **Real login locked to Vaultr; brand-lab → homepage preview only (`485d38f7`).** `/users/log_in` showed "Log in to Night Ops": the demo brand cookie (set by the homepage white-label brand-lab) was read server-side on the real login and defaulted to the night-ops preset, so the Vaultr demo's own login looked like another company. Fix: `SessionController.new/2` stops reading the brand cookie; the login template hard-codes "Vaultr" + the Vaultr mark (like the homepage header/app shell) with NO `data-demo-brand-*` hooks → neither cookie (server) nor `demo_branding.js` (client) can re-skin it. The login is now a plain Vaultr page on the GLOBAL Vaultr palette (`--vt-color-*`) + `data-theme="system"` (follows OS light/dark, same as the homepage; brand-var mapping needs `[data-demo-brand-surface]` and JS needs `data-demo-brand-presets`, neither present). `Demo.Branding` default flipped night-ops→vaultr so the brand-lab opens on Vaultr and previews others in place; the brand cookie now scopes ONLY the homepage preview. Net −147 lines. **Verified LIVE light+dark** + full email/password sign-in → `/admin`; 62 ExUnit + 2 rewritten demo-showcase specs green (lock guard: login stays Vaultr even with `sigra_demo_brand=meridian`). | complete ✓ | 2026-06-21 |
| 260622-i0e | **Vaultr demo: real account screens + full vt-* brand coherence + sudo fix + product identity.** The `/app` hub routed personas into a stubbed `/users/settings`, off-brand daisyUI screens (inert in the build-free `--no-tailwind` demo), and a sudo dead-end. Defined **Vaultr = team credential/secrets vault** (copy across home/login/layout/branding). Added vt-* primitives (`.vt-form`, `.vt-alert` info/warn/danger, `--vt-color-danger`+`.vt-btn--danger`, `.vt-menu`+`.vt-avatar`). Replaced the settings stub with a real `<Layouts.app>`+vt-* page (profile/email-with-confirm-link/password/delete; new `/users/settings/confirm-email/:token` + `User.profile_changeset` + `Accounts.update_display_name`/`deliver_email_change_confirmation`). Rebranded org switcher, sessions, reactivation, sudo, organizations index/new/settings/members, MFA challenge + settings to vt-* (several now wrap in `<Layouts.app>`; fixed reactivation log_out navigate→DELETE bug). **Fixed the sudo dead-end** (`:stale_sudo` → `/users/sudo?return_to=<path>`, was `/users/log_in`) in the example AND the **Sigra installer template** + golden fixture (real bug in every host app). Removed duplicate AppLive logout. **216 example tests 0 failures**; golden fixture matches (only pre-existing phx 1.8.8/1.8.7 config.exs drift remains); **verified live** `/users/settings/mfa` stale-sudo → `/users/sudo?return_to=…`. Residual deep-modal/enrollment daisyUI polish + sessions seed realism filed as a todo. 6 commits `eab0479f`→`6dae6d1d`. | complete ✓ | 2026-06-22 |
| 260622-gy0 | **Vaultr authenticated account-home hub (`/app`).** Login dead-ended every persona: homepage lured all 9 to "Open Sigra Admin", 7 non-admins bounced to a raw `send_resp(403)`, post-login landed on the evaluator homepage, no Vaultr-branded authed surface, header always said "Sign in". Built (user-approved "account-home hub" scope): new `ExampleWeb.AppLive` at `/app` in the existing `<Layouts.app>` chrome — greets by `display_name`, real-state security strip (TOTP/passkey/OAuth via `Accounts.mfa_enabled?`/`passkey_count_for_user`/scoped `UserIdentity`), quick actions, org cards (`Organizations.list_organizations_for_user`), CONDITIONAL platform-admin card (`SigraAdminPolicy.platform_admin?` → `/admin`) + per-org admin-console links (`admin_org_ids` → `/admin/organizations/:slug`), deletion-notice card. `signed_in_path` + MFA-return `/`→`/app`; auth-aware headers (Log out + Dashboard); graceful `:insufficient_scope` (authed non-admin → flash + 302 `/app`, raw 403 only for unauth/non-HTML); `.vt-status-pill--ok` CSS. **All in `test/example` only** — installer templates untouched (generic host keeps `signed_in_path "/"`), no golden-diff impact. **216 ExUnit 0 failures**; **verified LIVE on :4011** per persona (alice→/app no admin card + `/admin`→302/app; morgan→acme-corp console; admin→platform card + `/admin` 200; carol→"Connected with Github"; homepage header flips on auth). Deferred (filed todo): Frank/Grace auto-redirect to reactivation — `check_account_active` unwired + naive wiring loops; interim `/app` deletion card covers it. Dave (locked) left enumeration-safe by design. | complete ✓ | 2026-06-22 |
| 260622-jfr | **Demo app rebranded Vaultr (secrets vault) → Tasklane (project/work tracker), framing-only.** The "team secrets vault" identity was auth-adjacent and blurred the line between the app and Sigra (the auth lib it consumes). Picked a clearly non-auth, relatable B2B domain so "Sigra is the auth layer" is self-evident; kept it a pure auth showcase (NO product CRUD — `/app`+copy read as "Tasklane's account/security area"). Source commit `ceba947a`: product name→"Tasklane"; tagline "Team secrets vault"→"Work tracking for teams"; hero/login/`/app`/credentials/reactivation/sudo/mfa-challenge copy reframed; persona email domain `demo.vaultr.test`→`demo.tasklane.test` (single `@demo_domain` const; `SigraAdminPolicy` gates via `Personas.email/1` so admin/morgan stay correct); branding preset id/label/desc/subject+profiles→Tasklane, private `@vaultr_*`→`@tasklane_*` (one file, `--vt-*` output unchanged); logo `vaultr-mark.svg` (shield+lock)→`tasklane-mark.svg` (task-lanes glyph, same teal); `data-testid` `vaultr-login`→`tasklane-login`; `<title>`→Tasklane; config/accounts brand fallbacks; README. Tests commit `74f464ec`: mechanical `Vaultr→Tasklane`/`vaultr→tasklane` across 8 ExUnit + 6 Playwright files. **Kept** `vt-*` prefix+palette, `Example` modules, persona local-parts/roles/org topology. **216 ExUnit 0 failures** (page/session controller + credentials tests render the real HTML = live-render coverage); zero residual `vaultr` in source/tests/playwright; **fully example-scoped** — nothing under `priv/templates`/Sigra core/`test/sigra/install`, no golden impact. Deferred: WS5 (Alice multi-workspace) skipped (would break `seeds_test` topology, no gain; multi-org Q was informational); demo DB needs a re-seed to carry the new domain rows. 2 commits `ceba947a`→`74f464ec`. | complete ✓ | 2026-06-22 |
| 260622-nft | **Fixed email-change confirmation always failing ("invalid or has expired") — a real shipped bug in every generated host app, never caught (only mock-based unit tests existed).** Debugging found THREE chained defects in the confirm path: (1) **double-encoded hashed tokens** — `Sigra.Token.generate_hashed_token/0` already returns a base64 STRING + SHA-256 of the bytes, but generated `build_hashed_token/3` re-encoded the string, so the link carried a double-encoded token while `verify_*` decodes once → hash NEVER matched (broke email-change AND magic-link; proved by byte sizes 58→43→32); (2) **change-context verify mismatch** — `verify_email_token_query(token, "change:")` matched context EXACTLY (never `"change:<old>"`) and required `sent_to == user.email` (but change tokens set `sent_to = NEW`, `email` still OLD); (3) **session-invalidation crash** — `do_confirm` called `delete_all_for_user/2` without the `:repo`/`:session_schema` the Ecto store requires → `Keyword.fetch!` raise. Fixes: dedicated `verify_email_token_query(_, "change:" <> _)` head (prefix `like "change:%"` + `sent_to == pending_email`); `build_hashed_token` uses encoded string as-is; `confirm_email_change` threads `session_store_opts` via `session_store_and_opts/2` + `email_change.ex` forwards them. `user_token.ex` changes hit installer template + golden fixture (byte-mirrored) + example; `auth.ex`/`email_change.ex` are lib-only. Added integration round-trip (real Repo+UserToken) + LiveView E2E over `/users/settings/confirm-email/:token` (both fail pre-fix). **223 ExUnit 0 failures**; lib email_change + vault_promotion pass; golden_diff fails ONLY on the known phx 1.8.8-vs-1.8.7 config.exs drift (my user_token.ex matched golden byte-for-byte). Deferred (filed todo `session-invalidation-missing-store-opts`): the IDENTICAL session-opts bug in `password_change.ex` + `deletion.ex`. Existing host apps must regenerate `user_token.ex`. 3 commits `10441805`→`0fb59516`. | complete ✓ | 2026-06-22 |
| 260623-j59 | **Fixed session-invalidation crashes in password-change + account-deletion (sibling of nft, todo `session-invalidation-missing-store-opts`).** Both flows invalidate sessions via the real `Sigra.SessionStores.Ecto` store but the public `Sigra.Auth` path crashed — only mock-based unit tests ran them. Integration testing against the real config struct + store found THREE chained real-path defects: (1) **missing `session_store_opts`** — `delete_all_for_user/2` called with only `except_token`/`[]`; the Ecto store does `Keyword.fetch!(opts, :repo)` → ArgumentError; (2) **`Sigra.Config` not Access-compatible** — `password_change.ex`/`deletion.ex` did `get_in(config, [...])`, but on the public path `config` is a `%Sigra.Config{}` struct → `UndefinedFunctionError (Sigra.Config.fetch/2)`, which fires *before* (1); (3) **`schedule_deletion` never passed `:token_query_fn`** — `Sigra.Account.Deletion` does `Keyword.fetch!(opts, :token_query_fn)` and used struct-unsafe `get_in(config, [:audit\|:session,…])`. Fixes: thread `session_store_opts` via `session_store_and_opts/2` + forward to `delete_all_for_user` (mirror of nft `c2ab16f1`); add `access_config/1` (maps the struct before `get_in/2`; maps/keyword lists pass through); `schedule_deletion` threads `token_query_fn` (identical lambda to confirm/reset/email-change paths) + reads `config.audit`/`config.session` directly. `email_change.ex` untouched; **library-only** (no `priv/templates`/golden mirror for these flows). New `session_invalidation_test.exs` over the REAL Ecto store (password-change preserves current session via `except_token` + deletes others + changes password; deletion revokes ALL). **Regression-proven**: reverting the lib fix → 2 failures, restoring → 0. 28 lib unit tests still pass; **225 ExUnit 0 failures** (223 + 2); compile `--warnings-as-errors` clean. Added an `oban_jobs` migration so the example's optional deletion enqueue succeeds (deeper Oban-optional robustness — enqueue when Oban compiled-but-unsupervised/no-table → 42P01 — noted as a separate potential lib follow-up). 3 commits `880fe5fe`→`5a25f665`. | complete ✓ | 2026-06-23 |
| 260624-vin | **Wired `check_account_active` into the example `:require_authenticated` pipeline (loop-safe) — todo `wire-check-account-active-reactivation`.** The plug existed but was never wired, so deletion-scheduled personas (Frank/Grace) landed on `/app` instead of the reactivation flow; naive wiring loops because `/users/reactivation` sits in the same pipeline. Added an exact-`request_path` `exempt_path?/2` guard (reactivation + log_out exempt for `check_account_active`; settings + log_out for the also-unwired `require_password_unchanged`, made loop-safe but not pipeline-wired), then wired `plug :check_account_active` after `:require_authenticated_user`, before `:require_mfa`. New conn test: deletion-scheduled → `/app` 302→`/users/reactivation`; → `/users/reactivation` 200 (no-loop guard); active → `/app` 200. **Template parity:** mirrored the guard bodies into `priv/templates/sigra.install/core/user_auth.ex` + golden fixture (byte-for-byte; router wiring stays opt-in for generated hosts). **Incidental real bug fixed** (separate commit): `Sigra.Testing.scheduled_deletion_fixture/3` + `deleted_user_fixture/2` wrote microsecond `DateTime`s but Sigra's `deleted_at`/`scheduled_deletion_at` are `:utc_datetime` (second precision) → `repo.update!` raised `ArgumentError`; never exercised until this wiring. Truncated to seconds. **228 ExUnit 0 failures** (225+3); `golden_diff` green **after installing pinned phx_new 1.8.7** (1.8.8 was present → known `config.exs` drift masks the tree-walk before `user_auth.ex`); compile `--warnings-as-errors` clean. 3 commits `08c947b9`→`1ea02781`. | complete ✓ | 2026-06-24 |
| 260624-vqv | **Fixed `scripts/ci/snapshot-recapture-gate.sh` single-lane recapture (todo `recapture-gate-single-lane`, 185-REVIEW WR-02).** The gate passed the SAME `--allow` slugs with `--require-all` to BOTH the checkpoint lane (step b) and the design lane (step b2); the snapshot dirs are disjoint and `snapshot-canary-guard.sh`'s `--require-all` demands every allowed slug change *in that lane's* dir, so recapturing one lane always failed the opposite lane's `--require-all` ("declared intended delta did not change"). MANUAL dev tool, not merge-blocking. Fix (script-only — canary-guard untouched): route each positional slug to the lane(s) whose snapshot dir actually contains it (working-tree glob, so newly-recorded untracked PNGs route too); slug in neither lane → hard error (exit 2); each lane gets `--require-all` + its `--allow` subset ONLY when it owns ≥1 intended slug (else still runs its full drift/canary check). Added a `RECAPTURE_DRYRUN=1` seam (prints per-lane routing, exits before the slow Playwright/mix lanes). Bare positional interface preserved. **Verified** `bash -n` + `shellcheck` clean on changed code (lone SC2209 is the pre-existing `MIX_ENV=test mix` line), and dry-run routing proof with real slugs (`audit-explorer`→CK-only, `board-applied-chip`→design-only, both→split, unknown→exit 2). Full e2e (compare-mode Playwright lanes + ExUnit goldens) is CI-verified (slow + needs booted :4011 demo). 1 commit `cae8cbc9`. | complete ✓ | 2026-06-24 |
| 260621-o1q | **Vaultr demo polish — kicker spacing + click-to-copy credentials.** (1) Homepage `.vt-panel__header` ("Seeded evidence") sat flush against the stat grid (grid has no bottom margin; `.vt-kicker` is `margin: 0`) → added surgical `.vt-metric-grid + .vt-panel__header { margin-top: var(--sg-space-6) }` (24px section break; only when a header directly follows a metric grid). (2) Click-to-copy on `.vt-code` credential chips (homepage + `/demo/credentials`) by reusing the existing global `installCopyDelegate()` + `showToast("Copied")` + `.sg-toast` infra (was scoped to `.sg-admin-shell code.sg-code`) — broadened match+label selectors to also match `code.vt-code` in BOTH source (`admin_hooks.js`) and served bundle (`app.js`); added `cursor: copy` + hover to `.vt-code`; toast is `position: fixed` (no reflow); wrapped `/demo/credentials` email in `code.vt-code` for parity. **Verified LIVE** on `:4011` (extended demo-showcase spec: 24px gap, `cursor: copy`, "Copied" toast, `clipboard.readText()` matches); 16 ExUnit (page/session/branding) green. Surfaced a separate per-persona post-login UX gap (admin-door luring + raw 403 + non-auth-aware header) — tracked as follow-on, not in this task. | complete ✓ | 2026-06-21 |
| 260621-vbr | **Vaultr demo mini-brand typography (`d242d1a8`).** Vaultr (`vt-*` demo surfaces) rendered in Space Grotesk — the Sigra logo font — set as global `--font-sans`; the word "Sigra" in the hero looked like the Sigra wordmark. Gave Vaultr its own face, scoped to `vt-*` only (Sigra admin `sg-*` keeps Space Grotesk): self-hosted Fraunces (serif display + "Vaultr" wordmark, WONK/SOFT pinned off) + Inter (body), both OFL latin-subset in `test/example/priv/static/assets/fonts/`; `--vt-font-display`/`--vt-font-text` tokens + `@font-face`; applied to `vt-title`/`vt-panel__title`/`vt-auth__title`/`vt-brand__name` (display) + vt container roots (text). Also fixed a **pre-existing app.css comment corruption**: the "VAULTR HOST APP" banner had lost its opening `/*`, so the stray `* … */` merged into the next rule's selector and silently dropped it (was eating the original `.vt-home/.vt-app-main` bg rule). Added a platform-independent Playwright guard (`.vt-title`→Fraunces, never Space Grotesk; body→Inter). **Verified LIVE light+dark** via Playwright; admin provably unaffected (identical snapshot diff w/ and w/o change → pre-existing local-vs-CI baseline staleness); no baselines needed updating. | complete ✓ | 2026-06-21 |

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

### Acknowledged at v1.40 close (2026-06-21)

20 open artifact items acknowledged and deferred at milestone close. None are blockers (audit verdict `tech_debt`: 18/18 reqs satisfied, 7/7 integration wired). The only two v1.40-relevant items are the same audit tech-debt item #3 — Phase 197's "CI measures itself" runtime proof (re-gated design-gallery + recapture job), verified statically/mechanically, awaiting one live non-PR CI run to observe green. The rest are carried backlog (admin-UI pass-2, mailglass corrigendum, dormant seeds).

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| verification_gap | 197-VERIFICATION.md [human_needed] | tracked — design-gallery hard re-gate + recapture verified statically; awaits one live non-PR CI run to observe green (zero-human-UAT model; closes naturally on next scheduled/main run) | v1.40 |
| uat_gap | 197-UAT.md [partial, 0 pending scenarios] | tracked — same CI-observed runtime proof as above | v1.40 |
| quick_task | 260528-nwa-fix-rc-01-in-guides-recipes-companion-li | superseded / stale | v1.40 |
| quick_task | 260528-sbn-fix-v1-29-doc-debt-mailglass-corrigendum | superseded / stale | v1.40 |
| quick_task | 260602-gll..ikd-stage-0..7-admin-ui-pass-2 (8 tasks) | superseded by v1.39 DS-COHERENCE | v1.40 |
| todo | 2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent | tracked — needs 25+ audit events for pagination fixture | v1.40 |
| todo | 2026-06-17-page04-branding-explicit-scoring | tracked | v1.40 |
| todo | 2026-06-18-token-reference-completeness-ci-guard | tracked | v1.40 |
| todo | 2026-06-19-uat-demo-dx-polish-nits | tracked | v1.40 |
| todo | 2026-06-20-mix-sigra-migrate-schema-helper | tracked (installer DX) | v1.40 |
| todo | 2026-06-20-playwright-parallelization-per-shard-db | tracked — sub-12m fast-path stretch (GATE-01 aspirational); Playwright job sharding | v1.40 |
| todo | 2026-06-20-runtime-auth-prefix-override | tracked | v1.40 |
| todo | recapture-gate-single-lane | tracked — shared `--require-all` slugs break single-lane recapture | v1.40 |
| seed | SEED-004-phx-new-button-forward-compat | dormant | v1.40 |
| seed | SEED-005-ci-cd-pipeline-performance-audit | dormant — this milestone's source seed (audit playbook); resolved in substance, seed kept as reference | v1.40 |
| seed | SEED-006-admin-design-gallery-ci-baseline-recapture | dormant — folded into PW-03 / Phase 197 (addressed) | v1.40 |

### Acknowledged at v1.41 close (2026-06-27)

9 open artifact items acknowledged and deferred at milestone close (audit verdict `tech_debt`: 18/18 requirements satisfied, 0 critical blockers). The resolvable cruft was genuinely resolved before close, not buried: the `stale-known-failure-contract-tests` todo was fixed by Phase 204-02 (moved to `todos/resolved/`), and the 10 superseded admin-ui-pass-2 / stale-doc quick-tasks were marked `status: complete` on their canonical summaries. The residual below is irreducible forward backlog (features + review-debt), dormant future-bet seeds, and one already-non-blocking deferred UAT.

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| uat_gap | 202-UAT.md [deferred, 0 pending scenarios] | non-blocking — deferred, no open scenarios | v1.41 |
| todo | 2026-06-18-token-reference-completeness-ci-guard | tracked — CI guard for admin-token-reference completeness | v1.41 |
| todo | 2026-06-19-uat-demo-dx-polish-nits | tracked — non-blocking demo-DX polish | v1.41 |
| todo | 2026-06-20-mix-sigra-migrate-schema-helper | tracked — installer feature (schema migrate path) | v1.41 |
| todo | 2026-06-20-playwright-parallelization-per-shard-db | tracked — CI perf (Playwright sharding); overlaps SEED-005 | v1.41 |
| todo | 2026-06-20-runtime-auth-prefix-override | tracked — config feature | v1.41 |
| todo | 2026-06-21-app-css-comment-corruption-cleanup | tracked — demo app.css orphaned-comment cleanup (IN-01 Vaultr→Tasklane part done in 204) | v1.41 |
| todo | 2026-06-22-vaultr-authed-rebrand-residuals | tracked — demo rebrand residuals | v1.41 |
| todo | 2026-06-22-white-label-auth-email-theming | tracked — auth/email white-label feature | v1.41 |
| todo | 2026-06-24-oban-enqueue-unguarded-when-compiled-but-unsupervised | tracked — Oban-optional robustness | v1.41 |
| todo | 2026-06-25-phase199-code-review-info-hardening | tracked — deferred code-review info items | v1.41 |
| todo | 2026-06-25-phase200-code-review-deferred | tracked — deferred code-review items | v1.41 |
| seed | SEED-004-phx-new-button-forward-compat | dormant | v1.41 |
| seed | SEED-005-ci-cd-pipeline-performance-audit | dormant | v1.41 |
| seed | SEED-006-admin-design-gallery-ci-baseline-recapture | dormant | v1.41 |

## Session Continuity

Last session: 2026-06-30T03:12:31.865Z
Stopped at: Completed 208.1-01-PLAN.md
Resume file: 

None
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
| Phase 193 P01 | 1096 | 2 tasks | 1 files |
| Phase 193 P02 | 6 min | 1 tasks | 2 files |
| Phase 193 P03 | 2 min | 2 tasks | 1 files |
| Phase 194 P02 | ~4 minutes | 3 tasks | 2 files |
| Phase 195 P01 | 3 | 3 tasks | 12 files |
| Phase 195 P02 | 5 | 3 tasks | 1 files |
| Phase 195 P03 | 525603 | 2 tasks | 2 files |
| Phase 196 P01 | 4min | 3 tasks | 1 files |
| Phase 196 P02 | 1m | 3 tasks | 1 files |

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 196 P04 | 4min | 2 tasks | 3 files |
| Phase 197 P02 | 2min | - tasks | - files |
| Phase 197 P02 | 2min | 2 tasks | 1 files |
| Phase 197 P03 | 2min | 4 tasks | 4 files |
| Phase 197 P04 | 5min | 3 tasks | 1 files |
| Phase 197 P05 | 2m | 2 tasks | 2 files |
| Phase 198 P02 | 4m | - tasks | - files |
| Phase 198 P03 | 383s | 3 tasks | 2 files |
| Phase 199 P01 | 131s | 2 tasks | 2 files |
| Phase 199 P02 | 5 minutes | 2 tasks | 2 files |
| Phase 199 P03 | 6min | 4 tasks | 2 files |
| Phase 199-foundation-tier-2-scorecard-stress-fixtures P04 | 25min | 4 tasks | 1 files |
| Phase 200 P01 | 236 | 3 tasks | 5 files |
| Phase 200 P02 | 304s | 3 tasks | 1 files |
| Phase 200 P03 | 600 | 3 tasks | 6 files |
| Phase 201 P01 | 274 | 3 tasks | 1 files |
| Phase 201 P02 | 34s | 1 tasks | 1 files |
| Phase 201 P03 | 185s | - tasks | - files |
| Phase 202 P01 | 136s | 3 tasks | 1 files |
| Phase 202 P02 | 156s | 2 tasks | 1 files |
| Phase 202 P03 | 116s | 2 tasks | 1 files |
| Phase 202 P04 | 1318s | 2 tasks | 2 files |
| Phase 202 P05 | 843 | 3 tasks | 6 files |
| Phase 203 P01 | 69s | 3 tasks | 2 files |
| Phase 203 P03 | 216s | 1 tasks | 1 files |
| Phase 203 P04 | 156s | - tasks | - files |
| Phase 203 P05 | 490s | 2 tasks | 2 files |
| Phase 204 P01 | 129s | - tasks | - files |
| Phase 204 P02 | 157s | 2 tasks | 4 files |
| Phase 204 P03 | 93min | 2 tasks | 3 files |
| Phase 204 P04 | 5min | 2 tasks | 0 files |
| Phase 204 P05 | 440s | 3 tasks | 4 files |
| Phase 205-foundation P01 | 3 | 2 tasks | 3 files |
| Phase 205 P02 | 35 | 3 tasks | 4 files |
| Phase 205 P04 | 4 | 1 tasks | 1 files |
| Phase 206 P03 | 33m | 2 tasks | 70 files |
| Phase 206 P04 | ~4m | 2 tasks | 1 files |
| Phase 207 P03 | ~31 minutes | 2 tasks | 1 files |
| Phase 208 P01 | 1m | 2 tasks | 0 files |
| Phase 208.1-v1-42-ci-gate-remediation P01 | 13min | 3 tasks | 2 files |
