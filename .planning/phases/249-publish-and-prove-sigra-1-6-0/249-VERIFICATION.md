---
phase: 249-publish-and-prove-sigra-1-6-0
verified: 2026-10-09T23:46:19Z
status: gaps_found
score: 32/40 must-haves verified
covered_files:
  - .github/ci-skip-manifest.tsv
  - .github/workflows/ci.yml
  - .github/workflows/release-please.yml
  - .planning/METHODOLOGY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-01-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-01-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-02-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-02-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-03-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-03-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-04-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-04-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-05-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-05-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-06-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-06-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-07-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-07-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-08-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-08-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-09-CANDIDATE.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-09-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-09-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-10-CANDIDATE.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-10-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-10-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-11-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-11-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-12-PLAN.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-12-SUMMARY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-ACCEPTANCE.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-MAIN-PROOF.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PREFLIGHT.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PRESERVATION.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-REVIEW-DISPOSITION.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-REVIEW.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-SECURITY.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-VALIDATION.md
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs
  - .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs
  - doc/llms.txt
  - scripts/ci/check-docs-index.sh
  - scripts/ci/check-docs-index.test.sh
  - scripts/ci/honest-skip-verdict.sh
  - scripts/ci/honest-skip-verdict.test.sh
  - scripts/ci/refresh-release-docs.sh
  - scripts/ci/refresh-release-docs.test.sh
  - scripts/ci/release-public-proof.sh
  - scripts/ci/release-public-proof.test.sh
  - scripts/maintainers/preserve-phase-249-worktrees.mjs
  - scripts/maintainers/preserve-phase-249-worktrees.test.mjs
  - test/sigra/planning/phase_232_playwright_economics_test.exs
  - test/sigra/planning/phase_249_release_docs_contract_test.exs
covered_digest: "v3:sha256:d70a64037a1bba432847c6de1c7b8d60106b42cf495aa78d3df58feee9e66d80"
behavior_unverified: 0
overrides_applied: 4
overrides:
  - must_have: "Every inherited change set is preserved at a durable verified location before its original worktree becomes clean; unresolved ownership or preservation blocks REL-02 (D-08, D-09)."
    reason: "The exact historical .planning/HANDOFF.json bytes were unrecoverable. The user explicitly authorized this one accepted-loss exception; all other inventoried paths have verified preservation evidence, and current cleanliness remains independently guarded."
    accepted_by: "user"
    accepted_at: "2026-10-09"
  - must_have: "D-09: Every inherited path, including files created after the old capture, has an evidenced owner, disposition, exact source identity and recoverable preservation ref before that path is removed from a source worktree."
    reason: "The exact historical .planning/HANDOFF.json bytes were unrecoverable. The user explicitly authorized this one accepted-loss exception; all other inventoried paths have verified preservation evidence, and current cleanliness remains independently guarded."
    accepted_by: "user"
    accepted_at: "2026-10-09"
  - must_have: "D-09: The complete candidate diff contains exactly the ten Plan 09 paths and four Plan 10 paths, with no inherited work, preservation refs, gap planning artifacts or unrelated PR content."
    reason: "A related Phase 232 CI contract regression test for the DockerHub mirror failure was added while resolving the user-authorized CI failure, making the scoped candidate 15 paths. The extra test is isolated, relevant, and covered by passing CI."
    accepted_by: "user"
    accepted_at: "2026-10-09"
  - must_have: "D-09: One internally reviewed, phase-scoped PR contains exactly the Plan 09 plus Plan 10 candidate paths and no inherited or unrelated work."
    reason: "A related Phase 232 CI contract regression test for the DockerHub mirror failure was added while resolving the user-authorized CI failure, making the scoped candidate 15 paths. The extra test is isolated, relevant, and covered by passing CI."
    accepted_by: "user"
    accepted_at: "2026-10-09"
gaps:
  - truth: "Closeout evidence reflects the exact live PR/worktree population, final acceptance is current, and the terminal evidence ref binds that acceptance to post-write clean-worktree reads."
    status: failed
    reason: "The live inventory validator rejects the captured ledger with worktree_head_mismatch and pull_request_population_or_identity_mismatch. The ledger's #302 identity is stale. The canonical acceptance and terminal ref still bind the earlier main 3c7d713f rather than current main 08300af1740fea8b77d5928a182688acbf103edc, so the required final replay and seal remain outstanding."
    artifacts:
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json"
        issue: "Does not match the current live root worktree head and PR #302 identity."
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-ACCEPTANCE.json"
        issue: "Canonical acceptance is not refreshed for current main 08300af1740fea8b77d5928a182688acbf103edc and the current inventory."
      - path: "refs/heads/evidence/phase-249-final-acceptance"
        issue: "Terminal commit 5d32d65e... binds old canonical acceptance commit 6596fa... and main 3c7d713f..., not the current acceptance/main."
    missing:
      - "Recapture the complete live PR/worktree inventory and refresh the source-backed disposition for current PR #302."
      - "After this verification and required state/summary updates are committed, rerun final acceptance against current main and current raw worktree status."
      - "Write and verify the terminal ref-only record last, binding the canonical acceptance commit and two post-ref-write zero-row status captures; then reread each worktree."
  - truth: "Every currently open PR has a current source-backed disposition and every local worktree has zero raw porcelain rows at final acceptance."
    status: failed
    reason: "The captured closeout ledger is stale for the live PR/worktree identities; the final strict cleanliness assertion has not been replayed after the pending verification/state updates."
    artifacts:
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json"
        issue: "Its inventory provenance no longer matches live identities."
    missing:
      - "Refresh live inventory and dispositions, then run the terminal all-worktrees-clean check after evidence/state commits."
  - truth: "The plan's failure cases (changed main, stale/missing CI, missing receipt, new dirty path, or undispositioned PR) leave durable blocked evidence."
    status: partial
    reason: "The validator's negative fixtures pass, but the canonical final acceptance and terminal seal have not been refreshed to record the present live-inventory blockers."
    artifacts:
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-ACCEPTANCE.json"
        issue: "The committed canonical record predates current main and current PR/worktree identities."
    missing:
      - "Persist the refreshed final blocked-or-passed acceptance and its matching terminal evidence only after all phase updates are final."
---

# Phase 249: Publish and Prove Sigra 1.6.0 Verification Report

**Phase Goal:** Adopters can install documented Sigra 1.6.0, and maintainers can trace it to the exact gated source while finishing in a clean repository state.
**Verified:** 2026-10-09T23:46:19Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---:|---|---|---|
| 1 | A read-only ready/blocked preflight runs before release mutation. | ✓ VERIFIED | Preflight evidence and fail-closed fixtures are present; the exact-source mismatch was rerun from the matching clean main checkout. |
| 2 | Hex 1.6.0, versioned HexDocs, resolving source link, tag/source SHA, artifact and package-source CI join. | ✓ VERIFIED | Public proof from a clean checkout of main 08300af... resolves rendered source to immutable package source 9e80cb78...; Hex checksum and versioned docs agree. |
| 3 | The receipt is sanitized and excludes its own commit/run identity and later main identity. | ✓ VERIFIED | Receipt retains package-source SHA and CI; final-main fields are separate in 249-FINAL-MAIN-PROOF.json. |
| 4 | Indexed doc/llms.txt equals complete generated ExDoc output. | ✓ VERIFIED | Docs build/index contract and exact-main docs CI passed; CI job 114067129936 succeeded. |
| 5 | Required PR CI builds docs with warnings as errors and fails on generated-index drift with regeneration guidance. | ✓ VERIFIED | Required CI workflow and docs-index contract test verify build-then-compare behavior, including docs-only changes. |
| 6 | Trusted-main refresh edits only the one eligible candidate's docs index without a write token during docs build. | ✓ VERIFIED | Workflow permissions and candidate-bound refresh contract tests pass; writer scope is narrowed to doc/llms.txt. |
| 7 | Refresh rejects candidate/path/branch drift and non-fast-forward races. | ✓ VERIFIED | Refresh writer identity and race fixtures pass; push is non-force and scoped. |
| 8 | Refreshed candidate gets ordinary CI and exact-head merge guard. | ✓ VERIFIED | Candidate merge gate and exact-head behavior are covered by workflow contract tests and hosted CI evidence. |
| 9 | Every current open PR has an explicit release disposition. | ✗ FAILED | The live validator reports pull_request_population_or_identity_mismatch; #302's current identity differs from the ledger. |
| 10 | Every worktree and dirty path is inventoried with owner/preservation or explicit blocker. | ✗ FAILED | The captured snapshot is stale: validator reports root worktree_head_mismatch and a changed PR identity. |
| 11 | Inherited changes are preserved before source worktrees are cleaned. | ✓ VERIFIED (override) | All inventoried changes except exact historical .planning/HANDOFF.json bytes have verified preservation; user explicitly accepted that unrecoverable loss. |
| 12 | Only phase-scoped code, docs index and source-derived receipt are promoted; unrelated PRs stay separate. | ✓ VERIFIED | PR #305 is the scoped release change; unrelated open PRs were not merged. |
| 13 | Promotion record is separate and receipt remains bound to package source. | ✓ VERIFIED | Promotion record and receipt are distinct; package source remains 9e80cb78... |
| 14 | Final protected-main receipt commit has exact-head successful ordinary CI and ci-gate. | ✓ VERIFIED | Main 08300af1740fea8b77d5928a182688acbf103edc; run 38003573391, attempt 1, job 114069179560 succeeded. |
| 15 | REL-02 receipt points to immutable package source/CI; later main proof is separate. | ✓ VERIFIED | The release receipt names source 9e80cb78...; final-main SHA and CI are recorded separately. |
| 16 | Package, tag, Hex, versioned docs and source destination still join the release receipt. | ✓ VERIFIED | Read-only exact-main public proof passed and resolved source URL to the tagged source commit. |
| 17 | Every current PR has a disposition and all local worktrees are clean after verified preservation. | ✗ FAILED | Worktree cleanliness was observed before report/state updates, but current ledger identities are stale and final terminal cleanliness has not been replayed. |
| 18 | Public proof rejects mismatched artifacts, tag, package, docs, source or CI identities. | ✓ VERIFIED | Hostile artifact and identity mismatch fixtures pass. |
| 19 | Untrusted artifacts are inert; receipt accepts only allowlisted source-bound values. | ✓ VERIFIED | Sanitization and source/main identity separation are covered by passing proof fixtures. |
| 20 | Fresh complete worktree and paginated PR inventory accounts for all current paths/PRs. | ✗ FAILED | Current inventory validation fails on root worktree head and PR population/identity mismatch. |
| 21 | Every inherited path has owner, exact identity and recoverable ref before removal. | ✓ VERIFIED (override) | Verified for inventoried changes except the explicit user-accepted unrecoverable historical handoff bytes. |
| 22 | Inventory-transition exclusions never weaken the terminal all-worktrees-clean check. | ✓ VERIFIED | The validator and fixtures inspect raw porcelain status and prevent declared evidence outputs from hiding dirty paths. |
| 23 | Ambiguous ownership, drift, new dirty paths or failed reads create an exact blocker without altering source. | ✓ VERIFIED | Fail-closed preservation fixtures pass, including absent refs, hash drift, owner ambiguity and new dirty paths. |
| 24 | Candidate slice contains the unchanged sanitized receipt and immutable source CI. | ✓ VERIFIED | Candidate/receipt evidence keeps package-source identity 9e80cb78... and source CI separate from later main. |
| 25 | Candidate includes complete generated ExDoc index and required build-then-compare gate. | ✓ VERIFIED | doc/llms.txt, CI workflow, and docs-index tests are present and connected. |
| 26 | Candidate contains only scoped Phase 249 paths, with inherited and unrelated PR work excluded. | ✓ VERIFIED | PR #305's 15-path diff is phase-related and excludes inherited changes; the extra Phase 232 regression test is accepted under the scope override below. |
| 27 | Candidate was assembled against fresh protected main in a clean isolated worktree. | ✓ VERIFIED | Candidate and promotion records document the isolated base/head and review/CI process. |
| 28 | Complete candidate includes trusted refresh path, unprivileged docs build and exact candidate recheck. | ✓ VERIFIED | Candidate CI and workflow contract checks passed. |
| 29 | Candidate retains unchanged artifact-derived receipt and source CI identity. | ✓ VERIFIED | Receipt blob/hash matches the artifact-derived package-source evidence. |
| 30 | Candidate has exactly 14 paths (ten Plan 09 plus four Plan 10). | ✓ VERIFIED (override) | The submitted candidate has 15 paths because the user-authorized CI repair added a related Phase 232 DockerHub-mirror regression test; no unrelated inherited work was included. |
| 31 | Candidate was internally reviewed and locally green before PR. | ✓ VERIFIED | Internal review disposition is clean; focused closeout fixtures passed 60/60 in this verifier run. |
| 32 | Protected merge retains unchanged receipt blob and immutable source identity. | ✓ VERIFIED | PR #305 merged as 08300af...; receipt blob is 04319a..., matching the source-bound receipt. |
| 33 | Reviewed PR includes exactly Plan 09/10 candidate paths and no unrelated work. | ✓ VERIFIED (override) | The only added path beyond the original 14 is the related, user-authorized Phase 232 regression test; hosted exact-head CI passed. |
| 34 | Exact current PR head/base passed required CI before protected squash auto-merge; promotion records identities. | ✓ VERIFIED | PR #305 CI run 38003010120, job 114067027263, passed on exact PR head; merge SHA is current main. |
| 35 | Release Please and unrelated PRs remain open with dispositions in refreshed closeout ledger. | ✗ FAILED | Current PR population/identity does not match the recorded ledger; #302 needs a current source-backed disposition. |
| 36 | Current protected main has exact receipt and successful ci-gate, separate from package source. | ✓ VERIFIED | Current main 08300af...; exact-main CI run 38003573391, job 114069179560, succeeded. |
| 37 | All worktrees are raw-clean after evidence commits and all open PRs have current dispositions. | ✗ FAILED | Final capture is pending; current ledger is stale and the report/state changes still require commit before terminal proof. |
| 38 | Terminal record binds final validation and post-ref-write raw clean reads to canonical acceptance. | ✗ FAILED | Existing terminal ref binds old acceptance/main (6596fa... / 3c7d713f...), not the current acceptance/main. |
| 39 | REL-01 public proof remains valid without republishing or tag mutation. | ✓ VERIFIED | Exact-current-main clean-clone proof passed; package/tag/docs/source identities remain joined. |
| 40 | Changed/missing release or inventory evidence produces durable blocked acceptance. | ✗ FAILED | Negative fixtures pass, but canonical final acceptance/terminal artifacts have not been refreshed to encode the current inventory blockers. |

**Score:** 32/40 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| 249-RELEASE-RECEIPT.json | Sanitized package-source receipt | ✓ VERIFIED | Source SHA and CI are immutable and distinct from final main. |
| 249-FINAL-MAIN-PROOF.json | Current exact-main receipt and CI proof | ✓ VERIFIED | Exact SHA 08300af...; run 38003573391, ci-gate job 114069179560 passed. |
| validate-closeout.mjs and .test.mjs | Fail-closed inventory, acceptance and terminal validator | ✓ VERIFIED | 60/60 focused tests passed in 1.6s. |
| 249-VALIDATION.md, 249-SECURITY.md, 249-REVIEW.md | Validation, threat and code-review evidence | ✓ VERIFIED | Nyquist complete; no open threats; zero review findings. |
| 249-CLOSEOUT.json | Current PR/worktree inventory and dispositions | ✗ STALE | Live validator reports worktree head and PR identity mismatch. |
| 249-FINAL-ACCEPTANCE.json | Final public/main/inventory acceptance | ✗ STALE | Not refreshed after PR #305 merged and current main advanced to 08300af.... |
| refs/heads/evidence/phase-249-final-acceptance | Terminal evidence bound to canonical acceptance | ✗ STALE | Existing terminal commit seals prior main/acceptance, not the current final proof. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Package-source release artifact | 249-RELEASE-RECEIPT.json | Sanitized artifact fields and package source CI | ✓ WIRED | Receipt source SHA and run identity match the published 1.6.0 source. |
| Release receipt | Protected main | PR #305 merge and receipt blob | ✓ WIRED | Exact receipt blob 04319a... is on current main. |
| Protected main | Exact-main CI | Run 38003573391, job 114069179560 | ✓ WIRED | Required ci-gate succeeded on main SHA 08300af.... |
| Current closeout inventory | Canonical final acceptance | Validator joins PR/worktree identities | ✗ NOT CURRENT | Current validator returns worktree_head_mismatch and pull_request_population_or_identity_mismatch. |
| Canonical final acceptance | Terminal evidence ref | Ref-only terminal commit | ✗ STALE | Link exists but points to previous canonical acceptance and previous main. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| 249-RELEASE-RECEIPT.json | package version/source/checksum/docs/source CI | Live Hex/API, tag/source, release artifact and CI | Yes | ✓ FLOWING |
| 249-FINAL-MAIN-PROOF.json | final main SHA/receipt blob/run/job | GitHub protected main, contents API, Actions run/job | Yes | ✓ FLOWING |
| 249-CLOSEOUT.json | open PR/worktree identities | Live GitHub PR inventory and raw local porcelain status | Captured data is stale | ⚠️ STATIC/STALE |
| 249-FINAL-ACCEPTANCE.json and terminal ref | joined verdict and final cleanliness | Closeout plus current public/main proof | Prior capture only | ⚠️ STALE |

### Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
|---|---|---|---|
| Closeout validator rejects unsafe preservation, stale identities, missing proof and terminal drift | node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs | 60 passed, 0 failed | ✓ PASS |
| Public release identity resolves from exact current main checkout | Clean-clone public proof recorded in phase evidence | Version 1.6.0, source resolves to 9e80cb78..., package checksum/docs/source join pass | ✓ PASS |
| Final-main CI gate belongs to the receipt-bearing protected head | GitHub run 38003573391, job 114069179560 | Completed success on 08300af... | ✓ PASS |
| Full terminal acceptance matches live closeout state | validate-closeout.mjs --mode inventory | worktree_head_mismatch; pull_request_population_or_identity_mismatch | ✗ FAIL |

### Probe Execution

No phase-declared probe-*.sh script was found. The deterministic closeout test suite and live proof artifacts above cover the relevant verification paths.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| REL-01 | 249-01, 249-06, 249-07, 249-12 | Hex 1.6.0, versioned docs and source reference resolve to the gated release source. | ✓ SATISFIED | Read-only clean-clone proof from exact current main resolves source to immutable 9e80cb78...; Hex checksum and versioned docs agree. |
| REL-02 | 249-01, 249-04–249-12 | Receipt/main CI, raw-clean worktrees and current dispositions for every open PR. | ✗ BLOCKED | Exact main receipt/CI passed, but closeout inventory is stale and final acceptance/terminal seal have not been replayed. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| — | — | No blocking implementation anti-pattern or unresolved debt marker found in the phase-modified files. | — | Historical TBD markers in the pre-existing pattern-mapping document are not in the modified implementation/evidence set. |

### Human Verification Required

None. The remaining acceptance conditions are deterministic repository/GitHub state checks and can be completed by the already-planned final replay; human UAT would not add evidence.

### Gaps Summary

The published package and public docs/source proof are valid, and protected main 08300af1740fea8b77d5928a182688acbf103edc has successful exact-head required CI. Phase 249 is not yet fully accepted because the recorded PR/worktree inventory and terminal seal predate the latest merge/current identities. The required final acceptance and terminal evidence replay is explicitly scheduled after this report and the remaining phase/state updates are committed. No release implementation failure or human UAT blocker was found.

---

_Verified: 2026-10-09T23:46:19Z_  
_Verifier: the agent (gsd-verifier)_
