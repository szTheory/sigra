# Phase 130: Verification And Release Readiness - Research

**Researched:** 2026-05-27 [VERIFIED: environment current_date]
**Domain:** Elixir/Phoenix release-readiness verification, ExUnit evidence capture, GSD requirements traceability [VERIFIED: .planning/ROADMAP.md; mix.exs; .planning/v1.28-MILESTONE-AUDIT.md]
**Confidence:** HIGH [VERIFIED: local repo artifacts and local Mix help]

## User Constraints

No `130-CONTEXT.md` exists for this phase, so there are no phase-specific locked decisions, discretion notes, or deferred ideas to copy from discuss-phase. [VERIFIED: gsd-sdk query init.phase-op 130]

## Summary

Phase 130 should be planned as a proof-and-alignment phase, not a feature phase: `PROOF-01` is still pending because the phase has no plan, summary, validation, or verification artifact, while Phases 127-129 already report passed verification for export, deletion lifecycle, generated-host parity, and documentation truth. [VERIFIED: .planning/REQUIREMENTS.md; .planning/v1.28-MILESTONE-AUDIT.md; .planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md; .planning/phases/128-account-deletion-lifecycle-truth/128-VERIFICATION.md; .planning/phases/129-generated-host-parity-and-docs/129-VERIFICATION.md]

The planner should create a single plan that reruns the targeted DATA-LIFECYCLE suites, runs the broader release-relevant gates, records blockers explicitly if any broader lane fails, and repairs requirements/roadmap traceability so all v1.28 requirements map to completed active-roadmap phases before commit/push. [VERIFIED: .planning/ROADMAP.md; .planning/v1.28-MILESTONE-AUDIT.md; .github/workflows/ci.yml]

**Primary recommendation:** Use one verification/readiness plan that produces fresh command evidence, a traceability matrix, `130-VALIDATION.md`, `130-VERIFICATION.md`, and updates `PROOF-01` from Pending to Complete only after evidence is captured. [VERIFIED: .planning/REQUIREMENTS.md; .planning/v1.28-MILESTONE-AUDIT.md; .planning/config.json]

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROOF-01 | Targeted tests prove export shape, optional-schema degradation, deletion lifecycle truth, worker scheduling behavior, and generated-host parity. | Use the existing targeted suites from Phase 127-129 verification plus final traceability and CI-equivalent release gates. [VERIFIED: .planning/REQUIREMENTS.md; .planning/v1.28-MILESTONE-AUDIT.md] |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Sigra targets Phoenix 1.8+ / Ecto 3.x, with PostgreSQL primary and Plug compatibility where it does not compromise DX. [VERIFIED: CLAUDE.md]
- Security-sensitive defaults include OWASP standards, Argon2id, HMAC-protected tokens, and enumeration prevention by default. [VERIFIED: CLAUDE.md]
- Dependencies should remain minimal; copy-paste is preferred over dependencies when code is small and stable. [VERIFIED: CLAUDE.md]
- Tests should cover happy path, main error cases, and boundaries in AAA style, flat and self-contained. [VERIFIED: CLAUDE.md]
- Root `mix test` requires live Postgres at `localhost:5432` with `postgres` / `postgres`; missing DB fails fast. [VERIFIED: CLAUDE.md; test/test_helper.exs]
- Full local suite command is `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`. [VERIFIED: CLAUDE.md]
- GSD workflow expects repo edits to stay inside GSD command flow; this phase is already invoked through GSD research/planning. [VERIFIED: CLAUDE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Export contract proof | Test / Verification | Library | The exported payload is produced by `Sigra.DataExport.export_auth_data/3`, but Phase 130 owns fresh proof that the existing tests still pass. [VERIFIED: lib/sigra/data_export.ex; test/sigra/data_export_test.exs] |
| Deletion lifecycle proof | Test / Verification | Library + Worker | `Sigra.Account.Deletion` and `Sigra.Workers.AccountDeletion` own runtime behavior; Phase 130 should prove schedule/cancel/execute/worker behavior through targeted tests. [VERIFIED: lib/sigra/account/deletion.ex; lib/sigra/workers/account_deletion.ex; test/sigra/account/deletion_test.exs; test/sigra/workers/account_deletion_test.exs] |
| Generated-host parity proof | Test / Verification | Generator + Example App | Templates, example app, and golden fixture already delegate to library APIs; Phase 130 should re-run their parity tests. [VERIFIED: priv/templates/sigra.install/core/auth.ex; test/example/lib/example/accounts.ex; test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex] |
| Documentation release gate | Test / Verification | Docs | CI runs docs with `--warnings-as-errors`; Phase 130 should treat docs warnings as release blockers or explicitly record them. [VERIFIED: .github/workflows/ci.yml; mix help docs] |
| Requirements traceability | Planning Artifacts | GSD State | `PROOF-01` is the only pending v1.28 requirement and the audit says final proof plus traceability repair are required. [VERIFIED: .planning/REQUIREMENTS.md; .planning/v1.28-MILESTONE-AUDIT.md] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 with OTP 28 runtime | Run ExUnit, docs, compile, and project tasks | Current local toolchain matches `.tool-versions` Elixir 1.19.5 / OTP 28 intent. [VERIFIED: mix --version; .tool-versions] |
| ExUnit via Mix | Bundled with Elixir 1.19.5 | Test framework and evidence command surface | `mix test` loads `test/test_helper.exs`, requires matching test files, supports targeted file paths and `--max-failures`. [VERIFIED: mix help test] |
| ExDoc | 0.40.1 locked | Documentation build gate | CI uses `mix docs --warnings-as-errors` in the library test job. [VERIFIED: mix deps; .github/workflows/ci.yml] |
| PostgreSQL | Local server accepting on 5432; CI uses postgres:15 | Required for full root test lane | Project instructions say root tests require Postgres credentials `postgres` / `postgres`; local `pg_isready` reports accepting connections. [VERIFIED: CLAUDE.md; pg_isready] |
| GSD SDK | local CLI present | Phase/traceability operations and commit docs | `gsd-sdk query init.phase-op 130` found the phase and `commit_docs: true`. [VERIFIED: gsd-sdk query init.phase-op 130] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Phoenix | 1.8.5 locked | Framework/generator compatibility context | Use only as existing dependency context; Phase 130 should not change Phoenix code unless verification exposes a blocker. [VERIFIED: mix deps; mix.exs] |
| Ecto / Ecto SQL | 3.13.5 locked | Query and Repo behavior behind export/lifecycle tests | Required indirectly by targeted export/lifecycle tests and full suite. [VERIFIED: mix deps; mix.exs] |
| Oban | 2.21.1 locked | Account deletion worker changeset/scheduling behavior | Required indirectly for account-deletion enqueue proof. [VERIFIED: mix deps; test/sigra/account/deletion_test.exs] |
| rg | local CLI present | Traceability and anti-overclaim grep checks | Use for fast source/planning checks around `PROOF-01`, `export_auth_data`, stale claims, and milestone artifacts. [VERIFIED: command -v rg] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing ExUnit/Mix lanes | New custom release script | Do not add a custom release-readiness harness; the repo already has targeted ExUnit lanes, CI jobs, and GSD verification artifacts. [VERIFIED: .github/workflows/ci.yml; phase verification files] |
| GSD traceability update | Manual-only checklist | Manual-only proof would not close the GSD gap because the audit requires phase artifacts and requirement status alignment. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md] |

**Installation:** No new packages should be installed for Phase 130. [VERIFIED: mix.exs; mix deps]

**Version verification:** Versions above were verified with `mix --version`, `.tool-versions`, and `mix deps`; no `npm install` / `npm view` version check applies because this phase adds no npm stack. [VERIFIED: mix --version; .tool-versions; mix deps]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 130 plan starts
  |
  v
Read existing phase evidence and current dirty tree
  |
  v
Run targeted DATA-LIFECYCLE suites
  |-- export + lifecycle lane --> proves EXP/LIFE/PROOF behaviors
  |-- generated/docs lane -----> proves HOST/DOC/PROOF behaviors
  |
  v
Run broader release gates
  |-- root library tests with Postgres
  |-- docs warnings-as-errors
  |-- optional CI-equivalent smoke lanes if touched files require them
  |
  v
Decision: all green?
  |-- yes --> update REQUIREMENTS/ROADMAP/STATE and write 130 artifacts
  |-- no  --> write explicit blockers with failing command, failure summary, owner, and retry condition
  |
  v
Final verification artifact closes PROOF-01
```

### Recommended Project Structure

```text
.planning/phases/130-verification-and-release-readiness/
├── 130-01-PLAN.md          # Single proof/readiness plan
├── 130-01-SUMMARY.md       # Command evidence and traceability changes
├── 130-VALIDATION.md       # Nyquist validation contract
├── 130-VERIFICATION.md     # Final verifier proof
└── 130-RESEARCH.md         # This research artifact
```

Structure reflects existing phase artifact conventions for Phases 127-129. [VERIFIED: find .planning/phases/127... .planning/phases/128... .planning/phases/129...]

### Pattern 1: Evidence-First Release Closure

**What:** Rerun the exact targeted suites that already proved the data-lifecycle contract, then capture broader release gate results before updating requirement status. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

**When to use:** Use when a milestone has already implemented behavior but still lacks final release-readiness proof. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

**Example:**

```bash
mix test test/sigra/data_export_test.exs \
  test/sigra/account/deletion_test.exs \
  test/sigra/workers/account_deletion_test.exs \
  test/sigra/account_audit_atomicity_test.exs \
  --max-failures 1

mix test test/sigra/templates/settings_live_test.exs \
  test/sigra/install/isolation_test.exs \
  test/sigra/install/golden_diff_test.exs \
  test/sigra/guides_dx02_test.exs \
  --max-failures 1
```

Source: current milestone audit lists these exact suites as fresh targeted evidence with 56 and 66 passing tests. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

### Pattern 2: CI-Equivalent Broader Gate

**What:** Run the release-relevant CI commands locally, then classify any failure as a blocker rather than silently passing the phase. [VERIFIED: .github/workflows/ci.yml]

**When to use:** Use before closing `PROOF-01` because success criteria require broader relevant lanes to pass or blockers to be captured. [VERIFIED: .planning/ROADMAP.md]

**Example:**

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test
mix docs --warnings-as-errors
```

Source: local project instructions provide the full test command; CI library job runs `mix docs --warnings-as-errors`. [VERIFIED: CLAUDE.md; .github/workflows/ci.yml]

### Pattern 3: Requirements Traceability Matrix Before Commit

**What:** Compare `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, phase summaries, validation reports, and verification reports before marking `PROOF-01` complete. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

**When to use:** Use at the end of Phase 130, because traceability is an explicit success criterion. [VERIFIED: .planning/ROADMAP.md]

**Example:**

```bash
rg -n "EXP-01|EXP-02|LIFE-01|LIFE-02|LIFE-03|HOST-01|DOC-01|PROOF-01" \
  .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/phases/127-* .planning/phases/128-* .planning/phases/129-* .planning/phases/130-*
```

Source: `PROOF-01` currently remains Pending while all other v1.28 requirements are Complete. [VERIFIED: .planning/REQUIREMENTS.md]

### Anti-Patterns to Avoid

- **Closing `PROOF-01` from old evidence only:** Previous verification is useful, but Phase 130 success criteria require targeted tests to pass after final code/doc edits. [VERIFIED: .planning/ROADMAP.md]
- **Ignoring docs warnings because `mix docs` exits successfully:** CI uses `mix docs --warnings-as-errors`, so docs warnings are release-relevant. [VERIFIED: .github/workflows/ci.yml; mix help docs]
- **Updating requirements before evidence:** The audit gap is missing proof, so status changes should follow command evidence and artifact creation. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
- **Adding new product behavior during release readiness:** The active gap is proof/traceability, not a new export, lifecycle, or docs feature. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test execution and filtering | Custom shell harness | `mix test` with explicit file paths and `--max-failures 1` | Mix already supports targeted file paths and failure limits. [VERIFIED: mix help test] |
| Docs release gate | Ad hoc markdown grep only | `mix docs --warnings-as-errors` plus existing guide assertions | CI uses ExDoc warnings-as-errors; guide tests already pin key DATA-LIFECYCLE strings. [VERIFIED: .github/workflows/ci.yml; test/sigra/guides_dx02_test.exs] |
| Golden parity proof | Manual fixture inspection only | Existing `test/sigra/install/golden_diff_test.exs` lane | Phase 129 verification used golden diff as automated parity proof. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-VERIFICATION.md] |
| Traceability audit | New parser | `rg` plus GSD phase artifacts and existing requirements table | Existing artifacts already list requirement IDs and statuses; no custom parser is needed for this bounded phase. [VERIFIED: .planning/REQUIREMENTS.md; phase summaries] |

**Key insight:** Phase 130 should turn existing implementation into fresh, auditable proof; custom tooling would add untested surface area to a release gate. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

## Common Pitfalls

### Pitfall 1: Full Suite Requires Postgres

**What goes wrong:** Root `mix test` fails before proving behavior if local Postgres is missing or credentials differ. [VERIFIED: CLAUDE.md]
**Why it happens:** The project intentionally has no default tag exclusion and fails fast without the database. [VERIFIED: test/test_helper.exs; CLAUDE.md]
**How to avoid:** Ensure `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` can connect before release evidence capture. [VERIFIED: CLAUDE.md]
**Warning signs:** `pg_isready` fails or full test setup exits before running targeted assertions. [VERIFIED: pg_isready]

### Pitfall 2: Docs Warnings Are Release Blockers

**What goes wrong:** Running plain `mix docs` can pass while CI's `mix docs --warnings-as-errors` would fail. [VERIFIED: .github/workflows/ci.yml; mix help docs]
**Why it happens:** ExDoc has an explicit `--warnings-as-errors` option, and the CI library job uses it. [VERIFIED: mix help docs; .github/workflows/ci.yml]
**How to avoid:** Plan the docs gate with `mix docs --warnings-as-errors`, not plain `mix docs`. [VERIFIED: .github/workflows/ci.yml]
**Warning signs:** Prior Phase 129 summary noted pre-existing unresolved `Sigra.OAuth.callback/4` warnings from `mix docs`. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-02-SUMMARY.md]

### Pitfall 3: Stale Milestone Audit Confusion

**What goes wrong:** `.planning/milestones/v1.28-MILESTONE-AUDIT.md` still reflects an earlier state where Phases 128 and 129 were missing. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md; .planning/milestones/v1.28-MILESTONE-AUDIT.md]
**Why it happens:** The current audit is `.planning/v1.28-MILESTONE-AUDIT.md`, while the archived milestone path is stale. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
**How to avoid:** Treat `.planning/v1.28-MILESTONE-AUDIT.md` as the current gap source and either update/archive the stale copy only if planner scopes that artifact. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
**Warning signs:** An audit claims Phases 128/129 are missing despite existing `128-VERIFICATION.md` and `129-VERIFICATION.md`. [VERIFIED: find phase files; .planning/milestones/v1.28-MILESTONE-AUDIT.md]

### Pitfall 4: Formatting Raw EEx Templates

**What goes wrong:** `mix format --check-formatted` fails on raw generator templates because placeholders like `<%= context_module %>` are not standalone Elixir. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-01-SUMMARY.md]
**Why it happens:** Raw templates are rendered before becoming valid Elixir. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-01-SUMMARY.md]
**How to avoid:** Format generated/rendered `.ex` / `.exs` surfaces and use template-specific tests for raw EEx files. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-VALIDATION.md]
**Warning signs:** Formatter errors at template line 1 before checking substantive code. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-01-SUMMARY.md]

## Code Examples

### Targeted DATA-LIFECYCLE Proof Lane

```bash
mix test test/sigra/data_export_test.exs \
  test/sigra/account/deletion_test.exs \
  test/sigra/workers/account_deletion_test.exs \
  test/sigra/account_audit_atomicity_test.exs \
  --max-failures 1
```

Source: current milestone audit records this lane as 56 tests, 0 failures. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

### Generated Host / Docs Proof Lane

```bash
mix test test/sigra/templates/settings_live_test.exs \
  test/sigra/install/isolation_test.exs \
  test/sigra/install/golden_diff_test.exs \
  test/sigra/guides_dx02_test.exs \
  --max-failures 1
```

Source: current milestone audit records this lane as 66 tests, 0 failures. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

### Broader Release Gate

```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test
mix docs --warnings-as-errors
```

Source: project instructions and CI library job. [VERIFIED: CLAUDE.md; .github/workflows/ci.yml]

### Traceability Check

```bash
rg -n "PROOF-01|Phase 130|Pending|Complete" \
  .planning/REQUIREMENTS.md \
  .planning/ROADMAP.md \
  .planning/v1.28-MILESTONE-AUDIT.md \
  .planning/phases/130-verification-and-release-readiness
```

Source: `PROOF-01` is pending and assigned to Phase 130. [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Plain `mix docs` as docs sanity check | CI-level `mix docs --warnings-as-errors` for release readiness | Existing CI config current in repo | Phase 130 should not treat warning-emitting docs as release-green. [VERIFIED: .github/workflows/ci.yml; .planning/phases/129-generated-host-parity-and-docs/129-02-SUMMARY.md] |
| Earlier audit said Phases 128/129 were missing | Current root audit says Phases 127-129 are verified and only Phase 130 is missing | 2026-05-27 current audit supersedes stale milestone copy | Planner should close only `PROOF-01`, not reopen completed Phases 128/129. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md; .planning/milestones/v1.28-MILESTONE-AUDIT.md] |
| Generated host had no export wrapper before Phase 129 | Generated template, example app, and golden fixture delegate to `Sigra.DataExport.export_auth_data/3` | Phase 129 completion on 2026-05-27 | Phase 130 should prove parity, not redesign wrapper behavior. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-01-SUMMARY.md] |

**Deprecated/outdated:**
- Treat `.planning/milestones/v1.28-MILESTONE-AUDIT.md` as current: it is stale and contradicts current Phase 129 state. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md; .planning/milestones/v1.28-MILESTONE-AUDIT.md]
- Treat plain `mix docs` warnings as non-release-relevant: CI uses warnings-as-errors. [VERIFIED: .github/workflows/ci.yml]

## Assumptions Log

All claims in this research were verified or cited from local project artifacts, local command output, or local tool help; no user confirmation is needed before planning. [VERIFIED: all cited sources in this file]

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | No `[ASSUMED]` claims were used. | All | None. [VERIFIED: all cited sources in this file] |

## Open Questions

1. **Should Phase 130 update the stale `.planning/milestones/v1.28-MILESTONE-AUDIT.md` copy?** [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md; .planning/milestones/v1.28-MILESTONE-AUDIT.md]
   - What we know: The current root audit says the milestone path copy is stale. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
   - What's unclear: Whether milestone archive copies are meant to be repaired during active closeout or left until milestone archive. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
   - Recommendation: Plan Phase 130 to update active traceability first; update the stale milestone copy only if required by verification or milestone archive workflow. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]

2. **Will `mix docs --warnings-as-errors` currently fail because of the pre-existing `Sigra.OAuth.callback/4` warnings?** [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-02-SUMMARY.md; .github/workflows/ci.yml]
   - What we know: Phase 129 `mix docs` emitted unresolved-reference warnings but exited successfully; CI runs `mix docs --warnings-as-errors`. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-02-SUMMARY.md; .github/workflows/ci.yml]
   - What's unclear: This research did not run `mix docs --warnings-as-errors` to avoid generating doc artifacts during research. [VERIFIED: command history]
   - Recommendation: Make this a Phase 130 Wave 0 gate; either fix warnings or record them as explicit release blockers. [VERIFIED: .planning/ROADMAP.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | Test/docs gates | ✓ | Mix 1.19.5, OTP 28 runtime | None needed. [VERIFIED: mix --version] |
| PostgreSQL server | Full root test lane | ✓ | `pg_isready` accepting at localhost:5432 | Docker one-liner in `CLAUDE.md` if unavailable. [VERIFIED: pg_isready; CLAUDE.md] |
| psql CLI | DB diagnostics | ✓ | 14.17 Homebrew | Use `pg_isready` for minimal readiness. [VERIFIED: psql --version; pg_isready] |
| Docker | Postgres fallback | ✓ | 29.5.2 | Existing local Postgres is already accepting. [VERIFIED: docker --version; pg_isready] |
| gsd-sdk | Phase metadata / commit docs | ✓ | CLI present | Manual artifact edits only if SDK fails. [VERIFIED: command -v gsd-sdk; gsd-sdk query init.phase-op 130] |
| rg | Traceability scans | ✓ | CLI present | Use `grep` if unavailable. [VERIFIED: command -v rg] |
| Graphify knowledge graph | Optional graph context | ✗ | disabled | Proceed with direct file/source research. [VERIFIED: gsd-tools graphify status] |

**Missing dependencies with no fallback:** None for planning. [VERIFIED: environment probes]

**Missing dependencies with fallback:** Graphify is disabled; direct file and source grep covered required relationships. [VERIFIED: gsd-tools graphify status; rg output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix 1.19.5. [VERIFIED: mix --version; mix help test] |
| Config file | `test/test_helper.exs`; `config/test.exs`; project test filters in `mix.exs`. [VERIFIED: test/test_helper.exs; config/test.exs; mix.exs] |
| Quick run command | `mix test test/sigra/data_export_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs test/sigra/account_audit_atomicity_test.exs --max-failures 1` [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |
| Docs release command | `mix docs --warnings-as-errors` [VERIFIED: .github/workflows/ci.yml; mix help docs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| PROOF-01 | Export shape and optional-schema degradation | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | ✅ [VERIFIED: test/sigra/data_export_test.exs] |
| PROOF-01 | Deletion lifecycle truth and worker scheduling behavior | unit | `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --max-failures 1` | ✅ [VERIFIED: test/sigra/account/deletion_test.exs; test/sigra/workers/account_deletion_test.exs] |
| PROOF-01 | Generated-host parity and golden fixture parity | template/integration | `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/isolation_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1` | ✅ [VERIFIED: test/sigra/templates/settings_live_test.exs; test/sigra/install/isolation_test.exs; test/sigra/install/golden_diff_test.exs] |
| PROOF-01 | Docs truth for export boundary, omissions, and deletion strategies | docs/guide test | `mix test test/sigra/guides_dx02_test.exs --max-failures 1` and `mix docs --warnings-as-errors` | ✅ [VERIFIED: test/sigra/guides_dx02_test.exs; .github/workflows/ci.yml] |
| PROOF-01 | Broader release readiness or explicit blockers | integration/release | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` | ✅ [VERIFIED: CLAUDE.md; .github/workflows/ci.yml] |
| PROOF-01 | Requirements traceability maps all v1.28 requirements to active roadmap | artifact audit | `rg -n "EXP-01|EXP-02|LIFE-01|LIFE-02|LIFE-03|HOST-01|DOC-01|PROOF-01" .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/phases/127-* .planning/phases/128-* .planning/phases/129-* .planning/phases/130-*` | ✅ [VERIFIED: .planning/REQUIREMENTS.md; .planning/ROADMAP.md] |

### Sampling Rate

- **Per task commit:** Run the targeted lane for the artifact touched; for traceability-only edits, run the traceability `rg` command. [VERIFIED: phase validation patterns 127-129]
- **Per wave merge:** Run both targeted DATA-LIFECYCLE suites listed in Code Examples. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
- **Phase gate:** Run full root test lane and `mix docs --warnings-as-errors`, then write blockers if either fails. [VERIFIED: .planning/ROADMAP.md; .github/workflows/ci.yml]

### Wave 0 Gaps

- [ ] `.planning/phases/130-verification-and-release-readiness/130-VALIDATION.md` — required because Nyquist validation is enabled and Phase 130 is missing validation. [VERIFIED: .planning/config.json; .planning/v1.28-MILESTONE-AUDIT.md]
- [ ] `.planning/phases/130-verification-and-release-readiness/130-VERIFICATION.md` — required because current audit marks verification missing. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
- [ ] `.planning/phases/130-verification-and-release-readiness/130-01-SUMMARY.md` — required to record command evidence and traceability changes. [VERIFIED: existing phase artifact conventions 127-129]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Do not alter auth behavior in Phase 130; prove existing auth-account export/lifecycle tests remain green. [VERIFIED: .planning/ROADMAP.md] |
| V3 Session Management | yes | Export/lifecycle tests cover sessions and revocation-adjacent deletion flows. [VERIFIED: .planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md; .planning/phases/128-account-deletion-lifecycle-truth/128-VERIFICATION.md] |
| V4 Access Control | yes | Generated example export wrapper preserves `forbid_sensitive_operation/3` guard. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-VERIFICATION.md] |
| V5 Input Validation | limited | No new external input parsing should be added; use existing tests/artifacts. [VERIFIED: .planning/ROADMAP.md] |
| V6 Cryptography | yes | Export proof must continue excluding secret/replay-relevant credential fields. [VERIFIED: .planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md] |
| V7 Error Handling and Logging | yes | Broader failures must be captured as explicit blockers instead of hidden release-readiness claims. [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for Phase 130

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret-bearing data exported during release closure | Information Disclosure | Rerun `test/sigra/data_export_test.exs`, which refutes hashed tokens and encrypted credential fields. [VERIFIED: .planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md] |
| Misleading release status after stale or partial tests | Repudiation | Capture fresh command outputs in `130-01-SUMMARY.md` and `130-VERIFICATION.md`. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md] |
| Generated host diverges from library export/lifecycle contract | Tampering / Integrity | Rerun template, isolation, and golden diff tests. [VERIFIED: .planning/phases/129-generated-host-parity-and-docs/129-VERIFICATION.md] |
| Docs overclaim deletion/export/compliance behavior | Information Disclosure / Repudiation | Rerun guide assertions and docs warnings-as-errors; record blockers on warning failures. [VERIFIED: test/sigra/guides_dx02_test.exs; .github/workflows/ci.yml] |

## Sources

### Primary (HIGH confidence)

- `.planning/REQUIREMENTS.md` — v1.28 requirement status and traceability. [VERIFIED: file read]
- `.planning/ROADMAP.md` — Phase 130 goal, dependency, success criteria, and active milestone scope. [VERIFIED: file read]
- `.planning/STATE.md` — current focus, phase history, and Phase 127-129 decisions. [VERIFIED: file read]
- `.planning/v1.28-MILESTONE-AUDIT.md` — current PROOF-01 gap source and targeted evidence lanes. [VERIFIED: file read]
- `CLAUDE.md` — project constraints and local Postgres test prerequisite. [VERIFIED: file read]
- `mix.exs`, `test/test_helper.exs`, `config/test.exs` — local test/doc/dependency configuration. [VERIFIED: file read]
- `.github/workflows/ci.yml` — CI release-relevant library test and docs gates. [VERIFIED: file read]
- Phase 127-129 `SUMMARY.md`, `VALIDATION.md`, and `VERIFICATION.md` artifacts — prior proof surfaces and command evidence. [VERIFIED: file read]
- `mix help test`, `mix help docs`, `mix --version`, `mix deps` — local tool behavior and versions. [VERIFIED: command output]

### Secondary (MEDIUM confidence)

- None. [VERIFIED: no web/community sources used]

### Tertiary (LOW confidence)

- None. [VERIFIED: no unverified sources used]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions and commands verified locally through Mix, deps, and CI config. [VERIFIED: mix --version; mix deps; .github/workflows/ci.yml]
- Architecture: HIGH — phase is bounded to existing test/proof/artifact flow and current audit explicitly names the gap. [VERIFIED: .planning/v1.28-MILESTONE-AUDIT.md]
- Pitfalls: HIGH — pitfalls come from local project instructions, CI config, and previous phase summaries. [VERIFIED: CLAUDE.md; .github/workflows/ci.yml; phase summaries]

**Research date:** 2026-05-27 [VERIFIED: environment current_date]
**Valid until:** 2026-06-03 for release-readiness commands because CI/docs/test state can change quickly. [VERIFIED: .github/workflows/ci.yml]
