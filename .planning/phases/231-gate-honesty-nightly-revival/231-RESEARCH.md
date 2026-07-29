# Phase 231: Gate Honesty + Nightly Revival - Research

**Researched:** 2026-07-29
**Verified at HEAD:** `76d9111743735d81f574858e4ba1cb494c636d0d` (branch `worktree-discuss-231`)
**Domain:** GitHub Actions workflow honesty, CI gate aggregation, Playwright reflow diagnosis, bash guard/self-test authoring
**Confidence:** HIGH on anchors and mechanisms (all verified by direct file read + live `gh` calls); MEDIUM on the 320px root-cause ranking; LOW on nothing material.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**GATE-03 — honest-skip enumeration and enforcement**

- **D-01:** Do **not** build a new enumeration. GATE-03 consumes the existing `.github/ci-skip-manifest.tsv` (shipped by Phase 230, 17 rows carrying `tier / kind / id / parent_job_id / display_name / gate_level / gate / observer`) through a new extracted `scripts/ci/` verdict script. The manifest's own header block instructs this: *"Phase 231 GATE-03 SHOULD read this file rather than re-deriving the set. GATE-03 owns the `ci-gate` pass/fail consequence; this file owns the enumeration."* Three-way parity (manifest ⇔ `ci.yml` ⇔ `MAINTAINING.md:142-199`) is already machine-enforced by `scripts/ci/prohibitions/honest-skip-parity.test.mjs`.
  - *If a second oracle is created:* the manifest and the ci-gate logic drift, the parity test keeps passing against a manifest nothing enforces, and GATE-03 reproduces the "condition that reads plausibly and verifies nothing" failure it exists to remove.
- **D-02:** The verdict script is invoked from a **step inside the existing `ci-gate` job** (`ci.yml:1789-1840`) — not a new job, not inline shell. That job already owns the consequence (`if [[ "$result" != "success" && "$result" != "skipped" ]]`, `ci.yml:1831`). House pattern for a new guard is a `scripts/ci/*.sh` + hermetic `*.test.sh` pair wired into `fast_checks`; there are ~10 such pairs at `ci.yml:155-230`.
- **D-03:** The PR-side honest-skip set for the nine `ci-gate.needs` lanes (`ci.yml:1793-1802`) is exactly **{`upgrade_smoke` (any PR), `library_tests_dep_off` (docs-only PR only)}** after GATE-02 lands. On any **non-`pull_request`** event, **no** `ci-gate.needs` lane may skip — `changes` emits `docs_only=false` unconditionally on non-PR events (`ci.yml:138-141`), so no tier-C skip is reachable there. Verified on PR run `30412458437`.
- **D-04:** Adopt the non-vacuity posture already established by `scripts/ci/ci-demotion-observer.sh:70-80` — a manifest that parses to **zero rows is a broken parse, not a clean run**, and must fail.
- **D-05:** Prove SC-3's **fail** direction with a deliberate **dispatch-input probe** modelled on the existing `nightly_probe` / `force_fail_probe` (`ci.yml:8-12, 2585-2595`) — not by temporarily rotting a real gate on a branch. `force_fail_probe` is the repo's existing documented mechanism for proving a red path on demand: `needs`-free, non-PR-gated, outside `ci-gate.needs`. A one-off branch experiment produces evidence that expires; a probe input is re-provable forever, matching the standing-receipt posture Phase 230 adopted in `ci-observe.yml`.

**GATE-02 — replacing the stale `head_ref` condition**

- **D-06:** **Delete the `if:` clause at `ci.yml:1674` outright** so `generated_admin_playwright_smoke` runs on **every** event. Do **not** replace it with the house `if: github.event_name != 'pull_request'` pattern — that would be honest but would still leave generated-host parity verified on *no PR at all*, which is GATE-02's defect restated rather than fixed. GATE-02's requirement text is explicit: parity must be verified *on a lane that actually executes on a PR*. This also retires the disclosed residual at `MAINTAINING.md:274` ("Generated-host template parity … becomes nightly-only").
- **D-07 (cost is settled, not a judgment call):** Enabling it on PRs costs **~0 wall-clock and ~4 runner-minutes**, and does **not** conflict with FAST-01's `<12m` p50 target. Measured job durations: 229s (nightly `30425416933`), 224s / 243s / 234s / 268s / 222s (pushes `30389700235`, `30387490396`, `30379435985`, `30374856611`, `30325414426`). The post-230 PR pole is `example_playwright_smoke` at **989s** (run wall 1012s, `30412458437`), and this job's only dependency is `release_ref_guard` (3s) — so it runs fully in parallel. Even after Phase 232 collapses the Playwright pole toward ~8-10m, ~4m still sits under it. FAST-01 is a **p50 wall-clock** requirement, not a runner-minute budget.
  - *Fallback if it ever does land on the critical path:* keep the job but shed its `npx playwright install --with-deps chromium webkit` (`ci.yml:1707`) via the Phase-230 cache.
- **D-08 (hard-fail boundary):** The `admin-generated.spec.ts:169-176` failure **must be diagnosed and fixed before** the clause is removed — same demote-then-fix discipline as 230's D-10/D-11. It is **not transient**, correcting `230-VERIFICATION.md:174`: sampled **8 pass / 5 fail (~38%)** over the runs where the 9-test version ran (pass: `30472016250`, `30466318240`, `30389700235`, `30387490396`, `30379435985`, `30374856611`, `30325414426`; fail: `30461966943`, `30425416933`, `30414885679`, `30331796188`, `30321079383`). Every failure is the same assertion — `expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)` at 320px with `html { font-size: 32px }` — and it fails **on the retry too**, so it is sticky-within-run, not per-attempt randomness. At ~38% it would red `ci-gate` on more than a third of PRs, training maintainers to ignore it: the precise dishonest-signal failure this phase exists to remove.
- **D-09 (owner-selected):** Diagnose the flake **in-phase from artifacts**, as a first-class work item — not time-boxed-then-quarantined, and not deferred to a pre-phase task. Pull the `generated-admin-failure-diagnostics` artifact (`test-failed-1.png`) from run `30425416933`, confirm or kill the running hypothesis, and fix properly. **GATE-02 does not enable until the lane is green.** Relaxing or narrowing the 320px assertion is **not** an accepted outcome.
  - *Running hypothesis (unconfirmed — do not implement against it without evidence):* a webfont-metrics race against the 15-character single-token app name `SigraAdminSmoke`. See `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md`.
- **D-10 (hard-fail boundary):** Removing the clause requires a **same-commit** edit to three other files or `fast_checks` reds on the phase's own PR with a cause that looks unrelated: the `.github/ci-skip-manifest.tsv` row `A job generated_admin_playwright_smoke` (which records the stale gate string verbatim), `MAINTAINING.md:137` (CI cadence list), and `MAINTAINING.md:274` (residual 2). `honest-skip-parity.test.mjs` asserts all three directions and runs on every PR.

**GATE-04 — admin_eval_render order of operations**

- **D-11 (strict order — do not reorder):**
  1. Install `chromium webkit` at `ci.yml:2517-2519`, **and re-token the Phase-230 browser-set cache key** (230-CONTEXT D-16 made the key browser-set-scoped *specifically* so a shared key could not restore WebKit and make this job look fixed without the fix).
  2. Fix `test/example/priv/playwright/lib/eval/probes.ts:380`.
  3. Run and **read** whether b1-b6 pass.
  4. **Only then** delete `continue-on-error: true` at `ci.yml:2450`.
- **D-12:** Evidence for the two bugs, from push run `30472016250` (job `90644402928`): `Running 192 tests using 1 worker` → `76 failed, 116 passed (16.2m)`, exit 1 at harness phase (a).
  - *Bug 1:* every `admin-eval-mobile` test is in the failed set — that project is `devices['iPhone 13']` (`playwright.config.ts:215-217`), i.e. **WebKit**, while the step at `ci.yml:2517` installs **chromium only** and its own step name asserts "admin-eval uses chromium."
  - *Bug 2:* the chromium/dark failures cluster on `board-mg-2` (all 4 states) plus `board-summary_chip`, `board-field_help` — matching `probes.ts:380`'s `el.className.includes('ember')`, which throws on an SVG element where `className` is an `SVGAnimatedString`. (`probes.ts:176` and `:237` use `className` only for truthiness and do **not** throw — do not "fix" those.)
- **D-13 (hard-fail boundary):** The **step-level** `continue-on-error: true` at `ci.yml:2548` **stays**. It is what lets partial bundles upload before the re-fail step at `:2560-2565`; deleting it loses the artifact on failure. Only the **job-level** one at `:2450` is removed.
- **D-14:** SC-4's "guards executing" is observed by grepping the job log for the harness's own literal phase banners — `admin-eval-harness: (b1) stale-render guard` … `(b6) settled findings lint` and `admin-eval-harness: PASS — all phases green` (`scripts/ci/admin-eval-harness.sh:93-116`) — **plus** `conclusion: success` on the job. The harness runs under `set -euo pipefail` (`:63`) and echoes each phase before invoking it, so banner presence proves reach and the job conclusion proves pass. `stale-render-guard.sh` runs nowhere else in the repo — `fast_checks` runs only its unit self-test. Job-green alone does **not** distinguish "guards ran and passed" from "guards were reached but no-opped".
- **D-15 (budget for this):** A **third defect class is likely**. b1-b6 have never executed in CI, so their pass is unproven. Phase (a2) `fix-queue-build.mjs` is the sole writer of `open_findings` in `admin-render-sha.json` and rewrites it in the working tree; b3/b4/b5 then compare working tree against **committed HEAD** (`--base HEAD`, `admin-eval-harness.sh:99-113`), so a fresh render whose findings differ from committed reds them. b1 additionally hard-fails when any bundle's `app_git_sha != git HEAD` or when admin source changed after capture (`stale-render-guard.sh:1-24`). Prior art: the latent fix-queue-lint proxy-marker bug found on terminal `fast_checks` during v1.44. **The plan must not respond to a b-phase red by restoring `continue-on-error`** — that is forbidden by 230's D-15 posture and by REQUIREMENTS.md "Out of Scope".

**GATE-01 — nightly revival**

- **D-16:** Target **literal green**. The fallback ("every remaining red lane is a filed, diagnosed defect with an owner") is held in reserve, not adopted up front. Measured on the most recent nightly, run `30425416933` (2026-07-29T05:33Z, head `018229e5` — **pre**-Phase-230 merge): 25 jobs, **23 green**. Exactly two reds: `Generated admin Playwright smoke` (229s), which propagates to `ci-gate` (4s), and `Admin eval render + probe` (851s, `continue-on-error`, so it does not redden the run). `upgrade_smoke`, all four `install_matrix` legs, both recapture lanes, `nightly_probe`, and every required lane were green.
  - **Consequence for sequencing:** the nightly's red is *entirely* GATE-02's defect plus GATE-04's defect. GATE-01 is largely an **observation** of the other two, not independent work.
- **D-17 (corrects the filed todo):** The "Playwright reports (GitHub Pages)" scheduled red is **not spec drift**. `playwright-github-pages.yml` goes from `Setup example dev DB` (`:81`) directly to `Boot example app` (`:95`) with **no `Run demo seeds` step**, while **all four** example-booting jobs in `ci.yml` run one (`:1288`, `:1950`, `:2258`, `:2506`), seeding ~30 loadtest users. Without them the admin users index does not paginate and `getByRole('link', { name: 'Next page' })` never renders — which is exactly how scheduled run `30432494488` fails, in all three checkpoint projects at `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:230`. `.planning/todos/pending/2026-07-27-playwright-github-pages-publisher-red.md` guessed "real spec drift" and floated `continue-on-error` as an option — **the latter is both unnecessary and forbidden by 230's D-15.** Add the seeds step.
- **D-18 (owner-selected — new finding, no todo covers it):** `pages-build-deployment` has failed on **six consecutive pushes** (`30472014592`, `30466317343`, `30461965393`, `30389698709`, `30387487782`, `30379433249`). Its log shows Jekyll (`github-pages v232`) rendering `AGENTS.md`, `CHANGELOG.md`, `CLAUDE.md`, `brandbook/**` from `/github/workspace/.` — i.e. **Pages is building `main`'s repo root, not the `gh-pages` branch** the publisher targets. `scripts/ci/ensure-github-pages-legacy-branch.sh` is supposed to set the Pages source to legacy + `gh-pages`, but it runs only **after a successful publish** — and the publisher has been red daily, so it has never run. Chicken-and-egg.
  - **Scope decision:** **in scope only insofar as D-17's fix lets that script finally run**, which may self-heal the Pages source. If it does **not** self-heal (token scope, or a Settings→Pages change required), **file it as a diagnosed defect with an owner under SC-1's fallback branch** — do **not** expand the phase into a repo-admin Pages reconfiguration.
- **D-19:** GATE-01 landing **requires deleting** the schedule-lane leniency branch at `.github/workflows/ci-observe.yml:130-136`. That code carries its own removal condition in a comment: *"REMOVAL CONDITION: Phase 231 GATE-01. When a scheduled run concludes green … delete this branch so the schedule lane fails like the push lane does."* `MAINTAINING.md:255-262` records the same commitment. Leaving it means a demoted construct silently stops executing on the nightly and the receipt warns instead of failing — a new silent-rot channel opened by the phase meant to close them.

**DX-05 — release-lane honesty**

- **D-20:** Raise `max_attempts` from `60` to `120` at `release-please.yml:119` (a 60-minute ceiling at the existing 30s interval) **and** add an explicit `timeout-minutes` to the `gate-ci-green` job (`release-please.yml:96-104`), which today carries **none** and so inherits the 360-minute default. Evidence: run `30379435985` (push, `main`, 2026-07-28T16:41:34Z) concluded `success`, while `gate-ci-green` in run `30379435970` gave up at 17:16:37Z — about **one minute before** the run it was waiting on finished. Post-230 push wall-clocks measured 28m29s (`30466318240`) with a historical max of 42.3m, so 30m is structurally below the run it waits for. Polling costs nothing when green — it exits on first success.
- **D-21 (owner-selected):** SC-5's literal wording is **not directly observable in this phase** — `gate-ci-green` has `if: needs.release-please.outputs.release_created == 'true'` (`release-please.yml:100`), so it never runs on an ordinary push. **Extract the polling loop into `scripts/ci/wait-for-ci-gate.sh`** with a hermetic `.test.sh` wired into `fast_checks`, then **invoke the extracted script live** against the SHA of a real completed push-to-`main` run and show it returns 0 well inside 120 attempts. Book the next-real-release confirmation as a **standing receipt**, not a phase blocker.
  - *Why this is a genuine observation and not a YAML read:* it exercises the real logic against a real run's real `gh run list` / `gh run view` output. This is Phase 230's own precedent — `ci-observe.yml` exists precisely because two receipts were structurally impossible to observe pre-merge, and both were converted from one-time human UAT into standing assertions (`230-VERIFICATION.md:151-166`).
- **D-22:** Make `scripts/ci/notify-failure-issue.sh` **self-healing** — check `gh label list` and create the label when absent before `gh issue create --label` (`:33`) — with a hermetic self-test that shadows `gh` with a recording stub. The stub technique already exists in-repo (`ci-demotion-observer.sh:37-39` documents invoking `gh` bare via PATH so its self-test can shadow it — no network, no token). Preferred over the soft-fail `gh issue edit` alternative, per the todo's own recommendation.
  - *Confirm before relying on it:* whether `issues: write` suffices for `gh label create` with `GITHUB_TOKEN` (see Needs Research).
- **D-23:** **Do not re-stage the red-probe.** SC-5's "a red-probe creates a tracking issue" is **already observed** and should be cited, not re-derived. Issue **#118** (`release-lane-rot`, "ci-gate red on main", created 2026-07-29T01:39:14Z) was opened by run `30414636733` and carries **3 idempotent comments** from runs `30414885679`, `30425416933`, `30461966943` — proving both script branches (create at `:33`, find-and-comment at `:26-30`) against the real Issues API. The failure branch is observed too: `Notify on red ci-gate (release-lane-rot)` concluded `failure` on nightly `30331796188` (pre-label) and `success` on `30425416933` (post-label). What remains unexercised since the label existed is the **`release-please.yml` consumer** (`:344-379`) — that, and only that, is what a new probe would need to cover.

**Sequencing**

- **D-24:** Plan order is **GATE-02 fix (D-08/D-09) → GATE-04 fix (D-11) → GATE-02 enable (D-06) → GATE-03 enforcement (D-01..D-05) → GATE-01 observation (D-16..D-19)**. DX-05 (D-20..D-23) is **fully parallel** — it touches only `release-please.yml` and `scripts/ci/notify-failure-issue.sh`.
  - *Why GATE-01 is last:* its two reds *are* GATE-02's and GATE-04's defects, so it is an observation of them, not independent work.
  - *Why GATE-03 must land after the stale `head_ref` is gone:* landing it first would either red every PR on a lane the phase is about to fix, or force the manifest to allowlist a gate known to be rotted — enshrining the rot in the very oracle meant to detect it.

**How each success criterion is observed**

- **D-25:** Every SC closes on a **named run ID plus a named command**, never a YAML read (`ROADMAP.md:40-43`). The phase's own PR is the SC-2 vehicle — it necessarily touches `ci.yml`, so `docs_only=false` and the full matrix runs.
  - **SC-1:** the first scheduled run after merge (cron `30 4 * * *`, `ci.yml:18-21`); `gh run view <id> --json jobs`.
  - **SC-2:** on the phase PR's own run, `Generated admin Playwright smoke` non-`skipped` with a real duration, plus `9 passed` in `gh run view --log --job <id>`.
  - **SC-3:** two dispatched probe runs — clean → `ci-gate` success; rot probe → `ci-gate` failure **naming the lane**.
  - **SC-4:** `admin_eval_render` `conclusion: success` plus the six `(b1)`…`(b6)` banners and `PASS — all phases green` in its log.
  - **SC-5:** the extracted script's live invocation output plus issue #118's comment thread.

### Claude's Discretion

- Exact filename and CLI shape of the GATE-03 verdict script and its self-test (house pattern is `scripts/ci/<name>.sh` + `<name>.test.sh` wired into `fast_checks`).
- The dispatch-input name for the SC-3 rot probe (`force_rot_probe` is a reasonable default, mirroring `force_fail_probe`).
- Whether the GATE-03 verdict runs as one step or two inside `ci-gate`.
- `timeout-minutes` value for `gate-ci-green` (any value comfortably above the 60-minute polling ceiling D-20 establishes).
- Wave/plan decomposition, provided D-24's order and D-11's internal order are preserved.

### Deferred Ideas (OUT OF SCOPE)

- **Add `ci-gate` as a required ruleset context** (SEED-005 P1-2) — repo-admin action, no GATE-0x requirement covers it.
- **`example_unit_smoke` is ruleset-required yet absent from `ci-gate.needs`** (`ci.yml:1793-1802`) — a real adjacent honesty gap, uncovered by any requirement. **File as a new todo during planning; do not fix here.**
- **GitHub Pages source reconfiguration**, if D-17's fix does not self-heal it — becomes a filed, diagnosed defect with an owner under SC-1's fallback branch (D-18), in the same human-gated class as the Hex retire.
- **`admin_design_recapture`'s 19.28m of discarded work on every push** — inherited from 230-CONTEXT.md's out-of-scope list; still uncovered by any requirement.
- Reviewed-but-not-folded todos: `2026-06-20-playwright-parallelization-per-shard-db.md` (Phase 232), `2026-07-10-canary-recapture-lane-excludes-canary.md`, `2026-07-10-upgrade-smoke-button-type-hex-publish.md`, `2026-07-03-hex-retire-stray-1-20-0.md`, and the W-1..W-8 findings.
- **Ruleset 14941512 changes** of any kind.
- **`storageState` / PW-01 and per-shard-DB parallelization** — Phase 232.
- **GATE-05's before/after coverage inventory** — Phase 235.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GATE-01 | The nightly scheduled run is green, or every remaining red lane is a filed, diagnosed defect with an owner. | § Nightly Red Inventory (live-verified against run `30425416933`); § GitHub Pages Publisher Diagnosis; § ci-observe Leniency Removal |
| GATE-02 | Generated-host parity is verified on a lane that actually executes; no required or aggregated lane can report pass solely because it was skipped by a stale condition. | § GATE-02: The 320px Reflow Failure (artifact evidence downloaded and read, two hypotheses falsified); § Anchor Verification (`ci.yml:1674`); § Contradiction C-2 (D-10's boundary is inverted) |
| GATE-03 | `ci-gate` distinguishes "skipped because correctly gated for this event" from "skipped because its gate rotted", and fails on the latter. | § GATE-03: Verdict Script Specification (exact manifest columns, exact `ci-gate` context surface, the `needs: changes` gap); § House Pattern: guard + self-test pair |
| GATE-04 | `admin_eval_render` runs green on its new lane, and the harness guards downstream of its Playwright phase demonstrably execute. | § GATE-04: b1-b6 Precondition Inventory (six concrete red vectors, each with a no-`continue-on-error` remedy); § Contradiction C-3 (p05 must be retired same-commit) |
| DX-05 | The two filed release-lane defects are resolved — `gate-ci-green` no longer times out on a green release, and the `release-lane-rot` notifier raises an issue when a lane fails. | § DX-05: Token Permissions For Label Creation (authoritative docs answer); § DX-05: Extracting `wait-for-ci-gate.sh`; live verification of label + issue #118 |
</phase_requirements>

---

## Summary

Every file, line anchor, and run ID cited in `231-CONTEXT.md` was re-verified at HEAD `76d91117` by direct read and by live `gh` calls. **21 of 24 anchors are exact.** Three drifted (all cosmetic: `admin-eval-harness.sh:63` → `:55`; `ci-demotion-observer.sh:70-80` → `:74-89`; `playwright-github-pages.yml`'s "`:81` → `:95`" understates two intervening steps). None of the drift changes a decision.

**Three findings materially change what the plan must contain, and none of them contradicts a decision — they are boundaries CONTEXT.md did not know about.** (1) `scripts/ci/prohibitions/honest-skip-parity.test.mjs`, cited by D-01 and D-10 as the three-way parity enforcer, **does not exist**; the real enforcer is `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs`, and it never asserts the manifest's `gate` column, which inverts D-10's stated hard-fail boundary. (2) `scripts/ci/prohibitions/p05-admin-eval-red-not-abandoned.test.mjs` **asserts that `continue-on-error: true` is present in `admin_eval_render`** and that GATE-04's REQUIREMENTS.md row does not say `Complete` — so D-11 step 4 and the phase's own requirement bookkeeping will both red `fast_checks` unless p05 is retired in the same commit. p05's own comment anticipates exactly this and instructs it be done "deliberately, in Phase 231, not silently." (3) SC-2's stated observable `9 passed` **never appears in any log**: `admin-acceptance-smoke.sh --test all` runs Playwright twice, and a green run prints `8 passed` and then `1 passed`.

On GATE-02's 320px failure, the diagnosis is substantially advanced. The `generated-admin-failure-diagnostics` artifact from run `30425416933` was downloaded and read. **The screenshot proves the overflow is real, not a measurement artifact** — the login card visibly extends past the 320px viewport with "Email for sign-in lin[k]" clipped at the right edge. The brand wordmark `SigraAdminSmoke` **is already breaking correctly** (`Sigra / Admi / nSm / oke`), so the running webfont/wordmark hypothesis is not the cause of the assertion failure — and the filed todo's proposed fix (narrow `overflow-wrap: anywhere` to `break-word` on `.sigra-auth__product`) would make the assertion fail *more*, not less. Two candidate mechanisms were falsified by live evidence: the runner image is byte-identical between a passing and a failing run (`ubuntu24/20260720.247`), and so are the Chromium (`147.0.7727.15`) and WebKit (`26.4`) builds. The surviving primary hypothesis is that the overflow is **structural and always present**, driven by the `<input>` elements' intrinsic min-content width (default `size≈20` characters at a 32px root font) propagating up through grid items that carry no `min-width: 0`, and that the ~62% of "passes" are **racy false-greens** where `page.evaluate` reads `innerWidth` before the 320px viewport is applied in the renderer.

**Primary recommendation:** Sequence exactly per D-24, but insert a *pre-work* task before GATE-02's fix that instruments the assertion to report *which element overflows and what `innerWidth` was observed* — the diagnosis is one instrumented run away from certain, and every downstream decision (CSS fix vs. wait-for-layout fix vs. both) depends on it. Then treat p05's retirement and p10's tier-A floor as first-class same-commit obligations alongside every YAML edit.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Honest-skip enumeration (what may legitimately skip) | Data file (`.github/ci-skip-manifest.tsv`) | — | D-01: one oracle. The manifest's header block explicitly assigns enumeration to itself and consequence to GATE-03. |
| Honest-skip *verdict* (does this run's skip set pass?) | `scripts/ci/` bash guard | Step inside `ci-gate` job | D-02: the job already owns the consequence; a script keeps the logic testable off-CI. |
| Gate consequence (fail the run) | `ci-gate` job (`ci.yml:1789-1840`) | — | Only job whose `result` propagates to `notify_release_lane_rot` and to the DAG. |
| Three-way manifest ⇔ ci.yml parity | `scripts/ci/prohibitions/p10-*.test.mjs` (node:test) | `fast_checks` step `ci.yml:354` | Already exists; must be *extended*, not duplicated. See C-2. |
| Generated-host parity execution | `generated_admin_playwright_smoke` job | `scripts/ci/admin-acceptance-smoke.sh` | The job is the lane; the script is the work. D-06 changes only the lane's gate. |
| Reflow correctness at 320px/200% | Shipped CSS (`priv/templates/sigra.install/core/sigra_auth.css`) | Spec assertion (`admin-generated.spec.ts:174-176`) | The assertion is a *detector*. The fix belongs in the CSS, per D-09's "not an accepted outcome" on narrowing. |
| Eval-harness guard execution | `scripts/ci/admin-eval-harness.sh` phases b1-b6 | `admin_eval_render` job | Harness owns ordering + banners; job owns lane, browsers, and artifact upload. |
| Release-lane wait logic | `scripts/ci/wait-for-ci-gate.sh` (new, D-21) | `release-please.yml` `gate-ci-green` step | Extraction is what makes an unobservable receipt observable. Same move as Phase 230's `docs-only-classify.sh`. |
| Tracking-issue creation | `scripts/ci/notify-failure-issue.sh` | Two workflow consumers | Already shared (Phase 222 D-07); D-22 only adds a self-heal branch. |

---

## Anchor Verification At HEAD `76d91117`

Every anchor named in `231-CONTEXT.md` `<code_context>` and `<decisions>`, re-read at HEAD. `[VERIFIED: direct file read]` throughout.

### `.github/workflows/ci.yml` (2595 lines)

| CONTEXT cite | Verdict | Actual at HEAD |
|---|---|---|
| `:8-12` `force_fail_probe` input | **EXACT** | `force_fail_probe:` declared `:8`, `description` `:9`, `required` `:10`, `type: boolean` `:11`, `default: false` `:12`. |
| `:18-21` nightly cron | **EXACT** | `schedule:` `:18`; comment `:19-20`; `- cron: '30 4 * * *'` `:21`. |
| `:138-141` `changes.docs_only` non-PR branch | **EXACT** | `if [ "${EVENT_NAME}" != "pull_request" ]; then` `:138`; `echo "docs_only=false" >> "$GITHUB_OUTPUT"` `:139`; `exit 0` `:140`; `fi` `:141`. Job declared `:101`; `outputs.docs_only` `:105-106`. |
| `:155-230` fast_checks script/test pairs | **UNDERSTATED (not wrong)** | Job starts `:155`. The pairs run `:175`→`:343`; the prohibition suite runs at `:344-354`. New guards should be appended near `:322` (docs-only classifier self-test) — the Phase-230 tail. |
| `:1674` stale `generated_admin_playwright_smoke` `if:` | **EXACT** | `if: github.event_name != 'pull_request' \|\| github.head_ref == 'ship/v1.42-ci-gate-remediation'`. Job declared `:1662`, `name:` `:1663`, `timeout-minutes: 15` `:1671`, D-08 comment `:1672-1673`, `needs: release_ref_guard` `:1675`. |
| `:1707` its Playwright browser install | **EXACT** | `run: npx playwright install --with-deps chromium webkit`. No cache step in this job. |
| `:1789-1840` `ci-gate` job | **EXACT** | Job `:1789`; `name: ci-gate` `:1790`; `timeout-minutes: 5` `:1792`; `if: always()` `:1803`; single step `:1805`; `env:` map `:1806-1815`; `run:` `:1816-1840`. |
| `:1793-1802` its `needs:` | **EXACT** | 9 entries: `install_golden_contract`, `library_tests`, `library_tests_dep_off`, `install_smoke`, `upgrade_smoke`, `example_http_smoke`, `example_playwright_smoke`, `generated_admin_playwright_smoke`, `fast_checks`. **`changes` is NOT among them** — see § GATE-03 spec. |
| `:1831` skipped-counts-as-pass | **EXACT** | `if [[ "$result" != "success" && "$result" != "skipped" ]]; then`. |
| `:2450` job-level `continue-on-error` | **EXACT** | `continue-on-error: true` at 4-space indent under `admin_eval_render` (job `:2440`). |
| `:2517-2519` chromium-only install | **EXACT** | `- name: Install Playwright browsers (chromium only — admin-eval uses chromium)` `:2517`; `working-directory` `:2518`; `run: npx playwright install --with-deps chromium` `:2519`. |
| `:2548` step-level `continue-on-error` — MUST STAY | **EXACT** | Under step `id: admin_eval_harness` (`:2547`). |
| `:2560-2565` re-fail step | **EXACT** | `- name: Fail the job if harness did not PASS` `:2560`; `if: steps.admin_eval_harness.outcome == 'failure'` `:2562`; `exit 1` `:2565`. |
| `:2585-2595` `nightly_probe` | **EXACT** | Job `:2585`; `if: github.event_name != 'pull_request'` `:2589`; step `if: ${{ inputs.force_fail_probe }}` `:2592`; `exit 1` `:2595` (last line of file). |
| `:1288` / `:1950` / `:2258` / `:2506` `Run demo seeds` | **EXACT, all four** | `grep -n "Run demo seeds"` returns precisely these four lines. Each runs `mix run priv/repo/seeds.exs` with `MIX_ENV: dev` + `PG*` env. |

**Additional anchors discovered (not in CONTEXT, needed by the plan):**

| Anchor | What it is | Why the plan needs it |
|---|---|---|
| `ci.yml:1301-1320` | The single Playwright browser cache in the repo (`example_playwright_smoke` only). Key `:1319` = `${{ runner.os }}-playwright-chromium-webkit-1.59.1-v1`; `restore-keys` `:1320` = `${{ runner.os }}-playwright-chromium-webkit-`. | D-11 step 1 says "re-token the Phase-230 browser-set cache key." **There is no browser cache in `admin_eval_render`.** The key that must not be shared lives here. Re-tokening it (e.g. `-v2`) is the correct minimal action; adding a *new* cache to `admin_eval_render` requires a distinct key. Comment `:1304-1315` states the rationale verbatim and names Phase 231 GATE-04. |
| `ci.yml:344-354` | `- name: Phase 230 prohibition guards` → `run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | This is where p05 and p10 execute. Every prohibition test runs on every PR and push inside `fast_checks`. |
| `ci.yml:1785` | `name: generated-admin-failure-diagnostics` (upload-artifact) | The artifact D-09 requires. |
| `ci.yml:1851-1881` | `notify_release_lane_rot` job; `permissions: issues: write` at `:1857-1858`; `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` `:1859-1860`. | The declared permission set D-22's self-heal must work under. |
| `ci.yml:57` | `release_ref_guard` job | Sole `needs:` of both `generated_admin_playwright_smoke` and `admin_eval_render`. A skip/failure there cascades into a `skipped` on both — a GATE-03 edge case. |

### `.github/workflows/ci-observe.yml` (183 lines)

| CONTEXT cite | Verdict | Actual at HEAD |
|---|---|---|
| `:16-23` GATE-03 boundary note | **NEAR-EXACT** | `# BOUNDARY WITH PHASE 231 (GATE-03)` at `:16`; body `:17-21`; `:22` blank; `:23-25` a separate `workflow_run`-default-branch note. Read `:16-21` as the boundary note. |
| `:130-136` leniency branch (D-19 deletes) | **NEAR-EXACT — removal target is `:123-136`** | Rationale comment `:123-129`; `# REMOVAL CONDITION: Phase 231 GATE-01…` `:130-132`; `if [ "$RUN_EVENT" = "schedule" ]; then` `:133`; `::warning::` echo `:134`; `exit 0` `:135`; `fi` `:136`; `exit 1` `:137` **stays**. Deleting only `:130-136` leaves an orphaned rationale comment at `:123-129`; delete `:123-136` inclusive. |

### `.github/workflows/playwright-github-pages.yml` (196 lines)

| CONTEXT cite | Verdict | Actual at HEAD |
|---|---|---|
| `:81` → `:95` "no `Run demo seeds`" | **CLAIM TRUE; line span understated** | `- name: Setup example dev DB` `:81`, `run: mix ecto.create && mix ecto.migrate` `:88`. Then `Install Playwright deps` `:89-91`, `Install Playwright browsers` `:92-94`, `Boot example app in background` `:95-103`. **Confirmed: no `Run demo seeds` step anywhere in the file.** |
| Insertion point | — | **After `:88`**, before `:89`, mirroring `ci.yml:1288-1296` verbatim minus the `docs_only` `if:` (this workflow has no `changes` job). |
| Scheduling | — | `cron: '45 6 * * *'` `:18`; also `workflow_dispatch` `:15` and a path-filtered `push: branches:[main]` `:19-25` whose paths include `test/example/priv/playwright/**` — **so the phase's own PR merge will trigger this workflow**, giving an in-milestone observation without waiting for the 06:45 cron. |
| Permissions | — | `contents: write`, `pages: write` at `:36-38`. |

### `.github/workflows/release-please.yml` (379 lines)

| CONTEXT cite | Verdict | Actual at HEAD |
|---|---|---|
| `:96-104` `gate-ci-green` job | **EXACT** | Job `:96`; `name:` `:97`; `needs: release-please` `:99`; `if: ${{ needs.release-please.outputs.release_created == 'true' }}` `:100`; `permissions: actions: write / contents: read` `:101-103`; `steps:` `:104`. **Confirmed: no `timeout-minutes`.** |
| `:119` `max_attempts` | **EXACT** | `max_attempts=60` `:119`; `wait_seconds=30` `:120`; loop `:124`. Ceiling = 60 × 30s = 30 min. |
| `:344-379` unexercised `release-lane-rot` consumer | **EXACT** | `notify-release-failure:` `:344`; `needs: [release-please, gate-ci-green, publish-hex]` `:347`; `if:` `:348-352`; `bash scripts/ci/notify-failure-issue.sh` `:379` (last line of file). **Declares no job-level `permissions:`** → inherits the workflow-level block at `:19-23` (`actions: write`, `contents: write`, `issues: write`, `pull-requests: write`). |

### `scripts/ci/` and specs

| CONTEXT cite | Verdict | Actual at HEAD |
|---|---|---|
| `notify-failure-issue.sh:26-30` (comment branch) | **EXACT** | `existing="$(gh issue list --label … )"` `:26`; `if [[ -n "$existing" ]]` `:28`; `gh issue comment` `:30`. |
| `notify-failure-issue.sh:33` (create branch) | **EXACT** | `gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY"` `:33`. File is 34 lines; env fail-closed guards `:21-24`. |
| `ci-demotion-observer.sh:37-39` (bare-`gh`-via-PATH) | **EXACT** | `# Security: never echoes GH_TOKEN … \`gh\` is invoked bare via PATH so the self-test can shadow it with a recording stub — no network call and no GH_TOKEN anywhere in scripts/ci/ci-demotion-observer.test.sh.` |
| `ci-demotion-observer.sh:70-80` (non-vacuity) | **DRIFT → `:74-89`** | Comment block `:74-78`; `ASSERT_ROWS="$(awk …)"` `:79-84`; `ASSERT_COUNT` `:86`; `if [[ "$ASSERT_COUNT" -lt 2 ]]; then fail "… the parse broke, this is not a pass"` `:87-89`. |
| `admin-eval-harness.sh:63` (`set -euo pipefail`) | **DRIFT → `:55`** | `set -euo pipefail` is line **55**. Line 63 is a comment (`#   admin-eval        — Desktop Chrome DPR1, HARD-GATE geometry (D-15)`). The claim is still true. |
| `admin-eval-harness.sh:93-116` (banners) | **EXACT, all seven** | `(b1) stale-render guard` `:93`; `(b2) evidence anchor integrity check` `:96`; `(b3) fix-queue derived-field lint (auto_eligible, priority, open_findings)` `:99`; `(b4) quality findings consistency guard (working-tree vs committed HEAD)` `:107`; `(b5) award ledger verify-then-climb guard (working-tree vs committed HEAD)` `:110`; `(b6) settled findings lint` `:113`; `admin-eval-harness: PASS — all phases green` `:116`. Also `(a)` `:68` and `(a2)` `:84`. |
| `stale-render-guard.sh:1-24` (b1 hard-fails) | **EXACT** | Four hard-fail conditions documented `:4-9`; admin globs `:11-18`; `set -euo pipefail` `:26`. Implementations: absence `:55-60`, sha mismatch `:78-83`, unreachable `:85-92`, source-newer `:94-104`. |
| `probes.ts:176` | **EXACT** | `: el.className` (truthiness only, ternary → `.${Array.from(el.classList).join('.')}` `:177`). Safe. |
| `probes.ts:237` | **EXACT** | Identical shape. Safe. |
| `probes.ts:380` | **EXACT** | `const isEmberClass = el.classList.contains('sg-ember') \|\| el.className.includes('ember');` — throws `TypeError: el.className.includes is not a function` on SVG elements. |
| `playwright.config.ts:215-217` | **EXACT** | `name: 'admin-eval-mobile'` `:215`; `testMatch: ADMIN_EVAL_SPEC` `:216`; `use: { ...devices['iPhone 13'] }` `:217`. Block spans `:214-218`. |
| `admin-generated.spec.ts:169-176` | **EXACT** | `setViewportSize({width:320,height:800})` `:169`; `html.style.fontSize = "32px"` `:170-172`; `expect(heading "Sign in").toBeVisible()` `:173`; `expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)` `:174-176`. |
| `MAINTAINING.md:104-110` | **EXACT** | 5 required-check names at `:106-110`; ruleset 14941512 named `:102`; "`ci-gate` is NOT an enforced required check" `:112`. |
| `MAINTAINING.md:137` | **EXACT** | `- \`generated_admin_playwright_smoke\` (generated-host admin behavior; see its \`timeout-minutes:\` for the current ceiling)` under the **"Nightly / main / dispatch-broad coverage (… skipped on PRs)"** heading `:133`. |
| `MAINTAINING.md:142-199` | **EXACT** | `### Honest-skip set after Phase 230 (v1.47 FAST-02/FAST-03/FAST-05)`; Tier A `:152-157`, Tier B `:159-174`, Tier C `:176-190`, "Not skipped" `:192-196`. |
| `MAINTAINING.md:255-262` | **EXACT** | Residual 4; the sentence "**that leniency is removed when Phase 231's GATE-01 lands.**" is `:262`. |
| `MAINTAINING.md:274` | **EXACT** | Residual 2, "Generated-host template parity — `generated_admin_playwright_smoke` … is fully moved to nightly." |

### `.github/ci-skip-manifest.tsv` — full header block and exact shape

**File is 76 lines.** Comment/header block `:1-56`. Column-header row at **`:60`**. **16 data rows at `:61-76`.** (CONTEXT's "17 rows" = 16 data + the column-header row.)

**Exact column order (tab-separated, `:60`):**
```
tier	kind	id	parent_job_id	display_name	gate_level	gate	observer
```

**Documented semantics (from the header block, verbatim summary):**
- `tier`: `A` = event-gated, pre-existing (Phase 196), NOT demoted by 230 — "Phase 231's GATE-01/GATE-02 own these; the observer deliberately does NOT assert on them". `B` = event-gated, demoted BY Phase 230. `C` = diff-gated (docs-only) — "a different audit question from A/B".
- `kind`: `job` | `step`.
- `id`: the ci.yml job id, or the step `id:` when `kind=step`. "Every id here MUST resolve in ci.yml."
- `parent_job_id`: owning job id when `kind=step`; `-` when `kind=job`. A step row's parent must also appear as a `kind=job` row.
- `display_name`: the job/step `name:` EXACTLY as ci.yml spells it (the Actions API returns names, never ids).
- `gate_level`: `job` | `step` — *where* the predicate is applied. "For the four ruleset-required tier-C lanes this MUST stay `step`."
- `gate`: the literal gating predicate, normalized (`${{ }}` stripped, whitespace collapsed).
- `observer`: `assert` (must have executed on a non-PR run; tier B only) | `exempt` (event-gated AND outcome-gated, so a skip on a healthy run is correct) | `ignore` (outside observer scope; tier A/C).

**Consumers named in the header:** `ci-demotion-observer.sh` (reads `assert` rows), `honest-skip-parity.test.mjs` *(does not exist — see C-1)*, and "Phase 231 GATE-03".

**The 16 data rows at HEAD:**

| # | tier | kind | id | parent | gate_level | observer |
|---|---|---|---|---|---|---|
| 1 | A | job | `install_matrix` | - | job | ignore |
| 2 | A | job | `upgrade_smoke` | - | job | ignore |
| 3 | A | job | `passkeys_manual_fallback_smoke` | - | job | ignore |
| 4 | A | job | `passkeys_opt_out_smoke` | - | job | ignore |
| 5 | A | job | `generated_admin_playwright_smoke` | - | job | ignore |
| 6 | A | job | `nightly_probe` | - | job | ignore |
| 7 | A | job | `admin_design_recapture` | - | job | ignore |
| 8 | A | job | `admin_checkpoint_recapture` | - | job | ignore |
| 9 | A | job | `notify_release_lane_rot` | - | job | **exempt** |
| 10 | B | job | `admin_eval_render` | - | job | **assert** |
| 11 | B | step | `design_gallery_snapshots` | `example_playwright_smoke` | step | **assert** |
| 12 | C | job | `library_tests_dep_off` | - | job | ignore |
| 13 | C | job | `example_unit_smoke` | - | **step** | ignore |
| 14 | C | job | `install_smoke` | - | **step** | ignore |
| 15 | C | job | `example_http_smoke` | - | **step** | ignore |
| 16 | C | job | `example_playwright_smoke` | - | **step** | ignore |

Row 5's `gate` column literally records the stale string: `github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation'`.

---

## Contradictions With Locked Decisions

These are stated with the evidence, per the research brief. **None of them changes a decision's intent** — each is a factual correction to a premise, with a concrete remedy that preserves the decision.

### C-1 — `honest-skip-parity.test.mjs` does not exist [VERIFIED: `find` + `ls` at HEAD]

D-01 and D-10 both cite `scripts/ci/prohibitions/honest-skip-parity.test.mjs`. That file is not in the repo. `ls scripts/ci/prohibitions/` returns exactly:

```
_lib.mjs
p01-committed-method-provenance.test.mjs   p08-no-cache-saving-overclaim.test.mjs
p02-axe-signal-not-reduced.test.mjs        p09-timeouts-not-truncating.test.mjs
p03-no-green-on-empty-grep.test.mjs        p10-no-undocumented-demotion.test.mjs
p04-no-release-lane-cancellation.test.mjs  p11-sc-restatement-recorded.test.mjs
p05-admin-eval-red-not-abandoned.test.mjs  p12-run-id-provenance.test.mjs
p06-never-docs-gate-asserting-lanes.test.mjs  p13-no-lane-green-because-skipped.test.mjs
p07-docs-only-green-is-labelled.test.mjs
```

`git log -S honest-skip-parity` finds nothing; a repo-wide grep for the string finds only `test/fixtures/prohibitions/p07-honest-skip-line-citation.md` (a p07 fail-first fixture). The parity work is split across two files:

- **`p10-no-undocumented-demotion.test.mjs`** — manifest ⇔ `ci.yml`. Six assertions: tier floors (`rows >= 12`, `A >= 9`, `B >= 2`, `C >= 5`); every `id` resolves in `ci.yml`; every step row's parent is a manifest job row; every `display_name` matches ci.yml's declared `name:`; **no event-gated job in ci.yml is missing from the manifest**; and a negative control that `fast_checks` / `library_tests` / `library_tests_shard` are *absent*.
- **`p07-docs-only-green-is-labelled.test.mjs`** — `MAINTAINING.md` ⇔ manifest, but **tier B only** (`section.includes(r.id)` for each tier-B row) plus rot-surface bans (no `ci.yml:<line>` citations, no hardcoded ExUnit count, no hardcoded duration inside the honest-skip section).

**Consequence for D-01:** the "one oracle" posture is correct and the manifest is genuinely the enumeration — but the parity is **not** three-way for tier A, and no test asserts the `gate` column against `ci.yml` in either direction. GATE-03's verdict script is therefore the *first* consumer that will read `gate`, and the plan should consider extending p10 with a `gate`-column assertion as a cheap, in-scope hardening (it directly serves GATE-03's "a condition that reads plausibly and verifies nothing" mandate).

### C-2 — D-10's hard-fail boundary is inverted for the manifest row [VERIFIED: read of p10 + p07 + manifest]

D-10 states that removing `ci.yml:1674` "requires a same-commit edit to three other files **or `fast_checks` reds**." Traced against the actual guards:

| Same-commit edit D-10 names | Does omitting it red `fast_checks`? | Why |
|---|---|---|
| `.github/ci-skip-manifest.tsv` row 5 | **NO.** Leaving the stale row is silently accepted. | p10 asserts `id` resolves (it does — the job still exists) and `display_name` matches (unchanged). p10 **never reads the `gate` column**. p10's "no event-gated job missing from the manifest" test only fires in the *other* direction. |
| `MAINTAINING.md:137` | **NO.** | p07 checks only tier-**B** ids against the prose. `generated_admin_playwright_smoke` is tier A. |
| `MAINTAINING.md:274` | **NO.** | Not asserted by any guard. |

**And the natural correct edit actively reds.** The right manifest action is to **delete row 5** — a job with no `if:` never skips and does not belong in an honest-skip enumeration. But p10's first test asserts `counts.A >= 9`, and there are exactly 9 tier-A rows. Deleting row 5 drops tier A to 8 → **`fast_checks` fails on a message about a broken parse**, which is precisely the "cause that looks unrelated" D-10 was trying to warn about, just arriving from the opposite direction.

**Remedy the plan must specify (same commit as D-06):**
1. Delete manifest row 5.
2. Lower p10's tier-A floor from `>= 9` to `>= 8` **and update its failure message** to record why the count dropped (a floor lowered without a recorded reason is itself a rot surface).
3. Edit `MAINTAINING.md:137` (move the lane out of the nightly-only list) and `MAINTAINING.md:152-153` (tier-A prose also names it — **D-10 does not mention this line; it must be edited too**), and retire residual 2 at `:274`.
4. Consider adding the `gate`-column assertion to p10 so the next stale gate *does* red.

### C-3 — p05 will red on D-11 step 4 and on the requirement bookkeeping [VERIFIED: read of `p05-admin-eval-red-not-abandoned.test.mjs`]

`p05` runs on every PR and push (`ci.yml:354`). It contains four assertions, two of which this phase necessarily violates:

```js
test('the unread red is retained and visible, not masked away', () => {
  assert.match(block, /^ {4}continue-on-error:\s*true\s*$/m, …);
});
test('GATE-04 is still tracked as an open follow-up', () => {
  …
  assert.ok(!/\bComplete\b/.test(row), …);   // row = the GATE-04 line in REQUIREMENTS.md
});
```

D-11 step 4 deletes `ci.yml:2450`. The moment it does, p05's third test fails. Separately, marking GATE-04 `Complete` in `REQUIREMENTS.md`'s traceability table fails p05's fourth test.

**This is anticipated by p05's own text**, which is why it is a boundary and not a blocker:

> *"If it is genuinely complete, this guard has served its purpose and should be retired together with the continue-on-error assertion above — deliberately, in Phase 231, not silently."*

**Remedy:** p05's retirement is a first-class task in the GATE-04 wave, in the **same commit** as the `continue-on-error` deletion. Two defensible shapes:
- **(a) Invert it** — keep the file, flip the third test to assert `continue-on-error: true` is **absent** from the `admin_eval_render` block, and drop the fourth test. This preserves a forward-only ratchet (the mask can never be silently reinstated) and is the stronger option.
- **(b) Delete it** with a recorded rationale in `MAINTAINING.md`. Weaker: nothing then stops a future re-mask.

Recommend **(a)**. Note that `p05`'s *second* test (`if:` must contain `github.event_name != 'pull_request'`) stays valid and must keep passing — D-11 does not change `admin_eval_render`'s lane.

Also verify: `scripts/ci/prohibitions/p13-no-lane-green-because-skipped.test.mjs` reads `230-EVIDENCE.md` and asserts each `observer: assert` manifest row appears in a captured slot and is never recorded as `skipped`. D-06's manifest edit touches tier A only, so p13 is unaffected. **Do not delete manifest rows 10 or 11** — p13 and `ci-demotion-observer.sh` both hard-fail on fewer than 2 assert rows.

### C-4 — SC-2's `9 passed` observable does not exist [VERIFIED: live `gh run view --log`]

D-25 SC-2 says to observe "`9 passed` in `gh run view --log --job <id>`". `admin-acceptance-smoke.sh --test all` invokes Playwright **twice** (the shell/reflow suite, then the denial-response suite). Live logs:

- **Passing** run `30389700235`, job `90377880503`:
  `Running 9 tests using 1 worker` → `8 passed (10.7s)` → (second invocation) → `1 passed (1.5s)`
- **Failing** run `30425416933`, job `90490780778`:
  `Running 9 tests using 1 worker` → `1 failed` / `7 passed (14.7s)`; the second invocation never runs.

**Remedy:** restate SC-2's observable as **`Running 9 tests using 1 worker` followed by `8 passed` and then `1 passed`, with zero `failed` lines** — or, more robustly, as *the job's own `conclusion: success` plus the `Running 9 tests` line proving non-vacuity*. Record the restatement explicitly; `p11-sc-restatement-recorded.test.mjs` exists precisely to force SC restatements to be written down rather than quietly diverged from.

### C-5 — D-09's running hypothesis is contradicted by its own todo, and the todo's fix would worsen the assertion [VERIFIED: artifact read + CSS read]

See § GATE-02 for the full chain. In short: the filed todo asserts *"WCAG reflow containment is green — nothing scrolls horizontally"*, which is the exact opposite of what the failing assertion measures; and its proposed remedy (narrow `.sigra-auth__product`'s `overflow-wrap: anywhere` to `break-word`) would remove the *only* thing currently preventing the 15-char token from overflowing. The todo describes a **cosmetic** complaint about a *successful* break. Closing it against a `scrollWidth` fix would be closing the wrong finding. **Recommend: keep the two separate.** Fix the overflow (GATE-02), and leave the mid-word-break aesthetics todo open with a note that its proposed direction conflicts with the reflow assertion.

---

## Standard Stack

**No new runtime, library, or package dependency is introduced by this phase.** Every artifact it touches is already in the repo.

### Tooling already in use (versions verified at HEAD)

| Tool | Where pinned | Purpose in this phase |
|---|---|---|
| `bash` (`set -euo pipefail`) | every `scripts/ci/*.sh` | GATE-03 verdict script, `wait-for-ci-gate.sh`, both self-tests |
| `node --test` (node 20, `actions/setup-node@8207627…` v7.0.0) | `ci.yml:354`, `ci.yml:1691-1695` | p05/p10 prohibition edits |
| `jq` | preinstalled on `ubuntu-latest`; used in `ci-observe.yml`, `release-please.yml:132` | run-payload parsing |
| `gh` CLI | preinstalled on `ubuntu-latest` | `gh run list` / `gh run view` / `gh issue *` / `gh label *` |
| `awk` (`-F'\t'`) | `ci-demotion-observer.sh:79-84` | manifest parsing — **reuse this exact idiom**, do not introduce a TSV library |
| `@playwright/test` 1.59.1 | `test/example/priv/playwright/package-lock.json`; key at `ci.yml:1319` | the 320px spec, admin-eval spec |
| Chromium `147.0.7727.15` (`playwright chromium v1217`), WebKit `26.4` (`v2272`) | resolved by `npx playwright install` | GATE-04 bug 1 |
| `phx_new` 1.8.8 | `ci.yml:1701`, `admin-acceptance-smoke.sh` `PHX_NEW_PIN` | generated-host scaffold |
| Runner image `ubuntu24/20260720.247` | `ubuntu-latest` | falsified as a 320px variance source |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| `awk -F'\t'` manifest parse | `node` + a TSV parser | Adds a Node hop inside a bash guard for no gain; breaks symmetry with `ci-demotion-observer.sh`, which is D-04's cited precedent. **Reject.** |
| A new `honest-skip-parity.test.mjs` | Extending `p10` | C-1: creating the file CONTEXT believed already existed would produce two node:test parity oracles. **Extend p10.** |
| A second `ci-gate`-like job for GATE-03 | A step inside `ci-gate` | D-02 locks the step. A new job would also need to be added to the DAG and would not own the consequence. |
| `gh api` for label ops | `gh label list` / `gh label create` | `gh label` is the documented CLI surface and is trivially stub-shadowable in the existing self-test. |

**Installation:** none.

---

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** Verified by reading the full CONTEXT scope: every change lands in `.github/workflows/*.yml`, `.github/ci-skip-manifest.tsv`, `scripts/ci/*`, `MAINTAINING.md`, `priv/templates/sigra.install/core/sigra_auth.css`, `test/example/priv/playwright/**`, and `.planning/**`. No `mix.exs`, `package.json`, or `package-lock.json` edit is in scope.

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

If the 320px fix should ever require a font package on the CI image (it should not — see § GATE-02), that is a new-dependency decision the plan must escalate rather than absorb.

---

## House Patterns The Plan Must Replicate

### Pattern 1: the `scripts/ci/<name>.sh` + `<name>.test.sh` pair

**Shape of the guard** (from `ci-demotion-observer.sh`, the closest analog to "read a TSV, emit a verdict"):

```bash
#!/usr/bin/env bash
# <Phase> (<REQ>): one-paragraph CONTRACT.
#
# WHY IT IS NOT <the obvious alternative>   ← every shipped guard explains this
# SCOPE (deliberate, recorded)
# BOUNDARY WITH <adjacent phase>
#
# Security: never echoes GH_TOKEN or any secret. `gh` is invoked bare via PATH so the
# self-test can shadow it with a recording stub -- no network call and no GH_TOKEN
# anywhere in scripts/ci/<name>.test.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPO="szTheory/sigra"
MANIFEST="${ROOT}/.github/ci-skip-manifest.tsv"
RUN_ID="${GITHUB_RUN_ID:-}"
FROM_JSON=""
FORMAT="table"
EVENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run)       RUN_ID="$2";   shift 2;;
    --repo)      REPO="$2";     shift 2;;
    --manifest)  MANIFEST="$2"; shift 2;;
    --from-json) FROM_JSON="$2";shift 2;;
    --format)    FORMAT="$2";   shift 2;;
    --event)     EVENT="$2";    shift 2;;
    *) echo "<name>: FAIL: unknown arg: $1" >&2; exit 2;;   # NOTE: exit 2, not 1
  esac
done

fail() { echo "<name>: FAIL: $*" >&2; exit 1; }
```

Conventions that are load-bearing and must be preserved:
- **Exit-code trichotomy:** `0` = pass, `1` = assertion failure / hard error, **`2` = usage error** (unknown flag), and the self-test asserts `2` with **zero** `gh` round-trips.
- **`--from-json`** so the self-test never touches the network — and so `ci-observe.yml` can feed a saved payload.
- **`--format table|json`** validated up front (`ci-demotion-observer.sh:68-70`).
- **Non-vacuity floor**, always with the literal phrase `the parse broke, this is not a pass` (`:88`). The message convention is documented in `prohibitions/_lib.mjs:22-24` as borrowed from `test/sigra/planning/phase_230_ci_timeouts_test.exs`.
- **Manifest parse idiom** (`:79-84`) — copy verbatim, changing only the column filter:
  ```bash
  ASSERT_ROWS="$(awk -F'\t' '
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    $1 == "tier" { next }
    $8 == "assert" { print $2 "\t" $3 "\t" $4 "\t" $5 }
  ' "$MANIFEST")"
  ```
- **`grep -c .` caveat** (`ci-demotion-observer.test.sh:140-142`): `grep -c .` prints `0` **and exits 1** on no match, so `|| echo 0` emits a second zero and every later arithmetic comparison becomes a syntax error. Swallow the status with `|| true` instead.
- Also repo-wide: **use `grep -c`, not `grep -q`, in bash CI scripts under `pipefail`** (SIGPIPE), per an accumulated Phase-217 decision in `STATE.md`.

**Wiring into `fast_checks`** — the exact block shape at `ci.yml:175-343`:

```yaml
      - name: <Human-readable guard name>
        # Phase 231 (GATE-0X / D-0Y): one-to-three lines saying what this proves and,
        # if it is a self-test only, saying explicitly what it does NOT cover.
        run: bash scripts/ci/<name>.test.sh
```

A representative shipped pair, verbatim (`ci.yml:252-256`):

```yaml
      - name: Notify-failure-issue self-test
        # Phase 222 Plan 02 (HARD-01/HARD-02/D-07): hermetic proof that the shared
        # tracking-issue notifier is idempotent (create-once / comment-once) and
        # fail-closed on missing LABEL/TITLE/BODY. No real `gh` CLI or network call.
        run: bash scripts/ci/notify-failure-issue.test.sh
```

Note the two-step convention where a guard *and* its self-test both run (`ci.yml:208-211`):

```yaml
      - name: Quality ledger monotonic guard
        run: bash scripts/ci/quality-ledger-monotonic.sh --base "${{ steps.base.outputs.ref }}"
      - name: Quality ledger monotonic guard self-test
        run: bash scripts/ci/quality-ledger-monotonic.test.sh
```

For GATE-03 only the **self-test** belongs in `fast_checks`; the guard itself runs inside `ci-gate` (D-02).

### Pattern 2: the `gh`-shadowing recording stub (D-22's required shape)

`scripts/ci/ci-demotion-observer.test.sh` is the canonical form. The stub itself (`:110-121`) — note the heredoc is **unquoted** (`<<STUB`) so `${GH_STUB_LOG}` and `${PAYLOAD_FILE}` interpolate at write time, while `\$*` and `\${GH_STUB_FAIL:-}` are escaped to survive into the stub:

```bash
TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"; mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
PAYLOAD_FILE="${TMPDIR_ROOT}/payload.json"
: > "$GH_STUB_LOG"

cat >"${STUB_BIN_DIR}/gh" <<STUB
#!/usr/bin/env bash
# Recording stub for \`gh\` (test-only). Logs argv, returns the scripted payload.
set -euo pipefail
echo "\$*" >> "${GH_STUB_LOG}"
if [[ -n "\${GH_STUB_FAIL:-}" ]]; then
  echo "gh: simulated failure" >&2
  exit 1
fi
cat "${PAYLOAD_FILE}"
STUB
chmod +x "${STUB_BIN_DIR}/gh"

run_observer() {           # $1 = payload JSON, rest = argv
  local payload="$1"; shift
  printf '%s' "$payload" > "$PAYLOAD_FILE"
  : > "$GH_STUB_LOG"
  PATH="${STUB_BIN_DIR}:${PATH}" bash "$SCRIPT" --run 999 --manifest "$REAL_MANIFEST" "$@" 2>&1 || true
}
gh_call_count() { local n; n="$(grep -c . "$GH_STUB_LOG" 2>/dev/null || true)"; echo "${n:-0}"; }
```

The **existing** `notify-failure-issue.test.sh` stub (`:45-60`) uses a *quoted* heredoc (`<<'STUB'`) and dispatches on argv, returning `${GH_STUB_ISSUE_NUMBER:-}` for `issue list`:

```bash
cat >"${STUB_BIN_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${GH_STUB_LOG}"
if [[ "${1:-}" == "issue" && "${2:-}" == "list" ]]; then
  echo "${GH_STUB_ISSUE_NUMBER:-}"
  exit 0
fi
if [[ "${1:-}" == "issue" && ( "${2:-}" == "create" || "${2:-}" == "comment" ) ]]; then
  exit 0
fi
echo "gh stub: unexpected invocation: $*" >&2
exit 1
STUB
```

> **⚠ Hard-fail boundary CONTEXT.md does not name.** That stub's fallthrough is `exit 1` on any unrecognized invocation. The moment D-22 adds `gh label list` / `gh label create` to `notify-failure-issue.sh`, **all three existing test cases (A, B, C) break** — `set -euo pipefail` in the script under test propagates the stub's non-zero exit. **The plan must extend the stub with `label` branches in the same commit as the script change.** Suggested branches: `label list` → echo `${GH_STUB_LABEL_EXISTS:-}` (empty = absent); `label create` → `exit 0` (and `exit 1` when `GH_STUB_LABEL_CREATE_FAIL` is set, to exercise the soft-fail path).

Required new cases for D-22, mirroring the existing A/B/C naming:
- **D:** label absent → exactly one `label create`, then exactly one `issue create`.
- **E:** label present → **zero** `label create`, then `issue create`.
- **F:** existing open issue → zero `label create` calls **and** zero `issue create` (the comment path must not re-check the label).
- **G:** `label create` fails (permission denied) → the script still opens the issue (see § DX-05 for the recommended soft-fail).

### Pattern 3: the `workflow_dispatch` probe input + consuming job (D-05's model)

Input declaration (`ci.yml:6-12`, verbatim):

```yaml
on:
  workflow_dispatch:
    inputs:
      force_fail_probe:
        description: 'Intentionally fail a nightly-gated job to verify the nightly lane reports red (set true to probe).'
        required: false
        type: boolean
        default: false
```

Consuming job (`ci.yml:2579-2595`, verbatim):

```yaml
  # D-14 forced-failure probe: a needs-free, nightly-gated job that proves the
  # nightly trigger path reports red on a real failure. Dispatching with
  # `gh workflow run "CI" -f force_fail_probe=true` reds this job and only
  # this job. Normal nightly/push/dispatch runs (force_fail_probe=false) keep
  # the step skipped and the job green. Never runs on pull_request events.
  # NOT in ci-gate.needs — it is a standalone self-test, not a gate input.
  nightly_probe:
    name: Nightly probe (forced-failure self-test)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: github.event_name != 'pull_request'
    steps:
      - name: Forced-failure probe (nightly self-test)
        if: ${{ inputs.force_fail_probe }}
        run: |
          echo "force_fail_probe=true: intentionally failing to prove the nightly lane reports red"
          exit 1
```

Structural notes the SC-3 rot probe must mirror:
- The gate is at **step** level (`if: ${{ inputs.force_fail_probe }}`); the job-level `if:` is only the event gate. A step-level gate keeps the job green on ordinary runs while the probe step is `skipped`.
- `inputs.X` is readable **only** on `workflow_dispatch`; on `schedule` / `push` / `pull_request` it evaluates to empty (falsey). No `github.event.inputs` guard is needed.
- Dispatch command: `gh workflow run "CI" -f force_fail_probe=true` (add `--ref <branch>` for a branch-scoped probe).

**Divergence required for SC-3.** `nightly_probe` is deliberately *outside* `ci-gate.needs`. The SC-3 rot probe must do the opposite: it must reach `ci-gate`'s verdict step. The cleanest shape that preserves everything else is a **verdict-script-level** input rather than a new job — pass the probe flag into the GATE-03 step so it injects a synthetic rotted-skip row and the script's own verdict logic reds. That keeps the DAG unchanged and makes the fail direction reproducible forever. Suggested input name (Claude's Discretion): `force_rot_probe`, description modelled on `force_fail_probe`'s wording.

### Pattern 4: `install_golden_contract`'s always-run-job + `detect`-step + step-level `if:`

Available at `ci.yml:228-308` if any new *gating* is needed. Verified present; not required by any locked decision here. The `detect` idiom also appears inline in `fast_checks` at `ci.yml:177-194`.

---

## GATE-03: Verdict Script Specification

### The context surface actually available inside `ci-gate`

`ci-gate`'s `needs:` (`ci.yml:1793-1802`) contains **nine** entries. `changes` is **not** one of them.

**This is the single most important implementation constraint for GATE-03.** A step inside `ci-gate` cannot read `needs.changes.outputs.docs_only` today — the expression evaluates to empty, which under D-03's rule would make `library_tests_dep_off`'s docs-only skip look *illegitimate on every docs-only PR* and red the gate.

Three options, in preference order:

1. **Add `changes` to `ci-gate.needs`** (recommended). `changes` is a 5-minute-ceiling, ~36s job that already gates four required lanes; adding a `needs` edge from `ci-gate` costs zero wall-clock because `ci-gate` waits on nine slower lanes anyway. Add `DOCS_ONLY: ${{ needs.changes.outputs.docs_only }}` to the step's `env:` map. **Check p06** (`p06-never-docs-gate-asserting-lanes.test.mjs`) first: it asserts `fast_checks`, `library_tests`, `library_tests_shard` do **not** declare `needs: changes`. `ci-gate` is not in that `NEVER_DOCS_GATED` set, so this is safe — but read `_lib.mjs`'s `NEVER_DOCS_GATED` export at implementation time to confirm.
2. **Re-derive docs-only inside the verdict script** by calling `scripts/ci/docs-only-classify.sh`. Rejected — creates a second classification oracle, exactly the D-01 failure mode.
3. **Treat `library_tests_dep_off`'s skip as unconditionally legitimate on `pull_request`.** Rejected — it re-opens the "skipped by a rotted condition" hole for that lane.

### Everything a step inside `ci-gate` can read

| Expression | Available? | Notes |
|---|---|---|
| `needs.<job>.result` | ✅ for the 9 listed | Values: `success` \| `failure` \| `cancelled` \| `skipped`. Already mapped into `env:` at `:1806-1815` — extend that map. |
| `needs.<job>.outputs.*` | ✅ only if the job declares `outputs:` | Only `changes` declares any (`docs_only`, `:105-106`). |
| `github.event_name` | ✅ | `pull_request` \| `push` \| `schedule` \| `workflow_dispatch`. |
| `github.base_ref` / `github.head_ref` | ✅ but **only** on `pull_request` | Empty on every other event — this is the exact rot vector GATE-02 exists to remove. Do **not** use either in the verdict. |
| `inputs.<name>` | ✅ only on `workflow_dispatch` | The `force_rot_probe` seam. |
| The repo working tree | ❌ | `ci-gate` runs **no `actions/checkout` step** today. **The verdict script cannot read `.github/ci-skip-manifest.tsv` until a checkout step is added.** Add `- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` as the first step (SHA copied verbatim from `ci.yml:1686` / `:1862` — DX-02 requires SHA pinning). Default `fetch-depth: 1` suffices; the script reads a committed file, not history. |

**Security requirement (repo convention, non-negotiable):** every GitHub context string must reach the shell via an `env:` mapping, never inlined into a `run:` body. Documented at `ci.yml:132-135` and `notify-failure-issue.sh:14-18`, and enforced by the existing style throughout. GATE-03's step must follow it.

### The verdict the script must compute

Inputs: the manifest path, `github.event_name`, the nine `needs.*.result` values, `changes.outputs.docs_only`, and (optionally) the rot-probe flag.

```
0. Non-vacuity (D-04)
   Parse the manifest. If it yields ZERO rows for the ci-gate.needs intersection,
   FAIL with the literal phrase "the parse broke, this is not a pass".
   Concretely: at least 6 of the 9 ci-gate.needs lanes must appear in the manifest
   (upgrade_smoke, library_tests_dep_off, install_smoke, example_http_smoke,
   example_playwright_smoke, generated_admin_playwright_smoke-until-D-06-removes-it).
   Floor after D-06 lands: >= 5.

1. Build ALLOWED_SKIPS for this event.
   if event != 'pull_request':
       ALLOWED_SKIPS = {}                       # D-03: changes emits docs_only=false
                                                # unconditionally on non-PR events
                                                # (ci.yml:138-141), so no tier-C skip
                                                # is reachable.
   else:
       ALLOWED_SKIPS = { 'upgrade_smoke' }      # tier A, event-gated, always legit on a PR
       if DOCS_ONLY == 'true':
           ALLOWED_SKIPS += { 'library_tests_dep_off' }   # tier C, gate_level=job

2. Verdict per lane.
   for lane in the 9 ci-gate.needs lanes:
       if result == 'skipped' and lane not in ALLOWED_SKIPS:
           FAIL, NAMING THE LANE, the event, and the manifest gate string that
           was supposed to justify the skip (or "no manifest row" when absent).
       if result not in {'success','skipped'}:
           FAIL (existing ci.yml:1831 behaviour — preserve it).

3. Rot detection: the manifest-vs-reality direction.
   For each lane in ALLOWED_SKIPS that actually skipped, the manifest row's `gate`
   column must be non-empty and must reference either `github.event_name` or
   `docs_only`. A gate string referencing `github.head_ref`, a branch name, or a
   literal SHA is a ROTTED CONDITION -- FAIL even though the lane was "allowed"
   to skip. This is the assertion that would have caught GATE-02's defect.

4. Positive control (anti-vacuity, second form).
   At least one lane must have been EVALUATED. If every lane's result is empty
   (a needs-map typo, a renamed job), FAIL -- never "nothing to check, so pass".
```

**Why step 3 matters:** without it the script is a *permission list*, and a permission list that grants a rotted gate is the very artifact GATE-03 exists to reject. Step 3 is what makes the manifest's `gate` column load-bearing for the first time (see C-1) and gives GATE-03 a falsifiable claim rather than a restatement of `ci.yml:1831`.

### Skip-cascade edge cases the script must not misclassify

| Situation | `needs.X.result` | Correct verdict |
|---|---|---|
| `release_ref_guard` fails → `generated_admin_playwright_smoke` never runs | `skipped` | This is a **cascade**, not a rot. The upstream failure will already red `ci-gate` through `library_tests`/`fast_checks` or through the guard's own lane if it were in `needs` — but `release_ref_guard` is **not** in `ci-gate.needs`. **Recommend: treat a `skipped` with no manifest row as FAIL and let the message say "no manifest row"** — that is honest, and the cascade is a real coverage loss. Do not add a special case. |
| Run cancelled (FAST-04 supersession on a PR branch) | `cancelled` | Already fails today via `ci.yml:1831` and must continue to. `ci-demotion-observer.test.sh` cases H/I establish that cancellations and timeouts are never waved through. |
| `library_tests_dep_off` skipped on a **non-docs-only** PR | `skipped` | FAIL. Its `if:` also depends on `needs.release_ref_guard.result == 'success'` (manifest row 12), so a red guard produces exactly this. Honest to fail. |
| Job renamed | result empty | Step 4's positive control catches it. Renaming is documented in `ci-demotion-observer.test.sh` case E as "the #1 rot mode". |

### Naming and shape (Claude's Discretion, with a recommendation)

- Script: `scripts/ci/honest-skip-verdict.sh` — reads as the consequence half of the manifest's own vocabulary.
- Self-test: `scripts/ci/honest-skip-verdict.test.sh`, wired into `fast_checks` near `ci.yml:322`.
- CLI: `--manifest <path>` (default `${ROOT}/.github/ci-skip-manifest.tsv`), `--event <name>`, `--docs-only <true|false>`, `--results <json>` or repeated `--lane <id>=<result>`, `--format table|json`, `--rot-probe`. Keep `exit 2` for usage errors.
- One step inside `ci-gate`, placed **before** the existing `Verify required release CI lanes` step so a rotted skip is reported before the generic result loop — or fold the existing loop into the script. **Recommend two steps**, keeping the existing loop byte-unchanged: the diff stays reviewable and the existing behaviour is provably preserved.

---

## GATE-04: b1-b6 Precondition Inventory (D-15's third defect class)

b1-b6 have never executed in CI. Below is every precondition that can red a b-phase in the CI environment but not locally, each with the remedy that does **not** restore `continue-on-error`. Sources: direct read of `admin-eval-harness.sh`, `stale-render-guard.sh`, `fix-queue-build.mjs`, `fix-queue-lint.sh`, `quality-findings-monotonic.sh`, `award-guard.mjs`, and `.gitignore`.

**Baseline facts (measured at HEAD):**
- `guides/reference/admin-render-sha.json` is **committed** and carries `186` cells totalling **33,642** `open_findings`.
- `guides/reference/fix-queue.json`, `settled-findings.tsv`, `admin-award-ledger.json` are all committed.
- `test/example/priv/playwright/eval/` is **gitignored** (`.gitignore:57-59`) — so bundles never exist in a fresh checkout and are produced only by phase (a).

| # | Phase | Precondition | Why CI differs from local | Remedy without `continue-on-error` |
|---|---|---|---|---|
| **R1** | b1 | Every bundle's `app_git_sha` must equal `git rev-parse HEAD` (`stale-render-guard.sh:79-83`). `app_git_sha` defaults to `git rev-parse HEAD` at capture time (`bundle.ts:80-84`, `:125-126`). | Same checkout, same HEAD → should match. **But** `actions/checkout` with default `fetch-depth: 1` produces a shallow repo. `admin_eval_render`'s checkout at `ci.yml:2468` declares no `fetch-depth`. | Match is structural; **verify** by grepping the job log for `stale-render-guard: checking N bundle(s) against HEAD <sha>`. If it ever mismatches, add `fetch-depth: 0` — never mask. |
| **R2** | b1 | `git cat-file -e "${BUNDLE_APP_SHA}^{commit}"` must succeed (`:87`). | A shallow clone still contains HEAD as a real object, so this passes. On a `pull_request` event the checkout is the merge commit — also a real local object. | No action. Note this is a **loud** failure by design (`:88-89` names shallow clone explicitly). |
| **R3** | b1 | `git diff --name-only <bundle_sha> HEAD -- <ADMIN_GLOBS>` must be empty (`:97-104`). Globs at `:39-46`: `lib/sigra/admin`, `lib/sigra/admin.ex`, `lib/sigra/live_view/admin_scope.ex`, `priv/templates/sigra.install/admin`, `priv/static/assets/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`. | `bundle_sha == HEAD` → the diff is empty by construction. | No action. **However:** if the phase's own commits touch any admin glob *and* the harness runs at an earlier SHA, this reds. Keep the eval work and the admin-CSS work (GATE-02's `sigra_auth.css` fix) in **separate commits** — note `sigra_auth.css` is **not** in the glob list, so GATE-02's CSS fix is safe. |
| **R4** | b3 | `fix-queue-lint.sh:166-172` — every cell's `open_findings` must be `<= totalUncollapsed` (the sum over `fix-queue.json` entries, expanding systemic parents by `surfaces_affected.length`). | b3 runs **after** (a2) rewrote both files from the same render, so they agree by construction — *provided* (a) completed fully. If (a) partially fails (e.g. a WebKit crash after bug 1 is fixed), the builder writes a partial queue while `admin-render-sha.json` retains larger committed counts → **red**. | Make phase (a)'s failure the *first* failure: the harness's `set -euo pipefail` already aborts before (a2) if `npx playwright test` exits non-zero, so a partial-queue state cannot arise from a clean abort. Confirm by reading the log ordering. Do **not** add `|| true` anywhere in the harness. |
| **R5** | b3 | `fix-queue-lint.sh:174-193` — all admin surfaces must report the **same** `open_findings` for the same cell key, except cells at `0` (the "introduced but not measured" sentinel, `:175-179`). | A fresh full-matrix render measures every surface; the committed ledger was produced by an earlier, possibly partial run. Cross-surface disagreement introduced by a fresh render is the most likely b3 red. | If it reds, the honest fix is **commit the regenerated `admin-render-sha.json` + `fix-queue.json`** produced by the CI run (download from the `admin-eval-bundles-<run_id>` artifact) — the same "regenerate at CI-native truth" move Phase 219 used for the amd64 baselines. **Never** relax the lint. |
| **R6** | b4 | `quality-findings-monotonic.sh --base HEAD` — for **every** cell, working-tree `open_findings` must be `<=` committed HEAD's (`:78-88`). Absent-at-base cells default to `0`, so **any new cell with a non-zero count is an automatic fail** (`:80` `base_count="${BASE_COUNTS[$item]:-0}"`). | **This is the highest-probability red.** The committed 33,642 findings were captured on some prior render. An ubuntu-CI-native render will differ per cell; any cell that goes *up* fails. New surfaces/cells fail unconditionally. | Two honest routes: **(i)** commit the CI-native regenerated ledger first (a "recapture" commit, exactly the Phase 219 precedent — the guard then compares CI-native to CI-native), or **(ii)** if counts genuinely rose, that is a real regression and belongs in the fix queue. **The plan must budget a dedicated task for (i)** and must not assume b4 passes. |
| **R7** | b5 | `award-guard.mjs --base HEAD` — an axis may rise only with a fresh `verified_at_sha` + resolving evidence; `band == min(axes)`; no axis decrease; `resolveEvidenceRef` (`:199`, from `lib/eval-probe-ids.mjs`) must resolve every referenced ref. | Nothing rewrites `admin-award-ledger.json` during a harness run, so working tree == HEAD → no axis change → the climb checks pass. **Risk:** `resolveEvidenceRef` defers `test:` / `conformance:` prefixes to prefix-only validation (a recorded 216 seam), but with **fresh bundles present** the bundle-backed refs are now resolved for real for the first time. | Read the job log for `award-guard` output. If an evidence ref fails to resolve against a real bundle, that is a genuine finding — fix the ref or the bundle capture, do not weaken the guard. |
| **R8** | b2 | `evidence-anchor-check.mjs` **soft-skips (exit 0) when no bundles are present** — that is why `fast_checks` can run it (`ci.yml:230-234`). With bundles present it runs in **full for the first time in CI**: every finding's structural anchor must resolve in the captured DOM. | Locally the anchor set was validated against a darwin render. A CI render can produce anchors that do not resolve if class chains differ. | Fix the anchor or the probe. Prior art: `216-09` fixed exactly this class of bug (board-scoped probes). **Do not** re-add a soft-skip on the harness path. |
| **R9** | all b | `evidence-anchor-check.mjs` resolves `cheerio` via `createRequire` from the Playwright subproject (216-04 decision, and a `219`/`220` fix relocated the runtime require to *after* the no-bundles guard). `npm ci` runs at `ci.yml:2516`, so `cheerio` is present. | Ordering-sensitive: the require happens only once bundles exist. Now that bundles will exist, the require executes in CI for the first time. | Confirm `cheerio` is in `test/example/priv/playwright/package-lock.json`. A `MODULE_NOT_FOUND` here is a real dependency gap, not a reason to mask. |
| **R10** | (a) | WebKit browser availability (D-11 step 1). `admin-eval-mobile` = `devices['iPhone 13']` = WebKit. `ci.yml:2519` installs chromium only. | The Phase-230 cache key `${{ runner.os }}-playwright-chromium-webkit-1.59.1-v1` (`ci.yml:1319`) is deliberately browser-set-scoped so it cannot restore WebKit here (`ci.yml:1304-1315` says so explicitly, naming Phase 231 GATE-04). | Change `:2519` to `npx playwright install --with-deps chromium webkit` and update the step `name:` (which currently *asserts* "chromium only — admin-eval uses chromium" and would become a lie). **Re-token `ci.yml:1319` → `-v2`** so no pre-231 cache entry can satisfy a post-231 key. |
| **R11** | (a) | `probes.ts:380` `SVGAnimatedString` crash. | Deterministic — fires wherever an SVG is in the probe's element sweep. | `const cls = typeof el.className === 'string' ? el.className : (el.className?.baseVal ?? '');` then `el.classList.contains('sg-ember') \|\| cls.includes('ember')`. Equivalent and safer: `el.classList.contains('sg-ember') \|\| Array.from(el.classList).some(c => c.includes('ember'))`. **Do not touch `:176` or `:237`.** |
| **R12** | job | Runtime. Job `timeout-minutes: 40` (`ci.yml:2443`); the last observed harness run was `16.2m` for phase (a) alone at 192 tests / 1 worker, and the whole job measured `851s` (14.2m) on nightly `30425416933` when it aborted early. Adding WebKit will *increase* phase (a) time, and b1-b6 then run for the first time. | Local runs are not time-bounded. | Watch the first green run's duration. If it approaches 40m, raise the ceiling deliberately with a recorded measurement (FAST-07's sizing rule is ~2× measured). Do not silently let it time out — `ci-demotion-observer.test.sh` case I establishes `timed_out` as a hard fail. |

**Bottom line for the plan:** treat **R6** (and its sibling **R5**) as *expected*, not exceptional. Budget an explicit task: run the harness in CI, download `admin-eval-bundles-<run_id>`, and commit the CI-native `admin-render-sha.json` + `fix-queue.json` regeneration as its own reviewed commit — **before** `continue-on-error` is deleted, so the deletion lands on a lane already proven green.

---

## GATE-02: The 320px Reflow Failure — Diagnosis From Artifacts

### The exact assertion

`test/example/priv/playwright/tests/admin-generated.spec.ts:169-176`, added in v1.46 (PR #104, commit `40240903`):

```ts
await page.setViewportSize({ width: 320, height: 800 });
await page.locator("html").evaluate((element) => {
  element.style.fontSize = "32px";
});
await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
expect(
  await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
).toBe(true);
```

It runs at the **end** of the first test in the spec (`:79`), after the "Other ways to sign in" disclosure has been opened (`:98-99`), after `emulateMedia({ colorScheme: 'dark', reducedMotion: 'reduce' })` (`:148`), and after an axe scan (`:160-167`). The `auth-login-system-dark-320-reflow` checkpoint capture at `:177-180` is **downstream** of the assertion, so it is never produced on a failing run.

### How to pull the diagnostics artifact

Verified live — the artifact exists and is **not expired** (7-day retention from 2026-07-29):

```bash
gh run download 30425416933 \
  --repo szTheory/sigra \
  --name generated-admin-failure-diagnostics \
  --dir /tmp/gate02-diag
```

Equivalent by id (`8713476454`, 3,905,947 bytes):

```bash
gh api repos/szTheory/sigra/actions/artifacts/8713476454/zip > /tmp/gate02-diag.zip
```

The four artifacts on that run: `admin-example-report`, `admin-eval-bundles-30425416933` (12 MB — **also useful for GATE-04's R5/R6**), `generated-admin-failure-diagnostics`, `generated-admin-report`.

> **⚠ Time-sensitive.** `retention-days: 7` (`ci.yml:1787`). These expire ~2026-08-05. If planning slips past that, the plan must re-produce a failure (dispatch CI on a branch, or wait for a nightly) rather than assume the artifact is retrievable.

Contents (verified): `test-failed-1.png`, `video.webm`, `trace.zip` (retry dir only), `error-context.md`, and the two earlier checkpoint PNGs — for both the first attempt and `-retry1`, confirming D-08's "fails on the retry too".

### What the artifact shows

`error-context.md` records only `Expected: true / Received: false` plus a full accessibility snapshot. The a11y snapshot confirms the DOM state at failure: disclosure open, both forms present, `Work sign-in` region rendered, brand paragraph reading `SigraAdminSmoke`.

`test-failed-1.png` (320 × 1718, dark) is decisive:

- The brand wordmark **is breaking correctly** — rendered as four stacked fragments `Sigra` / `Admi` / `nSm` / `oke`. `.sigra-auth__product` carries `overflow-wrap: anywhere` and `min-width: 0` (`sigra_auth.css:446-455`), and it is doing its job.
- The auth card's **left edge sits at ≈ x=35** and its content extends **past the right edge of the 320px frame**. The label `Email for sign-in lin` is visibly **clipped mid-word at x=320** — it is not wrapping, it is running off-canvas.
- Therefore `documentElement.scrollWidth` genuinely exceeds `innerWidth`. **The assertion is measuring a real overflow, not a measurement artifact.**

### Hypotheses falsified by live evidence

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Webfont-metrics race (D-09's running hypothesis, from the filed todo) | **KILLED** | `sigra_auth.css` contains **no `@font-face` and no remote font link**. The only font stacks are `ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif` (`:33-39`) and a monospace stack (`:299`, `:337`). There is no webfont to race. |
| The 15-char token `SigraAdminSmoke` forces the overflow | **KILLED** | The screenshot shows it breaking into four fragments. It is *not* the widest thing on the line. |
| The generated app name varies per run | **KILLED** | `admin-acceptance-smoke.sh:24` hardcodes `APP_NAME="sigra_admin_smoke"`. |
| Runner-image drift changes font metrics | **KILLED** | `Image Release: …/ubuntu24%2F20260720.247` is **identical** on the failing run `30425416933` (job `90490780778`) and the passing run `30389700235` (job `90377880503`). |
| Browser-build drift | **KILLED** | Both runs download `Chrome for Testing 147.0.7727.15 (playwright chromium v1217)` and `WebKit 26.4 (playwright webkit v2272)`. |

### Surviving hypotheses, ranked, with confirm/kill evidence

**H1 (primary) — the overflow is structural and always present; the "passes" are racy false-greens.**

Mechanism: `<input>` elements have a default intrinsic preferred width (`size` ≈ 20 characters). `sigra_auth.css:643-663` sets `width: 100%` on them but **not** `min-width: 0`. `width: 100%` does not override a grid/flex item's automatic minimum size, which resolves to `min-content` — roughly 20 characters at the inherited font size. At a 32px root font that is ~320px + `padding: 0.7rem 0.85rem` (≈54px at 32px root) + 2px border ≈ **375px min-content**, against a 320px viewport minus page padding. `.sigra-auth form` has `min-width: 0` (`:632-636`) but the *inputs themselves*, as grid items, do not. The label then has room to sit on one line, which is exactly the "clipped, not wrapped" behaviour in the screenshot.

If the overflow is always present, the ~62% of runs that pass must be reading a stale `innerWidth`: `page.setViewportSize()` is asynchronous at the CDP boundary, and `page.evaluate(() => … innerWidth)` at `:175` has **no wait for the new viewport to be applied**. If `innerWidth` still reads `1280`, then `scrollWidth (≈1280) <= innerWidth (1280)` → trivially `true`. The intervening `expect(heading).toBeVisible()` (`:173`) is a retrying locator assertion that resolves as soon as the heading is visible, which it already is — it does not synchronise the viewport.

- **Confirm by:** replacing the assertion body with an instrumented `page.evaluate` that returns `{ innerWidth, scrollWidth, clientWidth, offenders }`, where `offenders` = `[...document.querySelectorAll('*')].filter(e => e.getBoundingClientRect().right > innerWidth + 1).map(e => ({tag: e.tagName, cls: e.className?.toString?.() ?? '', right: e.getBoundingClientRect().right}))`. Run it 5× in CI. **If passing runs report `innerWidth: 1280`, H1 is proven.**
- **Kill by:** passing runs reporting `innerWidth: 320` with `scrollWidth <= 320`. That would mean layout genuinely differs, and H2 takes over.

**H2 (secondary) — a genuine layout race after the root-font mutation.**

`element.style.fontSize = "32px"` reflows the whole document. Chromium's transition properties (`sigra_auth.css:40-43`, `:423-425`, `:658-662`) are 140-220 ms; `emulateMedia({reducedMotion:'reduce'})` at `:148` suppresses them for the *reduced-motion* media query only if the CSS honours it (`:734-742` shows a `prefers-reduced-motion` block exists, scoped to checkboxes). A width transition mid-flight could momentarily overflow.

- **Confirm by:** inserting `await page.waitForFunction(() => window.innerWidth === 320)` plus a `requestAnimationFrame` settle before the read, and observing the failure rate over ≥ 5 runs.
- **Weakened by:** D-08's "fails on the retry too". A retry is a fresh browser context; a pure timing race should re-randomize. Sticky-within-run points away from a per-invocation race and toward a per-*machine* determinant — but every per-machine determinant tested above was identical between a pass and a fail. **This tension is the single strongest argument for H1**, where the "pass" is the anomaly and the "fail" is the truth.

**H3 (tertiary) — the generated host's own `app.css`.** `mix phx.new --no-install` (`admin-acceptance-smoke.sh:100-103`) scaffolds a Phoenix 1.8.8 host whose Tailwind/daisyUI asset pipeline resolves at build time. A floating daisyUI/Tailwind resolution could change the page's box model between runs.
- **Confirm by:** diffing the generated `assets/` lockfile or the served `app.css` byte length between a passing and a failing run (the spec already measures `sigra_auth.css` bytes at `:107-118` — add the host `app.css` to that probe).
- **Kill by:** identical bytes.

### The fix that satisfies D-09

D-09 forbids relaxing or narrowing the assertion. Under H1 the honest fix is a **real WCAG 1.4.10 reflow fix in the shipped CSS**:

```css
  .sigra-auth input[type="email"],
  .sigra-auth input[type="password"],
  .sigra-auth input[type="text"],
  .sigra-auth input[type="number"],
  .sigra-auth textarea,
  .sigra-auth select,
  .sigra-auth .input {
    width: 100%;
    min-width: 0;          /* NEW: a grid/flex item's automatic minimum is min-content,
                              which for an <input> is ~20ch and overflows at 200% zoom */
    …
  }
```

plus, if the instrumented run names other offenders, `min-width: 0` on the intermediate stack/grid wrappers. This must land in **both** `priv/templates/sigra.install/core/sigra_auth.css` (the shipped template) **and** its example twin if one exists — the repo has a documented installer-template-drift hazard (`reference_installer_template_drift`), and generated-host checks failing while the example passes is its signature. Verify with `diff` after editing.

Under H2 the fix is a `waitForFunction` on the viewport, which is **not** a relaxation of the assertion (the assertion is unchanged; only its precondition is made deterministic). Both fixes are compatible and can ship together.

**Reconciling the filed todo (C-5):** `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md` proposes narrowing `.sigra-auth__product` from `overflow-wrap: anywhere` to `break-word` semantics. That would let the 15-char token overflow its line and would make the assertion fail *harder*. Keep the todo open; add a note that its proposed direction is now known to conflict with the reflow gate, and that any future implementation must add a `min-width: 0` / container-query companion.

---

## DX-05: Token Permissions For Label Creation, And The Extraction

### Does `issues: write` suffice for `gh label create`?

**Yes, per GitHub's own permissions reference.** [CITED: docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens]

| Endpoint | `gh` command | Required permission | Access |
|---|---|---|---|
| `GET /repos/{owner}/{repo}/labels` | `gh label list` | Issues | `read` |
| `POST /repos/{owner}/{repo}/labels` | `gh label create` | Issues | `write` |

Both fall under the "Repository permissions for 'Issues'" section. No `repository-projects`, `administration`, or PAT scope is required.

**Caveat, recorded honestly.** GitHub community discussion #13565 has a contested history: the March 2022 original report claimed `issues: write` did **not** permit label operations; a February 2023 comment reported it did; and a January 2025 comment suggests it may have regressed (referencing discussion #149877). [CITED: github.com/orgs/community/discussions/13565] The documented answer and the community answer disagree, and I could not resolve the disagreement to `[VERIFIED]` without a live write against a real repo, which is out of scope for research.

### What the callers currently declare [VERIFIED: direct file read]

| Consumer | Declared permissions | Sufficient for D-22? |
|---|---|---|
| `ci.yml:1851` `notify_release_lane_rot` | job-level `permissions: issues: write` (`:1857-1858`) | **Yes**, per the docs. Note the workflow default is `contents: read` (`ci.yml:27-30`), and this job overrides it — so `issues: write` is the *only* scope it has. |
| `release-please.yml:344` `notify-release-failure` | **no job-level block** → inherits workflow-level `:19-23`: `actions: write`, `contents: write`, `issues: write`, `pull-requests: write` | **Yes.** |

Both already carry `issues: write`. **No permissions change is required by D-22.**

### Recommended implementation shape (fail-soft, and why)

Given the ambiguity above, and given that the `release-lane-rot` label **already exists** (verified live: `gh label list --search release-lane-rot` returns `release-lane-rot | Release/CI lane failed to complete (HARD-02 loud signal from notify-failure-issue.sh) | #b60205`), the self-heal branch is a belt-and-suspenders path that will effectively never fire in this repo. Make it **non-fatal**:

```bash
# Self-heal the label (Phase 231 D-22). `gh label create` needs Issues: write, which both
# callers declare -- but a permission regression must not cost us the tracking issue, which
# is the actual signal. Fail SOFT here and let the issue be created either way.
if ! gh label list --limit 200 --json name --jq '.[].name' | grep -qxF "$LABEL"; then
  echo "notify-failure-issue: label '${LABEL}' absent; creating"
  gh label create "$LABEL" \
    --description "Auto-created by notify-failure-issue.sh (Phase 231 D-22)" \
    --color b60205 \
    || echo "notify-failure-issue: WARNING: could not create label '${LABEL}' (continuing; the issue is the signal)"
fi
```

Then, so a soft-failed label never silently loses the issue, make the `create` call tolerant too:

```bash
gh issue create --label "$LABEL" --title "$TITLE" --body "$BODY" \
  || gh issue create --title "$TITLE" --body "$BODY"
```

The second form is the todo's own "soft-fail alternative" applied only as a last resort, which preserves D-22's stated preference for the self-heal as the primary path.

**Note on `grep -qxF` under `pipefail`:** `set -euo pipefail` is active (`:19`). `grep -q` closes the pipe early and can SIGPIPE the upstream `gh` — the repo has a recorded decision to prefer `grep -c` over `grep -q` in bash CI scripts for exactly this reason. Safer form: `LABELS="$(gh label list --limit 200 --json name --jq '.[].name')"; if ! printf '%s\n' "$LABELS" | grep -qxF "$LABEL"; then …`.

### D-21: extracting `wait-for-ci-gate.sh`

The polling loop is `release-please.yml:111-…` (the `run:` body starting at `:111`). Its inputs are `REPOSITORY`, `TAG_NAME`, `RELEASE_SHA`, plus the two tunables `max_attempts=60` (`:119`) and `wait_seconds=30` (`:120`). It performs `gh run list --repo … --workflow ci.yml --commit "$sha" --limit 20 --json databaseId,status,conclusion,url,createdAt` (`:125-130`), and at attempt 3 self-dispatches `gh workflow run ci.yml --ref "$TAG_NAME"` (`:135-139`).

Extraction contract for `scripts/ci/wait-for-ci-gate.sh`:
- Flags: `--sha`, `--repo`, `--tag`, `--max-attempts` (default 120), `--wait-seconds` (default 30), `--dispatch-after` (default 3), `--no-dispatch`, `--from-json` (for the hermetic self-test), `--format table|json`.
- `gh` invoked **bare via PATH** (the D-22/observer convention) so the self-test can shadow it.
- Fail-closed on: empty `gh` output, non-zero `gh` exit, a payload that is not a JSON array, and exhausting `max_attempts`.
- Non-vacuity: a run list of length 0 after the dispatch window must **not** be read as "nothing to wait for, so green".

Self-test cases (mirroring `ci-demotion-observer.test.sh`'s lettering): green on first poll (exactly one `gh run list`); green after N polls; timeout → exit 1 with the attempt count named; zero runs → dispatch fired exactly once at attempt 3; `gh` absent → non-zero; `gh` non-zero → exit 1; unknown flag → exit 2 with zero `gh` calls; `--from-json` → identical verdict with zero `gh` calls.

**Live invocation for D-21's receipt** (a real completed push-to-`main` run):

```bash
bash scripts/ci/wait-for-ci-gate.sh \
  --sha "$(gh run view 30466318240 --repo szTheory/sigra --json headSha -q .headSha)" \
  --repo szTheory/sigra --no-dispatch --format json
# expect: exit 0, attempts well under 120
```

**`timeout-minutes` for `gate-ci-green`** (Claude's Discretion): `max_attempts=120 × 30s = 60m` polling ceiling, plus checkout/setup. FAST-07's sizing rule is ~2× measured, floor 5. Recommend **`timeout-minutes: 75`** — comfortably above the 60-minute polling ceiling, and far below the 360-minute default it inherits today.

### D-23: what is already proven, verified live

```
$ gh label list --repo szTheory/sigra --search release-lane-rot
release-lane-rot   Release/CI lane failed to complete (HARD-02 loud signal from notify-failure-issue.sh)   #b60205

$ gh issue view 118 --repo szTheory/sigra --json number,title,labels,state,comments
{"number":118,"title":"ci-gate red on main (release-lane-rot)","state":"OPEN",
 "labels":["release-lane-rot"],"comment_count":3}
```

Both `notify-failure-issue.sh` branches are proven against the real Issues API. **Do not re-stage.** The only unexercised surface is `release-please.yml:344-379`, and D-23 scopes that out of a new probe.

---

## GATE-01: Nightly Red Inventory (live-verified)

`gh run view 30425416933 --repo szTheory/sigra --json jobs` returns exactly **three** non-`success` jobs:

| Job | `databaseId` | Conclusion | Duration | Owner |
|---|---|---|---|---|
| `Generated admin Playwright smoke` | `90490780778` | `failure` | 05:33:32→05:37:21 = **229s** | GATE-02 (the 320px assertion) |
| `Admin eval render + probe (evidence only, not a merge gate)` | `90490780796` | `failure` | 05:33:32→05:47:43 = **851s** | GATE-04 (bugs 1 and 2) |
| `ci-gate` | `90494800754` | `failure` | 06:00:27→06:00:31 = **4s** | propagation from the first |

This matches D-16 exactly. **GATE-01 is an observation of GATE-02 and GATE-04, with two additions:**

1. **The `Playwright reports (GitHub Pages)` workflow is a *separate* workflow** (`playwright-github-pages.yml`, cron `45 6 * * *`), not a job in the CI nightly. D-17's fix (insert `Run demo seeds` after `:88`) is independent and can land in parallel with everything else. Its `push:` trigger includes `test/example/priv/playwright/**` (`:25`), so **the phase's own merge will trigger it** — an in-milestone observation, not a wait for the next 06:45 cron.
2. **`pages-build-deployment`** is a GitHub-managed workflow, not repo YAML. D-18 correctly scopes it to "in scope only insofar as D-17's fix lets `ensure-github-pages-legacy-branch.sh` finally run."

**D-19's deletion target** is `ci-observe.yml:123-136` (see the anchor table). After deletion, `exit 1` at `:137` becomes the unconditional consequence — matching the push lane. Also update `MAINTAINING.md:255-262` (residual 4) to record that the leniency was removed and by which run's evidence.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Enumerating legitimate skips | A second list inside the verdict script | `.github/ci-skip-manifest.tsv` | D-01. Two oracles is the exact failure mode GATE-03 exists to remove. |
| Three-way manifest parity | A new `honest-skip-parity.test.mjs` | Extend `p10-no-undocumented-demotion.test.mjs` | C-1. The file CONTEXT believed existed does not; creating it now would produce the duplicate oracle D-01 forbids. |
| TSV parsing | A Node TSV library, `cut`, or a regex | `awk -F'\t'` per `ci-demotion-observer.sh:79-84` | Handles the `#`/blank/header skips correctly and is already the proven idiom. |
| `gh` testing | Mocking HTTP, or requiring `GH_TOKEN` in CI | A PATH-shadowed recording stub | `ci-demotion-observer.test.sh:110-121`. Hermetic, no network, no token. |
| Proving a red path | Rotting a real gate on a branch | A `workflow_dispatch` input probe | D-05. Branch experiments produce evidence that expires. |
| Docs-only classification | Re-deriving it in the verdict script | `needs.changes.outputs.docs_only` | `scripts/ci/docs-only-classify.sh` is already the single classifier with its own self-test. |
| Waiting for CI in a workflow | Inline `run:` shell | `scripts/ci/wait-for-ci-gate.sh` + self-test | D-21. Inline shell is structurally unobservable, which is the whole defect. |
| Making a red go away | `continue-on-error`, `retries`, a narrowed assertion | Fix it, or file it as a diagnosed defect with an owner | 230's D-15, REQUIREMENTS.md "Out of Scope", D-09, D-13, D-15, D-17. |
| Reflow overflow at 200% zoom | A viewport-specific media query hack | `min-width: 0` on the intrinsically-sized items | The standard CSS fix for grid/flex `min-content` blowout. |

**Key insight:** every guard in this repo is written to fail on *its own* vacuity first (`"the parse broke, this is not a pass"`), and every self-test is hermetic. A new guard that does not follow both conventions will pass review but will silently stop protecting anything — which is the class of defect this entire milestone exists to eliminate.

---

## Common Pitfalls

### Pitfall 1: `ci-gate` has no checkout
**What goes wrong:** the GATE-03 step tries to read `.github/ci-skip-manifest.tsv` and gets `No such file or directory`.
**Why:** `ci-gate` (`ci.yml:1789-1840`) has exactly one step and no `actions/checkout`. It is a pure aggregation job.
**How to avoid:** add `- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` as its first step. DX-02 requires the SHA pin + version comment.
**Warning signs:** the verdict step fails instantly with a path error on the first PR.

### Pitfall 2: `needs.changes.outputs.docs_only` is empty inside `ci-gate`
**What goes wrong:** the docs-only branch of D-03's allow-set never activates, and every docs-only PR reds on `library_tests_dep_off`.
**Why:** `changes` is not in `ci-gate.needs`. A `needs.<job>` expression for a job outside `needs` resolves to empty, not an error.
**How to avoid:** add `changes` to `ci-gate.needs` and map it into `env:`. Confirm `p06`'s `NEVER_DOCS_GATED` set does not include `ci-gate`.
**Warning signs:** a green run whose verdict output shows `docs_only=` with nothing after it.

### Pitfall 3: p05 reds when `continue-on-error` is removed
**What goes wrong:** `fast_checks` fails on the phase's own PR with a message about masking an unread red — the opposite of what the commit did.
**Why:** C-3. `p05-admin-eval-red-not-abandoned.test.mjs` asserts the flag's *presence*.
**How to avoid:** retire or invert p05 in the same commit as `ci.yml:2450`'s deletion. Same for the `REQUIREMENTS.md` GATE-04 `Complete` marking.
**Warning signs:** a `node --test` TAP failure naming `p05` right after a "remove the mask" commit.

### Pitfall 4: p10's tier-A floor reds when the manifest row is deleted
**What goes wrong:** deleting `generated_admin_playwright_smoke` from the manifest fails `tier A has 8 rows, expected >= 9 — the parse broke`.
**Why:** C-2. There are exactly 9 tier-A rows; the floor is `>= 9`.
**How to avoid:** lower the floor to `>= 8` with a recorded reason in the same commit.
**Warning signs:** a p10 TAP failure whose message says "the parse broke" when the parse is fine.

### Pitfall 5: the `gh` stub's fallthrough kills the existing notifier self-test
**What goes wrong:** all three existing cases in `notify-failure-issue.test.sh` break the moment `gh label list` is added.
**Why:** the stub's default branch is `echo "gh stub: unexpected invocation" >&2; exit 1` (`:57-58`), and the script under test runs with `set -euo pipefail`.
**How to avoid:** extend the stub with `label` branches in the same commit.
**Warning signs:** `Test A: exit=1 create_count=0` in `fast_checks`.

### Pitfall 6: the browser-set cache key silently "fixes" GATE-04
**What goes wrong:** WebKit gets restored into `admin_eval_render` from a cache and the job looks fixed without the install change.
**Why:** this is exactly what `ci.yml:1304-1315` was written to prevent, and it names Phase 231 GATE-04.
**How to avoid:** re-token `ci.yml:1319` (`-v1` → `-v2`) as D-11 step 1 requires, and if a browser cache is added to `admin_eval_render`, give it a distinct key.
**Warning signs:** `admin-eval-mobile` passing without `webkit` appearing in the install step's log.

### Pitfall 7: b4 reds on an honest, correct render (R6)
**What goes wrong:** the first green-Playwright harness run dies at `(b4)` with `open findings increased for '<surface>/<cell>'`.
**Why:** the committed `admin-render-sha.json` (33,642 findings over 186 cells) was captured elsewhere; a CI-native render differs.
**How to avoid:** budget the recapture task described in R6 *before* deleting `continue-on-error`.
**Warning signs:** the `(b1)`…`(b3)` banners appear and `(b5)` never does.

### Pitfall 8: SC-2's observable never appears
**What goes wrong:** the verifier greps for `9 passed` and finds nothing on a fully green run.
**Why:** C-4. Two Playwright invocations → `8 passed` then `1 passed`.
**How to avoid:** restate SC-2 explicitly (and record the restatement; `p11-sc-restatement-recorded.test.mjs` exists to force this).

### Pitfall 9: `[skip ci]` in a squash body
**What goes wrong:** the entire push-to-`main` CI run is silently skipped, and SC-1's nightly evidence never materialises.
**Why:** documented at `MAINTAINING.md:282-290` — GitHub honors `[skip ci]` anywhere in a commit message, and squash concatenates every commit body.
**How to avoid:** scan the phase's commit messages for the literal token before squash-merging (this phase's prose *will* discuss `admin_design_recapture`, whose own commits use it).

### Pitfall 10: installer-template vs example drift on the CSS fix
**What goes wrong:** the generated-host lane still fails after the CSS fix while the example app passes.
**Why:** the recorded `installer_template_drift` hazard — `priv/templates/sigra.install/` drifts behind hand-maintained `test/example/`.
**How to avoid:** after editing `priv/templates/sigra.install/core/sigra_auth.css`, `diff` it against the example twin and mirror. Re-bless the install golden fixture if the generator emits it.

---

## Runtime State Inventory

This phase is a CI-configuration refactor. Applying the rename/refactor discipline:

| Category | Items Found | Action Required |
|---|---|---|
| **Stored data** | **None in a database.** The only persistent "records" this phase's strings appear in are the committed ledgers `guides/reference/admin-render-sha.json` (186 cells / 33,642 `open_findings`) and `fix-queue.json`. These **are** data whose values will change when a CI-native render runs — see R5/R6. | **Data migration required for GATE-04:** commit the CI-regenerated ledgers as their own reviewed commit. Not a code edit. |
| **Live service config** | **GitHub Actions artifact retention** (`retention-days: 7`) — the `generated-admin-failure-diagnostics` artifact D-09 needs expires ~2026-08-05 and lives only on GitHub, not in git. **Ruleset 14941512** — 5 required status-check *name strings*; **out of scope, do not touch**, but note that D-06 does **not** rename `Generated admin Playwright smoke`, so no context is disturbed. **GitHub Pages source setting** — currently pointing at `main`'s repo root rather than `gh-pages` (D-18); lives in Settings→Pages, not in git. | Download the artifact **now** (command given above). File the Pages source as a diagnosed defect if D-17's fix does not self-heal it. |
| **OS-registered state** | **None.** No pm2, launchd, systemd, or Task Scheduler registration is involved. | None — verified: no `scripts/` entry registers OS-level state for CI. |
| **Secrets / env vars** | `GITHUB_TOKEN` (`secrets.GITHUB_TOKEN`) consumed at `ci.yml:1860` and `release-please.yml:107`, `:357`. `RELEASE_PLEASE_TOKEN` (optional PAT) at `release-please.yml:92`. **No key name changes.** D-22 needs no new scope — both callers already declare `issues: write`. | None. Confirm at implementation time that the extracted `wait-for-ci-gate.sh` still receives `GH_TOKEN` via the step's `env:` (never inlined). |
| **Build artifacts / installed packages** | **Playwright browser cache** at `~/.cache/ms-playwright`, keyed `${{ runner.os }}-playwright-chromium-webkit-1.59.1-v1` (`ci.yml:1319`). This is GitHub-hosted cache state, not git state, and D-11 explicitly requires it be re-tokened so a stale entry cannot mask the WebKit fix. | **Re-token to `-v2`** as part of D-11 step 1. Old entries age out on GitHub's 7-day-unused / 10 GB policy; no manual purge needed. |

**The canonical question — "after every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?"** Answer: exactly two. (1) The GitHub Actions cache entry under the `-v1` browser-set key. (2) The committed eval ledgers, whose *values* (not names) reflect a pre-CI-native render. Both are addressed above.

---

## Environment Availability

Probed on the working machine (darwin 25.5.0) and against CI's declared toolchain.

| Dependency | Required By | Available (local) | Version | Fallback |
|---|---|---|---|---|
| `gh` CLI (authenticated) | Anchor verification, artifact download, D-21 live receipt, SC-1/2/3/4/5 evidence | ✓ | live calls to `szTheory/sigra` succeeded (run/job/artifact/label/issue reads) | none needed |
| `git` | every anchor check, `stale-render-guard.sh` | ✓ | HEAD `76d91117` | — |
| `node` | `p05`/`p10` edits, ledger inspection | ✓ | ran `node -e` against `admin-render-sha.json` | CI uses node 20 (`ci.yml:1693`) |
| `jq` | run-payload parsing in self-tests | ✓ | used by `ci-demotion-observer.test.sh` | preinstalled on `ubuntu-latest` |
| `bash` ≥ 4 (`mapfile`, `declare -A`) | `stale-render-guard.sh:53`, `quality-findings-monotonic.sh:66` | ⚠ macOS ships bash 3.2 as `/bin/bash` | scripts use `#!/usr/bin/env bash` | Homebrew bash locally; `ubuntu-latest` ships bash 5 — **CI is the authority.** Do not "fix" a local bash-3.2 failure by rewriting the script. |
| PostgreSQL (`postgres`/`postgres`, `sigra_test`) | any local `mix test` | ⚠ not probed | — | `scripts/db/up.sh` + `direnv allow` per CLAUDE.md; **not needed for this phase's work** |
| `phx_new` 1.8.8 archive | install golden tests | ⚠ not probed | CI pins 1.8.8 (`ci.yml:1701`) | `mix archive.install --force hex phx_new 1.8.8` — **only** needed if the CSS fix touches the installer golden fixture |
| Playwright browsers (chromium 147.0.7727.15, webkit 26.4) | reproducing the 320px failure locally | ✗ | — | **Do not reproduce locally.** The failure is CI-environment-shaped and every local determinant differs. Instrument and run in CI. |
| Docker | UAT/demo stack | not required | — | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** local Postgres and `phx_new` — both have documented setup paths in `CLAUDE.md` and neither blocks the CI-shaped work that constitutes this phase.

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test Framework

| Property | Value |
|---|---|
| Framework (guards) | `bash` self-tests (`scripts/ci/*.test.sh`) + `node --test` (`scripts/ci/prohibitions/*.test.mjs`, node 20) |
| Framework (specs) | `@playwright/test` 1.59.1 |
| Framework (library) | ExUnit (not exercised by this phase) |
| Config files | `.github/workflows/ci.yml` (`fast_checks` `:155-354`); `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `bash scripts/ci/<name>.test.sh` (each < 5s, hermetic) |
| Prohibition suite | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (the shell glob is load-bearing — a bare directory arg is not valid on node 22) |
| Full suite command | the CI run itself; there is no local equivalent for a gate-honesty phase |

### Phase Requirements → Test Map

| Req | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| GATE-03 | manifest parses to a populated, tiered enumeration; zero rows = broken parse | unit (hermetic) | `bash scripts/ci/honest-skip-verdict.test.sh` | ❌ Wave 0 |
| GATE-03 | a rotted skip (gate string references `head_ref`/branch/SHA) fails the verdict | unit (hermetic) | same | ❌ Wave 0 |
| GATE-03 | a correct event-gated skip passes; a correct docs-only skip passes | unit (hermetic) | same | ❌ Wave 0 |
| GATE-03 | manifest `gate` column agrees with `ci.yml`'s actual `if:` | node:test | `node --test scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs` | ⚠ exists, needs a new assertion |
| GATE-02 | `generated_admin_playwright_smoke` runs on `pull_request` | node:test | new assertion in `p10` (or a new prohibition) asserting the job declares **no** `head_ref` condition | ❌ Wave 0 |
| GATE-02 | 320px / 200%-zoom reflow containment | e2e | `npx playwright test tests/admin-generated.spec.ts --project=admin-generated` (via `scripts/ci/admin-acceptance-smoke.sh --test all`) | ✅ `admin-generated.spec.ts:169-176` |
| GATE-04 | `probes.ts` ember check survives SVG `className` | unit | add an `SVGAnimatedString`-shaped case to the probe unit tests, or assert via a fresh `admin-eval` bundle containing an SVG surface | ❌ Wave 0 |
| GATE-04 | b1-b6 execute and pass | integration | `bash scripts/ci/admin-eval-harness.sh` (in `admin_eval_render`) | ✅ harness exists; has never run to completion in CI |
| GATE-04 | `continue-on-error: true` cannot be silently reinstated | node:test | inverted `p05-admin-eval-red-not-abandoned.test.mjs` | ⚠ exists, must be inverted (C-3) |
| GATE-01 | `playwright-github-pages.yml` seeds before boot | node:test or bash | assert the workflow contains a `Run demo seeds` step between DB setup and boot | ❌ Wave 0 |
| GATE-01 | ci-observe schedule leniency is gone | node:test | assert `ci-observe.yml` contains no `RUN_EVENT" = "schedule"` early-exit | ❌ Wave 0 |
| DX-05 | polling loop returns 0 inside 120 attempts against a real run | unit (hermetic) + live | `bash scripts/ci/wait-for-ci-gate.test.sh`; then the live invocation shown in § DX-05 | ❌ Wave 0 |
| DX-05 | notifier self-heals a missing label; never loses the issue | unit (hermetic) | `bash scripts/ci/notify-failure-issue.test.sh` (extended) | ⚠ exists, stub must be extended (Pitfall 5) |

### Sampling Rate

- **Per task commit:** the specific `*.test.sh` / `node --test <file>` for the guard touched (each < 5s).
- **Per wave merge:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` plus every `scripts/ci/*.test.sh` the wave touched.
- **Phase gate:** a full CI run green on the phase PR, then the five observed-run receipts below.

### Success-criterion validation (D-25, with the C-4 correction)

| SC | Command | Observable artifact |
|---|---|---|
| **SC-1** | `gh run view <first-scheduled-run-after-merge> --repo szTheory/sigra --json jobs` | zero jobs with `conclusion` outside `{success, skipped}` — or, under the fallback branch, a filed defect with an owner linked from the run. Trigger: cron `30 4 * * *` (`ci.yml:21`). |
| **SC-2** | `gh run view <phase-PR-run> --repo szTheory/sigra --json jobs -q '.jobs[] \| select(.name=="Generated admin Playwright smoke")'` then `gh run view --repo szTheory/sigra --job <id> --log` | `conclusion: success`, `startedAt != completedAt` (a real duration, **not** `skipped`), and — **restated per C-4** — `Running 9 tests using 1 worker` followed by `8 passed` and then `1 passed`, with zero `failed` lines. |
| **SC-3** | `gh workflow run "CI" -f force_rot_probe=false` then `gh workflow run "CI" -f force_rot_probe=true`; `gh run view <id> --json jobs` on each | clean → `ci-gate` `conclusion: success`; rot probe → `ci-gate` `conclusion: failure` **whose log names the specific lane and its gate string**. |
| **SC-4** | `gh run view --repo szTheory/sigra --job <admin_eval_render-job-id> --log \| grep -E 'admin-eval-harness: \((b1\|b2\|b3\|b4\|b5\|b6)\)\|PASS — all phases green'` plus `--json jobs` for the conclusion | six `(bN)` banner lines **and** `admin-eval-harness: PASS — all phases green`, **and** `conclusion: success` on the job. Banners alone prove reach; the conclusion proves pass (D-14). |
| **SC-5** | `bash scripts/ci/wait-for-ci-gate.sh --sha <real-push-to-main-sha> --repo szTheory/sigra --no-dispatch --format json`; plus `gh issue view 118 --repo szTheory/sigra --json comments` | exit 0 with an attempt count well under 120; plus issue #118's 3-comment thread (already captured — D-23 forbids re-staging). |

### Wave 0 Gaps

- [ ] `scripts/ci/honest-skip-verdict.sh` + `.test.sh` — GATE-03
- [ ] `scripts/ci/wait-for-ci-gate.sh` + `.test.sh` — DX-05 / D-21
- [ ] Extend the `gh` stub in `scripts/ci/notify-failure-issue.test.sh` with `label list` / `label create` branches, plus cases D–G — DX-05 / D-22 (**blocks the script change**)
- [ ] Extend `p10-no-undocumented-demotion.test.mjs`: `gate`-column-vs-`ci.yml` assertion; tier-A floor `>= 9` → `>= 8` with a recorded reason — C-2
- [ ] Invert `p05-admin-eval-red-not-abandoned.test.mjs`: assert `continue-on-error` **absent**; drop the `REQUIREMENTS.md`-not-`Complete` assertion — C-3 (**blocks D-11 step 4**)
- [ ] A structural assertion that `playwright-github-pages.yml` seeds before boot — GATE-01 / D-17
- [ ] A structural assertion that `ci-observe.yml` has no schedule-lane leniency — GATE-01 / D-19
- [ ] Instrumentation task for the 320px assertion (report `innerWidth` + the overflowing elements) — GATE-02 / D-09 diagnosis
- [ ] CI-native regeneration + commit of `admin-render-sha.json` / `fix-queue.json` — GATE-04 / R5, R6
- [ ] Wire every new `.test.sh` into `fast_checks` near `ci.yml:322`

---

## Security Domain

`security_enforcement` is absent from `.planning/config.json` → treated as enabled. This phase ships no user-facing auth surface; the relevant attack surface is CI supply chain and shell/workflow injection.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | No auth code path changes. (`sigra_auth.css` is presentation only.) |
| V3 Session Management | no | — |
| V4 Access Control | **yes (CI)** | Least-privilege `permissions:` per job. Workflow default is `contents: read` (`ci.yml:27-30`); every job that needs more overrides explicitly. **`ci-gate`'s new checkout needs nothing beyond the default.** |
| V5 Input Validation | **yes** | GitHub context strings (`github.event_name`, `github.base_ref`, run ids) must reach shell **only** via `env:` mapping, never inlined into a `run:` body. Documented at `ci.yml:132-135` and `notify-failure-issue.sh:14-18`. |
| V6 Cryptography | no | No crypto code changes. |
| V14 Configuration | **yes** | Third-party actions pinned to full commit SHAs with a version comment (DX-02). Reuse `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1` verbatim. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Workflow-command injection via a crafted branch name / PR title interpolated into `run:` | Tampering | `env:` mapping only; the repo already enforces this convention. GATE-03 must not inline `github.event_name`. |
| Secret leakage in guard output | Information Disclosure | `notify-failure-issue.sh:14-18`'s "never echoes GH_TOKEN or any secret" clause; carry it into `wait-for-ci-gate.sh`'s header verbatim. |
| Over-broad `GITHUB_TOKEN` scope for label creation | Elevation of Privilege | `issues: write` is sufficient and already declared by both callers. **Do not add `administration` or a PAT.** |
| Unpinned third-party action | Supply chain / Tampering | SHA pin + `# vX.Y.Z` comment. |
| A guard that fails open | Repudiation | Non-vacuity floors with the literal `"the parse broke, this is not a pass"` message, on every new guard. |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The `<input>` min-content width is the element that overflows at 320px/32px. | GATE-02 H1 | The CSS fix targets the wrong element and the lane stays red. **Mitigated** by the instrumentation task, which names the actual offenders before any fix is written. |
| A2 | The ~62% of passing runs are false-greens caused by `page.evaluate` reading a pre-viewport-change `innerWidth`. | GATE-02 H1 | If false, H2/H3 apply and the fix is a wait or a host-CSS pin instead. **Mitigated** by the same instrumentation (`innerWidth` is returned explicitly). |
| A3 | `issues: write` is sufficient for `gh label create` with the default `GITHUB_TOKEN`. | DX-05 | The self-heal branch fails. **Mitigated** by the fail-soft design, which preserves the issue regardless. Documented by GitHub but contradicted by a 2025 community report. |
| A4 | Adding `changes` to `ci-gate.needs` does not violate any prohibition guard. | GATE-03 | `p06` reds on the phase's own PR. **Mitigated** by reading `_lib.mjs`'s `NEVER_DOCS_GATED` export at implementation time — `ci-gate` was not in the three names p06's source enumerates. |
| A5 | The `admin-eval` fresh CI render will produce per-cell `open_findings` differing from the committed 33,642. | GATE-04 R6 | If counts happen to match, the recapture task is a no-op — costless. If they differ (expected), the task is essential. |
| A6 | `p05`'s inversion is acceptable to the reviewer rather than deletion. | C-3 | Style disagreement only; both shapes satisfy the requirement. p05's own comment sanctions retirement in this phase either way. |
| A7 | `admin_eval_render`'s shallow checkout keeps `bundle_sha == HEAD`. | GATE-04 R1 | b1 reds with a sha mismatch. Cheap to confirm from the first run's log line `stale-render-guard: checking N bundle(s) against HEAD <sha>`. |
| A8 | The `generated-admin-failure-diagnostics` artifact remains downloadable through the planning window. | GATE-02 | Verified `expired: false` today; expires ~2026-08-05. **Mitigate by downloading now** (the command is given; it was executed successfully during this research). |

---

## Open Questions

1. **Which element actually overflows at 320px/32px?**
   - *What we know:* the overflow is real (screenshot), the brand wordmark is not the cause, and the input `min-content` chain is the strongest structural candidate. Runner image, browser builds, and app name are all falsified as variance sources.
   - *What's unclear:* whether the passing runs measure a 320px viewport at all.
   - *Recommendation:* make the instrumentation task the **first** task of the GATE-02 wave. One instrumented CI run resolves H1 vs H2 vs H3 definitively.

2. **Should `p10` gain a `gate`-column assertion in this phase?**
   - *What we know:* it is what would have caught GATE-02's defect, it is ~15 lines, and it directly serves GATE-03's mandate.
   - *What's unclear:* whether it is in scope, since no locked decision names it (D-01 assumed it already existed).
   - *Recommendation:* **yes, include it.** C-1 makes the assumption false, and GATE-03's requirement text ("fails on the latter") is not satisfiable in a durable way without it.

3. **Does D-18's Pages source self-heal after D-17's seeds fix?**
   - *What we know:* `ensure-github-pages-legacy-branch.sh` runs only after a successful publish, and the publisher has never succeeded.
   - *What's unclear:* whether the script's REST call succeeds under the workflow's `pages: write` scope.
   - *Recommendation:* observe the first post-fix run; if the Pages source is still `main`'s root, file the diagnosed defect under SC-1's fallback and stop — do **not** expand into repo-admin work (D-18 is explicit).

4. **How many CI iterations will GATE-04 need before b1-b6 are green?**
   - *What we know:* six independent precondition classes (R4-R9), at least one of which (R6) is near-certain to fire.
   - *What's unclear:* whether R5 and R6 resolve in one recapture commit or several.
   - *Recommendation:* structure the GATE-04 wave as *fix → run → read → regenerate → run → delete the mask*, with the "read" step explicitly budgeted rather than assumed instantaneous. D-11's four-step order already anticipates this; make step 3 a real task, not a checkbox.

5. **Is `example_unit_smoke`'s absence from `ci-gate.needs` worth a note in the verdict script's output?**
   - *What we know:* it is ruleset-required yet absent (deferred, "file as a new todo").
   - *What's unclear:* nothing material.
   - *Recommendation:* file the todo during planning as CONTEXT instructs; optionally have the verdict script *report* (never fail on) any ruleset-required name missing from its lane set — a zero-cost honesty signal that stays inside the deferral.

---

## Sources

### Primary (HIGH confidence — direct read / live tool at HEAD `76d91117`)

- `.github/workflows/ci.yml` (2595 lines) — every anchor in the verification table
- `.github/workflows/ci-observe.yml` (183), `playwright-github-pages.yml` (196), `release-please.yml` (379)
- `.github/ci-skip-manifest.tsv` (76 lines; header `:1-56`, columns `:60`, 16 data rows `:61-76`)
- `scripts/ci/notify-failure-issue.sh` (34) and `notify-failure-issue.test.sh` (138)
- `scripts/ci/ci-demotion-observer.sh` (235) and `ci-demotion-observer.test.sh` (397)
- `scripts/ci/admin-eval-harness.sh` (116), `stale-render-guard.sh` (111), `quality-findings-monotonic.sh`, `fix-queue-lint.sh`, `fix-queue-build.mjs`, `award-guard.mjs`
- `scripts/ci/prohibitions/` — `_lib.mjs`, `p05`, `p06`, `p07`, `p10`, `p13`
- `scripts/ci/admin-acceptance-smoke.sh`
- `test/example/priv/playwright/tests/admin-generated.spec.ts`, `playwright.config.ts`, `lib/eval/probes.ts`, `lib/eval/bundle.ts`
- `priv/templates/sigra.install/core/sigra_auth.css`, `login_html.ex`
- `MAINTAINING.md` (587), `.planning/REQUIREMENTS.md`, `.planning/config.json`
- `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md`
- **Live `gh` calls:** `gh run view 30425416933 --json jobs`; `gh api …/actions/runs/30425416933/artifacts`; `gh run download … --name generated-admin-failure-diagnostics`; `gh run view --job 90490780778 --log`; `gh run view --job 90377880503 --log`; `gh label list --search release-lane-rot`; `gh issue view 118`
- **Artifact read:** `test-failed-1.png` (320×1718) and `error-context.md` from run `30425416933`

### Secondary (MEDIUM confidence)

- docs.github.com — *Permissions required for fine-grained personal access tokens*: `POST /repos/{owner}/{repo}/labels` → **Issues: write**; `GET /repos/{owner}/{repo}/labels` → **Issues: read**

### Tertiary (LOW confidence — flagged, not relied on)

- github.com/orgs/community/discussions/13565 — contested history of whether `issues: write` permits label creation (2022 "no" → 2023 "yes" → 2025 "may be broken"). Used only to justify the fail-soft design, never as the basis for a decision.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| Anchor verification | **HIGH** | Every line read directly at HEAD `76d91117`; drift reported with exact replacement lines. |
| Contradictions C-1 / C-2 / C-3 / C-4 | **HIGH** | C-1 by `ls` + `find` + `git log -S`; C-2/C-3 by reading the guard source; C-4 by two live job logs. |
| House patterns | **HIGH** | Quoted verbatim from shipped files. |
| GATE-03 verdict spec | **HIGH** on the available context surface (`ci-gate` has no checkout, no `changes` edge — both verified); **MEDIUM** on the exact allow-set shape, which follows D-03 as locked. |
| GATE-04 precondition inventory | **HIGH** on mechanism (every guard read line by line); **MEDIUM** on which will actually fire (b1-b6 have never run in CI, by definition). |
| GATE-02 320px diagnosis | **HIGH** that the overflow is real and that five hypotheses are falsified; **MEDIUM** on H1's ranking — it is the best-supported explanation but is not yet instrumented. |
| DX-05 permissions | **MEDIUM** — GitHub's own docs are unambiguous, but a 2025 community report contradicts them; the fail-soft design makes the answer non-load-bearing. |
| Nightly inventory | **HIGH** — live `gh run view` on run `30425416933`. |

**Research date:** 2026-07-29
**Valid until:** **2026-08-05** for anything depending on the `30425416933` artifacts (7-day retention). ~2026-08-28 for the line anchors, which will drift with any `ci.yml` edit — re-verify with the tables above if planning slips.
