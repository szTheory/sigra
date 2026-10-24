---
phase: 244-playwright-test-1-59-1-1-62-1-alone
plan: 02
subsystem: testing
tags: [playwright, imagemagick, npm, ci, supply-chain]
requires:
  - phase: 244
    provides: baseline-only capture workflow and inventory receipt from plan 244-01
provides:
  - Exact, fail-closed decoded-pixel and path-inventory comparison
  - Isolated @playwright/test 1.62.1 candidate lock and cache-key checks
affects: [phase-244 measurement, playwright-ci]
actuals:
  tokens: 18296
  tasks: 3
  commits: 6
plan_head_before: f5a4bd060fd24a0f23cf861c00ed692ae6c4c8ac
commits: 6
tech-stack:
  added: [@playwright/test 1.62.1, ImageMagick package pin]
  patterns: [complete tracked image inventory validation, strict comparator identity and metric parsing]
key-files:
  created: [.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/deferred-items.md]
  modified:
    - scripts/ci/measure-playwright-drift.mjs
    - scripts/ci/measure-playwright-drift.test.mjs
    - scripts/ci/playwright-cache-key-guard.sh
    - scripts/ci/playwright-cache-key-guard.test.sh
    - scripts/ci/run-playwright-drift.sh
    - test/example/priv/playwright/package.json
    - test/example/priv/playwright/package-lock.json
    - .github/workflows/ci.yml
    - .github/workflows/phase-244-playwright-measure.yml
key-decisions:
  - "Use pinned Ubuntu ImageMagick package 8:6.9.12.98+dfsg1-5.2build2 and reject a different package identity."
  - "Keep 1.62.1 isolated to the example Playwright test-tooling candidate and update each existing versioned browser cache key."
  - "Proceed past the package gate only after the refreshed npm metadata, tarball digest, provenance, and official release identity agreed."
patterns-established:
  - "Comparator receipts include expected inventory count/hash, both render inventories, per-image dimensions, changed-pixel result, and explicit missing/extra paths."
  - "The cache guard enumerates every chromium and chromium-webkit versioned key and checks each against the lockfile."
requirements-completed: [QUEUE-02]
coverage:
  - id: D1
    description: Exact decoded-pixel verdict rejects dimension, inventory, comparator, and metric uncertainty.
    requirement: QUEUE-02
    verification:
      - kind: unit
        ref: "node --test scripts/ci/measure-playwright-drift.test.mjs (12 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: Playwright 1.62.1 package identity passed the refreshed supply-chain legitimacy gate before installation.
    requirement: QUEUE-02
    verification:
      - kind: other
        ref: "npm registry metadata + tarball SHA-512 + npm provenance + Microsoft release v1.62.1"
        status: pass
    human_judgment: false
  - id: D3
    description: Candidate package trio resolves to 1.62.1 and both browser cache-key families remain guarded.
    requirement: QUEUE-02
    verification:
      - kind: unit
        ref: "bash scripts/ci/playwright-cache-key-guard.test.sh"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/playwright-cache-key-guard.sh && npm --prefix test/example/priv/playwright ls @playwright/test playwright playwright-core --all"
        status: pass
    human_judgment: false
duration: 31min
completed: 2026-09-26
status: complete
---

# Phase 244 Plan 02: Exact Comparator and Isolated Playwright Candidate Summary

**Full-inventory pixel comparison now fails closed on differences or uncertainty, while the isolated Playwright candidate and all five browser cache keys resolve to 1.62.1.**

## Performance

- **Duration:** 31 min
- **Started:** 2026-09-26T12:13:22Z
- **Completed:** 2026-09-26T12:44:35Z
- **Tasks:** 3
- **Files modified:** 10, including the deferred issue record

## Accomplishments

- Extended the comparator receipt to record the tracked inventory count and SHA-256, actual render path sets, missing/extra paths, both decoded dimensions, per-image outcome, changed-pixel total, raw comparator diagnostics, and a schema version.
- Added hermetic generated-PNG coverage for equal pixels, a changed pixel, dimension mismatch, missing and extra paths, malformed AE output, and a missing comparator. ImageMagick is pinned to Ubuntu package `8:6.9.12.98+dfsg1-5.2build2`; the measurement script checks the installed package identity and records it in the receipt.
- Upgraded only the example Playwright test-tooling package to exact `1.62.1`. The resolved `@playwright/test`, `playwright`, and `playwright-core` versions agree, and all five existing cache keys now use `1.62.1`.
- Expanded the cache guard to require and validate every chromium-only and chromium-webkit key. Negative fixtures cover stale or absent keys in either family.

## Supply-Chain Gate Evidence

- Refreshed `npm view @playwright/test@1.62.1 version dist.tarball dist.integrity dist.attestations --json` returned version `1.62.1`, tarball `https://registry.npmjs.org/@playwright/test/-/test-1.62.1.tgz`, integrity `sha512-DTcUc8qii+cpHvtOwggMtBRMjKZHXYWdw8syRYu2vtzuq4Wxphqq4NfCs5Zt44L6mA8rfDfj+PHnxFc/FeK6mQ==`, and publish attestations.
- Downloaded the registry tarball and recomputed its SHA-512; it matched the registry integrity exactly.
- The SLSA provenance subject digest matched that tarball and identified `https://github.com/microsoft/playwright`, workflow `.github/workflows/publish_release.yml`, ref `refs/tags/v1.62.1`, and commit `26a9e470a7b3c7822084b09fb7f13902c5f37b51`. npm listed the publisher as GitHub Actions OIDC.
- Microsoft's official v1.62.1 release page reports commit `26a9e47` with a verified signature. The fresh verdict was **OK**, so the candidate install proceeded after the gate was recorded.

## Task Commits

1. **Task 1 RED: comparator contract tests** — `5d27a884` (`test`)
2. **Task 1 GREEN: exact pixel inventory comparator and pinned identity** — `45e7b31b` (`feat`)
3. **Task 1 fix: stop pixel comparison when inventories disagree** — `905a7c19` (`fix`)
4. **Task 3: isolated 1.62.1 candidate and cache guard** — `cffee948` (`feat`)

**Plan metadata commits:** `010a413a` (`docs: complete plan`) and `01059571` (`docs: record plan metadata hash`).

## Verification

- `node --test scripts/ci/measure-playwright-drift.test.mjs` — 12 passed.
- `bash scripts/ci/playwright-cache-key-guard.test.sh` — 8 passed.
- `bash scripts/ci/playwright-cache-key-guard.sh` — all 5 keys matched lock version `1.62.1` (2 chromium, 3 chromium-webkit).
- `npm --prefix test/example/priv/playwright ls @playwright/test playwright playwright-core --all` — all three package levels resolved to `1.62.1`.
- `git diff --check` passed; no tracked PNG changes were present.

## Files Created/Modified

- `scripts/ci/measure-playwright-drift.mjs` — full inventory, dimensions, metrics, diagnostics, and comparator identity enforcement.
- `scripts/ci/measure-playwright-drift.test.mjs` — exact-pixel and fail-closed contract tests.
- `scripts/ci/run-playwright-drift.sh` and `.github/workflows/phase-244-playwright-measure.yml` — install and verify the pinned Ubuntu comparator package.
- `test/example/priv/playwright/package.json` and `package-lock.json` — isolated exact candidate version and matching package trio.
- `.github/workflows/ci.yml` — the five matrix cache keys now match 1.62.1.
- `scripts/ci/playwright-cache-key-guard.sh` and `.test.sh` — both browser cache families are enumerated and tested.
- `deferred-items.md` — records the pre-existing `undici@7.28.0` audit finding.

## Decisions Made

- Retained the existing browser-cache strategy and advanced only its versioned keys.
- Kept the 1.62.1 change inside `test/example/priv/playwright`; no Elixir, Phoenix, generated-host, or PNG baseline files changed.
- Used the exact Ubuntu Noble ImageMagick package version for measurement and made a version mismatch fatal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Comparator output compatibility] Accepted ImageMagick's documented integer plus normalized-value AE format while retaining strict parsing.**
- **Found during:** Task 1 (exact comparator tests)
- **Issue:** The local ImageMagick 7 comparator emits `0 (0)` for exact equality, while the original parser accepted only one integer and incorrectly rejected a valid zero result.
- **Fix:** Parse the integer decision metric and syntax-check the optional normalized value; reject extra or malformed output.
- **Files modified:** `scripts/ci/measure-playwright-drift.mjs`, `scripts/ci/measure-playwright-drift.test.mjs`
- **Verification:** Generated PNG tests passed for equality, pixel change, and malformed metrics.
- **Committed in:** `45e7b31b`

**2. [Rule 2 - Comparator identity] Pinned and checked the Ubuntu ImageMagick package used by the capture workflow.**
- **Found during:** Task 1
- **Issue:** The existing workflow installed whichever ImageMagick package the Ubuntu image currently offered, so comparator identity was not fixed.
- **Fix:** Pin package version `8:6.9.12.98+dfsg1-5.2build2`; record and reject mismatched installed package metadata.
- **Source:** The [Ubuntu Noble package catalog](https://packages.ubuntu.com/noble/imagemagick) confirms that exact `imagemagick` package version.
- **Files modified:** `.github/workflows/phase-244-playwright-measure.yml`, `scripts/ci/run-playwright-drift.sh`, `scripts/ci/measure-playwright-drift.mjs`
- **Verification:** Focused comparator suite passed; the runtime enforces the package version before a measurement receipt can be accepted.
- **Committed in:** `45e7b31b`

**3. [Rule 1 - Fail-closed inventory handling] Stop before pixel comparison when either full render inventory differs from the tracked set.**
- **Found during:** Task 1 final review
- **Issue:** Missing/extra paths were recorded, but the comparator still processed the remaining expected images.
- **Fix:** Mark expected paths inconclusive and skip all pixel comparisons until both render inventories match the source tree; added a test comparator that fails if invoked.
- **Files modified:** `scripts/ci/measure-playwright-drift.mjs`, `scripts/ci/measure-playwright-drift.test.mjs`
- **Verification:** `node --test scripts/ci/measure-playwright-drift.test.mjs` — 12 passed.
- **Committed in:** `905a7c19`

**Total deviations:** 3 auto-fixed (Rule 1: 2, Rule 2: 1).
**Impact on plan:** All three changes close comparator correctness, inventory ordering, and identity gaps required by the plan's exact-pixel trust boundary.

## Issues Encountered

- Candidate installation reported one high-severity registry audit finding in `undici@7.28.0`. Comparison with the base lockfile confirmed it was already present and unchanged, so it was recorded as an out-of-scope deferred item rather than broadening this Playwright-only candidate.
- The Git index in the normal checkout is read-only. Task commits were created in `/private/tmp/sigra-phase244-plan02-clone` on the existing phase branch using only plan-owned files; the code and evidence remain in the normal checkout for review.
- No candidate CI measurement was dispatched in this plan; the focused local verification commands above passed.

## Next Phase Readiness

- The isolated package/cache candidate is ready for the next authorized paired CI measurement. The comparator rejects missing, extra, dimension-mismatched, changed, malformed, or unmeasurable image results as non-zero-drift outcomes.
- The pre-existing `undici@7.28.0` advisory remains open in `deferred-items.md` for separate dependency triage.

## Self-Check: PASSED

- Summary and deferred issue files exist in the phase directory.
- All four task commits are present in the disposable clone's phase branch.
- No tracked Playwright PNG files were changed.

---
*Phase: 244-playwright-test-1-59-1-1-62-1-alone*
*Completed: 2026-09-26*
