---
phase: 131
slug: forwarder-behaviour-threadline-forwarder-library-scaffolding
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-27
---

# Phase 131 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `131-RESEARCH.md` §6 (Validation Architecture, Nyquist Dimension 8).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18 / OTP 27, Phoenix 1.8) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/audit/ test/sigra/workers/audit_forward_test.exs --max-cases 4` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Dep-off CI lane** | `mix test` run with `:threadline` excluded from `mix.lock` (new lane added this phase — TL-04 §2 in research) |
| **Estimated runtime** | ~6–10 s for `audit/` slice; ~25–40 s full suite (current baseline) |

All tests run against the live Postgres at `localhost:5432` per `./CLAUDE.md`. No `:postgres` tag exclusion. The Phase 131 `:integration` tag means "requires `audit_events` migrated in the test repo" — already true for the existing `test/sigra/audit/` suite.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/audit/` (quick slice covers the forwarder + its precedents).
- **After every plan wave:** Run `MIX_ENV=test mix test` (full suite — no watch mode).
- **Before `/gsd:verify-work`:** Full suite green + dep-off lane green + `mix docs --warnings-as-errors` clean + `mix credo --strict` clean.
- **Max feedback latency:** ~40 s (full suite worst case on local).

---

## Per-Task Verification Map

> Plans are not yet generated; this table is finalized by the planner in §6 of each `*-PLAN.md` and folded back here as Wave 0 ratchets. The rows below pin success-criterion → test-type mappings the planner MUST honor.

| Success Criterion | Test Type | Requirement | Threat Ref | Secure Behavior | Automated Command | Tag |
|-------------------|-----------|-------------|------------|-----------------|-------------------|-----|
| SC-1: Threadline present + configured → matching row + `[:sigra,:audit,:forward,:ok]` event with UUID+occurred_at metadata | integration | TL-01, TL-05, FB-01 | — | Audit-row UUID is the canonical idempotency key downstream; telemetry observable for monitoring | `mix test test/sigra/audit/forwarders/threadline_test.exs` | `:integration` |
| SC-2: Threadline absent → `mix compile && mix test` green; one boot `Logger.warning`; Noop substitutes | dep-off CI lane | TL-04 | — | Optional-dep absence MUST NOT break compile or test; warning informs operator | dep-off lane run (`mix.lock` without `:threadline`) | `:dep_off` |
| SC-3: Forced Threadline failure → `[:sigra,:audit,:forward,:error]` fires; audit row remains committed | integration | TL-01, TL-05 | Pitfall 2 (boundary doctrine) | Forwarder failure NEVER rolls back originating transaction; handler MUST NOT raise to `:telemetry` (auto-detach landmine) | `mix test test/sigra/audit/forwarders/threadline_test.exs --only forwarder_failure` | `:integration` |
| SC-4: `:auto`/`:async`/`:sync` dispatch matches `Sigra.Delivery`; `:async` raises at boot if Oban absent | unit + boot-error contract | TL-02, TL-03 | — | `:async` without Oban supervised = fail-fast at boot, never silent | `mix test test/sigra/audit/forwarders/dispatch_test.exs` + Oban-supervised vs not boot tests | `:unit` + `:integration` |
| SC-5: `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` attaches via same path as Threadline | unit (behaviour contract) | FB-01 | — | Behaviour generalizes beyond in-tree impl; no payload-shape coupling | `mix test test/sigra/audit/forwarder_test.exs` | `:unit` |

*Per-task rows (filled in by planner during plan generation, then ratcheted back here):*

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TBD | TBD | TBD | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

These test files MUST exist (as RED stubs at minimum) before the implementation wave starts:

- [ ] `test/sigra/audit/forwarder_test.exs` — behaviour contract test (SC-5; Mox-defmock attach contract)
- [ ] `test/sigra/audit/forwarders/threadline_test.exs` — impl tests (SC-1, SC-3; idempotency key, error path)
- [ ] `test/sigra/audit/forwarders/noop_test.exs` — fallback contract (SC-2 negative path)
- [ ] `test/sigra/audit/forwarders/dispatch_test.exs` — `:auto`/`:async`/`:sync` routing (SC-4)
- [ ] `test/sigra/workers/audit_forward_test.exs` — Oban worker tests (SC-4 worker path, cancel taxonomy)
- [ ] CI workflow update for `:dep_off` lane (SC-2)
- [ ] *Existing `test/sigra/audit/` directory already houses 7 sibling test files — pattern established; no new `conftest`/`test_helper.exs` setup required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | — | All 5 success criteria have automated verification per §6 of RESEARCH.md. Phase 131 has zero human UAT items (matches Jon's GSD-wide "zero-human UAT" preference). | — |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies declared
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING test files listed above
- [ ] No `--watch` / `--watch-all` flags anywhere in plans
- [ ] Feedback latency < 40 s on full suite
- [ ] Dep-off CI lane lands in this phase (per research recommendation §6) OR is explicitly deferred to Phase 136 PROOF-01
- [ ] `nyquist_compliant: true` set in frontmatter once planner ratchets per-task rows

**Approval:** pending (ratchets when planner fills per-task rows from PLAN.md files)
