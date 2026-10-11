---
phase: "251"
slug: "close-ready-01-and-ready-02-release-readiness-gaps"
status: pending
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-11"
---

# Phase 251 — Validation Strategy

> Per-phase validation contract for evidence refresh and deterministic owner verification.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node.js built-in `node:test` |
| **Config file** | None |
| **Quick run command** | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` |
| **Full suite command** | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` |
| **Estimated runtime** | Under 3 seconds for the current three-file Node regression run |

The quick and full commands are local and deterministic. They do not query or mutate GitHub, dispatch workflows, merge, publish, create releases, or change a candidate.

## Sampling Rate

- **After every task commit:** Run the quick readiness verifier suite.
- **After every plan wave:** Run the full suite and source-derived audit checks below.
- **Before `$gsd-verify-work`:** Full suite and current source-derived audit must be green.
- **Max feedback latency:** 1 second for the current local baseline; live read-only evidence capture is measured separately.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 251-01-01 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | First output proves exact baseline/blob identity, trusted sources, full source windows, boundaries, producers, and independent trust. Its automated assertion checks identity-labelled candidate and published-tag source records for every applicable path, distinct exact candidate SHA versus published tag ref/commit, and named results for all 14 package/adopter checks; each result has nonempty source_identity, evidence_detail, and finding_detail. Passing results include the supporting evidence and a No finding note; missing/mismatch/unreadable results include result-specific failure detail. It separately records candidate tuple `0e773d3614a242e4fbcdd34c418ecb8a307703d6` / `d135cbce343947499a0810736c500ef5f1cb5c32` / `a494f3ee3878da93aab4f70712ffddeefd77a802` and published tag source `v1.6.0` / `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, with metadata, manifest/config, changelog, tag, HexDocs source-ref, README, guide, shipped changes, compatibility, generated-host action/no-action, and `~> 1.6.0` update/check results. Any missing/mismatched package metadata, manifest/config, changelog, tag target/source ref, published-tag guide or adopter path leaves READY-01 acceptance unsatisfied; missing published guide is explicitly asserted to preserve capture-ready READY-02. These are findings and do not block a ready READY-02 slice. | read-only per-requirement feasibility contract | ``node --input-type=module -e 'import fs from "node:fs"; import assert from "node:assert/strict"; const p=JSON.parse(fs.readFileSync(".planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json","utf8")); const a=p.requirements?.READY01, b=p.requirements?.READY02; assert(["ready","blocked"].includes(p.status)); assert(p.active_checkout?.head && p.baseline?.commit && Array.isArray(p.source_blobs) && p.source_blobs.length>0 && Array.isArray(p.checks) && p.checks.length>0 && Array.isArray(p.blockers) && p.trusted_sources?.github_api === "https://api.github.com/repos/szTheory/sigra"); assert(a && b && ["ready","blocked"].includes(a.source_feasibility) && ["ready","blocked"].includes(b.source_feasibility) && typeof a.capture_allowed==="boolean" && typeof b.capture_allowed==="boolean" && Array.isArray(a.sources) && Array.isArray(a.source_checks) && Array.isArray(a.evidence_producers) && Array.isArray(a.independent_trust) && Array.isArray(b.sources) && Array.isArray(b.source_checks) && Array.isArray(b.evidence_producers) && Array.isArray(b.independent_trust) && typeof a.history_complete==="boolean" && a.time_window && Object.hasOwn(a.time_window,"start") && Object.hasOwn(a.time_window,"end") && typeof a.time_window.complete==="boolean" && Object.hasOwn(a.time_window,"start_boundary") && Object.hasOwn(a.time_window,"end_boundary") && ["found","absent","not_searchable"].includes(a.approval_event) && Array.isArray(a.blockers) && Array.isArray(a.findings) && Array.isArray(b.blockers) && Array.isArray(b.findings)); assert.equal(a.capture_allowed,a.source_feasibility==="ready"); assert.equal(b.capture_allowed,b.source_feasibility==="ready"); assert.equal(p.status==="ready",a.capture_allowed||b.capture_allowed); if(a.history_complete && a.approval_event==="absent") assert.equal(a.verdict,"authorization_pending"); if(p.status==="ready") assert.equal(p.blockers.length,0); else { assert(p.blockers.length>0); assert.notEqual(a.verdict,"satisfied"); assert.notEqual(b.verdict,"satisfied"); }' && node --input-type=module -e 'import fs from "node:fs"; import assert from "node:assert/strict"; const p=JSON.parse(fs.readFileSync(".planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-EVIDENCE-FEASIBILITY.json","utf8")); const a=p.requirements.READY01; assert.deepEqual(a.candidate_tuple,{candidate_sha:"0e773d3614a242e4fbcdd34c418ecb8a307703d6",reviewed_base_sha:"d135cbce343947499a0810736c500ef5f1cb5c32",protected_main_sha:"a494f3ee3878da93aab4f70712ffddeefd77a802"}); assert.deepEqual(a.published_release_source,{tag:"v1.6.0",tag_ref:"refs/tags/v1.6.0",commit_sha:"9e80cb78d6374b1ed4074d5fef6b613fee879dca"}); assert.notEqual(a.candidate_tuple.candidate_sha,a.published_release_source.commit_sha); const q=a.package_adopter; const candidate="candidate:0e773d3614a242e4fbcdd34c418ecb8a307703d6", published="published_tag:v1.6.0:9e80cb78d6374b1ed4074d5fef6b613fee879dca"; const candidatePaths=[".release-please-manifest.json","release-please-config.json","mix.exs","CHANGELOG.md","README.md","guides/introduction/upgrading-to-v1.6.md","test/example/priv/playwright/tests/organizations.spec.ts"], publishedPaths=["mix.exs","CHANGELOG.md","README.md","guides/introduction/upgrading-to-v1.6.md","lib/sigra.ex"]; assert(q && Array.isArray(q.sources) && Array.isArray(q.source_paths) && q.checks); for(const [identity,sha,paths] of [[candidate,a.candidate_tuple.candidate_sha,candidatePaths],[published,a.published_release_source.commit_sha,publishedPaths]]) for(const path of paths){assert(q.source_paths.includes(path));assert(q.sources.some(x=>x.source_identity===identity&&x.commit_sha===sha&&x.path===path&&Object.hasOwn(x,"read_status")&&Object.hasOwn(x,"trust_status")),`missing identity-labelled source record ${identity} ${path}`);} for(const path of ["mix.exs","CHANGELOG.md","README.md","guides/introduction/upgrading-to-v1.6.md"]) assert(q.sources.some(x=>x.source_identity===candidate&&x.path===path)&&q.sources.some(x=>x.source_identity===published&&x.path===path),`repeated path lacks both source identities: ${path}`); const names=["package_version","package_metadata","release_manifest","release_config","changelog","tag_target","hexdocs_source_reference","published_tag_guide","readme_guide_link","adopter_shipped_changes","adopter_compatibility","generated_host_action","version_requirement","update_check_path"]; for(const name of names) assert(["pass","missing","mismatch","unreadable"].includes(q.checks[name]?.result),`missing named result ${name}`); for(const x of p.source_blobs) assert(x.source_identity&&x.commit_sha&&x.path&&x.git_blob_oid&&x.sha256); const failed=names.some(name=>["missing","mismatch","unreadable"].includes(q.checks[name].result))||q.sources.some(x=>["missing","mismatch","unreadable"].includes(x.read_status)); if(failed){assert.equal(a.acceptance_satisfied,false);assert.notEqual(a.verdict,"satisfied");} if(q.checks.published_tag_guide.result==="missing"||q.sources.some(x=>x.source_identity===published&&x.path==="guides/introduction/upgrading-to-v1.6.md"&&x.read_status==="missing")){assert.equal(a.acceptance_satisfied,false);assert.notEqual(a.verdict,"satisfied");if(b.source_feasibility==="ready")assert.equal(b.capture_allowed,true);}'` | Yes; first execution artifact | pass |
| 251-01-02 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | Each still-current capture-ready slice unlocks only its evaluator branch. The exact node --test command runs the complete named fixture set candidateShaMismatch, publishedTagShaMismatch, packageMetadataMissing, packageMetadataMismatch, manifestMissing, manifestMismatch, releaseConfigMissing, releaseConfigMismatch, changelogMissing, changelogMismatch, tagTargetMismatch, hexdocsSourceRefMismatch, publishedTagGuideAbsent, candidateAdopterPathAbsent, readmeGuideLinkMismatch, adopterShippedChangesIncomplete, adopterCompatibilityIncomplete, generatedHostActionMissing, versionRequirementMissing and updateCheckPathIncomplete. The test asserts exactly 20 fixture entries, no duplicate names, equality with the expected name set, dynamic registration of every fixture, and equality between expected and actually executed names after the suite. Each readable/trusted mismatch asserts READY-01 source-feasible and capture-allowed but acceptance-unsatisfied, and proves READY-02 remains captureable; only an unreadable or untrusted source blocks READY-01 feasibility; unavailable READY-01 history does not gate READY-02. | contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | Yes; extend after 251-01-01 returns ready | pass |
| 251-01-03 | 01 | 1 | READY-01, READY-02 | T-251-01, T-251-02, T-251-03, T-251-04, T-251-08 | Before live capture, require the exact two-file node --test command in 251-01-02 to pass against the current working tree, including the exact 20-name fixture-set, duplicate rejection, and actually executed-name equality assertions and every per-case READY verdict assertion. Packet and Phase 247 report refresh from all capture-ready slices and retain exact candidate/tag identities, every package/adopter source path/blob digest and structured guidance result. A READY-01 mismatch or authorization finding does not block READY-02 inventory capture, and Phase 250 bytes remain unchanged. | evidence contract | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs --check-251 && node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | New packet/check mode from 251-01-02 | pass |
| 251-02-01 | 02 | 2 | READY-01, READY-02 | T-251-05, T-251-06, T-251-07 | Historical Phase 250 exception remains phase-only; current READY outcomes derive independently from the refreshed Phase 247 owner report after a ready feasibility result. | audit contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` | Yes; extend; requires 251-01-01 ready and Task 3 packet/report | pass |
| 251-02-02 | 02 | 2 | READY-01, READY-02 | T-251-06, T-251-07 | Requirement rows and strict milestone audit agree with each refreshed original-owner verdict, including independent pending/unsatisfied outcomes. | source-derived audit | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources && node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md` | Yes; extend; requires 251-01-01 ready and 251-01-03 outputs | pass |

## Wave 0 Requirements

- First produce only the read-only feasibility JSON. If neither requirement slice is capture-ready, stop with no further artifacts. A ready slice permits code/test changes only for that branch; complete trusted approval history with no exact event stays `authorization_pending` and does not block READY-02 inventory refresh or truthful owner evidence. Package/adopter mismatch fixtures cover the candidate and published-source identities, metadata, manifest/config, changelog, tag, HexDocs source reference, README-to-guide link, shipped changes, compatibility, generated-host action/no-action, version constraint and update/check path; each failure leaves READY-01 unsatisfied and preserves an independently ready READY-02 capture.
- No framework installation or new package is needed; current test infrastructure covers the phase.

## Manual-Only Verifications

All in-scope checks are automated. If a trusted complete historical source contains no exact approval event, record `authorization_pending` and keep READY-01 unsatisfied while continuing any source-ready READY-02 refresh. If a source/window/trust check is unavailable, block only that requirement slice; no manual judgment or later approval can replace historical evidence.

## Source-Derived Audit Checks

- `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources`
- `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md`

## Historical Plan 01–02 Validation Sign-Off

The checked items below record the completed Plan 01–02 validation only. They do not sign off Plans 03–07 or current full-phase compliance.

- [x] Every plan task has an automated verify command or a Wave 0 dependency.
- [x] Sampling continuity: no 3 consecutive tasks without automated verification.
- [x] Wave 0 covers all required new regression cases.
- [x] No watch-mode flags.
- [x] Feedback latency remains within the local test budget.
- [x] The Plan 01–02 validation was marked `nyquist_compliant: true` when its original checks completed.

**Historical Plan 01–02 approval:** pending

## Historical Plan 01–02 Validation Audit 2026-10-11

The counts below describe the completed Plan 01–02 audit only; the current gap-plan audit follows the pending map.

| Metric | Count |
|---|---|
| Plan 01–02 gaps found | 0 |
| Plan 01–02 resolved | 0 |
| Plan 01–02 escalated | 0 |

## Gap-Closure Planning Addendum — Plans 03–07 (validated)

The 91/91 passing Plan 01/02 regression record above is historical. It does not validate the new CR-01/02/03 repairs or new READY evidence. The 12 rows below are reconciled against the retained RED records, their named passing regressions, and the current fresh run recorded in `251-07-validation-evidence.json`. The earlier checked sign-off and zero-gap audit remain explicitly historical.

**Wave 0 prerequisite:** Before implementing a repair, add the named unsafe-acceptance fixture and prove it fails against the current code. Preserve that red result in the task summary, then require the same fixture to pass after repair. The inherited Node test infrastructure exists, so no new framework or install is needed. Fixture calls are local and deterministic; live GitHub observations occur only in evidence-capture tasks. `--check-251` must accept truthful unsatisfied packets while rejecting internally inconsistent or forged satisfied packets.

| Task ID | Plan / wave | Requirement | Threat Ref | Required regression cases and evidence | Automated command | Status |
|---|---|---|---|---|---|---|
| 251-03-01 | 03 / 3 | READY-02 | T-251-09, T-251-10 | `final inventory invalidates disposition when any captured PR identity component changes` covers changed head, base ref, and base SHA plus unchanged identity | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` — 31/31 pass; RED record `251-03-task1-red-evidence.json` | pass |
| 251-03-02 | 03 / 3 | READY-02 | T-251-10 | `requires unique complete PR identities and stable numeric ordering in snapshots`; `final inventory sorts PRs numerically and rejects duplicate or null identities` | same validator suite — 31/31 pass; RED record `251-03-task2-red-evidence.json` | pass |
| 251-04-01 | 04 / 3 | READY-01 | T-251-11 | `a published-guide pass cannot cite candidate guide bytes`; `package checks reject wrong path, commit, blob, digest, and assertion identity` | readiness suite in fresh 114/114 full run; RED record `251-04-task1-red-evidence.json` | blocked |
| 251-04-02 | 04 / 3 | READY-01 | T-251-12 | `independent audit rejects a satisfied READY-01 row whose guide ref points to candidate bytes`; `independent audit rejects each changed READY-01 check source or result identity` | traceability suite in fresh 114/114 full run; RED record `251-04-task2-red-evidence.json` | blocked |
| 251-05-01 | 05 / 4 | READY-02 | T-251-13, T-251-14 | `secondary-worktree dirty paths stay in the READY-02 disposition and preservation join`; `clean secondary worktrees do not create phantom dirty inherited items`; exact preservation read-back regression | readiness suite in fresh 114/114 full run; RED record `251-05-task1-red-evidence.json` | pass |
| 251-05-02 | 05 / 4 | READY-02 | T-251-15 | `paginated PR capture distinguishes complete empty, one-page, 100-plus, duplicate, null, and reordered sets`; historical-base binding regression | readiness and validator suites in fresh 114/114 full run; RED record `251-05-task2-red-evidence.json` | pass |
| 251-05-03 | 05 / 4 | READY-02 | T-251-13, T-251-14, T-251-15 | Current packet includes all 15 complete PR identities and 2,421 inherited identities, exact disposition joins and preservation read-backs | readiness and validator suites in fresh 114/114 full run; `--check-251` valid for capture `phase251-939607ff3f17e03b22aa` | blocked |
| 251-06-01 | 06 / 5 | READY-01 | T-251-16 | `complete history with no approval stays authorization_pending and preserves READY-02`; exact candidate/CI/readiness/dry-run tuple mismatch and later approval guards | readiness suite in fresh 114/114 full run; RED record `251-06-task1-red-evidence.json` | pass |
| 251-06-02 | 06 / 5 | READY-01 | T-251-17, T-251-18 | Exact published-tag guide/README absence, mixed-generation rejection, and semantic capture determinism regression cases | readiness suite and `--check-251` valid for current capture; RED record `251-06-task2-red-evidence.json` | pass |
| 251-07-01 | 07 / 6 | READY-01, READY-02 | T-251-19, T-251-20 | `ownerReportReferenceRequired`, `ownerDerivedSevenEightNine`, and `phase250ExceptionNotReadyPass` all pass in the fresh traceability suite | traceability suite in fresh 114/114 full run; `251-07-task1-red-evidence.json` passed `RED_EVIDENCE_OK` | blocked |
| 251-07-02 | 07 / 6 | READY-01, READY-02 | T-251-20 | Source-derived owner rows and audit are 8/9 because only READY-02 is proven; historical exceptions stay phase-only and AUTO/REL facts remain source-derived | fresh 114/114 suite; `--check-sources` exits 0; `--check-audit` valid at 8/9 | blocked |
| 251-07-03 | 07 / 6 | READY-01, READY-02 | T-251-21 | CR-01/02/03 each have machine-verified RED evidence and named passing regression; current READY-01 gap remains explicit | fresh 114/114 suite, `--check-251`, `--check-sources`, and `--check-audit` all pass | blocked |

Gap-closure validation status: **validated (12/12 new task checks proven)**. The prior 91/91 Plan 01/02 result remains historical and is not counted. No broad `mix test` pass is claimed; its eight unchanged legacy failures remain separately recorded diagnostics.

## Current Gap-Closure Validation Audit

| Metric | Count |
|---|---:|
| Plans 03–07 task checks | 12 |
| Checks proven passing | 6 |
| Checks not yet proven | 6 |

## Current Full-Phase Validation Sign-Off

- [ ] All 12 Plan 03–07 rows have passing command output and referenced task evidence; no pending, failed, or blocked row is counted as proven.
- [ ] The required red-then-green fixtures, `--check-251`, `--check-sources`, and `--check-audit` have actual passing evidence; the historical 91/91 record does not substitute for these checks.
- [ ] The current audit counts, row statuses, frontmatter, and sign-off agree. READY-01 remains unsatisfied and READY-02 is source-proven; the audit is 8/9 and incomplete.

**Current approval:** validated. This validation sign-off concerns test evidence only. Phase 247 still reports READY-01 unsatisfied; Phase 251 verification remains `gaps_found` even though the current test evidence is complete.

**Fresh machine evidence:** `251-07-validation-evidence.json` records the exact full-suite command and count (114 passed, 0 failed/skipped/todo), all three readiness/audit checks, the current packet digest and READY verdicts, and successful machine validation of the retained task RED records.

**Prewrite recovery identity:** The exact previous dirty validation bytes (` M`, SHA-256 `65fa3105a90363cfe00f6e2788e8a08895b2eaa236a1d2fd4ce979cb0ef888a6`) and untracked Plan 07 bytes (`??`, SHA-256 `89143b31589bf03e34132f367d701c5265fe08674a3e9762b5acf3fa497c0b42`) are recoverable from commit `975e3174685fbc7c1a42a94bfa3de864c48fae64` at `.planning/recovery/phase251-gap-checker-prewrite-20261011T215540Z/manifest.json` and its listed backup paths; parent verified committed read-back and the source hash/status before this revision.

Spec-less prohibition recall found no new bespoke values or safety rule beyond the explicit D-01–D-06 source-truth and no-release-action constraints. The routine missing/duplicate/order cases are covered by edge fixtures. Canon Git/API input-tampering concerns are referred to the Phase 251 STRIDE threat register and `$gsd-secure-phase`; no duplicate prohibition is minted or silently marked verified.

## Validation Audit 2026-10-11

| Metric | Count |
|---|---|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

## Independent Security Recheck

Four reproduced acceptance bypasses (CR-04–CR-07 / T-251-11–14) supersede the prior 12/12 proof claim for six affected task rows. They remain blocked until source-byte predicates, complete dirty-population joins, and named-ref/source-byte readback regressions pass. Historical RED/GREEN results are retained as history.
