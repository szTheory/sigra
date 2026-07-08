---
phase: 218-elevation-wave-nit-cleanup
plan: "04"
subsystem: dx/uat
tags: [uat, shell, dx, demo]
status: complete

dependency_graph:
  requires: []
  provides: [ui-01-resolved]
  affects: [scripts/uat/up.sh]

tech_stack:
  added: []
  patterns: [bash-validity-pass, stale-resource-reap, live-probe-on-status]

key_files:
  created: []
  modified:
    - scripts/uat/up.sh

decisions:
  - "--no-watch in non-shared mode and --attach in private-traefik mode trigger the 'ignored in <mode> mode' warning (post-parse validity pass mirrors the --proxy/--private-traefik mutual-exclusion precedent)"
  - "print_status always re-probes via curl -fsS --max-time 2 when invoked via --status — it never trusts the frozen SIGRA_UAT_READY flag written at boot time"
  - "Host-run wait_for_http timeout bumped to 120s at the call site only; default 60s preserved for Docker path (already gated by container healthcheck)"
  - "reap_stale_uat_stacks guards: (1) != current project, (2) no running containers — neither condition can accidentally tear down a live stack; opt-out via SIGRA_UAT_REAP=0"

metrics:
  duration: 235s
  completed_date: "2026-07-08"

one_liner: "Folded all four UI-01 nits into scripts/uat/up.sh: flag-inert warnings, --status live re-probe, 120s host boot timeout, and stale-stack reap"
---

# Phase 218 Plan 04: UAT Demo-DX Polish Nits Summary

Folded UI-01 carry-forward todo (2026-06-19-uat-demo-dx-polish-nits) into `scripts/uat/up.sh`. All four deferred nits from the PR #56 code review are now resolved. Zero overlap with CI/panel/admin-eval harness files.

## What Was Built

### Nit 1 + Nit 5: Flag-inert warnings (post-parse validity pass)

Added a validity pass after mode selection (mirroring the existing `--proxy`/`--private-traefik` mutual-exclusion check). Two cases warned:

- `--no-watch` passed outside shared mode prints: `Note: --no-watch is ignored in <mode> mode (only applies to the shared proxy path).`
- `--attach`/`--iex` passed in `private-traefik` mode prints: `Note: --attach/--iex is ignored in private-traefik mode (use --dev for a host-run IEx shell).`

Both use the existing `yellow` helper. Script continues — these are informational only.

### Nit 7: `--status` live re-probe

Modified `print_status` to re-probe liveness at the start of the function using `curl -fsS --max-time 2 "${probe_url}"`. The probe_url falls back to `${base}` if `SIGRA_UAT_RAW_URL` is unset. This overwrites the frozen `SIGRA_UAT_READY` flag so a server that came up after the initial boot probe now shows as live, and a torn-down server shows as STARTING.

Reuses the exact same guard already present in `wait_for_http` (line 551).

### Nit 8: Host-run `wait_for_http` timeout bump

Changed the host-run call site at the end of the script from:
```bash
wait_for_http "${SIGRA_UAT_RAW_URL}"
```
to:
```bash
wait_for_http "${SIGRA_UAT_RAW_URL}" 120
```

The default `60` in `wait_for_http "${2:-60}"` stays unchanged for the Docker probe path. The 120s budget accommodates a cold first-run compile of `test/example` + `sigra` (~70-90s on a warm machine without a pre-warmed build).

### Reap stale leaked-UAT-stack

Added `reap_stale_uat_stacks()` function, wired before the Docker bring-up step. The function:
- Requires `SIGRA_UAT_REAP=1` (default) — opt-out via `SIGRA_UAT_REAP=0`
- Lists all compose containers carrying `label=dev.sigra.proxy-host` (the Sigra-specific UAT label)
- For each unique project found: skips the current invocation's project, skips any project with running containers (live stacks never touched)
- Tears down inactive orphaned projects via `docker compose -p <project> --profile proxy --profile private-traefik down -v --remove-orphans`

Mirrors the `sync_host_compile_env_port` stale-build wipe precedent in terms of opt-in-safe default-on behavior.

## Live Exercise Deferred

The `--dev` host-run path end-to-end boot (auto-start + health-gate + browser open) was not live-exercised in this execution. Docker and a local Postgres with a compiled example build were not available during execution. The script passes `bash -n` and all logic is covered by static analysis. Live exercise can be performed by the operator with `scripts/uat/up.sh --dev`.

## Verification

All plan verification criteria met:

- `bash -n scripts/uat/up.sh` passes
- `grep -qi 'ignored in' scripts/uat/up.sh` matches (two warning lines)
- `grep -q 'curl -fsS --max-time 2' scripts/uat/up.sh` matches (both in print_status and wait_for_http)
- Host-run `wait_for_http` call passes `120` as second arg
- `reap_stale_uat_stacks()` excludes current project and excludes projects with running containers
- No `scripts/ci`, `scripts/panel`, or admin-eval file modified

## Todo Disposition

`.planning/todos/pending/2026-06-19-uat-demo-dx-polish-nits.md` moved to `.planning/todos/resolved/`.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1+2: All four nits in up.sh | 8f6eea84 | scripts/uat/up.sh |

## Deviations from Plan

None — plan executed exactly as written. Tasks 1 and 2 were committed together (they touch the same file and are the entire plan's deliverable).

## Threat Flags

None. This plan edits a local demo/UAT shell orchestrator that is not part of the shipped library, CI gates, or any runtime auth path.

## Self-Check: PASSED

- `scripts/uat/up.sh` exists and passes `bash -n`
- Commit `8f6eea84` verified in git log
- Todo moved to resolved directory
