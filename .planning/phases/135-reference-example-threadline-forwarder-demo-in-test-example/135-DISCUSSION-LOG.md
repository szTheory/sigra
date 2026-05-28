# Phase 135: Reference Example — Threadline Forwarder Demo in `test/example/` - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-28
**Phase:** 135-reference-example-threadline-forwarder-demo-in-test-example
**Mode:** assumptions (`minimal_decisive` calibration)
**Areas analyzed:** Test materialization strategy; Dispatch mode + attach wiring; Dep scope / CI lane reuse / test tagging

## Assumptions Presented

### Test Materialization Strategy (the crux)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Assert a real `audit_actions` row from Threadline's real schema; no Mox/stub | Confident | `deps/threadline/lib/threadline.ex:40-62` (`record_action/2` does `repo.insert`); `lib/sigra/audit/forwarders/threadline.ex:294-296` (UUID→`correlation_id`) |
| Commit both `mix threadline.install` migrations (capture then semantics) into `test/example/priv/repo/migrations/` | Confident | `deps/threadline/lib/threadline/semantics/migration.ex:48-52` ALTERs the `audit_transactions` table created by `deps/threadline/lib/threadline/capture/migration.ex:24-31`; `test/example/mix.exs` `test` alias runs `ecto.migrate` |
| Trigger login via `ExampleWeb.UserAuth.log_in_user/2`, assert `audit_actions` row by `correlation_id == audit_event.id`, `name == "session.create"` | Confident | analog `test/example/test/example_web/audit_integration_test.exs:55-71` |
| Query `Threadline.Semantics.AuditAction` schema directly (no helper exists in 0.5.0) | Confident | `deps/threadline/lib/threadline.ex` read APIs query `audit_transactions`, not `audit_actions` |

### Dispatch Mode + Attach Wiring
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Use `dispatch: :sync` for deterministic synchronous assertion | Confident | example supervises no Oban; `lib/sigra/audit/forwarders.ex:90-101` `oban_running?/1` → `:auto` collapses to inline anyway |
| Attach forwarder in test setup, not at app boot (`attach(repo: Example.Repo, id: :test, ...)` + `on_exit` detach) | Confident | `test/example/lib/example/application.ex` never calls `Sigra.Application.attach_forwarders/0` |
| Pass `repo: Example.Repo` so the inline insert stays in the SQL sandbox connection | Confident | `test/example/test/support/conn_case.ex` / `data_case.ex` sandbox setup |

### Dep Scope / CI Lane Reuse / Tagging
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `{:threadline, "~> 0.5", only: [:dev, :test]}` in `test/example/mix.exs` | Confident | recipe pins `~> 0.5`; `:dev` scope keeps forwarder module compilable in dev-boot smoke lanes |
| Tag new test `@moduletag :example_app` only (NOT `:requires_threadline`) | Confident | `:requires_threadline` is library-suite dep-off concept (`ci.yml:205-219`); example never in that lane; `:example_app` is the gate (`test/example/test/test_helper.exs:1`) |
| Reuse existing `example_unit_smoke` lane (`mix test --include example_app`, `ci.yml:267`); no new job | Confident | success criterion #3 |
| Mirror `forwarders:` block into `config/config.exs` too (app-env surface `attach_forwarders/0` reads), in addition to `accounts.ex` (EX-01) | Confident | dual config surface in example app |

## Corrections Made

No corrections — all three areas confirmed via "Yes, proceed".

## External Research

None performed — Threadline 0.5.0 dep source answered the materialization question
(direct query on `Threadline.Semantics.AuditAction`; no `get_action_by_correlation_id`
helper exists). No external web research gap.
