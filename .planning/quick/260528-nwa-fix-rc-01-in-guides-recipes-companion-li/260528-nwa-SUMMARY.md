---
status: complete
phase: quick-260528-nwa
plan: "01"
subsystem: docs
tags: [rc-01, cr-01, threadline, audit, docs-only]
dependency_graph:
  requires: []
  provides: [RC-01, CR-01-doc-side]
  affects: [guides/recipes/companion-libs/threadline.md, guides/recipes/companion-libs/accrue.md, guides/flows/audit-logging.md]
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - guides/recipes/companion-libs/threadline.md
    - guides/recipes/companion-libs/accrue.md
    - guides/flows/audit-logging.md
decisions:
  - "Kept accrue.md log_audit/2 example as billing.seat.added action string — matches seat/billing narrative context per plan intent"
  - "Spread event_map into metadata: Map.take rather than inventing positional fields — preserves doc clarity"
metrics:
  duration: ~180s
  completed: "2026-05-28"
  tasks_completed: 3
  files_modified: 3
---

# Quick Task 260528-nwa: Fix RC-01/CR-01 doc defects in companion-lib guides

One-liner: Corrected three guide files — threadline.md forwarder block now uses `repo: MyApp.Repo` (DB-based 0.5+ path), accrue.md and audit-logging.md now call real `Sigra.Audit.log/2 (action, opts)`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix RC-01 — threadline.md forwarders block + failure modes + prereqs | 0f9654a | guides/recipes/companion-libs/threadline.md |
| 2 | Fix CR-01 — real Sigra.Audit.log/2 signature in accrue.md + audit-logging.md | 89019d4 | guides/recipes/companion-libs/accrue.md, guides/flows/audit-logging.md |
| 3 | Verification gate — docs build clean + banned-phrase + key-set match | (no commit — verification only) | — |

## What Was Fixed

### RC-01 (threadline.md)

**Forwarders config block:** Replaced `endpoint: System.get_env("THREADLINE_ENDPOINT")` and `api_key: System.get_env("THREADLINE_API_KEY")` with `repo: MyApp.Repo` plus an inline comment explaining Threadline 0.5+ is DB-based. Key set now matches `test/example/config/config.exs:52-63` (module/id/dispatch/repo).

**Prerequisites bullet:** Rewrote the "Environment variables are set" bullet — Threadline 0.5+ has no HTTP secrets for the forwarder; adopter confirms the repo from Threadline's bootstrap is passed as `repo:`.

**Failure mode #4:** Rewrote from HTTP/network framing to DB/transient framing. Updated heading from "Network or transient failure" to "Transient DB failure on :async path". Retained all correct mechanics (Sigra.Workers.AuditForward, max_attempts: 5, exponential backoff, discarded state, telemetry event, no auth op rollback).

**Unchanged (verified correct):** version pins on lines 1/5/28 (`threadline ~> 0.5`), prose pin `threadline.ex:290-307`, failure modes #1/#2/#3/#5, Non-goals and See-also sections.

### CR-01 (accrue.md + audit-logging.md)

**accrue.md line 81:** Replaced `Sigra.Audit.log(event_map |> Map.put(:actor_id, user.id))` (non-existent `log/1` map call) with `Sigra.Audit.log("billing.seat.added", actor_id: user.id, actor_type: "user", metadata: Map.take(event_map, [...]))` — real `log/2 (action, opts)` form.

**audit-logging.md line 93:** Removed leading `config` argument from `Sigra.Audit.log(config, "billing.subscription.upgraded", ...)` (non-existent `log/3`). Now reads `Sigra.Audit.log("billing.subscription.upgraded", ...)`. All opts preserved.

**Unchanged:** surrounding prose in both files (line-7 and line-105 `log`/`log/2` references are correct), `Sigra.Audit.multi/4` / `log_multi` example (already correct).

## Verification Results

- `mix docs --warnings-as-errors`: exit 0
- Banned-phrase grep across three files: zero matches (seamlessly, just works, production-ready out of the box, the recommended way)
- `grep -n "endpoint:\|api_key:\|THREADLINE_ENDPOINT\|THREADLINE_API_KEY\|HTTP timeout\|Network or transient" threadline.md`: zero matches
- `grep -n "repo: MyApp.Repo" threadline.md`: line 71 (PASS)
- `grep -n "threadline.ex:290-307" threadline.md`: line 77 (unchanged, PASS)
- `grep -nE "Sigra\.Audit\.log\(config," audit-logging.md`: zero matches
- `grep -nE "Sigra\.Audit\.log\(event_map" accrue.md`: zero matches
- Forwarders block key set in threadline.md: module/id/dispatch/repo — no endpoint/api_key

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — docs-only change, no new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

- guides/recipes/companion-libs/threadline.md: modified and committed (0f9654a)
- guides/recipes/companion-libs/accrue.md: modified and committed (89019d4)
- guides/flows/audit-logging.md: modified and committed (89019d4)
- mix docs --warnings-as-errors: exit 0
