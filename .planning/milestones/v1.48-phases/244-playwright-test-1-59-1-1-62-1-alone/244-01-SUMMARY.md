# Phase 244 Plan 01 Summary

## Status

Complete. The isolated Ubuntu measurement route has a successful one-image tracer receipt and a full-corpus capture whose rendered path sets exactly match the 115 tracked PNGs at the measured source SHA.

## Evidence

- Tracer run [36216570816](https://github.com/szTheory/sigra/actions/runs/36216570816), source SHA `f5a4bd060fd24a0f23cf861c00ed692ae6c4c8ac`: one tracked PNG, Playwright 1.59.1 on both sides, Chromium revision 1217 on both sides, zero changed pixels, successful workflow.
- Full capture run [36220505738](https://github.com/szTheory/sigra/actions/runs/36220505738), source SHA `abe9391bbc171b22a28fec4f69e073c272361c90`: 115/115 tracked paths rendered on both sides, 115 comparison results, no missing/extra paths or diagnostics. Inventory-only verification passed with `node scripts/ci/measure-playwright-drift.mjs verify --manifest <artifact>/measurement.json --inventory-only --source-sha abe9391bbc171b22a28fec4f69e073c272361c90`.
- The full-capture manifest reports `drift` across 25 paths. Inspection shows generated IDs and runtime timestamps in user-detail/session screens; this is recorded as same-version capture variability, not as zero drift. The workflow run concluded failure because the original verifier incorrectly made inventory-only verification require zero changed pixels. The verifier now keeps inventory validation independent from the exact-pixel verdict; exact verification still rejects any changed pixel.
- The deterministic manifest suite passes 8/8 tests. `node --check`, `bash -n`, `actionlint`, and `git diff --check` also pass.
- No canonical tracked PNG was modified. Full renders and diff images are preserved in the run artifact.

## Workflow changes

Worktree isolation is disabled in the project GSD config. The scoped read-only measurement workflow now supports tracer/full scopes, initializes the BEAM toolchain once per job, and installs Chromium plus WebKit and their system dependencies in the isolated full-capture browser path. The workflow and related guard changes merged through PRs [#276](https://github.com/szTheory/sigra/pull/276), [#277](https://github.com/szTheory/sigra/pull/277), [#278](https://github.com/szTheory/sigra/pull/278), [#279](https://github.com/szTheory/sigra/pull/279), [#280](https://github.com/szTheory/sigra/pull/280), [#281](https://github.com/szTheory/sigra/pull/281), and [#282](https://github.com/szTheory/sigra/pull/282).

## Handoff

Continue with `$gsd-execute-phase 244`. Plan 244-01 is recorded complete; the next plan is 244-02, whose package-legitimacy step is a blocking human checkpoint if the fresh supply-chain audit remains `[SUS]` or `[ASSUMED]`.
