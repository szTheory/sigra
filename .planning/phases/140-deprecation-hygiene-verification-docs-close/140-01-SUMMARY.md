---
phase: 140-deprecation-hygiene-verification-docs-close
plan: "01"
subsystem: auth
tags: [elixir, deprecation, exdoc, annotations]

requires:
  - phase: 137-optional-dependency-source-of-truth
    provides: OptionalDeps SOT consolidation (context for deprecation hygiene wave)
  - phase: 139-recipe-contract-fixture-verification
    provides: Phase 139 wave complete — all Wave 1 substrate landed

provides:
  - "DEPR-02: Sigra.MFA.Trust.cookie_opts/0 carries removal target 0.4.0 in both @doc deprecated: and @deprecated"
  - "DEPR-01: Sigra.Account.audit_forced_password_change/2 carries removal target 0.5.0 in @deprecated"

affects:
  - 140-02-PLAN (PROOF-01 proof bundle execution)
  - 140-03-PLAN (DOC-01 guides/MAINTAINING.md appends)

tech-stack:
  added: []
  patterns:
    - "Elixir deprecation annotation hygiene: append removal target to existing @deprecated/@doc deprecated: strings without weakening migration guidance"

key-files:
  created: []
  modified:
    - lib/sigra/mfa/trust.ex
    - lib/sigra/account.ex

key-decisions:
  - "Removal targets expressed as Hex SemVer 0.x minors (0.4.0, 0.5.0), never v1.x planning labels (D-01)"
  - "cookie_opts/0 has both @doc deprecated: and @deprecated — both updated in sync (D-02, D-04)"
  - "audit_forced_password_change/2 has only @deprecated — no @doc deprecated: added (D-03; avoids duplicate display in ExDoc)"
  - "All edits are additive string appends; existing migration guidance preserved verbatim (D-04)"

patterns-established:
  - "Pattern: When both @doc deprecated: and @deprecated are present, both must be updated to stay in sync for ExDoc + compiler warning parity"
  - "Pattern: When only @deprecated is present (soft-deprecated function), do not add @doc deprecated: to avoid duplicate ExDoc display"

requirements-completed:
  - DEPR-01
  - DEPR-02

duration: 5min
completed: 2026-05-29
---

# Phase 140 Plan 01: Deprecation Annotation Removal-Target Hygiene Summary

**Appended Hex SemVer removal targets to both live deprecated functions: cookie_opts/0 schedules removal in 0.4.0, audit_forced_password_change/2 in 0.5.0**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-29T18:09:00Z
- **Completed:** 2026-05-29T18:14:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Appended " Scheduled for removal in 0.4.0." to both `@doc deprecated:` and `@deprecated` attributes for `Sigra.MFA.Trust.cookie_opts/0` (trust.ex:43-44)
- Appended " Scheduled for removal in 0.5.0." to the single `@deprecated` attribute for `Sigra.Account.audit_forced_password_change/2` (account.ex:543)
- All existing migration guidance preserved verbatim; no function bodies changed; `MIX_ENV=test mix compile --no-deps-check` exits 0

## Task Commits

Each task was committed atomically:

1. **Task 1: Append removal target 0.4.0 to cookie_opts/0 deprecation annotations (DEPR-02)** - `8e56fb5` (docs)
2. **Task 2: Append removal target 0.5.0 to audit_forced_password_change/2 deprecation annotation (DEPR-01)** - `3ed7133` (docs)

## Files Created/Modified
- `lib/sigra/mfa/trust.ex` — Both @doc deprecated: and @deprecated for cookie_opts/0 now end with "Scheduled for removal in 0.4.0."
- `lib/sigra/account.ex` — @deprecated for audit_forced_password_change/2 now ends with "Scheduled for removal in 0.5.0."

## Decisions Made
- Removal targets are Hex SemVer 0.x minors (D-01): 0.4.0 for the already-raising stub (cookie_opts/0), 0.5.0 for the still-functional soft-deprecated function (audit_forced_password_change/2)
- No @doc deprecated: added to audit_forced_password_change/2 — it uses @deprecated only; adding @doc deprecated: would cause duplicate deprecation display in ExDoc

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## Known Stubs
None — no stubs introduced. This plan is docstring-only appends to @deprecated annotations.

## Threat Flags
None — edits are docstring-only string appends to @deprecated annotations. No new network endpoints, auth paths, file access patterns, or schema changes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DEPR-01 and DEPR-02 requirements satisfied; ready for Wave 2
- Plan 140-02 (PROOF-01: six-gate proof bundle execution) can proceed — both source files compile clean and carry the removal-target strings that Gate 8 (docs-render grep) will assert against

---
*Phase: 140-deprecation-hygiene-verification-docs-close*
*Completed: 2026-05-29*

## Self-Check: PASSED

- lib/sigra/mfa/trust.ex: FOUND
- lib/sigra/account.ex: FOUND
- 140-01-SUMMARY.md: FOUND
- Commit 8e56fb5 (DEPR-02): FOUND
- Commit 3ed7133 (DEPR-01): FOUND
