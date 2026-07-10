# Phase 216: Harness Foundation + Award Gradient - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in 216-CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-03
**Phase:** 216-harness-foundation-award-gradient
**Mode:** assumptions + deep research (operator requested per-area deep research before locking)
**Areas analyzed:** Harness runtime/home · Evidence bundle format/location · Stale-render & evidence-integrity guards · Deterministic probe engine · Award sub-score gradient + findings-monotonic guard · Two pilot surfaces

## Assumptions Presented (initial codebase analysis)

### Harness runtime & home
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Playwright spec + thin bash orchestrator under scripts/ci/; not a mix task, not a node CLI | Confident | admin-design.spec.ts, snapshot-recapture-gate.sh, @axe-core/playwright, /admin/_design gallery already renders the matrix |

### Evidence bundle format & location
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One JSON+PNG per (surface×theme×viewport×state), gitignored; commit only derived findings/ledger; render_sha256 over DOM+sorted computed-style | Likely | admin-artifact-bundle-contract.sh ephemeral tree; test-results/ + playwright-report/ already gitignored |

### Stale-render + evidence-integrity guards
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Bash + git plumbing (not mtime); anchor-presence over captured DOM | Likely | quality-ledger-monotonic.sh --base, snapshot-canary-guard.sh --base HEAD |

### Deterministic probe engine
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| In-browser page.evaluate; off-token defined vs --sg-* read live from :root | Likely | existing computed-style checks in admin-design.spec.ts; card-in-card + target-size prototyped |

### Award sub-score ledger + findings-monotonic guard
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Extend ledger doc with a sub-score; separate findings guard; fast_checks lane | Likely | quality-ledger-monotonic.sh awk -F'|' requires bare [012]; ci.yml fast_checks |

### Two pilot surfaces
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| users-index-live + user-show-live | Likely | admin-quality-ledger.md lines 87–88 (richest Tier-2 evidence; table-equiv + modal) |

## Corrections Made

No assumptions were reversed. The operator did not correct any assumption — instead requested **deeper
per-area research** (pros/cons/tradeoffs, ecosystem idiom, lessons from comparable tools, DX/UX lenses,
leveraging the `prompts/` corpus + current brandbook) before locking. Four parallel research agents ran;
findings **hardened and sharpened** the assumptions and reconciled one divergence. Net changes vs the
initial assumptions:

### Firmed to Confident
- **Harness runtime (D-01/02):** confirmed Playwright+bash; the mix-task path explicitly rejected because
  its only value (Ecto Sandbox reuse) is moot for a static gallery.
- **Stale-render guard (D-07/08):** confirmed git-plumbing (mtime is broken in CI — actions/checkout#468);
  **absence of bundles = FAIL not skip** (new precision).

### Sharpened
- **render_sha256 (D-06):** must hash a **canonicalized DOM allowlist** (strip csrf/data-phx-*/nonce/vsn,
  sort attrs) — raw outerHTML would churn the SHA every render and defeat the gate. New, load-bearing.
- **Probe focus-ring (D-13):** decisive correction from reading sigra_admin.css:449 — focus is
  `box-shadow` with `outline:none`; probe must diff box-shadow, NOT outline (outline check false-positives
  on every button).
- **Gate/warn split (D-15):** explicit split + geometry probes hard-gate only in -chromium DPR1.
- **Reuse (D-14):** axe-core target-size rule + existing card-in-card check + existing data-sg-*-audit-only
  suppression convention.

### Reconciled divergence (operator-locked "as-is")
- **Award representation (D-19):** research agents split — one recommended a new markdown ledger column
  (extend the tier guard), the other a sibling `admin-award-ledger.json`. **Locked toward JSON**, because
  it keeps the fragile awk column-4 grammar frozen AND is the only representation where a guard can
  enforce verify-then-climb (band==min(axes), evidence_ref resolvability, verified_at_sha freshness).
- **Award shape (D-17/18):** A0→A3 ordinal band (not 0–100), decomposed into a fixed 4-axis vector,
  rolled up by **min() floor rule** (anti-gaming) — grounded in Awwwards/Lighthouse/CMMI/DORA/Nielsen
  precedent + the persona rubric's existing worst-verdict rule.

### New in-scope decision surfaced by research
- **CI base-ref merge-base fix (D-10):** the shared `id: base` step resolves origin/main **tip**, not
  merge-base — false-fails a down-ratchet when main moves ahead. One-line fix folded into this phase
  (operator-approved), foundational to the new findings-count down-ratchet.

## Auto-Resolved

Not applicable (interactive, not --auto).

## External Research

Four parallel general-purpose research agents + one prior architecture-research agent:

1. **Headless-DOM vs live-browser + axe determinism** — cheerio resolves anchor checks browser-free;
   jsdom has no layout so geometry probes MUST be captured in-browser; axe count guard must count distinct
   `rule-id × target` from `violations` only (drop `incomplete`), per matrix cell, pinned version, never
   diff dark-vs-light (color-contrast inflation). Sources: jsdom/cheerio docs, axe-core API.md, issues
   #2088/#3513.
2. **Harness & artifact architecture** — Playwright test-runner + Storybook test-runner artifact model;
   Chromatic/Percy/reg-suit commit nothing, BackstopJS/loki suffer committed-blob churn; canonicalize DOM
   before hashing. Sources: playwright.dev, reg-viz, browserstack Percy docs.
3. **Forward-only ratchet patterns** — betterer (stable-hash lesson, merge-conflict cautionary tale),
   ESLint bulk-suppressions (count-based → low conflict), SonarQube new-code reference-branch,
   type-coverage; merge-base vs tip correctness. Sources: eslint.org blog 2025-04, betterer docs,
   SonarSource docs, git-scm merge-base, actions/checkout#468.
4. **Design-system conformance probes** — runtime-read :root token scale, rem→px ±0.5px, longhands not
   shorthand, box-shadow focus-ring, reuse axe target-size (WCAG 2.2), gate/warn split. Sources: WCAG
   2.5.8 / 2.4.13, axe-core issues #4295/#4805, stylelint-declaration-strict-value, Style Dictionary,
   EightShapes typography.
5. **Award-gradient information design + pilots** — A0→A3 ordinal band + 4-axis min()-floor vector +
   JSON representation + verify-then-climb; users-index + user-show pilots (widest probe span, richest
   re-verifiable Tier-2 claims; user-show modal-ownership re-verify). Sources: Awwwards evaluation,
   Lighthouse scoring, CMMI/DORA/Nielsen.
</content>
