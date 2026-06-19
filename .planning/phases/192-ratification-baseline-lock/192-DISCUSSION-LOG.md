# Phase 192: Ratification & Baseline Lock - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-18
**Phase:** 192-ratification-baseline-lock
**Mode:** assumptions (+ deep multi-subagent prior-art research per maintainer request)
**Areas analyzed:** Ledger tier policy · Baseline recapture idempotency · Full-surface axe scope ·
Generated-host parity / known-failure carve-out · Monotonic guard base ref

## Assumptions Presented

### Final Ledger Tier Policy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Lock all cells at achieved Tier 1; do NOT promote to Tier 2 | Confident | admin-quality-ledger.md (all rows T1; T2 subjective line 12); REQUIREMENTS.md:84; quality-ledger-monotonic.sh (decrease-only) |

### Deliberate-Recapture vs Already-Empty Allowlists
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Recapture is transient (populate→update→require-all→revert→reset) | Likely | snapshot-recapture-gate.sh:38,53; 191-VERIFICATION truth #9 |

### Bit-Identical Recapture Paradox
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Idempotent re-render → no git delta → `--require-all` fails by construction; compare-mode zero-drift is the real proof | Likely | admin-checkpoints.spec.ts:143-147 (maxDiffPixelRatio 0.22); ROADMAP "re-run starts from current=ratified" |

### Full-Surface Axe Scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Existing per-checkpoint full-page + per-board element-scoped A/AA satisfies "full-surface" | Likely | admin-checkpoints.spec.ts:120-122; admin-design.spec.ts:53; ledger axe evidence cols |

### RUN_PARITY + Known-Failure + Monotonic Base
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| RUN_PARITY local via admin-acceptance-smoke (PORT 4017, Postgres); 3 known failures carved out; guard vs origin/main needs fetch | Confident | admin-acceptance-smoke.sh:27,84,109,231; 191-VERIFICATION.md:108-111; ci.yml origin/base_ref |

## Deep Research (4 parallel subagents, maintainer-requested)

Maintainer requested full pros/cons/tradeoffs + ecosystem-idiomatic + lessons-from-comparable-tools
+ DX research on each area before locking. Findings (decisive, all coherent):

1. **Ledger tier** → LOCK at Tier 1. Every successful forward-only ratchet (Codecov-patch, ESLint
   suppressions, betterer, RuboCop TODO, Figma strict-migration) gates an OBJECTIVE deterministic
   quantity; none gate aesthetic judgment. A monotonic guard protects writes forever → a premature
   subjective "2" is irreversible false confidence. Idiomatic Elixir has no subjective-quality
   ratchets (only objective binary gates). Tier 2 stays a future objectively-proxied milestone.

2. **Recapture paradox** → compare-mode zero-drift (interpretation A), NOT force-recapture (B). The
   paradox dissolves: baselines are deliberately non-byte-deterministic (0.22 CI tolerance,
   macOS/Linux font split, no pinning), so `--require-all` over recaptured baselines is
   self-contradictory. Mature pattern (ApprovalTests/Chromatic/jest-`--ci`): never force-rewrite at
   a lock. Five-clause invariant proof defined. Byte-reproducibility would need Docker/font parity
   → backlog.

3. **Axe scope** → current A/AA architecture is correct (GOV.UK/Storybook component-vs-page split;
   `region` exclusion standard); ONE cheap widening to WCAG 2.1/2.2 AA (+5 rules) makes
   "full-surface" honestly defensible (the modern legal floor). Don't gate `best-practice`; don't
   crawl live routes; hover/focus/motion stay in interaction lanes.

4. **Parity + known failures + base ref** → proof-by-CI pinned to head SHA (mature generators split
   fast text-goldens local / slow scaffold-boot CI; Sigra history shows CI catches generated-host
   drift). Known failures → executable quarantine (greppable `known_failure` tag + non-blocking
   reported lane + self-healing "exactly-3-still-red" contract test — pytest strict-xfail /
   Google-Spotify model), not silent exclude. Monotonic: `git fetch origin main && --base
   origin/main` (default `--base HEAD` is self-referential; fetch mandatory).

## Corrections / Decisions Made

The maintainer confirmed all three recommended levers (the only ones with real scope tradeoffs):

### Full-surface axe scope
- **Original assumption:** Existing A/AA scope already satisfies "full-surface" (no change).
- **Maintainer decision:** **Widen to WCAG 2.1/2.2 AA now** (+5 rules) to make the gate literally
  defensible, accepting the small risk of new findings (likely `target-size` on dense controls →
  documented per-rule suppression if the contract accepts the density). → D-07/D-08.

### Known pre-existing failures
- **Original assumption:** Carve out the 3 as non-regressions.
- **Maintainer decision:** **Executable quarantine** — greppable `known_failure` tags + reason/
  tracking links + non-blocking reported lane + self-healing contract test asserting "exactly 3,
  still red"; create the 2 missing installer todos. Not lightweight prose/exclude. → D-11/D-12.

### GATE-01 interpretation
- **Original assumption:** Transient force-recapture honors the literal wording.
- **Maintainer decision:** **Reinterpret as zero-drift idempotency proof** (compare-mode, no
  `--require-all`, no PNG churn; allowlists already empty = the locked steady state). Update the
  GATE-01 phrasing in REQUIREMENTS.md to remove the self-contradiction. → D-03/D-04/D-05.

## External Research

No web/library external research needed — all findings sourced from internal scripts, specs, CI
config, prior-phase artifacts, and the four prior-art research subagents (which drew on documented
industry tools/precedents). The only residual empirical unknown (byte-identical vs sub-threshold
PNGs) is settled by D-06: baselines are non-byte-deterministic by design, so compare-mode
zero-drift is the correct proof and byte-reproducibility is backlogged.
