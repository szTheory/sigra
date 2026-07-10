---
created: 2026-06-19T00:00:00.000Z
status: pending
title: UAT demo-DX polish nits (deferred from PR #56 code review) — flag inert flags, re-probe --status, longer host-run timeout
area: dx
resolves_phase: 218
files:
  - scripts/uat/up.sh
source: PR #56 code review (quick task 260619-l1b). Real bugs (#1 orphaned BEAM, #2 leaking watch volumes, #3 PID reuse, #4 attach ignored) were FIXED in commit b93f8e2f. These are the low-severity nits intentionally deferred.
---

## What

Polish items from the PR #56 code review, none blocking — the live-verified
default proxy path and the fixed host-run teardown all work. Capture so they
aren't lost:

1. **Flags silently inert in the wrong mode (nit #5).** `--no-watch` only affects
   `shared` mode; `--attach`/`--iex` now imply `--dev` (fixed), but `--no-watch`
   passed in `--dev` mode, or other cross-mode combos, are still silent no-ops.
   Add a one-line "ignored in <mode> mode" warning when a flag can't apply.

2. **`--status` reports a frozen `SIGRA_UAT_READY` (nit #7).** The readiness flag
   is written to `tmp/uat.env` at boot time and `--status` re-sources it, so a
   server that came up *after* the probe timed out still prints `STARTING`
   forever (and a torn-down one could print live). Re-probe with a quick
   `curl -fsS --max-time 2` inside `print_status` when invoked via `--status`.

3. **Host-run `wait_for_http` timeout likely too short for a cold `--dev` boot
   (nit #8).** Default 60s; a first-run `mix phx.server` compiles the example +
   sigra from scratch (~70–90s), so `--dev` will routinely print the `STARTING`
   warning and skip the browser open even though it comes up shortly after.
   Bump the host-run call to ~120s, or detect "Compiling" in the log and extend.

## Also worth doing (related, separate)

- **Live-exercise the `--dev` host-run path end-to-end** (auto-start + health-gate
  + `--attach` foreground IEx) and the **bind-mount hot-reload** path. The default
  proxy boot is live-verified; these two were only static-checked + reasoned.
- **Reap stale leaked UAT stacks** from before the `down.sh` profile fix: a
  `sigra-uat-jon-main-39bab8dd-web-1` (Up 26h) container and `…-main…` / `…-v1-37
  -auth-branding…` volume sets were found orphaned. Clean with
  `docker compose -p <project> --profile '*' down -v --remove-orphans` per stale
  project, or `docker rm -f <web> && docker volume rm <vols>`.

## Why deferred

Label/UX/cosmetic only; the correctness bugs from the review were fixed and
verified in PR #56. Batch these into a future quick task touching `scripts/uat/`.
