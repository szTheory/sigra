---
id: SEED-007
status: deferred
planted: 2026-06-21
planted_during: --dev host-run boot fixes (quick tasks 260621-in8 / in8b)
trigger_when: Next time host-run `--dev` port fragility resurfaces, OR a deliberate pass over the generated-host `use Sigra.Organizations` macro / `secret_key_base` wiring
scope: Medium
---

# SEED-007: Decouple `secret_key_base` from the whole-Endpoint compile-env invariant

## Why This Matters

`test/example/lib/example/organizations.ex` reads
`Application.compile_env!(:example, ExampleWeb.Endpoint)[:secret_key_base]`. Reading
any sub-key via `compile_env!` marks the **entire** `ExampleWeb.Endpoint` config —
including the volatile `http: [port: …]` — as a compile-time invariant that Elixir
re-validates at the START of every mix task and ABORTS on mismatch *before* it can
recompile (so a `_build/dev` compiled at a different port can't self-heal).

This is the root cause behind the whole `--dev` saga (260621-in8 / in8b). We worked
around it in `scripts/uat/up.sh` by (a) defaulting host-run to a stable port 4011 and
(b) `sync_host_compile_env_port()` wiping the example build on frozen-port mismatch.
Those workarounds are solid, but the underlying coupling remains and the same trap
ships to **every generated host app** that uses `use Sigra.Organizations`.

## The Fix (deferred — bigger blast radius)

Give `secret_key_base` its own dedicated config key (e.g.
`config :example, :sigra_secret_key_base, "…"` consumed via
`Application.compile_env!(:example, :sigra_secret_key_base)`), so the volatile
endpoint port is never part of any compile-time invariant. Then host-run `--dev`
could use any/dynamic port with no stable-port constraint and no build-wipe, and the
generated-host upgrade path is cleaner.

## Why deferred

- Touches the library macro / generated-host contract (`use Sigra.Organizations`),
  not just the demo — must mirror into `priv/templates/sigra.install/**` and keep the
  new secret key in sync with the endpoint's `secret_key_base` across dev/test/prod
  + `runtime.exs` (risk of subtle token-signing divergence if they drift).
- The `up.sh` workarounds already make `--dev` reliable today, so this is an
  architecture-cleanliness improvement, not a correctness hotfix.

## References

- `scripts/uat/up.sh` — `sync_host_compile_env_port()` + `ensure_port_free()` (the workaround)
- `test/example/lib/example/organizations.ex:~45` — the `compile_env!` call
- `test/example/config/dev.exs` — endpoint `http: [port: …]` from `PORT`
- Memory: `reference_host_run_compile_env_port`
- Quick tasks 260621-in8 / 260621-in8b in `.planning/STATE.md`
