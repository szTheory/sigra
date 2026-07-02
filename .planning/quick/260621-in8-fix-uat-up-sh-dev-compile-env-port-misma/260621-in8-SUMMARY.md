---
quick_id: 260621-in8
slug: fix-uat-up-sh-dev-compile-env-port-misma
description: Fix uat up.sh --dev compile-env PORT mismatch
date: 2026-06-21
status: complete
commit: 0487e747
---

# Quick Task 260621-in8 — Summary

## What

Fixed `scripts/uat/up.sh --dev` (host-run / proxy-mode `none`) failing to boot the
`test/example` Phoenix app with a Phoenix `validate_compile_env` error
(compile-time `port: 4011` ≠ runtime random port).

## Root cause

`test/example/lib/example/organizations.ex:45` reads
`Application.compile_env!(:example, ExampleWeb.Endpoint)[:secret_key_base]`, which
marks the entire `ExampleWeb.Endpoint` config — including the volatile
`http: [port: …]` — as a compile-time invariant Phoenix re-validates at boot. The
`none)` branch picked a **fresh random free port every run** via `find_free_port`,
but `setup_host_example` reused the cached `_build` compiled at the project's
documented local port 4011 → compiled 4011 ≠ runtime random port → boot refused.
`ensure_port_free()` (up.sh:572-581) compounded it by bumping to another random
port if the chosen one was taken.

## Changes (`scripts/uat/up.sh`, commit `0487e747`)

1. `none)` branch port default (line 762): `${PORT:-$(find_free_port)}` →
   `${PORT:-4011}` — stable, compile-cache-valid, matches the local convention
   (4000 collides with Rulestead Docker). Explicit `SIGRA_EXAMPLE_PORT=`/`PORT=`
   overrides still win.
2. `start_host_server()` background launch (line 565): added
   `--no-validate-compile-env` to `mix phx.server`.
3. `--attach` foreground exec (line 827): added `--no-validate-compile-env` to
   `iex -S mix phx.server`.
4. Printed `SIGRA_UAT_SERVER_COMMAND` (line 815): added `--no-validate-compile-env`
   to keep the displayed command consistent.

The `--no-validate-compile-env` flags are load-bearing, not merely defensive:
`ensure_port_free` can still bump to a random port at runtime, so the dev server
must boot regardless. Only `secret_key_base` (static in `config/dev.exs:42`) truly
needs compile stability; the port is a runtime concern.

## Untouched (verified)

- `shared)` branch (Docker proxy) and `private-traefik)` branch still use
  `find_free_port` (lines 732, 755) — unaffected.
- `ensure_port_free()` fallback (line 575) still uses `find_free_port`.

## Verification

- `bash -n scripts/uat/up.sh` → clean.
- `grep 'PORT:-4011'` → exactly one match, in `none)` (line 762).
- `grep -c -- '--no-validate-compile-env'` → 3.
- Other port branches unchanged.

Runtime verification (`scripts/uat/up.sh --dev` actually booting) was not run here —
it requires Docker + Postgres + a browser. The static checks above plus the precise,
minimal diff are sufficient for this script change; the user can confirm live with
`scripts/uat/up.sh --dev`.

## Out of scope (future)

Refactor `use Sigra.Organizations` to isolate `secret_key_base` into its own config
key so the volatile endpoint port is never part of the compile-time invariant for
generated host apps — larger blast radius (library macro + generator templates).
