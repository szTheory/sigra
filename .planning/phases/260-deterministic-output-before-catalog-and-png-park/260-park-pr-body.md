Suggested title: `ci: park PNG compare on pull_request and push`

## Summary

Adds one explicit env switch, `SIGRA_PNG_COMPARE_SKIP`, to the three PNG-comparing steps of `example_playwright_shard`. With `1`, only the `toHaveScreenshot` comparison is skipped. The axe scans, the real-login specs and every behavior assertion keep running on every pull request. Any other value, including unset, compares, so a forgotten setter fails loud instead of silently going green.

Why now: the brand adoption work that follows changes rendered admin and demo output on purpose. Until the baselines are recaptured in CI, a PNG compare on every pull request would only report that intended drift. Parking the compare at the comparison level, rather than demoting whole lanes, keeps the cheaper accessibility and behavior signal on the PR path.

## Mechanism

- `ci.yml` sets `SIGRA_PNG_COMPARE_SKIP: ${{ github.event_name == 'workflow_dispatch' && '0' || '1' }}` through `env:` on exactly three steps: `Run admin checkpoints`, `Run design gallery behavior and snapshots` and `Run demo showcase`. It is never interpolated into `run:`.
- `pull_request`, `push` and `schedule` get `1` (compare skipped). `workflow_dispatch` gets `0` (compare runs).
- `admin-checkpoints.spec.ts` and `demo-showcase.spec.ts` return before `toHaveScreenshot` when the switch is `1` and add a `png-compare` annotation naming the skipped slug. The axe scan in the checkpoint helper runs before the guard.
- `admin-design.spec.ts` calls `test.skip(...)` first in each of the 28 `@snapshot` board tests, so Playwright reports them as skipped. The untagged axe test and the behavior tests in that file are untouched.
- No `if:` predicate, job name, `.github/ci-skip-manifest.tsv` row or `spec-ownership.json` entry changed.
- Both recapture jobs, `scripts/ci/run-playwright-drift.sh` and `scripts/ci/snapshot-recapture-gate.sh` are not edited and keep comparing, because the switch is unset there.

## Where the compare still runs

`release_ref_guard` lets a manual `ci.yml` dispatch through in these shapes only, and on a dispatch the switch is `0`:

1. From a `v*` tag.
2. With `recapture_branch` set.
3. With `phase_244_final_main=true` from `refs/heads/main`, an empty `recapture_branch` and both failure probes false.
4. With `phase_246_ci_evidence=true` from the dedicated Phase 246 evidence branch, an empty `recapture_branch` and both probes false.

So PNG comparison now happens in release-tag evidence runs, final-main evidence runs and recapture runs. It does not happen on pull requests, pushes or the schedule. The recapture jobs compare because they leave the switch unset.

## What stays out of scope

- No baseline was recaptured and nothing was run with `--update-snapshots`. No PNG is in the diff.
- The impersonation-banner canary is not allowlisted. `scripts/ci/snapshot-canary-guard.sh`, which runs from `fast_checks`, is unchanged.
- `playwright-github-pages.yml` is deliberately left unedited. It does not set the switch, so it keeps comparing `admin-checkpoints.spec.ts` and will report drift once rendered output changes, until baselines are recaptured. It is not a required context and not part of `ci-gate`. A flag there was considered and declined on purpose to keep this a `ci.yml`-only workflow change.

## Guard evidence

- New `test/sigra/planning/phase_260_png_park_contract_test.exs` (17 tests) pins the switch on exactly three steps, env-only placement, the spec guards, compare-on where the switch is unset, the five required job names and the canary reference. It uses planted-source controls so each assertion is shown able to fail.
- The existing demotion guards stay green: the phase 230 and phase 234 contract tests, the 93 prohibition tests under `scripts/ci/prohibitions/`, and `scripts/ci/ci-demotion-observer.test.sh` (19 checks).
- A live positive control on this branch, run against the example app booted in dev mode on a macOS machine. With the switch unset or `0`, a `board:` snapshot test executes the comparison; a deliberately narrower viewport (a scratch config outside the repo, no baseline touched) makes it fail with a size mismatch. With `SIGRA_PNG_COMPARE_SKIP=1` the same test is reported skipped, and the whole design spec on the chromium project reports 28 skipped with the axe test and the behavior tests passing. The design boards happen to stay inside their pixel tolerance on that machine, which is why the control needs the narrower viewport. The checkpoint and demo lanes fail naturally against the Linux-native baselines with the switch unset (35,745 and 42,349 differing pixels) and pass with it set to `1`.

## Diff budget

6 files, 472 insertions, 1 deletion (a renamed unused parameter):

- `.github/workflows/ci.yml`: +6 (three env lines and three one-line comments)
- Three Playwright specs: +37 / -1 in total
- One contract test: +406
- `MAINTAINING.md`: one new paragraph, "PNG compare switch"

Nothing under `lib/` or `priv/` changes, so no shipped bytes move.

## Reviewer notes

- Merge with squash. The branch carries RED/GREEN test-first commit pairs that the squash collapses.
- Merging changes what the required `Example Playwright smoke (full lifecycle)` check measures for every later pull request: axe and behavior, not pixels. Reverting the squash commit returns the lanes to comparing on pull requests.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
