---
phase: "248"
slug: "exact-source-release-gate"
status: draft
threats_open: 1
asvs_level: 1
created: "2026-10-08"
---

# Phase 248 — Security

> Per-phase security contract for the guarded release automation.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Release candidate to source gate | Tag, Release Please outputs, CI run metadata, and checked-out source are treated as separate claims until full commit identities agree. | Git refs, SHAs, CI conclusions |
| Candidate PR to merge workflow | PR metadata and workflow-run payloads are untrusted inputs to default-branch automation; source and current PR state are re-read before exact-head merge. | PR title, branch, labels, run ID, head SHA |
| Workflow to GitHub and Hex credentials | Privileged jobs use main-restricted environments; token permissions are job-scoped and Hex write credentials are passed only to the publish step. | GitHub token and Hex API keys |
| Workflow outputs to release receipts | Gate, publish, recovery, and observer data are validated as data before a durable artifact is written. | Run IDs, URLs, SHAs, verdicts, timestamps, diagnostics |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-248-01 | Tampering | `release-exact-source.sh` | high | mitigate | Require tag-resolved commit, Release Please SHA, and checkout `HEAD` to match before package setup; covered by helper fixtures and workflow contract. | closed |
| T-248-02 | Spoofing | `wait-for-ci-gate.sh` | high | mitigate | Require the successful `ci-gate` run's full head SHA to match the requested release SHA; preserve the bounded poll and report run identity. | closed |
| T-248-03 | Tampering | candidate preflight and merge workflow | high | mitigate | Validate one current candidate, metadata, content, and exact push-run SHA; re-read immediately before merge and use `--match-head-commit`. A content failure leaves the PR open. | closed |
| T-248-04 | Elevation of privilege | `release-pr-automerge.yml` | high | mitigate | Run trusted default-branch code, scope the release token to the guarded merge job, avoid admin bypass, and retain repository branch protection. | closed |
| T-248-05 | Elevation of privilege | Release Please, merge, and publish jobs | high | mitigate | Limit token permissions by job, use the `release-automation` environment for event-causing operations, isolate Hex dry-run and write keys by step, and keep the write key on final publication only. | closed |
| T-248-06 | Denial of service | release workflow concurrency | medium | mitigate | Give each evaluation a unique run/attempt concurrency identity and set `cancel-in-progress: false`. | closed |
| T-248-07 | Repudiation | receipt writer and terminal aggregator | high | mitigate | Validate full release, source, workflow, gate, timestamp, and verdict identity before atomic receipt replacement; reject malformed or credential-shaped data. | closed |
| T-248-08 | Tampering | receipt retries and failure notification | medium | mitigate | Preserve prior validated stage evidence for duplicate updates and upload the receipt before issue or label notification. | closed |
| T-248-09 | Elevation of privilege | trusted cancellation observer | high | mitigate | Use default-branch code and read-only permissions; re-query and validate repository, workflow, run, event, main branch, conclusion, and source SHA; do not download source artifacts or execute source code. | closed |
| T-248-10 | Repudiation | cancellation receipt path | medium | mitigate | Preserve the validated source event and source/observer links in the shared schema; make duplicate completion events idempotent. | closed |
| T-248-11 | Elevation of privilege | `release-automation` and `hex-publish` environments | high | mitigate | Move `RELEASE_PLEASE_TOKEN` into `release-automation` and `HEX_API_KEY` into `hex-publish`, remove their repository-level copies, and require exact-`main` deployment policies. Policies are verified, but name-only live checks show both environment copies absent and both repository copies present; workflow boolean checks cannot prove scope. | open |
| T-248-SC | Tampering | package-manager installation | low | accept | No additional npm, pip, or cargo package-manager installation is introduced by this phase. | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-248-SC | T-248-SC | Plan-time accepted risk: this phase adds no npm, pip, or cargo package-manager installation surface. | Phase plan disposition | 2026-10-08 |

## Operational Configuration Note

The live `release-automation` and `hex-publish` environment policies currently allow exactly `main`, with admin bypass disabled. Read-only name checks still show `RELEASE_PLEASE_TOKEN` and `HEX_API_KEY` only at repository scope; the environment copies have not been confirmed. Workflow jobs remain main-restricted and the secret preflight is fail-closed, but the one-time least-privilege secret transfer and repository-copy removal remain an external setup item in `248-USER-SETUP.md`. This note is not treated as proof that a release workflow or retained receipt has run.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-08 | 12 | 11 | 1 | Codex GSD security auditor (ASVS L1) |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [ ] `threats_open: 0` confirmed
- [ ] `status: verified` set in frontmatter

**Approval:** pending — environment secret transfer and repository-copy removal remain outstanding.

## Security Audit 2026-10-08

| Metric | Count |
|---|---|
| Threats found | 12 |
| Closed | 11 |
| Open | 1 |
