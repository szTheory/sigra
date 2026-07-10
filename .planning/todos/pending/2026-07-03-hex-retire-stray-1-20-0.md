---
created: 2026-07-03T00:00:00.000Z
status: pending
resolves_phase: 223
title: Retire stray Hex 1.20.0 so 1.1.0 is the resolved latest_stable
area: release
files:
  - milestones/v1.43-phases/214-debt-robustness-clear/214-05-SUMMARY.md
source: 2026-07-03 v1.43 close — Jon deferred (no time now); manual/interactive step, cannot be automated
---

## What

A stray `1.20.0` was published to Hex during an earlier dev cycle (same family as
the old 1.32.0 confusion). Because 1.20.0 > 1.1.0 by SemVer, Hex reports
`latest_stable_version = 1.20.0`, so `{:sigra, "~> 1.0"}` resolves to **1.20.0**
instead of the real 1.1.0 GA. Deletion is not allowed post-grace-window — **retire
is the only lever** (reversible via `--unretire`). Hex.pm web UI has no retire
button; it's CLI/API only.

Phase 214 (DEBT-04) already cleared the *local* wart — deleted git tag `v1.20.0`
(local + remote) and corrected `contract.md` to 1.1.0 — but the **published Hex
version still outranks the GA**. This is the remaining half, and it needs Jon's
interactive Hex auth, so it can't be done by an agent.

## Why deferred

Purely a manual/interactive step (Hex write-key auth prompts for the hex.pm
password). No real adopters are blocked today. Jon deferred it at the v1.43 close
("don't have time right now").

## How (runbook — from 214-05-SUMMARY.md)

The locally stored Hex key is read-only ("key not authorized for retire"). So:

1. Mint a write key (prompts for hex.pm password — Jon, interactive):
   `mix hex.user key generate --key-name sigra-retire --permission api`
   (or refresh auth first if expired: `mix hex.user auth`)
2. Retire the stray version:
   `mix hex.retire sigra 1.20.0 invalid --message "Published in error during dev cycle; not a real release — use 1.1.0+"`
3. Verify: `https://hex.pm/api/packages/sigra` → `latest_stable_version` should
   drop back to `1.1.0`; `{:sigra, "~> 1.0"}` then resolves to 1.1.0.

Reversible with `mix hex.retire sigra 1.20.0 --unretire` if ever needed.

## Done when

Hex reports `1.1.0` (not `1.20.0`) as `latest_stable_version` and `~> 1.0`
resolves to the real GA. See also the full runbook in
`milestones/v1.43-phases/214-debt-robustness-clear/214-05-SUMMARY.md`.
