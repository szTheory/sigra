---
phase: 249-publish-and-prove-sigra-1-6-0
reviewed: 2026-10-10T00:00:00Z
depth: deep
files_reviewed: 2
files_reviewed_list:
  - scripts/ci/release-public-proof.sh
  - scripts/ci/release-public-proof.test.sh
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 249: Code Review Report

**Reviewed:** 2026-10-10T00:00:00Z  
**Depth:** deep  
**Files Reviewed:** 2  
**Status:** issues_found

## Summary

The repaired URL check rejects lookalike domains, credentials with nonempty user or password, non-HTTPS schemes, non-default ports, nonmatching paths, and populated query/fragment values. Legitimate Hex API URLs and both documented HexDocs redirect hosts/paths pass. One edge case remains: WHATWG `URL.search`, `URL.hash`, `URL.username`, and `URL.password` are empty for delimiter-only query/fragment and empty user-info syntax, so those forms bypass the corresponding rejection checks.

## Critical Issues

### CR-01: Empty query, fragment, and user-info delimiters bypass URL rejection

**File:** `scripts/ci/release-public-proof.sh:126-127`

**Issue:** The check tests parsed component values (`url.search`, `url.hash`, `url.username`, and `url.password`) for truthiness. Node’s WHATWG URL parser normalizes `https://hex.pm/api/packages/sigra/releases/1.6.0?`, the same URL followed by `#`, and `https://@hex.pm/api/packages/sigra/releases/1.6.0` to empty component values. `trusted_service_destination` therefore accepts those URLs when the remaining host/path are valid, despite the policy requiring any query, fragment, or credentials to be rejected. The supplied redirect fixtures do not cover these delimiter-only forms, so the current 54/54 result does not exercise this boundary.

**Fix:** Reject the presence of URL user-info and query/fragment delimiters independently of component contents (for example, inspect a canonical serialized URL or parse the raw authority and delimiter presence safely). Add Hex and HexDocs fixtures for trailing `?`, trailing `#`, and empty user-info (`@`) and assert each blocks before a success receipt.

## Verification

`bash scripts/ci/release-public-proof.test.sh` passed 54/54. Direct Node checks confirmed that URL parsing produces empty `search`, `hash`, `username`, and `password` values for the three forms described above. Existing positive fixtures exercise the valid Hex release endpoint and HexDocs redirect to `sigra.hexdocs.pm`.

---

_Reviewed: 2026-10-10T00:00:00Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: deep_
