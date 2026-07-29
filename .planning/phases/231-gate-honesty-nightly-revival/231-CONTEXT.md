# Phase 231: Gate Honesty + Nightly Revival - Context

**Gathered:** 2026-07-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Every gate that reports green is asserting something on a lane that **actually ran**, and a red
lane produces a signal a human sees. Owns **GATE-01, GATE-02, GATE-03, GATE-04, DX-05**.

**In scope:** `.github/workflows/ci.yml` (the `ci-gate` aggregation, `generated_admin_playwright_smoke`'s
stale condition, `admin_eval_render`'s two bugs and its `continue-on-error`),
`.github/workflows/ci-observe.yml` (schedule-lane leniency removal),
`.github/workflows/playwright-github-pages.yml` (missing seeds prelude),
`.github/workflows/release-please.yml` (`gate-ci-green` ceiling),
`scripts/ci/notify-failure-issue.sh` (label self-heal), `test/example/priv/playwright/lib/eval/probes.ts`,
`test/example/priv/playwright/tests/admin-generated.spec.ts`, and new `scripts/ci/` guard +
self-test pairs.

**Explicitly NOT in scope:**
- **Ruleset 14941512 changes.** Adding `ci-gate` as a required context (SEED-005 P1-2) and the
  `example_unit_smoke`-is-required-but-absent-from-`ci-gate.needs` gap (`ci.yml:1793-1802`) are
  both real adjacent honesty gaps, but **no GATE-0x requirement covers either**, and both are
  repo-admin actions. File, do not fix.
- **`storageState` / PW-01 and per-shard-DB parallelization** — Phase 232.
- **`admin_design_recapture`'s 19.28m of discarded work** — no requirement covers it (carried
  forward from 230-CONTEXT.md's out-of-scope list).
- **GATE-05's before/after coverage inventory** — Phase 235, and it consumes Phase 234's DX-04
  spec inventory as input.
</domain>

<decisions>
## Implementation Decisions

### GATE-03 — honest-skip enumeration and enforcement

- **D-01:** Do **not** build a new enumeration. GATE-03 consumes the existing
  `.github/ci-skip-manifest.tsv` (shipped by Phase 230, 17 rows carrying
  `tier / kind / id / parent_job_id / display_name / gate_level / gate / observer`) through a new
  extracted `scripts/ci/` verdict script. The manifest's own header block instructs this:
  *"Phase 231 GATE-03 SHOULD read this file rather than re-deriving the set. GATE-03 owns the
  `ci-gate` pass/fail consequence; this file owns the enumeration."* Three-way parity
  (manifest ⇔ `ci.yml` ⇔ `MAINTAINING.md:142-199`) is already machine-enforced by
  `scripts/ci/prohibitions/honest-skip-parity.test.mjs`.
  - *If a second oracle is created:* the manifest and the ci-gate logic drift, the parity test keeps
    passing against a manifest nothing enforces, and GATE-03 reproduces the "condition that reads
    plausibly and verifies nothing" failure it exists to remove.

- **D-02:** The verdict script is invoked from a **step inside the existing `ci-gate` job**
  (`ci.yml:1789-1840`) — not a new job, not inline shell. That job already owns the consequence
  (`if [[ "$result" != "success" && "$result" != "skipped" ]]`, `ci.yml:1831`). House pattern for a
  new guard is a `scripts/ci/*.sh` + hermetic `*.test.sh` pair wired into `fast_checks`; there are
  ~10 such pairs at `ci.yml:155-230`.

- **D-03:** The PR-side honest-skip set for the nine `ci-gate.needs` lanes (`ci.yml:1793-1802`) is
  exactly **{`upgrade_smoke` (any PR), `library_tests_dep_off` (docs-only PR only)}** after GATE-02
  lands. On any **non-`pull_request`** event, **no** `ci-gate.needs` lane may skip — `changes` emits
  `docs_only=false` unconditionally on non-PR events (`ci.yml:138-141`), so no tier-C skip is
  reachable there. Verified on PR run `30412458437`.

- **D-04:** Adopt the non-vacuity posture already established by
  `scripts/ci/ci-demotion-observer.sh:70-80` — a manifest that parses to **zero rows is a broken
  parse, not a clean run**, and must fail.

- **D-05:** Prove SC-3's **fail** direction with a deliberate **dispatch-input probe** modelled on
  the existing `nightly_probe` / `force_fail_probe` (`ci.yml:8-12, 2585-2595`) — not by temporarily
  rotting a real gate on a branch. `force_fail_probe` is the repo's existing documented mechanism
  for proving a red path on demand: `needs`-free, non-PR-gated, outside `ci-gate.needs`. A one-off
  branch experiment produces evidence that expires; a probe input is re-provable forever, matching
  the standing-receipt posture Phase 230 adopted in `ci-observe.yml`.

### GATE-02 — replacing the stale `head_ref` condition

- **D-06:** **Delete the `if:` clause at `ci.yml:1674` outright** so
  `generated_admin_playwright_smoke` runs on **every** event. Do **not** replace it with the house
  `if: github.event_name != 'pull_request'` pattern — that would be honest but would still leave
  generated-host parity verified on *no PR at all*, which is GATE-02's defect restated rather than
  fixed. GATE-02's requirement text is explicit: parity must be verified *on a lane that actually
  executes on a PR*. This also retires the disclosed residual at `MAINTAINING.md:274`
  ("Generated-host template parity … becomes nightly-only").

- **D-07 (cost is settled, not a judgment call):** Enabling it on PRs costs **~0 wall-clock and
  ~4 runner-minutes**, and does **not** conflict with FAST-01's `<12m` p50 target. Measured job
  durations: 229s (nightly `30425416933`), 224s / 243s / 234s / 268s / 222s (pushes `30389700235`,
  `30387490396`, `30379435985`, `30374856611`, `30325414426`). The post-230 PR pole is
  `example_playwright_smoke` at **989s** (run wall 1012s, `30412458437`), and this job's only
  dependency is `release_ref_guard` (3s) — so it runs fully in parallel. Even after Phase 232
  collapses the Playwright pole toward ~8-10m, ~4m still sits under it. FAST-01 is a **p50
  wall-clock** requirement, not a runner-minute budget.
  - *Fallback if it ever does land on the critical path:* keep the job but shed its
    `npx playwright install --with-deps chromium webkit` (`ci.yml:1707`) via the Phase-230 cache.

- **D-08 (hard-fail boundary):** The `admin-generated.spec.ts:169-176` failure **must be diagnosed
  and fixed before** the clause is removed — same demote-then-fix discipline as 230's D-10/D-11.
  It is **not transient**, correcting `230-VERIFICATION.md:174`: sampled **8 pass / 5 fail (~38%)**
  over the runs where the 9-test version ran (pass: `30472016250`, `30466318240`, `30389700235`,
  `30387490396`, `30379435985`, `30374856611`, `30325414426`; fail: `30461966943`, `30425416933`,
  `30414885679`, `30331796188`, `30321079383`). Every failure is the same assertion —
  `expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)`
  at 320px with `html { font-size: 32px }` — and it fails **on the retry too**, so it is
  sticky-within-run, not per-attempt randomness. At ~38% it would red `ci-gate` on more than a third
  of PRs, training maintainers to ignore it: the precise dishonest-signal failure this phase exists
  to remove.

- **D-09 (owner-selected):** Diagnose the flake **in-phase from artifacts**, as a first-class work
  item — not time-boxed-then-quarantined, and not deferred to a pre-phase task. Pull the
  `generated-admin-failure-diagnostics` artifact (`test-failed-1.png`) from run `30425416933`,
  confirm or kill the running hypothesis, and fix properly. **GATE-02 does not enable until the lane
  is green.** Relaxing or narrowing the 320px assertion is **not** an accepted outcome.
  - *Running hypothesis (unconfirmed — do not implement against it without evidence):* a
    webfont-metrics race against the 15-character single-token app name `SigraAdminSmoke`. See
    `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md`.

- **D-10 (hard-fail boundary):** Removing the clause requires a **same-commit** edit to three other
  files or `fast_checks` reds on the phase's own PR with a cause that looks unrelated:
  the `.github/ci-skip-manifest.tsv` row `A job generated_admin_playwright_smoke` (which records the
  stale gate string verbatim), `MAINTAINING.md:137` (CI cadence list), and `MAINTAINING.md:274`
  (residual 2). `honest-skip-parity.test.mjs` asserts all three directions and runs on every PR.

### GATE-04 — admin_eval_render order of operations

- **D-11 (strict order — do not reorder):**
  1. Install `chromium webkit` at `ci.yml:2517-2519`, **and re-token the Phase-230 browser-set cache
     key** (230-CONTEXT D-16 made the key browser-set-scoped *specifically* so a shared key could not
     restore WebKit and make this job look fixed without the fix).
  2. Fix `test/example/priv/playwright/lib/eval/probes.ts:380`.
  3. Run and **read** whether b1-b6 pass.
  4. **Only then** delete `continue-on-error: true` at `ci.yml:2450`.

- **D-12:** Evidence for the two bugs, from push run `30472016250` (job `90644402928`):
  `Running 192 tests using 1 worker` → `76 failed, 116 passed (16.2m)`, exit 1 at harness phase (a).
  - *Bug 1:* every `admin-eval-mobile` test is in the failed set — that project is
    `devices['iPhone 13']` (`playwright.config.ts:215-217`), i.e. **WebKit**, while the step at
    `ci.yml:2517` installs **chromium only** and its own step name asserts "admin-eval uses chromium."
  - *Bug 2:* the chromium/dark failures cluster on `board-mg-2` (all 4 states) plus `board-summary_chip`,
    `board-field_help` — matching `probes.ts:380`'s `el.className.includes('ember')`, which throws on
    an SVG element where `className` is an `SVGAnimatedString`. (`probes.ts:176` and `:237` use
    `className` only for truthiness and do **not** throw — do not "fix" those.)

- **D-13 (hard-fail boundary):** The **step-level** `continue-on-error: true` at `ci.yml:2548`
  **stays**. It is what lets partial bundles upload before the re-fail step at `:2560-2565`;
  deleting it loses the artifact on failure. Only the **job-level** one at `:2450` is removed.

- **D-14:** SC-4's "guards executing" is observed by grepping the job log for the harness's own
  literal phase banners — `admin-eval-harness: (b1) stale-render guard` … `(b6) settled findings lint`
  and `admin-eval-harness: PASS — all phases green` (`scripts/ci/admin-eval-harness.sh:93-116`) —
  **plus** `conclusion: success` on the job. The harness runs under `set -euo pipefail` (`:63`) and
  echoes each phase before invoking it, so banner presence proves reach and the job conclusion proves
  pass. `stale-render-guard.sh` runs nowhere else in the repo — `fast_checks` runs only its unit
  self-test. Job-green alone does **not** distinguish "guards ran and passed" from "guards were
  reached but no-opped".

- **D-15 (budget for this):** A **third defect class is likely**. b1-b6 have never executed in CI, so
  their pass is unproven. Phase (a2) `fix-queue-build.mjs` is the sole writer of `open_findings` in
  `admin-render-sha.json` and rewrites it in the working tree; b3/b4/b5 then compare working tree
  against **committed HEAD** (`--base HEAD`, `admin-eval-harness.sh:99-113`), so a fresh render whose
  findings differ from committed reds them. b1 additionally hard-fails when any bundle's
  `app_git_sha != git HEAD` or when admin source changed after capture (`stale-render-guard.sh:1-24`).
  Prior art: the latent fix-queue-lint proxy-marker bug found on terminal `fast_checks` during v1.44.
  **The plan must not respond to a b-phase red by restoring `continue-on-error`** — that is forbidden
  by 230's D-15 posture and by REQUIREMENTS.md "Out of Scope".

### GATE-01 — nightly revival

- **D-16:** Target **literal green**. The fallback ("every remaining red lane is a filed, diagnosed
  defect with an owner") is held in reserve, not adopted up front. Measured on the most recent
  nightly, run `30425416933` (2026-07-29T05:33Z, head `018229e5` — **pre**-Phase-230 merge): 25 jobs,
  **23 green**. Exactly two reds: `Generated admin Playwright smoke` (229s), which propagates to
  `ci-gate` (4s), and `Admin eval render + probe` (851s, `continue-on-error`, so it does not redden
  the run). `upgrade_smoke`, all four `install_matrix` legs, both recapture lanes, `nightly_probe`,
  and every required lane were green.
  - **Consequence for sequencing:** the nightly's red is *entirely* GATE-02's defect plus GATE-04's
    defect. GATE-01 is largely an **observation** of the other two, not independent work.

- **D-17 (corrects the filed todo):** The "Playwright reports (GitHub Pages)" scheduled red is **not
  spec drift**. `playwright-github-pages.yml` goes from `Setup example dev DB` (`:81`) directly to
  `Boot example app` (`:95`) with **no `Run demo seeds` step**, while **all four** example-booting
  jobs in `ci.yml` run one (`:1288`, `:1950`, `:2258`, `:2506`), seeding ~30 loadtest users. Without
  them the admin users index does not paginate and `getByRole('link', { name: 'Next page' })` never
  renders — which is exactly how scheduled run `30432494488` fails, in all three checkpoint projects
  at `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:230`.
  `.planning/todos/pending/2026-07-27-playwright-github-pages-publisher-red.md` guessed "real spec
  drift" and floated `continue-on-error` as an option — **the latter is both unnecessary and
  forbidden by 230's D-15.** Add the seeds step.

- **D-18 (owner-selected — new finding, no todo covers it):** `pages-build-deployment` has failed on
  **six consecutive pushes** (`30472014592`, `30466317343`, `30461965393`, `30389698709`,
  `30387487782`, `30379433249`). Its log shows Jekyll (`github-pages v232`) rendering `AGENTS.md`,
  `CHANGELOG.md`, `CLAUDE.md`, `brandbook/**` from `/github/workspace/.` — i.e. **Pages is building
  `main`'s repo root, not the `gh-pages` branch** the publisher targets.
  `scripts/ci/ensure-github-pages-legacy-branch.sh` is supposed to set the Pages source to legacy +
  `gh-pages`, but it runs only **after a successful publish** — and the publisher has been red daily,
  so it has never run. Chicken-and-egg.
  - **Scope decision:** **in scope only insofar as D-17's fix lets that script finally run**, which
    may self-heal the Pages source. If it does **not** self-heal (token scope, or a Settings→Pages
    change required), **file it as a diagnosed defect with an owner under SC-1's fallback branch** —
    do **not** expand the phase into a repo-admin Pages reconfiguration.

- **D-19:** GATE-01 landing **requires deleting** the schedule-lane leniency branch at
  `.github/workflows/ci-observe.yml:130-136`. That code carries its own removal condition in a
  comment: *"REMOVAL CONDITION: Phase 231 GATE-01. When a scheduled run concludes green … delete this
  branch so the schedule lane fails like the push lane does."* `MAINTAINING.md:255-262` records the
  same commitment. Leaving it means a demoted construct silently stops executing on the nightly and
  the receipt warns instead of failing — a new silent-rot channel opened by the phase meant to close
  them.

### DX-05 — release-lane honesty

- **D-20:** Raise `max_attempts` from `60` to `120` at `release-please.yml:119` (a 60-minute ceiling
  at the existing 30s interval) **and** add an explicit `timeout-minutes` to the `gate-ci-green` job
  (`release-please.yml:96-104`), which today carries **none** and so inherits the 360-minute default.
  Evidence: run `30379435985` (push, `main`, 2026-07-28T16:41:34Z) concluded `success`, while
  `gate-ci-green` in run `30379435970` gave up at 17:16:37Z — about **one minute before** the run it
  was waiting on finished. Post-230 push wall-clocks measured 28m29s (`30466318240`) with a
  historical max of 42.3m, so 30m is structurally below the run it waits for. Polling costs nothing
  when green — it exits on first success.

- **D-21 (owner-selected):** SC-5's literal wording is **not directly observable in this phase** —
  `gate-ci-green` has `if: needs.release-please.outputs.release_created == 'true'`
  (`release-please.yml:100`), so it never runs on an ordinary push. **Extract the polling loop into
  `scripts/ci/wait-for-ci-gate.sh`** with a hermetic `.test.sh` wired into `fast_checks`, then
  **invoke the extracted script live** against the SHA of a real completed push-to-`main` run and
  show it returns 0 well inside 120 attempts. Book the next-real-release confirmation as a
  **standing receipt**, not a phase blocker.
  - *Why this is a genuine observation and not a YAML read:* it exercises the real logic against a
    real run's real `gh run list` / `gh run view` output. This is Phase 230's own precedent —
    `ci-observe.yml` exists precisely because two receipts were structurally impossible to observe
    pre-merge, and both were converted from one-time human UAT into standing assertions
    (`230-VERIFICATION.md:151-166`).

- **D-22:** Make `scripts/ci/notify-failure-issue.sh` **self-healing** — check `gh label list` and
  create the label when absent before `gh issue create --label` (`:33`) — with a hermetic self-test
  that shadows `gh` with a recording stub. The stub technique already exists in-repo
  (`ci-demotion-observer.sh:37-39` documents invoking `gh` bare via PATH so its self-test can shadow
  it — no network, no token). Preferred over the soft-fail `gh issue edit` alternative, per the
  todo's own recommendation.
  - *Confirm before relying on it:* whether `issues: write` suffices for `gh label create` with
    `GITHUB_TOKEN` (see Needs Research).

- **D-23:** **Do not re-stage the red-probe.** SC-5's "a red-probe creates a tracking issue" is
  **already observed** and should be cited, not re-derived. Issue **#118** (`release-lane-rot`,
  "ci-gate red on main", created 2026-07-29T01:39:14Z) was opened by run `30414636733` and carries
  **3 idempotent comments** from runs `30414885679`, `30425416933`, `30461966943` — proving both
  script branches (create at `:33`, find-and-comment at `:26-30`) against the real Issues API. The
  failure branch is observed too: `Notify on red ci-gate (release-lane-rot)` concluded `failure` on
  nightly `30331796188` (pre-label) and `success` on `30425416933` (post-label). What remains
  unexercised since the label existed is the **`release-please.yml` consumer** (`:344-379`) — that,
  and only that, is what a new probe would need to cover.

### Sequencing

- **D-24:** Plan order is **GATE-02 fix (D-08/D-09) → GATE-04 fix (D-11) → GATE-02 enable (D-06) →
  GATE-03 enforcement (D-01..D-05) → GATE-01 observation (D-16..D-19)**. DX-05 (D-20..D-23) is
  **fully parallel** — it touches only `release-please.yml` and `scripts/ci/notify-failure-issue.sh`.
  - *Why GATE-01 is last:* its two reds *are* GATE-02's and GATE-04's defects, so it is an
    observation of them, not independent work.
  - *Why GATE-03 must land after the stale `head_ref` is gone:* landing it first would either red
    every PR on a lane the phase is about to fix, or force the manifest to allowlist a gate known to
    be rotted — enshrining the rot in the very oracle meant to detect it.

### How each success criterion is observed

- **D-25:** Every SC closes on a **named run ID plus a named command**, never a YAML read
  (`ROADMAP.md:40-43`). The phase's own PR is the SC-2 vehicle — it necessarily touches `ci.yml`, so
  `docs_only=false` and the full matrix runs.
  - **SC-1:** the first scheduled run after merge (cron `30 4 * * *`, `ci.yml:18-21`);
    `gh run view <id> --json jobs`.
  - **SC-2:** on the phase PR's own run, `Generated admin Playwright smoke` non-`skipped` with a real
    duration, plus `9 passed` in `gh run view --log --job <id>`.
  - **SC-3:** two dispatched probe runs — clean → `ci-gate` success; rot probe → `ci-gate` failure
    **naming the lane**.
  - **SC-4:** `admin_eval_render` `conclusion: success` plus the six `(b1)`…`(b6)` banners and
    `PASS — all phases green` in its log.
  - **SC-5:** the extracted script's live invocation output plus issue #118's comment thread.

### Claude's Discretion

- Exact filename and CLI shape of the GATE-03 verdict script and its self-test (house pattern is
  `scripts/ci/<name>.sh` + `<name>.test.sh` wired into `fast_checks`).
- The dispatch-input name for the SC-3 rot probe (`force_rot_probe` is a reasonable default,
  mirroring `force_fail_probe`).
- Whether the GATE-03 verdict runs as one step or two inside `ci-gate`.
- `timeout-minutes` value for `gate-ci-green` (any value comfortably above the 60-minute polling
  ceiling D-20 establishes).
- Wave/plan decomposition, provided D-24's order and D-11's internal order are preserved.

### Folded Todos

All five todos tagged `resolves_phase: 231` are folded into scope:

- `2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md` → GATE-04 (D-11..D-15). Note
  the ~17m/PR half was already resolved by Phase 230's D-10 demotion; **this phase owns the
  correctness half only**.
- `2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` → GATE-02
  (D-06..D-10).
- `2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` → DX-05 (D-20, D-21).
- `2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` → DX-05 (D-22, D-23).
- `2026-07-27-playwright-github-pages-publisher-red.md` → GATE-01 (D-17). **Its stated hypothesis is
  wrong** — see D-17. Close it against the seeds-prelude diagnosis, not the spec-drift one.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 231 block; the "Verification Philosophy (binds every phase)"
  section; the Phase 230 block for what just landed.
- `.planning/REQUIREMENTS.md` — GATE-01..GATE-05, DX-05, the measured baseline table, and the notes
  explaining why GATE-05 sits in Phase 235 and DX-05 sits here.
- `.planning/METHODOLOGY.md` — Decisive Defaulting, Escalation Threshold, Discuss-Phase Default.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` — D-01..D-21, especially
  **D-10/D-11** (the demote-don't-mask discipline), **D-15** (never mask a red), **D-16** (the
  browser-set-scoped cache key that GATE-04 depends on), and the out-of-scope list this phase inherits.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-VERIFICATION.md` — current post-230
  state; `:151-166` (standing-receipt precedent for D-21); `:174` (the "transient" classification
  that **D-08 corrects**).
- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` — the observed-run evidence
  contract this phase's proof discipline mirrors.
- `.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` — the precedent failure mode (audits that were
  "code-level reads that never executed the specs") this phase exists to prevent.
- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` + its 2026-07-28 Addendum — the audit's own
  gate findings. **P1-2 (add `ci-gate` as a required context) is explicitly out of scope here.**
- `.github/ci-skip-manifest.tsv` — **the oracle for GATE-03.** Read its header block first.
- `MAINTAINING.md` — `:104-110` (the 5 ruleset-required contexts), `:137` (CI cadence, edited by
  D-10), `:142-199` (honest-skip parity target), `:255-262` (the ci-observe removal commitment),
  `:274` (residual 2, retired by D-06).
- The five folded todos in `.planning/todos/pending/` listed under "Folded Todos" above.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`.github/ci-skip-manifest.tsv`** — 17-row machine-readable honest-skip oracle shipped by Phase
  230, with a header block that explicitly hands GATE-03 its contract. **Consume, do not re-derive.**
- **`scripts/ci/prohibitions/honest-skip-parity.test.mjs`** — already machine-enforces manifest ⇔
  `ci.yml` ⇔ `MAINTAINING.md` parity "in every direction", on every PR via `fast_checks`. This is
  why D-10's same-commit edits are mandatory.
- **`scripts/ci/ci-demotion-observer.sh`** — two reusable patterns: `:70-80` the non-vacuity posture
  (zero rows = broken parse), and `:37-39` the bare-`gh`-via-PATH convention that lets a self-test
  shadow `gh` with a recording stub (no network, no token). D-04 and D-22 both build on it.
- **`ci.yml:8-12, 2585-2595`** — `nightly_probe` / `force_fail_probe` dispatch inputs: the existing,
  documented mechanism for proving a red path on demand. D-05's SC-3 probe mirrors this.
- **`.github/workflows/ci-observe.yml`** — Phase 230's standing-receipt machinery, and the precedent
  D-21 invokes for a structurally-unobservable criterion. Also carries the `:130-136` leniency branch
  D-19 must delete.
- **`scripts/ci/admin-eval-harness.sh:93-116`** — emits literal `(b1)`…`(b6)` phase banners and a
  `PASS — all phases green` line. This is D-14's observation surface, free of charge.
- **~10 `scripts/ci/*.sh` + `*.test.sh` pairs wired into `fast_checks`** (`ci.yml:155-230`) — the
  house pattern for every new guard this phase adds.
- **`install_golden_contract` (`ci.yml:228-308`)** — the always-run-job + `detect`-step + step-level
  `if:` pattern, if any new gating is needed.

### Established Patterns

- **Demote, then fix — never mask.** 230's D-10/D-11/D-15. This phase is the "then fix" half, and
  D-13/D-15/D-17 all restate that `continue-on-error` is not an available answer to a red.
- **A `skipped` job proves nothing.** `ci-gate` counts `skipped` as pass (`ci.yml:1831`) — the root
  cause of both GATE-02's and GATE-03's defects.
- **Proof is an observed run, never a YAML read.** Every SC in D-25 names a run ID and a command.
- **Structurally-unobservable receipts become standing assertions,** not deferred human UAT
  (`230-VERIFICATION.md:151-166`); D-21 applies it.
- **Forward instructions are left in-code with removal conditions.** Phase 230 left three for this
  phase: the manifest header, `ci-observe.yml:16-23` and `:130-136`, and `MAINTAINING.md:255-262`.
  Treat them as authority, per METHODOLOGY's Prompt And Prior-Art Weighting.

### Integration Points

- `ci.yml:1789-1840` (`ci-gate` job + its `needs:` at `:1793-1802`) — GATE-03's enforcement site.
- `ci.yml:1674` (`generated_admin_playwright_smoke`'s stale `if:`) — GATE-02's deletion site;
  `:1707` is its browser install.
- `ci.yml:2450` (job-level `continue-on-error`), `:2517-2519` (chromium-only install), `:2548`
  (step-level `continue-on-error`, **keep**), `:2560-2565` (re-fail step) — GATE-04's sites.
- `ci.yml:138-141` (`changes` job's `docs_only` output) — why non-PR events have no reachable
  tier-C skip.
- `ci.yml:18-21` — the nightly cron (`30 4 * * *`), SC-1's trigger.
- `test/example/priv/playwright/lib/eval/probes.ts:380` — the `SVGAnimatedString` bug (`:176`, `:237`
  use `className` safely — leave them).
- `test/example/priv/playwright/playwright.config.ts:215-217` — `admin-eval-mobile` =
  `devices['iPhone 13']` = WebKit.
- `test/example/priv/playwright/tests/admin-generated.spec.ts:169-176` — the ~38% 320px flake.
- `playwright-github-pages.yml:81`→`:95` — the missing seeds step; compare `ci.yml:1288`, `:1950`,
  `:2258`, `:2506`.
- `release-please.yml:96-104` (job), `:119` (`max_attempts`), `:344-379` (the unexercised
  `release-lane-rot` consumer).
- `scripts/ci/notify-failure-issue.sh:26-30` (comment branch), `:33` (create branch).
- `scripts/ci/stale-render-guard.sh:1-24` — b1's hard-fail conditions (D-15's third-defect risk).
</code_context>

<specifics>
## Specific Ideas

- **Do not relax the 320px assertion.** D-09 was chosen over an explicit "time-box, then quarantine"
  option. A narrowed assertion with a recorded justification is **not** an accepted outcome for
  GATE-02.
- **Do not re-run work that already has evidence.** D-23: issue #118 and its three comments already
  prove both branches of `notify-failure-issue.sh` against the real API.
- **Correct the written record where this phase's evidence contradicts it.** Two corrections are
  already owed: `230-VERIFICATION.md:174`'s "transient" (D-08) and the GitHub-Pages todo's
  spec-drift hypothesis (D-17). Both were wrong; say so in the artifacts rather than quietly
  diverging.
</specifics>

<deferred>
## Deferred Ideas

- **Add `ci-gate` as a required ruleset context** (SEED-005 P1-2) — repo-admin action, no GATE-0x
  requirement covers it.
- **`example_unit_smoke` is ruleset-required yet absent from `ci-gate.needs`** (`ci.yml:1793-1802`) —
  a real adjacent honesty gap, uncovered by any requirement. **File as a new todo during planning;
  do not fix here.**
- **GitHub Pages source reconfiguration**, if D-17's fix does not self-heal it — becomes a filed,
  diagnosed defect with an owner under SC-1's fallback branch (D-18), in the same human-gated class
  as the Hex retire.
- **`admin_design_recapture`'s 19.28m of discarded work on every push** — inherited from
  230-CONTEXT.md's out-of-scope list; still uncovered by any requirement.

### Reviewed Todos (not folded)

- `2026-06-20-playwright-parallelization-per-shard-db.md` (score 0.9) — tagged `resolves_phase: 232`.
  Belongs to Playwright Economics.
- `2026-07-10-canary-recapture-lane-excludes-canary.md` (0.9) — recapture-lane noise; no GATE-0x
  requirement covers it.
- `2026-07-10-upgrade-smoke-button-type-hex-publish.md` (0.9) — tagged `resolves_phase: 223`;
  superseded by the 1.4.0 publish.
- `2026-07-03-hex-retire-stray-1-20-0.md` (0.7) — human-gated interactive Hex auth, deferred
  indefinitely by the owner (ADR 003).
- The W-1..W-8 findings and the 0.4-0.6 scored auth/admin todos — product-surface work, not gate
  honesty. Out of milestone.
</deferred>
