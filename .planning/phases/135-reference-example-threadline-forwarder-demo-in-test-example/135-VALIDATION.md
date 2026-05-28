---
phase: 135
slug: reference-example-threadline-forwarder-demo-in-test-example
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 135 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `135-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5) + `Phoenix.ConnTest` via `ExampleWeb.ConnCase` |
| **Config file** | `test/example/test/test_helper.exs` (`ExUnit.start(exclude: [:example_app])`, `Ecto.Adapters.SQL.Sandbox.mode(Example.Repo, :manual)`) |
| **Quick run command** | `mix test test/example_web/threadline_forwarder_test.exs --include example_app` (run inside `test/example/`) |
| **Full suite command** | `mix test --include example_app` (run inside `test/example/` — the `example_unit_smoke` CI lane, `ci.yml:267`) |
| **Estimated runtime** | ~5 seconds (single file, DB up) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/example_web/threadline_forwarder_test.exs --include example_app` (inside `test/example/`)
- **After every plan wave:** Run `mix test --include example_app` (inside `test/example/`)
- **Before `/gsd:verify-work`:** Full example suite green; existing 3 `test/example/` CI jobs remain green (success criterion #3)
- **Max feedback latency:** ~5 seconds (quick) / ~30 seconds (full example suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| EX-01 | 01 | 1 | EX-01 | — | A Sigra `session.create` audit event materializes as a real Threadline `audit_actions` row joined on `correlation_id == audit_event.id`, with `name == "session.create"`, `status == :ok`, `actor_ref.id == user.id`, `actor_ref.type == :user` | integration | `mix test test/example_web/threadline_forwarder_test.exs --include example_app` (in `test/example/`) | ❌ W0 — NEW file | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Anti-under-sampling spec (what the single assertion bundle MUST cover)
1. **Trigger reality:** drive the real auth path `ExampleWeb.UserAuth.log_in_user/2` (not a direct `Sigra.Audit` call).
2. **Source row exists:** a `session.create` `AuditEvent` row for `user.id` exists (yields the join key `audit_event.id`).
3. **Projection row materialized:** a `Threadline.Semantics.AuditAction` row exists where `correlation_id == audit_event.id`.
4. **Shape correctness:** `name == "session.create"`, `status == :ok`, `actor_ref.id == user.id`, `actor_ref.type == :user`.

### Forbidden under-sampling (do NOT accept as "validated")
- Asserting only that `record_action/2`/the forwarder was *called* (Mox stub / `:threadline_module` override) — violates D-01; samples wiring, not projection.
- Asserting only that *some* `audit_actions` row exists with no `correlation_id` join.
- Asserting `name`/`status` but not the actor or join key (misses "expected actor shape").
- Querying `Threadline.timeline/2`/`actor_history/2` (wrong tables — they query capture tables, not `audit_actions`).

---

## Wave 0 Requirements

- [ ] `test/example/test/example_web/threadline_forwarder_test.exs` — NEW, covers EX-01 (the only test file this phase adds).
- [ ] Two committed migrations under `test/example/priv/repo/migrations/` (capture **then** semantics) — verify ascending/distinct timestamps before commit (RESEARCH Pitfall 2: `mix threadline.install` generates both with a second-resolution timestamp and can collide; bump +1s if equal).
- [ ] `{:threadline, "~> 0.5", only: [:dev, :test]}` in `test/example/mix.exs` + updated `test/example/mix.lock`.
- No new framework install needed — ExUnit + ConnCase + SQL Sandbox already present (applied via the example's `test`/`setup` aliases → `ecto.migrate`).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Adopter grep discoverability ("grep `test/example/` for threadline → working reference in < 1 min") | EX-01 / Success Criterion #2 | Discoverability is a documentation/ergonomics property, not a runtime assertion | `grep -ri threadline test/example/` returns hits in mix.exs, accounts.ex, config.exs, the test, and AGENTS.md |

*All runtime behaviors have automated verification; the only manual check is the doc/grep discoverability ergonomic.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
