# Phase 232: Playwright Economics — Authenticate Once, Then Shard - Context

**Gathered:** 2026-07-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Collapse the Playwright critical path in a deliberately measurable sequence: first remove
per-test design-board registration by authenticating once per design project, then restructure
the residual Playwright seams into independently isolated shards, and finally replace the
duplicated example-app boot prelude with one shared definition. The required check name
`Example Playwright smoke (full lifecycle)` remains byte-identical throughout.

Owns **PW-01, PW-02, and PW-03**. PW-01 must land and be measured before PW-02 changes the job
topology so the registration win and sharding win remain distinguishable. Proof comes from
retry-free observed runs and job durations, not from workflow-file inspection.

The user folded these two pending todos into the analysis:

- `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md`
- `.planning/todos/pending/2026-06-20-runtime-auth-prefix-override.md`

The first is implemented by this phase. The second is resolved as an explicitly rejected
isolation mechanism: per-shard databases meet the phase goal without changing Sigra's production
runtime or generated-host schema-prefix contract.
</domain>

<decisions>
## Implementation Decisions

### Authentication reuse and ordered measurement

- **D-01:** Add one explicit Playwright setup dependency for each of the three design projects.
  Each setup registers its own unique policy-valid `platform-admin+...` identity and writes a
  project-specific `storageState`; design tests consume the matching state rather than sharing
  one state file across viewport/theme projects.
- **D-02:** Remove `registerUser()` from `admin-design.spec.ts`'s per-test `beforeEach`. Retain only
  deterministic navigation plus existing LiveView and font readiness checks. Preserve role
  selectors, stable hooks, readiness signals, and the no-sleeps posture from the admin UI test
  contract.
- **D-03:** Land and observe PW-01 before any PW-02 topology change. Record the design-board job
  duration before and after with identical passing assertion and snapshot counts so the
  authentication-reuse improvement has its own receipt.

### Parallelization and state isolation

- **D-04:** Parallelize the existing independent Playwright seams as CI matrix shards. Each shard
  owns an isolated runner-local PostgreSQL service/database, example-app process, and listening
  port. Do not claim isolation by merely increasing `workers` or enabling `fullyParallel` against
  the current shared database and app.
- **D-05:** Prove correctness with a real run using more than one concurrent shard and
  `--retries=0`. Retries and `continue-on-error` remain forbidden as flake mitigation; any
  cross-spec interference must be removed rather than masked.
- **D-06:** Use separate databases—not per-shard auth schemas—for isolation. Do not add a
  production runtime auth-schema prefix override: generated schemas and migrations currently bake
  the prefix at install time, and a runtime-only override could point authentication queries at an
  unmigrated schema.

### Required context and shared boot prelude

- **D-07:** Put the shard jobs behind one terminal result aggregator whose displayed job name is
  exactly `Example Playwright smoke (full lifecycle)`. Every shard outcome must reach that
  aggregator; no seam may become advisory or disappear from the required verdict.
- **D-08:** Define the example-app boot prelude exactly once in a reusable workflow-level
  component and have every app-booting Playwright job consume it. The shared contract covers the
  applicable checkout/toolchain/cache/compile, database setup and migration, seeds, browser setup,
  app boot, and readiness behavior so individual lanes cannot drift.

### The agent's Discretion

- Exact setup-project names, state-file paths, and generated test identity suffixes, provided the
  three project states remain distinct and ephemeral.
- Exact shard count and seam-to-shard mapping after measuring the PW-01 baseline, provided the
  seams run concurrently with isolated databases/apps and all outcomes reach the required result.
- Whether the single boot definition is implemented as a composite action or another supported
  GitHub Actions reuse primitive. Research/planning should select the smallest mechanism that can
  parameterize the current jobs without changing their behavior.
- Exact evidence artifact layout and helper-script names, following the existing committed CI
  receipt patterns.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope, requirements, and proof discipline

- `.planning/ROADMAP.md` — Phase 232 boundary, success criteria, ordering, and byte-identical
  required-check constraint.
- `.planning/REQUIREMENTS.md` — PW-01/PW-02/PW-03 and milestone-wide no-coverage-loss guardrails.
- `.planning/METHODOLOGY.md` — decisive-defaulting, escalation, research-depth, and UX lenses.
- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` — canonical Playwright economics audit,
  recommended ordering, per-shard isolation rationale, and measurement expectations.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` — locked gallery split,
  project-level axe coverage, required-job posture, and explicit deferral of PW-01 to this phase.
- `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md` — locked honest-gate and
  generated-host parity decisions that this phase must not reopen.

### Folded todo inputs

- `.planning/todos/pending/2026-06-20-playwright-parallelization-per-shard-db.md` — original
  per-shard database-isolation proposal folded into PW-02.
- `.planning/todos/pending/2026-06-20-runtime-auth-prefix-override.md` — runtime-prefix proposal
  evaluated and rejected as the Phase 232 isolation mechanism.

### CI and admin test contracts

- `MAINTAINING.md` — ruleset-required check names and CI operating contract.
- `guides/reference/admin-ui-principles.md` — deterministic admin UI and interaction principles.
- `guides/reference/admin-design-contract.md` — canonical `sg-*` admin design/test contract.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `.github/workflows/ci.yml`'s `library_tests` result job provides the existing name-preserving
  aggregator pattern.
- `.github/workflows/ci.yml`'s primary Playwright smoke setup is the canonical source for the
  shared boot prelude; the recapture jobs expose the duplicated variants that must consume it.
- `test/example/priv/playwright/tests/admin-design.spec.ts` already contains deterministic
  LiveView/font readiness and project-derived admin identity helpers.
- `test/example/priv/playwright/helpers/fixtures.ts` owns the shared test-only password literal.

### Established Patterns

- `test/example/priv/playwright/playwright.config.ts` currently records the correctness posture as
  `fullyParallel: false`, `workers: 1`, shared base URL, and CI retry behavior; Phase 232 must
  replace the shared-state reason for serialization rather than simply deleting the guard.
- `.github/workflows/ci.yml` already aggregates individual Playwright seam outcomes into the
  required result; the sharded topology must preserve that hard-fail boundary.
- `test/example/config/dev.exs` already accepts database and port environment configuration,
  providing the per-shard process-isolation seams.
- `admin-design.spec.ts` distinguishes PR-retained axe/behavior coverage from event-gated
  snapshots; authentication reuse must preserve those project and coverage boundaries.

### Integration Points

- `.github/workflows/ci.yml` — restructure the primary required Playwright job, extract the shared
  boot definition, and connect every shard outcome to the terminal required context.
- `test/example/priv/playwright/playwright.config.ts` — add setup dependencies and per-project
  `storageState` wiring while preserving project viewport/theme identities.
- `test/example/priv/playwright/tests/admin-design.spec.ts` — remove per-test registration while
  retaining deterministic page readiness.
- `test/example/config/dev.exs` — consume existing database/port environment seams per shard.
- `test/example/lib/example/sigra_admin_policy.ex` — setup identities must retain the required
  `platform-admin+` prefix.
</code_context>

<specifics>
## Specific Ideas

- “Authenticate once, then shard” is an enforced sequencing rule, not merely the phase title.
- Keep the required check name byte-identical: `Example Playwright smoke (full lifecycle)`.
- Isolation is runner-local ownership. Shards may use the same numeric port/database name on
  separate runners, but no two concurrent seams may share a live app or database.
- The folded runtime-prefix todo does not authorize a generated-host/public contract expansion.
</specifics>

<deferred>
## Deferred Ideas

- A production runtime/boot-time auth-schema prefix override remains deferred. It needs an
  explicit generated-host and migration contract in a separate feature phase if ever promoted.
- The remaining automated todo matches were outside PW-01/PW-02/PW-03 and remain in their existing
  backlog/phase ownership; none were folded into Phase 232.
</deferred>

---

*Phase: 232-playwright-economics-authenticate-once-then-shard*
*Context gathered: 2026-07-31*
