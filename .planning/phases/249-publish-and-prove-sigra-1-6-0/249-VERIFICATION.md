---
phase: 249-publish-and-prove-sigra-1-6-0
verified: 2026-10-10T16:11:31.257Z
status: gaps_found
source_snapshot: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-249-SOURCE-SNAPSHOT.json
owner_requirements: [REL-01, REL-02]
---

# Phase 249: Publish and Prove Sigra 1.6.0 Verification Report

**Phase Goal:** Adopters can install documented Sigra 1.6.0, and maintainers can trace it to the exact gated source while finishing in a clean repository state.
**Verified:** 2026-10-10T16:11:31.257Z
**Status:** gaps_found
**Re-verification:** Yes — independently joined the terminal acceptance ref and fresh public/main/inventory evidence.

<!-- phase249-evidence {"requirements":{"REL-01":"satisfied","REL-02":"unsatisfied"},"package_source_sha":"9e80cb78d6374b1ed4074d5fef6b613fee879dca","historical_release_main_sha":"08300af1740fea8b77d5928a182688acbf103edc","current_protected_main_sha":"6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5","evidence_ref":"refs/heads/evidence/phase-249-final-acceptance","evidence_ref_commit":"65f1ca4c851d62415ed656509cb068dc3acbab15","evidence_acceptance_blob":"4bbd07d77d721e14f93c98e43f4fa6ef143a5519","evidence_terminal_blob":"b42563cbc389156ea355950fb598efeb0e979a54","historical_ci_run_id":38003573391,"historical_ci_job_id":114069179560,"current_ci_run_id":38061391571,"current_ci_job_id":114241911167,"receipt_blob_sha":"04319a489442de5ac80a80a992df5927973d49aa","worktree_count":7,"pull_request_count":16,"accepted_loss_sha256":"00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148","historical_report_sha256":"864d5d71244451736e66eb1d45363f46b8c36b23d95fc02b15d69948965b5681"} -->

## Current Evidence Boundary

- **REL-01: satisfied.** Hex 1.6.0, versioned docs, source URL, checksum, and tag resolve to package source `9e80cb78d6374b1ed4074d5fef6b613fee879dca`. Historical acceptance is `refs/heads/evidence/phase-249-final-acceptance` at 65f1ca4c851d62415ed656509cb068dc3acbab15; its acceptance blob 4bbd07d77d721e14f93c98e43f4fa6ef143a5519 and passing terminal record validate against historical release main 08300af1740fea8b77d5928a182688acbf103edc. Exact historical ci-gate: run 38003573391, attempt 1, job 114069179560.
- **REL-02: unsatisfied.** Current protected main 6b2bd9e8ad9ab2042fc216f1cc207316e0f9a3d5 is recorded separately. Its exact ci-gate is run 38061391571, attempt 1, job 114241911167 (success); the containing CI run concluded failure. The current receipt blob is 04319a489442de5ac80a80a992df5927973d49aa. Fresh inventory has 7 registered worktrees and 16 open PRs.

## Accepted historical loss

The exact historical `.planning/HANDOFF.json` revision is accepted-with-recorded-loss under the user's authorization dated 2026-10-09: “accept reality and move on accordingly.” Its identity is SHA-256 `00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148`; those historical bytes were not recovered and were not preserved.

## Current blockers

- REL-02: current CI workflow run concluded failure for the exact current main SHA
- REL-02: open PR #302 has no disposition matching its current base/head identity
- REL-02: open PR #306 has no disposition matching its current base/head identity
- REL-02: open PR #307 has no disposition matching its current base/head identity
- REL-02: open PR #308 has no disposition matching its current base/head identity
- REL-02: open PR #309 has no disposition matching its current base/head identity

## Historical verification context

The earlier `gaps_found` report records the state before the later terminal acceptance ref and current post-canary main. Its historical observations remain unchanged; this report uses the new immutable acceptance identity and freshly observed current PR/worktree state.

<details>
<summary>Historical Phase 249 report preserved verbatim</summary>

`````markdown
---
phase: 249-publish-and-prove-sigra-1-6-0
verified: 2026-10-09T23:56:36Z
status: gaps_found
score: 35/40 must-haves verified
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
covered_digest: "v3:sha256:cf89cf61740b6cf846b74425747cc0e35b0cc0a484505297c3c75ae333a99913"
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
re_verification:
  previous_status: gaps_found
  previous_score: 32/40
  gaps_closed:
    - "The refreshed live ledger now passes population/identity validation for six worktrees and fourteen open PRs; PR #302 has a current disposition."
    - "Current inventory and preservation checks pass with zero dirty paths; the exact historical HANDOFF.json accepted-loss remains explicit and bounded."
    - "Canonical final acceptance and terminal evidence now bind main 08300af1740fea8b77d5928a182688acbf103edc, its successful exact-head ci-gate, and the matching acceptance evidence commit."
  gaps_remaining:
    - "The report, phase summary/validation, and project handoff/state/roadmap updates are now dirty after terminal commit a8adada5c34fe09ce41a1cc59be83f4c5a1c7d33; commit the pending updates, then refresh inventory/acceptance and replay terminal sealing last."
  regressions: []
gaps:
  - truth: "After all phase evidence is final, every registered worktree is raw-clean and the terminal ref binds the current canonical acceptance to post-ref-write raw status reads."
    status: failed
    reason: "The previous stale worktree/#302 findings are superseded: inventory, dispositions, preservation and canonical final acceptance passed, and terminal commit a8adada5c34fe09ce41a1cc59be83f4c5a1c7d33 binds passed acceptance for main 08300af1740fea8b77d5928a182688acbf103edc. The subsequent report and planning/state updates now change root worktree paths; the read-only validator reports dirty_path_population_mismatch, so the pending updates must be committed before the final inventory/terminal replay."
    artifacts:
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md"
        issue: "The revised report is modified after the terminal raw-status capture and is not yet included in a new canonical acceptance and terminal seal."
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-12-SUMMARY.md"
        issue: "The refreshed snapshot diagnosis and final-replay route were added after the terminal capture."
      - path: ".planning/phases/249-publish-and-prove-sigra-1-6-0/249-VALIDATION.md"
        issue: "The 249-12 final replay row was updated after the terminal capture."
      - path: ".planning/HANDOFF.json, .planning/ROADMAP.md, .planning/STATE.md, .planning/state.json"
        issue: "Coordinated project routing/state updates are pending commit and were made after the interim terminal seal."
      - path: "refs/heads/evidence/phase-249-final-acceptance"
        issue: "Terminal commit a8adada5c34fe09ce41a1cc59be83f4c5a1c7d33 is valid for its captured snapshot but predates the pending phase/state/report updates."
    missing:
      - "Commit the report and coordinated phase/state updates, refresh inventory and final acceptance against those commits, and rerun terminal sealing as the last repository mutation."
---

# Phase 249: Publish and Prove Sigra 1.6.0 Verification Report

**Phase Goal:** Adopters can install documented Sigra 1.6.0, and maintainers can trace it to the exact gated source while finishing in a clean repository state.
**Verified:** 2026-10-09T23:56:36Z
**Status:** gaps_found
**Re-verification:** Yes — after closeout gap closure

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
| 9 | Every current open PR has an explicit release disposition. | ✓ VERIFIED | Refreshed inventory covers 14 open PRs; disposition validation passes with no missing or stale identities. The earlier #302 mismatch was superseded by the new snapshot. |
| 10 | Every worktree and dirty path is inventoried with owner/preservation or explicit blocker. | ✗ FAILED | The refreshed snapshot passed for six worktrees; subsequent report, summary, validation, handoff and state edits now create a different root dirty-path set (dirty_path_population_mismatch). |
| 11 | Inherited changes are preserved before source worktrees are cleaned. | ✓ VERIFIED (override) | All inventoried changes except exact historical .planning/HANDOFF.json bytes have verified preservation; user explicitly accepted that unrecoverable loss. |
| 12 | Only phase-scoped code, docs index and source-derived receipt are promoted; unrelated PRs stay separate. | ✓ VERIFIED | PR #305 is the scoped release change; unrelated open PRs were not merged. |
| 13 | Promotion record is separate and receipt remains bound to package source. | ✓ VERIFIED | Promotion record and receipt are distinct; package source remains 9e80cb78... |
| 14 | Final protected-main receipt commit has exact-head successful ordinary CI and ci-gate. | ✓ VERIFIED | Main 08300af1740fea8b77d5928a182688acbf103edc; run 38003573391, attempt 1, job 114069179560 succeeded. |
| 15 | REL-02 receipt points to immutable package source/CI; later main proof is separate. | ✓ VERIFIED | The release receipt names source 9e80cb78...; final-main SHA and CI are recorded separately. |
| 16 | Package, tag, Hex, versioned docs and source destination still join the release receipt. | ✓ VERIFIED | Read-only exact-main public proof passed and resolved source URL to the tagged source commit. |
| 17 | Every current PR has a disposition and all local worktrees are clean after verified preservation. | ✗ FAILED | PR dispositions and preservation pass, but seven pending root planning/report paths mean the worktree set is not currently at the sealed clean state. |
| 18 | Public proof rejects mismatched artifacts, tag, package, docs, source or CI identities. | ✓ VERIFIED | Hostile artifact and identity mismatch fixtures pass. |
| 19 | Untrusted artifacts are inert; receipt accepts only allowlisted source-bound values. | ✓ VERIFIED | Sanitization and source/main identity separation are covered by passing proof fixtures. |
| 20 | Fresh complete worktree and paginated PR inventory accounts for all current paths/PRs. | ✗ FAILED | The refreshed six-worktree/fourteen-PR snapshot passed before subsequent planning/report edits; the validator now detects changed dirty-path population. |
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
| 35 | Release Please and unrelated PRs remain open with dispositions in refreshed closeout ledger. | ✓ VERIFIED | Refreshed disposition validator passes for all 14 current open PRs, including current #302 identity. |
| 36 | Current protected main has exact receipt and successful ci-gate, separate from package source. | ✓ VERIFIED | Current main 08300af...; exact-main CI run 38003573391, job 114069179560, succeeded. |
| 37 | All worktrees are raw-clean after evidence commits and all open PRs have current dispositions. | ✗ FAILED | Terminal commit a8adada5... recorded six zero-byte status reads, but seven planning/report paths changed afterward and need commit plus recapture. |
| 38 | Terminal record binds final validation and post-ref-write raw clean reads to canonical acceptance. | ✗ FAILED | Terminal commit a8adada5... correctly binds the passed acceptance for main 08300af..., but predates the pending report/state updates and is not the latest repository-state seal. |
| 39 | REL-01 public proof remains valid without republishing or tag mutation. | ✓ VERIFIED | Exact-current-main clean-clone proof passed; package/tag/docs/source identities remain joined. |
| 40 | Changed/missing release or inventory evidence produces durable blocked acceptance. | ✓ VERIFIED | The negative fixture for a newly dirty path and undispositioned PR requires final acceptance to block; the focused closeout suite remains 60/60 passing. |

**Score:** 35/40 truths verified (0 present, behavior-unverified)

### Deferred Items

None.

### Advisory (New Scope, Unevidenced)

None. The earlier root-worktree/#302 mismatch is superseded by the refreshed inventory; the only remaining issue is the verification report's own post-seal update.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| 249-RELEASE-RECEIPT.json | Sanitized package-source receipt | ✓ VERIFIED | Source SHA and CI are immutable and distinct from final main. |
| 249-FINAL-MAIN-PROOF.json | Current exact-main receipt and CI proof | ✓ VERIFIED | Exact SHA 08300af...; run 38003573391, ci-gate job 114069179560 passed. |
| validate-closeout.mjs and .test.mjs | Fail-closed inventory, acceptance and terminal validator | ✓ VERIFIED | 60/60 focused tests passed in 1.6s. |
| 249-VALIDATION.md, 249-SECURITY.md, 249-REVIEW.md | Validation, threat and code-review evidence | ✓ VERIFIED | Nyquist complete; no open threats; zero review findings. |
| 249-CLOSEOUT.json | Current PR/worktree inventory and dispositions | ✓ VERIFIED AT CAPTURE | `--mode inventory`, `dispositions` and `preservation` passed for six worktrees and fourteen PRs. This report revision occurred after that capture, so final replay is still required. |
| 249-FINAL-ACCEPTANCE.json | Final public/main/inventory acceptance | ✓ VERIFIED | Canonical passed acceptance is preserved at commit `ed8cf726f502464bb566efb80d674248606fba2f`, blob `7f3180c487f7d9a69555ab18bc2aad34b07c32ab`, SHA-256 `6a93bbe47f68c2af7f4bdf9270234c10b935e4755c523f46b742248572ad5164`. |
| refs/heads/evidence/phase-249-final-acceptance | Terminal evidence bound to canonical acceptance | ⚠️ STALE AFTER REPORT UPDATE | Ref points to `a8adada5c34fe09ce41a1cc59be83f4c5a1c7d33`; it validly seals the canonical acceptance and six zero-byte reads, but predates this revised report. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Package-source release artifact | 249-RELEASE-RECEIPT.json | Sanitized artifact fields and package source CI | ✓ WIRED | Receipt source SHA and run identity match the published 1.6.0 source. |
| Release receipt | Protected main | PR #305 merge and receipt blob | ✓ WIRED | Exact receipt blob 04319a... is on current main. |
| Protected main | Exact-main CI | Run 38003573391, job 114069179560 | ✓ WIRED | Required ci-gate succeeded on main SHA 08300af.... |
| Current closeout inventory | Canonical final acceptance | Validator joins PR/worktree identities | ✓ VERIFIED AT CAPTURE | Refreshed inventory and disposition validators pass; final replay must include this report's new bytes. |
| Canonical final acceptance | Terminal evidence ref | Ref-only terminal commit | ✓ VERIFIED AT CAPTURE | Terminal record binds canonical blob `7f3180...`, acceptance commit `ed8cf7...`, and current main `08300af...`; it must be resealed after this report update. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| 249-RELEASE-RECEIPT.json | package version/source/checksum/docs/source CI | Live Hex/API, tag/source, release artifact and CI | Yes | ✓ FLOWING |
| 249-FINAL-MAIN-PROOF.json | final main SHA/receipt blob/run/job | GitHub protected main, contents API, Actions run/job | Yes | ✓ FLOWING |
| 249-CLOSEOUT.json | open PR/worktree identities | Live GitHub PR inventory and raw local porcelain status | Six worktrees, fourteen PRs; zero dirty paths at capture | ✓ FLOWING AT CAPTURE |
| Canonical acceptance and terminal ref | joined verdict and final cleanliness | Closeout plus current public/main proof | Passed acceptance; six byte-empty terminal reads | ✓ FLOWING AT CAPTURE; RESEAL AFTER REPORT COMMIT |

### Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
|---|---|---|---|
| Closeout validator rejects unsafe preservation, stale identities, missing proof and terminal drift | node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs | 60 passed, 0 failed | ✓ PASS |
| Public release identity resolves from exact current main checkout | Clean-clone public proof recorded in phase evidence | Version 1.6.0, source resolves to 9e80cb78..., package checksum/docs/source join pass | ✓ PASS |
| Final-main CI gate belongs to the receipt-bearing protected head | GitHub run 38003573391, job 114069179560 | Completed success on 08300af... | ✓ PASS |
| Refreshed live inventory, PR dispositions, preservation | validate-closeout.mjs --mode inventory/dispositions/preservation | Inventory/dispositions/preservation passed for six worktrees and 14 PRs with one authorized HANDOFF accepted-loss; after later file updates inventory detects dirty-path population drift | ✓ PASS AT CAPTURE |
| Canonical acceptance and terminal seal bind exact current-main proof | Read canonical acceptance from commit ed8cf726; terminal ref a8adada5 | Passed on main 08300af; 6 worktrees, 14 PRs, 0 dirty paths; 6/6 post-write raw statuses empty | ✓ PASS AT CAPTURE |
| Current root worktree remains clean after pending updates | validate-closeout.mjs --mode inventory; git status --short | dirty_path_population_mismatch; handoff, roadmap, state, phase summary/validation and this report are modified | ✗ FAIL; commit and reseal |

### Probe Execution

No phase-declared probe-*.sh script was found. The deterministic closeout test suite and live proof artifacts above cover the relevant verification paths.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| REL-01 | 249-01, 249-06, 249-07, 249-12 | Hex 1.6.0, versioned docs and source reference resolve to the gated release source. | ✓ SATISFIED | Read-only clean-clone proof from exact current main resolves source to immutable 9e80cb78...; Hex checksum and versioned docs agree. |
| REL-02 | 249-01, 249-04–249-12 | Receipt/main CI, raw-clean worktrees and current dispositions for every open PR. | ⚠️ BLOCKED PENDING FINAL RESEAL | Refreshed acceptance passed for current main and inventory; commit this report and rerun the terminal seal as the final repository mutation. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| — | — | No blocking implementation anti-pattern or unresolved debt marker found in the phase-modified files. | — | Historical TBD markers in the pre-existing pattern-mapping document are not in the modified implementation/evidence set. |

### Human Verification Required

None. The remaining acceptance condition is deterministic: commit this revised report, recapture the inventory, refresh canonical acceptance if needed, and reseal the terminal ref. Human UAT would not add evidence.

### Gaps Summary

The former stale-inventory and PR #302 identity findings are closed by a refreshed complete snapshot: six worktrees, fourteen PRs, all dispositions valid, preservation valid with the explicitly accepted historical HANDOFF loss, and a passed final acceptance for current main `08300af1740fea8b77d5928a182688acbf103edc`. Terminal commit `a8adada5c34fe09ce41a1cc59be83f4c5a1c7d33` correctly binds that acceptance and six empty post-write status records. This report revision itself is a later tracked-worktree change, so the last closeout step remains: commit this report, refresh acceptance, and reseal/read the terminal status after the commit. No release implementation failure or human UAT blocker was found.

---

_Verified: 2026-10-09T23:56:36Z_
_Verifier: the agent (gsd-verifier)_
`````
</details>
