# Phase 135: Reference Example — Threadline Forwarder Demo in `test/example/` - Context

**Gathered:** 2026-05-28 (assumptions mode, `minimal_decisive` calibration)
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the EXISTING `test/example/` app (NOT a new top-level `examples/` directory)
with a runnable Threadline forwarder demo that exercises Phase 131's library code
through Phase 132's recipe config block, proven via existing CI lanes.

**Hard scope anchors (from ROADMAP.md / REQUIREMENTS.md EX-01, NOT re-litigated here):**

- Four deliverables, all inside `test/example/`:
  1. `test/example/mix.exs` adds Threadline as a dev/test-scoped dep.
  2. `test/example/lib/example/accounts.ex` adds the `forwarders:` block under the
     existing `audit:` keyword in `sigra_config/0`.
  3. A new `test/example/test/example_web/threadline_forwarder_test.exs` asserts a
     Sigra login audit event materializes as a Threadline row.
  4. `test/example/AGENTS.md` documents the demo wiring.
- **No new top-level `examples/` directory** — `test/example/` is already CI-wired
  (3 jobs in `ci.yml`) and was the resolution to Phase 114's nested-example-app drift
  (REQUIREMENTS.md Out-of-Scope). Re-opening `examples/` re-opens that wound.
- **No new CI jobs** — reuse existing `test/example/` lanes. (Success criterion #3.)
- The `forwarders:` block pins LITERALLY against the frozen Phase 131 shape, as
  published in Phase 132's `guides/recipes/companion-libs/threadline.md`. The example
  app is the recipe's working proof, not a divergent variant.
- Library code is frozen — Phase 135 writes NO new code under `lib/`. Only
  `test/example/` files change.
</domain>

<decisions>
## Implementation Decisions

### Test Materialization Strategy (EX-01, Success Criterion #1) — the crux

- **D-01:** The test asserts a **real** `audit_actions` row inserted by Threadline's
  real schema/store. **No Mox stub, no `threadline_module:` override, no test sink.**
  The demo's entire value is a real end-to-end projection an adopter can copy.
- **D-02:** Commit the **two** `mix threadline.install`-generated migrations into
  `test/example/priv/repo/migrations/`, in dependency order: the capture migration
  (creates `audit_transactions`) THEN the semantics migration (ALTERs
  `audit_transactions` + creates `audit_actions`). Both are required — the semantics
  migration ALTERs a table the capture migration creates
  (`deps/threadline/lib/threadline/semantics/migration.ex:48-52` depends on
  `deps/threadline/lib/threadline/capture/migration.ex:24-31`). The example's `test`
  alias already runs `ecto.migrate --quiet` (`test/example/mix.exs`), so they apply
  automatically.
- **D-03:** The test triggers a login through the existing example-app auth path
  (`ExampleWeb.UserAuth.log_in_user/2`), then asserts via `Example.Repo` a single row:
  `Repo.one(from a in Threadline.Semantics.AuditAction, where: a.correlation_id == ^audit_event.id)`
  with `name == "session.create"` and the actor reference carrying the user id. The
  Sigra audit UUID → Threadline `:correlation_id` mapping is the join key
  (`lib/sigra/audit/forwarders/threadline.ex:294-296`).
- **D-04:** Query the `Threadline.Semantics.AuditAction` Ecto schema directly. Threadline
  0.5.0 exposes no `get_action_by_correlation_id`-style helper, and the higher-level
  read APIs (`Threadline.actor_history/2`, `Threadline.timeline/2`) query the
  trigger-capture tables (`audit_transactions`/`audit_changes`), NOT `audit_actions`.
- **D-05:** Closest analog to copy structurally:
  `test/example/test/example_web/audit_integration_test.exs:55-71` (login-trigger →
  `Repo`-query-the-audit-table). The new test is one hop downstream into
  `audit_actions`.

### Dispatch Mode + Forwarder Attach Wiring (Success Criterion #1)

- **D-06:** Use `dispatch: :sync` in the reference `forwarders:` block (NOT the
  canonical `:auto`). The example app supervises no Oban, so `:auto` already collapses
  to inline (`oban_running?/1` returns false — `lib/sigra/audit/forwarders.ex:90-101`);
  pinning `:sync` makes intent explicit and the assertion deterministic immediately
  after `log_in_user`. `:async` is forbidden here — it raises at boot without Oban
  (`lib/sigra/application.ex` attach path).
- **D-07:** **Attach the forwarder in the test setup**, not at app boot. The example's
  `Example.Application.start/2` is a vanilla Phoenix tree that never calls
  `Sigra.Application.attach_forwarders/0`, so a config block alone does not auto-attach.
  Test setup calls `Sigra.Audit.Forwarders.Threadline.attach(repo: Example.Repo, id: :test, dispatch: :sync, ...)`
  with an `on_exit` `:telemetry.detach/1` using the same handler id.
- **D-08:** Pass `repo: Example.Repo` to `attach/1`. The `:sync` inline `record_action/2`
  runs in the test process, so the insert must use the repo that owns the
  `Ecto.Adapters.SQL.Sandbox` connection (`test/example/test/support/conn_case.ex`,
  `data_case.ex` sandbox setup) — otherwise the row is invisible to the follow-up query
  and/or leaks past rollback.

### Dep Scope, CI Lane Reuse, Test Tagging (Success Criteria #2, #3)

- **D-09:** Add `{:threadline, "~> 0.5", only: [:dev, :test]}` to `test/example/mix.exs`
  deps. `~> 0.5` matches the recipe pin (Phase 132). `:dev` scope (not `:test`-only)
  keeps the forwarder module compilable in the dev-boot smoke lanes
  (`example_http_smoke` / `example_playwright_smoke` boot `mix phx.server` in dev), so
  the reference config emits no `maybe_warn_missing_forwarder_deps` warning at dev boot.
- **D-10:** Tag the new test `@moduletag :example_app` **only**. Do NOT add
  `:requires_threadline` — that tag is a library-suite concept for the repo-root dep-off
  lane (`ci.yml:205-219`, `test/sigra/audit/forwarders/threadline_test.exs:13`); the
  example app is never part of that lane (it runs from repo root with no
  `working-directory: test/example`). `:example_app` is the gate
  (`test/example/test/test_helper.exs:1` excludes by default; the lane includes via
  `--include example_app`).
- **D-11:** The existing `example_unit_smoke` CI lane runs `mix test --include example_app`
  (`ci.yml:267`) and will execute the new test with **no new job**. Verify no other lane
  needs editing.
- **D-12:** Mirror the `forwarders:` block into `test/example/config/config.exs`'s
  `config :example, :sigra_config` too (in addition to `accounts.ex` per EX-01).
  `config.exs` is the surface `attach_forwarders/0` actually reads, and dual placement
  maximizes adopter-grep fidelity (success criterion #2: "grep `test/example/` for
  'threadline' and find a working reference in under a minute").
- **D-13:** Append a clearly-titled "Threadline audit forwarder demo" section to the
  existing `test/example/AGENTS.md` — additive, matching its existing section-header
  style.

### Claude's Discretion

- Exact migration filenames/timestamps for the two committed Threadline migrations
  (planner/executor runs `mix threadline.install` and commits what it generates, in the
  capture-then-semantics order D-02 requires).
- Whether the test attaches the forwarder in a `setup` block or inline per-test, and the
  exact `on_exit` detach shape — internal test structure, below the escalation threshold.
- Exact `actor` mapping arg shape passed through to `record_action/2` (the executor
  reads `lib/sigra/audit/forwarders/threadline.ex:238-307` for the required `:actor`
  shape; the test asserts the resulting `actor_ref` carries the user id).
- Prose voice of the `AGENTS.md` section and the inline comments in the config block.

### Folded Todos

None — no pending todos crossed Phase 135's scope window.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Repo files — analogs Phase 135 mirrors and code it pins against

- `/Users/jon/projects/sigra/test/example/test/example_web/audit_integration_test.exs` — the closest analog test; copy its login-trigger + `Repo`-query structure (new test is one hop downstream into `audit_actions`).
- `/Users/jon/projects/sigra/lib/sigra/audit/forwarders/threadline.ex` (lines 99-160, 238-307) — `attach/1` + `handle_event/4` + `call_threadline/2`; `:sync` calls `record_action/2` inline, accepts `:repo`/`:threadline_module`/`:actor_type` opts, maps Sigra UUID → `correlation_id` (294-296).
- `/Users/jon/projects/sigra/lib/sigra/audit/forwarders.ex` (lines 89-110) — `oban_running?/1` / dispatch resolution proving `:auto` collapses to `:sync` when Oban absent (it is, in the example).
- `/Users/jon/projects/sigra/lib/sigra/application.ex` (lines 123-169) — `attach_forwarders/0` reads `Application.get_env(otp_app, :sigra_config)[:audit][:forwarders]` and raises on `:async` without Oban; explains why the example must attach in test (its Application doesn't call this).
- `/Users/jon/projects/sigra/deps/threadline/lib/threadline.ex` (lines 40-62, 240-253) — `record_action/2` contract: required `:actor`+`:repo`, maps `:correlation_id`/`:status`, returns `{:ok, %AuditAction{}}`.
- `/Users/jon/projects/sigra/deps/threadline/lib/threadline/semantics/audit_action.ex` — the `audit_actions` Ecto schema the test queries (`name`, `actor_ref`, `correlation_id`, `status`).
- `/Users/jon/projects/sigra/deps/threadline/lib/threadline/capture/migration.ex` AND `/Users/jon/projects/sigra/deps/threadline/lib/threadline/semantics/migration.ex` — the two `mix threadline.install` migrations; semantics ALTERs the capture-created `audit_transactions`, so both must be committed and run in order.
- `/Users/jon/projects/sigra/test/example/lib/example/application.ex` — confirms NO Oban child and NO `attach_forwarders/0` call; the gap the test must bridge by attaching itself.
- `/Users/jon/projects/sigra/test/example/lib/example/accounts.ex` (lines 590-622) — `sigra_config/0`; add `forwarders:` under the existing `audit:` keyword (per EX-01).
- `/Users/jon/projects/sigra/test/example/config/config.exs` (lines 43-63) — `config :example, :sigra_config` app-env surface (the surface `attach_forwarders/0` reads); mirror the `forwarders:` entry here too (D-12).
- `/Users/jon/projects/sigra/test/example/mix.exs` (lines 41-71, aliases 81-86) — deps list (add `{:threadline, "~> 0.5", only: [:dev, :test]}`; `mox` is already `only: :test` precedent); `test`/`setup` aliases run `ecto.migrate`.
- `/Users/jon/projects/sigra/test/example/test/test_helper.exs` + `/Users/jon/projects/sigra/test/example/test/support/conn_case.ex` + `data_case.ex` — the `:example_app` exclude gate and SQL-sandbox setup the `:sync` inline insert must run within (pass `repo: Example.Repo`).
- `/Users/jon/projects/sigra/test/example/AGENTS.md` — add the "Threadline audit forwarder demo" section here (D-13).
- `/Users/jon/projects/sigra/.github/workflows/ci.yml` (lines 205-219 dep-off lane; 221-267 `example_unit_smoke`) — dep-off runs from repo root (not the example); `example_unit_smoke` runs `mix test --include example_app` (the lane that executes the new test, no new job).
- `/Users/jon/projects/sigra/guides/recipes/companion-libs/threadline.md` — the Phase 132 recipe the example proves; the `forwarders:` block must match it literally.

### Planning artifacts

- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — EX-01 (line 44) + Out-of-Scope (lines 63-73, esp. no `examples/` dir).
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` — Phase 135 Goal + Success Criteria #1–#3 (lines 134-146).
- `/Users/jon/projects/sigra/.planning/phases/131-forwarder-behaviour-threadline-forwarder-library-scaffolding/131-CONTEXT.md` — frozen `forwarders:` config shape (D-05/D-06), telemetry contract, dispatch semantics.
- `/Users/jon/projects/sigra/.planning/phases/132-threadline-recipe-mailglass-cross-link-recipe/132-CONTEXT.md` — the recipe block the example pins against (D-05/specifics).
- `/Users/jon/projects/sigra/.planning/METHODOLOGY.md` — Decisive Defaulting + Escalation Threshold lenses applied in this CONTEXT.
- `/Users/jon/projects/sigra/.planning/STATE.md` — v1.29 milestone status, locked decisions.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Analog test:** `test/example/test/example_web/audit_integration_test.exs` already
  proves the login→audit-row pattern (login via `log_in_user`, then `Repo`-query the
  Sigra audit table). The new test reuses that scaffold and follows the row one hop
  downstream into Threadline's `audit_actions`.
- **Forwarder code (Phase 131 shipped):** `lib/sigra/audit/forwarders/threadline.ex`
  `attach/1` accepts `:repo`, `:id`, `:dispatch`, `:threadline_module`, `:actor_type`
  opts and runs `record_action/2` inline on the `:sync` path — directly callable from
  test setup.
- **Dispatch resolution:** `lib/sigra/audit/forwarders.ex` `oban_running?/1` makes
  `:auto` deterministic-inline when Oban is absent (the example's case).
- **Threadline 0.5.0 store:** `Threadline.record_action/2` + `Threadline.Semantics.AuditAction`
  schema give a concrete, queryable insert target — no mocking required.
- **Example app test conventions:** `@moduletag :example_app` + `test_helper.exs`
  `exclude: [:example_app]` + `mix test --include example_app` lane; SQL-sandbox setup
  in `conn_case.ex`/`data_case.ex`.

### Established Patterns

- **`:example_app` tagging:** every example test carries `@moduletag :example_app`;
  default runs exclude it, the CI lane includes it. The new test must follow this.
- **Optional-dep scoping in the example:** `mox` is already `only: :test`; Sigra's
  optional deps (oban, hammer, assent, joken, eqrcode, swoosh) are listed plainly.
  Threadline joins as `only: [:dev, :test]` so the dev-boot smoke lanes still compile
  the forwarder module.
- **Migrations are applied via the `test`/`setup` aliases** (`ecto.migrate`), so
  committed Threadline migrations auto-apply in CI with no lane edit.
- **Dual config surface:** the example carries Sigra config in BOTH
  `lib/example/accounts.ex` `sigra_config/0` AND `config/config.exs`
  `config :example, :sigra_config`. `attach_forwarders/0` reads the app-env (config.exs)
  surface; EX-01 names `accounts.ex`. The block goes in both.

### Integration Points

- **`test/example/mix.exs` deps** — add `{:threadline, "~> 0.5", only: [:dev, :test]}`.
- **`test/example/lib/example/accounts.ex` `sigra_config/0`** (~590-622) — add
  `forwarders:` under the existing `audit:` keyword.
- **`test/example/config/config.exs`** (~43-63) — mirror the `forwarders:` entry.
- **`test/example/priv/repo/migrations/`** — commit the two Threadline install
  migrations (capture then semantics).
- **`test/example/test/example_web/threadline_forwarder_test.exs`** (NEW) — `@moduletag
  :example_app`; attaches forwarder with `repo: Example.Repo`; asserts the
  `audit_actions` row.
- **`test/example/AGENTS.md`** — new "Threadline audit forwarder demo" section.
- **`.github/workflows/ci.yml` `example_unit_smoke`** — executes the new test as-is
  (`mix test --include example_app`); no edit, no new job.
</code_context>

<specifics>
## Specific Ideas

- **Literal recipe parity:** the `forwarders:` block in `accounts.ex` / `config.exs`
  reproduces the Phase 132 `guides/recipes/companion-libs/threadline.md` block, with
  `dispatch: :sync` (D-06) instead of `:auto` for deterministic test assertion. If the
  planner prefers to keep the published `:auto` literal in the committed config and pass
  `dispatch: :sync` only in the test's `attach/1` call, that is acceptable — the
  attach-call opts are what govern the `:sync` test path (D-07/D-08). Planner picks
  whichever keeps the demo's reference value highest while staying deterministic.
- **Join-key assertion:** assert on `correlation_id == audit_event.id` (the Sigra audit
  UUID), `name == "session.create"`, and the actor reference carrying the user id —
  this is the "expected actor + action shape" of success criterion #1.
- **Grep target:** an adopter running `grep -ri threadline test/example/` should hit the
  dep (mix.exs), the config block (accounts.ex + config.exs), the test, and the
  AGENTS.md section — a working reference in under a minute (success criterion #2).
</specifics>

<deferred>
## Deferred Ideas

- **Recipe-contract test fixtures** (walk `guides/recipes/companion-libs/*.md` and assert
  required section headings + version pins + banner) — carried from Phase 131/132
  deferred lists; v1.29-future or post-v1.29, not Phase 135.
- **Threadline correlation-ID propagation (Sigra → Threadline trace correlation)** —
  v1.30 candidate (Phase 131 deferred).
- **`mix sigra.doctor` adopter-facing diagnostic** — out of v1.29 (Phase 131/132
  deferred).
- **A second forwarder (Datadog/Honeycomb/custom) demo in the example app** — would
  prove the behaviour generalizes, but EX-01 scopes exactly one Threadline demo. New
  scope; not this phase.

### Reviewed Todos (not folded)

None reviewed this round — no pending todos crossed Phase 135's scope window.
</deferred>
