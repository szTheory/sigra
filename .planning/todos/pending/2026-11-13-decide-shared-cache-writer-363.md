---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Decide whether to keep the shared-cache writer (PR #363) that landed without its proof stack
area: ci
severity: minor
source: v1.50 branch triage (CI-machinery review)
files:
  - .github/workflows
---

The Phase 255.1 shared-cache writer workflow, runner-image helper and Playwright OS-deps helper are on main; the evidence stack that was meant to prove they speed CI was never landed and no hosted before/after exists. Either measure a real before/after (5+ hosted runs) and keep, or remove. Until then treat any CI-speed claim as unproven.
