---
created: 2026-05-08T00:00:00.000Z
title: Resolve lingering working-tree changes on chore/phase-88-uat-evidence
area: ci
files:
  - .planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/subscription-detail.png
  - scripts/ci/admin-acceptance-smoke.sh
  - test/example/lib/example_web/controllers/test_db_probe_controller.ex
---

## Problem

Branch `chore/phase-88-uat-evidence` has three modified files lingering in the working tree:

- `.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/subscription-detail.png`
- `scripts/ci/admin-acceptance-smoke.sh`
- `test/example/lib/example_web/controllers/test_db_probe_controller.ex`

Recent commits on this branch (`7f4cc76`, `16c0a85`, `9479348`, `b93a595`, `a9be1f5`) suggest CI/install-contract repair work. The three uncommitted files might be the next layer of the same fixes, or they might be stale local edits that shouldn't ship.

## Solution

Decide before the next milestone starts:

- `git diff` each file to determine intent
- Either commit them (if they belong to the phase-88 evidence + CI repair line), revert (if stale local edits), or roll into the first phase of the next milestone (if part of a new direction)
- Don't let them rot — the v1.24 milestone is archived, and starting EMAIL-RAILS with three loose files is a recipe for noise.
