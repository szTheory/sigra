---
phase: 88
gauat_requirement: GAUAT-07
hex_version: 0.2.5
git_sha: bf05676
git_tag: 
ci_run_url: 
ci_workflow: .github/workflows/ci.yml / mfa_e2e_playwright
generated_by: mix sigra.uat.report --phase=mfa-backup-rotation
generated_at: 2026-04-28T20:42:49Z
disposition: pass
---

# GAUAT-07: MFA Backup-Code Rotation Evidence

**Evidence rows present:** 4/4  
**Git SHA:** `bf05676`  
**Generated at:** 2026-04-28T20:42:49Z  

| Artifact class | Outcome | Evidence path | SHA-256 (first 16) |
|----------------|---------|---------------|--------------------|
| ui-rotation-flow | pass | `reports/ui-summary.json` | `29c000b0d479ac00` |
| old-code-invalidated | pass | `reports/old-code-validity.json` | `804e131b7dff7225` |
| audit-event-persisted | pass | `reports/audit-event.json` | `d5b5e59678e5dabf` |
| transcript | pass | `transcript.log` | `16428d69dddf93df` |
