---
phase: quick-260619-l1b
plan: 01
subsystem: dev-experience / UAT demo tooling
status: complete
tags: [docker, traefik, uat, demo, dx, live-reload, docs]
requires: [scripts/uat/up.sh, scripts/uat/down.sh, scripts/uat/docker-compose.yml, scripts/uat/lib/naming.sh, scripts/ci/lib/free-port.sh, scripts/uat/Dockerfile.example]
provides:
  - "scripts/uat/up.sh no-flag default = Dockerized shared-Traefik demo with live reload, readiness gate, auto-open, grouped routes"
  - "scripts/uat/docker-compose.watch.yml bind-mount live-reload override (compile-env safe)"
  - "web service healthcheck enabling up -d --wait"
  - "down.sh host-run Phoenix PID/log cleanup"
  - "claim-based sigra.localhost alias (works on any branch)"
affects: [guides/recipes/local-development.md, guides/introduction/demo-showcase.md, scripts/uat/RUNBOOK.md, README.md, CLAUDE.md]
tech-stack:
  added: []
  patterns: [docker-compose-override-merge, readiness-probe-gate, background-pidfile-process, named-volume-shadowing]
key-files:
  created:
    - scripts/uat/docker-compose.watch.yml
  modified:
    - scripts/uat/up.sh
    - scripts/uat/docker-compose.yml
    - scripts/uat/down.sh
    - guides/recipes/local-development.md
    - guides/introduction/demo-showcase.md
    - scripts/uat/RUNBOOK.md
    - README.md
    - CLAUDE.md
decisions:
  - "No-flag up.sh default flips from host-run (none) to Dockerized shared-Traefik (shared); --proxy becomes an explicit alias; --dev/--host opts into host-run"
  - "Readiness probe (wait_for_http) always targets the raw 127.0.0.1:<port> URL so it resolves in every browser and bypasses *.localhost DNS; never exits non-zero (degrades to STARTING label)"
  - "Live-reload override is bind-mount + named-volume shadowing ONLY — no environment block on the web service — preserving the compile-env invariant for in-container recompiles"
  - "sigra.localhost alias relaxed from default-branch-only to claim-based (first stack to claim it on any branch wins)"
  - "private-traefik path intentionally left as print-the-command (not auto-started) — only the new 'none' (--dev) host-run path auto-starts + health-gates"
metrics:
  duration: ~30m
  completed: 2026-06-19
  tasks: 3
  files: 9
  commits: 5
---

# Phase quick-260619-l1b: Demo Docker DX — proxy-by-default Summary

One-liner: `scripts/uat/up.sh` with no flags is now a single hands-off command that builds + boots the Dockerized Vaultr demo behind the shared Traefik proxy with bind-mount live reload, blocks on a `--wait` healthcheck + `wait_for_http` readiness probe, auto-opens `/demo/credentials`, and prints grouped auth/admin/ops routes — with host-run kept as an explicit, now-actually-started `--dev` opt-in.

## What changed

### Task 1 — `up.sh` default flip + flags + helpers + routes + alias + compose (commit `8a53dde2`, fix `f8c71db2`)

- **Default-mode flip:** mode selection now resolves the no-flag default to `shared` (was `none`). `--private-traefik` → `private-traefik`; `--dev`/`--host` → `none`; default or explicit `--proxy` → `shared`. Mutual-exclusion and all existing explicit-flag behaviors preserved.
- **New flags:** `--dev`/`--host` (host-run), `--attach`/`--iex` (foreground IEx), `--no-watch` (disable bind-mount override), `--no-open` (skip auto-open). Wired into the arg loop with new default vars (`ENABLE_DEV_HOST`, `SIGRA_UAT_OPEN`, `ENABLE_ATTACH`, `ENABLE_WATCH`, `SIGRA_UAT_READY`, host pid/log path vars, `WATCH_FILE`). Usage header + `--help` sed range updated (range corrected to `2,25` in the fix commit so it never leaks `set -euo pipefail`).
- **Helpers (match existing cyan/green/yellow/red style):** `wait_for_http` (readiness probe → sets `SIGRA_UAT_READY`, never exits non-zero), `start_host_server` (background `mix phx.server` → `tmp/uat-phoenix.log` + `tmp/uat-phoenix.pid`), `ensure_port_free` (TOCTOU re-pick of host-run port), `maybe_open_browser` (open/xdg-open, tolerant).
- **shared branch (`setup_docker_example`):** builds a `compose_files` array that appends `-f docker-compose.watch.yml` when `ENABLE_WATCH=1` (default), applied to `stop`/`build`/`run`/`up`/`port`; switched the final `up -d web` → `up -d --wait web`; then `wait_for_http` on the raw URL.
- **host-run branch (mode `none`, `--dev`):** `--attach` → `exec` foreground IEx with the compile env; else `ensure_port_free` → `start_host_server` → `wait_for_http`.
- **print_status:** PRIMARY URL line branches on `SIGRA_UAT_READY` (appends `STARTING — not yet responding (see …)` when not ready); new ADMIN route group (`/admin`, `/admin/users`, `/admin/audit`, `/admin/auth-branding`, `/admin/_design`, `/admin/organizations/acme-corp` + "sign in as admin@demo.vaultr.test"); server line reworded from a run command into Logs (docker logs for shared, `tail -f tmp/uat-phoenix.log · Attach IEx: …` for host-run).
- **Persist + auto-open:** `SIGRA_UAT_READY`, host pid/log paths added to `write_state_file`; `maybe_open_browser` called after the final `print_status`.
- **Claim-based alias:** dropped the `is_default_branch` requirement from the alias gate (`if ! alias_claimed_by_other`), keeping the conflict check; reworded the comment + the note.
- **`docker-compose.yml`:** added a `web` healthcheck hitting `http://127.0.0.1:4000/demo/credentials` via `wget` (interval 3s / timeout 3s / retries 20 / start_period 30s) to enable `up -d --wait`.
- **`docker-compose.watch.yml` (new):** `web` override bind-mounting `../..:/app:cached` + four named volumes shadowing `_build`/`deps` at both `/app` and `/app/test/example`; re-declares the external `proxy` network. Carries the COMPILE-ENV INVARIANT inline and contains **no** `environment:` block.

### Task 2 — `down.sh` host-run PID cleanup (commit `438f2412`)

- Added `stop_host_run_phoenix`: reads `tmp/uat-phoenix.pid`, `kill`s when alive (`kill -0` guard), `rm -f`s the pid + log; every step tolerant of absence (`|| true`). Invoked in both the `--purge` and default branches; `--purge` STATE_FILE removal preserved.

### Task 3 — Reader-empathetic docs (commit `890c7615`)

- **local-development.md:** rewrote the TL;DR gameplan + "Running the demo app" to the one-command default; added a flag table, a "Running several Sigra-family libs at once" subsection (claim-based `sigra.localhost`), refreshed "Iterating on code", and added troubleshooting for the `STARTING` label / `tmp/uat-phoenix.log` / macOS bind-mount reload lag (→ `--dev`).
- **demo-showcase.md:** evaluator blurb → "one command, opens itself" (no second terminal); persona/screenshot content untouched.
- **RUNBOOK.md:** new default one-liner + flag table.
- **README.md:** Evaluating lane now points at the single-command demo.
- **CLAUDE.md:** surgical note appended to the existing UAT-stack sentence; unrelated sections untouched.

## Files touched

Created: `scripts/uat/docker-compose.watch.yml`
Modified: `scripts/uat/up.sh`, `scripts/uat/docker-compose.yml`, `scripts/uat/down.sh`, `guides/recipes/local-development.md`, `guides/introduction/demo-showcase.md`, `scripts/uat/RUNBOOK.md`, `README.md`, `CLAUDE.md`

## Verification results (CI-safe, all run)

| Check | Result |
| ----- | ------ |
| `bash -n scripts/uat/up.sh` | PASS |
| `bash -n scripts/uat/down.sh` | PASS |
| `docker compose -f docker-compose.yml -f docker-compose.watch.yml --profile proxy config -q` | PASS (docker present in env; full merged config validated) |
| `python3` YAML safe_load of both compose files | PASS |
| `grep -q 'docker-compose.watch.yml' up.sh` | PASS |
| `grep -q -- '--wait' up.sh` | PASS |
| helpers present (`wait_for_http`/`start_host_server`/`ensure_port_free`/`maybe_open_browser`) | PASS (each individually) |
| `grep -Eq 'SIGRA_UAT_OPEN\|--no-open\|--dev\|--attach\|--no-watch' up.sh` | PASS |
| admin routes (`/admin/auth-branding`, `/admin/_design`, `acme-corp`) in up.sh | PASS |
| `grep -q 'healthcheck' docker-compose.yml` | PASS |
| watch override has NO `SIGRA_EXAMPLE_BIND`/`PGHOST`/`PORT:` keys | PASS (reworded invariant comment so the assertion holds) |
| alias gate dropped `is_default_branch && ! alias_claimed_by_other` | PASS |
| `down.sh` references `uat-phoenix.pid` + `uat-phoenix.log` | PASS |
| local-development.md `--dev`/`--no-open`/`--no-watch` | PASS |
| local-development.md `sigra.localhost`/`one command` | PASS |
| local-development.md `tmp/uat-phoenix.log` | PASS |
| RUNBOOK.md references `up.sh` | PASS |
| `--help` sed range excludes `set -euo pipefail` | PASS (range corrected to 2,25) |
| `grep -rn 'up.sh' scripts/ci` (no dependency on old default) | none found |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `--help` sed range leaked `set -euo pipefail`**
- **Found during:** Task 1 final verification.
- **Issue:** The expanded usage header pushed `set -euo pipefail` to line 27; the `--help` range was set to `2,27p`, which would print that bare line in help output.
- **Fix:** Tightened the range to `2,25p` (last usage comment).
- **Files modified:** `scripts/uat/up.sh`
- **Commit:** `f8c71db2`

**2. [Rule 3 - Blocking] Watch-override verification grep matched the invariant comment**
- **Found during:** Task 1 verification (`! grep -Eq 'SIGRA_EXAMPLE_BIND|PGHOST|^\s*PORT:'`).
- **Issue:** The COMPILE-ENV INVARIANT comment originally spelled out the literal env-var names (`SIGRA_EXAMPLE_BIND`, `PGHOST`, …), tripping the "override must not contain these keys" assertion even though no `environment:` block exists.
- **Fix:** Reworded the comment to describe the forbidden values prose-style (bind address / HTTP port / Postgres vars / example URL) without the bare tokens; the file still contains no `environment:` block, so the invariant is genuinely satisfied.
- **Files modified:** `scripts/uat/docker-compose.watch.yml`
- **Commit:** `8a53dde2`

No architectural changes; no auth gates.

## Manual end-to-end checklist (maintainer — Docker required, cannot run in CI)

Run from the `chore/post-v1.39-cleanup` branch on a machine with Docker Desktop running:

1. `scripts/uat/down.sh && scripts/uat/up.sh` → image build (first run), `up -d --wait` blocks on the web healthcheck, `wait_for_http` passes, browser auto-opens `/demo/credentials` at a `*.localhost` (ideally `sigra.localhost`) URL that loads immediately. Confirm the printout shows the URL as live (not `STARTING`) and lists the ADMIN route group.
2. Log in as `admin@demo.vaultr.test`; click each printed ADMIN route (`/admin`, `/admin/users`, `/admin/audit`, `/admin/auth-branding`, `/admin/_design`, `/admin/organizations/acme-corp`) → all 200.
3. Edit a `test/example` admin template → confirm hot reload in the browser **without** an image rebuild (bind-mount + inotify). Edit a `lib/` Sigra source file → confirm reload too.
4. `scripts/uat/up.sh --dev` → host-run path auto-starts in the background, `wait_for_http` gates, prints a live `127.0.0.1:<port>`, loads. Then `scripts/uat/up.sh --dev --attach` → drops into a foreground IEx shell bound to the server.
5. From a second checkout/branch, `scripts/uat/up.sh` → distinct `*.localhost` host, no port/route collision; `sigra.localhost` held by exactly one stack (claim-based — confirm a feature-branch checkout can win it).
6. `scripts/uat/down.sh` → containers down AND any host-run Phoenix PID killed; `tmp/uat-phoenix.{pid,log}` removed.
7. Re-run `scripts/uat/up.sh` after a CSS-only change → no dep re-download/recompile (cached layers), fast.
8. Sanity: `--no-watch` (proxy without bind mount), `--no-open` (no browser), `--reset`, `--no-seed`, `--private-traefik`, `--status`, `--print-env`, `--refresh-code` all behave as before.
9. `mix test` still green (no test references these scripts).

## Self-Check: PASSED

- `scripts/uat/docker-compose.watch.yml` — FOUND
- commit `8a53dde2` — FOUND
- commit `438f2412` — FOUND
- commit `890c7615` — FOUND
- commit `f8c71db2` — FOUND
