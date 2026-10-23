---
created: 2026-09-25T00:00:00.000Z
status: pending
title: "FUT-02: define a durable Dependabot groups policy after the current dependency queue is drained"
area: dependencies
files:
  - .github/dependabot.yml
  - .planning/REQUIREMENTS.md
source: Phase 243 requirement FUT-02; grouping policy is explicitly separate from draining the named PR queue
---

## What

Design and adopt a reviewed Dependabot `groups:` policy for compatible dependency updates. Specify which ecosystems and packages may be grouped, how security updates are handled, and which dependency families must remain individually attributable.

## Why

Grouping can reduce repetitive pull requests and maintenance overhead, but broad grouping can obscure which version change caused a failure and weakens the queue's causal evidence. The policy should be designed and reviewed after the current individually sequenced dependency queue is drained.

## Evidence and boundary

- `.planning/REQUIREMENTS.md` lists FUT-02 as carried-forward Dependabot `groups:` policy work.
- Phase 243 D-06 and D-08 require fixed order and one-at-a-time Tier B merge attribution.
- `.github/dependabot.yml` is the future implementation surface; this todo does not change it.

## Acceptance

A future owner documents ecosystem/package grouping rules, security-update behavior, and exceptions for updates that require individual CI attribution. A separate reviewed change updates `.github/dependabot.yml`; this record does not implement that policy.
