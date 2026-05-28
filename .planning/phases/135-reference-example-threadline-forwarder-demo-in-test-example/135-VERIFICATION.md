---
phase: 135-reference-example-threadline-forwarder-demo-in-test-example
verified: 2026-05-28T00:00:00Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  note: initial verification
---

# Phase 135: Reference Example — Threadline Forwarder Demo Verification Report

**Phase Goal:** Extend the existing `test/example/` app with a runnable Threadline forwarder demo that proves the Sigra→Threadline wiring end-to-end via the existing CI lanes (no new top-level `examples/` dir, no new CI job).
**Verified:** 2026-05-28
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | Running `threadline_forwarder_test.exs` inside `test/example/` exits 0 and drives the REAL auth path (`ExampleWeb.UserAuth.log_in_user/2`), asserting a real `Threadline.Semantics.AuditAction` row joined on `correlation_id == audit_event.id`. | ✓ VERIFIED | I ran the test myself: `mix test test/example_web/threadline_forwarder_test.exs --include example_app` → `1 test, 0 failures` (exit 0). Test L64-66 drives `conn \|> Plug.Test.init_test_session(%{}) \|> ExampleWeb.UserAuth.log_in_user(user)` (real path, no direct `Sigra.Audit` call). L80-81 joins `Repo.one(from a in AuditAction, where: a.correlation_id == ^audit_event.id)`. |
| 2 | The asserted Threadline row has `name == "session.create"`, `status == :ok`, `actor_ref.id == user.id`, `actor_ref.type == :user` (struct field access). | ✓ VERIFIED | Test L84-87 asserts exactly these four conditions via struct field access (`action.actor_ref.id`, `action.actor_ref.type`), not map access. Assertions execute as part of the passing test. |
| 3 | `grep -ri threadline test/example/` finds the dep, both config blocks (config.exs + accounts.ex), the test, and the AGENTS.md section. | ✓ VERIFIED | `grep -ril threadline test/example/` returns 9 files: AGENTS.md, config/config.exs, lib/example/accounts.ex, mix.exs, mix.lock, all 3 migrations, and the test file. All required touchpoints present. |
| 4 | NO new top-level `examples/` directory; NO new CI job; the existing `example_unit_smoke` lane runs the test as-is. | ✓ VERIFIED | No `examples/` dir exists (`ls -d examples/` → absent). `git diff --stat 8137e53 HEAD -- .github/workflows/` is empty (no CI changes). ci.yml:221 `example_unit_smoke` runs `mix test --include example_app` (ci.yml:267) — I ran that exact command: `236 tests, 0 failures`. |
| 5 | NO file under repo-root `lib/` is modified (library code frozen). `test/example/lib/example/accounts.ex` IS expected to change. | ✓ VERIFIED | `git diff --stat 8137e53 HEAD -- lib/` is empty (zero repo-root lib/ changes). The only `lib/` change is `test/example/lib/example/accounts.ex` (host-app code, expected). |
| 6 | `test/example/mix.exs` carries Threadline as a `:dev, :test`-scoped dep; both config surfaces carry the `forwarders:` block under the existing `audit:` keyword; AGENTS.md documents the demo. | ✓ VERIFIED | mix.exs:70 `{:threadline, "~> 0.5", only: [:dev, :test]}` (exact tuple). accounts.ex:609-621 and config.exs:52-64 carry byte-identical `forwarders:` blocks under `audit:` with `module: Sigra.Audit.Forwarders.Threadline`, `id: :default`, `dispatch: :auto`, `repo: Example.Repo`. AGENTS.md:192 `## Threadline audit forwarder demo` section present after the usage-rules fence (L190). |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `test/example/mix.exs` | Threadline `:dev,:test` dep | ✓ VERIFIED | L70 exact tuple `{:threadline, "~> 0.5", only: [:dev, :test]}`. |
| `test/example/mix.lock` | committed lock with threadline | ✓ VERIFIED | Contains `threadline` entry (resolved to 0.6.0 — see deviation note). |
| `*_threadline_audit_schema.exs` (capture) | creates `audit_transactions` | ✓ VERIFIED | `20260528152137`, module `ThreadlineAuditSchema`, `def up`/`def down`, `CREATE TABLE ... audit_transactions`. |
| `*_threadline_semantics_schema.exs` (semantics) | creates `audit_actions`, ALTERs `audit_transactions` | ✓ VERIFIED | `20260528152138`, module `ThreadlineSemanticsMigration`, `CREATE TABLE audit_actions` + `ALTER TABLE audit_transactions`. Timestamp sorts after capture. |
| `*_threadline_governance_schema.exs` (governance) | creates governance tables | ✓ VERIFIED | `20260528152139`, module `ThreadlineGovernanceSchema`. Extra 3rd migration from 0.6.0 (deviation, committed verbatim). |
| `test/example/lib/example/accounts.ex` | `forwarders:` block under `audit:` | ✓ VERIFIED | L609-621, `Sigra.Audit.Forwarders.Threadline` present, no other key changed. |
| `test/example/config/config.exs` | mirrored `forwarders:` block | ✓ VERIFIED | L52-64, byte-identical to accounts.ex block. |
| `test/example/AGENTS.md` | demo section outside usage-rules fence | ✓ VERIFIED | L192 section after `<!-- usage-rules-end -->` (L190); names 4 touchpoints; no marketing voice. |
| `test/example/test/example_web/threadline_forwarder_test.exs` | full projection-chain assertion | ✓ VERIFIED | Asserts the real correlation_id join + actor/action shape; passes. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| test setup | `Sigra.Audit.Forwarders.Threadline.attach/1` | `attach(repo: Example.Repo, id: :test, dispatch: :sync, actor_type: :user)` + on_exit detach | ✓ WIRED | Test L43-49 attaches; L51-56 on_exit detaches `:test` AND re-attaches `:default` via `Sigra.Application.attach_forwarders()` (CR-02/WR-02 remediation, commit d7e508e). |
| test assertion | `Threadline.Semantics.AuditAction` (audit_actions) | `Repo.one(from a in AuditAction, where: a.correlation_id == ^audit_event.id)` | ✓ WIRED | Test L80-81. Join on correlation_id, not weakened to "some row exists". |
| semantics migration | capture migration | semantics ALTERs `audit_transactions`; semantics timestamp > capture timestamp | ✓ WIRED | capture=152137 < semantics=152138 < governance=152139 (ascending). Both migrations apply cleanly (proven by passing test which runs `ecto.migrate --quiet` via the `test` alias). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `threadline_forwarder_test.exs` | `action` (AuditAction row) | `Repo.one` against live Postgres after real login → telemetry `[:sigra, :audit, :log]` → `Sigra.Audit.Forwarders.Threadline` inline `record_action/2` insert | ✓ FLOWING | Real DB round-trip: login emits the Sigra audit event, the `:sync` forwarder projects it into `audit_actions`, and the assertion reads it back joined on `correlation_id`. No mock/stub/sink (no Mox, no `threadline_module:` override). The asserted values (name/status/actor_ref) come from a real persisted row. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Focused integration test green | `mix test test/example_web/threadline_forwarder_test.exs --include example_app` | `1 test, 0 failures` (exit 0) | ✓ PASS |
| Lane parity (example_unit_smoke, ci.yml:267) | `mix test --include example_app` | `236 tests, 0 failures` (exit 0) | ✓ PASS |
| Dep scope exact | `grep '{:threadline, "~> 0.5", only: [:dev, :test]}' mix.exs` | match | ✓ PASS |
| No dead HTTP keys | `grep 'THREADLINE_ENDPOINT\|THREADLINE_API_KEY\|api_key:' lib config` | none | ✓ PASS |
| No marketing voice in AGENTS.md | `grep -i 'seamlessly\|just works\|production-ready out of the box\|the recommended way'` | none | ✓ PASS |

Note: the `236 tests` run emits expected log noise (a `Jetstream #907` structural-defense LiveView test deliberately triggers an out-of-band event that raises in a separate process). The suite still finishes `0 failures`.

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| (none) | — | Phase declares no `scripts/*/tests/probe-*.sh`; verification is via the example_unit_smoke lane test, executed above | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| EX-01 | 135-01-PLAN.md | `test/example/` extends with a working Threadline forwarder demo: dep in mix.exs, `forwarders:` block in accounts.ex, integration test asserting a Sigra audit event materializes as a Threadline row, AGENTS.md documents wiring, no new top-level `examples/` dir. | ✓ SATISFIED | All five sub-clauses verified: dep (mix.exs:70), config (accounts.ex:609 + config.exs:52), test (passes, asserts the projection), AGENTS.md (L192 section), no `examples/` dir. REQUIREMENTS.md:94 maps EX-01 → Phase 135 (Active). No orphaned requirements for this phase. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | — | No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers in any phase-modified file | — | Clean |

### Info-Level Observations (non-blocking)

1. **Threadline resolved to 0.6.0, not 0.5.0** — `~> 0.5` allows minor bumps. API/schema compatible (`record_action/2`, `AuditAction`, `ActorRef` unchanged); test passes against 0.6.0. The dep constraint string `"~> 0.5"` still matches the plan artifact contract exactly. Documented in SUMMARY deviation #1.

2. **Three migrations, not two** — 0.6.0 adds a governance migration (`threadline_export_jobs`, `threadline_retention_runs`). All three committed verbatim with ascending timestamps (152137/152138/152139). The plan's must_have artifacts named only capture+semantics; the third is an additive superset that does not violate any constraint (it applies cleanly and is not referenced by the demo's happy path). Documented in SUMMARY deviation #2.

3. **CR-01 (deferred, tracked)** — The capture migration's `CREATE TABLE audit_transactions` (L6-12) omits the `actor_ref` column that its own trigger function (L36) inserts into; `actor_ref` is added by the semantics ALTER. This is a forward-reference in Threadline's **generated** DDL, committed verbatim by design. It only breaks a partial `mix ecto.rollback` to exactly migration 1's state; the demo's happy path uses the Semantics `record_action/2` API (not the capture trigger) and never partial-rolls-back, so the test is unaffected. Upstream Threadline concern, tracked in REVIEW remediation — NOT a gap against this phase's goal.

4. **AGENTS.md migration count nit** — AGENTS.md L208 says "Two committed migrations" but there are three (governance was added by 0.6.0). Documentation accuracy nit; the demo wiring is fully described and discoverable. Non-blocking.

### Human Verification Required

None. All three Success Criteria are programmatically verifiable and were verified by direct command execution in this session (focused test green, full lane green, structural greps, git-diff invariants). No visual/UX/real-time/external-service behavior is involved.

### Gaps Summary

No gaps. The phase goal is achieved and independently confirmed in the codebase:

- The integration test exists, drives the real auth path, asserts the real Threadline `audit_actions` projection joined on `correlation_id`, and passes (exit 0) — both in isolation and via the existing `example_unit_smoke` lane command (`236 tests, 0 failures`).
- All four grep touchpoints (dep, dual config, test, AGENTS.md) plus migrations are discoverable under `test/example/`.
- The frozen-library invariant holds (zero repo-root `lib/` changes), no `examples/` dir was created, and no CI workflow was modified.
- EX-01 is fully satisfied with no orphaned requirements.

The 0.6.0/three-migration deviations and the deferred CR-01 trigger issue are honestly documented, were verified against the code, and do not block the phase goal.

---

_Verified: 2026-05-28_
_Verifier: Claude (gsd-verifier)_
