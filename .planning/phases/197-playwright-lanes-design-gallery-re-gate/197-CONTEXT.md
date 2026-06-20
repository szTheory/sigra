# Phase 197: Playwright Lanes & Design-Gallery Re-Gate - Context

**Gathered:** 2026-06-20 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

CI/test-infra only (v1.40 CI-PERF milestone). Scope is the `example_playwright_smoke`
job in `.github/workflows/ci.yml` and the Playwright specs/config it runs. Three
requirements: PW-01 (lane critical path + failure surfacing), PW-02 (deterministic
readiness), PW-03 (re-gate the `continue-on-error` admin-design gallery, folding SEED-006).

**Out of scope:** library auth code, generated-host output, the other CI long poles
(`library_tests`, `library_tests_dep_off` — those were Phase 195), and the `mix ci` /
acceptance-gate work (Phase 198, DX-01/GATE-01/GATE-02). No new product surfaces.
</domain>

<decisions>
## Implementation Decisions

### PW-01 — Lane topology: failure-surfacing without matrix sharding

- **D-01:** Add `if: ${{ !cancelled() }}` (equivalently `if: success() || failure()`) to
  **every** `npx playwright test` step in `example_playwright_smoke` so an early step
  failure no longer aborts the job and skips later independent steps. All step failures
  surface in a single run (satisfies success criterion 1a). Currently every test step
  (`ci.yml` ~982–1090) has no `if:` guard, so the first failure masks the rest — the
  documented cause of this milestone's multiple ~25m round-trips.

- **D-02:** Add a final aggregating step (`if: always()`) that fails the job if any test
  step's outcome was `failure`, so `!cancelled()`-guarded steps still hard-gate. Do NOT let
  the guards silently swallow failures — the job must still go red, just AFTER running all
  steps.

- **D-03:** Do **NOT** matrix-shard the lane across parallel jobs. The boot prelude
  (`mix deps.get` → `mix compile --warnings-as-errors` → `ecto.create`/`migrate` →
  `mix run priv/repo/seeds.exs` → `npm ci` → `npx playwright install --with-deps`) is the
  dominant fixed cost and would be re-paid per shard; `playwright.config.ts` is
  `workers: 1, fullyParallel: false` (deliberate — shared DB state), so shards cannot safely
  run concurrently against one app and per-shard app+DB re-boot is net-negative. Critical-path
  reduction (criterion 1b) comes instead from consolidating serial `npx playwright test`
  process launches and trimming the prelude.

- **D-04:** Wall-clock reduction levers for criterion 1b (researcher to quantify, pick the
  evidence-backed subset): (a) consolidate multiple serial `npx playwright test` invocations
  into fewer invocations (one launch can pass many specs + `--project` flags, removing
  repeated Playwright runner startup); (b) drop unused browser installs — confirm whether
  `webkit` (in `npx playwright install --with-deps chromium webkit`) is actually exercised by
  any project; if not, install chromium only. The wall-clock win via this route is modest
  (test execution is serial-by-design); the failure-surfacing win (D-01) is the larger
  reliability gain. Honest tradeoff to record in VERIFICATION if criterion 1b is only modestly
  met.

### PW-02 — Deterministic readiness

- **D-05:** Keep the bash `for i in $(seq 1 30); curl -sf http://localhost:4000/; sleep 1`
  loop (`ci.yml:954–961`) and the route warm-up loop (`ci.yml:962–969`) — both are explicit
  poll-until-ready probes (the warm-up loop is justified against `plug_init_mode: :runtime`
  compile-on-demand), NOT blind sleeps. There is **no `Process.sleep` in browser-lane code**
  (only in deps and AGENTS.md guidance), so PW-02's letter is already met for the infra.

- **D-06:** Replace the two `await page.waitForTimeout(1_000)` calls — `organizations.spec.ts:152`
  and `ga-uat-shift-left.spec.ts:106`, both inside `/dev/mailbox` poll loops — with explicit
  polling via `expect.poll()` (re-query the mailbox until the invitation link appears, with a
  Playwright-managed interval/timeout), removing the fixed 1s sleeps. These are the only
  fixed-duration waits in browser-lane test code.

### PW-03 — Font determinism + in-CI recapture (USER-CONFIRMED root-cause reframing)

- **D-07 (CORRECTS SEED-006 premise):** SEED-006's stated root cause — "the brand webfont
  (Space Grotesk) does not load in the CI dev boot" — is **factually wrong**. Independent
  verification found **no webfont served anywhere**: no `@font-face`, no `*.woff*`, no Google
  Fonts link in `test/example/assets` or `priv/static/assets/*.css`; served CSS uses system
  stacks only (`default.css` `--font-sans: ui-sans-serif, system-ui, …`). The gallery route is
  `/admin/_design` on the same `mix phx.server` app (`router.ex:186–193`), so local capture
  and CI capture hit identical CSS. The real cause of the ~20–53px reflow is a **host-OS
  system-font metric difference** — macOS (local capture box) resolves `system-ui` to a
  different font with different line-heights than ubuntu (`ubuntu-latest` CI runner). Element-
  scoped boards (`locator('#board-xxx')`) reflow taller; fixed-viewport `admin-checkpoints`
  stays green. The SEED-006 doc and any VERIFICATION must record this correction (operator-truth
  requirement) — the brand "webfont loads" framing in ROADMAP success criterion #3 was built on
  a false premise.

- **D-08 (USER-CONFIRMED):** Remediation = **bundle a self-hosted brand font + recapture
  in-CI**. Concretely: (1) ship Space Grotesk as a self-hosted `@font-face` (woff2 under the
  example's `priv/static`) and set it as the served `--font-sans` so render is **OS-independent**
  in both local capture and CI; (2) add `await document.fonts.ready` to the design spec
  (`beforeEach` / extend `waitForLiveViewReady`) so capture waits for font load; (3) recapture
  ALL `admin-design-*` baselines in the CI (ubuntu) environment via a recapture job. This makes
  criterion #3 *literally* true (a brand font now loads), and closes the brand-truth gap that
  logos are currently outlined-only with no brand font on body text. Chosen over (a)
  recapture-in-CI-only (render stays OS-dependent → local diverges from CI baselines) and
  (b) a pinned CI-available fallback like Liberation Sans (lower fidelity, not brand type).

- **D-09:** In-CI recapture runs as a dedicated **`workflow_dispatch`** job (or folds into the
  Phase-196 nightly `schedule:` lane) — NOT inline in the PR-gating job. `snapshot-recapture-gate.sh`
  is a *verify-after-local-update* gate (compare-mode + canary-guard; it does NOT `--update-snapshots`
  or commit). The new job boots the app on the runner, runs
  `npx playwright test tests/admin-design.spec.ts --project=admin-design-{chromium,mobile,dark}
  --update-snapshots`, then commits the PNGs through `snapshot-canary-guard.sh` with an explicit
  `--allow`/allowlist for the recaptured slugs (steady-state allowlist is empty). Reuse the
  Phase-196 trigger precedent (`if: github.event_name != 'pull_request'`, `schedule:` cron at a
  non-colliding minute).

- **D-10:** Once render is deterministic and baselines are recaptured in-CI, **remove
  `continue-on-error: true`** from the "Run design gallery boards" step (`ci.yml:1043`) — the
  gallery hard-gates on the PR path again. **Keep it inline** in `example_playwright_smoke`
  (do NOT move to nightly) — success criterion #4 and the phase goal require it to hard-gate,
  and it already shares the booted app. Nightly relocation (SEED-006 option 3) is the documented
  fallback only if it remains fragile after the font fix.

### Folded Todos

- **D-11 (MG-5/6, folds `2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md`):**
  Resolve the MG-5/6 content-equivalence `test.fail()` (admin-design.spec.ts) — required by
  success criterion #4 ("MG-5/6 data dependency resolved or explicitly skipped with a recorded
  reason"). **Preferred:** seed one user with ≥25 audit events in the gallery fixture so
  pagination renders deterministically, then remove `test.fail()`. **Bounded fallback** (if
  seeding perturbs other boards' deterministic captures): convert `test.fail()` →
  `test.skip('data-dependent pagination; tracked in <todo>')`. Avoid `test.fail()` standing —
  it spuriously passes if pagination ever appears.

### Claude's Discretion

- Exact `if:` expression form (`!cancelled()` vs `success() || failure()`), the aggregating-step
  implementation, the cron minute, the woff2 source/subset, and the `expect.poll` interval/timeout
  values — all implementation-level, decisively defaulted by the planner per METHODOLOGY.md
  (none cross the staff-architect-contract escalation threshold).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` — gallery fragility
  source (NOTE: its stated webfont root cause is corrected by D-07).
- `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` — milestone baseline + audit
  playbook; gallery lane placement is in scope there too.
- `.planning/REQUIREMENTS.md` — PW-01/02/03 wording (lines 31–33), GATE guardrails (51–52).
- `.planning/phases/196-pr-fast-vs-nightly-broad-trigger-model/196-CONTEXT.md` — `schedule:`
  cron + `if: github.event_name != 'pull_request'` + `ci-gate` skipped-as-non-failing
  precedent (D-09 reuse).
- `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` —
  folded (D-11).
- `.github/workflows/ci.yml` — `example_playwright_smoke` job (~872–1090); `continue-on-error`
  at 1043; readiness loops 954–969; Phase-196 trigger precedent at 13, 515, 1170–1173.
- `test/example/priv/playwright/playwright.config.ts` — `workers:1, fullyParallel:false`,
  project partitioning.
- `test/example/priv/playwright/tests/admin-design.spec.ts` — element-scoped boards;
  `waitForLiveViewReady` (15–18); MG-5/6 `test.fail()` block.
- `scripts/ci/snapshot-recapture-gate.sh` + `scripts/ci/snapshot-canary-guard.sh` — recapture
  verify gate + empty-allowlist drift guard (neither captures/commits today).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase-196 conditional-job trigger model (`schedule:` cron, `if: github.event_name != 'pull_request'`,
  `ci-gate` treating `skipped` as non-failing) — directly reusable for the D-09 recapture job.
- `snapshot-canary-guard.sh` allowlist mechanism — the commit path for recaptured baselines.
- `waitForLiveViewReady` (admin-design.spec.ts:15–18) — the established explicit-readiness pattern
  to extend with `document.fonts.ready` (D-08).
- `scripts/brand/fonts/SpaceGrotesk[wght].ttf` — brand font binary already in-repo (source for the
  D-08 self-hosted woff2; subset/convert as needed).

### Established Patterns
- One shared booted `mix phx.server` (MIX_ENV=dev) feeds all Playwright steps in the lane; specs
  run serially (`workers:1`) against shared DB state — a deliberate correctness constraint that
  rules out naive in-process or cross-shard parallelism (D-03).
- WR-04 stdout/stderr redirect + failure-dump step idiom for backgrounded server logs (ci.yml:944–952,
  1077–1085).
- Visual baselines are committed PNGs under `*.spec.ts-snapshots/`, drift-guarded by an
  empty-allowlist canary; viewport captures (`admin-checkpoints`) tolerate metric deltas,
  element-scoped captures (`admin-design`) do not (the SEED-006 asymmetry).

### Integration Points
- New/edited `if:` guards + aggregating step land inside `example_playwright_smoke` (`ci.yml`).
- New recapture job is a sibling job in the same `ci.yml`, gated to non-PR events (D-09).
- `@font-face` + `--font-sans` change lands in the example's served CSS
  (`test/example/priv/static/assets/css/default.css` and/or `app.css`) + a woff2 in `priv/static`.
- `expect.poll` rewrites touch `organizations.spec.ts` and `ga-uat-shift-left.spec.ts` only.
</code_context>

<specifics>
## Specific Ideas

- PW-03 remediation is the user-confirmed "bundle self-hosted font + recapture in-CI" path
  (chosen over recapture-only and pinned-fallback), explicitly because it makes render
  OS-independent for BOTH local and CI and closes the outlined-logo-only brand-truth gap.
- The SEED-006 root-cause correction (no webfont exists; it's a system-font OS metric delta)
  must be written back into the seed/VERIFICATION, not silently fixed.
</specifics>

<deferred>
## Deferred Ideas

- Broader webfont adoption across non-design admin/auth/demo surfaces — out of scope; D-08
  bundles the font for render determinism, not as a design refresh.

### Reviewed Todos (not folded)
- `2026-06-18-token-reference-completeness-ci-guard.md` — admin-token-reference completeness CI
  guard; different concern (not a Playwright-lane/font/readiness issue). Not folded.
- `2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` — `fast_checks` installer
  CI-contract drift (Phase-194 fold-in); not a browser-lane issue. Out of Phase-197 scope; known
  pre-existing item.
- `2026-06-17-page04-branding-explicit-scoring.md` — admin-UI quality-ledger scoring; not CI-lane.
  Not folded.
</deferred>
