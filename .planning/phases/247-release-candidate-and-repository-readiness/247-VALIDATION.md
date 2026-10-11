---
phase: "247"
slug: "release-candidate-and-repository-readiness"
status: validated
nyquist_compliant: false
wave_0_complete: true
created: "2026-10-06"
audited: "2026-10-11"
---

# Phase 247 — Validation Strategy

> Behavioral coverage now maps all 11 plans. The validation gates reject stale candidate evidence, but the final READY-01/READY-02 proof is still incomplete: the persisted dry-run receipt names `d76d7f23`, while the repaired candidate result names `0e773d36`. The latest independent phase report remains `gaps_found`.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Frameworks** | Node.js built-in `node:test`; hermetic Bash fixtures for the trusted Hex helper; Playwright for LiveView browser flows; `actionlint` for the workflow contract |
| **Focused readiness command** | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` |
| **Readiness result** | 26 passed, 0 failed after adding the source-specific stale-receipt regression test |
| **Trusted helper command** | `bash scripts/ci/phase-247-hex-dry-run.test.sh` |
| **Trusted helper result** | The current workspace copy reports 14 fixture cases, but it pins the superseded `563f411` source. A separate audit checkout using the helper/workflow/fixture files from live main `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97` reports 25 fixtures plus the receipt timestamp assertion, all passing. |
| **Workflow lint** | `actionlint .github/workflows/phase-247-hex-dry-run.yml` passed against the live-main workflow snapshot in the same isolated audit checkout. The workspace copy is older. |
| **Browser configuration** | Playwright `1.59.1`, zero retries, mobile WebKit registration flow. Local WebKit startup is blocked by the diagnosed AppKit abort; exact-head CI is the browser proof. |
| **Exact candidate CI** | Run `37819712610`, attempt 1, candidate `0e773d3614a242e4fbcdd34c418ecb8a307703d6`; the mobile WebKit organization lane and `ci-gate` passed. |

## Source Identity and Evidence Reconciliation

| Evidence | Recorded identity | Audit result |
|----------|-------------------|--------------|
| Repaired Playwright candidate | `0e773d3614a242e4fbcdd34c418ecb8a307703d6`, reviewed base `d135cbce343947499a0810736c500ef5f1cb5c32` | The immutable candidate contains the `Strong` feedback wait in both signup paths. Exact-head run `37819712610` passed. |
| Protected evidence rebind | PR #297, pre-merge head `9d07f211c7a30afd97ae2b6e762f65b683e93a7b`, merge `51be73415cf6de5531d3fb4c91ec3caf2c7544b6` | Plan 10 records successful required CI run `37822383917`, attempt 2; the merge changed the four approved evidence paths and retained manifest blob `12daf4f704bbc2d4aa136d0ef678e64abce38aeb`. The reviewed-base diff is `85020173c21fded708030b7422bb00ddd1510a073010122e6cf5364527772ec4` (9,906 bytes). |
| Persisted dry-run receipt and baseline in this checkout | Receipt run `37803817504`; candidate `d76d7f2306f6099063a80a420d2d8a4e04c7785f`; baseline digest `d7cbfeddd55bc0528738f89b82377379e55a73464f2c174217af31410625ac5e` (8,372 bytes) | Stale for the repaired `0e773d36` candidate. The source-specific regression test confirms the final validator rejects this tuple for that candidate. |
| Plan 11 summary claim | Dry-run run `37824714823`; final validator reported ready | Not independently corroborated by the persisted receipt or readiness ledger in this checkout. The later reconciliation in `247-VERIFICATION.md` records `gaps_found`, a receipt tuple mismatch, and incomplete source/inventory joins. |
| Live repository at audit time | PR #224 closed/merged; PR head `64071b81a131fcfe4068a91d4814da478f13b084`, merge `9e80cb78d6374b1ed4074d5fef6b613fee879dca`; main `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97` | This is later than the Phase 247 candidate verification. Do not describe PR #224 as currently open or use the later merge head as a substitute for the phase-time candidate. |

The local validation checkout is clean at `e46dd6f22959bafaa2a084cddcd98a989a3bcabf`, but several tracked copies of the workflow, helper, test fixture, baseline, and receipt predate the final rebind. Live main contains the fixed `0e773d36` workflow/helper. No implementation files were changed during this audit.

## Per-Task Verification Map

| Task ID | Requirement | Behavior under test | Test type | Command / evidence | Result |
|---------|-------------|----------------------|-----------|--------------------|--------|
| 247-01-01 | READY-02 | Reject omitted PRs and duplicate path keys; accept fresh explicit empty sets; retain the immutable entry snapshot. | Unit/contract | Readiness suite: `rejects an omitted live pull request`, `rejects duplicate kind-plus-path identities`, `accepts explicitly empty populations`, and snapshot tests. | **green** — covered by 26 passing tests. |
| 247-01-02 | READY-02 | Candidate checkout is clean and pinned to reviewed source with Phase 246 evidence. | Unit/contract + source evidence | Readiness suite: `accepts only a clean candidate pinned to reviewed source with exact Phase 246 evidence`; Plan 01 ledger and CI records. | **green** — behavior and historical source proof are recorded. |
| 247-02-01 | READY-01, READY-02 | Reject mismatched PR/base/main/tested SHAs, unreviewed non-fast-forward movement, and invalid promotion proof. | Unit/contract + CI | Readiness suite candidate/promotion fixtures; Plan 06 exact candidate run `37819712610` supersedes the older `563f411` candidate CI. | **green** — fixture behavior passes; older source receipts are historical. |
| 247-02-02 | READY-01 | Require aligned release metadata and a versioned summary; reject misplaced Unreleased notes. | Unit/contract + docs CI | Readiness suite: version/source-ref and misplaced-summary cases; Plan 06 exact-head docs CI at `0e773d36`. | **green** — covered at the repaired candidate. |
| 247-03-01 | READY-01 | README → v1.6 guide → 1.6.0 changelog route and source-backed adopter claims. | Contract + docs CI | Readiness suite guide contract; candidate tree at `0e773d36`; exact-head CI `37819712610`. | **green** — candidate source and docs job passed; local checkout copy is older. |
| 247-04-01 | READY-01, READY-02 | Reject missing dry-run evidence, changed source, broken links, incomplete dispositions, and unresolved severe review findings. | Unit/contract + live ledger | Readiness suite final-readiness fixtures; new recorded-receipt regression; current independent report `247-VERIFICATION.md`. | **partial** — rejection behavior passes, but the persisted final ledger is stale and the independent report is `gaps_found`. |
| 247-04-package | READY-01 | Inspect unpacked package metadata, README, and CHANGELOG for version 1.6.0. | Package integration | Plan 04/11 package-inspection records; final source identity must be reconciled with the current receipt before claiming readiness. | **partial** — historical package evidence exists; no current source-bound final ledger joins it to the repaired candidate. |
| 247-04-docs | READY-01 | Build ExDoc without warnings at the candidate's exact dependency versions. | Package integration + CI | Plan 06 exact-head docs job in run `37819712610`; `Library tests shard` executes the docs build. | **green** — exact candidate CI docs step passed. |
| 247-04-dry-run | READY-01 | Authenticated Hex dry run validates the exact candidate without publishing. | Protected workflow integration | Persisted receipt `247-HEX-DRY-RUN-RECEIPT.json`; stale-receipt regression test. | **blocked** — saved receipt is run `37803817504` for `d76d7f23`; Plan 11's claimed run `37824714823` is not represented by the saved receipt. |
| 247-05-01 | READY-01, READY-02 | Fix the trusted helper's fixed-source, baseline, authentication, release-absence, and receipt contracts. | Hermetic integration | Current-main helper/fixture snapshot from `4ff6c50`; `bash scripts/ci/phase-247-hex-dry-run.test.sh` in `/private/tmp/sigra-phase247-fixture-live`. | **green** — 25 adversarial fixtures and receipt-timestamp assertion passed on the `0e773d36` source pin. |
| 247-05-02 | READY-01, READY-02 | Land only the evidence workflow/helper/test/baseline paths through protected CI and verify the preserved diff. | Integration | Plan 10 PR #297; run `37822383917` attempt 2; merge `51be734`; exact four-path diff and manifest blob recorded. | **green** — the rebind and immutable baseline checks are recorded. |
| 247-05-03 | READY-01 | Run the authenticated non-publishing command and retain a safe exact-source receipt. | Protected workflow integration | Plan 11 summary claims run `37824714823`; saved receipt and baseline remain bound to `d76d7f23`. | **blocked** — current matching receipt is absent; no pass is inferred from the summary claim. |
| 247-05-04 | READY-01, READY-02 | Consume the receipt, independently recompute the baseline, and refresh final readiness. | Unit/contract + live validator | Readiness suite: 26 passed; source-specific stale receipt case passes. Current `247-RELEASE-READINESS.json` and `247-VERIFICATION.md` remain mismatched. | **partial** — stale evidence is rejected; a valid final tuple is not present. |
| 247-06-01 | READY-01, READY-02 | Candidate docs are present in the real PR tree; both signup paths wait for rendered `Strong` before role-based submission. | Playwright integration | `git show 0e773d36:test/example/priv/playwright/tests/organizations.spec.ts`; CI run `37819712610`, mobile WebKit job. | **green** — both waits exist at the immutable candidate and exact-head mobile CI passed; local AppKit abort is not browser proof. |
| 247-06-02 | READY-01, READY-02 | Refresh candidate source review and readiness ledger only after exact-head CI and source checks. | Contract + integration | Candidate CI run `37819712610`; Plan 06 summary; final reconciliation in `247-VERIFICATION.md`. | **partial** — exact candidate CI passed, but later final readiness evidence does not join to that source. |
| 247-07-01 | READY-01, READY-02 | Rebind helper/workflow to only the reviewed source and recompute the raw diff digest/byte count. | Hermetic integration + lint | Live-main fixture suite: 25 cases; `actionlint`; baseline digest `85020173…`, 9,906 bytes. | **green** — current-main helper fixtures and workflow lint pass. |
| 247-07-02 | READY-01, READY-02 | Protected evidence merge changes exactly four allowed paths and preserves the baseline blob. | Integration | Final rebind evidence PR #297, run `37822383917` attempt 2, merge `51be734`, manifest blob `12daf4f7…`. | **green** — identities and four-path advance are recorded in Plan 10. |
| 247-08-01 | READY-01 | Receipt helper receives only boolean key-presence evidence; the Hex value stays in the dry-run step. | Hermetic workflow contract | Live-main helper fixture suite: 25 cases; `actionlint` on workflow from main `4ff6c50`. | **green** — source-bound contract fixtures and lint pass. |
| 247-08-1b | READY-01, READY-02 | Dirty source check fails closed and reports paths without file contents. | Hermetic integration | Live-main helper fixture suite: 25 cases, including dirty-checkout diagnostics. | **green** — path-only failure behavior is covered. |
| 247-08-02 | READY-01 | Produce one authenticated exact-source dry-run receipt after evidence merge. | Protected workflow integration | Saved receipt `37803817504` is for `d76d7f23`; Plan 11 claims `37824714823` for the repaired source. | **blocked** — the saved receipt does not prove the repaired candidate. |
| 247-08-03 | READY-01, READY-02 | Final validator accepts only the current source, receipt, CI, and complete inventory tuple. | Unit/contract + live ledger | Readiness suite: 26 passed; final live report `247-VERIFICATION.md`. | **partial** — negative stale-tuple behavior passes; current positive final-readiness tuple remains unproven. |
| 247-09-01 | READY-01, READY-02 | Signup waits for LiveView's visible validation result before a real submit. | Playwright integration | Candidate commit `0e773d36`; local diagnostics `247-09-LOCAL-RESULT.json`; CI run `37819712610`. | **green** — exact-head mobile WebKit CI passed; local startup was blocked before page creation by AppKit. |
| 247-09-02 | READY-01, READY-02 | Require explicit authorization before pushing the test-only candidate change. | Human checkpoint | Plan 09 summary preserves that approval was requested but not the verbatim response; later verification reports no immutable approval for the proposed recovery tuple. | **escalated** — approval cannot be inferred from green CI. |
| 247-09-03 | READY-01, READY-02 | Prove the approved test-only commit on the exact release PR head. | Exact-head CI | Run `37819712610`, attempt 1, candidate `0e773d36`; mobile WebKit and `ci-gate` succeeded. | **green** — CI evidence is source-bound to the phase-time candidate. |
| 247-10-01 | READY-01, READY-02 | Record the exact candidate/base/main tuple and enumerate stale artifacts before rebind. | Read-only contract | `247-10-REBIND-PROPOSAL.json`; Plan 10 summary records the proposal and tuple. | **green** — proposal artifact exists; it does not itself authorize execution. |
| 247-10-02 | READY-01, READY-02 | Obtain separate approval for one evidence rebind and downstream recovery. | Human checkpoint | Plan 10 summary says approved; later canonical reconciliation records approval pending and no immutable approval artifact. | **escalated** — source-bound approval cannot be proven from the retained records. |
| 247-10-03 | READY-01, READY-02 | Bind the approved source through one protected four-path evidence PR and verify the surviving manifest blob. | Hermetic + protected integration | Current-main 25-fixture suite; actionlint; PR #297 run `37822383917`, merge `51be734`; source identities in Plan 10 summary. | **partial** — rebind behavior is verified, but the later independent report does not accept the approval/evidence join. |
| 247-11-01 | READY-01 | Produce an authenticated, non-publishing receipt for the repaired candidate and exact baseline. | Protected workflow integration | Plan 11 summary claims run `37824714823`; saved receipt remains run `37803817504` / candidate `d76d7f23`. | **blocked** — no matching persisted receipt. |
| 247-11-02 | READY-01, READY-02 | Final validator accepts one current candidate, CI, receipt, baseline, and complete inventory. | Unit/contract + live validator | Readiness suite: 26 passed, including `rejects the recorded historical dry-run receipt for the repaired Playwright candidate`; current ledger is still bound to `d76d7f23`. | **partial** — stale-source rejection is proven; positive final readiness is not. |
| 247-11-03 | READY-01, READY-02 | Independent verifier confirms all phase truths on the same final source. | Independent verification | Current `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md`, reconciled by Phase 250. | **blocked** — status is `gaps_found`; READY-01 and READY-02 are unsatisfied. |

## Adversarial Test Execution

```text
node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
tests 26 | pass 26 | fail 0 | skipped 0 | exit 0

Live-main helper snapshot at 4ff6c50:
bash scripts/ci/phase-247-hex-dry-run.test.sh
fixtures 25 | receipt timestamp assertion passed | exit 0

actionlint .github/workflows/phase-247-hex-dry-run.yml
exit 0 (live-main workflow snapshot)
```

The added behavioral test feeds the repaired candidate SHA from `247-09-PLAYWRIGHT-RESULT.json` and the persisted older receipt into `validateFinalReadiness`. The validator returns `final_hex_dry_run_failed`; it does not accept package-summary output or a receipt for another candidate as current proof. This covers the negative stale-source behavior. It does not convert the current final ledger into a pass.

The local workspace's dry-run fixture script also ran and reported 14 cases passed, but that script pins candidate `563f411` and base `590eb4e`; that result is historical and is not counted as evidence for `0e773d36`. The current-main helper and fixture snapshot was separately exercised in `/private/tmp/sigra-phase247-fixture-live` and passed 25 cases. The exact candidate Playwright lane passed in CI run `37819712610`; local WebKit remains blocked by the recorded host AppKit abort.

## Manual-Only and Escalated Items

- **247-09-02 / 247-10-02 approval gates:** retain the blocking status unless an immutable record proves the exact candidate/base/main tuple was authorized. Later verification reports approval pending; this audit does not reconstruct approval from a summary or infer it from CI.
- **247-05-03 / 247-08-02 / 247-11-01 final receipt:** the committed receipt is for `d76d7f23`, while the rebind and Plan 11 claim name `0e773d36`. A matching safe receipt is required before READY-01 can pass.
- **247-11-02 / 247-11-03 final readiness:** `247-VERIFICATION.md` reports `gaps_found`, READY-01/READY-02 unsatisfied, and incomplete fresh source/inventory joins. Do not report phase completion from the passing unit/fixture suites.

## Validation Sign-Off

- [x] All 11 plan task groups are represented in the verification map.
- [x] Existing readiness tests pass; one source-specific stale-receipt behavioral test was added and run.
- [x] Current-main dry-run helper fixtures and actionlint pass in an isolated audit checkout.
- [x] Exact candidate mobile WebKit CI and protected evidence-PR CI identities are recorded.
- [ ] Current candidate, baseline, authenticated receipt, approval, and final inventory do not yet join in the retained phase artifacts.
- [ ] `nyquist_compliant: false` — the stale tuple is rejected, but a passing source-bound final readiness run and independent verification are still missing.

This validation audit does not authorize publication, tagging, or a release-PR merge.

## Validation Audit 2026-10-11

| Metric | Count |
|---|---|
| Gaps found | 7 |
| Resolved | 3 |
| Escalated | 4 |
