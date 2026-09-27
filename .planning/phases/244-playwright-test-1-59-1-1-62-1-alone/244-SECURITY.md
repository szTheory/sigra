---
phase: "244"
slug: "playwright-test-1-59-1-1-62-1-alone"
status: verified
threats_open: 0
open_total: 0
asvs_level: 1
block_on: high
created: "2026-09-26"
updated: "2026-09-26"
---

# Phase 244 — Security

> Security enforcement is active. All 15 registered mitigations were verified closed on 2026-09-26. No risk was accepted or waived.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Workflow input to shell/filesystem | Capture paths and refs must stay inside the committed source inventory. | Git refs, image paths, runner inputs |
| External packages to CI | npm packages and comparator packages are external supply-chain inputs. | Package archives, integrity and provenance |
| GitHub API to evidence | PR, run, job, and step responses can be stale, incomplete, or malformed. | Run IDs, SHAs, PR refs, job/step outcomes |
| CI artifacts to merge/defer decision | Receipts must bind visual results to the correct candidate and live repository state. | Measurement manifest, final-main receipt, disposition |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-244-01 | Tampering | render inventory input | high | mitigate | Derive paths from `git ls-tree` at the source SHA; reject traversal, missing, and extra paths. | closed |
| T-244-02 | Spoofing | measurement identity | medium | mitigate | Bind run ID, run URL, source SHA, and authorized workflow route to structured workflow context. | closed |
| T-244-03 | Information disclosure | uploaded artifacts | low | mitigate | Grant contents-read only and upload scoped render/log outputs without process environment or tokens. | closed |
| T-244-14 | Elevation of privilege | dispatch routes | high | mitigate | Restrict the measurement workflow to explicit phase refs; require safe exact-main inputs and exclude write-capable recapture jobs. | closed |
| T-244-04 | Tampering | npm upgrade | high | mitigate | Validate package identity and lockfile integrity against registry metadata and provenance before installation. | closed |
| T-244-05 | Tampering | image comparator | high | mitigate | Pin/check Ubuntu ImageMagick identity and strictly parse comparator output with negative fixtures. | closed |
| T-244-SC | Tampering | npm install | high | mitigate | Require verified registry signature, provenance, and official release identity before candidate installation. | closed |
| T-244-06 | Spoofing | PR/check provenance | high | mitigate | Verify run ID, source SHA, PR number/head SHA, exact manifest digest, and an artifact that explicitly reports `expired: false` in both live and persisted provenance. | closed |
| T-244-07 | Tampering | paired render roots | high | mitigate | Verify exact source-tree equality after installation, excluding only the explicitly allowed package/lock changes. | closed |
| T-244-08 | Repudiation | failed measurement | medium | mitigate | Preserve run identity, source SHA, per-image results, verdict, and diagnostics on failed measurements. | closed |
| T-244-09 | Elevation of privilege | merge decision | high | mitigate | Require zero drift, a live authorized candidate, refreshed base, and exact successful required checks. If a required-workflow result lacks matching repository/path/ref/SHA evidence, keep it unverified and ineligible. The captured policy has no required-workflow rules. | closed |
| T-244-10 | Repudiation | defer outcome | medium | mitigate | Persist disposition inputs, PR state, measurement result, and an actionable deferred follow-up. | closed |
| T-244-11 | Spoofing | final run SHA | high | mitigate | Re-read main before and after collection and require the run SHA to match the unchanged main SHA. | closed |
| T-244-12 | Tampering | API job/step list | high | mitigate | Exhaust pagination and require each named job and browser/aggregate step exactly once with successful completion. | closed |
| T-244-13 | Denial of service | GitHub API quota | medium | mitigate | Use one CI watcher at 60-second intervals, preflight quota, and stop on 403/429. | closed |

### Resolved Gap Evidence

- **T-244-04 and T-244-SC (high):** Plan 244-02's blocking checkpoint recorded a fresh `OK` before candidate installation. The tarball SHA-512 matched registry integrity; SLSA provenance matched the Microsoft Playwright v1.62.1 release workflow, tag, and commit; the publisher was GitHub Actions OIDC; and the Microsoft release signature was verified (`244-02-PLAN.md:70,75-76`; `244-02-SUMMARY.md:99-102`). A fresh `npm audit signatures` independently verified 51 registry signatures and 11 provenance attestations.
- **T-244-06 (high):** Run/artifact and exact-manifest-byte checks are enforced in `scripts/ci/measure-playwright-drift.mjs`; artifact records must explicitly report `expired: false` in both live verification and persisted authorization; the receipt records the provenance digest at `244-PLAYWRIGHT-EVIDENCE.json:2409,2416`; all 53 structured provenance/eligibility tests pass.
- **T-244-07 (high):** `scripts/ci/verify-playwright-source-tree.sh` compares source trees and package transforms; `scripts/ci/run-playwright-drift.sh` invokes it after each install and before browser/capture work. Hermetic positive and negative fixtures pass.
- **T-244-09 (high):** `scripts/ci/measure-playwright-drift.mjs` requires provenance, zero drift, current PR/head/base, and successful required checks. If future policy adds required workflows, repository/path/ref/SHA must match; missing SHA evidence remains unverified. The captured policy has no required-workflow entries. The current receipt correctly records `merge_eligible: false` because measured drift exists and PR #213 is closed; the offline receipt validator passes.
- **T-244-13 (medium):** `scripts/ci/capture-phase-244-final-main.sh` records exactly one 60-second watcher, quota preflight above the 250-request threshold, and a no-retry stop policy for 403/429. The receipt for run `36266022766` validates, and the hard-stop fixtures pass.

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-26 | 15 | 11 | 4 (3 blocking, 1 below threshold) | gsd-security-auditor |
| 2026-09-26 | 15 | 15 | 0 | gsd-security-auditor |
| 2026-09-26 | 15 | 15 | 0 | gsd-security-auditor (post-review recheck at ba4169fe) |

## Sign-Off

- [x] All threats have a disposition (`mitigate`).
- [x] No risks were accepted.
- [x] `threats_open: 0` confirmed.
- [x] `status: verified` set in frontmatter.

**Approval:** secured — all 15 registered threats verified closed on 2026-09-26.
