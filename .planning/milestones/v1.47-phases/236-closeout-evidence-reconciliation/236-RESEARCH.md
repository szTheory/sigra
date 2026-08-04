# Phase 236: Closeout Evidence Reconciliation - Research

**Researched:** 2026-08-04
**Domain:** deterministic milestone-evidence reconciliation and Nyquist lifecycle closeout
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Audit-gap reconciliation
- **D-01:** Repair only the four missing SUMMARY completion declarations identified by the v1.47 audit: `GATE-01`, `GATE-04`, `TEST-02`, and `TEST-03`. Add each ID to the appropriate existing phase SUMMARY frontmatter; do not rewrite historical execution narratives or treat the metadata repair as a new runtime proof claim.
- **D-02:** Reconcile `REQUIREMENTS.md` traceability statuses for `TEST-01..03` and `DX-01..04/DX-06` against their checked requirement rows, completed phase verifications, and existing deterministic contracts. Completion must remain supported by all audit sources; a checkbox alone is never sufficient.

### Validation lifecycle
- **D-03:** Run the established deterministic Nyquist validation workflow for Phases 230, 231, 232, and 234 and update their existing validation artifacts to the workflow's canonical `validated` lifecycle state only when the automated validation evidence passes. Do not create substitute approval prose or waive a failed validation.
- **D-04:** Preserve Phase 233 and Phase 235 as already Nyquist-compliant. Preserve all completed Phase 230–235 verification artifacts and protected receipts byte-for-byte except where a validator's canonical lifecycle update explicitly requires an artifact change.

### Honest terminal closeout
- **D-05:** Re-run the v1.47 milestone audit after reconciliation. Mark the milestone ready to close only if the audit reports all requirements satisfied and the Nyquist classification is compliant; otherwise retain the audit's exact remaining diagnostics and stop rather than relabeling them passed.
- **D-06:** Keep operational/debt items separate from the evidence-closeout gate: Phase 231 Pages-source repository administration, Phase 232 edge-semantics assumptions, Phase 233 `Code.require_file/1` warnings, and Phase 235's non-authoritative historical verifier are recorded debt, not acceptance blockers unless the renewed audit proves otherwise.

### the agent's Discretion
- Choose the smallest set of existing SUMMARY files that truthfully provides each missing requirement declaration, following the repository's current frontmatter shape.
- Choose the validation and audit command order, provided evidence is deterministic, phase-scoped, and the final milestone audit is fresh.

### Deferred Ideas (OUT OF SCOPE)
- `.planning/todos/pending/2026-08-01-phase-234-github-evidence-residual.md` and `.planning/todos/pending/2026-08-01-phase-234-pr-evidence-blocked.md` — resolved Phase 234 diagnostic history, not Phase 236 implementation scope.
- `2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — a required-check/DAG policy change explicitly deferred by Phase 231.
- `2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` — one-off network reliability work; no retry policy is introduced in this closeout phase.
- The Phase 231, 232, 233, and 235 tech-debt items named in the milestone audit remain separately tracked unless the renewed audit changes their status.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM system, Rail Accent assets, and Light/Dark/System modes for admin UI work; this documentation-only phase must not touch those surfaces. [VERIFIED: AGENTS.md]
- Keep any Playwright/admin UI work deterministic: role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: AGENTS.md]
- Replace human/UAT claims with deterministic tests, automation, CI polling, and machine-readable evidence; do not waive missing evidence. [VERIFIED: AGENTS.md]
- If GitHub CI is watched, use one watcher with a 60-second interval; check API rate-limit headroom first and stop on 403/429. [VERIFIED: AGENTS.md]

## Summary

Phase 236 is an evidence-closeout operation, not a CI or product implementation phase. The authoritative audit reports 20/24 requirements satisfied solely because four independently verified requirements lack matching `requirements-completed` SUMMARY frontmatter, and it reports four noncanonical Nyquist artifacts. Its closure path is exactly: repair four declarations, reconcile eight stale traceability statuses, run canonical validation for the four affected phases, then produce a fresh milestone audit. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md]

Use the existing evidence as the authority. The audit already confirms all six phase verifications, eight cross-phase integration checks, and seven end-to-end flows; Phase 236 must neither recapture runtime evidence nor overwrite retained receipts. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md]

**Primary recommendation:** Plan three sequential checkpoints: truthful SUMMARY/traceability reconciliation, canonical validator runs for 230/231/232/234, then a fresh audit whose result is the sole milestone-closeout verdict. [VERIFIED: 236-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Requirement completion declarations | Repository planning metadata | Audit workflow | SUMMARY frontmatter is the audit's required third source. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |
| Traceability reconciliation | Repository planning metadata | Existing phase VERIFICATION/contracts | Rows must agree with checked requirements, verification, and deterministic contracts. [VERIFIED: 236-CONTEXT.md] |
| Nyquist lifecycle transition | GSD validation workflow | Existing VALIDATION artifacts | The workflow owns the canonical `status: validated` transition. [VERIFIED: /Users/jon/.codex/gsd-core/workflows/validate-phase.md] |
| Milestone closeout verdict | GSD milestone-audit workflow | Requirement, validation, and verification artifacts | The renewed audit determines whether all requirements and Nyquist coverage are compliant. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---|---:|---|---|
| GSD `$gsd-validate-phase` | repository-installed workflow | Audits completed phase validation coverage and updates existing VALIDATION state. [VERIFIED: /Users/jon/.codex/gsd-core/workflows/validate-phase.md] | It is the active post-verification Nyquist hook. [VERIFIED: `gsd-tools loop render-hooks verify:post`] |
| GSD `$gsd-audit-milestone` | repository-installed workflow | Recomputes requirement, integration, flow, and Nyquist closeout results. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] | The audit itself prescribes this as the final closure step. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |
| YAML frontmatter + Markdown planning artifacts | existing repository format | Stores completion declarations, traceability, and validation lifecycle state. [VERIFIED: phase 231/233 SUMMARY and 230–235 VALIDATION artifacts] | Existing artifacts are the audit's data source. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---|---:|---|---|
| ExUnit / `mix test` | repository existing | Runs deterministic planning contracts before lifecycle mutation. [VERIFIED: 234-VALIDATION.md] | Validator-selected or focused contracts only; do not replace validation with prose. [VERIFIED: 236-CONTEXT.md] |
| GitHub CLI (`gh`) | 2.95.0 installed | Supports deterministic, bounded service evidence when a validator requires it. [VERIFIED: local `gh --version`] | Only through the existing validator/audit workflow and AGENTS.md polling constraints. [VERIFIED: AGENTS.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Canonical GSD validator | Hand-editing `status` / approval prose | Invalid: the lifecycle must transition only after automated validation passes. [VERIFIED: 236-CONTEXT.md] |
| Fresh milestone audit | Manual “ready” declaration | Invalid: the exact renewed audit diagnostics determine closeout. [VERIFIED: 236-CONTEXT.md] |

**Installation:** None. This phase installs no external package. [VERIFIED: 236-CONTEXT.md]

## Architecture Patterns

### System Architecture Diagram

```text
Existing SUMMARY + REQUIREMENTS + VERIFICATION/contracts
                 │
                 ▼
     narrow metadata reconciliation
                 │
                 ▼
 validate-phase 230 / 231 / 232 / 234 ──failed──> retain diagnostics; stop
                 │ passed
                 ▼
      VALIDATION.md status: validated
                 │
                 ▼
           audit-milestone v1.47 ──gaps──> retain exact diagnostics; stop
                 │ compliant
                 ▼
         milestone ready-to-close verdict
```

### Recommended Project Structure

```text
.planning/
├── REQUIREMENTS.md                              # checked requirement text and traceability rows
├── v1.47-v1.47-MILESTONE-AUDIT.md              # regenerated authoritative closeout result
└── phases/
    ├── 231-gate-honesty-nightly-revival/       # GATE SUMMARY declaration + validation
    ├── 233-library-suite-economics/            # TEST SUMMARY declaration
    ├── 230-tier-1-critical-path-reclamation/   # validation lifecycle only
    ├── 232-playwright-economics-authenticate-once-then-shard/ # validation lifecycle only
    └── 234-hygiene-supply-chain-and-contributor-dx/ # traceability + validation
```

### Pattern 1: Smallest truthful completion declaration

**What:** Add each missing ID once, to the existing SUMMARY whose scope and verification already cover that requirement; preserve its narrative and receipt references. [VERIFIED: 236-CONTEXT.md]

**Use:** `GATE-01` belongs in `231-11-SUMMARY.md`, the existing Phase 231 closure SUMMARY that owns its final observation; the later accepted schedule receipt is independently recorded by `231-VERIFICATION.md`. `GATE-04` belongs in `231-06-SUMMARY.md`, whose coverage and receipts establish the hard-signal lane. `TEST-02` and `TEST-03` belong in `233-05-SUMMARY.md`, which records balanced shard times and scaffold receiver coverage. [VERIFIED: 231-11-SUMMARY.md; 231-06-SUMMARY.md; 231-VERIFICATION.md; 233-05-SUMMARY.md; 233-VERIFICATION.md]

```yaml
# Source: existing SUMMARY frontmatter convention
requirements-completed: [GATE-04]
```

### Pattern 2: Validator-owned lifecycle change

**What:** Invoke the validator rather than normalizing frontmatter by hand. For an existing VALIDATION artifact, the workflow updates its task coverage, appends an audit trail, and sets `status: validated`; its compliant path requires automated coverage. [VERIFIED: /Users/jon/.codex/gsd-core/workflows/validate-phase.md]

```bash
$gsd-validate-phase 231
```

### Anti-Patterns to Avoid

- **Recapturing runtime evidence:** The phase must cite existing passing runtime, integration, flow, and terminal results, not manufacture a new proof population. [VERIFIED: 236-CONTEXT.md]
- **Broad historical cleanup:** Do not rewrite execution narratives, verification reports, or protected receipts merely to make the bookkeeping uniform. [VERIFIED: 236-CONTEXT.md]
- **Optimistic lifecycle edit:** Do not change `draft`, `ready`, or `complete` to `validated` except through successful canonical validation. [VERIFIED: 236-CONTEXT.md]
- **Conflating debt with a failed requirement:** Retain the four named debt items unless the renewed audit itself changes their classification. [VERIFIED: 236-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Nyquist audit | Custom status scanner or approval prose | `$gsd-validate-phase` | It owns canonical lifecycle mutation and validates task coverage. [VERIFIED: /Users/jon/.codex/gsd-core/workflows/validate-phase.md] |
| Milestone closeout | One-off requirements checklist | `$gsd-audit-milestone` | It applies the project’s three-source and Nyquist classification rules. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |
| CI evidence reproduction | New CI run collection script | Existing retained receipts/contracts | New evidence is explicitly out of scope and can alter the acceptance population. [VERIFIED: 236-CONTEXT.md] |

**Key insight:** Phase 236’s correctness is provenance preservation: existing proof plus minimal metadata makes the audit discoverable; extra “proof” is scope expansion. [VERIFIED: 236-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Declaring from a checkbox alone

**What goes wrong:** A checked REQUIREMENTS row can mask a missing SUMMARY source, leaving the audit partial. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md]

**How to avoid:** Before each declaration, cross-check the requirement row, the completed phase VERIFICATION verdict, and the scoped SUMMARY. [VERIFIED: 236-CONTEXT.md]

### Pitfall 2: Marking validation compliant before the validator passes

**What goes wrong:** The audit treats noncanonical `draft`, `ready`, and `complete` states as NOT-VALIDATED even when `nyquist_compliant: true`. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md]

**How to avoid:** Run the workflow for 230, 231, 232, and 234; if it fails, retain the precise artifact diagnostics rather than mutating them. [VERIFIED: 236-CONTEXT.md]

### Pitfall 3: Falsifying terminal evidence history

**What goes wrong:** Replacing historical FAST-01 misses or protected receipts would corrupt the provenance the milestone relies on. [VERIFIED: 236-CONTEXT.md]

**How to avoid:** Treat all 230–235 VERIFICATION artifacts and protected receipts as byte-preserved inputs, except canonical validator-owned changes. [VERIFIED: 236-CONTEXT.md]

## Code Examples

### Deterministic closeout sequence

```bash
# 1. Run focused metadata/traceability contract(s), then reconcile only approved rows.
# 2. Run each validator; it owns status: validated transitions.
$gsd-validate-phase 230
$gsd-validate-phase 231
$gsd-validate-phase 232
$gsd-validate-phase 234

# 3. Only after all validators pass, regenerate the milestone verdict.
$gsd-audit-milestone v1.47
```

Source: [VERIFIED: 236-CONTEXT.md; .planning/v1.47-v1.47-MILESTONE-AUDIT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Presence of a VALIDATION artifact or a truthy compliance field | Canonical `status: validated` plus compliant coverage | Current audit contract | Lifecycle state is part of acceptance, not decorative metadata. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |
| Local requirement checkbox | Three-source requirement completion | Current v1.47 audit | SUMMARY declaration and independent verification are both required. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |

## Assumptions Log

All findings are derived from current repository artifacts and installed GSD workflow sources; no assumed implementation claim is needed.

## Open Questions

None. Exact ownership is established: `231-11-SUMMARY.md` → GATE-01, `231-06-SUMMARY.md` → GATE-04, and `233-05-SUMMARY.md` → TEST-02/TEST-03. The plan should include a read-first assertion against the corresponding VERIFICATION report before each metadata mutation. [VERIFIED: 231-11-SUMMARY.md; 231-06-SUMMARY.md; 233-05-SUMMARY.md; 231-VERIFICATION.md; 233-VERIFICATION.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir / Mix | deterministic planning contracts | ✓ | Erlang/OTP 28 runtime reported | none — required for validator-selected tests. [VERIFIED: local runtime probe] |
| GitHub CLI | validator/audit service evidence if invoked | ✓ | 2.95.0 | retain existing receipts only when no new service query is required. [VERIFIED: local `gh --version`] |
| GSD validation/audit workflows | lifecycle and closeout | ✓ | repository-installed | none — canonical workflow is mandatory. [VERIFIED: installed GSD workflow files] |

**Missing dependencies with no fallback:** None identified. [VERIFIED: local runtime probe]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (existing repository) [VERIFIED: 234-VALIDATION.md] |
| Config file | `mix.exs` [VERIFIED: 234-VALIDATION.md] |
| Quick run command | validator-selected focused planning contract(s), plus `mix test test/sigra/planning/` when required by the validator [VERIFIED: 234-VALIDATION.md] |
| Full suite command | `mix ci` [VERIFIED: 234-VALIDATION.md] |

### Phase Behaviors → Test Map

| Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|
| Four completion IDs remain limited to verified requirements | metadata reconciliation | focused planning contract or deterministic frontmatter assertion created in Wave 0 | ❌ Wave 0 |
| Traceability statuses agree with requirement checkboxes, verification reports, and existing contracts | metadata reconciliation | focused planning contract or deterministic table assertion created in Wave 0 | ❌ Wave 0 |
| 230/231/232/234 reach canonical validation lifecycle only after coverage passes | workflow audit | `$gsd-validate-phase <phase>` | ✅ existing VALIDATION artifacts |
| Milestone is labeled ready only from a clean fresh audit | end-to-end audit | `$gsd-audit-milestone v1.47` | ✅ existing audit workflow/artifact |

### Sampling Rate

- **Per metadata task commit:** focused contract/frontmatter assertion.
- **Per lifecycle checkpoint:** the one phase-scoped validator invocation.
- **Phase gate:** fresh v1.47 milestone audit must report all requirements satisfied and Nyquist compliant.

### Wave 0 Gaps

- [ ] Add a narrow deterministic contract/command that rejects wrong SUMMARY ownership, extra completion IDs, unbacked traceability “Complete” rows, and protected-receipt edits before metadata is changed.
- [ ] Do not add new runtime/CI evidence collection tests; those are out of Phase 236 scope. [VERIFIED: 236-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | No authentication surface changes. [VERIFIED: 236-CONTEXT.md] |
| V3 Session Management | no | No session surface changes. [VERIFIED: 236-CONTEXT.md] |
| V4 Access Control | no | No access-control surface changes. [VERIFIED: 236-CONTEXT.md] |
| V5 Input Validation | yes | Deterministic validation/audit commands reject incomplete or noncanonical evidence state. [VERIFIED: /Users/jon/.codex/gsd-core/workflows/validate-phase.md] |
| V6 Cryptography | yes | Preserve protected receipt bytes and existing attestation verification; do not reimplement cryptographic checks. [VERIFIED: 236-CONTEXT.md] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Evidence tampering by narrative rewrite | Tampering | Minimal frontmatter/table edits; preserve verification artifacts and protected receipts. [VERIFIED: 236-CONTEXT.md] |
| False closeout from stale metadata | Tampering | Three-source reconciliation, canonical lifecycle validation, then fresh audit. [VERIFIED: .planning/v1.47-v1.47-MILESTONE-AUDIT.md] |
| CI/API rate-limit churn | Denial of service | Single 60-second watcher, rate-limit check, and hard stop on 403/429. [VERIFIED: AGENTS.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/v1.47-v1.47-MILESTONE-AUDIT.md` — authoritative gaps, three-source rule, Nyquist state, and closure path.
- `.planning/phases/236-closeout-evidence-reconciliation/236-CONTEXT.md` — locked scope and preservation constraints.
- `/Users/jon/.codex/gsd-core/workflows/validate-phase.md` — canonical lifecycle behavior.
- Existing 230–235 SUMMARY, VALIDATION, and VERIFICATION artifacts — repository conventions and current state.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — canonical installed workflow and repository artifacts were inspected.
- Architecture: HIGH — the audit supplies an explicit closure path and source-of-truth hierarchy.
- Pitfalls: HIGH — each is an active audited gap or locked preservation constraint.

**Research date:** 2026-08-04
**Valid until:** 2026-08-11 (closeout artifact state is actively changing).
