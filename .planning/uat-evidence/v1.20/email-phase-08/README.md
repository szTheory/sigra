---
phase: 08
gauat_requirement: GAUAT-02
hex_version: 0.2.5
git_sha: eaf0fd8
git_tag: 
ci_run_url: 
ci_workflow: .github/workflows/ci.yml / email_visual_regression
generated_by: mix sigra.uat.report --phase=08
generated_at: 2026-04-26T19:58:06Z
disposition: pass
---

# Phase 08: Lifecycle Email Visual Regression Evidence

**Baselines present:** 28/28  
**Git SHA:** `eaf0fd8`  
**Generated at:** 2026-04-26T19:58:06Z  

| Template | Engine | Theme | Outcome | SHA-256 (first 16) | Bytes |
|----------|--------|-------|---------|--------------------|-------|
| email-change-confirmation | chromium | light | pass | `daeb2e592b5e2f7d` | 43269 |
| email-change-confirmation | chromium | dark | pass | `daeb2e592b5e2f7d` | 43269 |
| email-change-confirmation | webkit | light | pass | `25e027df27edde6b` | 59466 |
| email-change-confirmation | webkit | dark | pass | `25e027df27edde6b` | 59466 |
| email-change-notification | chromium | light | pass | `50813ea8e5a8daca` | 49327 |
| email-change-notification | chromium | dark | pass | `50813ea8e5a8daca` | 49327 |
| email-change-notification | webkit | light | pass | `1aaf9448465ebadc` | 66784 |
| email-change-notification | webkit | dark | pass | `1aaf9448465ebadc` | 66784 |
| email-changed | chromium | light | pass | `d7b1697bcdd08ca4` | 35218 |
| email-changed | chromium | dark | pass | `d7b1697bcdd08ca4` | 35218 |
| email-changed | webkit | light | pass | `662df8a91fb56aa6` | 50473 |
| email-changed | webkit | dark | pass | `662df8a91fb56aa6` | 50473 |
| password-changed | chromium | light | pass | `9385e6ddafaf0bef` | 44894 |
| password-changed | chromium | dark | pass | `9385e6ddafaf0bef` | 44894 |
| password-changed | webkit | light | pass | `232430050e7c689a` | 61014 |
| password-changed | webkit | dark | pass | `232430050e7c689a` | 61014 |
| deletion-scheduled | chromium | light | pass | `a2bd591faa13c55b` | 47971 |
| deletion-scheduled | chromium | dark | pass | `a2bd591faa13c55b` | 47971 |
| deletion-scheduled | webkit | light | pass | `b68d7103fe7443db` | 63983 |
| deletion-scheduled | webkit | dark | pass | `b68d7103fe7443db` | 63983 |
| deletion-cancelled | chromium | light | pass | `9dc402f1fbb39b00` | 32747 |
| deletion-cancelled | chromium | dark | pass | `9dc402f1fbb39b00` | 32747 |
| deletion-cancelled | webkit | light | pass | `dbe52b90b857fd4d` | 47454 |
| deletion-cancelled | webkit | dark | pass | `dbe52b90b857fd4d` | 47454 |
| deletion-finalized | chromium | light | pass | `4839209bb59dd658` | 34393 |
| deletion-finalized | chromium | dark | pass | `4839209bb59dd658` | 34393 |
| deletion-finalized | webkit | light | pass | `8d8b3fe511371da4` | 48382 |
| deletion-finalized | webkit | dark | pass | `8d8b3fe511371da4` | 48382 |

## Baseline path

`test/example/priv/playwright/__snapshots__/email-visual.spec.ts/`
