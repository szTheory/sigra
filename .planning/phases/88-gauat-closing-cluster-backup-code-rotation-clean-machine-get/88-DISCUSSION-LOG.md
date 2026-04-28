# Phase 88: GAUAT closing cluster — backup-code rotation + clean-machine getting-started + results filing & SEED-001 closure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 88-gauat-closing-cluster-backup-code-rotation-clean-machine-get
**Areas discussed:** Backup-code evidence shape, Clean-machine run standard, Go/no-go and seed-closure policy, Results-file structure

---

## Backup-code evidence shape

| Option | Description | Selected |
|--------|-------------|----------|
| Screenshot-heavy human proof pack | Strong visual proof of the flow, but weak on invalidation and audit semantics | |
| Transcript/query-heavy proof pack | Strongest security truth, but undersells the human-visible flow | |
| Hybrid proof pack | Small screenshot set plus canonical transcript/query proof | ✓ |

**User's choice:** Delegate and synthesize the strongest recommendation.
**Notes:** Chosen recommendation is the hybrid pack, biased toward transcript/query truth. Screenshots prove the flow happened; state/audit artifacts prove the security claim.

---

## Clean-machine run standard

| Option | Description | Selected |
|--------|-------------|----------|
| Pristine VM + naive operator + full recording | Strong independence signal, but heavy and theatrical for this ecosystem | |
| Maintainer-run fresh host + transcript + friction log | Cheap and practical, but weaker if used without any automated floor | |
| Automated doc contract only | Good CI hygiene, but too weak for real first-run confidence | |
| Hybrid protocol | Automated contract plus one bounded human fresh-run | ✓ |

**User's choice:** Delegate and synthesize the strongest recommendation.
**Notes:** Chosen recommendation keeps the contract script as baseline and adds one honest fresh-run by a competent Phoenix developer new to Sigra.

---

## Go/no-go and seed-closure policy

| Option | Description | Selected |
|--------|-------------|----------|
| Strict closure only with full remote/dated evidence | Strongest launch-truth posture | |
| Allow local-green temporarily | Fine for execution, too weak for launch truth | |
| Partial validation with explicit reopen triggers | Practical fallback when non-critical rows lag | ✓ |
| Binary any-gap blocks everything | Safest externally, but can over-block low-value laggards | |

**User's choice:** Delegate and synthesize the strongest recommendation.
**Notes:** Chosen package is strict evidence for `validated`, practical fallback for `partially-validated`, and explicit rejection of local-only green as launch truth.

---

## Results-file structure

| Option | Description | Selected |
|--------|-------------|----------|
| Full v1.4 matrix mirror | Familiar, but duplicates too much and invites drift | |
| Compact signoff index | Concise, auditable, and aligned with existing v1.20 evidence split | ✓ |
| Narrative summary only | Readable, but too weak for row-level auditability | |
| Manifest-first top-level index | Strong provenance, wrong primary surface for human signoff | |

**User's choice:** Delegate and synthesize the strongest recommendation.
**Notes:** Chosen recommendation is a compact top-level result file with one row per `GAUAT-01..08`, explicit final disposition, and links into detailed evidence bundles.

---

## the agent's Discretion

- The exact artifact filenames inside the future `GAUAT-07` and `GAUAT-08` evidence directories
- Whether to use one or two evidence links per row in `.planning/v1.20-GA-UAT-RESULTS.md`
- Whether the `GAUAT-08` witness transcript gets a separate summary README

## Deferred Ideas

- Full Playwright + DB proof automation for backup-code regeneration
- Heavier onboarding-study artifacts beyond the bounded Phase 88 witness protocol
