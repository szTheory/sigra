---
phase: "244"
slug: "playwright-test-1-59-1-1-62-1-alone"
status: blocked
threats_open: 3
open_total: 4
asvs_level: 1
block_on: high
created: "2026-09-26"
updated: "2026-09-26"
---

# Phase 244 — Security

> Security enforcement is active. Eleven registered mitigations were verified; three high-severity mitigations remain open and block phase advancement. One medium-severity operational-control threat remains open below the configured blocking threshold. No risk was accepted or waived.

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
| T-244-06 | Spoofing | PR/check provenance | high | mitigate | Verify run ID, source SHA, PR number/head SHA, and a measurement-manifest digest against structured API fields. | open — blocking |
| T-244-07 | Tampering | paired render roots | high | mitigate | Verify exact source-tree equality after installation, excluding only the explicitly allowed package/lock changes. | open — blocking |
| T-244-08 | Repudiation | failed measurement | medium | mitigate | Preserve run identity, source SHA, per-image results, verdict, and diagnostics on failed measurements. | closed |
| T-244-09 | Elevation of privilege | merge decision | high | mitigate | Require zero drift, a live authorized candidate, refreshed base, and successful current required checks before declaring merge eligibility. | open — blocking |
| T-244-10 | Repudiation | defer outcome | medium | mitigate | Persist disposition inputs, PR state, measurement result, and an actionable deferred follow-up. | closed |
| T-244-11 | Spoofing | final run SHA | high | mitigate | Re-read main before and after collection and require the run SHA to match the unchanged main SHA. | closed |
| T-244-12 | Tampering | API job/step list | high | mitigate | Exhaust pagination and require each named job and browser/aggregate step exactly once with successful completion. | closed |
| T-244-13 | Denial of service | GitHub API quota | medium | mitigate | Use one CI watcher at 60-second intervals, preflight quota, and stop on 403/429. | open — below high threshold |

### Open Threat Evidence

- **T-244-06 (high):** `scripts/ci/measure-playwright-drift.mjs:61-73,417-430` validates embedded run/source identity and inventory paths, but does not verify structured GitHub API fields or persist/check a digest for the full measurement manifest. The committed evidence records run/SHA and PR/head fields without a full manifest digest (`244-PLAYWRIGHT-EVIDENCE.json:4-16,2055-2078`).
- **T-244-07 (high):** `scripts/ci/run-playwright-drift.sh:37-58` starts both capture roots from the same source archive and validates the package trio, but does not compare source trees after installation/capture with only the package/lock change allowed.
- **T-244-09 (high):** `scripts/ci/measure-playwright-drift.mjs:121-127,204-216` derives `merge_eligible` from the pixel verdict. It does not enforce the live PR/ref/base/current-check conditions required by the plan. The current nonzero-drift receipt safely defers the closed PR, but does not implement the zero-drift authorization guard (`244-PLAYWRIGHT-EVIDENCE.json:1814-1818,2050-2078`).
- **T-244-13 (medium):** `scripts/ci/capture-phase-244-final-main.sh:36-38` preflights API quota and hard-stops on 403/429, and its receipt retains quota/reset information. The one-watcher/60-second interval requirement is not machine-recorded or enforced by the collector.

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-26 | 15 | 11 | 4 (3 blocking, 1 below threshold) | gsd-security-auditor |

## Sign-Off

- [x] All threats have a disposition (`mitigate`).
- [x] No risks were accepted.
- [ ] `threats_open: 0` confirmed.
- [ ] `status: verified` set in frontmatter.

**Approval:** blocked — resolve T-244-06, T-244-07, and T-244-09, then rerun `$gsd-secure-phase 244`.
