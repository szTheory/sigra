---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Decide whether to cut the automated UI-process machinery that still lives on main
area: ci
severity: minor
source: v1.50 branch triage; owner steer toward a component catalog and away from Playwright baselines
files:
  - .github/workflows/ci.yml
  - test/example/priv/playwright
---

Main still carries nightly jobs `admin_design_recapture`, `admin_checkpoint_recapture`, `admin_eval_render`, ~115 baseline PNGs and the autofix/eval-harness/snapshot-guard/drift scripts. The owner expects a Storybook-style catalog to replace most of this and considers the old process inefficient. Do NOT cut it as part of a brand or CI-hygiene PR: schedule it deliberately, keep the independent protections (real-login and generated-host smoke, axe a11y gate, golden install fixtures), and write the replacement (catalog-based admin screens) first.
