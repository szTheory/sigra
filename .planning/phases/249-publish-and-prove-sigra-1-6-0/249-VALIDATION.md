---
phase: "249"
slug: "publish-and-prove-sigra-1-6-0"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-09"
---

# Phase 249 — Validation Strategy

> Plan IDs and executable commands are bound below. Locked D-03/D-04 resolve Research Open Question 1: the committed receipt points to the immutable v1.6.0 package-source SHA and its matching source CI; the later protected-main SHA and its own CI are separate final-closeout evidence. The phase worktree is an older v1.5.0 snapshot, so its initial docs mismatch was not authoritative for the v1.6.0 gate. The docs build/index comparison passed both in an isolated checkout of protected-main SHA `3c7d713f290c93de3b9fd54be7ece31d71f32787` on Elixir 1.18.4 / OTP 27.3.4.15 and in final-main CI on `08300af1740fea8b77d5928a182688acbf103edc`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing ExUnit, shell fixture/contract tests, and `actionlint` |
| **Config file** | `mix.exs`, `.github/workflows/ci.yml`, and the existing release workflow contracts |
| **Quick run command** | `bash scripts/ci/release-public-proof.test.sh && bash scripts/ci/release-receipt.test.sh && bash scripts/ci/check-docs-index.test.sh && bash scripts/ci/refresh-release-docs.test.sh && node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` |
| **Full suite command** | Trusted current `.github/workflows/ci.yml` runs `MIX_ENV=test mix ci` in `library_tests_shard`, and `mix docs --warnings-as-errors` in `library_tests_dep_off`; both feed `ci-gate`. Use its actual DB/toolchain setup, then confirm hosted CI on the resulting exact SHA. |
| **Measured runtime** | `release-public-proof.test.sh`: 28.99 seconds wall time on exact PR source commit `238eb1d68dd797222a869e5a98676aca4ebef651`; full post-merge CI on `08300af1740fea8b77d5928a182688acbf103edc` completed in about 19 minutes |

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
| 249-01-T1 | 249-01 | 1 | REL-01, REL-02 | T-249-01, T-249-02 | Read-only ready/blocked preflight precedes mutation; public identity joins exact package source and matching source CI | 60-case fixture + existing live proof | `bash scripts/ci/release-public-proof.test.sh` (60 passed); recorded `249-RELEASE-RECEIPT.json`, `249-PREFLIGHT.json` | ✅ | pass (live evidence retained; no republish) |
| 249-02-T1 | 249-02 | 2 | REL-02 | T-249-03 | Full generated index equals indexed bytes; title and navigation drift fail | fixture + generated build | `bash scripts/ci/check-docs-index.test.sh` (6 passed); isolated `mix docs --warnings-as-errors && bash scripts/ci/check-docs-index.sh` on `3c7d713f290c93de3b9fd54be7ece31d71f32787`; final-main run `38003573391` docs job `114067129936` passed on `08300af1740fea8b77d5928a182688acbf103edc` | ✅ | pass (the old 1.5.0 phase worktree mismatch is retained as a scope diagnostic) |
| 249-02-T2 | 249-02 | 2 | REL-02 | T-249-03, T-249-04 | Required docs job compares complete output on docs-only PRs and feeds ci-gate | shell contract + workflow lint | `bash scripts/ci/honest-skip-verdict.test.sh` (20 passed); `actionlint -shellcheck= .github/workflows/ci.yml` (pass) | ✅ | pass |
| 249-03-T1 | 249-03 | 3 | REL-02 | T-249-05, T-249-06 | One eligible candidate gets narrow, non-force docs refresh without build write credentials | shell fixtures + workflow lint | `bash scripts/ci/refresh-release-docs.test.sh` (12 passed); `actionlint -shellcheck= .github/workflows/release-please.yml` (pass) | ✅ | pass |
| 249-03-T2 | 249-03 | 3 | REL-02 | T-249-05, T-249-06, T-249-07 | Stale heads/races fail closed; exact-head CI and merge remain authoritative | shell, ExUnit, workflow lint | `bash scripts/ci/release-candidate-preflight.test.sh` (26 passed); `mix test test/sigra/planning/phase_249_release_docs_contract_test.exs test/sigra/planning/phase_248_release_gate_contract_test.exs` (15 passed); actionlint (3 workflows, pass) | ✅ | pass |
| 249-04-T1 | 249-04 | 2 | REL-02 | T-249-08, T-249-09 | Complete PR/worktree inventory detects partial, duplicate, and order variance | Node fixtures + recorded inventory | `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` (60 passed); `249-CLOSEOUT.json` and final acceptance | ✅ | pass (recorded live inventory; no refresh needed) |
| 249-04-T2 | 249-04 | 2 | REL-02 | T-249-08, T-249-09 | Every PR and dirty set has disposition or explicit blocker | Node fixtures + final acceptance | same Node suite; final acceptance has all PRs dispositioned; preservation record has explicit accepted-loss identity | ✅ | pass (one accepted historical loss remains explicit) |
| 249-05-T1 | 249-05 | 4 | REL-02 | T-249-10 | Inherited changes are preserved or exact loss is explicit; unsafe sets block | Node fixtures + later preservation evidence | `node --test scripts/maintainers/preserve-phase-249-worktrees.test.mjs .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` (63 passed); Plan 12 preservation evidence | ✅ | superseded; original Plan 05 result remains blocked and recoverable |
| 249-05-T2 | 249-05 | 4 | REL-01, REL-02 | T-249-11 | Exact reviewed candidate passed CI and was merged through protected review | Node promotion fixtures + hosted evidence | same Node suite; PR #304 candidate run 37992672660 and merge SHA 3c7d713f290c93de3b9fd54be7ece31d71f32787 | ✅ | superseded; original Plan 05 result remains blocked and recoverable |
| 249-06-T1 | 249-06 | 5 | REL-02 | T-249-12 | Protected main contains receipt and successful ordinary CI/ci-gate on exact SHA | Node post-merge fixtures + hosted proof | same Node suite; `249-FINAL-MAIN-PROOF.json` run 37993629114/job 114036565274 on exact SHA | ✅ | superseded; original Plan 06 result remains blocked and recoverable |
| 249-06-T2 | 249-06 | 5 | REL-01, REL-02 | T-249-13 | Public release, exact main, current PR inventory and terminal clean state jointly pass acceptance | Node final-acceptance fixtures + retained seal | same Node suite (60 passed); final acceptance and terminal seal on `refs/heads/evidence/phase-249-final-acceptance` | ✅ | superseded; original Plan 06 result remains blocked and recoverable |
| 249-07-T1 | 249-07 | 2 | REL-01, REL-02 | T-249-14 | Wrong identity, package/docs mismatch, redirects, or false source link fail closed | adversarial release fixtures | `bash scripts/ci/release-public-proof.test.sh` (60 passed); `bash scripts/ci/release-receipt.test.sh` (15 passed) | ✅ | pass |
| 249-07-T2 | 249-07 | 2 | REL-01, REL-02 | T-249-15 | Credential-like and shell-like artifact data stays inert and absent from receipt | hostile-data fixture | same two scripts (60 + 15 passed), including credential keys, diagnostics, shell-like values | ✅ | pass |
| 249-08-T1 | 249-08 | 2 | REL-02 | T-249-08, T-249-10 | Selected inherited bytes are pinned, read back, then only selected path is cleaned | Node behavior tests | `node --test scripts/maintainers/preserve-phase-249-worktrees.test.mjs .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` (63 passed) | ✅ | pass |
| 249-08-T2 | 249-08 | 2 | REL-02 | T-249-08, T-249-09 | Capture binds every live path and does not hide post-capture/dirty handoff paths | Node behavior tests | `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` (60 passed); recorded complete inventory | ✅ | pass |
| 249-08-T3 | 249-08 | 2 | REL-02 | T-249-10 | All safely attributable changes have verified refs and exact bytes; unresolved identities block | Node behavior tests + current acceptance | combined Node suite (63 passed); final preservation evidence accepts only the user-authorized handoff loss | ✅ | pass with explicit accepted-loss disposition |
| 249-09-T1 | 249-09 | 3 | REL-02 | T-249-01, T-249-03 | Source-bound receipt and complete docs-index comparison are assembled | shell fixtures + candidate artifact | public proof 60 passed; docs fixture 6 passed; `249-09-CANDIDATE.json` records candidate identity | ✅ | pass |
| 249-09-T2 | 249-09 | 3 | REL-02 | T-249-03, T-249-04 | Docs index and required CI wiring reject drift including docs-only changes | shell fixtures + hosted candidate evidence | honest-skip 20 passed; actionlint CI workflow passed; final-main CI run `38003573391`, docs job `114067129936`, passed on `08300af1740fea8b77d5928a182688acbf103edc` | ✅ | pass |
| 249-10-T1 | 249-10 | 4 | REL-02 | T-249-05, T-249-06, T-249-07 | Trusted refresh workflow binds candidate and rejects symlink/race/write privilege hazards | shell + ExUnit + actionlint | refresh 12 passed; preflight 26 passed; ExUnit 15 passed; actionlint 3 workflows passed | ✅ | pass |
| 249-10-T2 | 249-10 | 4 | REL-02 | T-249-03, T-249-14 | Reviewed 14-path candidate passes contributor gate and preserves receipt | recorded exact candidate gate + fixtures | `249-10-CANDIDATE.json` and summary record MIX_ENV=test mix ci pass; docs/receipt/refresh fixtures pass | ✅ | pass (exact candidate evidence; no external release mutation) |
| 249-11-T1 | 249-11 | 5 | REL-02 | T-249-08, T-249-11 | One scoped PR has exact reviewed head, source CI, and complete candidate paths | Node evidence fixtures + hosted record | Node closeout suite (60 passed); PR #304 exact-head CI run 37992672660 passed | ✅ | pass |
| 249-11-T2 | 249-11 | 5 | REL-02 | T-249-11 | Merge is guarded by exact state and promotion result is durably persisted | Node promotion fixtures + hosted merge record | Node closeout suite (60 passed); promotion record and merge SHA in `249-11-SUMMARY.md` | ✅ | pass |
| 249-12-T1 | 249-12 | 5 | REL-02 | T-249-12 | Exact current-main proof joins receipt, CI, and ci-gate to same SHA | Node post-merge fixtures + retained final-main proof | Node closeout suite (60 passed); `249-FINAL-MAIN-PROOF.json`, current main `08300af1740fea8b77d5928a182688acbf103edc`, run `38003573391`, ci-gate job `114069179560` | ✅ | pass |
| 249-12-T2 | 249-12 | 5 | REL-01, REL-02 | T-249-13 | Preservation, public proof, inventory, canonical acceptance and ref-only terminal status are bound | Node terminal fixtures + retained acceptance | Node closeout suite (60 passed); prior terminal evidence retained; final inventory/acceptance/seal replay follows this CI and the new review/security artifacts | ✅ | pending final closeout replay |

---

## Wave 0 Requirements

- [x] Receipt projection fixtures cover correct identity, mismatched source/run, and secret redaction.
- [x] Public verifier fixtures cover tag/source-CI, package/docs redirects, wrong source destination, malformed artifact, and inert hostile payloads.
- [x] Plan 07 hostile identity/security expansion runs (60 release-proof cases plus 15 receipt cases).
- [x] Full generated-index equality fixtures cover title-only and generated navigation-row drift; exact protected-main source build and index comparison pass.
- [x] Release Please refresh fixtures cover candidate identity, races, unexpected paths, and exact-head CI registration.
- [x] Inventory/ledger fixtures cover population completeness, duplicate identities, missing paths, dirty status, preservation hashes and terminal reread.
- [x] Bind all task IDs and exact commands to Plans 01–12; 05/06 original blocked results remain preserved and explicitly superseded by later evidence.

## Flagged spec-less probes

Research Open Question 1 is resolved by locked D-03/D-04: REL-02's receipt-source phrase names the immutable package source and matching source CI; final protected-main SHA and its own CI are separate final-closeout fields. Plan 01 proves the end-to-end positive join and a bounded missing-source-CI block; dependent Plan 07 tests the exhaustive artifact, identity, destination, and security failure matrix. The preflight's REL-01 `unclassified` probe and REL-02 `adjacency`, `empty`, and `ordering` prompts remain flagged assumptions, not new requirements. Plan 04 tests exact-set uniqueness, a successful empty PR query, query failure, and stable sorting. If an external behavior cannot be inferred from these concrete contracts, leave it unproven and surface a blocked diagnostic rather than inventing a pass.

---

## Manual-Only Verifications

All in-scope release, CI, GitHub, Hex, and repository-state checks should run automatically. If an external authority or credential makes a proof unavailable, preserve a machine-readable blocked result; do not convert it into a manual pass.

---

## Validation Sign-Off

- [x] All plan tasks have automated verification or an explicitly justified evidence blocker.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Focused feedback latency is measured from the exact PR source checkout (recorded below).
- [x] All 24 mapped task checks have deterministic tests or retained, scoped external evidence.

## Current Audit Findings

- **Resolved scope mismatch — 249-02-T1 / 249-09-T2:** The initial command ran in the phase worktree at an older 1.5.0 commit and generated a 1.5.0 title against the 1.6.0 index. An isolated clean checkout of trusted protected-main SHA `3c7d713f290c93de3b9fd54be7ece31d71f32787`, using the CI-matched Elixir 1.18.4 / OTP 27.3.4.15 toolchain, passed both `mix docs --warnings-as-errors` and `bash scripts/ci/check-docs-index.sh`. The original output was a valid diagnostic about checkout identity, not a product regression.
- **Redirect validation repair:** Final code review found Hex/HexDocs lookalike-host and delimiter-only URL cases that the original checks accepted. The fix is PR #305 head `238eb1d68dd797222a869e5a98676aca4ebef651`, covered by 60/60 focused fixtures and PR CI run `38003010120`, then squash-merged as `08300af1740fea8b77d5928a182688acbf103edc`. Full final-main CI run `38003573391` passed, including `ci-gate` job `114069179560` and docs-index job `114067129936`.
- **Historical BLOCKED — 249-05 / 249-06:** original executions remain blocked in their preserved evidence refs. Their goals were later satisfied by Plans 08, 11, and 12; status labels above describe supersession, never a green original run.
- **Evidence scope:** the immutable v1.6.0 publication was not repeated; its existing read-only public proof and source receipt remain unchanged. PR #305 and final-main CI were rerun on exact heads. The final closeout inventory, canonical acceptance, and terminal ref seal still need replay after this follow-up's documentation and security artifacts are committed.

**Approval:** validation coverage is complete; the post-review redirect hardening is merged and final-main CI is green. The final clean-state seal remains pending until the refreshed closeout pass.

**Feedback latency measurement:** `/usr/bin/time -p bash scripts/ci/release-public-proof.test.sh` in the isolated current-main PR checkout completed in 28.99 seconds (`real`), with 60 passed and 0 failed.
