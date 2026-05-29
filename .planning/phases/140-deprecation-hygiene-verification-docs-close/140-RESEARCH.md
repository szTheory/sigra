# Phase 140: Deprecation Hygiene + Verification & Docs Close — Research

**Researched:** 2026-05-29
**Domain:** Elixir/Phoenix — deprecation annotation hygiene, proof-bundle execution, ExDoc surfacing, MAINTAINING.md / deployment guide authoring
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Removal targets are expressed in **Hex SemVer `0.x` minors**, never in internal `v1.x` planning-milestone labels. The Hex package is `0.3.0` (mix.exs:4); `v1.x` labels are planning tranches only.

**D-02:** `Sigra.MFA.Trust.cookie_opts/0` — removal target **`0.4.0`** (full deletion of the raising stub). Only the removal target version is added; existing migration guidance is not weakened.

**D-03:** `Sigra.Account.audit_forced_password_change/2` — removal target **`0.5.0`** (one minor of soft-deprecation grace; function still works). Removal target is added; existing migration guidance (`clear_password_change_requirement/3`) is not changed.

**D-04:** Removal target baked into both the `@deprecated` string and `@doc deprecated:` where present; AND recorded in docs (D-09). Do not weaken or remove existing migration guidance — append the target version to it.

**D-05:** Reuse the Phase 136 six-gate proof-bundle pattern verbatim. File `140-VERIFICATION.md` with canonical dash-prefix name and YAML frontmatter (`phase / verified / status / score / overrides_applied`).

**D-06:** Proof gates (all must be green): (1) full suite `mix test`; (2) audit subtree `test/sigra/audit/`; (3) dep-off lane (`mix deps.unlock/clean threadline` + `--exclude requires_threadline --no-deps-check`); (4) `test/example/` lane; (5) `mix docs --warnings-as-errors` exit 0; (6) `mix sigra.doctor` exercised against `test/example/`.

**D-07:** Add a gate/check that the two deprecation removal-timeline notes **actually render in `mix docs`** output — grep assertion against `doc/` HTML after `mix docs`.

**D-08:** Credo `--strict` advisory issues remain a non-blocking advisory (consistent with prior milestone-close phases; not CI-enforced).

**D-09:** Placement: `mix sigra.doctor` usage → new `## Operator diagnostics` section in `guides/recipes/deployment.md`. `Sigra.OptionalDeps` maintainer note + recipe-contract-testing note + deprecation-removal-timeline note → new `##` sections in `MAINTAINING.md`.

**D-10:** Any new or newly-referenced guide/extra MUST be registered in mix.exs `extras` and `groups_for_extras`. Both `MAINTAINING.md` (line 184) and `guides/recipes/deployment.md` (line 218) are **already registered** — no new mix.exs registration needed since this phase only appends to existing files.

**D-11:** The recipe-contract-testing note documents `test/sigra/recipes/companion_lib_contract_test.exs` as a maintainer-internal drift guard.

**D-12:** Flip `[ ]`→`[x]` on ROADMAP.md lines 45/70/71 and reconcile the "1/3" progress-table row (line 132) to reflect Phase 137 complete. STATE.md drift and stale branch name are **deferred to `/gsd-complete-milestone`** — out of scope.

### Claude's Discretion

- Exact section titles/wording of the new MAINTAINING.md and deployment.md sections.
- Whether `mix docs` deprecation-rendering check (D-07) is a grep assertion vs. a manual proof step.
- Internal modularization of any verification helper / test shape.

### Deferred Ideas (OUT OF SCOPE)

- STATE.md drift reconciliation and the stale `v1.28-data-lifecycle` branch name.
- Actually deleting the deprecated functions (only schedules removal here).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEPR-01 | `Sigra.Account.audit_forced_password_change/2` carries a documented removal target version and migration note | Current annotation text confirmed; exact append documented below |
| DEPR-02 | `Sigra.MFA.Trust.cookie_opts/0` carries a documented removal target version and migration note | Current annotation text confirmed; exact append documented below |
| PROOF-01 | Full test suite + dep-off CI lane + `mix docs --warnings-as-errors` all green; `mix sigra.doctor` exercised against `test/example/`; per-phase verification artifacts filed | Six gate commands extracted verbatim from 136-VERIFICATION.md; doctor behavior confirmed |
| DOC-01 | Guides/docs updated — `mix sigra.doctor` usage, `Sigra.OptionalDeps` maintainer note, deprecation-removal-timeline notes, recipe-contract-testing note | Target files confirmed registered in mix.exs; section placements identified |
</phase_requirements>

---

## Summary

Phase 140 is a milestone-close phase with three bounded jobs: deprecation annotation hygiene on two live functions, a six-gate verification proof bundle, and docs/guide appends. All substrate (Phases 137–139) is fully landed and confirmed by 137-01/02/03-SUMMARY.md, 138-VERIFICATION.md, and 139 plan completion.

**The phase is purely additive and editorial.** It does not add capabilities, change runtime behavior, or actually delete the deprecated functions — it schedules their removal and documents everything that was shipped in v1.30.

The only concrete unknowns at planning time are: (a) the exact text of the deprecation string appends (fully specifiable from the current annotation text below), and (b) whether the doctor gate against `test/example/` exits 0 or 1 — which is expected to be 0 because `test/example/` has no misconfigured features (confirmed by 136 VERIFICATION Gate 4 passing clean; the example app is well-formed).

**Primary recommendation:** Structure the phase as two sequential waves — Wave 1 for DEPR edits + ROADMAP fix (all file edits, no test runs), Wave 2 for full proof bundle execution + `140-VERIFICATION.md` filing + DOC-01 guide appends. Run docs-render grep assertion as part of Wave 2.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Deprecation annotation hygiene | Library source (`lib/`) | — | In-source `@deprecated` / `@doc deprecated:` strings live in library code; no runtime behavior change |
| Verification proof execution | CI shell layer | Library test suite | Gate commands are shell invocations of `mix` tasks; all logic already exists |
| ExDoc rendering proof | ExDoc pipeline | Filesystem grep | `mix docs` produces `doc/` HTML; grep asserts the published artifact, not just the source |
| `mix sigra.doctor` exercise | Mix task (`lib/mix/tasks/sigra.doctor.ex`) | Library (`lib/sigra/doctor.ex`) | The task is the CI-facing gate; library module holds the logic; both already shipped (Phase 138) |
| Deployment guide docs (DOC-01) | `guides/recipes/deployment.md` | — | Operator-audience guide already registered in ExDoc extras; append only |
| Maintainer docs (DOC-01) | `MAINTAINING.md` | — | Maintainer-audience doc already registered in ExDoc extras; append only |
| ROADMAP reconciliation (D-12) | `.planning/ROADMAP.md` | — | Planning artifact only; no impact on library or Hex package |

---

## Deprecation Edit Shape (DEPR-01 / DEPR-02)

### DEPR-02: `Sigra.MFA.Trust.cookie_opts/0` — `lib/sigra/mfa/trust.ex:42-57`

**Current annotations (verified at lib/sigra/mfa/trust.ex:42-44):** [VERIFIED: codebase read]

```elixir
@doc since: "0.6.0"
@doc deprecated: "Use cookie_opts/1 with a %Sigra.Config{} so cookie_domain is honored."
@deprecated "Use cookie_opts/1 with a %Sigra.Config{} so cookie_domain is honored."
```

**Required change (D-02, D-04):** Append ` Scheduled for removal in 0.4.0.` to both the `@doc deprecated:` string and the `@deprecated` string. Do NOT modify `@doc since:`. Do NOT change the `@doc """...` narrative above (lines 30-41), which already has full migration context.

**After edit:**
```elixir
@doc since: "0.6.0"
@doc deprecated: "Use cookie_opts/1 with a %Sigra.Config{} so cookie_domain is honored. Scheduled for removal in 0.4.0."
@deprecated "Use cookie_opts/1 with a %Sigra.Config{} so cookie_domain is honored. Scheduled for removal in 0.4.0."
```

**Observation:** This function is a `no_return()` raising stub — it already raises at runtime with a full migration message. The deprecation annotations are surface-only (compiler warnings, ExDoc). The only change is appending the target version string.

---

### DEPR-01: `Sigra.Account.audit_forced_password_change/2` — `lib/sigra/account.ex:542-556`

**Current annotations (verified at lib/sigra/account.ex:542-543):** [VERIFIED: codebase read]

```elixir
@doc since: "0.9.0"
@deprecated "Use clear_password_change_requirement/3 when :audit_schema is configured; do not call this function for the same forced-clear completion or you may duplicate audit rows."
```

**Note:** This function has `@deprecated` only — there is NO `@doc deprecated:` attribute. The function is still-functional (soft-deprecation only). There is no `@doc since:` tag conflict. [VERIFIED: codebase grep — single `@deprecated` annotation, no `@doc deprecated:` present]

**Required change (D-03, D-04):** Append ` Scheduled for removal in 0.5.0.` to the `@deprecated` string. Do NOT add a `@doc deprecated:` attribute (the existing pattern for this function uses only `@deprecated`; adding `@doc deprecated:` would be a separate ExDoc attribute that could cause duplicate display).

**After edit:**
```elixir
@doc since: "0.9.0"
@deprecated "Use clear_password_change_requirement/3 when :audit_schema is configured; do not call this function for the same forced-clear completion or you may duplicate audit rows. Scheduled for removal in 0.5.0."
```

**Observation:** The `@doc """...` narrative above (lines 532-541) already provides migration context (`Prefer clear_password_change_requirement/3`). The `@deprecated` append is the only change.

---

## Proof Gate Commands (PROOF-01 / D-05 / D-06)

Extracted verbatim from `136-VERIFICATION.md` Behavioral Spot-Checks table. [VERIFIED: codebase read of 136-VERIFICATION.md]

### Gate 1: Full library suite
```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test
```
Expected: 0 failures, exit code 0. Prior run result: 33 doctests, 3 properties, 2252 tests, 0 failures.

### Gate 2: Audit subtree
```bash
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit/
```
Expected: 0 failures, exit code 0. Prior run result: 60 tests, 0 failures.

### Gate 3: Dep-off lane (three-step sequence)
```bash
# Step 3a — unlock
mix deps.unlock threadline
# Step 3b — clean
mix deps.clean threadline --build
# Step 3c — compile (must exit 0 with no warnings)
MIX_ENV=test mix compile --warnings-as-errors --no-deps-check
# Step 3d — test
PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --exclude requires_threadline --no-deps-check
# Step 3e — restore
mix deps.get
```
Expected: compile exit 0, test exit 0, 6 excluded, 0 failures.

**Note on ci.yml match:** This matches ci.yml:205-219 exactly. [VERIFIED: codebase read of ci.yml:165-219]

### Gate 4: test/example/ lane
```bash
cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test --include example_app
```
Expected: 236 tests, 0 failures, exit code 0.

### Gate 5: Docs build
```bash
mix docs --warnings-as-errors
```
Expected: exit code 0. Note: Run this gate AFTER the DEPR edits so the docs-render grep assertion (Gate 7, see below) can follow immediately.

### Gate 6: Credo advisory (non-blocking, D-08)
```bash
mix credo --strict
```
Expected: exits non-zero with advisory issues (pre-existing 506 library advisories from Phase 136). Record exit code and issue count verbatim. The 2 enforced custom checks:
```bash
mix credo --only sigra
```
Expected: exit 0. Gate 6 is recorded as advisory, does NOT block PROOF-01.

### Gate 7 (NEW — D-06 doctor gate): `mix sigra.doctor` against `test/example/`
```bash
cd test/example && mix sigra.doctor
```
Expected: exit code 0. The doctor command exits 0 when all configured features are properly wired or no features are configured (confirmed by `Mix.Tasks.Sigra.Doctor` module doc and `Sigra.Doctor` design). [VERIFIED: codebase read of lib/mix/tasks/sigra.doctor.ex, exit code documentation]

**Important:** The `test/example/` app has a well-formed configuration (Gate 4 passes 236 tests clean). If any misconfiguration existed, Gate 4 would already surface it. Doctor exit-1 would only fire on `configured-but-broken` wiring. The example app is expected to exit 0.

**Doctor exit-code contract (from lib/mix/tasks/sigra.doctor.ex lines 44-48):**
- Exit 0: all configured features properly wired (or no features configured). Absent optional deps are NOT an error.
- Exit 1: at least one configured feature has broken wiring.

**Note:** This gate must be run from the `test/example/` directory so the Mix task picks up the example app's application config, not the library's own `config/`.

### Gate 8 (D-07): Deprecation notes render in mix docs
After running Gate 5 (`mix docs --warnings-as-errors`), assert both removal-timeline strings appear in the generated HTML:
```bash
grep -r "Scheduled for removal in 0.4.0" doc/
grep -r "Scheduled for removal in 0.5.0" doc/
```
Both greps must return at least one match (exit 0). This is a grep assertion — no manual proof step required. [ASSUMED: ExDoc emits `@deprecated` strings into generated HTML in a predictable location; the exact HTML structure was not verified against ExDoc source, but the pattern is standard ExDoc behavior and consistent with prior deprecation surfacing in the project]

---

## mix.exs Registration Status (D-10)

Both target files are **already registered** in `mix.exs extras` and surfaced via `groups_for_extras`. No new registration is needed. [VERIFIED: codebase grep of mix.exs]

| File | mix.exs Line | groups_for_extras Bucket |
|------|-------------|--------------------------|
| `MAINTAINING.md` | 184 | Ungrouped ("Pages" in ExDoc default — root-level extras not matching any regex fall outside named groups but still surface) |
| `guides/recipes/deployment.md` | 218 | `Recipes` (`~r{guides/recipes/[^/]+\.md$}`) |

**Note on MAINTAINING.md grouping:** The `groups_for_extras` entries are: `Introduction`, `Reference`, `Flows`, `Companion Libraries`, `Recipes`, `Docs`. `MAINTAINING.md` is at the root and matches none of these patterns. In ExDoc, ungrouped extras surface as top-level pages outside any group — they are still reachable on HexDocs. This is pre-existing behavior, not new to this phase.

---

## DOC-01 Content Placement

### deployment.md: new `## Operator diagnostics` section

**Target file:** `guides/recipes/deployment.md`
**Placement:** After the existing `## Health check endpoint` section (line 183), before `## Fly.io specifics` (line 205). This positions it in the pre-deployment operations block where operators run final checks. [VERIFIED: codebase read of deployment.md]

**Section purpose:** Document `mix sigra.doctor` as a pre-deploy verification command for operators. Describe standard run, CI usage pattern (non-zero exit on misconfiguration), `--quiet` flag, and typical output states (loaded/available/configured-but-missing/missing).

**Key facts to include:**
- Command: `mix sigra.doctor` (standard), `mix sigra.doctor --quiet` (CI-friendly)
- Exit 0 = all wired correctly; Exit 1 = misconfiguration detected
- Nine features covered (totp_mfa, password_migration, oauth, rate_limiting, jwt, async_email, audit_forwarding, encryption, enterprise_connections)
- Safe to run in dep-off CI lane: exits 0 when no features are configured

### MAINTAINING.md: three new `##` sections

**Target file:** `MAINTAINING.md`
**Placement:** After the existing `## Semver for Sigra (pre-1.0)` section (line 216) and before `## Planning hygiene (without gsd-tools JSON)` (line 224). This clusters library-architecture notes together. [VERIFIED: codebase read of MAINTAINING.md]

Three sections to add:

1. **`## OptionalDeps single source of truth (Phase 137)`**
   - Documents `Sigra.OptionalDeps` as the canonical runtime optional-dep check module.
   - Notes which call sites delegate to it vs. the narrow documented exceptions (`Code.ensure_loaded?` used in: compile-time `defmodule` wrappers, dynamic host-schema atoms, boot-warning `cond`, doctor's dynamic-forwarder check).
   - States: "To add or audit an optional dependency, edit `lib/sigra/optional_deps.ex` — do not scatter new `Code.ensure_loaded?` guards across call sites."

2. **`## Recipe-contract fixture (Phase 139)`**
   - Documents `test/sigra/recipes/companion_lib_contract_test.exs` as a maintainer-internal merge-blocking drift guard.
   - States the five required markers every companion-lib recipe must carry.
   - Notes this is NOT a Hex-facing recipe — it is a CI contract assertion.

3. **`## Deprecation removal timeline`**
   - Documents the two live deprecated functions and their removal targets:
     - `Sigra.MFA.Trust.cookie_opts/0` — raises at runtime now; stub deleted in `0.4.0`
     - `Sigra.Account.audit_forced_password_change/2` — still works; removed in `0.5.0`
   - States the process: each removal-target version will carry a CHANGELOG entry and the function body will be deleted (not just the annotation).

---

## ROADMAP Reconciliation (D-12)

### Exact stale lines and their required updates [VERIFIED: codebase read of ROADMAP.md + 137-02/03-SUMMARY.md confirmed completed: 2026-05-29]

| Location | Current text | Required text |
|----------|-------------|---------------|
| ROADMAP.md line 45 | `- [ ] **Phase 137: Optional-Dependency Source of Truth** —` | `- [x] **Phase 137: Optional-Dependency Source of Truth** —` |
| ROADMAP.md line 66 | `- [x] 137-01-PLAN.md — Create \`Sigra.OptionalDeps\` SOT...` | (already `[x]` — no change) |
| ROADMAP.md line 70 | `  - [ ] 137-02-PLAN.md — Delegate single-leaf runtime guards...` | `  - [x] 137-02-PLAN.md — Delegate single-leaf runtime guards...` |
| ROADMAP.md line 71 | `  - [ ] 137-03-PLAN.md — Delegate compound-guard load-halves...` | `  - [x] 137-03-PLAN.md — Delegate compound-guard load-halves...` |
| ROADMAP.md line 132 | `\| 137. Optional-Dependency Source of Truth \| 1/3 \| In Progress\|  \|` | `\| 137. Optional-Dependency Source of Truth \| 3/3 \| Complete \| 2026-05-29 \|` |

**Honesty check:** Flipping these is honest because:
- 137-01-SUMMARY.md, 137-02-SUMMARY.md, 137-03-SUMMARY.md all exist with `completed: "2026-05-29"`. [VERIFIED: codebase read]
- The ROADMAP checkbox drift is cosmetic — the work landed but the ROADMAP was not updated during execution.

---

## Common Pitfalls

### Pitfall 1: `@doc deprecated:` vs `@deprecated` — different functions have different annotations

**What goes wrong:** Adding `@doc deprecated:` to `audit_forced_password_change/2` when it only has `@deprecated`, causing duplicate deprecation display in ExDoc, or adding to the wrong attribute.

**Why it happens:** `Sigra.MFA.Trust.cookie_opts/0` has BOTH `@doc deprecated:` AND `@deprecated`; `Sigra.Account.audit_forced_password_change/2` has ONLY `@deprecated`. Conflating the two.

**How to avoid:** DEPR-01 edit: modify only the single `@deprecated` string at account.ex:543. DEPR-02 edit: modify both the `@doc deprecated:` string (trust.ex:43) AND the `@deprecated` string (trust.ex:44).

**Warning signs:** If ExDoc shows the deprecation notice twice for a function, `@doc deprecated:` was added to a function that already renders it via `@deprecated`.

---

### Pitfall 2: Running `mix sigra.doctor` from the wrong directory

**What goes wrong:** Running `mix sigra.doctor` from the repo root against `test/example/` instead of `cd test/example && mix sigra.doctor`. The root Mix project has different application config than the example app; the doctor would inspect the library's own dev configuration, not the example app's.

**Why it happens:** Gate 4 for `test/example/` lane uses `cd test/example &&`, but it's easy to overlook for the doctor gate.

**How to avoid:** Gate 7 (doctor gate) MUST be run as `cd test/example && mix sigra.doctor`, matching the Gate 4 pattern verbatim.

**Warning signs:** If doctor output shows features that only exist in the library dev config but not in the example app config, the wrong directory is in use.

---

### Pitfall 3: grep for deprecation strings on `doc/` before running `mix docs`

**What goes wrong:** Gate 8 (D-07 grep assertion) runs before Gate 5 (`mix docs`), asserting against a stale `doc/` tree from a prior run that may not include the DEPR edits.

**How to avoid:** Run gates in order: DEPR edits first → Gate 5 (`mix docs --warnings-as-errors`) → Gate 8 (grep `doc/`).

---

### Pitfall 4: Weakening existing migration guidance

**What goes wrong:** The `@deprecated` string is rewritten rather than appended, losing the existing migration instructions.

**How to avoid (D-04):** Append ` Scheduled for removal in 0.x.` to the END of the existing string. Do not replace the existing string.

---

### Pitfall 5: STATE.md / branch name drift in scope

**What goes wrong:** Attempting to reconcile STATE.md drift or rename the `v1.28-data-lifecycle` branch as part of this phase.

**How to avoid (D-12):** Those items are explicitly deferred to `/gsd-complete-milestone`. This phase only edits ROADMAP.md lines 45/70/71/132.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built into Elixir) |
| Config file | `test/test_helper.exs` |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit/` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |

### Phase Requirements → Proof Signal Map

| Req ID | Behavior | Proof Type | Observable Signal | Automated Command |
|--------|----------|-----------|-------------------|-------------------|
| DEPR-01 | `audit_forced_password_change/2` carries removal target `0.5.0` | Source assertion + docs render | (a) `@deprecated` string contains `0.5.0`; (b) `grep -r "0.5.0" doc/` returns match after `mix docs` | (a) `grep "0.5.0" lib/sigra/account.ex`; (b) `mix docs --warnings-as-errors && grep -r "Scheduled for removal in 0.5.0" doc/` |
| DEPR-02 | `cookie_opts/0` carries removal target `0.4.0` | Source assertion + docs render | (a) both `@deprecated` and `@doc deprecated:` strings contain `0.4.0`; (b) `grep -r "0.4.0" doc/` returns match after `mix docs` | (a) `grep "0.4.0" lib/sigra/mfa/trust.ex`; (b) `mix docs --warnings-as-errors && grep -r "Scheduled for removal in 0.4.0" doc/` |
| PROOF-01 (Gate 1) | Full test suite green | ExUnit run | Exit 0, 0 failures | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| PROOF-01 (Gate 2) | Audit subtree green | ExUnit run | Exit 0, 0 failures | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit/` |
| PROOF-01 (Gate 3) | Dep-off lane green (Threadline absent) | ExUnit run + compile | Exit 0, 6 excluded, 0 failures | Multi-step: unlock → clean → compile → test → restore (see Gate 3 commands above) |
| PROOF-01 (Gate 4) | test/example/ lane green | ExUnit run | Exit 0, 236 tests, 0 failures | `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test --include example_app` |
| PROOF-01 (Gate 5) | `mix docs --warnings-as-errors` exits 0 | ExDoc build | Exit 0 | `mix docs --warnings-as-errors` |
| PROOF-01 (Gate 6) | `mix sigra.doctor` exits 0 against test/example/ | Mix task | Exit 0 (no misconfigured features) | `cd test/example && mix sigra.doctor` |
| PROOF-01 (Gate 6, advisory) | credo advisory count recorded | Static analysis | Issue count disclosed verbatim; enforced custom checks exit 0 | `mix credo --strict` (record verbatim) + `mix credo --only sigra` (must exit 0) |
| DOC-01 | deployment.md has Operator diagnostics section | Doc assertion | New `## Operator diagnostics` section present in file | `grep "## Operator diagnostics" guides/recipes/deployment.md` |
| DOC-01 | MAINTAINING.md has OptionalDeps + recipe-contract + deprecation-timeline sections | Doc assertion | Three new `##` section headings present | `grep -c "## OptionalDeps\|## Recipe-contract\|## Deprecation removal" MAINTAINING.md` (expect 3) |

### Sampling Rate

- **Per task commit:** Source grep assertions (DEPR-01/02 string checks)
- **Per wave merge:** Full proof gates 1–7 + grep assertions Gate 8
- **Phase gate:** All 8 gates green before filing `140-VERIFICATION.md` and calling `/gsd-verify-work`

### Wave 0 Gaps

None — existing test infrastructure covers all phase requirements. No new test files need to be created. The proof bundle re-runs existing suite gates; the DEPR edits are source-only with no new test coverage required. The DOC-01 edits are documentation appends with no test coverage required.

---

## Architecture Patterns

### Pattern 1: Six-Gate Proof Bundle (established Phase 136)

**What:** A verification artifact (`140-VERIFICATION.md`) with YAML frontmatter and a structured table of gate results. Each gate is a shell command with expected and actual output recorded verbatim.

**Template (from 136-VERIFICATION.md):**
```yaml
---
phase: 140-deprecation-hygiene-verification-docs-close
verified: <ISO timestamp>
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
gaps: []
deferred: []
human_verification: []
---
```

**Anti-pattern:** Do not record expected output only — record actual output verbatim to prevent overclaiming. The Phase 136 pattern explicitly states the test count and failure count from the actual run.

---

### Pattern 2: Elixir deprecation annotation convention

**What:** Elixir/ExDoc deprecation surfacing uses two mechanisms that must be kept in sync when both are present:
1. `@deprecated "message"` — Elixir compiler emits a warning at every call site. The string is the full deprecation notice.
2. `@doc deprecated: "message"` — ExDoc attribute for rendering a deprecation badge in generated docs.

**When both are present** (as in `cookie_opts/0`): both strings must be updated to stay in sync. ExDoc renders the `@doc deprecated:` value in the docs sidebar badge; the compiler uses `@deprecated`.

**When only `@deprecated` is present** (as in `audit_forced_password_change/2`): only the `@deprecated` string is updated. ExDoc will render from the `@deprecated` attribute directly.

**Source:** [VERIFIED: codebase read] — the two functions demonstrate the two patterns in production.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deprecation warning emission | Custom macro or logger warning | `@deprecated` + `@doc deprecated:` | Elixir compiler handles call-site warnings automatically; ExDoc handles docs surfacing |
| Doc render verification | Manual inspection of HexDocs | `mix docs --warnings-as-errors` + `grep doc/` | Automated and repeatable; catches regression in CI |
| Test suite execution | Ad-hoc `mix run` scripts | `mix test` with flags from Gate 1–4 | Established gates match CI exactly (ci.yml verified) |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL at localhost:5432 | Gates 1, 2, 3, 4 | ✓ (project prereq per CLAUDE.md) | postgres/postgres credentials | Docker one-liner in CLAUDE.md |
| ExDoc (`mix docs`) | Gate 5, Gate 8 | ✓ (mix.exs dev dep) | ex_doc ~> 0.40 | — |
| `mix sigra.doctor` (Phase 138 library code) | Gate 7 | ✓ (confirmed landed: lib/mix/tasks/sigra.doctor.ex, lib/sigra/doctor.ex) | Current HEAD | — |
| `test/example/` app | Gates 4, 7 | ✓ (236 tests passing per 136-VERIFICATION.md Gate 4) | Current HEAD | — |

**Missing dependencies with no fallback:** None.

---

## Standard Stack

No new packages in this phase. All required tooling is already in the project. [VERIFIED: codebase read]

## Package Legitimacy Audit

No packages installed in this phase. Not applicable.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Open-ended `@deprecated` with no timeline | `@deprecated "... Scheduled for removal in 0.x.0."` | This phase | Adopters can plan migration; maintainers have a removal commitment |
| Informal milestone-label versioning in deprecations | Hex SemVer `0.x` minors | This phase (D-01) | Consistent with published MAINTAINING.md pre-1.0 policy |

---

## Open Questions

1. **Doctor exit code against test/example/**
   - What we know: Doctor exits 1 only on misconfigured features; exits 0 on clean or unconfigured. The example app passed Gate 4 (236 tests) cleanly.
   - What's unclear: Whether any feature in `test/example/` is configured in a way that triggers the `configured_but_missing` wiring check state at the time of the Phase 140 proof run.
   - Recommendation: Run `cd test/example && mix sigra.doctor` as part of a dry-run before committing the verification report. If it exits 1, file the wiring error as a DOC-01 note and record non-zero exit verbatim (same disposition as the credo advisory gate). This is unlikely given the passing Gate 4.

2. **ExDoc `doc/` HTML structure for grep**
   - What we know: `mix docs --warnings-as-errors` exits 0 on current HEAD. ExDoc renders `@deprecated` strings into HTML.
   - What's unclear: Exact file path within `doc/` where the deprecation strings land (module page vs. search index vs. llms.txt).
   - Recommendation: Use `grep -r` across the entire `doc/` directory (not a specific file path) to be resilient to ExDoc internals.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ExDoc renders `@deprecated` string content (including the appended version phrase) into the generated `doc/` HTML tree in a way that `grep -r` can find | Proof Gate 8 | Grep assertion returns false negative; would need to inspect ExDoc output to identify correct grep target |
| A2 | `test/example/` app has no misconfigured features that cause `mix sigra.doctor` to exit 1 | Gate 7 | Doctor exits 1; need to file non-zero verbatim and explain the finding rather than marking gate as PASS |

---

## Sources

### Primary (HIGH confidence)
- `lib/sigra/mfa/trust.ex:42-57` — DEPR-02 current annotation text [VERIFIED: codebase read]
- `lib/sigra/account.ex:542-556` — DEPR-01 current annotation text [VERIFIED: codebase read]
- `.planning/phases/136-verification-proof-bundle-narrative-honesty-corrigendum/136-VERIFICATION.md` — six-gate proof commands and expected output [VERIFIED: codebase read]
- `.github/workflows/ci.yml:171-219` — dep-off lane definition confirms Gate 3 commands [VERIFIED: codebase read]
- `lib/mix/tasks/sigra.doctor.ex` — doctor exit-code contract (0 = clean, 1 = misconfigured) [VERIFIED: codebase read]
- `mix.exs:180-234` — extras and groups_for_extras confirming MAINTAINING.md (line 184) and deployment.md (line 218) already registered [VERIFIED: codebase read]
- `.planning/phases/137-optional-dependency-source-of-truth/137-02-SUMMARY.md` and `137-03-SUMMARY.md` — confirmed completed: 2026-05-29 [VERIFIED: codebase read]
- `.planning/ROADMAP.md:45,70,71,132` — exact stale line content confirmed [VERIFIED: codebase read]
- `MAINTAINING.md:216-244` — pre-1.0 SemVer policy + existing section structure [VERIFIED: codebase read]
- `guides/recipes/deployment.md` — existing section structure (H2 headings) [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- None needed — all critical claims verified from codebase.

---

## Metadata

**Confidence breakdown:**
- Deprecation edit shape: HIGH — current annotation text read from source; append is mechanical
- Proof gate commands: HIGH — extracted verbatim from 136-VERIFICATION.md which was itself a verified run
- mix.exs registration: HIGH — confirmed both files already registered, no new edits needed
- ROADMAP reconciliation: HIGH — exact line content confirmed; 137-02/03 summaries confirm completion
- DOC-01 placement: HIGH — section structure of both files read; no conflicts
- Doctor exit code: MEDIUM — expected 0 but not pre-run-verified (open question A2)
- ExDoc grep assertion: MEDIUM — standard ExDoc behavior, specific file path unknown (assumption A1)

**Research date:** 2026-05-29
**Valid until:** N/A — all findings grounded in current codebase state; no external library research

---

## RESEARCH COMPLETE

**Phase:** 140 - Deprecation Hygiene + Verification & Docs Close
**Confidence:** HIGH

### Key Findings

1. **Both deprecation edits are purely additive string appends.** `cookie_opts/0` (trust.ex:43-44) needs ` Scheduled for removal in 0.4.0.` appended to BOTH `@doc deprecated:` and `@deprecated`. `audit_forced_password_change/2` (account.ex:543) needs ` Scheduled for removal in 0.5.0.` appended to `@deprecated` only (no `@doc deprecated:` present). Do not rewrite — only append.

2. **Six proof gates extracted verbatim from 136-VERIFICATION.md.** The new doctor gate (Gate 7) is `cd test/example && mix sigra.doctor` and is expected to exit 0. The docs-render grep assertion (Gate 8, D-07) runs after Gate 5: `grep -r "Scheduled for removal in 0.4.0" doc/` and `grep -r "Scheduled for removal in 0.5.0" doc/`.

3. **No mix.exs changes needed.** Both `MAINTAINING.md` (line 184) and `guides/recipes/deployment.md` (line 218) are already registered in `extras`. DOC-01 is purely appending to existing registered files.

4. **ROADMAP D-12 reconciliation is four targeted edits:** lines 45/70/71 `[ ]`→`[x]`; line 132 `1/3 | In Progress` → `3/3 | Complete | 2026-05-29`. This is justified by 137-02-SUMMARY.md and 137-03-SUMMARY.md both carrying `completed: "2026-05-29"`.

5. **Phase 137 is fully landed.** All three 137-SUMMARY files exist and are dated 2026-05-29. The ROADMAP checkbox drift is cosmetic only.

### File Created
`.planning/phases/140-deprecation-hygiene-verification-docs-close/140-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Deprecation edit shape | HIGH | Current annotation text read from source |
| Proof gate commands | HIGH | Extracted verbatim from prior passing verification |
| mix.exs registration | HIGH | Grep confirmed both files already registered |
| ROADMAP reconciliation | HIGH | Line content confirmed; summaries confirm completion |
| DOC-01 placement | HIGH | Section structure of both files read |
| Doctor gate exit code | MEDIUM | Expected 0; not pre-verified |
| ExDoc grep path | MEDIUM | Standard behavior; specific file path in doc/ not verified |

### Open Questions
- Will `mix sigra.doctor` exit 0 or 1 against `test/example/`? Expected 0; record verbatim if not.
- Exact path within `doc/` where deprecation strings appear; use `grep -r` across whole tree as fallback.

### Ready for Planning
Research complete. Planner can now create PLAN.md files.
