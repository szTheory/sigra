# Phase 197: Playwright Lanes & Design-Gallery Re-Gate - Research

**Researched:** 2026-06-20
**Domain:** CI/test-infra — GitHub Actions `example_playwright_smoke` job, Playwright project topology, self-hosted webfont determinism, in-CI visual baseline recapture
**Confidence:** HIGH (all findings verified against live files in this session; no external package research needed — this is an infra/config phase)

## Summary

Phase 197 hardens the `example_playwright_smoke` lane along three axes already locked in CONTEXT.md (D-01..D-11). This research grounds those decisions in the live files and quantifies the deferred levers. The dominant reliability win (D-01/D-02) is mechanical: add `if: ${{ !cancelled() }}` to the **five** `npx playwright test` steps (CORRECTION: the live `example_playwright_smoke` lane has FIVE, not six — `npx playwright test` at ci.yml lines 985/1003/1045/1061/1074; step-name headers at 973/991/1027/1050/1068) plus a final `if: always()` aggregating step so independent failures surface in one run instead of masking each other. The wall-clock win (D-04) is genuinely modest and one of its two proposed levers is **unsafe as stated**: the `webkit` browser install **cannot** be dropped, because the `mobile`, `admin-checkpoints-mobile`, and `admin-design-mobile` Playwright projects all use `devices['iPhone 13']`, whose `defaultBrowserType` is `webkit` ([VERIFIED: playwright-core deviceDescriptorsSource.json]). The remaining D-04 lever — consolidating serial `npx playwright test` launches — saves only repeated runner-startup overhead (a few seconds each) because execution is `workers: 1` serial-by-design.

D-07's root-cause correction is fully verified: **no webfont is served anywhere** in the example app — no `@font-face`, no `*.woff2`, no Google Fonts link; served CSS uses system stacks (`default.css:9` `--font-sans: ui-sans-serif, system-ui, …`). The ~20–53px reflow is therefore a host-OS `system-ui` metric delta (macOS capture box vs ubuntu CI), not a font-load failure. D-08's remediation (bundle self-hosted Space Grotesk woff2, set `--font-sans`, await `document.fonts.ready`, recapture in-CI) is mechanically feasible: the brand TTF is in-repo (`scripts/brand/fonts/SpaceGrotesk[wght].ttf`) and `fonttools 4.62.1` is available to subset/convert to woff2.

The D-11 MG-5/6 `test.fail()` is **not** about the static gallery board — it navigates to the *real* `/admin/audit` and user-audit pages (admin-design.spec.ts:342-385) and asserts pagination links render, which requires a user with ≥25 audit events (`@default_limit 25` in `lib/sigra/admin/audit/query_params.ex:22`). **CORRECTION (ground truth, supersedes the "empty stub / ~3-5 events" claim below): `test/example/lib/example/demo/seeds.ex` is NOT an empty stub — it already seeds 18 admin-tied (`@audit_actions`, via `effective_user_id: admin.id`) + 16 persona-tied (`persona_audit_events()`, via `subject.id`) = 34 audit events. But NO single user reaches ≥25 per-user (admin has 18; each persona ≤~4), and the test asserts `Previous page` on the global `/admin/audit` page-1 (where it does not exist) and on the FIRST-LISTED non-admin user's audit page. So the DEFAULT D-11 resolution is `test.skip(...)` (D-11b) — see Plan 03 Task 4. A for-real run (D-11a) is permitted only after EMPIRICAL booted-app confirmation, and any seed change must target the first-listed user the test visits, not admin.**

**Primary recommendation:** Implement D-01/D-02 (guards + aggregator) and D-06 (expect.poll) exactly as specified — these are unambiguous and low-risk. For D-04, drop only the launch-consolidation lever and **keep webkit installed** (record the corrected finding in VERIFICATION). For D-08, add `@font-face` + `--font-sans` override to `app.css` (example-only, NOT the `sigra_admin.css` installer template) to avoid installer-parity scope. For D-09, the recapture job needs `permissions: contents: write` (the workflow default is `contents: read`). For D-11, prefer `test.skip()` with the recorded reason unless a one-user ≥25-event seed can be added without perturbing the 72 element-scoped baselines (it can — the gallery boards render static literal markup, so real-data seeding does not touch them).

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add `if: ${{ !cancelled() }}` (≡ `success() || failure()`) to **every** `npx playwright test` step in `example_playwright_smoke` so an early failure no longer skips later independent steps. All step failures surface in one run.
- **D-02:** Add a final aggregating step (`if: always()`) that fails the job if any test step's outcome was `failure` — guards must not silently swallow failures; the job still goes red, just after running all steps.
- **D-03:** Do **NOT** matrix-shard the lane. The boot prelude is the dominant fixed cost and would be re-paid per shard; `playwright.config.ts` is `workers:1, fullyParallel:false` (shared DB state) so shards cannot run concurrently against one app.
- **D-04:** Wall-clock levers (researcher quantifies, picks evidence-backed subset): (a) consolidate serial `npx playwright test` invocations; (b) drop unused browser installs (confirm whether `webkit` is exercised). Win is modest; failure-surfacing (D-01) is the larger gain.
- **D-05:** Keep the bash readiness loops (`ci.yml:953-968`) — explicit poll-until-ready probes, not blind sleeps. No `Process.sleep` in browser-lane code.
- **D-06:** Replace the two `await page.waitForTimeout(1_000)` calls (`organizations.spec.ts:152`, `ga-uat-shift-left.spec.ts:106`) with `expect.poll()` re-querying the mailbox.
- **D-07:** SEED-006's webfont-root-cause premise is factually wrong: no webfont served anywhere; real cause is host-OS `system-ui` metric delta. Record correction.
- **D-08:** Bundle self-hosted Space Grotesk woff2 + set `--font-sans` + `await document.fonts.ready` + recapture all `admin-design-*` baselines in-CI.
- **D-09:** In-CI recapture runs as a dedicated `workflow_dispatch` job (or folds into Phase-196 nightly `schedule:` lane), NOT inline in the PR-gating job; commits via `snapshot-canary-guard.sh --allow`.
- **D-10:** Remove `continue-on-error: true` from the design-gallery step (`ci.yml:1043`); keep it inline in `example_playwright_smoke` (do NOT move to nightly).
- **D-11:** Resolve MG-5/6 `test.fail()` — preferred: seed one user with ≥25 audit events; bounded fallback: `test.skip(...)` with recorded reason. Avoid `test.fail()` standing.

### Claude's Discretion
- Exact `if:` expression form; aggregating-step implementation; cron minute; woff2 source/subset; `expect.poll` interval/timeout values — all implementation-level, defaulted by planner.

### Deferred Ideas (OUT OF SCOPE)
- Broader webfont adoption across non-design admin/auth/demo surfaces — D-08 bundles the font for render determinism, NOT a design refresh.
- Reviewed-not-folded todos: token-reference-completeness CI guard; phase51 installer CI-contract drift; page04 branding scoring.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PW-01 | Reduce `example_playwright_smoke` critical path; early-step failure no longer masks later steps | D-01/D-02 guards+aggregator (Architecture Patterns §1); D-04 launch consolidation quantified (§Standard Stack / Pitfall 1); webkit-drop ruled out (Pitfall 2) |
| PW-02 | Deterministic readiness everywhere; no `Process.sleep`-based waits | D-05 confirmed (only 2 `waitForTimeout` in browser-lane code); D-06 `expect.poll()` rewrite shape (Code Examples §2) |
| PW-03 | Re-gate `continue-on-error` admin-design gallery; resolve ~20–53px height delta at root cause | D-07 verified (no webfont); D-08 self-hosted woff2 mechanics (Code Examples §3); D-09 recapture job shape; D-10 remove `continue-on-error` at `ci.yml:1043`; D-11 MG-5/6 (Pitfall 5) |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Step failure surfacing / aggregation | GitHub Actions workflow (`ci.yml`) | — | `if:` guards + aggregator are pure CI-orchestration concerns |
| Browser install scope | GitHub Actions workflow | Playwright config | Install list in `ci.yml:936`; which browsers are needed is determined by `playwright.config.ts` project `devices` |
| Test launch consolidation | GitHub Actions workflow | Playwright CLI | Multiple specs + `--project` flags can pass to one `npx playwright test` |
| Deterministic mailbox readiness | Playwright test code (specs) | — | `expect.poll()` lives in the two `.spec.ts` helpers |
| Render-font determinism | Served CSS (`app.css`) + font asset (`priv/static`) | Playwright spec (`document.fonts.ready`) | OS-independence requires the font to load in the browser; the spec waits for it |
| In-CI baseline recapture | GitHub Actions workflow (new job) | `snapshot-canary-guard.sh` | Boot+`--update-snapshots` is a workflow job; commit-gating is the canary script |
| MG-5/6 pagination data | Example app seeding | admin LiveView pagination (`@default_limit 25`) | Real `/admin/audit` page needs ≥25-event user; gallery board markup is static |

## Standard Stack

This is an infra/config phase — no new runtime dependencies are installed. The relevant tooling already present:

| Tool | Version | Purpose | Status |
|------|---------|---------|--------|
| `@playwright/test` | (vendored in `test/example/priv/playwright/node_modules`) | Browser test runner; `expect.poll()`, `--project`, `--update-snapshots`, `document.fonts.ready` | [VERIFIED: node_modules present, deviceDescriptorsSource.json read] |
| `fonttools` | 4.62.1 (python3) | Subset/convert `SpaceGrotesk[wght].ttf` → woff2 | [VERIFIED: `python3 -c "import fontTools"` → 4.62.1] |
| `woff2_compress` / standalone `fonttools` CLI | NOT installed | Alt woff2 conversion | [VERIFIED: `which` returns nothing — use python `fontTools.ttLib.woff2` instead] |
| GitHub Actions (`actions/cache`, `actions/checkout@v6`, `erlef/setup-beam@v1.24.0`, `actions/setup-node@v6`) | pinned by SHA | Existing lane infra | [VERIFIED: ci.yml:886-896] |

**No `npm install` / `mix deps` changes required.** The Package Legitimacy Audit section is therefore omitted (no external packages installed this phase).

### woff2 generation (no new dep — use the installed python fonttools)

```bash
# fontTools (4.62.1) ships the woff2 writer; brotli is the only extra it may need.
# Convert the variable TTF to woff2 (preserves the wght axis):
python3 - <<'PY'
from fontTools.ttLib import TTFont
f = TTFont("scripts/brand/fonts/SpaceGrotesk[wght].ttf")
f.flavor = "woff2"
f.save("test/example/priv/static/assets/fonts/space-grotesk-var.woff2")
PY
```

If `fontTools` raises `ImportError: No module named 'brotli'` during woff2 save, install `brotli` (`pip install brotli`) — verify in the CI environment first (the recapture job runs on ubuntu; the woff2 should ideally be **committed to the repo**, generated once locally, so CI never needs fonttools at all). **Recommendation: generate the woff2 once locally, commit it, and have CI consume the committed asset** — this keeps the CI recapture job dependency-free.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Self-hosted woff2 (D-08) | Recapture-in-CI only (no font) | Render stays OS-dependent → local capture diverges from CI baselines forever. Rejected in D-08. |
| Self-hosted brand woff2 | Pinned CI fallback (Liberation Sans) | Lower fidelity, not brand type. Rejected in D-08. |
| Variable woff2 (full wght axis) | Static-instance woff2 (single weight) | Static instance is smaller and avoids variable-axis rendering edge cases, but the gallery/body may use multiple weights. Variable is safer for fidelity; subset to needed weights if size matters. |

## Architecture Patterns

### System Architecture Diagram

```
                         example_playwright_smoke job (ci.yml:872-1168)
                         ────────────────────────────────────────────
  BOOT PRELUDE (fixed cost, paid once — D-03 says do not re-pay per shard)
    checkout → setup-beam → setup-node → cache example deps
      → mix deps.get → mix compile --warnings-as-errors
      → ecto.create+migrate → mix run priv/repo/seeds.exs   (stub today)
      → npm ci → npx playwright install --with-deps chromium webkit  (937)
      → mix phx.server &   (background, log → /tmp)          (949)
      → bash poll: curl / until 200, then warm-up routes      (953-968)  ← D-05 keep
                              │
                              ▼
  TEST STEPS (serial, workers:1, shared dev DB)  ── each gets D-01 `if: !cancelled()`
    1. admin behavior (chromium)              973  →  --project=chromium
    2. admin checkpoints (chromium/mobile/dark)  991
    3. [stage checkpoint PNGs]                  1014  (if: success)
    4. design gallery (chromium/mobile/dark)   1027  ← D-10 drop continue-on-error (1043)
    5. non-admin smoke (chromium)              1050  (golden-path, ga-uat, passkeys, orgs)
    6. demo-showcase (demo-showcase-chromium)  1068
                              │
                              ▼
  NEW: aggregating step (if: always())  ── D-02: red if any step.outcome == failure
                              │
                              ▼
  failure dump + artifact upload (existing, if: failure / always)   1077-1168


  NEW SIBLING JOB (D-09): admin_design_recapture
    if: github.event_name != 'pull_request'  (reuse Phase-196 precedent)
    permissions: contents: write             ← REQUIRED (workflow default is read)
    boot app → npx playwright test admin-design.spec.ts
                 --project=admin-design-{chromium,mobile,dark} --update-snapshots
             → snapshot-canary-guard.sh --allowlist snapshot-allowlist-design
                 --canary board-notice --allow <each recaptured slug>
             → commit + push PNGs
```

### Recommended Project Structure (files touched)
```
.github/workflows/ci.yml                              # D-01/D-02 guards+aggregator; D-04 consolidation; D-10 drop continue-on-error; D-09 new job
test/example/priv/playwright/tests/
├── organizations.spec.ts                             # D-06 expect.poll (line 152)
├── ga-uat-shift-left.spec.ts                         # D-06 expect.poll (line 106)
└── admin-design.spec.ts                              # D-08 document.fonts.ready; D-11 MG-5/6 test.fail→skip/seed
test/example/priv/static/assets/
├── fonts/space-grotesk-var.woff2                     # D-08 NEW committed font asset
└── css/app.css                                       # D-08 @font-face + --font-sans override (example-only)
test/example/priv/repo/seeds.exs (or demo seed path) # D-11 optional ≥25-event user seed
.planning/seeds/SEED-006-*.md                         # D-07 record root-cause correction
```

### Pattern 1: `!cancelled()` step guard + `always()` aggregator (D-01/D-02)
**What:** Each test step runs regardless of prior step outcome; a terminal step fails the job if any did.
**When to use:** Sequential steps that share a booted app but are independent test seams.
```yaml
# Source: GitHub Actions expressions + existing ci.yml idiom (Phase-196 if: patterns)
- name: Run admin behavior browser truth (chromium)
  id: admin_behavior            # give each test step an id so the aggregator can read outcomes
  if: ${{ !cancelled() }}       # ≡ success() || failure(); runs unless the job was cancelled
  working-directory: test/example/priv/playwright
  env: { CI: "true", SIGRA_EXAMPLE_URL: "http://localhost:4000" }
  run: npx playwright test tests/admin-user-operations.spec.ts ... --project=chromium
# ... repeat `id:` + `if: ${{ !cancelled() }}` on steps at 991, 1027, 1050, 1068 ...
- name: Aggregate Playwright step outcomes
  if: always()
  run: |
    fail=0
    for o in "${{ steps.admin_behavior.outcome }}" \
             "${{ steps.admin_checkpoints.outcome }}" \
             "${{ steps.design_gallery.outcome }}" \
             "${{ steps.non_admin_smoke.outcome }}" \
             "${{ steps.demo_showcase.outcome }}"; do
      [ "$o" = "failure" ] && fail=1
    done
    [ "$fail" -eq 1 ] && { echo "::error::one or more Playwright seams failed"; exit 1; } || echo "all seams passed"
```
**Note:** the `Stage admin checkpoint PNGs` step at 1014 is `if: success()` today — under D-01 the design step no longer aborts the job, but a *checkpoints* failure would now let staging run on stale results. Decide whether staging should become `if: ${{ steps.admin_checkpoints.outcome == 'success' }}` so it only stages from a green checkpoints run (see Pitfall 4).

### Pattern 2: `expect.poll()` mailbox readiness (D-06)
See Code Examples §2.

### Pattern 3: Self-hosted webfont + `document.fonts.ready` (D-08)
See Code Examples §3.

### Anti-Patterns to Avoid
- **Dropping the `webkit` install** — three mobile projects use `iPhone 13` (webkit). Removing it breaks all mobile lanes (Pitfall 2).
- **Putting `@font-face` in `sigra_admin.css`** — that file is an installer template (`priv/templates/sigra.install/admin/sigra_admin.css`); editing it pulls installer-parity work into scope and contradicts "not a design refresh" (D-08 / Deferred Ideas). Use `app.css` (example-only).
- **Leaving `test.fail()` standing** — it spuriously passes if pagination ever appears (D-11). Use `test.skip()` or seed real data.
- **Recapturing baselines inline in the PR job** — D-09 forbids; the recapture commits PNGs and needs `contents: write`, which the PR gate must not carry.
- **Matrix-sharding (D-03)** — re-pays the ~minutes-long boot prelude per shard and breaks shared-DB serial correctness.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wait for mailbox row | Custom `for` loop + `waitForTimeout` | `expect.poll(fn, {intervals, timeout})` | Playwright-managed backoff, auto-fail message, no fixed sleep (D-06) |
| Wait for font load | Arbitrary `waitForTimeout` after navigation | `await document.fonts.ready` | Resolves exactly when faces finish loading; deterministic (D-08) |
| Baseline drift gate | New script | `scripts/ci/snapshot-canary-guard.sh` (`--allowlist snapshot-allowlist-design --canary board-notice`) | Already handles the `-admin-design-*` slug suffix (`slug_of`, line 56) and the design allowlist exists |
| woff2 conversion in CI | bespoke build step | committed woff2 asset (generate once locally with fonttools) | Keeps the CI recapture job dependency-free |
| Nightly/non-PR gating | new workflow file | `if: github.event_name != 'pull_request'` (Phase-196 precedent, live at ci.yml:515,568,619,749,1173,1352) | Stable required-check surface; no branch-protection churn |

## Runtime State Inventory

> This phase edits CI config, specs, CSS, and a font asset. The only "runtime state" concern is committed visual baselines and the design allowlist.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB-stored rename. Example dev DB is recreated each CI run. | None |
| Live service config | None — no external service config holds any phase string. | None |
| OS-registered state | None. | None |
| Secrets/env vars | None new. Recapture job needs `permissions: contents: write` (job-scoped), no new secret. | Add job-level `permissions` block |
| Build artifacts / committed baselines | **72 committed PNG baselines** under `tests/admin-design.spec.ts-snapshots/` (24 boards × chromium/mobile/dark) — ALL must be recaptured in-CI under D-08 (render changes when the font loads). `snapshot-allowlist-design` exists, steady-state empty. | Recapture job overwrites all 72; canary-guard `--allow` each changed slug; reset allowlist to empty after merge |

**Verified by:** `ls tests/admin-design.spec.ts-snapshots/ | wc -l` → 72; `cat snapshot-allowlist-design` → comments only (empty steady state).

## Common Pitfalls

### Pitfall 1: D-04 wall-clock win is genuinely small — set expectations honestly
**What goes wrong:** Planner promises a large critical-path reduction; reality is a few seconds.
**Why it happens:** Execution is `workers:1, fullyParallel:false` (shared DB) — consolidating launches removes only repeated *runner startup* (Playwright process spin-up + config parse per `npx playwright test`), not test execution time. There are **6** test-step launches today (973, 991, 1027, 1050, 1068 + the staging step is not a launch). Consolidating compatible launches (e.g., the non-admin smoke at 1050 already passes 6 specs in one launch — good; the demo-showcase at 1068 is a separate `--project`, and design/checkpoints are separate `--project` sets) can at best merge a couple of launches. **Honest framing:** criterion 1b is "modestly met"; the real win is D-01 failure-surfacing. Record this tradeoff in VERIFICATION (CONTEXT D-04 anticipates it).
**How to avoid:** Quantify before/after launch count; do not promise minutes.
**Warning signs:** A plan task claiming ">2 min saved from consolidation."

**Concrete launch inventory (before):**
| Step (ci.yml line) | Specs | `--project` flags |
|---|---|---|
| 973 admin behavior | admin-user-operations, impersonation, admin-audit, admin-modal-interaction | `chromium` |
| 991 checkpoints | admin-checkpoints | `admin-checkpoints-{chromium,mobile,dark}` |
| 1027 design gallery | admin-design | `admin-design-{chromium,mobile,dark}` |
| 1050 non-admin smoke | golden-path, ga-uat-shift-left, passkeys-hooks, organizations, passkey-login, passkey-options | (default — chromium+mobile per testIgnore) |
| 1068 demo-showcase | demo-showcase | `demo-showcase-chromium` |

These five launches are **not** trivially mergeable into one: steps 973/1027/1068 use disjoint explicit `--project` sets, and the staging step at 1014 must run *between* checkpoints (991) and design (1027) because Playwright clears `test-results/` at the start of each launch (documented at ci.yml:1008-1013). **Safe consolidation is limited** — e.g. one could pass multiple specs to a single launch only if they share a project set. The cleanest small win: confirm the design step does not need to stay separate from non-admin (it does — different projects), so realistically launches stay ~5. Lever (a)'s yield is near-zero here; **lever (b) is the only meaningful install-time lever and it is blocked (Pitfall 2).**

### Pitfall 2: `webkit` install is NOT droppable — `iPhone 13` is webkit
**What goes wrong:** Planner removes `webkit` from `npx playwright install --with-deps chromium webkit` (ci.yml:937) to save install time; all mobile projects fail to launch a browser.
**Why it happens:** `playwright.config.ts` `mobile`, `admin-checkpoints-mobile`, and `admin-design-mobile` projects all use `...devices['iPhone 13']`. [VERIFIED: `deviceDescriptorsSource.json` → `iPhone 13.defaultBrowserType === "webkit"`; `Desktop Chrome.defaultBrowserType === "chromium"`].
**How to avoid:** **Keep `webkit` installed.** Record in RESEARCH/VERIFICATION that D-04 lever (b) is infeasible without first migrating mobile projects off webkit (out of scope — that would change baselines and behavior coverage).
**Warning signs:** Mobile lane error `Executable doesn't exist … browser has not been installed`.
**Confidence:** HIGH [VERIFIED: playwright-core deviceDescriptorsSource.json].

### Pitfall 3: `default.css` is a regenerable daisyUI dump — pick the right CSS home for `@font-face`
**What goes wrong:** `@font-face` + `--font-sans` override added to `default.css`, which is auto-generated ("You can safely remove the whole file" — header comment, default.css:1-3) and may be regenerated, dropping the edit.
**Why it happens:** `default.css:9` owns the canonical `--font-sans` (drives `--default-font-family`), so it's the tempting target — but it's not a durable home.
**How to avoid:** Add `@font-face` + a `:root { --font-sans: 'Space Grotesk', ui-sans-serif, system-ui, … }` override to **`app.css`** (or `sigra_admin.css` if admin-only is desired — but that's an installer template, see Anti-Patterns). All three CSS files are linked in `root.html.heex:10-12` in order default → sigra_admin → app, so `app.css` (last) wins the cascade for `--font-sans`. **Recommendation: `app.css`** — example-only, loads last, no installer parity.
**Warning signs:** Font renders locally but reverts after a CSS regen, or installer golden-diff test fails.

### Pitfall 4: D-01 guards interact with the `if: success()` staging step (ci.yml:1014)
**What goes wrong:** With `!cancelled()` guards, a failing **checkpoints** step (991) no longer aborts the job, so the `Stage admin checkpoint PNGs` step (1014, currently `if: success()`) — and later steps — still run. `if: success()` evaluates against the *cumulative* job status, which is now `failure` after a guarded failure, so staging would be **skipped** even when checkpoints itself passed but an earlier step failed; conversely the existing failure-dump (`if: failure()`, 1077) and `Collect curated screenshots` (`if: always()`, 1093) behave as before.
**Why it happens:** `success()` means "no previous step failed," which `!cancelled()` guards deliberately defeat.
**How to avoid:** Change the staging step's guard from `if: success()` to `if: ${{ steps.<checkpoints_step_id>.outcome == 'success' }}` so it stages whenever checkpoints specifically passed, independent of unrelated seam failures. Give the checkpoints step an `id:` (needed for the aggregator anyway).
**Warning signs:** Empty `artifacts/admin-checkpoints/` on a run where checkpoints passed but design failed.

### Pitfall 5: MG-5/6 `test.fail()` is about REAL admin pages, not the static gallery board (D-11)
**What goes wrong:** Planner seeds the static gallery board, but the test still fails because it navigates to real `/admin/users`, `/admin/audit`, and a user-detail audit page.
**Why it happens:** `admin-design.spec.ts:342-385` does `page.goto('/admin/audit')` etc. and asserts `getByRole('link', { name: 'Previous page' })` is attached — pagination only renders at ≥25 rows. Admin audit `@default_limit 25` ([VERIFIED: lib/sigra/admin/audit/query_params.ex:22]). **CORRECTION: the seed claim below ("Fresh per-test users have ~3-5 events; the example seeds.exs is a 21-line empty stub") is STALE — `test/example/lib/example/demo/seeds.ex` seeds 34 audit events (18 admin-tied + 16 persona-tied), but no single user reaches ≥25, so the disposition is D-11b skip-with-reason (Plan 03 Task 4). The original (now superseded) note read:** Fresh per-test users have ~3-5 events; the example `seeds.exs` is a 21-line empty stub ([VERIFIED]). The static gallery boards (`mg-5-desktop-results` etc.) render **hardcoded literal markup** with a static pagination nav (design_gallery_live.ex:611-833) — seeding does NOT touch them, so element-scoped baselines are unaffected.
**How to avoid (preferred, D-11a):** Seed ONE user with ≥25 audit events in the example seeding path (the spec's per-test fresh user lists ALL users on `/admin/users`, so a seeded heavy user is visible). Because gallery boards are static literals, this seed does **not** perturb the 72 element-scoped captures — confirming the D-11 fallback condition ("if seeding perturbs other boards") does NOT apply here. **Fallback (D-11b):** `test.skip('data-dependent pagination; tracked in <todo>')`. Either way, remove `test.fail()`.
**Recommendation:** D-11a (seed) is achievable and makes the gallery deterministically exercise pagination; it is the stronger outcome. If the seed proves fiddly (audit event insertion API, FK to a user), fall back to `test.skip()` — both satisfy criterion #4.
**Warning signs:** `Previous page` link absent on `/admin/audit`; test passes by `test.fail()` masking.

### Pitfall 6: Recapture job needs `contents: write` and a non-empty allowlist of exact slugs
**What goes wrong:** Recapture job can't push (default `permissions: contents: read`, ci.yml:26), or canary-guard rejects the changed PNGs because the recaptured slugs aren't allowlisted.
**Why it happens:** Workflow sets least-privilege `contents: read` globally (ci.yml:24-26). `snapshot-canary-guard.sh` fails on any changed slug not in the allowlist or passed via `--allow` (lines 106-108), and the `board-notice` canary (the design lane's canary, recapture-gate.sh:52) **can never be allowlisted** and fails on modify (line 104) — so recapturing `board-notice` will trip the canary.
**How to avoid:** (1) Add job-level `permissions: { contents: write }` to the recapture job. (2) Pass `--allow <slug>` for every recaptured slug, OR temporarily add them to `snapshot-allowlist-design`. (3) **`board-notice` is the design-lane canary** — recapturing it will trip the canary guard on modify. Since the font change alters ALL boards including `board-notice`, the recapture job must either (a) special-case the canary (the guard tolerates `added`, not `modified`), or (b) accept that the font-recapture is a one-time canary re-establishment requiring a manual canary update. **This needs a planning decision** — flag as Open Question 1.
**Warning signs:** `snapshot-canary-guard: FAIL: canary snapshot modified: 'board-notice'`.
**Confidence:** HIGH [VERIFIED: snapshot-canary-guard.sh:93-104, snapshot-recapture-gate.sh:52, ci.yml:24-26].

### Pitfall 7: `document.fonts.ready` resolves immediately if no face is actually requested
**What goes wrong:** Spec adds `await document.fonts.ready` but the font never loads (wrong `@font-face` `src` path, or no element uses the family), so it resolves instantly and capture happens pre-font.
**Why it happens:** `document.fonts.ready` resolves once all *pending* font loads settle — if the browser never requests the face (because `--font-sans` override didn't take, or the woff2 404s), there's nothing to wait for.
**How to avoid:** (1) Verify the woff2 is served (curl `/assets/fonts/space-grotesk-var.woff2` → 200 in the warm-up loop). (2) Ensure `--font-sans` override actually applies to body text (cascade: `app.css` loads last). (3) Optionally assert `await document.fonts.check('16px "Space Grotesk"')` is true after ready, to fail loudly if the face is missing. (4) Add `/assets/fonts/space-grotesk-var.woff2` to the existing route warm-up loop (ci.yml:964) is unnecessary (it's a static asset), but DO confirm it 200s.
**Warning signs:** Baselines recaptured in CI still differ from local; `document.fonts.check(...)` returns false.

## Code Examples

### 1. Step guards + aggregator (D-01/D-02)
See Architecture Patterns §Pattern 1 above.

### 2. `expect.poll()` mailbox readiness (D-06)
Both `organizations.spec.ts:115-156` and `ga-uat-shift-left.spec.ts:74-109` have a byte-identical poll loop ending in `await page.waitForTimeout(1_000)`. Rewrite the `for` loop + sleep with `expect.poll`:

```typescript
// Source: Playwright expect.poll docs + existing helper structure
async function extractInvitationLink(page: Page, recipient: string): Promise<string> {
  let link: string | null = null;
  await expect
    .poll(
      async () => {
        const mailbox = (await page.evaluate(async () => {
          const r = await fetch('/dev/mailbox/json');
          return r.json();
        })) as { data: Array<{ to: string[]; html_body: string | null; text_body: string | null }> };
        const row = mailbox.data.find((e) => {
          const body = [e.html_body || '', e.text_body || ''].join('\n');
          return e.to.join(' ').includes(recipient) && body.includes('/invitations/');
        });
        if (row) {
          const body = [row.html_body || '', row.text_body || ''].join('\n');
          const m = body.match(/https?:\/\/[^\s"'<>]*\/invitations\/[^\s"'<>]*\/accept/);
          if (m) {
            const u = new URL(m[0], page.url());
            u.protocol = new URL(page.url()).protocol;
            u.host = new URL(page.url()).host;
            link = u.toString();
          }
        }
        return link !== null;
      },
      {
        message: `No invitation link found in mailbox JSON for ${recipient}`,
        intervals: [250, 500, 1000], // backoff; Playwright re-polls on the last interval
        timeout: 30_000,             // ≈ old 30 × 1s budget; keep generous for longpoll dev transport
      },
    )
    .toBe(true);
  if (!link) throw new Error(`No invitation link for ${recipient}`);
  return link;
}
```
**Notes:** the old loop allotted 30 attempts × ~1s = ~30s; keep `timeout: 30_000`. `expect.poll` interval values are Claude's-discretion (CONTEXT). Capturing `link` via closure avoids re-deriving it after the poll. Mind ESLint/type rules — `let link` then closure assignment is the simplest faithful port.

### 3. Self-hosted font + `document.fonts.ready` (D-08)
```css
/* test/example/priv/static/assets/css/app.css — example-only (loads last per root.html.heex:12) */
@font-face {
  font-family: 'Space Grotesk';
  src: url('/assets/fonts/space-grotesk-var.woff2') format('woff2-variations');
  font-weight: 300 700;          /* variable wght axis range */
  font-display: swap;            /* but the spec waits for fonts.ready, so swap reflow is captured-after-ready */
  font-style: normal;
}
:root {
  /* Override the daisyUI default so body text uses the brand font OS-independently. */
  --font-sans: 'Space Grotesk', ui-sans-serif, system-ui, sans-serif,
    'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
}
```
```typescript
// test/example/priv/playwright/tests/admin-design.spec.ts — extend the readiness helper
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  // D-08: wait for the brand webfont so element heights are font-stable before capture.
  await page.evaluate(async () => { await (document as any).fonts.ready; });
  // Optional hard guard — fail loudly if the face never loaded:
  // const ok = await page.evaluate(() => (document as any).fonts.check('16px "Space Grotesk"'));
  // expect(ok, 'Space Grotesk must be loaded before snapshot').toBe(true);
}
```
**Note:** `font-display: swap` + `await document.fonts.ready` means the page may briefly render fallback, but capture happens *after* the face loads — correct. Consider `font-display: block` to avoid any fallback frame, though `ready` makes it moot for screenshots.

### 4. Recapture job shape (D-09)
```yaml
# .github/workflows/ci.yml — new sibling job (reuse Phase-196 if: precedent)
  admin_design_recapture:
    name: Recapture admin-design baselines (in-CI)
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'   # schedule + main + dispatch only (Phase-196, ci.yml:515 etc.)
    needs: release_ref_guard
    permissions:
      contents: write                          # REQUIRED to commit PNGs (workflow default is read, ci.yml:26)
    services:
      postgres: { image: postgres:15, env: { POSTGRES_PASSWORD: postgres }, ports: ['5432:5432'],
        options: >- --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5 }
    steps:
      # ... identical boot prelude to example_playwright_smoke (checkout/setup/deps/compile/db/seeds/npm/install/boot/poll) ...
      - name: Recapture admin-design baselines
        working-directory: test/example/priv/playwright
        env: { CI: "true", SIGRA_EXAMPLE_URL: "http://localhost:4000" }
        run: |
          npx playwright test tests/admin-design.spec.ts \
            --project=admin-design-chromium \
            --project=admin-design-mobile \
            --project=admin-design-dark \
            --update-snapshots
      - name: Gate + commit recaptured baselines
        run: |
          # --allow each changed slug (or temporarily populate snapshot-allowlist-design).
          # NOTE: board-notice is the design canary — see Open Question 1 for how to handle it.
          bash scripts/ci/snapshot-canary-guard.sh \
            --base HEAD \
            --allowlist test/example/priv/playwright/snapshot-allowlist-design \
            --canary board-notice \
            $(for s in $(...changed slugs...); do printf -- '--allow %s ' "$s"; done)
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add test/example/priv/playwright/tests/admin-design.spec.ts-snapshots/
          git commit -m "ci(197): recapture admin-design baselines in ubuntu CI [skip ci]" || echo "no changes"
          git push
```
**Caveats:** `[skip ci]` prevents a recapture-commit from re-triggering CI. Pushing from a scheduled run to `main` requires branch-protection to allow the actions bot (or push to a branch + open a PR). **Whether to commit-to-main vs open-a-PR is a planning decision** — flag as Open Question 2.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `for` loop + `page.waitForTimeout(1000)` | `expect.poll(fn, {intervals, timeout})` | Playwright ≥1.30 | Deterministic, self-documenting fail message (D-06) |
| Capture without font sync | `await document.fonts.ready` | evergreen | Eliminates fallback-reflow flake (D-08) |
| `continue-on-error` to mask flaky visual lane | Root-cause font determinism + in-CI recapture, then hard-gate | this phase | Restores real signal (D-10) |

**Deprecated/outdated:**
- SEED-006's "brand webfont does not load in CI" framing — **factually wrong** (D-07); no webfont exists. Must be corrected in the seed and VERIFICATION (operator-truth requirement).
- ci.yml:1032-1042 comment block ("the brand webfont does not load in this dev-mode boot") — same false premise; rewrite when removing `continue-on-error`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Generating the woff2 once locally with python `fontTools` (4.62.1) and committing it is cleaner than running fonttools in the CI recapture job | Standard Stack | LOW — if the committed woff2 has issues, CI can install fonttools; verify the file renders before committing |
| A2 | `app.css` (last in cascade) is the durable home for `@font-face`+`--font-sans`; `sigra_admin.css` is avoided to dodge installer parity | Pitfall 3 | MEDIUM — if the design system requires the font in the *generated* admin shell too, scope expands to the installer template (but Deferred Ideas scopes that out) |
| A3 | Seeding one ≥25-event user does not perturb the 72 element-scoped design baselines (gallery boards render static literals) | Pitfall 5 | LOW — verified gallery markup is hardcoded (design_gallery_live.ex:611-833); the `/admin/users` list shows the seeded user but is not screenshotted by element-scoped boards |
| A4 | Launch consolidation (D-04a) yields near-zero wall-clock here because the 5 launches use disjoint `--project` sets and the staging step must sit between checkpoints and design | Pitfall 1 | LOW — this is an honest "modest win" finding CONTEXT D-04 already anticipates |

**Note:** No `[ASSUMED]` package claims — this phase installs nothing. All file/line claims are `[VERIFIED]` against live files this session.

## Open Questions

> **ALL THREE RESOLVED by Plan 04 (197-04-PLAN.md).** Retained below for provenance.

1. **[RESOLVED — Plan 04 Task 2] `board-notice` is the design-lane canary AND the font change alters every board including it.**
   - What we know: `snapshot-canary-guard.sh` forbids `modify` of the canary (line 104) but tolerates `added` (line 100); recapture-gate.sh sets `--canary board-notice` for the design lane.
   - **Resolution:** Plan 04 Task 2 (OQ1) treats the font-driven recapture as a **deliberate one-time canary re-baseline** — delete the existing `board-notice` PNGs in a recapture sub-step so `--update-snapshots` re-creates them as `added` (the guard's legitimate birth path), NOT allowlisted, NOT a forbidden `modify`. The tripwire stays armed for future incremental PRs.

2. **[RESOLVED — Plan 04 Task 2] Recapture commit target: push-to-main vs open-a-PR.**
   - What we know: D-09 says "commits the PNGs through `snapshot-canary-guard.sh`"; the job runs on schedule/main/dispatch (non-PR).
   - **Resolution:** Plan 04 Task 2 (OQ2) commits recaptured PNGs to a `ci/recapture-admin-design-<run_id>` branch and opens a PR (`gh pr create`) with a `[skip ci]` commit — baseline changes get human review under branch protection rather than a silent push to `main`.

3. **[RESOLVED — Plan 04 Task 3] Does any non-design lane depend on system-font metrics?** The font override changes `--font-sans` globally (`:root`). `admin-checkpoints` is fixed-viewport and tolerant (SEED-006 asymmetry), and demo-showcase has its own baselines.
   - **Resolution:** Plan 04 Task 3 (OQ3) runs admin-checkpoints and demo-showcase in **COMPARE mode only** (no `--update-snapshots`) against the font-loaded app. If both pass within tolerance, scope stays admin-design (recorded in SUMMARY). If either shifts, it is **deferred to a tracked todo** with a concrete per-lane recapture command + allowlist/canary — NOT an unscoped mid-run recapture (which would risk arming/disarming the wrong canary). Plan 05's re-gate touches only the design lane, so a deferred sibling recapture does not block it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| python3 `fontTools` | woff2 generation (local, one-time) | ✓ | 4.62.1 | `pip install brotli` if woff2 save fails; or use any woff2 tool |
| `woff2_compress` / standalone `fonttools` CLI | alt woff2 path | ✗ | — | python `fontTools.ttLib` (above) |
| Brand TTF source | font asset | ✓ | `scripts/brand/fonts/SpaceGrotesk[wght].ttf` (136 KB, variable wght) | — |
| Playwright runtime + webkit/chromium | all browser lanes | ✓ (installed in CI per run) | vendored | — |
| GitHub Actions schedule/workflow_dispatch + `contents:write` | recapture job | ✓ trigger present; write is opt-in per job | — | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** woff2 CLI tools absent → use installed python fonttools (commit the artifact so CI needs nothing).

## Validation Architecture

> nyquist_validation is not explicitly disabled in config; included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Playwright `@playwright/test` (vendored) + bash CI assertions + ExUnit contract tests |
| Config file | `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `cd test/example/priv/playwright && CI=true npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium` (needs booted app on :4000) |
| Full suite command | The whole `example_playwright_smoke` lane (boot prelude + all 5 seams) — run via CI, or locally per `guides/recipes/local-development.md` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PW-01 | Each seam failure surfaces in one run | CI behavior | Force a single-spec failure; assert later steps still ran + job red via aggregator | ❌ Wave 0 — add an aggregator + a CI-level assertion or rely on the run itself |
| PW-01 | webkit still installed (regression guard) | infra assertion | grep ci.yml for `install --with-deps chromium webkit` | ✅ (manual/grep) |
| PW-02 | No fixed sleeps in browser-lane code | static check | `! grep -rn "waitForTimeout\|Process.sleep" test/example/priv/playwright/tests` | ✅ existing grep |
| PW-03 | Design gallery green in CI across 3 projects with font loaded | Playwright visual | `npx playwright test tests/admin-design.spec.ts --project=admin-design-{chromium,mobile,dark}` (CI) | ✅ spec exists; baselines need in-CI recapture |
| PW-03 | `continue-on-error` removed | static check | `! grep -n "continue-on-error: true" <design-gallery step>` in ci.yml | ✅ (manual/grep) |
| PW-03 | MG-5/6 no longer `test.fail()` | Playwright | the MG-5/6 test passes (seeded) or is explicitly skipped | ✅ spec exists |

### Sampling Rate
- **Per task commit:** the touched spec locally against a booted app; `grep` static checks for ci.yml edits.
- **Per wave merge:** full `example_playwright_smoke` in CI on the branch.
- **Phase gate:** design gallery hard-gates green in CI (no `continue-on-error`); `phase_51_*` and `phase_58_*` ci-contract tests stay green (they slice `ci.yml`; verify after edits — Phase 196 D-16 precedent).

### Wave 0 Gaps
- [ ] Aggregator step + (optional) a forced-failure verification of D-01 surfacing — mirror Phase-196 D-14's `force_fail_probe` idea if a deterministic proof is wanted.
- [ ] In-CI recapture of all 72 admin-design baselines (cannot pre-exist — that's the deliverable).
- [ ] Confirm `phase_51_install_golden_ci_contract_test.exs` / `phase_58_oauth_oa01_ci_contract_test.exs` still pass after ci.yml edits (they assert workflow structure). Note: phase51 contract test is **already red on main** per Phase-196 D-15 (being fixed in 196) — confirm 196 merged before relying on it green.

## Security Domain

Not applicable in the threat-modeling sense — this phase edits CI orchestration, test specs, one CSS file, and adds a committed font binary. Relevant guardrails:
- **Least privilege:** the new recapture job must scope `permissions: contents: write` at the **job** level only; the workflow default stays `contents: read` (ci.yml:24-26). Do not widen global permissions.
- **Supply chain:** the woff2 is generated from an in-repo brand TTF (`scripts/brand/fonts/`, OFL-licensed Space Grotesk per the logo SVG `<desc>`) — no third-party download. Commit the binary; CI consumes the committed asset (no network font fetch, no Google Fonts CDN dependency — which would also reintroduce nondeterminism).
- **No new external action/package** is introduced.

## Sources

### Primary (HIGH confidence) — live files read this session
- `.github/workflows/ci.yml` (lines 1-45 triggers, 872-1168 `example_playwright_smoke`, 1170-1179 generated-admin job header) — guards/aggregator/recapture targets, webkit install at 937, `continue-on-error` at 1043, readiness loops 953-968, Phase-196 `if:` precedent at 515/568/619/749/1173/1352
- `test/example/priv/playwright/playwright.config.ts` — `workers:1, fullyParallel:false`; projects using `Desktop Chrome` (chromium) and `iPhone 13` (webkit)
- `playwright-core/lib/server/deviceDescriptorsSource.json` — `iPhone 13.defaultBrowserType === "webkit"` (the webkit-not-droppable finding)
- `test/example/priv/playwright/tests/admin-design.spec.ts` — `waitForLiveViewReady` (15-19), MG-5/6 `test.fail()` (318-386), element-scoped board captures (70-80)
- `test/example/priv/playwright/tests/organizations.spec.ts:115-156` & `ga-uat-shift-left.spec.ts:74-109` — identical mailbox poll loops, `waitForTimeout(1_000)` at 152/106
- `test/example/priv/static/assets/default.css:9` (`--font-sans` system stack), `app.css` (last in cascade), `sigra_auth.css:16`; `root.html.heex:10-12` (CSS link order)
- `scripts/ci/snapshot-canary-guard.sh` (slug handling for `-admin-design-`, canary modify-forbidden) & `scripts/ci/snapshot-recapture-gate.sh` (verify-only, `--canary board-notice`) — neither captures/commits today
- `test/example/priv/playwright/snapshot-allowlist-design` (steady-state empty) + 72 committed admin-design baselines
- `test/example/lib/example_web/live/admin/design_gallery_live.ex:611-833` (static MG-5/6 markup) & `lib/sigra/admin/audit/query_params.ex:22` (`@default_limit 25`)
- `test/example/priv/repo/seeds.exs` (21-line empty stub)
- `scripts/brand/fonts/SpaceGrotesk[wght].ttf` (in-repo variable brand TTF); `python3 fontTools 4.62.1` available
- `.planning/phases/196-pr-fast-vs-nightly-broad-trigger-model/196-CONTEXT.md` — schedule cron + `if: github.event_name != 'pull_request'` precedent (live in ci.yml)
- `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` (D-11 fold)

### Secondary (MEDIUM confidence)
- Playwright `expect.poll` / `document.fonts.ready` semantics — standard, evergreen API knowledge applied to the verified call sites.

### Tertiary (LOW confidence)
- None — all load-bearing claims verified against files.

## Metadata

**Confidence breakdown:**
- Lane topology / guards (D-01/D-02): HIGH — exact step lines and the staging-step interaction verified
- D-04 levers: HIGH — webkit-not-droppable is hard-verified; consolidation win is honestly small
- Readiness (D-05/D-06): HIGH — both `waitForTimeout` sites are the only fixed sleeps; rewrite is mechanical
- Font determinism (D-07/D-08): HIGH — no webfont served (verified); woff2 tooling present; cascade home identified
- Recapture (D-09): HIGH on mechanics, MEDIUM on policy (canary handling + commit target are Open Questions 1-2)
- MG-5/6 (D-11): HIGH — root cause is real-page pagination + 25-event threshold + empty seeds, all verified

**Research date:** 2026-06-20
**Valid until:** ~2026-07-20 (ci.yml is actively edited by adjacent phases 194-198; re-verify line numbers and confirm Phase 196 merged before relying on its `if:`/ci-gate precedent and the phase51 contract test being green)
