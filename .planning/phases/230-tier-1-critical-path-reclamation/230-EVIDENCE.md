# Phase 230 — Observed-Run Evidence Ledger

**A claim without a verbatim run ID is not evidence.** Every wall-clock or per-job duration
claim anywhere in this phase — and downstream, Phase 235's FAST-01 verdict — must carry the
run ID it was measured from and the exact `scripts/ci/ci-run-metrics.sh` (or `gh`) invocation
that produced it. Static reads of `ci.yml` or `admin-design.spec.ts` are necessary-but-not-
sufficient pre-checks only; they are never, by themselves, proof that a CI run executed the
behavior they describe (`.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` — "code-level reads
that never executed the specs" is the precedent failure this ledger exists to prevent).

---

## Slot Index

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PR](#before-pr) | PR run `30390832059` (2026-07-28, pre-change) | `ci-run-metrics.sh --jobs 30390832059` | captured (run 30390832059) |
| [BEFORE-PUSH](#before-push) | Push run `30389700235` (2026-07-28, pre-change) | `ci-run-metrics.sh --jobs 30389700235` | captured (run 30389700235) |
| [AFTER-PR](#after-pr) | The phase's own PR (#117), final commit — the **miss** half of FAST-06's pair | `ci-run-metrics.sh --jobs 30412458437` | captured (run 30412458437) |
| [AFTER-PR-WARM](#after-pr-warm) | A second run on the **same** PR, pushed only after AFTER-PR's Playwright job concluded — the **hit** half of FAST-06's pair | `ci-run-metrics.sh --jobs 30413542431` | captured (run 30413542431) |
| [AFTER-NONPR](#after-nonpr) | `workflow_dispatch` on the phase branch — the demoted `admin_eval_render` and the event-gated snapshot step observed *executing* inside the phase window | `ci-run-metrics.sh --jobs 30414885679` | captured (run 30414885679) |
| [AFTER-PUSH](#after-push) | The push-to-`main` run of the merge commit | `ci-run-metrics.sh --jobs <id>` | pending (post-merge obligation) |
| [AFTER-DOCSONLY](#after-docsonly) | A docs-only PR cut from `main` after the merge | `gh pr checks <n>` + `gh run view <id> --json jobs` | pending (post-merge obligation) |
| [AFTER-CANCEL](#after-cancel) | Double-push probe on throwaway PR #120, branch cut from the phase branch | `gh run list --branch 230-09-cancel-probe --json conclusion` | captured (runs 30416160743 cancelled, 30416184110 completed) |

---

## BEFORE-PR

Status: captured (run 30390832059)

The pre-change PR baseline. Every duration claim in this phase's `<threat_model>` /
`<decisions>` (D-10's "17m33s", RESEARCH's `admin_eval_render` diagnosis, the SC-2 restatement
below) traces to this run.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30390832059
```

Output (verbatim, captured 2026-07-28):

```
job                                                                 conclusion  duration_s  duration
Fast checks (milestone/installer/contracts/snapshot/ledger guards)  success     20s         0m20s
Release ref guard                                                   success     3s          0m3s
Example unit smoke (ExUnit + ConnTest)                              success     59s         0m59s
Nightly probe (forced-failure self-test)                            skipped     0s          0m0s
Passkeys manual fallback smoke                                      skipped     0s          0m0s
Install matrix (flag combinations)                                  skipped     0s          0m0s
Passkeys opt-out smoke                                              skipped     0s          0m0s
Install smoke (fresh phx.new + sigra.install)                       success     118s        1m58s
Library tests shard 1                                               success     476s        7m56s
Library tests (dep-off — Threadline absent)                         success     76s         1m16s
Example HTTP smoke (boot + curl critical routes)                    success     53s         0m53s
Library tests shard 2                                               success     332s        5m32s
Install golden + idempotency contract (subprocess harness)          success     36s         0m36s
Admin eval render + probe (evidence only, not a merge gate)         failure     1053s       17m33s
Example Playwright smoke (full lifecycle)                           success     1710s       28m30s
Recapture admin-checkpoint baselines (in-CI)                        skipped     0s          0m0s
Generated admin Playwright smoke                                    skipped     0s          0m0s
Upgrade smoke (published source series -> local candidate)          skipped     0s          0m0s
Recapture admin-design baselines (in-CI)                            skipped     0s          0m0s
Library tests                                                       success     3s          0m3s
ci-gate                                                              success     3s          0m3s
Notify on red ci-gate (release-lane-rot)                            skipped     0s          0m0s
```

`Admin eval render + probe (evidence only, not a merge gate)` reports `failure` / `1053s` /
`17m33s` — not filtered despite the non-`success` conclusion, exactly the case D-21's script
was built to get right. Every one of the six skipped jobs in the SC-2 restatement below is
present in this table with `conclusion: skipped` and a ~0s duration, never absent.

---

## BEFORE-PUSH

Status: captured (run 30389700235)

The pre-change push-to-`main` baseline. This is the run every AFTER-PUSH / AFTER-NONPR
comparison is measured against — it shows every honest-skip job from BEFORE-PR *executing*.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30389700235
```

Output (verbatim, captured 2026-07-28):

```
job                                                                    conclusion  duration_s  duration
Passkeys manual fallback smoke                                         success     116s        1m56s
Install matrix (flag combinations) (--no-passkeys)                     success     102s        1m42s
Nightly probe (forced-failure self-test)                               success     5s          0m5s
Release ref guard                                                      success     2s          0m2s
Passkeys opt-out smoke                                                 success     203s        3m23s
Install matrix (flag combinations) (--no-organizations)                success     100s        1m40s
Install matrix (flag combinations)                                     success     118s        1m58s
Example unit smoke (ExUnit + ConnTest)                                 success     56s         0m56s
Fast checks (milestone/installer/contracts/snapshot/ledger guards)     success     27s         0m27s
Install matrix (flag combinations) (--no-organizations --no-passkeys)  success     113s        1m53s
Install golden + idempotency contract (subprocess harness)             success     349s        5m49s
Library tests (dep-off — Threadline absent)                            success     76s         1m16s
Recapture admin-design baselines (in-CI)                               success     1157s       19m17s
Example HTTP smoke (boot + curl critical routes)                       success     58s         0m58s
Install smoke (fresh phx.new + sigra.install)                          success     115s        1m55s
Library tests shard 1                                                  success     472s        7m52s
Library tests shard 2                                                  success     313s        5m13s
Admin eval render + probe (evidence only, not a merge gate)            failure     1102s       18m22s
Example Playwright smoke (full lifecycle)                              success     1585s       26m25s
Generated admin Playwright smoke                                       success     224s        3m44s
Recapture admin-checkpoint baselines (in-CI)                           success     315s        5m15s
Upgrade smoke (published source series -> local candidate)             success     121s        2m1s
Library tests                                                          success     3s          0m3s
ci-gate                                                                success     3s          0m3s
Notify on red ci-gate (release-lane-rot)                                skipped     0s          0m0s
```

`Example Playwright smoke (full lifecycle)` reports `1585s` (26m25s), above the 1500s floor
this ledger's acceptance criteria pin against. Every job the PR run skips (`Passkeys manual
fallback smoke`, `Install matrix`, `Passkeys opt-out smoke`, `Upgrade smoke`, `Recapture
admin-design baselines (in-CI)`, `Recapture admin-checkpoint baselines (in-CI)`, `Generated
admin Playwright smoke`) executes here with a real, non-skipped conclusion and a real duration
— the non-PR half of the SC-2 restatement.

---

## AFTER-PR

Status: captured (run 30412458437)

The **miss** half of FAST-06's Playwright browser cache pair. This is the phase's own PR
(#117), final wave-8 commit `ed55701a`, first CI run against that commit — a new cache key can
only miss on the run that introduces it.

Run: `30412458437` · event `pull_request` · head `ed55701ae64ce926f32b87610e0455d513d662a0` ·
created `2026-07-29T00:53:03Z` · completed `2026-07-29T01:09:55Z` · **wall-clock 16m52s**.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30412458437
```

Output (verbatim):

```
job                                                                 conclusion  duration_s  duration
Release ref guard                                                   success     3s          0m3s
Detect docs-only change                                             success     8s          0m8s
Fast checks (milestone/installer/contracts/snapshot/ledger guards)  success     26s         0m26s
Passkeys opt-out smoke                                              skipped     0s          0m0s
Nightly probe (forced-failure self-test)                            skipped     0s          0m0s
Install matrix (flag combinations)                                  skipped     0s          0m0s
Passkeys manual fallback smoke                                      skipped     0s          0m0s
Library tests shard 2                                               success     317s        5m17s
Library tests shard 1                                               success     480s        8m0s
Install golden + idempotency contract (subprocess harness)          success     32s         0m32s
Recapture admin-design baselines (in-CI)                            skipped     0s          0m0s
Recapture admin-checkpoint baselines (in-CI)                        skipped     0s          0m0s
Upgrade smoke (published source series -> local candidate)          skipped     0s          0m0s
Admin eval render + probe (evidence only, not a merge gate)         skipped     0s          0m0s
Generated admin Playwright smoke                                    skipped     0s          0m0s
Library tests (dep-off — Threadline absent)                         success     79s         1m19s
Install smoke (fresh phx.new + sigra.install)                       success     106s        1m46s
Example Playwright smoke (full lifecycle)                           success     989s        16m29s
Example unit smoke (ExUnit + ConnTest)                              success     51s         0m51s
Example HTTP smoke (boot + curl critical routes)                    success     67s         1m7s
Library tests                                                       success     4s          0m4s
ci-gate                                                              success     3s          0m3s
Notify on red ci-gate (release-lane-rot)                            skipped     0s          0m0s
```

`Example Playwright smoke (full lifecycle)` (16m29s) is the critical path, and the run's own
wall-clock (16m52s, `updatedAt - createdAt`) is only 23s longer than that job — confirming the
job dominates the DAG exactly as predicted below. `Admin eval render + probe (evidence only, not
a merge gate)` is `skipped` / `0s` — SC-2's restated criterion (skipped, duration < 5s).

**Step-level facts, pulled from `gh run view 30412458437 --json jobs` and per-job step logs
(`gh run view --log --job <jobId>`):**

- **`Detect docs-only change` job (`90451499447`), step `Detect docs-only change`:** emits
  `docs_only=false` (verbatim log line, 2026-07-29T00:53:11Z). This PR's `origin/main...HEAD`
  diff carries `.github/workflows/ci.yml`, `scripts/ci/*.sh`,
  `test/example/priv/playwright/tests/admin-design.spec.ts` and `test/sigra/planning/*.exs` —
  the mixed-diff case, expected `false`.
- **`Example Playwright smoke (full lifecycle)` job (`90451525539`), step
  `Run design gallery boards (chromium, mobile, dark)`:** Playwright's own list-reporter tail
  reports `Running 39 tests using 1 worker` … `39 passed (3.9m)` — the axe-only PR gallery step,
  39 tests as predicted (3 axe scans × 13 non-board utility tests… — see AFTER-NONPR for the
  full 84-test non-PR inventory this collapses from).
- **Same job, step `Run design gallery board snapshots (non-PR)`:** `conclusion: skipped` — the
  `@snapshot`-tagged boards never execute on this PR event, exactly D-01/D-02's event-gated split.
- **Same job, step `Cache Playwright browsers`
  (`actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0`):** log line
  `Cache not found for input keys: Linux-playwright-chromium-webkit-1.59.1-v1,
  Linux-playwright-chromium-webkit-` — **`cache-hit: false`**. This is the key-introducing run
  (D-18's literal-version key, `1.59.1-v1`, has never been saved before), so a miss is the
  correct and expected result.
  - `Install Playwright browsers` step duration: **36s** (`00:54:06Z` → `00:54:42Z`, full
    `--with-deps` install: apt deps + browser download, matching D-15's ~61s-total /
    ~14s-cacheable model plus deps-install variance).
  - `Post Cache Playwright browsers` (the `actions/cache` post-step, upload on miss) duration:
    **~3.7s** (`01:09:44.02Z` → `01:09:47.76Z`), log line `Sent 361117333 of 361117333 (100.0%),
    344.4 MBs/sec` / `Cache saved with key: Linux-playwright-chromium-webkit-1.59.1-v1` — the
    ~344MB browser cache actually saved (local-runner-to-blob transfer is fast; the byte count,
    not the 3.7s, is the "~400-500MB" figure the objective anticipated).
- **`Admin eval render + probe (evidence only, not a merge gate)`:** `conclusion: skipped`,
  duration **0s** (< 5s) — SC-2's restated criterion, satisfied.

Aggregate window (same day, for the REQUIREMENTS.md baseline comparison — see "Re-fetched Window
Baseline" above for the pre-Phase-230 re-fetch; this is the post-AFTER-PR re-fetch, already
mixing pre- and post-change runs since the window slides):

```
bash scripts/ci/ci-run-metrics.sh --limit 40 --format table
```

```
| trigger | n | mean | p50 | max | outcomes |
| --- | --- | --- | --- | --- | --- |
| pull_request | 24 | 28.8m | 27.4m | 41.7m | 21 pass / 3 fail |
| push | 9 | 29.7m | 27.4m | 42.3m | 8 pass / 1 fail |
| schedule | 6 | 27.0m | 27.1m | 27.7m | 0 pass / 6 fail |
| workflow_dispatch | 1 | 7.8m | 7.8m | 7.8m | 0 pass / 1 fail |
```

This 40-run window now contains 24 `pull_request` runs (up from 21 in REQUIREMENTS.md and 23 in
the pre-Phase-230 re-fetch above) — the single AFTER-PR run has entered the window and nudged
`pull_request` mean down from 29.4m to 28.8m, but n=24 with only one post-change run inside it is
not a post-change measurement; it is still overwhelmingly the pre-change population. Phase 235
owns the dedicated ≥10-run post-change measurement window (FAST-01).

**Note on AFTER-NONPR / AFTER-PUSH cache scope:** both of those runs are *expected* to report
`cache-hit: false` on their own first sighting of the `Linux-playwright-chromium-webkit-1.59.1-v1`
key, because their cache scope (`refs/heads/ci-efficiency-milestone-scope` and `refs/heads/main`
respectively) is distinct from this pull request's `refs/pull/117/merge` scope — GitHub Actions
does not share cache entries across scopes on first write. A reader must not read those misses as
a FAST-06 regression; only the AFTER-PR / AFTER-PR-WARM pair below is evidence for FAST-06.

---

## AFTER-PR-WARM

Status: captured (run 30413542431)

A **second** run on the *same* pull request (#117) as AFTER-PR, pushed only after AFTER-PR
(`30412458437`) fully completed and its `Example Playwright smoke (full lifecycle)` job
concluded **success** (`actions/cache` declares `post-if: success()`, so a non-success job would
save nothing and the warm run would also miss — verified success above, `989s`/`16m29s`). This
is the only slot in the ledger capable of logging a Playwright browser cache **hit**: a
brand-new cache key misses by construction on the run that introduces it, and a `pull_request`
run's cache scope (`refs/pull/117/merge`) is not readable by the `refs/heads/…`-scoped
AFTER-NONPR or AFTER-PUSH runs (GitHub Actions cache scoping). Two runs on one pull request
sharing a scope is the only pairing available, so FAST-06 is verified as an observed
**miss-then-hit pair** rather than a single observation.

The warm commit (`be2ff143761e39d4c8ad2e18ac02f14586560327`) touches exactly one file that is
neither Markdown nor under `.planning/`: a provenance comment appended to
`scripts/ci/playwright-cache-key-guard.sh` recording `30412458437` as the cache-seeding run
(self-test kept green: `bash scripts/ci/playwright-cache-key-guard.test.sh` → `7 passed, 0
failed`). It does not touch `test/example/priv/playwright/package-lock.json` or the cache key
itself. Its `Detect docs-only change` job (`90454907468`) emits `docs_only=false` (log
`2026-07-29T01:15:31Z`), confirming the Playwright lane was not gated off.

Run: `30413542431` · event `pull_request` · head `be2ff143761e39d4c8ad2e18ac02f14586560327` ·
created `2026-07-29T01:15:18Z` · completed `2026-07-29T01:34:59Z` · wall-clock **19m41s**.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30413542431
```

Output (verbatim):

```
job                                                                 conclusion  duration_s  duration
Release ref guard                                                   success     2s          0m2s
Detect docs-only change                                             success     6s          0m6s
Fast checks (milestone/installer/contracts/snapshot/ledger guards)  success     26s         0m26s
Passkeys opt-out smoke                                              skipped     0s          0m0s
Install matrix (flag combinations)                                  skipped     0s          0m0s
Nightly probe (forced-failure self-test)                            skipped     0s          0m0s
Passkeys manual fallback smoke                                      skipped     0s          0m0s
Install golden + idempotency contract (subprocess harness)          success     34s         0m34s
Library tests shard 1                                               success     478s        7m58s
Library tests shard 2                                               success     311s        5m11s
Recapture admin-checkpoint baselines (in-CI)                        skipped     0s          0m0s
Upgrade smoke (published source series -> local candidate)          skipped     0s          0m0s
Generated admin Playwright smoke                                    skipped     0s          0m0s
Admin eval render + probe (evidence only, not a merge gate)         skipped     0s          0m0s
Recapture admin-design baselines (in-CI)                            skipped     0s          0m0s
Install smoke (fresh phx.new + sigra.install)                       success     109s        1m49s
Example HTTP smoke (boot + curl critical routes)                    success     59s         0m59s
Library tests (dep-off — Threadline absent)                         success     76s         1m16s
Example Playwright smoke (full lifecycle)                           success     1151s       19m11s
Example unit smoke (ExUnit + ConnTest)                              success     65s         1m5s
Library tests                                                       success     4s          0m4s
ci-gate                                                              success     3s          0m3s
Notify on red ci-gate (release-lane-rot)                            skipped     0s          0m0s
```

Design gallery axe step re-confirms **39 tests** (`Running 39 tests using 1 worker` … `39 passed
(3.9m)`, `2026-07-29T01:26:55Z` → `01:30:49Z`) and the snapshot step remains `skipped` —
unaffected by the cache change, as expected.

**The miss/hit pair, recorded verbatim from `gh run view --json jobs` step timestamps and
`gh run view --log --job <id>` for job `90451525539` (AFTER-PR) and `90454943707`
(AFTER-PR-WARM):**

| | AFTER-PR (run `30412458437`) — miss | AFTER-PR-WARM (run `30413542431`) — hit |
|---|---|---|
| `Cache Playwright browsers` restore log | `Cache not found for input keys: Linux-playwright-chromium-webkit-1.59.1-v1, Linux-playwright-chromium-webkit-` | `Cache hit for: Linux-playwright-chromium-webkit-1.59.1-v1` / `Cache restored from key: Linux-playwright-chromium-webkit-1.59.1-v1` |
| **Cache-hit value (literal)** | **`cache-hit: false`** | **`cache-hit: true`** |
| `Install Playwright browsers` command run | `npx playwright install --with-deps chromium webkit` (full browser download + OS deps) | `npx playwright install-deps chromium webkit` (OS deps only — D-17's `cache-hit != 'true'` gate correctly took the cheaper branch) |
| `Install Playwright browsers` duration | 36s (`00:54:06Z`→`00:54:42Z`) | 180s (`01:16:37Z`→`01:19:37Z`) |
| `actions/cache` post-step (`Post Cache Playwright browsers`) | `Sent 361117333 of 361117333 (100.0%), 344.4 MBs/sec` / `Cache saved with key: …` — **3.7s** (`01:09:44.02Z`→`01:09:47.76Z`) | `Cache hit occurred on the primary key …, not saving cache.` — **~0s** (`01:34:41.70Z`→`01:34:41.70Z`, no re-upload on an exact hit) |

**Discrepancy, recorded honestly rather than adjusted:** the `actions/cache` post-step behaves
exactly as predicted — 0s / no re-upload on a hit vs 3.7s / a real upload on a miss — but the
`Install Playwright browsers` **step total** duration is *higher* on the hit run (180s) than on
the miss run (36s), the opposite of D-15's ~15-25s-savings prediction on that step. The step log
shows the branch taken is correct — `if [ "true" = "true" ]` selects `install-deps` (the
cache-hit path) rather than `install --with-deps` — and the cache mechanism itself is proven by
the restore log line above; the extra time on the hit run is entirely inside `apt-get`'s package
resolution/fetch for the same `install-deps chromium webkit` OS-dependency set that D-15 already
documented as **not cacheable** (`~33s` baseline estimate; this run's apt phase alone ran ~180s).
This reads as apt-mirror/network variance between the two runs' Azure-hosted GitHub runners, not
a defect in the cache wiring — the thing FAST-06 caches (the ~344MB browser binary download) is
demonstrably skipped on the hit run (`Cache restored from key`, no `Get:` progress for browser
binaries), while the uncacheable OS-dependency install (D-15's explicit scope exclusion) is what
varied. Recorded as an open item below rather than silently omitted or used to soften FAST-06's
criterion — the cache-hit/no-re-upload half of the pair, which *is* FAST-06's contract, holds.

---

## AFTER-NONPR

Status: captured (run 30414885679)

A `workflow_dispatch` run on the phase branch. The demoted `admin_eval_render` (FAST-03) and
the event-gated snapshot step (FAST-02) must be observed *executing* somewhere inside the phase
window, not only absent from the PR — waiting for AFTER-PUSH would push that observation past
the phase.

**Deviation from the plan's literal precondition (Rule 3 — blocking-issue auto-fix):** Task
2's stated precondition is "the dispatch is run with `force_fail_probe` false and
`recapture_branch` empty." A first dispatch attempt with both inputs at their literal defaults
(run `30414636733`) failed at `release_ref_guard`: that job's own logic (`ci.yml:73-91`) requires
a `workflow_dispatch` run to target `refs/tags/v*` **unless** `recapture_branch` is non-empty
(D-04's relaxation) — a branch-ref dispatch with `recapture_branch` empty is structurally
rejected, cascading `skipped` through every downstream job including `admin_eval_render`. This
is not a Phase 230 regression; it is the pre-existing, intentional release-evidence guard doing
its job. Re-dispatched with `recapture_branch=ci-efficiency-milestone-scope` (the phase branch
itself) — the documented way to run a branch-scoped dispatch (`ci.yml:13-17`) — which passed
`release_ref_guard` and let the full matrix execute. `30414636733` is recorded here as the
failed precondition-attempt for completeness; `30414885679` is the captured AFTER-NONPR run.

Run: `30414885679` · event `workflow_dispatch` · created `2026-07-29T01:43:32Z` · completed
`2026-07-29T02:08:13Z` · earliest job (`Release ref guard`) started `2026-07-29T01:43:35Z` — a
**3-second** queue delay, confirming this non-PR run was not queued (the structural half of
SC-3: every non-PR event keys on its own unique `github.run_id`, D-12).

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs 30414885679
```

Output (verbatim):

```
job                                                                    conclusion  duration_s  duration
Passkeys opt-out smoke                                                 success     193s        3m13s
Release ref guard                                                      success     2s          0m2s
Nightly probe (forced-failure self-test)                               success     3s          0m3s
Detect docs-only change                                                success     9s          0m9s
Passkeys manual fallback smoke                                         success     110s        1m50s
Install matrix (flag combinations)                                     success     107s        1m47s
Install matrix (flag combinations) (--no-organizations)                success     107s        1m47s
Fast checks (milestone/installer/contracts/snapshot/ledger guards)     success     28s         0m28s
Install matrix (flag combinations) (--no-passkeys)                     success     112s        1m52s
Install matrix (flag combinations) (--no-organizations --no-passkeys)  success     117s        1m57s
Install golden + idempotency contract (subprocess harness)             success     345s        5m45s
Library tests shard 2                                                  success     317s        5m17s
Recapture admin-checkpoint baselines (in-CI)                           success     351s        5m51s
Library tests shard 1                                                  success     396s        6m36s
Admin eval render + probe (evidence only, not a merge gate)            failure     1074s       17m54s
Upgrade smoke (published source series -> local candidate)             success     119s        1m59s
Generated admin Playwright smoke                                       failure     265s        4m25s
Recapture admin-design baselines (in-CI)                               success     980s        16m20s
Install smoke (fresh phx.new + sigra.install)                          success     113s        1m53s
Example Playwright smoke (full lifecycle)                              success     1443s       24m3s
Example HTTP smoke (boot + curl critical routes)                       success     56s         0m56s
Library tests (dep-off — Threadline absent)                            success     78s         1m18s
Example unit smoke (ExUnit + ConnTest)                                 success     53s         0m53s
Library tests                                                          success     2s          0m2s
ci-gate                                                                failure     3s          0m3s
Notify on red ci-gate (release-lane-rot)                               success     7s          0m7s
```

No job in this table reports `cancelled`. `ci-gate` is `failure`, caused by
`generated_admin_playwright_smoke` (`failure`) — that job **is** in `ci-gate.needs`
(`ci.yml:1766-1776`) — and is the pre-existing, out-of-scope GATE-02 defect (stale `head_ref ==
'ship/v1.42-ci-gate-remediation'` condition, `ci.yml:1343`; `230-CONTEXT.md` "Explicitly NOT in
scope" list). `admin_eval_render`'s own `failure` does **not** contribute to `ci-gate` — D-10
confirmed it is deliberately absent from `ci-gate.needs`, and this run confirms that
independently: `ci-gate`'s step log lists only `GENERATED_ADMIN_PLAYWRIGHT_SMOKE` as the failing
required lane, `ADMIN_EVAL_RENDER` is not one of the nine env vars the job checks at all.

**The four facts this slot exists to prove, each pulled from `--json jobs` and per-job step
logs:**

- **`admin_eval_render` executes** (not skipped): `conclusion: failure`, duration **1074s /
  17m54s** — exceeds 900s, in the documented ~18min band (D-19: 18.36m historical). The
  `failure` conclusion is recorded exactly as printed, per the plan's instruction — it is
  GATE-04's scope (Phase 231, D-11: `continue-on-error: true` is deliberately retained this
  phase) and does not invalidate the observation that the demoted work *moved*, not
  *disappeared*.
- **`design_gallery_snapshots` (the `Run design gallery board snapshots (non-PR)` step inside
  `Example Playwright smoke (full lifecycle)`, job `90459154527`) executes 84 tests:**
  `Running 84 tests using 1 worker` … `84 passed (7.2m)` (`2026-07-29T01:56:43Z` →
  `02:03:57Z`).
- **`admin_design_recapture`'s recapture step (job `90459122106`) executes the full ungrepped
  inventory: 123 tests**, not 120: `Running 123 tests using 1 worker` … `123 passed (12.1m)`
  (`2026-07-29T01:45:15Z` → `01:57:19Z`). This confirms the 120→123 correction recorded in
  `230-VALIDATION.md` ("Correction — recapture executed-test count") rather than the stale
  RESEARCH.md figure — no Pitfall 1 regression.
- **No queueing / no cancellation:** confirmed above (0 `cancelled` jobs, 3s queue delay).

**Recapture pull request cleanup:** the dispatch opened **PR #119**
(`ci/recapture-admin-checkpoints-30414885679` → `ci-efficiency-milestone-scope`, "ci: recapture
admin-checkpoint + demo-showcase baselines in ubuntu CI (30414885679)"). It targeted the phase
branch rather than `main` because `recapture_branch` was set (D-04) — expected given the
deviation above. No `admin-design` recapture PR opened (the design-gallery lane's baselines did
not drift on this run). PR #119 was **closed without merging** and its branch **deleted**:

```
gh pr close 119 --delete-branch
```

`gh pr view 119 --json state` → `{"state":"CLOSED"}`.

**Schedule-half substitution, stated in words:** this `workflow_dispatch` run is a **proxy** for
the nightly `schedule` trigger, not an observation of the nightly itself — the nightly has been
0-pass/9-fail over the whole sampled window (`230-VALIDATION.md`, REQUIREMENTS.md baseline
table), and reviving it to green is **GATE-01's** problem in **Phase 231**, not this phase's.
SC-3's schedule half is proven here by this dispatch proxy plus the structural
`github.run_id`-group argument (D-12: every non-PR event, including `schedule`, keys on its own
unique `run_id`, giving it a concurrency group of one that is structurally never queued or
cancelled — independently confirmed by this run's 0 `cancelled` jobs / 3s queue delay above).
This substitution is recorded in the per-requirement table below with evidence class
`proxy-observed`, not `observed`.

---

## AFTER-PUSH

Status: pending (post-merge obligation)

**Post-merge obligation.** This slot needs the push-to-`main` run of the merge commit, which
does not exist until the phase merges — there is no way to capture it before that point.

Post-merge capture command:

```
gh run list --repo szTheory/sigra --branch main --limit 1 --json databaseId --jq '.[0].databaseId'
bash scripts/ci/ci-run-metrics.sh --jobs <id-from-above>
```

---

## AFTER-DOCSONLY

Status: pending (post-merge obligation)

**Post-merge obligation.** `ci.yml` triggers on `pull_request: branches: [main]`, so every pull
request that runs the workflow diffs against `origin/main`; and any pre-merge pull request
carrying this phase's own `ci.yml`, `scripts/ci/*.sh`, and
`test/example/priv/playwright/tests/admin-design.spec.ts` changes is by definition not
docs-only, so no pre-merge PR can ever land in the `docs_only=true` branch. This slot cannot be
captured before the merge.

FAST-05's in-phase evidence is not this slot — it is the hermetic
`scripts/ci/docs-only-classify.test.sh` (both directions of the classification rule, plus the
empty-input and crafted-path cases) plus AFTER-PR's observed `docs_only=false` on a genuinely
mixed diff. The pending marker here is therefore a deferred *confirmation* of the `true` branch
on a real PR, not an evidence hole — FAST-05 is already falsifiable in-phase without it.

Post-merge capture command (cut a branch from `main` after the merge, commit a single `.md`
edit, open a PR against `main`):

```
gh pr checks <n>
gh run view <id> --repo szTheory/sigra --json jobs
```

---

## AFTER-CANCEL

Status: captured (runs 30416160743 cancelled, 30416184110 completed)

A double-push probe on a throwaway branch (`230-09-cancel-probe`) cut from the phase branch
(`ci-efficiency-milestone-scope`, so it inherits the new workflow — a branch cut from `main`
would run the pre-change workflow and prove nothing): push once, then push again immediately,
and confirm the superseded run concludes `cancelled` (FAST-04's `concurrency:` group, D-12)
while push/schedule runs on other branches are unaffected. This is also where the AFTER-DOCSONLY
slot's expectation is tested directly: a Markdown-only probe commit still classifies
`docs_only=false` because it inherits this phase's own diff — the "impossibility observed rather
than argued" evidence cited for FAST-05.

**Throwaway PR: #120** (`230-09-cancel-probe` → `main`, "throwaway: 230-09 AFTER-CANCEL probe (DO
NOT MERGE)"). Commit 1 (`825250fa`, run `30416160743` created `2026-07-29T02:11:28Z`) added a
single new Markdown file (`230-09-CANCEL-PROBE.md`) and nothing else. Commit 2 (`58ff93eb`, run
`30416184110` created `2026-07-29T02:11:58Z` — **30 seconds** later, while commit 1's run was
still in its early library-tests leg) edited that same file, still Markdown-only.

Command:

```
gh run list --repo szTheory/sigra --branch 230-09-cancel-probe --json databaseId,headSha,status,conclusion,createdAt
```

Output (verbatim):

```json
[
  {"conclusion":"","createdAt":"2026-07-29T02:11:58Z","databaseId":30416184110,"headSha":"58ff93ebce6996b5f99c0814e89a6caeacb043b6","status":"queued"},
  {"conclusion":"cancelled","createdAt":"2026-07-29T02:11:28Z","databaseId":30416160743,"headSha":"825250faba2db37f303dcc05da6b4fed75f359c5","status":"completed"}
]
```

(captured mid-supersession, before the second run finished; re-fetched after both completed:)

```json
[
  {"conclusion":"success","createdAt":"2026-07-29T02:11:58Z","databaseId":30416184110,"headSha":"58ff93ebce6996b5f99c0814e89a6caeacb043b6","status":"completed"},
  {"conclusion":"cancelled","createdAt":"2026-07-29T02:11:28Z","databaseId":30416160743,"headSha":"825250faba2db37f303dcc05da6b4fed75f359c5","status":"completed"}
]
```

The earlier run (`30416160743`, commit 1) concludes **`cancelled`** — superseded by the second
push 30 seconds later, exactly the `concurrency: { group:
${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }},
cancel-in-progress: true }` behaviour D-12 specifies. The later run (`30416184110`, commit 2)
**completed successfully**. No push/schedule/`workflow_dispatch` run in this phase's captured set
(BEFORE-PR, BEFORE-PUSH, AFTER-PR, AFTER-PR-WARM, AFTER-NONPR above) reports `cancelled` or a
queued start — a `gh run list --limit 15` snapshot taken at the same time shows the only two
`cancelled`/superseded runs anywhere in the recent history are these two PR-#120 runs; the
concurrent PR #117 run (`30416143238`, in flight at the same moment on a different PR/group) was
unaffected.

**The `docs_only` impossibility, observed rather than argued:** commit 1's `changes` job
(`Detect docs-only change`, job `90463148921`) emits **`docs_only=false`**
(`2026-07-29T02:12:24Z`), even though the commit itself touched only a new `.md` file. The
classifier reads `git diff --name-only origin/main...HEAD`, and on this branch that diff carries
every phase commit — `.github/workflows/ci.yml`, `scripts/ci/*.sh`,
`test/example/priv/playwright/tests/admin-design.spec.ts`, `test/sigra/planning/*.exs` — none of
which is Markdown or under `.planning/`. This is the **observed** demonstration that no pre-merge
pull request carrying this phase's own changes can exercise the docs-only fast path, regardless
of what its own newest commit touches: the classifier compares against `origin/main`, not against
the commit's own diff, and `pull_request: branches: [main]` leaves no alternative base to escape
that comparison.

**Cleanup:** PR #120 closed without merging; branch `230-09-cancel-probe` deleted (remote and
local):

```
gh pr close 120 --delete-branch
```

`gh pr view 120 --json state` → `{"state":"CLOSED"}`.

---

## Restated Success Criterion (SC-2)

RESEARCH finding 2 established that SC-2 as worded in ROADMAP.md is literally unsatisfiable: a
job whose `if:` evaluates false is **still present** in `gh run view --json jobs` with
`conclusion: "skipped"` and ~0s duration (verified on PR run `30390832059`, six such jobs).

**Operative restatement — verify against this, not the ROADMAP wording:**

> `admin_eval_render` appears in a PR run's job list with `conclusion == "skipped"` and
> `duration < 5s`, and appears on a non-PR run with `conclusion == "success"` and a
> real duration — with its ~17m no longer charged to any PR.

The "absent from the job list" wording in ROADMAP.md is unsatisfiable because a false `if:`
produces a `conclusion: "skipped"` job record with `completedAt ≈ startedAt`, never an absent
record — GitHub creates a job entry for every job declared in the workflow regardless of
whether its `if:` evaluates true. The six such jobs observed on run `30390832059`
(`[VERIFIED: gh run view 30390832059 --repo szTheory/sigra --json jobs, run live 2026-07-28]`,
`230-RESEARCH.md` § "SC-2 is unsatisfiable as literally worded"):

```
Nightly probe (forced-failure self-test)        skipped  19:11:09 → 19:11:09
Passkeys manual fallback smoke                  skipped  19:11:09 → 19:11:09
Install matrix (flag combinations)              skipped  19:11:09 → 19:11:09
Passkeys opt-out smoke                          skipped  19:11:09 → 19:11:09
Upgrade smoke (published source series …)       skipped  19:11:14 → 19:11:13
Recapture admin-design baselines (in-CI)        skipped  19:11:14 → 19:11:13
```

The `Upgrade smoke` and `Recapture admin-design baselines (in-CI)` rows above are the ones
whose `completedAt` precedes `startedAt` by ~1s — the negative-raw-duration case
`ci-run-metrics.sh` clamps to 0 (see Task 1's `<verify>`; also observed on `notify_release_lane_rot`
in this same run, per `230-RESEARCH.md`).

Both halves of the restatement are directly confirmed by BEFORE-PR / BEFORE-PUSH above:
`Admin eval render + probe (evidence only, not a merge gate)` is `skipped`-and-absent-from-billing
on no observed run yet (it demotes in this phase's own changes, captured at AFTER-PR /
AFTER-NONPR), but the *mechanism* — a false `if:` producing a present `skipped` record rather
than an absent one — is exactly what the six jobs above already demonstrate on the pre-change
baseline, and BEFORE-PUSH shows the symmetric non-PR half: every one of those same jobs runs
with a real conclusion and a real duration when the event is not `pull_request`.

---

## Re-fetched Window Baseline

Fetched 2026-07-28 (same day as BEFORE-PR/BEFORE-PUSH, before any Phase 230 CI edit changed the
window's composition). The 40-run window slides forward continuously, so `n` differs from
REQUIREMENTS.md:9-13 — but the `max` values for `pull_request` and `push` match REQUIREMENTS.md
exactly (`41.7m`, `42.3m`), confirming this script reproduces the baseline's measurement method
byte-for-byte on `max`, independent of the window's exact membership.

Command:

```
bash scripts/ci/ci-run-metrics.sh --limit 40 --format table
```

Output (verbatim):

```
| trigger | n | mean | p50 | max | outcomes |
| --- | --- | --- | --- | --- | --- |
| pull_request | 23 | 29.4m | 27.4m | 41.7m | 20 pass / 3 fail |
| push | 9 | 29.7m | 27.4m | 42.3m | 8 pass / 1 fail |
| schedule | 7 | 27.0m | 27.1m | 27.7m | 0 pass / 7 fail |
| workflow_dispatch | 1 | 7.8m | 7.8m | 7.8m | 0 pass / 1 fail |
```

REQUIREMENTS.md:9-13's committed baseline, for comparison:

```
| trigger | n | mean | p50 | max | outcomes |
| --- | --- | --- | --- | --- | --- |
| pull_request | 21 | 29.5m | 27.3m | 41.7m | 17 pass / 4 fail |
| push (main) | 7 | 30.5m | 27.6m | 42.3m | 6 pass / 1 fail |
| schedule (nightly) | 9 | 27.3m | 27.1m | 29.4m | 0 pass / 9 fail |
```

`max` matches exactly on both `pull_request` (41.7m) and `push` (42.3m). `n`/`mean`/`p50` drift
by the amount expected from a 40-run sliding window advancing over the ~13 days between the
original capture and this re-fetch — this is the expected, documented behavior of a windowed
measurement, not a discrepancy in the method.

---

## Predicted vs. Observed Post-Change PR Wall-Clock

**Predicted, stated before the observed number (230-CONTEXT.md, D-01/D-15/D-07 arithmetic):**

- Pre-change critical path: `example_playwright_smoke` at **28.5m** (of a 28.7m BEFORE-PR run).
- FAST-02 removes **~629s (~10.5m)** of gallery snapshot work from inside that job (D-01:
  866s → ~237s for the axe-only PR step).
- FAST-06 removes **~15-25s** more (D-15's honest browser-cache estimate, not the naive ~62s).
- The new `changes` classifier adds up to **~36s** at the head of the DAG (D-07), partly masked
  by `release_ref_guard` running alongside it.
- Net prediction: 28.5m − 10.5m − ~20s + ~36s(partially masked) ≈ **~18m**.

`FAST-03`'s 17m33s (`admin_eval_render`, BEFORE-PR) is deliberately **not** subtracted from this
arithmetic: `admin_eval_render` was never inside `example_playwright_smoke` / the critical path
on the PR event — it ran as its own parallel job (BEFORE-PR: `failure`/`17m33s`, non-blocking,
`continue-on-error: true`) and demoting it removes ~56 runner-minutes of PR *cost*, not PR
*wall-clock*. It does not move the critical path, because 17m33s was always under the 28.5m pole.

**Observed:** AFTER-PR (run `30412458437`) — `example_playwright_smoke` **989s (16m29s)**, run
wall-clock **16m52s** (`updatedAt - createdAt`). The observation lands **under** the ~18m
prediction by roughly 1m — better than the arithmetic anticipated, plausibly because the
`changes` classifier's ~36s head-of-DAG cost is genuinely masked by `release_ref_guard` running
in parallel (both complete before `example_playwright_smoke` starts), rather than only partially.

**This is not FAST-01.** ~18m predicted / 16m52s observed both land well short of the milestone's
under-12m headline by design — **FAST-01 / under-12m is Phase 235's verdict**, after the Tier-2
and Playwright-economics phases (`ROADMAP.md` v1.47 section), measured over ≥10 post-change runs
in a dedicated window. This phase's own AFTER-PR is one run; Phase 235 owns the statistically
meaningful sample.

---

## Per-Requirement Summary

Evidence classes: **`observed`** (the criterion's own subject watched doing the thing on a named
run) · **`proxy-observed`** (a different-but-analogous run stood in because the criterion's own
trigger was unobtainable in the phase window, substitution named) · **`hermetic-unit`** (a
committed self-test executed by `fast_checks` on every PR and push, no run watched) ·
**`structural-argument`** (a property of the configuration, no run watched and no test executes
the claim).

| Req | Behavior | Evidence | Number / Fact | Class |
|-----|----------|----------|----------------|-------|
| FAST-02 | `@snapshot` tag-integrity (board tests tagged, axe tests not) | `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs` | green | `hermetic-unit` |
| FAST-02 | PR gallery step executes only axe scans | AFTER-PR, job `90451525539`, step `Run design gallery boards (chromium, mobile, dark)` | **39** tests, `39 passed (3.9m)` | `observed` |
| FAST-02 | Non-PR snapshot step executes the demoted boards | AFTER-NONPR, job `90459154527`, step `Run design gallery board snapshots (non-PR)` | **84** tests, `84 passed (7.2m)` | `observed` |
| FAST-02 | `admin_design_recapture` still executes the full inventory (Pitfall 1 guard; 120→123 correction) | AFTER-NONPR, job `90459122106` | **123** tests, `123 passed (12.1m)` | `observed` |
| FAST-03 | `admin_eval_render` skipped on PR | AFTER-PR | `conclusion: skipped`, `0s` | `observed` |
| FAST-03 | `admin_eval_render` executes on non-PR | AFTER-NONPR | `conclusion: failure` (GATE-04/D-11 scope, unrelated to demotion), `1074s`/`17m54s` | `observed` |
| FAST-04 | Superseded PR run cancels | AFTER-CANCEL, run `30416160743` | `conclusion: cancelled` | `observed` |
| FAST-04 | Later run on the same PR completes; no push/schedule/dispatch run cancels | AFTER-CANCEL run `30416184110` completed; 0 `cancelled` jobs across BEFORE-PR/BEFORE-PUSH/AFTER-PR/AFTER-PR-WARM/AFTER-NONPR | `success`; 0 cancellations elsewhere | `observed` |
| FAST-05 | Classification rule, both directions + empty-input + crafted-path cases | `bash scripts/ci/docs-only-classify.test.sh` | `11 passed, 0 failed` | `hermetic-unit` |
| FAST-05 | Classifier wired, emits on a real mixed diff | AFTER-PR job `90451499447` **and** AFTER-CANCEL job `90463148921` | `docs_only=false` (both) | `observed` |
| FAST-05 | Docs-only fast path end-to-end (`docs_only=true`, five contexts merge-eligible) | AFTER-DOCSONLY (post-merge obligation) | not yet capturable pre-merge | `structural-argument` |
| FAST-06 | Cache key tracks the lockfile version | `bash scripts/ci/playwright-cache-key-guard.test.sh` | `7 passed, 0 failed` | `hermetic-unit` |
| FAST-06 | Miss-then-hit pair on one PR | AFTER-PR (`cache-hit: false`) → AFTER-PR-WARM (`cache-hit: true`) | see restated net below | `observed` |
| FAST-07 | Every job declares `timeout-minutes` | `mix test test/sigra/planning/phase_230_ci_timeouts_test.exs` | green | `hermetic-unit` |
| FAST-07 | No job in any captured run times out | BEFORE-PR, BEFORE-PUSH, AFTER-PR, AFTER-PR-WARM, AFTER-NONPR, AFTER-CANCEL | 0 `conclusion: timed_out` anywhere in six captured `--jobs` tables | `observed` |
| SC-1 (push-to-main half) | Push-to-`main` run of the merge commit | AFTER-PUSH (post-merge obligation) | not yet capturable pre-merge | `structural-argument` |
| SC-1 (non-PR never queued/cancelled) | `github.run_id`-group gives every non-PR event a group of one | AFTER-NONPR's 3s queue delay, 0 cancellations; AFTER-CANCEL's push/schedule-unaffected observation | consistent with, not yet the merge-commit proof | `structural-argument` |
| SC-3 (concurrency half) | Superseded PR run cancels, others don't | AFTER-CANCEL | see FAST-04 rows above | `observed` |
| SC-3 (schedule half) | Nightly-equivalent run observed executing the full non-PR matrix | AFTER-NONPR (`workflow_dispatch` substituting for `schedule`; nightly itself is 0-pass/9-fail, reviving it is **GATE-01 / Phase 231**) | 84-test snapshot step, 123-test recapture step, `admin_eval_render` real duration, all executing | `proxy-observed` |
| SC-2 | `admin_eval_render` restated criterion (skipped <5s on PR, real duration on non-PR) | AFTER-PR (`skipped`, `0s`) + AFTER-NONPR (`failure`, `1074s`) | both halves observed | `observed` |

**FAST-06's honest net, restated (not a headline saving figure):** a miss was logged on the
key-introducing run (AFTER-PR, `30412458437`) and a hit on the next run of the same pull request
(AFTER-PR-WARM, `30413542431`). The `actions/cache` post-step behaved exactly as the mechanism
predicts — miss: **3.7s**, a real ~344MB upload (`Sent 361117333 of 361117333`); hit: **~0s**,
`not saving cache` (no re-upload on an exact key match). The `Install Playwright browsers` step,
however, did **not** show the predicted ~15-25s saving: miss **36s** (full
`install --with-deps`, browser download + OS deps) vs hit **180s** (`install-deps` only — the
correct cheaper branch was taken, confirmed by the literal command in the step log — but
apt-get's package resolution for that non-cacheable OS-dependency set ran far slower on this
particular run than D-15's ~33s baseline estimate). The cache mechanism itself is directly
proven — `Cache hit for: Linux-playwright-chromium-webkit-1.59.1-v1` / `Cache restored from key:
…` on the hit run, absent on the miss run — but the net PR-wall-clock benefit of FAST-06 is not
demonstrated by this pair's `Install Playwright browsers` step timing, and is not claimed to be.

---

## Discrepancies (open items, not silently absorbed into adjusted expectations)

1. **AFTER-PR-WARM's `Install Playwright browsers` step duration (180s) is higher than
   AFTER-PR's (36s),** the opposite of D-15's ~15-25s-saving prediction for that step. Diagnosed
   above: the cache-hit branch (`install-deps` only) was correctly selected, and the browser
   binary restore is directly confirmed in the log — the extra time is entirely inside apt-get's
   package resolution for the non-cacheable OS-dependency set (D-15's own documented scope
   exclusion), which appears to have hit a slower window against the Ubuntu/Microsoft package
   mirrors on this specific run. Not re-run to "fix" the number, per the plan's instruction to
   record discrepancies rather than adjust expectations to match them.
2. **`ci-gate` is `failure` on AFTER-NONPR** (run `30414885679`), caused by
   `generated_admin_playwright_smoke` (`failure`). This is the **pre-existing, out-of-scope
   GATE-02 defect** (`ci.yml:1343`'s stale `head_ref == 'ship/v1.42-ci-gate-remediation'`
   condition — `230-CONTEXT.md` "Explicitly NOT in scope" list), not a Phase 230 regression;
   `admin_eval_render`'s own `failure` on the same run is independently confirmed to **not**
   contribute to `ci-gate` (it is absent from `ci-gate.needs`, D-10). Phase 231 owns fixing
   GATE-02.
3. **The plan's literal Task 2 precondition ("`recapture_branch` empty") cannot succeed on a
   branch-ref `workflow_dispatch`** — `release_ref_guard` requires either a `refs/tags/v*` ref
   or a non-empty `recapture_branch` (D-04). Recorded as a Rule 3 deviation in the AFTER-NONPR
   section above rather than silently working around it; the first (failed) attempt (run
   `30414636733`) is kept in the ledger for completeness alongside the corrected, captured run.
