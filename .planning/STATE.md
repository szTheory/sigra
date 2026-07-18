---
gsd_state_version: 1.0
milestone: v1.45
milestone_name: RELEASE-CURRENCY
status: Awaiting next milestone
stopped_at: Phase 223 context gathered (assumptions mode)
last_updated: "2026-07-11T01:32:45.037Z"
last_activity: 2026-07-11 — Milestone v1.45 completed and archived
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 11
  completed_plans: 9
  percent: 67
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Between milestones — v1.45 closed 2026-07-11 (override_closeout; Phase 223 deferred pending operator Hex retire). Start next via `/gsd-new-milestone` (phases continue from 224).

## Current Position

Phase: Milestone v1.45 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-07-18 — Completed quick task 260718-i1m: demo front-door get-started affordance + copy-scope fix

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
- [Phase ?]: OQ1: board-notice canary re-established as 'added' via pre-delete before --update-snapshots=all + restore canary/unchanged slugs; notice/1 wraps slot in <p>
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
- [Phase 208.1-02]: admin-user-operations 'No active sessions': getByText(exact:true) prevents substring match on inner slot text triggering strict-mode 2-element resolution
- [Phase 208.1-02]: admin-modal-interaction Phase 200 D-04 routing: navigate to sessions page via 'Manage sessions' before asserting 'Revoke session' button
- [Phase 208.1-02]: Sudo heading reconciled to 'Re-enter your password' across installer template + impersonation.spec.ts + admin-generated.spec.ts
- [Phase 208.1-02]: admin-audit: open 'More filters' disclosure + scope to desktop results pane + assert 'Session Create' pill not hidden event code inside closed details disclosure
- [Phase ?]: Boot prelude cloned verbatim from admin_design_recapture for checkpoint recapture job — no divergence between design and checkpoint lane boot sequences (Phase 209-01)
- [Phase ?]: D-10 part 2: delete impersonation-banner-admin-checkpoints-*.png before recapture so canary re-establishes as 'added' not 'modified' — preserves WCAG contrast fix (Phase 204-03) without allowlisting the canary (Phase 209-01)
- [Phase ?]: [Phase 209-02]: All 8 admin surfaces scored actionable in persona-JTBD panel (no kill/blocked); all findings tighten remediable in-place
- [Phase ?]: [Phase 209-02]: audit-user-live Effective-user absence is documented defensible asymmetry — waiver-track, not kill; per-user audit is already subject-scoped
- [Phase ?]: [Phase 209-02]: Panel roll-up kill/tighten counts as none/xN notation — prevents false-matching quality-ledger monotonic guard column-4 awk pattern
- [Phase ?]: Replace 'All clear' with 'No flagged accounts' on both Overview pages for cross-page coherence
- [Phase ?]: Remove Total-users summary chip from Global Overview; Users-List strip is the single owner (Plan 03 dedup)
- [Phase ?]: Waiver for org members action-link: admin overview is read-only, no admin invite route per D-06/OQ-1
- [Phase ?]: Remove sessions count from user-detail header dl; sessions count kept in Sessions card sub-heading only (209-04)
- [Phase ?]: Raise Manage sessions to sg-btn--primary; no confirm overlay added to user-detail page (stays on UserSessionsLive per UI-SPEC) (209-04)
- [Phase ?]: User Sessions kicker changed to Sessions; H1 now interpolates entity name matching user_show_live/audit_user_live siblings (209-04)
- [Phase ?]: Revoke copy: reassurance clause removed; security-remediation framing conveys consequence + reversibility per T-209-04-01 (209-04)
- [Phase ?]: scope_copy/1 added to branding_live as single-clause always-global helper; resolves NEW-2 architectural inconsistency (209-04)
- [Phase ?]: canary re-designation: impersonation-banner 'modified' vs origin/main due to Phase 204-03 WCAG fix; Plan-01 CI job resolves post-merge; WCAG fix preserved, canary not allowlisted (209-06)
- [Phase ?]: user-sessions content-equivalence is N/A (scope-safe control table, not desktop-table to mobile-card pattern per D-03)
- [Phase ?]: flow-* L4 citation resolves to v1.42-PERSONA-JTBD-PANEL.md roll-up plus per-surface docs for each lens entry-point; no net-new per-flow doc needed (D-04)
- [Phase ?]: Folded 208-03 mg-* L2 group flip: all 11 rows at bare Tier 2 with rich evidence; SC-4 achieved — whole L0-L4 fractal at Tier 2
- [Phase ?]: D-02a mechanism (ii) confirmed: prove snapshot/canary idempotency vs HEAD in-phase; origin/main canary reconciliation (5 stale checkpoint slugs + WCAG-fixed impersonation-banner) is integration-merge (PR #63) hand-off
- [Phase ?]: phx_new 1.8.7 pin (SEED-004) corrected before GATE-02 lane; do NOT regenerate golden fixture to absorb 1.8.8 diff
- [Phase ?]: GATE-02 smoke requires explicit PGPORT=5432 when tmp/db.env exports PGPORT=58915; generated host uses system Homebrew Postgres (5432), not Docker test Postgres (58915)
- [Phase ?]: No installer-template drift found in Phase 211-02 GATE-02 smoke; priv/templates/sigra.install/ byte-stable vs test/example/
- [Phase ?]: NoopTest flake is a parallel-shard log-capture race (not a regression): lean documented-known per Claude's Discretion (D-05); no determinism fix applied
- [Phase ?]: Full-suite terminal gate: 2403 tests, 2 Sigra.UpgradeIntegrationTest env-DB failures in D-05 accepted set; no new regression
- [Phase ?]: phase_192_known_failure_contract_test.exs correctly absent (deleted in 204-02); phase_148 4 tests re-confirmed green (D-08 re-confirm only)
- [Phase ?]: phx.new 1.8.8 is the pin target for Phase 213 (confirmed current latest via mix hex.info phx_new at execution)
- [Phase ?]: COMPAT-01 satisfied with zero code changes: fresh phx.new 1.8.8 host compiles clean under --warnings-as-errors (D-02 verified)
- [Phase ?]: Golden fixture delta under phx_new 1.8.8: 3 files changed (config.exs root_tag_attribute block + HexDocs URL format in application.ex and layouts.ex); D-05 guard NOT triggered
- [Phase ?]: Pin target for phx_new archive is concrete 1.8.8 (D-07)
- [Phase ?]: D-06 rebless_golden --check drift-detector wired in install_golden_contract as a hard gate
- [Phase ?]: COMPAT-03 satisfied: generated host admin Playwright chrome slice passes (1/1) against phx_new 1.8.8
- [Phase ?]: [Phase 214-01]: Process.register(dummy, Oban) pattern used in deletion_test.exs to simulate Oban supervision for the enqueue test
- [Phase ?]: D-08: user_id guard in delete_session/3 protects all callers at library layer without changing @callback delete/2 signature
- [Phase ?]: D-11: session_type/activity_value/relative_activity/pluralize promoted to Sigra.Admin.Components; scope_copy/1 kept as defp (context-specific copy text)
- [Phase ?]: DEBT-05: app.css orphaned sg-* value fragments deleted from :root; CI guard (app-css-corruption-check.sh) wired into fast_checks; browser-parse verified with Playwright (334 rules, --vt-color-ink resolved)
- [Phase ?]: Config-DB approach (D-18): Chimeway.Repo configured in config/test.exs using SIGRA_TEST_PG_* env vars
- [Phase ?]: Conditional :upgrade exclusion (D-19/D-20): phx_new_ok? check before ExUnit.start() in test_helper.exs
- [Phase ?]: DEBT-02 D-05: panel-schema-check.sh retired in-place with RETIRED banner; inputs are frozen v1.42 milestone deliverables that cannot be corrupted by future development
- [Phase ?]: DEBT-04 D-13: git tag v1.20.0 deleted local and remote; contract.md line 9 corrected to 1.1.0
- [Phase ?]: DEBT-04 D-14: mix hex.retire sigra 1.20.0 is a manual runbook step for Jon - documented in 214-05-SUMMARY.md
- [v1.44 INVARIANT]: The merge-blocking forward-only signal stays 100% deterministic (monotonic ledger guard, snapshot-canary, axe, token/contrast gates). The LLM panel is an issue-finder + judge-of-taste only — never a CI gate, never flips a ledger cell.
- [v1.44 INVARIANT]: Cite-and-flip is impossible by construction — evaluator receives only render bundles; finding anchor must exist in captured DOM.
- [v1.44 DECISION]: Forward gradient = verify-then-climb: harness first re-verifies existing Tier-2 claims against rendered output, then climbs via a new finer-grained award sub-score above the Tier-2 ceiling.
- [v1.44 DECISION]: Auto-fix scope = provably-safe mechanical classes only (copy / token-swap / component-swap); per-fix auto-revert on regression; judgment fixes route to human queue.
- [Phase ?]: 216-01 dep legitimacy gate
- [Phase ?]: 216-01 dep legitimacy gate
- [Phase ?]: 216-01 D-10 base-ref fix
- [Phase ?]: test decision
- [Phase ?]: Award band floor A0 on all axes at phase 216-02 start; climbing happens only against fresh render in Plan 07
- [Phase ?]: render_sha256 and open_findings consolidated in admin-render-sha.json as single authoritative source per D-21 (216-02)
- [Phase ?]: finding_id = sha256(surface NUL class NUL anchor) locked as 216 substrate key; Phase 217 AUTOFIX-01 must match — seam flagged UNRESOLVED per D-22 (216-02)
- [Phase ?]: Tier column-4 grammar frozen; award data in JSON sibling admin-award-ledger.json only; no 5th column, no decorator per D-19 (216-02)
- [Phase ?]: Allowlist canonicalization: KEEP_ATTRS plus class-sorted plus href-fingerprint-stripped; id always dropped
- [Phase ?]: Geometry excluded from renderSha256 entirely (not bucketed) - stored in bundle.facts only per D-06/D-11
- [Phase ?]: quality-findings-monotonic.sh uses node -e to parse admin-render-sha.json — avoids jq dep, keeps bash-guard idiom (216-04)
- [Phase ?]: skip-on-empty-base divergence (D-08/D-21): skip ONLY when ledger file absent; increase from 0 IS a regression (216-04)
- [Phase ?]: evidence-anchor-check.mjs resolves cheerio via createRequire from playwright subproject — no duplicate install (216-04)
- [Phase ?]: isStructuralAnchor rejects prose before cheerio: starts with ./#/[/: or single lowercase tag not followed by uppercase prose (216-04)
- [Phase ?]: eval-probe-ids.mjs is the single source of the nine canonical probe ids shared by award-guard and Plan 06 probes.ts (D-12 anti-drift)
- [Phase ?]: award-guard recomputes band=min(axes) — never trusts the typed band; FAILs on climb-without-render, band!=min, unresolved-evidence, and axis-decrease (D-20)
- [Phase ?]: resolveEvidenceRef defers test: and conformance: to prefix-only validation until Plans 06/07 populate those registries (intentional seam)
- [Phase ?]: probes.ts reads live --sg-* via getPropertyValue, never duplicated constant table
- [Phase ?]: admin-eval.spec.ts uses __dirname not bundle.ts import.meta.url for CJS/ESM Playwright compat
- [Phase ?]: stale-render-guard absence=FAIL (not skip), git plumbing only never mtime D-07/D-08
- [Phase ?]: board-scoped probes fix Gap 1; D-22 finding enrichment; W1 anchor-check fix
- [Phase ?]: .planning/phases/216-harness-foundation-award-gradient/216-09-SUMMARY.md
- [Phase ?]: .planning/phases/216-harness-foundation-award-gradient/216-09-SUMMARY.md
- [Phase ?]: 217-04
- [Phase 217]: fix-queue-build.mjs is sole open_findings writer in admin-render-sha.json (D-12 — eliminates two-producer drift)
- [Phase 217]: Systemic collapse: same (class,anchor) on >=2 board surfaces collapses to ONE high-priority parent in fix-queue.json
- [Phase ?]: Use grep -c not grep -q in bash CI scripts to avoid SIGPIPE under pipefail
- [Phase ?]: panel-forced-floor-check.mjs reads JSON only; self-tests attach to fast_checks, checker not wired over live panel output
- [Phase ?]: excerpt.mjs retains ALL class tokens for full anchor validation coverage
- [Phase ?]: Token-swap +/-1.0px band: tighter than probe detection, ties/far downgrade to judgment
- [Phase ?]: Copy-swap is text-node-only from fixed copy-rules.json; semantic judgment refused
- [Phase ?]: git revert --no-edit HEAD creates new commit on any rail trip; SC-4 proves reflog clean
- [Phase ?]: eval/autofix-state.json gitignored; admin-autofix-loop.sh never wired into CI (panel-ci-isolation proves it)
- [Phase ?]: admin-panel.sh degrades to exit 0 on missing ANTHROPIC_API_KEY — structural JUDGE-CI-01 guarantee
- [Phase ?]: SC-2/SC-4 live verifications deferred to human checkpoint — require real ANTHROPIC_API_KEY
- [Phase ?]: [218-01]: D-08 path: deep-equal drift check via readFileSync parse of eval-probe-ids.mjs
- [Phase ?]: [218-01]: L3 proxy mapping: index-live=mg-1, organization=mg-7, user-sessions=mg-11, audit-index/user=mg-6, branding=mg-4
- [Phase ?]: [218-01]: proxy:true structural skip in fix-queue-build.mjs step (j) — Plan 02 can safely run the builder
- [Phase ?]: vt-modal authored as dialog.vt-modal with sg-*/vt-* tokens; native dialog::backdrop uses color-mix overlay; phx-hook=DialogModal preserved
- [Phase ?]: mfa_challenge_controller.ex + mfa_challenge_html.ex confirmed dead code (router wires /users/mfa to MFAChallengeLive only); both removed
- [Phase ?]: [218-02]: verified_at_sha updated to 1f54de17 for all 32 cells; users-index-live A2 and user-show-live A1 HOLD (admin source unchanged since eeb6bf14)
- [Phase ?]: [218-02]: All new L1/L2 board award cells set at A0 rendered:false — honest floor; server not available for fresh render; raises deferred to Plan 06 after Plan 219 harness re-run
- [Phase ?]: verified_at_sha updated to 221f5615 for all 8 L3 cells; admin source unchanged between 1f54de17 and HEAD; all cells HOLD without correction
- [Phase ?]: No L3 award sub-score raised in 218-03; all raises deferred to Plan 06 after Plan 219 delivers clean-tree HEAD eval bundles (D-05 honesty-first)
- [Phase ?]: 218-06: Operator decision (verify-hold, 0 raises, panel deferred to Phase 219) resolved Task 1; PR #70 (elevate-03-wave-v144-pr -> main) assembled via gsd-pr-branch covering the full unshipped v1.44 elevation wave (216-218), 120 commits, 0 transient .planning leakage
- [Phase ?]: 218-07: Systemic-parent rep selection is lowest finding_id (localeCompare-minimum), not entries[0] — removes readdirSync order dependence (CR-01)
- [Phase ?]: 218-07: Also sorted walkFindings readdirSync walks (sha/surface/cell) as belt-and-suspenders alongside the rep fix
- [Phase ?]: 218-07: Did NOT regenerate guides/reference/fix-queue.json — eval bundle source dir is gitignored; determinism proof is hermetic-only, forward-only fix applied at next full-harness regen (Phase 219)
- [Phase ?]: Placed probeIdsDriftCheck() in a module-level test.beforeAll (outside test.describe) so the guard runs before the describe/beforeEach and needs no page fixture or live server.
- [Phase ?]: Substituted the plan's tsc --noEmit verify command with npx playwright test --list plus a path-resolution check because test/example/priv/playwright has no tsconfig.json or typescript install and no CI job runs tsc against it.
- [Phase ?]: 218-09: WR-01/WR-02/WR-03 mirrored byte-identically into installer templates (verified via diff/grep) so generated hosts do not ship the same crash/silent-no-op bugs; WR-04/WR-07 stay example-only (templates use Tailwind/daisyUI, not vt-* tokens)
- [Phase ?]: 218-09: WR-03 uses a flash-on-miss fallback instead of a new Organizations.get_member-by-id context function, to avoid widening library surface; the by-id scoped fetch is recorded as a follow-up
- [Phase ?]: 218-10: Ran two separate docker ps -a invocations (one per proxy-host label) combined with sort -u, mirroring the proxy_host_claimants precedent, since Docker CLI --filter ANDs multiple label filters within one query
- [Phase 219]: Fixed the durable/recurrence-proof way (:global attr + {@rest} spread on icon/1) per D-02, instead of stripping the inline style= from the two mfa_settings_live.ex call sites.
- [Phase 219-02]: D-04 recapture_branch relaxation checked BEFORE the refs/tags/v* case in release_ref_guard — recapture-only, tag path unchanged for every other dispatch
- [Phase 219-02]: D-03.1 demo-showcase recapture folded into admin_checkpoint_recapture (cheapest — already boots :4000), no canary/allowlist choreography needed
- [Phase 219-02]: D-03.2/D-05 checkpoint job converted from human-visual-review-only to self-gated snapshot-canary-guard.sh commit step, mirroring the design job, after impersonation-banner delete-rebirth
- [Phase 219-02]: D-06 canary-never-allowlistable assertion checked unconditionally right after ALLOWED map population in snapshot-canary-guard.sh, independent of whether the canary changed this run
- [Phase ?]: No file changes required for 219-04 — allowlists already at D-07 empty steady-state from 219-02/03; runtime --allow flags used for recapture, not committed entries
- [Phase ?]: Used the existing workflow_dispatch recapture run (29051223765) as the sole authoritative source for both SC-3 halves rather than dispatching a new CI run
- [Phase ?]: Did not rebless the install-golden fixture — job concluded success with no drift
- [Phase ?]: D-10: relocate the runtime cheerio require to after the no-bundles guard, rather than reordering the ci.yml npm-ci step or adding cheerio to a root package.json
- [Phase 220]: D-04: exactly three additive notes landed in one commit — no existing runbook section rewritten (D-03)
- [Phase 220]: Cited quality-ledger-monotonic.sh's 36-cell compare (not award-guard's skip-path exit-0) as the substantive SC-1 proof, per PI-1 — award-guard.mjs exits 0 against origin/main via a skip path because main predates the net-new award ledger; the guard did not compare anything at the merge-base boundary
- [Phase 220]: Recorded the local guard run explicitly as a PREVIEW, deferring the authoritative committed-HEAD proof to the terminal PR's fast_checks job per the 216 SC-5 trap — A green self-test/local run at a pre-PR sha is not valid evidence of a committed-HEAD guarantee; the binding proof is the same guards running in fast_checks against the real merge-base, confirmed via gh pr checks
- [Phase 220]: 220-04: Quarantine-PR draft scopes exactly the 3 impersonation-banner PNGs (D-05/D-08); required Example Playwright smoke green + PAT-push footgun note captured
- [Phase 220]: 220-04: Close-readiness record (D-13) maps SC-1..SC-4 to observable signals and captures affirmative panel-absence evidence (panel-ci-isolation.test.sh PASS 3/3 + zero-match ci.yml run: grep) for SC-4's panel half
- [Phase 220]: 220-04: Phase 220 complete (4/4 plans); does NOT self-merge any PR or archive the milestone — deferred ship sequence handed to operator/gsd-ship/gsd-complete-milestone
- [Phase ?]: 221-01: Mirrored only the Elixir semantics (scope: kwarg, impersonation_forbidden clause, dedupe copy) from the example twin into the installer template, not its vt-* markup; re-blessed the install golden fixture via the generator task
- [Phase 221]: up.sh --help window widened to 2,26p (not 2,30p) — stays inside the comment block, no code leak
- [Phase 221]: app-css-corruption-check.sh awk state machine resets last_was_prop=0 on complete single-line ;-terminated declarations, only =1 for genuine multi-line openers, closing the orphan-after-; false negative; proven by a net-new committed fixture + bash driver wired into CI (D-09/D-10)
- [Phase 221]: Pin value 1.3.0 matches Option 4a / D-13; scope discipline verified via git diff (single env line, no algorithm change); gate-green explicitly deferred to Plan 05 (push-to-main, after Plan 04 publish)
- [Phase 222]: Used a bash array (IFS=',' read -ra) instead of unquoted word-splitting for SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS to keep grep -vxF -f <(...) shellcheck-clean
- [Phase 222]: Exact-line fixed-string exclusion (grep -vxF, SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS default 1.20.0) replaces the D-03 retired-filter mechanism which RESEARCH proved matches zero live Hex rows
- [Phase ?]: [Phase 222-02]: One shared scripts/ci/notify-failure-issue.sh (D-07) is invoked from both ci.yml and release-please.yml instead of a composite action -- no new SHA-pinned third-party dependency.
- [Phase ?]: [Phase 222-02]: notify_release_lane_rot is deliberately absent from ci-gate.needs and is not a required check, mirroring nightly_probe's standalone posture, to avoid stranding PR merges under ruleset 14941512.
- [Phase ?]: [Phase 222-02]: GitHub context values (run id/sha/tag/version/job results) are passed to run: shell blocks only via the step env: mapping and referenced as shell variables, never inlined directly as ${{ github.* }} in shell text -- closes context-string injection threat T-222-02-02.
- [Phase 222]: 222-03: Treated the orchestrator's already-dispatched hex-publish.yml dry_run=true run (29132375168) against v1.3.0 as the authoritative HARD-02 readiness evidence rather than re-dispatching.
- [Phase 222]: 222-03: Inserted the MAINTAINING.md release-lane rot runbook subsection immediately after the Recovery / one-off publish line, mirroring the D-14 forced-failure-probe style, cross-referencing docs/release-runbook-v1-0.md without duplicating the release matrix.

### Pending Todos

- `2026-07-03-hex-retire-stray-1-20-0` — retire stray Hex `1.20.0` (operator/interactive step). Deferred indefinitely 2026-07-11 (Jon: no time, no adopters). Blocks Phase 223 completion. Low priority.

### Blockers/Concerns

- **Phase 223 PAUSED** — blocked on the deferred operator retire of stray Hex `1.20.0`. While `latest_stable_version=1.20.0` outranks the real GA `1.3.0`, PUB-05 (adopter resolution) and PROOF-01 (currency trust bundle) are literally unsatisfiable, so plans 223-02/223-03 are not run. Non-urgent: no adopters, and the CI gate is unaffected (`SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin). Root cause + guardrails: ADR 003.

### Roadmap Evolution

- Phase 208.1 inserted after Phase 208: v1.42 CI-Gate Remediation: fix ~15 never-CI-validated admin Playwright failures blocking the backlog ship + Phase 208 completion (URGENT)
- Phase 212 added (2026-07-01): v1.42 integration merge — closes the three gaps from the `/gsd-audit-milestone` aggregate audit (status `gaps_found`): GATE-01 snapshot-canary red vs origin/main (needs human canary decision), FLOW-01 persona-flow specs run in no CI gate, GATE-02 generated-host smoke CI-skipped. Drives PR #63 green + merged; only then ROADMAP v1.42 → shipped. See `.planning/v1.42-MILESTONE-AUDIT.md`.
- v1.43 STABILIZE roadmap created 2026-07-02: 3 phases (213-215), 13 requirements fully mapped. Phase 213 = Latest-Phoenix Compatibility (COMPAT-01/02/03); Phase 214 = Debt & Robustness Clear (DEBT-01..05, HEALTH-03); Phase 215 = Terminal Ratification (HEALTH-01/02/04, RATIFY-01).
- v1.44 ADMIN-UX-RATCHET roadmap created 2026-07-03: 5 phases (216-220), 14 requirements fully mapped. Phase 216 = Harness Foundation + Award Gradient (HARNESS-01/02/03, RATCHET-01/02); Phase 217 = Adversarial Panel + Auto-Fix Safety Rails (PANEL-01/02, AUTOFIX-01/02); Phase 218 = Elevation Wave + Nit Cleanup (ELEVATE-01/02/03); Phase 219 = Baseline Recapture + Canary Reconciliation (RECAP-01); Phase 220 = Terminal Ratification (RATIFY-01).
- v1.45 RELEASE-CURRENCY roadmap created 2026-07-10: 3 phases (221-223), 11 requirements fully mapped (fine granularity compressed to natural land-fixes-green → harden → publish-and-prove boundaries). Phase 221 = Unblock the Gate + Ship-Honest Generated-Host Debt (PUB-01, SHIP-01/02/03); Phase 222 = Release-Lane Hardening — No Silent Rot (HARD-01/02); Phase 223 = Get Current on Hex + Terminal Currency Proof (PUB-02/03/04/05, PROOF-01). Human-gated operator steps (interactive Hex write-auth) in Phase 223: `mix hex.retire sigra 1.20.0` + v1.2.0/v1.3.0 publish dispatch — runbook steps, not agent automation.

## Quick Tasks Completed

| Quick ID | Task | Status | Date |
| --- | --- | --- | --- |
| 260613-f1p | Pin phx_new to 1.8.7 in CI workflows (fix PR #52 red CI from phx_new 1.8.8 `<.button type>` drop). Verified: vault_promotion + golden_diff pass locally; SEED-004 filed for forward-compat. | complete ✓ | 2026-06-13 |
| 260618-fch | Fix vault_promotion_test.exs known failure — strip unsupported `type` attr from `<.button>` across 7 installer templates (durable fix vs phx_new button `:rest` allowlist) + sync example/golden mirrors + lift known_failure quarantine. Verified: 1 test, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-gdf | Resolve golden_diff_test.exs known failure — root cause was local phx_new 1.8.8 vs CI-pinned 1.8.7 (spurious config.exs `root_tag_attribute` byte-diff), NOT a stale fixture. Installed 1.8.7, lifted known_failure tag (no fixture change), documented phx_new 1.8.7 dev prereq in CLAUDE.md. Verified: 2 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-gly | Harden phase-186 D-11 parity test extractors — WR-02 (structural `extract_css_block/2` for auth dark block, replacing `Enum.take(30)`) + WR-03 (`extract_token_value/2` scoped to correct CSS block via optional selector). WR-01/IN-02 already resolved by prior pass; IN-03 optional CI guard deferred to new todo. Verified: 27 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 260618-grh | Narrow glossary drift-guard `action=` strip (phase 191 WR-01) — strip `action={…}` expressions but scan `action="…"` copy literals for banned terms; added regression test for the false-negative gap. Verified: 2 tests, 0 failures. | complete ✓ | 2026-06-18 |
| 189-verify | Close phase-189 ConfirmDialog review todo — WR-01/02/03/04 found already fixed in source (admin_hooks.js + branding_live.ex); fixed the dormant PAGE-03 verification spec (stale `/cancel/i` → `[data-sg-confirm-cancel]`) and wired admin-modal-interaction.spec.ts into the chromium CI lane. Verified green locally: 7/7 APG gates. | complete ✓ | 2026-06-18 |
| 260619-l1b | Demo/admin-UI Docker DX overhaul — `scripts/uat/up.sh` (no flags) now defaults to the shared-Traefik proxy path WITH live reload, health-gates the URL, auto-opens `/demo/credentials`. | complete ✓ | 2026-06-19 |
| 260621-in8 | Fix `scripts/uat/up.sh --dev` Phoenix `validate_compile_env` boot failure. | complete ✓ | 2026-06-21 |
| 260621-in8b | Follow-up regression fix to in8 — removed bogus `--no-validate-compile-env` flags; added `sync_host_compile_env_port()` self-heal. Verified LIVE all 3 paths. | complete ✓ | 2026-06-21 |
| 260621-nov | Night Ops brand-lab preset recolored teal→indigo/violet. | complete ✓ | 2026-06-21 |
| 260621-vlk | Real login locked to Vaultr; brand-lab → homepage preview only. | complete ✓ | 2026-06-21 |
| 260622-i0e | Vaultr demo: real account screens + full vt-* brand coherence + sudo fix + product identity. | complete ✓ | 2026-06-22 |
| 260622-gy0 | Vaultr authenticated account-home hub (`/app`). | complete ✓ | 2026-06-22 |
| 260622-jfr | Demo app rebranded Vaultr → Tasklane (project/work tracker), framing-only. | complete ✓ | 2026-06-22 |
| 260622-nft | Fixed email-change confirmation always failing — a real shipped bug in every generated host app. | complete ✓ | 2026-06-22 |
| 260623-j59 | Fixed session-invalidation crashes in password-change + account-deletion. | complete ✓ | 2026-06-23 |
| 260624-vin | Wired `check_account_active` into example `:require_authenticated` pipeline (loop-safe) + template parity. | complete ✓ | 2026-06-24 |
| 260624-vqv | Fixed `scripts/ci/snapshot-recapture-gate.sh` single-lane recapture (185-REVIEW WR-02). | complete ✓ | 2026-06-24 |
| 260621-o1q | Vaultr demo polish — kicker spacing + click-to-copy credentials. | complete ✓ | 2026-06-21 |
| 260621-vbr | Vaultr demo mini-brand typography + fixed pre-existing app.css comment corruption (opening `/*` lost). | complete ✓ | 2026-06-21 |
| 260718-eml | Fix settings email-change pending banner rendering blank (missing new email) + banner margin — request/cancel handlers now refresh `current_scope.user` with the updated user (example + installer template + byte-synced golden); scoped `.vt-panel .vt-alert` top margin; regression test. Shipped bug in every generated host. Live-verified (request + cancel) as alice. | complete ✓ | 2026-07-18 |
| 260718-i1m | Demo front-door get-started affordance + copy-scope fix — vt-code copy decoupled to opt-in (routes→links); home re-sequenced to orient→get-started(5-persona picker, `?demo={key}`)→showcase→reference; real login prefill + dev-gated password Fill + `/demo/use/:persona` fast-switch (distinct from impersonation); planted SEED-008 (generated-host first-admin bootstrap gap). Live-verified on running demo; caught+fixed Fill-button `user_password`→`name="user[password]"` selector no-op. | complete ✓ | 2026-07-18 |

## Deferred Items

| Category | Item | Status | Deferred At |
| --- | --- | --- | --- |
| Release-ops | Retire stray Hex `1.20.0` (PUB-04) + PUB-05 adopter-resolution proof + PROOF-01 currency bundle (all Phase 223) | Deferred indefinitely — operator/interactive Hex retire, no adopters. Resume `/gsd-execute-phase 223` after retire. Root cause: ADR 003. Tracked `todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` | v1.45 (override_closeout) |
| Release-ops | Push local `main` (v1.45 work + close-out commits) via close-out PR | Deferred — ruleset blocks direct push to `main`; needs a close-out PR | v1.45 |
| Brand exports | PNG/PDF exports for social/platform use | Deferred until a concrete platform target requires raster | v1.35 |
| Public docs | README/HexDocs visual adoption | Deferred to a separate focused change to avoid brand churn | v1.35 |
| Automation | Visual regression for `brandbook/index.html` | Nice-to-have | v1.35 |
| Playwright | `Phoenix.Ecto.SQL.Sandbox` for browser acceptance tests | Deferred | v1.33 |

### Acknowledged at v1.43 close (2026-07-03)

v1.43-pulled ledger entries all RESOLVED (reconciled by Phase 215 RATIFY-01, cross-checked in 215-03-SUMMARY): oban-enqueue (DEBT-01), phase209/phase200 code-review (DEBT-02/03), app-css-comment-corruption (DEBT-05), v142-integration-snapshot-canary-drift + stale-known-failure-contract-tests (HEALTH-03), all under `.planning/todos/resolved/`. SEED-004 phx-new-button-forward-compat RESOLVED via COMPAT-01/02/03 (Phase 213).

Items folded INTO v1.44 (will be resolved in Phase 218):

| Category | Item | Resolution |
| --- | --- | --- |
| todo | 2026-06-19-uat-demo-dx-polish-nits | UI-01 → Phase 218 (elevation wave nit cleanup) |
| todo | 2026-06-22-vaultr-authed-rebrand-residuals | UI-02 → Phase 218 (elevation wave nit cleanup) |

Items deferred beyond v1.44 (feature milestone or later) — NOT unreconciled debt:

| Category | Item | Status |
| --- | --- | --- |
| todo | 2026-06-20-runtime-auth-prefix-override | tracked — config feature (FEAT-01, v2) |
| todo | 2026-06-20-mix-sigra-migrate-schema-helper | tracked — installer feature (FEAT-02, v2) |
| todo | 2026-06-22-white-label-auth-email-theming | tracked — auth/email white-label (FEAT-03, v2) |
| todo | 2026-06-20-playwright-parallelization-per-shard-db | tracked — CI perf (SEED-005, v2) |
| todo | 2026-07-02-app-css-corruption-guard-blind-spot | accepted low-severity DEBT-05 follow-up (live app.css clean + browser-verified; regression-guard hardening gap only) |
| seed | SEED-005-ci-cd-pipeline-performance-audit | dormant — CI/CD perf audit (next-milestone candidate) |
| seed | SEED-006-admin-design-gallery-ci-baseline-recapture | dormant — deterministic CI fonts + in-CI baseline recapture |

### Acknowledged at v1.44 close (2026-07-10)

override_closeout — `audit-open` reported ~20 open items, all acknowledged-deferred at milestone close:

- **10 quick-tasks** (`260618-fch…`, `260618-gly…`, `260618-grh…`, `260619-l1b…`, etc.) — the **known false-flag**: completed quick-tasks that glob as "open" (same pattern acknowledged at v1.42/v1.43 close). No action.
- **1 debug session** `pr37-phantom-sigra-web` (investigating, 2026-05-02) — stale, from the phase-88 era; not v1.44 scope. (Its stray untracked copy — left by a bad stash pop during the v1.44 ship — was cleaned; the session record is preserved in stash `chore/phase-88-uat-evidence`.)
- **1 UAT gap** — carried; not blocking (v1.44 verification was gate-driven via Phase 220 + live CI).
- **5 todos / 3 seeds** — carried forward as tracked debt, notably the **new deferred-Hex TODO** `2026-07-10-upgrade-smoke-button-type-hex-publish` (fix upgrade-smoke `<.button type>` → publish v1.2.0/v1.3.0 to Hex), the Jon-manual Hex `1.20.0` retire, the v2 FEAT-01/02/03 config/installer features, and SEED-005/006 (dormant CI-perf / gallery-recapture). None are unreconciled blocking debt.

## Session Continuity

Last session: 2026-07-11T00:59:38.125Z
Stopped at: Phase 223 context gathered (assumptions mode)
Resume file: .planning/phases/223-get-current-on-hex-terminal-currency-proof/223-CONTEXT.md

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
| Phase 208.1 P03 | 38m | 3 tasks | 5 files |
| Phase 209 P01 | 4 | 1 tasks | 1 files |
| Phase 209 P02 | 522 | 3 tasks | 10 files |
| Phase 209 P03 | 2 | 2 tasks | 4 files |
| Phase 209 P04 | 5 minutes | 3 tasks | 6 files |
| Phase 209 P06 | 3min | 3 tasks | 1 files |
| Phase 210 P01 | 119 | 3 tasks | 1 files |
| Phase 210 P02 | 236 | - tasks | - files |
| Phase 210 P02 | 236 | 2 tasks | 1 files |
| Phase 211 P01 | 8min | 3 tasks | 0 files |
| Phase 211 P02 | 9min | 2 tasks | 0 files |
| Phase 211 P03 | 19min | 3 tasks | 0 files |
| Phase 213 P01 | 4min | 2 tasks | 3 files |
| Phase 213 P02 | 723 | 3 tasks | 10 files |
| Phase 214 P01 | 149 | 2 tasks | 5 files |
| Phase 214 P02 | 20 minutes | 2 tasks | 7 files |
| Phase 214 P03 | 6 | 3 tasks | 3 files |
| Phase 214 P04 | 89s | 2 tasks | 2 files |
| Phase 214 P05 | 170s | 2 tasks | 3 files |
| Phase 216 P01 | 144s | 3 tasks | 4 files |
| Phase 216 P04 | ~15min | 3 tasks | 6 files |
| Phase 216 P05 | 4min | 3 tasks | 3 files |
| Phase 216 P06 | 17min | 3 tasks | 5 files |
| Phase 216-harness-foundation-award-gradient P07 | 45m | 5 tasks | 6 files |
| Phase 216 P08 | 611 | 3 tasks | 4 files |
| Phase 216 P09 | 95 | - tasks | - files |
| Phase 217 P01 | 374 | 4 tasks | 7 files |
| Phase 217 P04 | 176 | 1 tasks | 1 files |
| Phase 217 P02 | 13m30s | 3 tasks | 7 files |
| Phase 217 P03 | 14m 38s | 3 tasks | 4 files |
| Phase 217 P05 | 621 | 4 tasks | 8 files |
| Phase 217 P06 | 914 | 3 tasks | 6 files |
| Phase 217 P07 | 3m37s | 2 tasks | 2 files |
| Phase 218 P01 | 707s | - tasks | - files |
| Phase 218 P04 | 235 | 2 tasks | 1 files |
| Phase 218 P05 | 311s | 2 tasks | 5 files |
| Phase 218 P02 | 1845s | 2 tasks | 1 files |
| Phase 218 P03 | 268s | 2 tasks | 1 files |
| Phase 218 P06 | 90min | 1 tasks | 2 files |
| Phase 218 P07 | 12min | 2 tasks | 2 files |
| Phase 218 P08 | 12min | 2 tasks | 2 files |
| Phase 218 P09 | 12min | 3 tasks | 8 files |
| Phase 218 P10 | 3min | 1 tasks | 1 files |
| Phase 219 P01 | 5min | 1 tasks | 1 files |
| Phase 219 P02 | 4min | 3 tasks | 2 files |
| Phase 219 P04 | 5min | 2 tasks | 0 files |
| Phase 219 P05 | 4min | 2 tasks | 0 files |
| Phase 220 P01 | 6min | 2 tasks | 2 files |
| Phase 220 P02 | 8min | 1 tasks | 1 files |
| Phase 220 P03 | 6min | 1 tasks | 1 files |
| Phase 220 P04 | 8min | 2 tasks | 2 files |
| Phase 221 P01 | 20min | 3 tasks | 2 files |
| Phase 221 P02 | 6min | 3 tasks | 5 files |
| Phase 221 P03 | 8min | 2 tasks | 1 files |
| Phase 222 P01 | 9min | 2 tasks | 6 files |
| Phase 222 P02 | 20min | 3 tasks | 5 files |
| Phase 222 P03 | 15min | 2 tasks | 2 files |
