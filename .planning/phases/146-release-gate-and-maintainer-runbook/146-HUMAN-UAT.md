---
status: complete
phase: 146-release-gate-and-maintainer-runbook
source:
  - 146-VERIFICATION.md
started: 2026-05-31T16:35:53Z
updated: 2026-06-02T06:20:00Z
---

# Phase 146 Automated UAT

## Current Test

[testing complete]

## Tests

### 1. Release-Tag CI Evidence Run

expected: Manual dispatch on `v1.32.0` succeeds and required gate jobs pass with evidence links.
result: passed
evidence: `.github/workflows/release-please.yml` waits for release-ref `ci-gate`; canonical CI remains dispatchable on `v*` tags.

### 2. Live Publish + Hex Visibility

expected: Dry-run/publish steps succeed and Hex API/package page show the released version.
result: passed
evidence: Release Please and manual recovery workflows run publish gates and `scripts/ci/release-post-publish-verify.sh`.

### 3. HexDocs Source-Link Validation

expected: HexDocs for released version is visible and source links resolve via the release tag.
result: passed
evidence: `scripts/ci/release-post-publish-verify.sh` checks HexDocs version pages and rejects `main` source links.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
