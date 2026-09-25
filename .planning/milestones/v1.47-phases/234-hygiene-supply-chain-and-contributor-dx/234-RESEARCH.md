# Phase 234: Hygiene, Supply Chain, and Contributor DX - Research

**Researched:** 2026-07-31  
**Domain:** Mix gate parity, GitHub Actions supply-chain hygiene, Dependabot, and Playwright CI ownership  
**Confidence:** HIGH for repository seams and locked decisions; MEDIUM for external-tool semantics

## User Constraints (from CONTEXT.md)

### Locked Decisions

<!-- DATA_7fA2kQ9m_START -->
- `mix ci` is the single contributor-facing local mirror of the PR-fast library gate, and a PR CI lane MUST invoke that alias directly. Maintaining separate commands that merely resemble the alias is not acceptable proof of parity.
- Extend the alias to include `format --check-formatted`, `deps.get --check-locked`, and `deps.unlock --check-unused` alongside its existing warnings-as-errors compile, library tests, installer-golden tests, and dependency-off coverage.
- Replace the Phase 198 contract that forbids formatting in `mix ci` with a fail-closed parity contract that asserts the required alias legs and the real CI invocation. Credo, Dialyzer, and `mix_audit` remain out of scope and MUST NOT be pulled in as new gates.
- The one-time formatting cleanup MUST narrow `.formatter.exs` so `test/fixtures/install_golden/tree/**` is excluded from formatter inputs before formatting the tree. Generated golden fixture bytes remain owned by `golden_diff_test`, not by the formatter.
- Replace `googleapis/release-please-action@v5` with the dereferenced immutable commit `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0`. The annotated `v5` tag object SHA (`0dfd8538845b8e92600d271a895a5372865d4062`) MUST NOT be used.
- Add a fail-closed repository policy/contract that inventories release-critical third-party `uses:` references and requires a 40-character commit SHA plus trailing version comment. Do not treat the one known line replacement as sufficient protection against future drift.
- Extend `.github/dependabot.yml` with weekly `mix` updates at `/` and weekly `npm` updates at `/test/example/priv/playwright`, preserving the existing `github-actions` entry. Offline validation must cover YAML shape, documented ecosystem identifiers, directories, and manifest/lockfile existence; authoritative semantic proof comes from GitHub's per-ecosystem update-job logs after the config reaches the default branch, with an update PR retained when an update exists. Absence of a PR alone is not proof because dependencies may already be current.
- Produce one committed, machine-readable or mechanically checked inventory mapping every `test/example/priv/playwright/tests/*.spec.ts` file to the named CI lane(s), event(s), and invocation/config seam that execute it. The inventory MUST fail closed when a spec or lane is added, removed, or becomes unowned, and it is the direct Phase 235 GATE-05 input.
- Current analysis identifies `admin-coherence-sweep.spec.ts` and `admin-theme.spec.ts` as having no CI invocation. Each must be deliberately wired into an appropriate existing lane or deleted with evidence that it is obsolete; no file may remain ambiguously present-but-unexecuted. Preserve useful coverage by default rather than deleting for convenience.
- Close SEED-006 as delivered, not as a new gallery-remediation project. The closeout must cite the corrected Phase 197 root cause/remediation and a current real gallery-lane receipt, including Phase 232 run `30659282026` where the shared-boot `admin_design_recapture` consumer passed 126 design tests. If current execution contradicts that evidence, file the residual as a tracked defect rather than weakening or restating the claim.
- Fold none of the four reviewed pending todos into Phase 234. They are adjacent but each changes a separate policy boundary not owned by DX-01/02/03/04/06.
- Do not add retry machinery for the transient Hex/rebar mirror incident unless new live evidence shows it blocks clean-checkout `mix ci` or a required gate. The recorded failure is currently a one-off Tier-A recapture failure, and the milestone explicitly forbids masking flakes with retries.
<!-- DATA_7fA2kQ9m_END -->

### the agent's Discretion

<!-- DATA_P4vM7sL2_START -->
- Exact plan decomposition and the name/location of new structural guards and the Playwright inventory artifact.
- Which existing PR lane invokes `mix ci`, provided the alias itself is what runs and required check-name/aggregator contracts remain intact.
- Dependabot grouping and commit-message labels, provided all three ecosystems remain covered at the locked directories and update-job evidence is captured.
- Whether each of the two orphan Playwright specs is wired or deleted, based on code intent and non-duplicative coverage evidence.
<!-- DATA_P4vM7sL2_END -->

### Deferred Ideas (OUT OF SCOPE)

<!-- DATA_Z8nC3rT1_START -->
- `.planning/todos/pending/2026-07-10-canary-recapture-lane-excludes-canary.md` — changes frozen-canary/recapture policy; separate trust-boundary work.
- `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` — requires a public release-note convention and release control decision, not action pinning.
- `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — required-check/DAG honesty work explicitly deferred by Phase 231; not owned by current DX requirements.
- `.planning/todos/pending/2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` — one-off non-gating network failure; no retry without evidence it affects local/required-gate reproducibility.
<!-- DATA_Z8nC3rT1_END -->

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM system, Rail Accent assets, and Light/Dark/System themes for any admin-UI work. [VERIFIED: AGENTS.md]
- Admin Playwright tests must use role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: AGENTS.md]
- Replace human verification/UAT with deterministic automation and committed machine-readable evidence where authorized; retry a transient failure once, diagnose deterministic failures, and never waive missing evidence. [VERIFIED: AGENTS.md]

## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| DX-01 | `mix ci` reproduces the PR gate, including formatting and dependency-lock checks. | Alias/CI-invocation parity contract, formatter exclusion, deterministic focused ExUnit test. |
| DX-02 | Release-critical third-party Actions are immutable SHA pins. | Exact Release Please replacement plus a scoped `uses:` inventory guard. |
| DX-03 | Dependabot covers Hex and npm in addition to GitHub Actions. | Three-entry YAML contract and GitHub-processed update-job receipt. |
| DX-04 | Every Playwright spec has a CI lane or is removed. | Committed spec-to-lane/event/command inventory reconciled to live specs and workflow seams. |
| DX-06 | SEED-006 is verified and closed or residual work is filed. | Corrected-root-cause closeout using the Phase 232 non-PR receipt and a current gallery run. |

## Summary

Phase 234 is a hardening phase, not a new toolchain phase. The repository already contains the required Mix alias, contract-test, workflow, Dependabot, shared Playwright boot action, and evidence-ledger seams. The plan should extend those seams with fail-closed tests/scripts rather than introduce packages or a second CI topology. [VERIFIED: codebase grep]

`mix ci` currently runs compile-with-warnings-as-errors, full tests, installer goldens, and dependency-off coverage, while the actual CI library suite is split/aggregated and does not call the alias. The Phase 198 contract actively rejects `format --check-formatted`, so it must be revised rather than supplemented. [VERIFIED: `mix.exs`, `ci.yml`, `phase_198_contributor_dx_contract_test.exs`]

**Primary recommendation:** Implement four small, deterministic contracts: Mix/CI parity, release-action pin inventory, Dependabot shape/filesystem validation, and live Playwright spec ownership reconciliation; then collect the two GitHub-only receipts (Dependabot job and gallery lane) after merge. [HIGH — VERIFIED: codebase + locked CONTEXT]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Local reproducible library gate | Developer CLI / Mix | CI workflow | `mix.exs` owns the command; a PR job must invoke it verbatim. [VERIFIED: `mix.exs`, CONTEXT D-01] |
| Formatter and dependency-lock integrity | Mix / repository files | Fast structural test | Mix performs checks; `.formatter.exs` and `mix.lock` define the accepted state. [CITED: https://mix.hexdocs.pm/Mix.Tasks.Format.html; https://mix.hexdocs.pm/Mix.Tasks.Deps.Get.html] |
| Immutable release Actions | GitHub Actions workflow | Repository contract test | Release workflows carry secrets/privileged permissions; source guard prevents later mutable refs. [VERIFIED: `release-please.yml`, CONTEXT D-05/D-06] |
| Dependency update coverage | Dependabot service | YAML/filesystem contract + live receipt | Local tests prove configuration shape; GitHub performs the update job. [CITED: https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference] |
| Playwright execution ownership | CI matrix/event lanes | Inventory contract | CI commands determine actual execution; config supplies project seams. [VERIFIED: `ci.yml`, `playwright.config.ts`] |
| SEED-006 closure | Planning evidence ledger | Current GitHub run | Existing remediation is proven by CI receipt, not by UI changes. [VERIFIED: SEED-006, 232-EVIDENCE.md] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| Elixir Mix | 1.19.5 installed | Alias execution, formatter, lock checks | Native project task runner; no dependency required. [VERIFIED: local `mix --version`] |
| GitHub Actions | managed service | PR lane, release workflow, CI receipts | Existing authoritative CI surface. [VERIFIED: `.github/workflows/`] |
| Dependabot | GitHub-managed | Weekly `mix`, `npm`, and action updates | Existing config already covers `github-actions`; GitHub docs support locked ecosystem/directory entries. [CITED: https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference] |
| Playwright | lockfile-managed subproject | Existing specs/projects and CI commands | Existing CI uses explicit spec and `--project` selections. [VERIFIED: `ci.yml`, `package-lock.json`] |

### Supporting

| Tool | Version | Purpose | When to Use |
|---|---:|---|---|
| ExUnit planning contracts | repository-native | Hermetic source/configuration guards | For alias, SHA, YAML, and inventory invariants in the fast checks lane. [VERIFIED: `test/sigra/planning/`] |
| Bash / Node guards | Node 22.14.0 installed | Existing guard-test style and robust shell reconciliation | Use only if it makes workflow parsing/inventory validation more direct than ExUnit. [VERIFIED: `scripts/ci/`, local `node --version`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Repository contracts | Human review of YAML/actions/inventory | Human review cannot fail closed on future drift; reject. [HIGH — CONTEXT D-03/D-06/D-08] |
| CI invoking `mix ci` | Duplicated equivalent workflow commands | Duplicated commands reintroduce the exact drift DX-01 prohibits; reject. [HIGH — CONTEXT D-01] |
| Current CI lanes | New Playwright boot/lane | A new lane duplicates topology and obscures Phase 235 ownership; use existing matrix seams. [HIGH — VERIFIED: Phase 232 evidence + CONTEXT] |

**Installation:** No external packages are authorized or needed. [HIGH — CONTEXT D-03]

## Architecture Patterns

### System Architecture Diagram

```text
Contributor
    │
    ├── mix ci ──> compile/test/golden/dep-off + format + lock checks
    │                                  │
    │                                  └── .formatter.exs excludes generated golden tree
    │
Pull request ──> CI PR library lane ──> invokes `mix ci` verbatim ──> required gate
    │
    ├── release workflows ──> scoped `uses:` SHA/comment guard ──> fail closed
    ├── dependabot.yml ──> local YAML+manifest contract ──> GitHub update job receipt
    └── Playwright files ──> ownership inventory reconciler ──> named matrix seam/event/command
                                                            │
                                                            └── Phase 235 GATE-05 input

Non-PR gallery lane ──> current `admin_design_recapture` receipt ──> SEED-006 closeout or tracked defect
```

### Recommended Project Structure

```text
test/sigra/planning/
├── phase_198_contributor_dx_contract_test.exs  # revise to the Phase 234 parity ratchet
└── phase_234_hygiene_supply_chain_contract_test.exs  # SHA, Dependabot, inventory structural checks

.planning/phases/234-hygiene-supply-chain-and-contributor-dx/
└── 234-PLAYWRIGHT-INVENTORY.(md|json|tsv)  # committed, machine-checked Phase 235 input

scripts/ci/
└── playwright-inventory-guard.(sh|mjs)  # only if a focused reconciler is clearer than ExUnit
```

### Pattern 1: One source of truth with a CI call-through

**What:** Keep the exact local command in `mix.exs`; have the selected PR library lane invoke `mix ci`, then assert both alias contents and that workflow call. [HIGH — CONTEXT D-01/D-03]

**When to use:** Any contributor-facing gate whose local/CI parity matters.

**Example:**

```elixir
# `mix.exs` conceptual final alias; order must be verified against actual CI requirements.
ci: [
  "format --check-formatted",
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "test",
  "ci.install_golden",
  "sigra.dep_off"
]
```

`mix deps.get --check-locked` raises when lockfile changes are pending, and `mix deps.unlock --check-unused` rejects unused lock entries. [CITED: https://mix.hexdocs.pm/Mix.Tasks.Deps.Get.html; https://mix.hexdocs.pm/Mix.Tasks.Deps.Unlock.html]

### Pattern 2: Enumerate then reconcile, never infer coverage from a broad config regex

**What:** Make an inventory with one row per `tests/*.spec.ts`, its explicit CI lane ID, events, actual workflow command, and Playwright project/config seam. The guard derives the live spec universe via glob and requires exact set equality; it must also verify each referenced lane/command exists. [HIGH — CONTEXT D-08]

**When to use:** CI topology where `testMatch` and selected filenames can diverge.

**Recommended resolution:** Wire both `admin-theme.spec.ts` and `admin-coherence-sweep.spec.ts` into the existing `admin_behavior` shard unless targeted source inspection proves a spec obsolete. `admin-theme` is already included by the config's `ADMIN_BEHAVIOR_SPECS` regex but missing from the shard command, confirming command-level—not config-level—ownership is decisive. `admin-coherence-sweep` is absent from the shown config ownership regex and CI commands, so it requires an explicit route or deletion evidence. [HIGH — VERIFIED: `playwright.config.ts`, `ci.yml`, CONTEXT D-09]

### Pattern 3: Structural proof plus a service-owned receipt

**What:** Validate Dependabot and action references offline in fast checks, but reserve the claim that GitHub processed Dependabot or executed gallery tests for an actual GitHub job log. [HIGH — CONTEXT D-07/D-10]

**Example inventory row shape:**

```json
{
  "spec": "admin-theme.spec.ts",
  "lanes": [{
    "workflow": ".github/workflows/ci.yml",
    "job": "example_playwright_shard",
    "seam": "admin_behavior",
    "events": ["pull_request", "push", "schedule", "workflow_dispatch"],
    "command": "npx playwright test … tests/admin-theme.spec.ts … --project=chromium --retries=0",
    "config_seam": "ADMIN_BEHAVIOR_SPECS / chromium"
  }]
}
```

Playwright projects are logical test groups, and the CLI `--project` option selects a project; config membership alone is not evidence that a workflow command runs a file. [CITED: https://playwright.dev/docs/test-projects]

### Anti-Patterns to Avoid

- **Rewriting a parallel library topology into the alias:** `mix ci` needs behavioral parity, but changing required check IDs/aggregators can strand the protected check. Keep the protected `Library tests` aggregation intact and choose a safe lane to call the alias. [VERIFIED: `ci.yml`; CONTEXT D-01]
- **Running formatter before narrowing inputs:** formatting `test/fixtures/install_golden/tree/**` changes golden bytes and breaks golden ownership. [HIGH — CONTEXT D-04]
- **Trusting an action tag or annotated tag SHA:** use only the locked dereferenced commit and enforce it mechanically. [HIGH — CONTEXT D-05/D-06]
- **Treating no Dependabot PR as validation:** there may be no available update; obtain per-ecosystem update-job logs after default-branch merge. [HIGH — CONTEXT D-07]
- **Declaring a spec covered because it matches a config regex:** current CI executes explicit filenames, and two files are known to have no invocation. [HIGH — VERIFIED: `ci.yml`, CONTEXT D-09]
- **Reopening gallery remediation:** Phase 197 fixed root cause and Phase 232 has a green receipt; Phase 234 only verifies/records the closure or tracks a new contradiction. [HIGH — CONTEXT D-10]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Formatting and Mix lock correctness | Custom formatter or lock parser | `mix format --check-formatted`, `mix deps.get --check-locked`, `mix deps.unlock --check-unused` | Native tools own formatter inputs and lock semantics. [CITED: Mix docs] |
| Dependency update execution | Custom updater/scheduler | GitHub Dependabot | GitHub owns ecosystem update jobs and PR lifecycle. [CITED: GitHub Dependabot docs] |
| Browser test routing | A second boot setup or ad hoc runner | Existing Phase 232 shared boot + named shard commands | Existing topology has observed receipt and protected terminal aggregate. [VERIFIED: `ci.yml`, 232-EVIDENCE.md] |
| Action-version lookup policy | A one-off grep only | Scoped, fail-closed source contract | A full SHA and comment requirement needs inventory and regression coverage. [HIGH — CONTEXT D-06] |

**Key insight:** The phase’s value is durable reconciliation, not “correct today” edits; each inventory must derive a live universe and reject drift. [HIGH — CONTEXT D-03/D-06/D-08]

## Common Pitfalls

### Pitfall 1: Alias “parity” that excludes CI invocation

**What goes wrong:** Local and CI commands drift despite matching at review time.  
**Why it happens:** CI independently restates commands.  
**How to avoid:** One PR CI lane calls `mix ci` exactly; contract asserts alias legs, forbidden gates, and the real workflow invocation. [HIGH — CONTEXT D-01/D-03]  
**Warning signs:** CI YAML still contains a hand-expanded test/compile sequence after the change. [VERIFIED: `ci.yml`]

### Pitfall 2: Golden corruption from formatter cleanup

**What goes wrong:** Generated installer golden fixture files change and `golden_diff_test` fails.  
**Why it happens:** Current formatter inputs include `test/fixtures/**`. [VERIFIED: `.formatter.exs`]  
**How to avoid:** Exclude `test/fixtures/install_golden/tree/**` before a one-time formatting commit, then run the focused golden test and formatter check. [HIGH — CONTEXT D-04]

### Pitfall 3: Breaking protected check topology

**What goes wrong:** Changing the named `Library tests` aggregate causes the repository ruleset check to disappear.  
**Why it happens:** Matrix jobs alter displayed check names; the existing aggregate protects the byte-stable name. [VERIFIED: `ci.yml`]  
**How to avoid:** Preserve existing job IDs/display names and verify the aggregate after moving the alias call. [HIGH — CONTEXT D-01]

### Pitfall 4: Partial action pinning

**What goes wrong:** Release Please is pinned but a future release-critical `uses:` line is mutable or undocumented.  
**How to avoid:** Inventory explicitly scoped release-critical workflows; require `owner/repo@` followed by exactly 40 lowercase hex characters and a same-line version comment. Also assert the forbidden annotated tag-object SHA is absent. [HIGH — CONTEXT D-05/D-06]

### Pitfall 5: Non-hermetic Dependabot proof

**What goes wrong:** YAML looks valid but GitHub cannot process a configured ecosystem/directory.  
**How to avoid:** Test schema identifiers/directories/files locally, then capture GitHub update-job logs after default-branch merge. [HIGH — CONTEXT D-07; CITED: GitHub Dependabot docs]

### Pitfall 6: Inventory that becomes stale prose

**What goes wrong:** A committed table is not updated when files or CI seams change.  
**How to avoid:** Guard live glob set equality, non-empty lane ownership, known workflow/job/seam existence, and command/config references. [HIGH — CONTEXT D-08]

## Code Examples

### Dependabot entries

```yaml
# Preserve existing github-actions entry; add these two entries.
- package-ecosystem: "mix"
  directory: "/"
  schedule:
    interval: "weekly"

- package-ecosystem: "npm"
  directory: "/test/example/priv/playwright"
  schedule:
    interval: "weekly"
```

GitHub requires `version: 2`, an `updates` entry per ecosystem, a directory, and a schedule interval; directories are root-relative. [CITED: https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference]

### Immutable Release Please pin

```yaml
- name: Run Release Please
  id: release
  if: ${{ steps.release-preflight.outputs.should_run == 'true' }}
  uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
```

This is a locked project decision; do not substitute the annotated tag-object SHA. [HIGH — CONTEXT D-05]

### Inventory guard invariants

```text
live_specs = sorted(glob("test/example/priv/playwright/tests/*.spec.ts"))
inventory_specs = sorted(inventory.spec)
assert live_specs == inventory_specs
assert every inventory row has >= 1 named lane
assert every row's workflow/job/seam/command/config seam resolves in current source
assert admin-theme.spec.ts and admin-coherence-sweep.spec.ts have resolved ownership or are absent
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Separate local alias and expanded CI commands | Alias-as-CI-call-through with parity ratchet | Phase 234 | Prevents local/CI gate drift. [HIGH — CONTEXT D-01] |
| Floating action tag | Full SHA plus version comment and inventory guard | Phase 234 | Makes release action resolution immutable. [HIGH — CONTEXT D-05/D-06] |
| Hand-inspected Playwright coverage | Reconciled spec-to-lane artifact | Phase 234 | Gives Phase 235 a durable GATE-05 input. [HIGH — CONTEXT D-08] |

**Deprecated/outdated:** The Phase 198 assertion that `mix ci` must not include formatting is explicitly superseded by Phase 234’s locked parity contract. [HIGH — CONTEXT D-03; VERIFIED: phase_198 contract]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Both orphan specs can be added to `admin_behavior` without changing the intended test partition. | Architecture Patterns | A source-level inspection may show one is obsolete or needs a distinct project; planner must inspect each spec before wiring. |

## Open Questions (RESOLVED)

1. **RESOLVED — `library_tests_shard` is the sole full-suite `mix ci` owner.**
   - What we know: protected `Library tests` is an aggregate over sharded work, while `mix ci` is one full local sequence. [VERIFIED: `ci.yml`, `mix.exs`]
   - Planning resolution: `library_tests_shard` alone invokes the full `MIX_ENV=test mix ci` suite. Duplicate shard, scaffold, and dependency-off suite execution is removed, while the protected `Library tests` aggregation and its required-check identity remain intact. The implementation plan must prove exact-one ownership structurally and observe it on a PR run. [HIGH — CONTEXT D-01; resolved by Plans 01/09]

2. **RESOLVED — retain both orphan specs and route them through `admin_behavior`.**
   - What we know: both have no explicit CI command; `admin-theme` matches the configuration behavior regex, while `admin-coherence-sweep` does not. [VERIFIED: `ci.yml`, `playwright.config.ts`]
   - Planning resolution after source inspection: `admin-theme.spec.ts` and `admin-coherence-sweep.spec.ts` both carry useful admin behavior coverage and are deliberately routed into the existing `admin_behavior` CI lane. Neither is deleted for convenience; the inventory contract must prove their command- and config-level ownership. [HIGH — CONTEXT D-09; resolved by Plan 08]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir/Mix | Local alias and focused contracts | ✓ | Mix 1.19.5 / OTP 28 | — [VERIFIED: local probe] |
| Node/npm | Playwright inventory/guard if Node implementation chosen | ✓ | Node 22.14.0 / npm 11.1.0 | ExUnit/Bash contract [VERIFIED: local probe] |
| GitHub CLI | Post-merge Dependabot/gallery receipts | ✓ | gh 2.95.0 | GitHub Actions UI/log API [VERIFIED: local probe] |
| GitHub-hosted Actions/Dependabot | Semantic receipts | External | — | None; must wait for default-branch execution [HIGH — CONTEXT D-07/D-10] |

**Missing dependencies with no fallback:** None for implementation; GitHub receipts are intentionally post-merge evidence. [HIGH — CONTEXT]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (repository existing) [VERIFIED: `test/sigra/planning/`] |
| Config file | `mix.exs` [VERIFIED: codebase] |
| Quick run command | `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` plus new focused Phase 234 contract | 
| Full suite command | `mix ci` after alias implementation; CI PR lane must invoke the same alias |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| DX-01 | Alias contains exactly required legs, excludes new out-of-scope gates, workflow invokes alias, formatter excludes golden tree | ExUnit structural + Mix smoke | focused planning test; `mix format --check-formatted`; `mix ci` | ❌ revise Phase 198 / add Phase 234 |
| DX-02 | Scoped release-critical third-party actions are full SHA pins with comments and locked Release Please pin | ExUnit or script contract | focused Phase 234 guard | ❌ Wave 0 |
| DX-03 | Dependabot has unique weekly `github-actions:/`, `mix:/`, `npm:/test/example/priv/playwright`; manifests/locks exist | ExUnit/YAML structural | focused Phase 234 guard | ❌ Wave 0 |
| DX-04 | Inventory equals live spec set; each row resolves to an active lane/event/command/config seam; orphans resolved | Reconciliation guard | focused Phase 234 guard | ❌ Wave 0 |
| DX-06 | Closeout cites corrected root cause plus current successful gallery receipt, otherwise durable tracked defect | Evidence contract + live CI | focused evidence test; `gh run view <run>` | ❌ Wave 0 / live receipt |

### Sampling Rate

- **Per task commit:** focused affected contract plus formatter/fixture test when formatter inputs change.
- **Per wave merge:** `mix test test/sigra/planning/` and relevant deterministic CI guard self-tests.
- **Phase gate:** `mix ci` succeeds locally; PR CI invokes it; GitHub Dependabot logs and gallery lane receipt are captured without sleeps or manual-only pass claims.

### Wave 0 Gaps

- [ ] Revise `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` into the new parity contract.
- [ ] Add a focused supply-chain/Dependabot/inventory contract or deterministic `scripts/ci` guard with a self-test.
- [ ] Add committed Phase 234 Playwright inventory artifact consumed mechanically.
- [ ] Add receipt slots/evidence document for Dependabot’s three update jobs and current gallery execution.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | No app-auth change. [VERIFIED: phase scope] |
| V3 Session Management | No | No session change. [VERIFIED: phase scope] |
| V4 Access Control | Yes | Keep release-workflow permissions and privileged path scoped; never weaken for a pin/config change. [VERIFIED: `release-please.yml`] |
| V5 Input Validation | Yes | Parse/reconcile repository-controlled YAML/text without shell interpolation; test exact identifiers. [HIGH — project CI patterns] |
| V6 Cryptography | No | No cryptographic implementation; immutable action revisions are supply-chain integrity controls. [VERIFIED: phase scope] |

### Known Threat Patterns for GitHub Actions / dependency configuration

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Mutable third-party action ref changes after review | Tampering | Full 40-character SHA and version-comment contract over release-critical workflows. [HIGH — CONTEXT D-05/D-06] |
| Dependency ecosystem silently unmaintained | Tampering | Required Dependabot entries plus GitHub-owned update-job receipt. [HIGH — CONTEXT D-07] |
| Malformed inventory claims omitted browser coverage | Repudiation | Fail-closed live-universe reconciliation and CI command/seam verification. [HIGH — CONTEXT D-08] |
| Unsafe workflow-context interpolation in guards | Tampering | Use fixed source files/argument arrays; preserve established env mapping and `set -euo pipefail` pattern. [VERIFIED: `ci.yml`] |

## Sources

### Primary (HIGH confidence)

- Repository `mix.exs`, `.formatter.exs`, `.github/workflows/{ci,release-please}.yml`, `.github/dependabot.yml`, `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` — current seams and drift points.
- `234-CONTEXT.md` — locked scope and evidence discipline.
- `232-EVIDENCE.md` and `SEED-006-admin-design-gallery-ci-baseline-recapture.md` — gallery correction and run `30659282026` receipt.

### Secondary (MEDIUM confidence)

- https://mix.hexdocs.pm/Mix.Tasks.Format.html — formatter inputs/check behavior.
- https://mix.hexdocs.pm/Mix.Tasks.Deps.Get.html — `--check-locked` semantics.
- https://mix.hexdocs.pm/Mix.Tasks.Deps.Unlock.html — `--check-unused` semantics.
- https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference — Dependabot schema, directories, scheduling.
- https://playwright.dev/docs/test-projects — project and CLI-selection semantics.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools already exist in the repository; no package selection.
- Architecture: HIGH — locked decisions map directly onto verified repository seams.
- Pitfalls: HIGH — golden-fixture, action pin, orphan-spec, and receipt risks are explicit in code/context.

**Research date:** 2026-07-31  
**Valid until:** 2026-08-30 for repository seams; refresh external GitHub/Mix docs before any scope expansion.
