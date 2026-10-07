---
created: 2026-09-25T00:00:00.000Z
status: pending
title: "FUT-04: launch-pack-contract exists without a workflow caller"
area: ci
files:
  - scripts/ci/launch-pack-contract.sh
  - .github/workflows/ci.yml
source: Phase 243 requirement FUT-04; live caller search at Phase 243 todo triage start
---

## What

Decide how `scripts/ci/launch-pack-contract.sh` should be invoked by the supported CI workflow, and add a deterministic caller with an explicit trigger and failure behavior in a future owned change.

## Evidence

At Phase 243 triage start, repository search found the script's own self-references and no occurrence in `.github/workflows/`. The script declares `launch-pack-contract` and verifies launch-pack artifacts, but no workflow invokes it. The requirement is also recorded as FUT-04 in `.planning/REQUIREMENTS.md`.

## Why

An uncalled contract script does not protect the launch-pack surface in pull requests or releases. The future owner should first decide whether it belongs in `ci.yml` or a release-specific workflow, then prove the selected workflow invokes it under the intended event.

## Boundary

This is a backlog record only. Phase 243 does not modify CI or run the script as part of todo triage.

## Acceptance

A future CI-owned change invokes the contract on the intended event, fails when the contract fails, and records workflow evidence proving the caller ran.
