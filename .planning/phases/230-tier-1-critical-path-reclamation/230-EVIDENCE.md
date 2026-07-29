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
| [AFTER-PR](#after-pr) | The phase's own PR, final commit — the **miss** half of FAST-06's pair | `ci-run-metrics.sh --jobs <id>` | pending |
| [AFTER-PR-WARM](#after-pr-warm) | A second run on the **same** PR, pushed only after AFTER-PR's Playwright job concludes — the **hit** half of FAST-06's pair | `ci-run-metrics.sh --jobs <id>` | pending |
| [AFTER-NONPR](#after-nonpr) | `workflow_dispatch` on the phase branch — the demoted `admin_eval_render` and the event-gated snapshot step observed *executing* inside the phase window | `ci-run-metrics.sh --jobs <id>` | pending |
| [AFTER-PUSH](#after-push) | The push-to-`main` run of the merge commit | `ci-run-metrics.sh --jobs <id>` | pending (post-merge obligation) |
| [AFTER-DOCSONLY](#after-docsonly) | A docs-only PR cut from `main` after the merge | `gh pr checks <n>` + `gh run view <id> --json jobs` | pending (post-merge obligation) |
| [AFTER-CANCEL](#after-cancel) | Double-push probe on a throwaway PR branch cut from the phase branch | `gh run list --branch <b> --json conclusion` | pending |

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

Status: pending

A `workflow_dispatch` run on the phase branch. The demoted `admin_eval_render` (FAST-03) and
the event-gated snapshot step (FAST-02) must be observed *executing* somewhere inside the phase
window, not only absent from the PR — waiting for AFTER-PUSH would push that observation past
the phase.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs <id>
```

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

Status: pending

A double-push probe on a throwaway branch cut from the phase branch: push once, then push again
immediately, and confirm the superseded run concludes `cancelled` (FAST-04's `concurrency:`
group, D-12) while push/schedule runs on other branches are unaffected. This is also where the
AFTER-DOCSONLY note above expects a Markdown-only probe commit to still classify `docs_only:
false` if it inherits this phase's own diff, which is the "impossibility observed rather than
argued" evidence cited for FAST-05.

Command:

```
gh run list --repo szTheory/sigra --branch <throwaway-branch> --json conclusion
```

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
