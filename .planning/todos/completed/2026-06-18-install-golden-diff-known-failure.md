---
created: 2026-06-18T00:00:00.000Z
status: pending
title: golden_diff_test.exs known failure — generated-tree byte diff vs committed fixture
area: test
files:
  - test/sigra/install/golden_diff_test.exs
source: phase 192 quarantine (D-11/D-12)
---

## What

`test/sigra/install/golden_diff_test.exs` fails with a generated-tree byte diff
vs the committed fixture in `test/fixtures/install_golden/`. Reproduces identically
on clean `origin/main` — not a phase-192 regression.

## Fix direction

Update the install golden fixture: run `mix sigra.install --yes` in a fresh app,
normalize the tree, and commit the updated fixture per the runbook in
`.planning/phases/11-generator-feature-system/11-01-SUMMARY.md`. Confirm the template
and the example are in sync first.

## Quarantine

Tagged `@moduletag known_failure: "..."` in phase 192. Remove the tag when the fixture
is updated and the test is green on both local and CI.
