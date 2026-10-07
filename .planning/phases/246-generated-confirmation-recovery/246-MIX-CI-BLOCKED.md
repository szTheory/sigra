# Phase 246 Plan 03: Required CI Blocker

> **Resolved:** the diagnostic below records the pre-dispatch failure state. The
> four contract failures were repaired, and exact-source required CI completed
> successfully at `2232272d77a4ebfccafe43ddec877bf3ad6195a7`. See
> `246-CI-EVIDENCE.json` for the successful run and job receipts.

At committed source `fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a`, a clean detached checkout ran `MIX_ENV=test mix ci` after `mix clean`. It exited 2: **33 doctests, 3 properties, 2623 tests, 4 failures, 12 skips, 22 exclusions**. The later dependency-off guard passed **65 tests, 0 failures**. Complete failure messages, stack locations, seed, source SHA, and the log fingerprint are retained in `246-MIX-CI-FAILURES.json`.

| Failing contract | Observed diagnostic | Scope |
|---|---|---|
| Phase 232 Playwright economics | The committed workflow has zero matches for its expected `playwright-chromium-1.62.1-v3` cache marker. | Workflow/package updates already dirty at phase entry are separate inherited work. |
| Phase 236 evidence provenance | Guard reads an absent `.planning/phases/236-…/236-EVIDENCE.md` path after archival. | Historical evidence/path maintenance. |
| Phase 242 install guidance | Committed README lacks the supported install tuple. | Existing dirty public documentation was preserved. |
| Phase 242 safety closeout | Guard reads an absent `.planning/phases/242-…/242-SAFETY-CLOSEOUT.md` path after archival. | Historical evidence/path maintenance; the phase's test received formatting-only changes. |

The first 17-failure run included phase-induced failures, so its initial classification as entirely unrelated was inaccurate. Follow-up work repaired the optional-scope installer drift guard and registered the new browser spec with an exact harness mapping. Live ownership now resides in `test/example/priv/playwright/spec-ownership.json`; the archived Phase 234 inventory retains its original captured bytes, preserving Phase 235 provenance. A fresh compile also removed stale Threadline dependency-off output, and the nested sandbox fixtures passed when permitted to run outside the enclosing process sandbox. The final four failures remain outside the confirmation implementation.

## Local proof retained

- Final-source focused suite: **236 tests, 0 failures**.
- Fresh-host installer: **8 tests, 0 failures**, generated from `6f10be8504075d3b8a676f6ef1b064dd2783387b`. `git diff` proves its `lib/`, `priv/`, confirmation probe, and installer runner are identical to the final source.
- Final-source generated-host full browser command: **8 admin tests passed, 1 planned skip; confirmation 1 passed; revoked-admin recheck 1 passed**. The existing admin branding navigation timed out on LiveView readiness once; its single retry passed and the first failure remains in the receipt.
- The committed Playwright version is **1.59.1**. Its matching Chromium browser was installed after an initial launch-prerequisite failure.
- Re-review: **19 files, 0 findings**. WR-01 is fixed and retained in the disposition ledger.
- The example app's additional `mix precommit` fails its warnings-as-errors compile on an existing `/dev/mailbox` test-environment route warning at `settings_live.ex:133`. Its complete log fingerprint is retained in the receipt.

At the time this diagnostic was first written, no branch had been pushed and no GitHub workflow had been dispatched. That state was superseded after the four failures were repaired. CI run [37558299754](https://github.com/szTheory/sigra/actions/runs/37558299754) completed successfully for exact source SHA `2232272d77a4ebfccafe43ddec877bf3ad6195a7`: `ci-gate`, `install_smoke`, `generated_admin_playwright_smoke`, all five example Playwright shards, the full Playwright aggregate, and the admin-eval render/probe all passed. The local macOS `mix ci` limitation remains recorded separately and was not waived or presented as a pass. Plan 246-03's required-CI blocker is resolved; final phase verification is still a separate step.

Resume `$gsd-execute-phase 246` to consume this actual required run, finish Phase 246 verification, and then continue the already-planned Phase 247 execution. Historical milestone phases remain untouched.
