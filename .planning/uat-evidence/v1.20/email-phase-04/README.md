---
phase: 04
gauat_requirement: GAUAT-01
hex_version: 0.2.5
git_sha: 6ce3cd3
git_tag: 
ci_run_url: 
ci_workflow: .github/workflows/ci.yml / email_visual_regression
generated_by: mix sigra.uat.report --phase=04
generated_at: 2026-04-26T18:47:22Z
disposition: pass
---

# Phase 04: Security Email Visual Regression Evidence

**Baselines present:** 8/8  
**Git SHA:** `6ce3cd3`  
**Generated at:** 2026-04-26T18:47:22Z  

| Template | Engine | Theme | Outcome | SHA-256 (first 16) | Bytes |
|----------|--------|-------|---------|--------------------|-------|
| lockout-notification | chromium | light | pass | `b6436e2c37dce18d` | 46983 |
| lockout-notification | chromium | dark | pass | `b6436e2c37dce18d` | 46983 |
| lockout-notification | webkit | light | pass | `8f6c4179cbf1b5fb` | 63587 |
| lockout-notification | webkit | dark | pass | `8f6c4179cbf1b5fb` | 63587 |
| suspicious-login | chromium | light | pass | `afa2c49f81f5c233` | 46761 |
| suspicious-login | chromium | dark | pass | `afa2c49f81f5c233` | 46761 |
| suspicious-login | webkit | light | pass | `b9412ee4b48a3e77` | 62864 |
| suspicious-login | webkit | dark | pass | `b9412ee4b48a3e77` | 62864 |

## Baseline path

`test/example/priv/playwright/__snapshots__/email-visual.spec.ts/`
