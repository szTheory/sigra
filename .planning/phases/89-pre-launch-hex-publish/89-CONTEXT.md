# Phase 89 Context: Pre-launch — Hex publish + README promotion + CHANGELOG/ExDoc alignment

## Goal
Make Sigra v1.20 publicly installable from Hex.pm and update README + ExDoc + CHANGELOG so adopters see "use this in production" framing with v1.20 evidence pointers. Maps to v1.5 `MAINT-01` First Public Launch checklist rows: Hex publish, README promotion, CHANGELOG finalization. The announcement post itself is held until Phase 90.

## Requirements
- **LAUNCH-01** — **Hex.pm publish v1.20**: Bump `mix.exs` version to `1.20.0`; tag `v1.20` annotated; `mix hex.publish` (with reviewable diff against the prior published version, if any); verify package shows on hex.pm with correct description, links, optional-deps, and ExDoc. Record release URL. (If this is Sigra's first-ever Hex publish, also covers `mix hex.user auth` setup if not already configured.)
- **LAUNCH-02** — **README "use this in production" promotion**: Update README from "production readiness available" framing to an explicit "Use this in production" section with: link to v1.20 GA evidence, link to Phase 9 C-1 PASS attestation (post-AUD-21), getting-started link, version-pin guidance. ExDoc landing path mirrors the change.
- **LAUNCH-07** — **CHANGELOG + ExDoc final alignment**: `CHANGELOG.md` v1.20.0 section finalized: covers AUD-21 (audit completeness PASS), GAUAT closure pointer, launch metadata, upgrade notes (none expected — pure additive). ExDoc extras include `upgrading-to-v1.20.md` (or "no upgrade required" stub if changeset is purely additive); `mix docs --warnings-as-errors` clean.

## Dependencies & Blockers
1. **Phase 85**: Hex package description and README must reference Phase 9 C-1 PASS (Completed).
2. **Phase 88**: README promotion is only honest after UAT results are green.
   - **BLOCKER**: According to `.planning/v1.20-GA-UAT-RESULTS.md`, `GAUAT-03..06` are currently `BLOCKED` due to missing remote CI provenance (`ci_run_url`).
   - The document explicitly states: *"Phase 89 cannot promote the README to 'use this in production' on the strength of Phase 88 alone, because GAUAT-03..06 remain blocked on remote CI provenance."*

## Execution Strategy
Before we can fully execute Phase 89 (specifically LAUNCH-02), we must:
1. **Clear the Blocker**: Ensure the latest commits (which are currently unstaged/uncommitted) are pushed to GitHub Actions to generate the `ci_run_url`. Update `v1.20-GA-UAT-RESULTS.md` to `PASS` status.
2. **Hex Configuration**: Ensure the executing environment has `mix hex.user auth` configured with the publishing maintainer credentials.
3. **Bump and Publish**: Update `mix.exs` version from `0.2.5` to `1.20.0`. Finalize `CHANGELOG.md`. Tag the release and run `mix hex.publish`.
4. **Update README**: Update the `README.md` to promote "Use this in production" with all required evidence links.

## Verification
Phase 89 will produce `89-VERIFICATION.md` recording the Hex publish URL, the published version diff against the prior tag, and an attestation that the v1.5 `MAINT-01` checklist rows for "Hex publish", "README promotion", and "CHANGELOG finalization" are checked off with evidence URLs.
