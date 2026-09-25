---
created: 2026-09-17T00:00:00.000Z
status: pending
title: p19 constructs the `bypass_actors` field name at runtime to route around the grep gate that polices it
area: ci
severity: minor
source: phase 238 code review (WR-02)
files:
  - scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
  - .planning/phases/238-tag-guard-then-tag-deletion/238-03-PLAN.md
---

## Problem

`scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs:50-55` and `:307-312` spell the field
name as `['bypass', 'actors'].join('_')` rather than as a literal. The reason is mechanical: the
plan's own verify gate (`238-03-PLAN.md:169`) counts literal `bypass_actors` occurrences outside
comments and expects zero, because `rulesetShapeIssue` must not assert on a field the operator
owns. The runtime join lets the behavior test reference the field while keeping that count at 0.

The intent is honoured today — `rulesetShapeIssue` (`:122-194`) genuinely never reads the field,
and the test at `:306-317` asserts the *absence* of an assertion. But the gate now measures
spelling, not behavior. The same `join` written inside `rulesetShapeIssue` would be a real
vacuous CI assertion that the grep still scores 0, so the gate can no longer detect the thing it
exists to detect.

## Suggested fix

Replace the grep with a structural or behavioral gate — e.g. feed `rulesetShapeIssue` a snapshot
whose `bypass_actors` is populated and assert the function's verdict is unchanged — and then
restore the literal spelling in the behavior test. The grep and the join should both go.

## Why it was not fixed in phase 238

The gate lives in an executed plan's verify block, which is immutable history; replacing it is a
design change to the prohibition-test contract, not a defect fix. Filed rather than reworked
under a review gate.
