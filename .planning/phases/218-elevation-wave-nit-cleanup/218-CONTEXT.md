# Phase 218: Elevation Wave + Nit Cleanup - Context

**Gathered:** 2026-07-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Run **every admin/operator surface + the L1/L2 component fractal** through the full harness
loop built in Phases 216–217 (render → deterministic probes → 4-lens LLM panel → dedup fix
queue → safe auto-fix), **verify-then-climb** each cell, fold in the two carry-forward nit
todos (UI-01 demo-DX, UI-02 Tasklane rebrand residuals) plus the two `resolves_phase:218`
harness-debt todos, and land it as **one reviewable PR** where the operator signs off only on
residual judgment calls + earned gradient raises — not an open-ended issue hunt.

**Out of this phase (hard boundaries):**
- **No baseline PNG recapture** — the ~115 committed baselines are recaptured in-CI (ubuntu)
  in **Phase 219** (RECAP-01). This wave only *reads* the render's `screenshot.png` for the
  before/after strip.
- **No new admin surfaces** — elevation/verification of existing cells only.
- **LLM panel never becomes a merge gate** (JUDGE-CI-01) — advisory/off-CI throughout.
- **Do not reopen locked 217 D-13** (CSS auto-apply stays out of the auto-fix rail).
- FEAT-01/02/03, SEED-005 (Playwright per-shard-DB), non-admin/auth surfaces stay deferred.
</domain>

<decisions>
## Implementation Decisions

### A. Wave scope & surface enumeration

- **D-01: Surfaces = the 8 L3 quality-ledger cells; fractal = the 36-cell inventory,
  rendered via the `/admin/_design` gallery boards — NOT by booting live routes.**
  The 8 L3 surfaces are `index-live`, `organization-live`, `users-index-live`,
  `user-show-live`, `user-sessions`, `audit-index-live`, `audit-user-live`, `branding-live`
  (`guides/reference/admin-quality-ledger.md` L85-92). The fractal = 1 L0 + 13 L1
  (`board-stat`…`board-audit_row`) + 11 L2 (`board-mg-1`…`board-mg-11`) + 8 L3 + 3 L4 = 36.
  L1/L2 are captured through `design_gallery_live.ex` static board fixtures (populated / zero /
  loading / error), preserving 216 D-02 ("static gallery, no per-test DB fixtures"). L3 cells
  are re-verified through their **representative gallery boards**, not live-route captures.

- **D-02: The wave's FIRST unit of work is render-matrix expansion.** The committed ledgers
  (`admin-render-sha.json`, `admin-award-ledger.json`) currently hold only the **2-pilot / 4-cell**
  slice from 216-07, even though `admin-eval.spec.ts` already renders all 11 L2 boards and
  `fix-queue.json` already carries 117 findings across mg-1..11. Promote the **full matrix** into
  the committed ledgers: all 11 L2 boards + the 13 L1 boards (needs an `admin-eval.spec.ts`
  extension — it currently iterates only `GROUP_BOARDS` mg-1..11, not the L1 boards) + the
  **6 not-yet-mapped L3 surface→board proxies** (`index`, `organization`, `user-sessions`,
  `audit-index`, `audit-user`, `branding` — the 2 pilots mg-2/5 = users-index, mg-9/10/11 =
  user-show are already mapped). `admin-panel.sh --all` and `award-guard.mjs` only see surfaces
  present in `admin-render-sha.json`, so this expansion is the precondition for SC-1.

### B. Wave orchestration / plan decomposition

- **D-03: Decompose per-surface-group, not per-cell.** Natural plan units:
  (1) **harness-hardening** — matrix expansion (D-02) + first-nav flake fix (D-09) + probe-ids
  single-source fold (D-08); (2) **L2 fractal** (mg-1..11); (3) **L1 fractal** (13 component
  boards); (4) **L3 surface verify-then-climb** (8 surfaces via board proxies); (5) **UI-01**
  (`scripts/uat`); (6) **UI-02** (`test/example` authed screens); (7) **ELEVATE-03 batched-PR
  assembly**. The existing `admin-eval-harness.sh --all` render + `admin-panel.sh --all` fan-out
  drive the loop; a "plan" = one surface group's verify-then-climb, matching the ledger's climb
  granularity. (Planner may merge/split, but avoid 36 per-cell micro-plans.)

### C. Panel execution & climb posture (OPERATOR DECISIONS)

- **D-04: The LLM panel IS run — locally, operator-driven, `admin-panel.sh --all --changed-only`.**
  Operator supplies `ANTHROPIC_API_KEY`; the content-hash skip cache (`admin-panel-verdicts.json`,
  keyed on `render_sha256`) keeps re-runs ~free, and a missing key hard-degrades to `exit 0`
  (JUDGE-CI-01). Panel output lands in the **parallel** `panel-findings.json` per cell — NEVER
  merged into `findings.json`, never enters the deterministic `open_findings` count, never gates.
  It feeds the fix queue only as advisory `judgment`/`component` entries and informs the operator's
  gradient-raise decisions.

- **D-05: Climb posture = verify-hold + selective earned raises (honesty-first).** Re-verify
  every cell **holds Tier-2 against rendered output** (this is the primary yield — catching any
  optimistically cite-and-flipped cell). Raise an award sub-score ONLY where the rendered evidence
  + panel clearly earn it; each raise is protected by the findings-count-monotonic guard. Do **not**
  climb broadly to look like progress — over-claiming on cells that merely "hold" weakens the
  operator-truth guarantee the milestone is built on. Most raises land as operator PR sign-off
  decisions (ELEVATE-03), not automated bumps.

### D. Auto-fix reality & the CSS-token seam

- **D-06: Auto-fix applies ≈0 fixes this wave; the wave is deterministic-probe + operator-panel
  driven.** Of the current 117 fix-queue findings, ~103 are `judgment` (misalignment `warn`), 1 is
  `component` (human), and the 13 `token`-eligible findings all cite **CSS-class anchors on
  `.error`-state cells** whose off-scale radius/shadow live in `sigra_admin.css` — which
  `fix-apply.mjs` **refuses** (locked 217 D-13: CSS 3-lockstep golden-diff hazard → downgraded to
  judgment). **Do not reopen D-13** to unblock CSS auto-apply. The 13 CSS-anchored off-scale
  findings are eligible for **manual operator fix in the PR** (a direct `sigra_admin.css` token
  correction is fine — it just can't ride the auto-apply rail). `open_findings` is currently 0
  (all `warn`-severity), so nothing is gate-blocking today.

### E. Baseline recapture seam (defer to 219)

- **D-07: No baseline PNG recapture in this phase.** Phase 219 (RECAP-01) recaptures the ~115
  committed baselines **in-CI on ubuntu** (darwin-local recapture is prohibited — see
  `reference_admin_design_baselines_ci_native`). This wave uses each render's `screenshot.png`
  only for the ELEVATE-03 before/after strip. **Flag for the planner:** the expanded matrix (D-02)
  may introduce new board captures whose baselines don't yet exist — coordinate that recapture set
  with Phase 219 rather than committing new darwin-captured PNGs here.

### F. Harness-debt todos (folded — do early, in the harness-hardening plan)

- **D-08: Fold `probe-ids-single-source-d12`.** `probes.ts` imports `PROBE_IDS` from
  `scripts/ci/lib/eval-probe-ids.mjs` (the canonical list the guards already use); if the Playwright
  CJS/ESM transform can't resolve it, add a cheap deep-equal self-test instead of leaving two
  hand-maintained arrays. Remove the `// FOLLOW-UP(216)` marker. Do before matrix expansion — a
  larger surface set raises the drift risk.

- **D-09: Fold `admin-eval-first-nav-flake`.** Switch `page.goto(...)` to
  `waitUntil:'domcontentloaded'` + explicit `waitForLiveViewReady` (already exists), and consider
  lowering the per-nav timeout so a stuck first-nav fails fast into its retry instead of hanging
  ~16 min. Do early — 16 first-nav flakes at 4 cells scale badly across a 36+-cell matrix. Verify
  by re-running `scripts/ci/admin-eval-harness.sh` and confirming near-zero `flaky` count.

### G. UI-01 / UI-02 folding (independent plans, same PR, no harness-loop interaction)

- **D-10: UI-01 (`scripts/uat/up.sh` demo-DX nits) = its own plan.** Flag-inert warnings
  ("ignored in <mode> mode" for cross-mode no-op flags), `--status` re-probe with
  `curl -fsS --max-time 2` inside `print_status`, host-run `wait_for_http` bump to ~120s (or
  detect "Compiling" and extend), and stale leaked-UAT-stack reap. Optionally live-exercise the
  `--dev` host-run + bind-mount hot-reload paths (only static-checked so far).

- **D-11: UI-02 (`test/example` authed-screen daisyUI→vt-* residuals) = its own plan.**
  `mfa_settings_live.ex` enrollment sub-flows (QR step, backup-codes grid, passkey rows →
  `vt-panel` / `.vt-form .input`); `organization_members_live.ex` confirm modals + invite form
  (build a `vt-modal` / restyle native `<dialog>` + `.vt-form`); confirm whether
  `mfa_challenge_html.ex` + `mfa_challenge_controller.ex` are reachable (unwired vs live
  `/users/mfa`) — remove if dead, else wrap in `vt-auth`; optionally set `geo_*` / parsed-UA on
  seeded sessions in `seeds.ex` for demo realism. Cosmetic (`--no-tailwind` demo), non-blocking;
  touches no `scripts/ci`, `scripts/panel`, or `admin-eval` files.

### H. ELEVATE-03 PR shape

- **D-12: Single reviewable PR with a before/after render strip + narrowed options per judgment
  call.** Operator review is bounded to approval of residual judgment calls + earned gradient
  raises. Use `gsd-pr-branch` to filter `.planning/` commits out of the review branch.

### Folded Todos
- `2026-07-04-probe-ids-single-source-d12` → D-08
- `2026-07-04-admin-eval-first-nav-flake` → D-09
- `2026-06-19-uat-demo-dx-polish-nits` (UI-01) → D-10
- `2026-06-22-vaultr-authed-rebrand-residuals` (UI-02) → D-11

### Claude's Discretion
- Exact plan count / merge-split within the D-03 grouping (avoid per-cell micro-plans).
- The concrete 6 L3→gallery-board proxy mappings (author against `design_gallery_live.ex`
  fixtures + `admin-quality-ledger.md` evidence, mirroring the mg-2/5 and mg-9/10/11 pilots).
- Whether the 13 CSS-anchored token findings get hand-fixed this wave or surfaced as
  operator judgment calls in the PR (D-06 allows either; honesty-first).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 218 detail (Goal, SC-1..3, ELEVATE-01/02/03)
- `.planning/phases/216-harness-foundation-award-gradient/216-CONTEXT.md` — deterministic harness decisions (D-02 static gallery, probes, stale-render guard, award sub-score ledger, monotonic guard)
- `.planning/phases/217-adversarial-panel-auto-fix-safety-rails/217-CONTEXT.md` — LLM panel + auto-fix decisions (D-01..D-14; JUDGE-CI-01, finding_id contract, D-13 CSS-out-of-scope, fix-queue)
- `guides/reference/admin-quality-ledger.md` — the 8 L3 surfaces + the 36-cell fractal inventory
- `guides/reference/admin-award-ledger.json` — award sub-score cells (currently 2 pilots — D-02 expansion target)
- `guides/reference/admin-render-sha.json` — render_sha256 per cell; the `--all` surface source of truth
- `guides/reference/admin-panel-verdicts.json` — content-hash skip cache (keyed on render_sha256)
- `guides/reference/fix-queue.json` — 117 findings; the ~0-auto-apply reality (D-06)
- `guides/reference/settled-findings.tsv` — settled/waiver OPEN-set sibling of the fix queue
- `scripts/ci/admin-eval-harness.sh` — the render orchestrator (`--all`)
- `scripts/ci/admin-panel.sh` — operator panel fan-out (`--all --changed-only`; API-key hard-degrade)
- `scripts/ci/award-guard.mjs` — verify-then-climb monotonic guard
- `scripts/ci/quality-findings-monotonic.sh` — findings-count-monotonic gate
- `scripts/ci/lib/eval-probe-ids.mjs` — canonical PROBE_IDS (D-08 single-source target)
- `scripts/ci/fix-queue-build.mjs` — fix-queue builder (open = built − settled)
- `scripts/panel/{judge,lenses,panel-schema,excerpt,fix-apply}.mjs` — panel + auto-fix rails (fix-apply refuses CSS)
- `test/example/priv/playwright/tests/admin-eval.spec.ts` — render spec (GROUP_BOARDS mg-1..11; needs L1-board + L3-proxy extension per D-02)
- `test/example/priv/playwright/lib/eval/probes.ts` — the 9 probes + duplicated PROBE_IDS (D-08)
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — L1/L2 board fixtures
- `.planning/todos/pending/{2026-07-04-probe-ids-single-source-d12,2026-07-04-admin-eval-first-nav-flake,2026-06-19-uat-demo-dx-polish-nits,2026-06-22-vaultr-authed-rebrand-residuals}.md`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The **entire harness loop already exists** (216/217): render orchestrator, 9 deterministic
  probes, stale-render + evidence-anchor guards, award sub-score ledger + monotonic guard, the
  4-lens LLM panel with k=3/≥2 consensus + content-hash skip cache, the fix-queue builder, and
  the auto-fix apply/revert rails. This wave *drives* that machinery — it does not build new
  harness primitives.
- `admin-eval-harness.sh --all` + `admin-panel.sh --all --changed-only` are the two commands the
  wave runs per iteration.

### Established Patterns
- **cite-and-flip defense:** evaluate RENDERED output, never code; the stale-render guard rejects
  bundles whose `app_git_sha != HEAD` (verify-then-climb only trusts a clean-tree render).
- **JUDGE-CI-01:** LLM panel is `scripts/panel/` (advisory) vs `scripts/ci/` (deterministic gates);
  a missing `ANTHROPIC_API_KEY` can only ever `exit 0`.
- **finding_id = sha256(surface \0 class \0 anchor)** — one key space across panel findings,
  settled-findings waivers, and the fix queue.
- **Static gallery over live routes** (216 D-02) — L1/L2/L3 all captured via `/admin/_design`
  board fixtures, no per-test DB seeding.

### Integration Points
- **Ledger asymmetry (the load-bearing gap):** `admin-render-sha.json` / `admin-award-ledger.json`
  = 2 pilots, but `admin-eval.spec.ts` renders mg-1..11 and `fix-queue.json` spans all of them.
  D-02 closes this by promoting the full matrix into the committed ledgers.
- **`admin-eval.spec.ts` iterates only `GROUP_BOARDS` (mg-1..11)** — the 13 L1 boards
  (`board-stat`…) are rendered by `admin-design.spec.ts`, not the eval spec; capturing L1 into the
  eval matrix needs a spec extension.
- **`fix-apply.mjs` refuses CSS files** — `.heex`/inline-style under admin+example only; the CSS-
  resident token findings route to the human/operator queue (D-06).
- **UI-01/UI-02 touch only `scripts/uat/up.sh` and the demo app's authed screens** — zero overlap
  with the admin harness loop; they ride the same PR but plan independently.
</code_context>

<specifics>
## Specific Ideas

- Operator (Jon) will run the panel locally with his `ANTHROPIC_API_KEY`, `--changed-only`, so
  first-run token spend is bounded and re-runs are ~free via the skip cache.
- Verify-hold is the primary deliverable; earned raises are the exception, decided at PR sign-off.
- The 6 not-yet-mapped L3→board proxies should mirror the two documented pilots
  (mg-2/5 = users-index, mg-9/10/11 = user-show).
</specifics>

<deferred>
## Deferred Ideas

- **Baseline PNG recapture / canary reconciliation** → Phase 219 (RECAP-01), ubuntu/CI-native.
- **Unblocking CSS-token auto-apply** → stays locked (217 D-13); not this milestone.

### Reviewed Todos (not folded)
- `2026-06-20-playwright-parallelization-per-shard-db` (SEED-005) — CI-perf, explicitly out of milestone scope.
- `2026-06-20-mix-sigra-migrate-schema-helper` (FEAT-02) — config/installer feature, deferred milestone.
- `2026-06-20-runtime-auth-prefix-override` (FEAT-01) — config feature, deferred.
- `2026-06-22-white-label-auth-email-theming` (FEAT-03) — non-admin/auth theming, deferred.
- `2026-07-02-app-css-corruption-guard-blind-spot` — CI-guard hardening (not admin-UI elevation); v1.43 already added the base guard. Defer unless it bites the UI-02 CSS work.
- `2026-07-03-hex-retire-stray-1-20-0` — Jon-manual release chore, not roadmap work.
</deferred>
