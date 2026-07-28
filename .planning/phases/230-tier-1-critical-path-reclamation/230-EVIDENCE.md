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

Status: pending

The **miss** half of FAST-06's Playwright browser cache pair. This is the phase's own PR, final
commit, first run — a new cache key can only miss on the run that introduces it. Capture after
the phase PR opens and its checks complete.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs <id>
```

---

## AFTER-PR-WARM

Status: pending

A **second** run on the *same* pull request as AFTER-PR, pushed only after AFTER-PR completes
and its Playwright job concludes success. This is the only slot in the ledger capable of
logging a Playwright browser cache **hit**: a brand-new cache key misses by construction on the
run that introduces it, and a `pull_request` run's cache scope (`refs/pull/<n>/merge`) is not
readable by the `refs/heads/…`-scoped AFTER-NONPR or AFTER-PUSH runs (GitHub Actions cache
scoping). Two runs on one pull request sharing a scope is the only pairing available, so
FAST-06 is verified as an observed miss-then-hit pair rather than a single observation.

Command:

```
bash scripts/ci/ci-run-metrics.sh --jobs <id>
```

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
