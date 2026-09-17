---
created: 2026-09-17T00:00:00.000Z
status: pending
title: The p19 known-bad fixture short-circuits at `enforcement`, so its second declared violation is never asserted
area: ci
severity: trivial
source: phase 238 code review (IN-01)
files:
  - test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json
  - scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
---

## Problem

`rulesetShapeIssue` checks `enforcement` (`p19-tag-namespace-ruleset.test.mjs:144-149`) before it
checks the rule/conditions shape (`:159-168`). The known-bad fixture violates both, so the first
check returns and the second violation it was built to exercise is never reached. The RED proof
is genuine — the fixture does go red — but it proves one assertion, not the two it declares.

## Suggested fix

Split into two fixtures, one violation each, so each branch of `rulesetShapeIssue` has its own
proof. Cheap and it makes the RED proof say what it claims.

## Why it was not fixed in phase 238

Cosmetic relative to the gate's purpose: the fixture reddens, the guard works. Filed to keep the
proof honest rather than to fix a failure.
