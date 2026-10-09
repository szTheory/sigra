---
phase: "249"
slug: "publish-and-prove-sigra-1-6-0"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-09"
---

# Phase 249 — Validation Strategy

> Plan IDs and executable commands are bound below. Locked D-03/D-04 resolve Research Open Question 1: the committed receipt points to the immutable v1.6.0 package-source SHA and its matching source CI; the later protected-main SHA and its own CI are separate final-closeout evidence. This remains a draft until the executors create and run the tests from a clean, current trusted source checkout.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing ExUnit, shell fixture/contract tests, and `actionlint` |
| **Config file** | `mix.exs`, `.github/workflows/ci.yml`, and the existing release workflow contracts |
| **Quick run command** | `bash scripts/ci/release-public-proof.test.sh && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/check-docs-index.test.sh && bash scripts/ci/refresh-release-docs.test.sh && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` |
| **Full suite command** | Trusted current `.github/workflows/ci.yml` runs `MIX_ENV=test mix ci` in `library_tests_shard`, and `mix docs --warnings-as-errors` in `library_tests_dep_off`; both feed `ci-gate`. Use its actual DB/toolchain setup, then confirm hosted CI on the resulting exact SHA. |
| **Estimated runtime** | Resolve from the trusted source and CI run; do not infer from this stale, dirty checkout |

---

## Sampling Rate

- **After every task commit:** Run the focused tests and workflow lint that cover the changed seam.
- **After every plan wave:** Run required CI on the exact resulting commit and capture the run/head SHA.
- **Before `$gsd-verify-work`:** Run the phase acceptance checks, external read-only proof, and clean-closeout assertions.
- **Max feedback latency:** Measure the focused local suite in the trusted source checkout; keep live API checks outside the fast loop.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 249-01-T1 | 249-01 | 1 | REL-01, REL-02 | T-249-01, T-249-02 | Read-only ready/blocked preflight precedes mutation; one positive artifact/tag/source-CI/Hex/docs/destination join emits a receipt bound to package source; final main remains separate | positive fixture + live read-only | `bash scripts/ci/release-public-proof.test.sh`; `bash scripts/ci/release-public-proof.sh --version 1.6.0 --preflight .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PREFLIGHT.json --output .planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json` | ❌ Wave 0 | ⬜ pending |
| 249-02-T1 | 249-02 | 2 | REL-02 | T-249-03 | Full generated index equals the Git-indexed blob after ExDoc build; title and row drift fail | fixture + build | `bash scripts/ci/check-docs-index.test.sh`; `mix docs --warnings-as-errors && bash scripts/ci/check-docs-index.sh` | ❌ Wave 0 | ⬜ pending |
| 249-02-T2 | 249-02 | 2 | REL-02 | T-249-03, T-249-04 | Required docs job passes/fails through ci-gate on all PRs, including docs-only; old allowed-skip contract is removed | workflow contract | `bash scripts/ci/check-docs-index.test.sh && bash scripts/ci/honest-skip-verdict.test.sh && actionlint .github/workflows/ci.yml` | ❌ Wave 0 | ⬜ pending |
| 249-03-T1 | 249-03 | 3 | REL-02 | T-249-05, T-249-06 | Fixed eligible candidate receives index-only non-force update; docs builder has no write token | fixture + workflow lint | `bash scripts/ci/refresh-release-docs.test.sh && actionlint .github/workflows/release-please.yml` | ❌ Wave 0 | ⬜ pending |
| 249-03-T2 | 249-03 | 3 | REL-02 | T-249-05, T-249-06, T-249-07 | Stale heads/races fail closed; normal CI and exact-head merger remain authoritative | fixture + ExUnit + workflow lint | `bash scripts/ci/refresh-release-docs.test.sh && bash scripts/ci/release-candidate-preflight.test.sh`; `mix test test/sigra/planning/phase_249_release_docs_contract_test.exs test/sigra/planning/phase_248_release_gate_contract_test.exs`; `actionlint .github/workflows/release-please.yml .github/workflows/release-pr-automerge.yml .github/workflows/ci.yml` | ❌ Wave 0 | ⬜ pending |
| 249-04-T1 | 249-04 | 2 | REL-02 | T-249-08, T-249-09 | Every current worktree/path and PR is inventoried; failed/empty/duplicate/ordering cases are honest | node fixture + live read-only | `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs`; `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode inventory` | ❌ Wave 0 | ⬜ pending |
| 249-04-T2 | 249-04 | 2 | REL-02 | T-249-08, T-249-09 | Every PR and dirty set has explicit disposition or blocker | node fixture + live read-only | `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs`; `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode dispositions` | ❌ Wave 0 | ⬜ pending |
| 249-05-T1 | 249-05 | 4 | REL-02 | T-249-10 | Each relocated set has verified durable ref and content hashes; unsafe sets block clean claim | fixture + live repository assertion | `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs`; `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode preservation` | ❌ Wave 0 | ⬜ pending |
| 249-05-T2 | 249-05 | 4 | REL-01, REL-02 | T-249-11 | Scoped reviewed PR contains the artifact-derived receipt and phase changes only; local checks and exact PR-head CI precede protected merge | fixture + local gate + hosted promotion assertion | `bash scripts/ci/release-public-proof.test.sh && bash scripts/ci/check-docs-index.test.sh && bash scripts/ci/refresh-release-docs.test.sh && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs`; `mix docs --warnings-as-errors && bash scripts/ci/check-docs-index.sh`; `scripts/db/up.sh && . tmp/db.env && MIX_ENV=test mix ci`; `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode promotion --output .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PROMOTION.json` | ❌ Wave 0 | ⬜ pending |
| 249-06-T1 | 249-06 | 5 | REL-02 | T-249-12 | Protected main contains the receipt and has successful ordinary CI and ci-gate on its own exact current SHA, separate from package source | fixture + hosted exact-head assertion | `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs`; `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode post-merge --output .planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-MAIN-PROOF.json` | ❌ Wave 0 | ⬜ pending |
| 249-06-T2 | 249-06 | 5 | REL-01, REL-02 | T-249-13 | Public 1.6.0 identity, final-main proof, fresh PR inventory and preserved clean worktrees jointly determine final acceptance | fixture + live read-only + closeout assertion | `bash scripts/ci/release-public-proof.test.sh && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs`; `bash scripts/ci/release-public-proof.sh --version 1.6.0 --preflight tmp/phase-249-closeout-preflight.json --output tmp/phase-249-closeout-public-proof.json`; `node .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs --ledger .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json --mode final --public-proof tmp/phase-249-closeout-public-proof.json --main-proof .planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-MAIN-PROOF.json --output .planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-ACCEPTANCE.json` | ❌ Wave 0 | ⬜ pending |
| 249-07-T1 | 249-07 | 2 | REL-01, REL-02 | T-249-14 | Wrong run/attempt/SHA/tag/source-CI, Hex/docs mismatch, or false rendered link fails closed | fixture matrix | `bash scripts/ci/release-public-proof.test.sh && bash scripts/ci/release-receipt.test.sh` | ❌ Wave 0 | ⬜ pending |
| 249-07-T2 | 249-07 | 2 | REL-01, REL-02 | T-249-15 | Credential-shaped, diagnostic, and shell-like input stays inert and absent from receipt; package-source fields remain distinct | hostile-data fixture | `bash scripts/ci/release-public-proof.test.sh && bash scripts/ci/release-receipt.test.sh` | ❌ Wave 0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] Receipt projection/validation fixtures for correct identity, mismatched source/run, and secret redaction.
- [ ] Live-source verifier fixtures for tag mismatch, missing/stale CI, unavailable docs, broken source link, and wrong destination.
- [ ] Plan 07 expands Plan 01's bounded tracer fixtures with wrong attempt/tag/source-CI, package/docs/link mismatch, malformed artifact, credential redaction, and inert-payload cases.
- [ ] Full generated-index equality fixtures for version-title and module/navigation-row drift.
- [ ] Release Please refresh workflow/identity fixtures for stale or deleted candidates, unexpected files, update races, and fresh-CI enforcement.
- [ ] Inventory/ledger completeness checks for every current PR and every preserved worktree change set.
- [x] Bind task IDs and exact commands to Plans 01–07; Plan 01 is the end-to-end tracer and Plan 07 is its bounded dependent negative/security expansion. Implementation and proof remain pending.

## Flagged spec-less probes

Research Open Question 1 is resolved by locked D-03/D-04: REL-02's receipt-source phrase names the immutable package source and matching source CI; final protected-main SHA and its own CI are separate final-closeout fields. Plan 01 proves the end-to-end positive join and a bounded missing-source-CI block; dependent Plan 07 tests the exhaustive artifact, identity, destination, and security failure matrix. The preflight's REL-01 `unclassified` probe and REL-02 `adjacency`, `empty`, and `ordering` prompts remain flagged assumptions, not new requirements. Plan 04 tests exact-set uniqueness, a successful empty PR query, query failure, and stable sorting. If an external behavior cannot be inferred from these concrete contracts, leave it unproven and surface a blocked diagnostic rather than inventing a pass.

---

## Manual-Only Verifications

All in-scope release, CI, GitHub, Hex, and repository-state checks should run automatically. If an external authority or credential makes a proof unavailable, preserve a machine-readable blocked result; do not convert it into a manual pass.

---

## Validation Sign-Off

- [ ] All plan tasks have automated verification or an explicitly justified evidence blocker.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all MISSING references.
- [ ] No watch-mode flags.
- [ ] Feedback latency is measured from the trusted source checkout.
- [ ] `nyquist_compliant: true` set only after plan tasks and evidence paths are verified.

**Approval:** pending
