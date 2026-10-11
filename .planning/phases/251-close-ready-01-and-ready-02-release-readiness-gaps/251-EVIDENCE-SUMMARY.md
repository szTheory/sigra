# Phase 251 Evidence Summary

- **Packet:** `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-247-RECONCILIATION.json`
- **Packet SHA-256:** `ef19258ecad5834d026699a413b44e9477531fc4d1ff99a2424c93e9e7d268e9`
- **Captured at:** 2026-10-11T22:37:54.627Z
- **Candidate tuple:** `0e773d3614a242e4fbcdd34c418ecb8a307703d6` / `d135cbce343947499a0810736c500ef5f1cb5c32` / `a494f3ee3878da93aab4f70712ffddeefd77a802`
- **Published release:** `v1.6.0` → `9e80cb78d6374b1ed4074d5fef6b613fee879dca`

| Requirement | Verdict | Source ready | Capture allowed |
|---|---|---|---|
| READY-01 | authorization_pending | blocked | false |
| READY-02 | satisfied | ready | true |

## Findings

- authorization_pending: complete review/timeline history has zero reviews and no exact-candidate approval.
- missing: published tag lacks the v1.6 guide.
- mismatch: published README omits the guide link.
- package_check_source_refs_invalid:package_version
- package_check_source_refs_invalid:package_metadata
- package_check_source_refs_invalid:release_manifest
- package_check_source_refs_invalid:release_config
- package_check_source_refs_invalid:changelog
- package_check_source_refs_invalid:tag_target
- package_check_source_refs_invalid:hexdocs_source_reference
- package_check_missing:published_tag_guide
- package_check_mismatch:readme_guide_link
- package_check_source_refs_invalid:adopter_shipped_changes
- package_check_source_refs_invalid:adopter_compatibility
- package_check_source_refs_invalid:generated_host_action
- package_check_source_refs_invalid:version_requirement
- package_check_source_refs_invalid:update_check_path
- authorization_pending
- Historical owner report commit 0e7a2835ebd0d7a1e791ad4dbc73955270108ed1 is locally readable but GitHub REST returns 404, so this required immutable source cannot be independently trusted.
- READY01_preflight_source_blocked
- Prior inventory is historical; Task 3 must capture a fresh complete open-PR and inherited-work inventory before dispositions.
