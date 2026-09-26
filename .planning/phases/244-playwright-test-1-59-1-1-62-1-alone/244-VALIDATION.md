---
phase: "244"
slug: "playwright-test-1-59-1-1-62-1-alone"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-26"
updated: "2026-09-26"
---

# Phase 244 — Validation Strategy

> Every task from Plans 01–08 is mapped below to an executable check or to a retained external CI/package attestation. The measurement found real drift; validation passing means the fail-closed decision and evidence are verified, not that the package bump is merge-eligible.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node.js built-in test runner; shell contract fixtures; Playwright CI consumers |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Comparator command** | `node --test scripts/ci/measure-playwright-drift.test.mjs` |
| **Cache contract command** | `bash scripts/ci/playwright-cache-key-guard.test.sh && bash scripts/ci/playwright-cache-key-guard.sh` |
| **Final receipt command** | `bash scripts/ci/capture-phase-244-final-main.test.sh` and the collector's offline `verify` mode |
| **External evidence** | GitHub Actions runs and npm registry signatures/attestations listed per task below |

## Per-Task Verification Map

| Task ID | Requirement / behavior | Automated validation and evidence | Current result |
|---------|------------------------|-----------------------------------|----------------|
| 244-01-01 | QUEUE-02: one tracked image is rendered and compared on Ubuntu; identity binds workflow, SHA, package and browser. | Tracer run `36216570816`, source `f5a4bd060fd24a0f23cf861c00ed692ae6c4c8ac`; retained one-path manifest reports zero changed pixels and successful run. | **PASS — recorded CI evidence** |
| 244-01-02 | QUEUE-02: full baseline inventory is rendered without changing canonical PNGs; missing/extra paths remain inconclusive. | Full-capture run `36220505738` records 115/115 paths at `abe9391bbc171b22a28fec4f69e073c272361c90`; inventory-only verification passed. The later paired run `36262576391` independently confirms 115 paths. `node --test scripts/ci/measure-playwright-drift.test.mjs` exercises incomplete/extra inventory failures. | **PASS — inventory verified**; original run concluded failure because its then-current exact-drift verifier also rejected measured drift. |
| 244-02-01 | QUEUE-02 / D1: equality, pixel drift, dimensions, path inventory, comparator errors and malformed metrics fail or pass precisely. | `node --test scripts/ci/measure-playwright-drift.test.mjs` — **15 passed, 0 failed**. Includes identical pixels, one-pixel change, dimensions, missing/extra/traversal paths, unavailable comparator and malformed output. | **PASS — 15/15** |
| 244-02-02 | QUEUE-02 / D2: candidate package identity, registry integrity, publisher provenance and official release identity are checked before install. | `npm_config_cache=/private/tmp/phase244-npm-cache npm view @playwright/test@1.62.1 version dist.tarball dist.integrity --json`; `npm_config_cache=/private/tmp/phase244-npm-cache npm audit signatures --prefix test/example/priv/playwright`. Metadata reports 1.62.1 and integrity `sha512-DTcUc8qii+cpHvtOwggMtBRMjKZHXYWdw8syRYu2vtzuq4Wxphqq4NfCs5Zt44L6mA8rfDfj+PHnxFc/FeK6mQ==`; npm reports 51 verified registry signatures and 11 verified attestations. Summary records tarball digest equality and Microsoft v1.62.1 signed release identity. | **PASS — live registry/signature check and recorded provenance audit** |
| 244-02-03 | QUEUE-02 / D3: all five cache keys and both browser families match the 1.62.1 lock; package trio resolves consistently. | `bash scripts/ci/playwright-cache-key-guard.test.sh && bash scripts/ci/playwright-cache-key-guard.sh && npm --prefix test/example/priv/playwright ls @playwright/test playwright playwright-core --all` — **8/8 fixtures pass**, five keys match, and all three Playwright packages resolve to 1.62.1. | **PASS — scoped trio verified**. `npm ls` also prints an unrelated existing `@axe-core/playwright` range mismatch; it does not change the tested Playwright trio. |
| 244-03-01 | QUEUE-02: paired same-SHA Ubuntu capture uses verified package/browser identities and fails closed on any drift or uncertainty. | `node scripts/ci/measure-playwright-drift.mjs verify --manifest .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json --source-sha 980812cba598781b0b95a763562aaafbd093afb8 --validate-recorded-outcome`; run `36262576391`. | **PASS — valid evidence, 115 paths, drift, merge_eligible=false**. The workflow's nonzero conclusion represents the intended drift verdict. |
| 244-03-02 | QUEUE-02: measurement decision and current PR identity are durably recorded; stale checks do not become visual proof. | The same manifest verifier above; retained run `36262573493` establishes candidate-SHA `fast_checks` and both cache guards. | **PASS — recorded decision and targeted CI**. Full PR CI separately failed at the out-of-scope `admin-audit.spec.ts:77` URL assertion. |
| 244-04-01 | QUEUE-02: restore only a live candidate, otherwise defer; the closed/missing-head PR must not be reopened. | `gh pr view 213 --repo szTheory/sigra --json number,state,mergedAt,headRefName,headRefOid,mergeable`. Live result: CLOSED, unmerged, head ref absent from remote (as recorded), `CONFLICTING`; default defer selected. | **PASS — defer route observed** |
| 244-04-02 | QUEUE-02: evidence decision matches live PR state and the measured drift; deferred todo is actionable. | `node scripts/ci/measure-playwright-drift.mjs verify --manifest .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json --source-sha 980812cba598781b0b95a763562aaafbd093afb8 --validate-recorded-outcome`; live `gh pr view 213` state assertion from the plan's `jq -e` contract. | **PASS — JSON verifier passed; deferred evidence agrees with CLOSED/unmerged PR** |
| 244-05-01 | QUEUE-02 / D1: collector rejects stale, missing, duplicate, skipped, malformed or docs-only job/step receipts. | `bash scripts/ci/capture-phase-244-final-main.test.sh` — success plus **10 fail-closed fixtures** and embedded-receipt verification. | **PASS — fixture suite green** |
| 244-05-02 | QUEUE-02 / D2: one post-disposition exact-main run proves all required consumers and `ci-gate` individually successful, with main unchanged. | `bash scripts/ci/capture-phase-244-final-main.sh verify --receipt .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json --main-sha 5a00b90d2314bc93f27aec4090b5928018743d1b`; run `36266022766`. | **PASS — receipt contract**; eight required jobs and seven consumer/browser steps passed at main SHA `5a00b90d2314bc93f27aec4090b5928018743d1b`. |
| 244-06-01 | QUEUE-02 / SEC-244-06: structured workflow-run and artifact API identity binds the exact raw manifest bytes and digest. | `node --test scripts/ci/measure-playwright-drift.test.mjs` — provenance fixtures; live run `36262576391` and artifact provenance retained in `244-PLAYWRIGHT-EVIDENCE.json`. | **PASS — 53/53 suite**; missing, null, string, and true artifact-expiry values are rejected in API and persisted evidence. |
| 244-06-02 | QUEUE-02 / SEC-244-09: merge eligibility requires zero drift, current authorized PR/head/base, complete nonempty policy, and exact successful checks. | `node --test scripts/ci/measure-playwright-drift.test.mjs`; `node scripts/ci/measure-playwright-drift.mjs verify --manifest .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json --source-sha 980812cba598781b0b95a763562aaafbd093afb8 --validate-recorded-outcome`. | **PASS — 53/53 suite**; wrong workflow repository/ref/SHA and absent SHA evidence fail closed. Captured policy has no workflow rules; drift and closed PR remain ineligible. |
| 244-07-01 | QUEUE-02 / SEC-244-07: paired install roots permit only the expected package manifest/lock transform and reject source mutations. | `bash scripts/ci/verify-playwright-source-tree.test.sh`; `node --test scripts/ci/verify-playwright-source-tree.test.mjs`. | **PASS — hermetic positive/negative fixtures**. |
| 244-07-02 | QUEUE-02 / SEC-244-07: every install root is checked after `npm ci` and before browser setup/capture, against one measured-SHA reference. | Same source-tree fixture commands; shell runner wiring assertions in the fixture; `bash -n scripts/ci/run-playwright-drift.sh`. | **PASS — guards wired at install boundaries and syntax valid**. |
| 244-08-01 | QUEUE-02 / SEC-244-13: final-main collection records one 60-second watcher after quota preflight and stops without retry on 403/429. | `bash scripts/ci/capture-phase-244-final-main.test.sh`; `node --test scripts/ci/capture-phase-244-final-main.test.mjs`; embedded watcher receipt in `244-PLAYWRIGHT-EVIDENCE.json`. | **PASS — quota, watcher, hard-stop and receipt fixtures**; run `36266022766` retained. |
| 244-08-02 | QUEUE-02: complete local repository gate passes at final gap-code HEAD after Plans 06–08. | `244-POST-REVIEW-MIX-CI-RESULT.md` and full output `244-POST-REVIEW-MIX-CI-LOG.txt`; command `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci`, HEAD `ba4169fe1337f6c96695d00c3e3fb608fb1276b9`. | **PASS — retry exit 0**; the prior sandbox attempt exited 2 and the permitted retry passed. |

## Measurement and Disposition

- Paired Ubuntu run `36262576391` captured the complete 115-image inventory. It found **30 changed images and 380,825 changed pixels**. The manifest is valid and correctly remains `drift` / `merge_eligible: false`.
- PR #213 is CLOSED and unmerged. Evidence records a defer with a pending follow-up todo. The live read above agrees with that disposition.
- Exact-main run `36266022766` passed after disposition. The offline receipt validator confirms its recorded required consumers against the unchanged main SHA.
- QUEUE-02's descriptor-less edge probe remains explicitly `unclassified` / `unresolved` (`applicable: 1`, `resolved: 0`, `unresolved: 1`). This is intentionally unresolved product evidence; it is not counted as a passed behavior or silently waived.

## Sampling and Sign-Off

- All **17 tasks** in Plans 01–08 have a verification mapping above. Existing focused suites exercise the planned negative behaviors; Plans 06–08 added test coverage during phase execution, and this audit needed no additional test files.
- The successful comparator, cache, receipt, measurement and final-main checks were run during this audit. External CI/package claims are linked to their retained run/evidence identities.
- No three consecutive tasks are left without automated validation. No watch-mode flags are used.
- Human visual judgment cannot override the measured drift or make the candidate merge-eligible.

**Nyquist status:** compliant for the planned fail-closed measurement, provenance, disposition, and receipt behaviors across Plans 01–08. QUEUE-02's spec-less edge remains explicitly unresolved as described above; it is disclosed and is not asserted as a passed behavior.
