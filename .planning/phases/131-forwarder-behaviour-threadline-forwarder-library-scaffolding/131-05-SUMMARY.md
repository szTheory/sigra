---
phase: 131
plan: "05"
subsystem: audit-forwarders-boot
tags:
  - audit
  - forwarders
  - boot-time
  - telemetry
  - oban
  - application
  - tdd
dependency_graph:
  requires:
    - "131-03: Sigra.Audit.Forwarders.oban_running?/1 (public, called cross-module)"
    - "131-04: Sigra.Audit.Forwarders.Noop (attach/1 used as test target)"
  provides:
    - "131-06: Boot-wiring complete — forwarders active at BEAM start"
  affects:
    - lib/sigra/application.ex
    - test/sigra/application_forwarders_test.exs
tech_stack:
  added: []
  patterns:
    - "maybe_warn_missing_forwarder_deps/0: one-shot Logger.warning per configured-but-missing forwarder dep"
    - "attach_forwarders/0: D-26 fail-fast raise on :async + no Oban at boot"
    - "D-27 single config cascade: Application.get_env(otp_app, :sigra_config)"
    - "D-12 single source: delegates to Sigra.Audit.Forwarders.oban_running?/1"
    - "T-131-14 redaction: Logger.warning only interpolates module name, never opts"
key_files:
  created:
    - test/sigra/application_forwarders_test.exs
  modified:
    - lib/sigra/application.ex
decisions:
  - "D-25 ordering enforced: maybe_warn_missing_forwarder_deps() before attach_forwarders() before verify_vault!()"
  - "D-26: ArgumentError raised at boot when dispatch: :async + Oban not supervised — fail-fast over silent degrade"
  - "D-12: application.ex delegates to Sigra.Audit.Forwarders.oban_running?/1 — no Process.whereis(Oban) duplication"
  - "T-131-14: Logger.warning text interpolates only inspect(module) — no opts blob, no :api_key, no :endpoint"
  - "attach_forwarders/0 uses D-23 split: Code.ensure_loaded?(module) gates attach call; missing-dep skip is silent (warning already emitted by maybe_warn_missing_forwarder_deps/0)"
metrics:
  duration: "7 minutes"
  completed: "2026-05-27"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 131 Plan 05: Boot-Time Forwarder Activation Summary

Boot-time forwarder activation glue wired into `Sigra.Application.start/2`: one-shot Logger.warning per configured-but-missing dep and attach call per loaded forwarder, with ArgumentError raised at boot when `:async` dispatch is configured without a supervised Oban.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing boot-wiring tests | dddb2cb | test/sigra/application_forwarders_test.exs |
| 2 (GREEN) | Implement maybe_warn_missing_forwarder_deps/0 + attach_forwarders/0 + wire into start/2 | 8375a89 | lib/sigra/application.ex |

## Implementation Details

### `lib/sigra/application.ex` — Modified Lines

**`start/2` call sequence (lines 21-29):** Two new calls added in D-25 order:
```elixir
  def start(_type, _args) do
    maybe_warn_audit_cleanup_fallback()
    maybe_warn_missing_cookie_domain()
    maybe_warn_missing_forwarder_deps()   # NEW (D-25)
    attach_forwarders()                    # NEW (D-25 + D-26 raise on :async + no Oban)
    verify_vault!()
    Supervisor.start_link([], strategy: :one_for_one, name: Sigra.Supervisor)
  end
```

**`maybe_warn_missing_forwarder_deps/0` (lines 92-120):** D-27 cascade extracts forwarder list; iterates via `Enum.each`; for each entry where `Code.ensure_loaded?(module)` is false, emits:
```
[Sigra.Audit] Forwarder #{inspect(module)} is configured but its module is not loaded.
Audit events will not be forwarded. Add the corresponding dep to mix.exs (e.g.
`{:threadline, "~> 0.5", optional: true}`), or remove the forwarder entry from
your sigra_config/0 `audit: [forwarders: [...]]` block.
See guides/recipes/companion-libs/threadline.md for full wiring.
```

**`attach_forwarders/0` (lines 122-160):** Same D-27 cascade; for each entry:
- D-26 raise (verbatim message):
```
[Sigra.Audit] Forwarder #{inspect(module)} is configured with dispatch: :async
but Oban is not supervised in this app.

Boot-time fail is intentional: silent degradation to :sync would mask the
misconfiguration. Fix one of:
  - add {:oban, "~> 2.17"} to mix.exs deps and supervise it, or
  - change dispatch to :auto (falls back to :sync if Oban is absent), or
  - remove the forwarder entry.

See guides/recipes/companion-libs/threadline.md for full wiring.
```
- D-23 attach: `if Code.ensure_loaded?(module), do: module.attach(forwarder_opts)`

### Key Verification Facts

- `Application.get_env(otp_app, :sigra_config)` appears 4 times in `application.ex` (existing 2 + new 2 — all use the single D-27 cascade)
- `Process.whereis(Oban)` count in `application.ex` = 0 (delegates to `Sigra.Audit.Forwarders.oban_running?/1`)
- `inspect(forwarder_opts)` count in `application.ex` = 0 (T-131-14 redaction satisfied)
- `api_key` count in `application.ex` = 0 (no opts-blob leak)
- `guides/recipes/companion-libs/threadline.md` appears in both warning and raise text

## Test Output

```
Running ExUnit with seed: 941039, max_cases: 36

.........
Finished in 0.03 seconds (0.00s async, 0.03s sync)
9 tests, 0 failures
```

Integration slice (audit/ + workers/audit_forward_test + application_forwarders_test):
```
76 tests, 0 failures
```

Full suite regression: 2230 tests, 0 failures.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Both new helpers execute real logic against actual Application env. The Logger.warning text references `guides/recipes/companion-libs/threadline.md` as a forward link — that recipe file ships in Phase 132 (documented as intentional by RESEARCH.md §7.3).

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The only new surface is:
- `Logger.warning` output (covered by T-131-18 — only interpolates module name)
- `attach_forwarders/0` calling `module.attach(opts)` (trust delegated to impl, which validates its own keys at attach time per D-08)

## Self-Check: PASSED

- `lib/sigra/application.ex` modified — FOUND, contains both helpers
- `test/sigra/application_forwarders_test.exs` created — FOUND
- Commit dddb2cb (RED tests) — FOUND
- Commit 8375a89 (GREEN implementation) — FOUND
- `maybe_warn_missing_forwarder_deps` in start/2 before `attach_forwarders` — VERIFIED (lines 24, 25)
- `raise ArgumentError` in attach_forwarders — VERIFIED (1 occurrence)
- `Process.whereis(Oban)` in application.ex — VERIFIED 0 occurrences (D-12)
- `inspect(forwarder_opts)` in application.ex — VERIFIED 0 occurrences (T-131-14)
- 9 tests GREEN, 2230 regression tests GREEN
