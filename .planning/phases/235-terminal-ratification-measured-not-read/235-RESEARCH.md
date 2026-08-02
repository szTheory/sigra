# Phase 235: Terminal Ratification — Measured, Not Read - Research

**Researched:** 2026-08-02
**Domain:** GitHub Actions run-data measurement, fail-closed CI ownership reconciliation, contributor CI documentation, and milestone-record closeout
**Confidence:** HIGH for repository seams and locked scope; MEDIUM for GitHub CLI/Actions semantics

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

<!-- DATA_Q7m2Lx8P_START -->
- **D-01:** Use `scripts/ci/ci-run-metrics.sh` in its default `wall` mode for the terminal after-window. Declare an immutable post-change cutoff tied to the last topology-changing milestone commit, record the capture endpoint, and include at least 10 `pull_request` runs after that cutoff. Use the same bounded time window when recording push-to-`main` and scheduled outcomes.
- **D-02:** Preserve the instrument's baseline-compatible semantics: queue-inclusive `updatedAt - createdAt`, sorted `floor(n/2)` p50, and all conclusions retained. Do not substitute job-span timing, successful runs only, hand arithmetic, or a rolling window that admits pre-change runs.
- **D-03:** Every measured claim must cite the exact command and real run IDs from which it was derived. Report the observed p50 even when it is at or above 12 minutes. If FAST-01 misses, record the measured number and identify the binding pole from run/job data; do not restate the target as achieved by intent.
- **D-04:** Produce one committed terminal before/after ownership artifact for GATE-05. It must map every affected spec or suite to its PR, push-to-`main`, and nightly ownership before and after Phases 230–234, including Playwright specs, design snapshots/axe coverage, `admin_eval_render`, library/scaffold/golden suites, and terminal aggregates. A current-state-only or Playwright-only list is insufficient.
- **D-05:** Consume `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json` as the mechanically verified current Playwright input rather than copying or replacing its ownership model. Extend fail-closed validation to reject missing, stale, duplicate, unowned, or non-executable before/after rows. Each moved row must name its receiver and cite the phase evidence or real lane receipt that proves execution.
- **D-06:** Keep `MIX_ENV=test mix ci` as the contributor-facing local parity path. Update `CONTRIBUTING.md` so its CI overview distinguishes direct shard/harness owners from byte-stable terminal required aggregates, explains the supported Playwright reproduction seam, and identifies signals intentionally limited to non-PR events. Documentation must match the live workflow rather than preserving the pre-reshape topology.
- **D-07:** Reconcile SEED-005 and the `CI-PERF` milestone-arc entry as an already-completed audit executed through Phases 230–235. Do not re-audit. Close as delivered only to the extent supported by terminal measurements; if the performance target misses or another residual remains, file or preserve an evidence-backed residual and link it from the closeout.
- **D-08:** Fold no pending todos into Phase 235. Earlier-phase CI todos, stale residual notes, and unrelated product/release/UI items remain outside the fixed FAST-01/GATE-05 boundary.
<!-- DATA_Q7m2Lx8P_END -->

### the agent's Discretion

<!-- DATA_V3n9Rw6K_START -->
- Exact filename and JSON/Markdown representation of the single GATE-05 artifact, provided it is one committed artifact with deterministic reconciliation coverage.
- Exact contract-test/helper names and table layout, following the existing Phase 230 measurement and Phase 234 inventory patterns.
- Exact wording and organization of `CONTRIBUTING.md`, provided the topology and reproduction claims are mechanically checkable against the live workflow.
- Whether a post-measurement timeout tightening is warranted. Any change must be sized from the measured steady state and must not truncate the evidence window or expand this phase into performance remediation.
<!-- DATA_V3n9Rw6K_END -->

### Deferred Ideas (OUT OF SCOPE)

<!-- DATA_H5q1Zd4B_START -->
- Earlier-phase performance and gate-honesty todos (`playwright-parallelization-per-shard-db`, `admin_eval_render`, generated-host parity, release-gate timeout/notifier) remain assigned to or delivered by Phases 231–232; reconcile their todo status separately rather than reimplementing them here.
- Phase 234 evidence residual notes are stale against its completed verification and do not replace Phase 235's fresh terminal measurement window.
- Release, auth UI, admin UI, installer, security, and GitHub Pages matches are keyword-adjacent new capabilities or defects outside FAST-01/GATE-05.
- Transient dependency-download retry work remains excluded by the milestone's no-flake-masking guardrail.
<!-- DATA_H5q1Zd4B_END -->
</user_constraints>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system, Rail Accent assets, and Light/Dark/System modes for any admin UI touched by the phase. [VERIFIED: `AGENTS.md`]
- Keep admin Playwright checks deterministic: role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: `AGENTS.md`]
- Replace human UAT with deterministic tests, automation, CI polling, and committed machine-readable evidence; retry a transient failure once, diagnose deterministic failure, and never waive missing evidence. [VERIFIED: `AGENTS.md`]
- Use at most one watcher per workflow run; when a watch is needed use `gh run watch <run-id> --repo szTheory/sigra --compact --interval 60 --exit-status`; inspect `gh api rate_limit` before a long watch and stop polling after 403/429. [VERIFIED: `AGENTS.md`]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| FAST-01 | PR merge verdict under 12 minutes p50 across at least 10 post-change runs. | Existing hermetic metrics instrument, immutable cutoff protocol, retained-outcome window, job-level binding-pole receipt. |
| GATE-05 | One artifact shows what runs on PR/main/nightly before and after, proving nothing silently dropped. | Phase 234 verified Playwright inventory, phase receipts, live-workflow reconciliation, and a new fail-closed terminal contract. |
</phase_requirements>

## Summary

Phase 235 is a terminal evidence phase, not a CI-topology rewrite. `scripts/ci/ci-run-metrics.sh` already implements the required baseline-compatible calculation: default `wall` mode uses queue-inclusive `updatedAt - createdAt`; it retains failed/cancelled conclusions; and p50 is the sorted element at `floor(n/2)`. Its hermetic test locks those semantics. The plan must invoke this script on a declared fixed after-window, preserve its raw run IDs and command, and record the measured outcome even if FAST-01 misses. [VERIFIED: `scripts/ci/ci-run-metrics.sh`, `scripts/ci/ci-run-metrics.test.sh`]

The new durable deliverable should be one committed JSON ownership ledger (recommended: `235-TERMINAL-RATIFICATION.json`) plus a focused ExUnit contract. The ledger must join: historical before receivers from Phases 230–233 evidence; the Phase 234 inventory as current Playwright input; actual workflow jobs/seams; and named live run receipts. It cannot infer execution from YAML or from a terminal aggregate alone. Phase 234 already establishes the required style: live specs are enumerated deterministically and validation rejects missing, stale, duplicate, unowned, missing-job, missing-command-marker, and invalid harness-indirection entries. [VERIFIED: `234-PLAYWRIGHT-INVENTORY.json`, `phase_234_playwright_inventory_contract_test.exs`, Phase 235 CONTEXT D-04/D-05]

The remaining documentation and planning-record edits follow the same source of truth. `CONTRIBUTING.md` currently describes the former broad topology; it must distinguish direct execution owners (`library_tests_shard`, Playwright shard/harness jobs) from byte-stable terminal aggregates (`Library tests`, `Example Playwright smoke`, `ci-gate`) and name the non-PR-only signals. `MILESTONE-ARC.md` still labels `CI-PERF` active while `STATE.md` identifies the completed audit and the v1.47 execution sequence; close both only according to the measured FAST-01/GATE-05 result. [VERIFIED: `CONTRIBUTING.md`, `.github/workflows/ci.yml`, `.planning/MILESTONE-ARC.md`, `.planning/STATE.md`]

**Primary recommendation:** Plan a fail-closed, evidence-backed ratification ledger and its contract first; after the tenth eligible PR run exists, capture one immutable window with the existing instrument, append job-span receipts only to diagnose a miss, then update contributor and milestone records from that artifact.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| PR wall-clock verdict | GitHub Actions / GitHub API | Repository metrics script | GitHub records authoritative run timestamps; the committed script applies the locked baseline formula. [VERIFIED: `ci-run-metrics.sh`] |
| Binding-pole diagnosis | GitHub Actions job metadata | Terminal evidence ledger | A run-level miss needs individual job durations, which `--jobs <run-id>` exposes. [VERIFIED: `ci-run-metrics.sh`] |
| Spec/suite event ownership | CI workflow | Repository ownership contract | Jobs and commands execute tests; the contract proves every ledger row still maps to those executable seams. [VERIFIED: `ci.yml`, Phase 234 inventory test] |
| Local reproduction guidance | Developer CLI / Mix | Contributor documentation | `MIX_ENV=test mix ci` remains the local library-gate parity path; docs must accurately delimit CI-only work. [VERIFIED: `CONTRIBUTING.md`, Phase 235 CONTEXT D-06] |
| SEED and milestone closure | Planning records | Terminal artifact | Closeout consumes measured evidence rather than changing runtime behavior. [VERIFIED: Phase 235 CONTEXT D-07] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| Repository `scripts/ci/ci-run-metrics.sh` | repository-local | Baseline-compatible wall-clock and per-job measurement | It is the milestone's explicitly mandated instrument and has a hermetic contract. [VERIFIED: `ci-run-metrics.sh`] |
| GitHub CLI `gh` | 2.95.0 installed | Retrieve workflow run and job metadata | The script's `gh run list` and `gh run view` fields are supported by the official CLI manual. [VERIFIED: local `gh --version`; CITED: https://cli.github.com/manual/gh_run_list; https://cli.github.com/manual/gh_run_view] |
| ExUnit planning contract | Mix 1.19.5 installed | Fail-closed ledger/doc/workflow validation | Existing Phase 234 ownership contract is the closest repository precedent. [VERIFIED: local `mix --version`, `phase_234_playwright_inventory_contract_test.exs`] |
| GitHub Actions `ci.yml` | managed service | Authoritative events, jobs, direct owners, and aggregates | Workflows can be triggered by PR, push, and schedule; job conditions can suppress execution, so run receipts remain necessary. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax; https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows] |

### Supporting

| Tool | Version | Purpose | When to Use |
|---|---:|---|---|
| `jq` | 1.7.1 installed | Inspect/validate committed JSON evidence and scripted metadata | For deterministic ledger test fixtures and review of metrics JSON. [VERIFIED: local `jq --version`] |
| Bash | 5.2.37 installed | Existing hermetic metrics contract and CI scripts | Retain for measurement/self-tests; do not add a competing calculator. [VERIFIED: local `bash --version`] |
| Node | 22.14.0 installed | Existing Playwright configuration seam only | Use only if a validation helper genuinely needs existing Node tooling. [VERIFIED: local `node --version`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Existing wall-mode script | Hand-built `gh`/`jq` calculation | Violates D-02 and risks changing queue inclusion, p50 indexing, or outcome retention; reject. [HIGH — Phase 235 CONTEXT D-01/D-02] |
| One committed ownership ledger | Separate per-phase markdown notes | Cannot establish one complete, mechanically reconciled GATE-05 source; reject. [HIGH — Phase 235 CONTEXT D-04/D-05] |
| Run/job receipts | YAML-only topology review | A conditional can make a plausible job skip; GitHub documents that `jobs.<job_id>.if` prevents execution. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |

**Installation:** No external package is needed or authorized; use the repository's existing scripts, CLI tools, ExUnit, and workflow. [VERIFIED: phase scope and existing codebase]

## Architecture Patterns

### System Architecture Diagram

```text
Immutable topology cutoff + capture endpoint
                 │
                 ▼
 GitHub Actions ci.yml ── PR / push-to-main / schedule runs ──► GitHub run + job metadata
                 │                                                    │
                 │                                                    ▼
 Phase 230–234 receipts + 234 Playwright inventory ──► terminal ownership ledger
                                                               │
                           live specs / workflow seams ────────┤ fail-closed ExUnit contract
                                                               ▼
     ci-run-metrics.sh --mode wall --since <cutoff> ──► measured tables + real run IDs
                                                               │
                              FAST-01 pass/miss + binding pole ┤
                                                               ▼
                         CONTRIBUTING.md + SEED-005 + CI-PERF closeout
```

### Recommended Project Structure

```text
.planning/phases/235-terminal-ratification-measured-not-read/
├── 235-TERMINAL-RATIFICATION.json  # single before/after GATE-05 and FAST-01 evidence artifact
├── 235-RESEARCH.md
└── 235-...-SUMMARY.md               # execution summary only, not a second evidence source
test/sigra/planning/
└── phase_235_terminal_ratification_contract_test.exs
```

### Pattern 1: Immutable-window measurement

**What:** Record a topology cutoff SHA/timestamp and capture endpoint before collecting the terminal window. Run the existing script with `--since` and `--event pull_request`; retain every matching outcome. Then include the corresponding fixed-window push and schedule tables, not a separately rolling sample. [HIGH — Phase 235 CONTEXT D-01/D-02]

**When to use:** Once 10 or more post-cutoff PR runs exist; until then the phase remains evidence-pending, not performance-passed. [HIGH — FAST-01, CONTEXT D-01]

**Example:**

```bash
# Source: repository measurement contract; record literal cutoff and output in the ledger.
bash scripts/ci/ci-run-metrics.sh --mode wall --since '<ISO-8601 cutoff>' --event pull_request --format json
bash scripts/ci/ci-run-metrics.sh --mode wall --since '<same cutoff>' --event push --format json
bash scripts/ci/ci-run-metrics.sh --mode wall --since '<same cutoff>' --event schedule --format json
```

### Pattern 2: Direct-owner vs terminal-aggregate ownership

**What:** Model each test family with `before` and `after` rows for `pull_request`, `push`, and `schedule`. Each row names the direct execution job and seam, any byte-stable terminal aggregate, event state (`executes`, `intentionally_not_pr`, or equivalent explicit state), receiver if moved, and evidence reference/run ID. [HIGH — CONTEXT D-04/D-05]

**When to use:** For all 20 current Playwright specs and every affected non-Playwright family: snapshots/axe, `admin_eval_render`, library/scaffold/golden suites, and terminal aggregates. [HIGH — CONTEXT D-04]

### Pattern 3: Fail-closed reconciliation built on the Phase 234 inventory

**What:** Decode `234-PLAYWRIGHT-INVENTORY.json`; treat it as the after-state Playwright input. Assert exact sorted unique coverage of current specs, then require each terminal ledger after-row to match an inventory lane/job/seam/event and executable workflow command or approved harness mapping. Add negative fixtures for missing, stale, duplicate, unowned, non-executable, missing receiver, and absent receipt rows. [VERIFIED: Phase 234 inventory and contract test; HIGH — CONTEXT D-05]

### Anti-Patterns to Avoid

- **Recomputing p50 or filtering failures:** changes the baseline comparison and violates D-02. [HIGH — CONTEXT D-02]
- **Using a terminal aggregate as the only execution proof:** an aggregate result does not identify which direct job/seam ran. [HIGH — CONTEXT D-04; VERIFIED: `ci.yml` has separate shard/harness/aggregate jobs]
- **Copying the Phase 234 inventory:** it is the current input; terminal evidence must consume and extend it. [HIGH — CONTEXT D-05]
- **Closing CI-PERF before the measurement verdict:** creates an unsupported claim if the p50 misses. [HIGH — CONTEXT D-03/D-07]
- **Collecting a new audit:** Phase 235 only reconciles completed audit execution and fresh terminal measurements. [HIGH — CONTEXT D-07]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| CI wall-clock statistics | New shell/JQ metrics calculator | `scripts/ci/ci-run-metrics.sh --mode wall` | Existing test locks duration, p50, clamping, and retained-outcome semantics. [VERIFIED: script + self-test] |
| Current Playwright ownership discovery | A second spec scanner/inventory model | `234-PLAYWRIGHT-INVENTORY.json` and its validation precedent | It already maps all current specs to executable lanes and harness exceptions. [VERIFIED: Phase 234 inventory/test] |
| Workflow event interpretation | Documentation prose inferred from YAML | Live run/job receipts plus workflow contract test | GitHub `if` conditions can prevent job execution. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |
| PR CI reproduction | New local command | `MIX_ENV=test mix ci` | Locked contributor parity path. [HIGH — CONTEXT D-06; VERIFIED: `CONTRIBUTING.md`] |

**Key insight:** This phase's value is provenance, not analysis sophistication: use the existing calculator and inventory, join them with live receipts, and make future drift mechanically fail.

## Common Pitfalls

### Pitfall 1: Measuring a moving or pre-change window

**What goes wrong:** A rolling `--limit` window can blend pre-topology runs into after data or change after the claim is written.
**Why it happens:** `gh run list` defaults to recent runs and the instrument's default limit is 40. [VERIFIED: `ci-run-metrics.sh`; CITED: https://cli.github.com/manual/gh_run_list]
**How to avoid:** Commit cutoff SHA/time, endpoint, literal commands, all selected run IDs, and count before deciding FAST-01.
**Warning signs:** Fewer than 10 PR IDs, a run created before cutoff, or different bounds for PR/push/schedule.

### Pitfall 2: Declaring a successful aggregate as coverage proof

**What goes wrong:** A required aggregate stays green while an upstream direct lane is skipped or a spec is no longer invoked.
**Why it happens:** Jobs can be prevented from running by `jobs.<job_id>.if`; static topology does not prove runtime execution. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]
**How to avoid:** Require direct owner + seam + event + concrete receipt for every moved row and test negative fixtures.
**Warning signs:** An ownership row names only `ci-gate`/aggregate, has no command marker, receiver, or run ID.

### Pitfall 3: Overstating an honest FAST-01 miss

**What goes wrong:** Documentation says the target is achieved because topology changed, while measured p50 remains >=12m.
**Why it happens:** Earlier evidence proves individual improvements, not the terminal population statistic.
**How to avoid:** Treat p50 threshold as a computed verdict; when it misses, include `--jobs` data for representative/max or median-neighbor runs to identify the binding pole and preserve/file the residual.
**Warning signs:** No p50 field, only successful runs, or no per-job evidence after a miss. [HIGH — CONTEXT D-02/D-03]

### Pitfall 4: Documentation that preserves the old monolithic topology

**What goes wrong:** Contributors cannot tell what `mix ci` reproduces, which job executes a suite, or which signal is intentionally non-PR.
**How to avoid:** Test representative documentation claims against literal current job IDs, check names, command seams, and event gates in `ci.yml`; retain the locked `MIX_ENV=test mix ci` wording.
**Warning signs:** Docs call `example_playwright_smoke` the executor rather than aggregate, or omit non-PR `admin_eval_render`/recapture signals. [VERIFIED: `CONTRIBUTING.md`, `ci.yml`; HIGH — CONTEXT D-06]

## Code Examples

Verified repository patterns:

### Baseline-compatible run retrieval

```bash
# Source: scripts/ci/ci-run-metrics.sh
gh run list --repo szTheory/sigra --workflow ci.yml --limit 40 \
  --json databaseId,event,createdAt,updatedAt,conclusion
gh run view <run-id> --repo szTheory/sigra --json jobs
```

The official CLI documents these JSON fields and both commands. [CITED: https://cli.github.com/manual/gh_run_list; https://cli.github.com/manual/gh_run_view]

### Focused deterministic contract execution

```bash
MIX_ENV=test mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
```

The first command is the existing contract precedent; the second is the recommended Wave 0 addition. [VERIFIED: `phase_234_playwright_inventory_contract_test.exs`; [ASSUMED] proposed Phase 235 filename]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| One broad PR CI topology with expensive evidence lanes | Direct shards/harnesses plus byte-stable terminal aggregates and non-PR evidence lanes | Phases 230–234 | Ratification must show direct execution separately from protected aggregate names. [VERIFIED: `ci.yml`, Phase 230–234 records] |
| Current-state Playwright ownership absent | Phase 234 machine-readable 20-spec inventory with live-seam validation | Phase 234 | Use as input, then extend to before/after all affected families. [VERIFIED: `234-PLAYWRIGHT-INVENTORY.json`] |
| CI-PERF shown as active audit | Audit completed; v1.47 phases execute its plan | 2026-07-28 planning record | Closeout reconciles the stale arc entry without re-auditing. [VERIFIED: `STATE.md`, SEED-005 addendum, `MILESTONE-ARC.md`] |

**Deprecated/outdated:** A prose/YAML-only statement that a test “runs in CI” is inadequate for this phase; a run receipt and deterministic reconciliation are required. [HIGH — CONTEXT proof discipline]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | `phase_235_terminal_ratification_contract_test.exs` is the preferred new test filename. | Code Examples / Project Structure | None functionally; planner may choose a repository-consistent alternative. |

## Open Questions

1. **Has the fixed after-window accumulated ten eligible PR runs when execution begins?**
   - What we know: FAST-01 requires at least ten and the installed CLI/instrument can collect them.
   - What's unclear: The future capture endpoint and exact count are runtime data.
   - Recommendation: Make evidence collection a checkpoint: if fewer than ten exist, commit the ledger/contract and wait/collect legitimate post-cutoff runs; do not dispatch synthetic PR runs or claim FAST-01 early.

2. **Does the measured p50 meet <12 minutes?**
   - What we know: Baseline is 27.3m p50 and the methodology is locked.
   - What's unclear: Post-change distribution.
   - Recommendation: Branch closeout text on the actual verdict; a miss must include binding-pole job receipts and an evidence-backed residual.

3. **Is timeout tightening warranted?**
   - What we know: It is discretionary but may not change evidence-window scope or become remediation.
   - Recommendation: Defer unless measured steady-state run/job data establishes a safe bounded value; otherwise record no change.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| `gh` | Live GitHub run/job measurements | ✓ | 2.95.0 | None; authenticated GitHub access is required for live receipts. |
| GitHub Actions access | PR/push/schedule outcomes | ✓ (repository integration) | managed | No local substitute for execution proof. |
| `jq` | JSON checks and metrics output | ✓ | 1.7.1 | Repository code uses it; no alternate planned. |
| Bash | Existing metrics instrument/self-test | ✓ | 5.2.37 | No alternate planned. |
| Mix / ExUnit | Deterministic contract | ✓ | Mix 1.19.5 / OTP 28 | No alternate planned. |

**Missing dependencies with no fallback:** None detected locally. GitHub API rate limiting remains an operational stop condition, not an install issue. [VERIFIED: local version probes, `AGENTS.md`]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit via Mix 1.19.5 |
| Config file | `mix.exs`, `test/test_helper.exs` |
| Quick run command | `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` |
| Full suite command | `MIX_ENV=test mix ci` plus `bash scripts/ci/ci-run-metrics.test.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| FAST-01 | Ledger locks cutoff, exact wall-mode commands, selected PR IDs/count, result, and job receipt references; calculator semantics remain hermetic. | contract + shell | `bash scripts/ci/ci-run-metrics.test.sh` and focused Phase 235 test | ❌ Wave 0 (metrics test exists) |
| GATE-05 | Single artifact covers every before/after family, consumes Phase 234 inventory, and rejects missing/stale/duplicate/unowned/non-executable/receiptless rows. | ExUnit contract | focused Phase 235 test | ❌ Wave 0 |
| FAST-01/GATE-05 | Docs and closeout use ledger-backed result and current topology names. | ExUnit contract | focused Phase 235 test | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Focused Phase 235 ExUnit contract and `bash scripts/ci/ci-run-metrics.test.sh`.
- **Per wave merge:** `MIX_ENV=test mix test test/sigra/planning/` plus JSON parse validation.
- **Phase gate:** One authorized GitHub measurement collection, one watcher per run if waiting is required, then full `MIX_ENV=test mix ci` green before verification.

### Wave 0 Gaps

- [ ] `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — validates the one ledger, source inventory consumption, all-family before/after coverage, live seam references, receipt provenance, and doc/closeout congruence.
- [ ] `235-TERMINAL-RATIFICATION.json` — machine-readable source of terminal truth with explicit schema/version/cutoff/window/rows/receipts/verdict fields.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | No application authentication change. |
| V3 Session Management | No | No session behavior change. |
| V4 Access Control | Yes | Use least-privilege existing GitHub credentials; do not print tokens or raw authenticated browser state. [VERIFIED: `ci-run-metrics.sh` security comment] |
| V5 Input Validation | Yes | Fail closed when evidence JSON, workflow seams, inventory rows, or receipt references are malformed/missing. [HIGH — CONTEXT D-05] |
| V6 Cryptography | No | No cryptographic implementation; do not hand-roll hashing/signing. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Forged or stale evidence row | Tampering | Exact run IDs/commands, immutable cutoff, live workflow/spec reconciliation, and negative contract fixtures. |
| Token or authenticated browser data retained in artifacts | Information disclosure | Keep only sanitized metadata/URLs/hashes; scripts must never echo `GH_TOKEN`. [VERIFIED: `ci-run-metrics.sh`, Phase 234 evidence pattern] |
| Rate-limit retry storm | Denial of service | One watcher, 60-second interval, one retry for transient failure, stop on 403/429. [VERIFIED: `AGENTS.md`] |

## Sources

### Primary (HIGH confidence)

- `scripts/ci/ci-run-metrics.sh` and `.test.sh` — mandatory calculation contract and hermetic semantics.
- `.github/workflows/ci.yml` — live direct owner, aggregate, harness, and event topology.
- `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json` and `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` — current inventory and fail-closed precedent.
- Phase 230–234 evidence/verification records — before-state receivers and named execution receipts.
- `CONTRIBUTING.md`, `.planning/STATE.md`, `.planning/MILESTONE-ARC.md`, SEED-005 — documentation and closeout targets.

### Secondary (MEDIUM confidence)

- [GitHub CLI `gh run list`](https://cli.github.com/manual/gh_run_list) — documented filters and run JSON fields.
- [GitHub CLI `gh run view`](https://cli.github.com/manual/gh_run_view) — documented jobs JSON field.
- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) — event/conditional behavior.
- [GitHub Actions events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) — scheduled workflow behavior and delays.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all core seams already exist and are locked by CONTEXT/codebase.
- Architecture: HIGH — direct mapping from current workflow, Phase 234 contract, and user decisions.
- Pitfalls: HIGH — explicit proof-discipline decisions plus metrics self-test; GitHub conditional semantics cited from official documentation.

**Research date:** 2026-08-02
**Valid until:** 2026-08-09 for live run-data assumptions; repository architecture remains valid until changed.
