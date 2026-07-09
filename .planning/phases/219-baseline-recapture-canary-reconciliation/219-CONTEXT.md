# Phase 219: Baseline Recapture + Canary Reconciliation - Context

**Gathered:** 2026-07-09 (assumptions mode + deep research pass)
**Status:** Ready for planning

<domain>
## Phase Boundary

After the Phase 218 elevation wave, recapture **all 115 committed Playwright PNG baselines
in-CI on ubuntu/amd64** (never darwin-local), reset both snapshot allowlists to empty
steady-state, and land with the **snapshot-canary drift guard + generated-host parity green**.
Fold in the one hard prerequisite the wave left behind: the example `<.icon style=>` compile
blocker. Zero-human on pixels; the operator's only review is the git-diff scope check (named
slugs), not per-pixel eyeballing.

**Baseline inventory (exact, `git ls-files` verified):**
- **84** admin-design (28 boards × chromium/mobile/dark) — canary `board-notice`
- **27** admin-checkpoints (9 slugs × chromium/mobile/dark) — canary `impersonation-banner`
- **4** demo-showcase (chromium-only) — no canary
- **= 115 total**

**Out of this phase (hard boundaries):**
- **No award-ledger lock / harness runbook / milestone-ship PR** — that is Phase 220 (RATIFY-01).
- **No new admin surfaces, no elevation/climb work** — 218 is done; 219 only re-baselines.
- **No installer-template drift fixes** (WR-01/02 `rename_passkey` scope + delete-passkey copy)
  — those need a golden rebless and are a separate `/gsd-code-review 218 --fix` concern. The
  219 icon fix is **example-only** and does NOT touch `priv/templates/**`.
- **Never recapture admin-native baselines on darwin** — render is OS-independent (self-hosted
  Space Grotesk woff2 + `document.fonts.ready`) but arm64↔amd64 sub-pixel AA parity is unproven.
- LLM panel stays advisory/off-CI (JUDGE-CI-01). SEED-005 (per-shard-DB Playwright) deferred.
</domain>

<decisions>
## Implementation Decisions

### A. Branch base & topology

- **D-01: Phase 219 branches off `main`; PR #70 (`elevate-03-wave-v144-pr`) is stale and gets
  closed.** `main` (HEAD `8918d897`) strictly subsumes the wave branch: both carry the same
  217+218 wave as parallel cherry-picks, but `main` *additionally* has the gap-closure
  (218-07…10) and the install-golden rebless `ec4dfd12` — neither is on PR #70. The icon
  blocker and all 115 baselines already live on `main`. Do NOT rebase or reconcile PR #70;
  branch fresh off `main` and close #70 as subsumed.

### B. Compile-blocker prerequisite (do first)

- **D-02: Fix the `<.icon style=>` compile blocker before any recapture — add `attr :rest,
  :global` + spread `{@rest}` to the example's `icon/1`.** Empirically verified: `mix compile
  --warnings-as-errors` fails with `undefined attribute "style" for component icon/1` at
  `test/example/lib/example_web/live/mfa_settings_live.ex:250,328`; the example `icon/1`
  (`test/example/lib/example_web/components/core_components.ex:444-451`) declares only
  `:name` + `:class`. This kills every recapture/smoke/parity job at the compile step before
  Playwright boots. Fix in ONE place (durable, recurrence-proof). **Example-only — no
  `priv/templates/**` change, no golden rebless.** (Alt considered: drop the inline `style`;
  rejected — `:global` is more durable and inconsequential divergence from pristine phx.new
  since it's the example host app, not installer output.)

### C. Recapture mechanism & trigger

- **D-03: Reuse the two existing ubuntu recapture jobs; add demo-showcase recapture; unify the
  canary delete-rebirth.** `admin_design_recapture` (ci.yml:1497) and `admin_checkpoint_recapture`
  (ci.yml:1798) already encode the correct amd64-native `--update-snapshots` → guard → open-PR
  flow. Three gaps to close:
  1. **demo-showcase (4 PNGs) has no recapture path** — add a single
     `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium
     --update-snapshots` step (cheapest: fold into the checkpoint job's existing :4000 boot) +
     commit the 4 PNGs. No canary/allowlist choreography (the lane has neither).
  2. **The checkpoint job does NOT delete-reborn its canary** (only the design job does) — add
     the equivalent `find … -name 'impersonation-banner-admin-checkpoints-*.png' -delete`
     before `--update-snapshots` so the canary re-appears as `added` (guard-tolerated), not
     `modified` (guard-forbidden).
  3. **Correct the stale `ci.yml:1490,1611` comments** ("72 admin-design / 24 boards") → now
     84 PNGs / 28 boards × 3.

- **D-04: Trigger recapture via a branch-scoped CI dispatch so amd64-native pixels land on the
  219 branch with all gates green BEFORE merge (OPERATOR DECISION — chosen over post-merge and
  local-act).** Today the recapture jobs skip PRs (`push` watches only `main`) and
  `workflow_dispatch` is blocked by `release_ref_guard` (requires a `refs/tags/v*` ref). Add a
  **small, surgical ci.yml path**: a `workflow_dispatch` input (e.g. `recapture_branch`) that
  lets the existing amd64 recapture jobs run against the 219 branch — bypassing the `v*`-tag
  guard for recapture-only — and commits the recaptured PNGs to that branch (retarget from the
  current hardcoded `--base main`). Rationale: yields **true CI-native amd64 pixels** (zero
  arm64-emulation arch-parity gamble) AND **green-before-merge** (no red on the required
  `example_playwright_smoke` gate; no merge deadlock; honors clean-gate discipline). Rejected:
  post-merge designed flow (leaves a required gate red on `main`, may deadlock the 219 merge);
  local `act --container-architecture linux/amd64` (qemu-slow, unproven emulated sub-pixel
  parity → compare-gate flake risk).

### D. Zero-human posture & canary discipline

- **D-05: Zero-human on PIXELS; keep the git-diff intent review.** 218 already visually verified
  the elevated renders, so recapture is mechanical byte-blessing. `snapshot-recapture-gate.sh`
  ("PASS — recording approved, no human review needed") + `snapshot-canary-guard.sh` +
  `example_playwright_smoke` compare-mode are the automated approval — no per-pixel human diff
  review. The ONE retained human touch is the cheap **scope check**: the recapture PR names the
  changed slugs in its diff (the reviewable-intent safeguard the SaaS tools charge for). This is
  not human UAT; it's the same reviewability a committed-baseline repo gives for free.

- **D-06: The sentinel/canary is what makes zero-human safe — harden it.** `board-notice`
  (design) and `impersonation-banner` (checkpoints) must NEVER be allowlisted; unexpected drift
  there condemns the whole recapture (presumed env-poisoned → gate fails). Enforce that canary
  slugs can never appear in either committed allowlist. Ecosystem-validated (canary/poison-pill
  fixture pattern; the live analogue of pinning the render env).

### E. Allowlist reconciliation (SC-2) = two-PR choreography

- **D-07: Recapture PR names changed non-canary slugs; a follow-up PR resets both allowlists to
  empty.** Both allowlists are already comment-only (empty). The guard only *diffs* PNGs vs base
  (it does not re-render), so on the recapture PR every shifted non-canary slug must be
  temporarily present (via committed allowlist entries and/or the jobs' runtime `--allow` flags)
  and both canaries delete-reborn — else `fast_checks` reds. SC-2's empty steady state is then a
  **follow-up PR** (base = main-with-PNGs → no PNG diff → guard exits zero with empty
  allowlists). demo-showcase needs no allowlist entry (no canary, no guard). Keep the
  empty-steady-state + named-slug-intent discipline — it's the minimal-dep analogue of
  Chromatic's approval UI and matches documented best practice; enforce allowlist↔changed-PNG
  symmetry so intent and pixels can't desync.

### F. Generated-host parity (SC-3)

- **D-08: SC-3 is essentially confirm-only.** install-golden is consistent on `main` (the wave
  touched no templates; `ec4dfd12` already re-blessed it) → no rebless. Acceptance-smoke
  (`generated_admin_playwright_smoke` → `scripts/ci/admin-acceptance-smoke.sh --test all`,
  ci.yml:1369) is hard-gated (in `ci-gate.needs`, NOT skipped) and consumes its own generated
  app, not the 115 example baselines — so recapture doesn't touch it. The example-only icon fix
  leaves generated-host unaffected. 219's obligation: confirm both parity halves stay green.

### Claude's Discretion
- Exact ci.yml dispatch-input shape and how narrowly to relax `release_ref_guard` for the
  recapture-only branch path (D-04) — planner/executor choose the least-surface implementation.
- Whether to physically consolidate demo-showcase recapture into the checkpoint job vs a small
  third job (D-03.1) — cheapest correct wiring wins.
- Plan decomposition granularity (natural units: icon-fix → ci.yml recapture-trigger + gaps →
  recapture-run/land PR → allowlist-reset follow-up PR → parity confirm).

### Folded Todos
None folded — see Deferred for reviewed todos.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.github/workflows/ci.yml` — `admin_design_recapture` (1497), `admin_checkpoint_recapture`
  (1798), `release_ref_guard` (34-52), workflow triggers (3-20), `fast_checks` canary guard
  (101-109), `example_playwright_smoke` compare lanes (design_gallery 1145-1170, admin_checkpoints
  1120-1125, demo_showcase 1191-1201, aggregator 1202-1221), `generated_admin_playwright_smoke`
  parity (1369), `ci-gate.needs` (~1448), stale "72/24" comments (1490, 1611), canary
  delete-rebirth pattern (1604-1607)
- `scripts/ci/snapshot-canary-guard.sh` — added-tolerated / modified-forbidden canary logic,
  empty-allowlist policy, `--allow` and `--require-all` semantics
- `scripts/ci/snapshot-recapture-gate.sh` — per-lane slug routing, "no human review needed" gate
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host runtime parity (SC-3)
- `test/example/lib/example_web/components/core_components.ex:444-451` — example `icon/1` (fix site)
- `test/example/lib/example_web/live/mfa_settings_live.ex:250,328` — `<.icon style=>` call sites
- `test/example/priv/playwright/snapshot-allowlist`, `…/snapshot-allowlist-design` — both empty
- `test/example/priv/playwright/playwright.config.ts` — 7 project partitions (168 = demo-showcase)
- `test/example/priv/playwright/tests/{admin-design,admin-checkpoints,demo-showcase}.spec.ts-snapshots/`
  — the 84/27/4 committed baselines
- `.actrc` + `~/.claude/…/memory/reference_act_local_ci.md` — local ubuntu-CI context (arm64 caveat)
- `.planning/REQUIREMENTS.md` — RECAP-01
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — cache-vs-artifact separation,
  determinism/strict-pinning, warnings-as-errors gating, required-vs-optional checks, and the
  `GITHUB_TOKEN`-doesn't-retrigger-workflows caveat (relevant to a bot-committed baseline PR)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Two working amd64 recapture jobs** already do the hard part (boot → `--update-snapshots` →
  guard → open PR): `admin_design_recapture`, `admin_checkpoint_recapture`. 219 extends, not rebuilds.
- **Two guard scripts** (`snapshot-canary-guard.sh`, `snapshot-recapture-gate.sh`) already encode
  the added-vs-modified/canary/allowlist logic and the "no human review needed" gate.
- **Deterministic render substrate** — self-hosted Space Grotesk woff2 + `document.fonts.ready` /
  `fonts.check` gating (ci.yml:1159-1164) makes the render OS-independent (arch parity is the only
  residual variable, handled by D-04's real-CI-amd64 choice).

### Established Patterns
- **Delete-then-recapture** so a changed baseline is born `added` (guard-tolerated), not `modified`
  (guard-forbidden) — already used for `board-notice`; extend to `impersonation-banner` (D-03.2).
- **Empty-steady-state allowlist + named-slug intent, reset on merge** — the committed-baseline,
  minimal-dep analogue of a Chromatic approval UI (ecosystem-validated).
- **Never-allowlistable sentinel/canary** — the single safeguard that makes zero-human defensible.

### Integration Points
- **Recapture-trigger surgery lands in ci.yml** — a `workflow_dispatch` recapture-branch input +
  narrow `release_ref_guard` relaxation + retarget commit base from `main` to the dispatched branch.
- **The real gate is `example_playwright_smoke`** — it re-renders and pixel-diffs against committed
  PNGs; no allowlist can silence it, so baselines MUST match the amd64 render to go green.
- **The two recapture jobs are asymmetric today** — design self-gates + delete-reborn canary + OQ3
  cross-lane compare; checkpoint does none (relies on human review, deliberately, since the guard
  is circular on a tracked-file recapture). D-03/D-05/D-06 unify them for the zero-human landing.
</code_context>

<specifics>
## Specific Ideas

- **Verified empirical failure** (subagent ran it): `mix compile --warnings-as-errors` in
  `test/example` exits non-zero on the two `<.icon style=>` sites — this is the confirmed #1 blocker.
- **Deadlock insight** driving D-04: the required `example_playwright_smoke` gate compares against
  stale committed baselines, so the post-merge flow can't get the branch onto `main` to trigger the
  push-based recapture jobs without leaving a required gate red — hence the branch-scoped dispatch.
- **Carry forward the 216 lesson:** the only valid green is a capture on a clean tree at the final
  committed HEAD; delete-then-add-at-HEAD dodges the stale-render / pre-commit-SHA trap.
</specifics>

<deferred>
## Deferred Ideas

- **Digest-pin the Playwright/browser image** (ecosystem hardening: prevents a silent upstream
  FreeType/Chromium raster bump masquerading as an intended delta) — worthwhile but out of the
  recapture scope; note for a future CI-hardening pass.

### Reviewed Todos (not folded)
- **2026-07-09 218 re-review follow-ups (WR-01/02, IN-01/02/03)** — installer-template scope
  drift (`rename_passkey` missing `scope:` + `{:error, :impersonation_forbidden}`, delete-passkey
  copy) + nits. Deferred: these need a golden rebless and are template-scope, orthogonal to 219's
  example-only recapture. Handle via `/gsd-code-review 218 --fix`. See [[reference_installer_template_drift]].
- **SEED-005 / per-shard-DB Playwright parallelization** — CI perf, not recapture. Deferred.
- **mix sigra.migrate_schema helper, runtime auth-prefix override, app.css corruption-guard
  hardening** — unrelated domains. Deferred.
</deferred>
