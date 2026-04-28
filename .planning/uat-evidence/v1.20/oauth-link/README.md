---
phase: 87
gauat_requirement: GAUAT-05
hex_version: 0.2.5
git_sha: 367a164
git_tag: 
ci_run_url: 
ci_workflow: .github/workflows/ci.yml / oauth_e2e_playwright
generated_by: mix sigra.uat.report --phase=oauth-link
generated_at: 2026-04-28T11:42:07Z
disposition: pass
---

# GAUAT-05: OAuth Link/Unlink Evidence

**Evidence rows present:** 4/4  
**Git SHA:** `367a164`  
**Generated at:** 2026-04-28T11:42:07Z  

| Artifact class | Outcome | Evidence path | SHA-256 (first 16) |
|----------------|---------|---------------|--------------------|
| linked-with-password | pass | `reports/db-probe-results.json` | `8f2a1de0e8dff3a4` |
| only-oauth-no-password | pass | `snapshots/oauth-link__disabled-tooltip__sha-367a164.png` | `7b0ba20923326b0b` |
| after-set-password | pass | `reports/db-probe-results.json` | `8f2a1de0e8dff3a4` |
| post-unlink | pass | `reports/db-probe-results.json` | `8f2a1de0e8dff3a4` |
