# Phase 235: Terminal Ratification — Measured, Not Read - Context

**Gathered:** 2026-08-02 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the v1.47 CI-EFFICIENCY milestone's terminal claims from real run data, publish one before/after coverage ownership artifact, reconcile contributor documentation with the shipped topology, and close the SEED-005 / CI-PERF planning record. This phase implements FAST-01 and GATE-05 only. It re-measures the completed Phases 230–234 work; it does not re-run the audit, add new gates, delete tests for speed, or start unrelated remediation.
</domain>

<decisions>
## Implementation Decisions

### Measurement window and FAST-01 verdict

- **D-01:** Use `scripts/ci/ci-run-metrics.sh` in its default `wall` mode for the terminal after-window. Declare an immutable post-change cutoff tied to the last topology-changing milestone commit, record the capture endpoint, and include at least 10 `pull_request` runs after that cutoff. Use the same bounded time window when recording push-to-`main` and scheduled outcomes.
- **D-02:** Preserve the instrument's baseline-compatible semantics: queue-inclusive `updatedAt - createdAt`, sorted `floor(n/2)` p50, and all conclusions retained. Do not substitute job-span timing, successful runs only, hand arithmetic, or a rolling window that admits pre-change runs.
- **D-03:** Every measured claim must cite the exact command and real run IDs from which it was derived. Report the observed p50 even when it is at or above 12 minutes. If FAST-01 misses, record the measured number and identify the binding pole from run/job data; do not restate the target as achieved by intent.

### Before/after coverage ratification

- **D-04:** Produce one committed terminal before/after ownership artifact for GATE-05. It must map every affected spec or suite to its PR, push-to-`main`, and nightly ownership before and after Phases 230–234, including Playwright specs, design snapshots/axe coverage, `admin_eval_render`, library/scaffold/golden suites, and terminal aggregates. A current-state-only or Playwright-only list is insufficient.
- **D-05:** Consume `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json` as the mechanically verified current Playwright input rather than copying or replacing its ownership model. Extend fail-closed validation to reject missing, stale, duplicate, unowned, or non-executable before/after rows. Each moved row must name its receiver and cite the phase evidence or real lane receipt that proves execution.

### Contributor topology

- **D-06:** Keep `MIX_ENV=test mix ci` as the contributor-facing local parity path. Update `CONTRIBUTING.md` so its CI overview distinguishes direct shard/harness owners from byte-stable terminal required aggregates, explains the supported Playwright reproduction seam, and identifies signals intentionally limited to non-PR events. Documentation must match the live workflow rather than preserving the pre-reshape topology.

### Honest closeout

- **D-07:** Reconcile SEED-005 and the `CI-PERF` milestone-arc entry as an already-completed audit executed through Phases 230–235. Do not re-audit. Close as delivered only to the extent supported by terminal measurements; if the performance target misses or another residual remains, file or preserve an evidence-backed residual and link it from the closeout.
- **D-08:** Fold no pending todos into Phase 235. Earlier-phase CI todos, stale residual notes, and unrelated product/release/UI items remain outside the fixed FAST-01/GATE-05 boundary.

### the agent's Discretion

- Exact filename and JSON/Markdown representation of the single GATE-05 artifact, provided it is one committed artifact with deterministic reconciliation coverage.
- Exact contract-test/helper names and table layout, following the existing Phase 230 measurement and Phase 234 inventory patterns.
- Exact wording and organization of `CONTRIBUTING.md`, provided the topology and reproduction claims are mechanically checkable against the live workflow.
- Whether a post-measurement timeout tightening is warranted. Any change must be sized from the measured steady state and must not truncate the evidence window or expand this phase into performance remediation.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 235 boundary, success criteria, proof discipline, and explicit out-of-scope list.
- `.planning/REQUIREMENTS.md` — FAST-01/GATE-05 text and the authoritative 29.5m mean / 27.3m p50 / 41.7m max baseline.
- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` — completed audit and original coverage/performance findings.
- `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` — verbatim scope guardrails and the Phase 230–235 execution sequence.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` — measurement contract, demotions, timeout boundary, and no-silent-drop decisions.
- `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md` — honest-skip, named-run proof, nightly, and non-PR signal decisions.
- `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-CONTEXT.md` — isolated Playwright shard ownership and terminal aggregate contract.
- `.planning/phases/233-library-suite-economics/233-CONTEXT.md` — library/scaffold/golden ownership and required aggregate contract.
- `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-CONTEXT.md` — `mix ci` and Phase 235 inventory-input decisions.
- `scripts/ci/ci-run-metrics.sh` and `scripts/ci/ci-run-metrics.test.sh` — mandatory baseline-compatible measurement instrument and hermetic contract.
- `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json` — mechanically checked current Playwright ownership input.
- `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` — fail-closed inventory reconciliation precedent.
- `.github/workflows/ci.yml` — live event, shard, harness, and aggregate topology.
- `CONTRIBUTING.md` — contributor-facing topology to reconcile.
- `.planning/MILESTONE-ARC.md` — stale `CI-PERF` active entry to close against the executed phase sequence.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `scripts/ci/ci-run-metrics.sh` already emits the exact baseline table shape and supports an explicit `--since` cutoff, event filtering, JSON output, and per-run job breakdowns; its self-test is already part of the repository's CI guard posture.
- `234-PLAYWRIGHT-INVENTORY.json` contains 20 sorted live spec rows, exact job/seam/event ownership, and a `phase_235_gate_input` marker.
- `phase_234_playwright_inventory_contract_test.exs` already reconciles live specs to workflow jobs, command markers, config seams, and the two approved harness indirections.
- Phase 230–234 evidence and verification artifacts contain the historical before state, moved receivers, run IDs, and exact commands needed to build the terminal comparison without re-auditing.

### Established Patterns

- Behavioral CI claims close on a named run ID plus a committed command; YAML reads are wiring evidence only.
- Machine-readable evidence fails closed under missing, stale, duplicate, partial, or non-executable ownership.
- Direct owners may be sharded or event-gated while protected check names remain byte-stable terminal aggregates.
- Retries and `continue-on-error` are not accepted as ways to conceal flake or manufacture a performance pass.
- The active methodology favors decisive repo-consistent defaults and escalates only choices that change proof or operator truth.

### Integration Points

- Measurement reads GitHub Actions metadata through the existing `gh`-backed metrics instrument and writes terminal evidence under the Phase 235 directory.
- Coverage ratification joins the Phase 234 Playwright inventory with Phase 230–233 demotion and suite-ownership evidence, then validates the result against `.github/workflows/ci.yml` and live spec paths.
- Contributor documentation derives its topology from the same workflow job/seam/aggregate names used by the inventory and evidence contracts.
- Closeout updates SEED-005 status and `.planning/MILESTONE-ARC.md` only after the measurement and inventory truth are known.
</code_context>

<specifics>
## Specific Ideas

- The terminal artifact is a before/after ownership map, not a fresh audit report.
- Use one declared post-change time window for PR, main, and nightly comparisons so the three outcome tables cannot drift onto different observation periods.
- Preserve the distinction between direct execution owner and terminal required check; a green aggregate alone is not proof that a named suite executed.
- An above-target p50 is an acceptable honest result for the phase, but not a FAST-01 pass.
</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)

- Earlier-phase performance and gate-honesty todos (`playwright-parallelization-per-shard-db`, `admin_eval_render`, generated-host parity, release-gate timeout/notifier) remain assigned to or delivered by Phases 231–232; reconcile their todo status separately rather than reimplementing them here.
- Phase 234 evidence residual notes are stale against its completed verification and do not replace Phase 235's fresh terminal measurement window.
- Release, auth UI, admin UI, installer, security, and GitHub Pages matches are keyword-adjacent new capabilities or defects outside FAST-01/GATE-05.
- Transient dependency-download retry work remains excluded by the milestone's no-flake-masking guardrail.
</deferred>
