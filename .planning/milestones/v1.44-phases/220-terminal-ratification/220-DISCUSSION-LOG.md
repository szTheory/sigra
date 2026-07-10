# Phase 220: Terminal Ratification - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-09
**Phase:** 220-terminal-ratification
**Mode:** assumptions (+ user-requested deep multi-lens research via subagents)
**Areas analyzed:** Award ledger lock (SC-1), Harness runbook (SC-2), Canary-merge reconciliation
(SC-3), cheerio fast_checks break (SC-4), Milestone-ship PR mechanics (Area 5)

## Assumptions Presented (initial analyzer pass)

### Award ledger lock (SC-1)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No net-new guard work; verify-then-confirm (guards already wired) | Likely | `award-guard.mjs`, `quality-ledger-monotonic.sh`, `ci.yml:120,133`; `admin-award-ledger.json:4` (218-03 verify-hold history) |

### Harness runbook (SC-2)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `admin-eval-runbook.md` already satisfies SC-2; at most light freshness commit | Confident | `admin-eval-runbook.md:3-5,12-36,152-161,313-336` |

### Canary-merge reconciliation (SC-3)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Canary WILL red fast_checks by design; ship-with-red (non-required) was initial rec | Confident (mechanism) / Likely (path) | `snapshot-canary-guard.sh:53-60,88,109-113`; `ci.yml:79-82,112-118`; ruleset 14941512 required-5 |

### cheerio fast_checks break (SC-4)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| evidence-anchor-check is a deterministic gate (not the LLM panel); keep gating, fix dep | Confident | `evidence-anchor-check.mjs:20-22,47,100-103,152`; `ci.yml:141-145,204-206`; `admin-eval-runbook.md:156,172-175` |

### Milestone-ship PR mechanics (Area 5)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One full-branch PR (this branch → main, .planning included) via /gsd-ship; merge deferred | Confident | 215 precedent PR #67; `215-03-SUMMARY.md:132-139`, `215-VERIFICATION.md:98-99,122-124`; STATE branch 189-ahead/0-behind |

## Deep Research (user-requested, 3 parallel gsd-advisor-researcher subagents)

User requested full pros/cons/tradeoffs, idiomatic-ecosystem, lessons-from-other-tools, and DX
lenses on every decision point before locking. Three researchers ran (release-engineer / SRE / VRT
expert; CI-CD architect / DevOps; OSS release-engineer / reviewer / runbook-DX). Key outputs:

### R1 — Canary reconciliation (MATERIAL CORRECTION)
- **Corrected the handoff's worst case:** the branch diff vs origin/main is **exactly 3 PNGs
  (`impersonation-banner` canary), not ~115.** `board-notice` and the other ~112 already match main.
  Independently re-verified: `git diff --name-status origin/main...HEAD -- '*.png'` → 3× `M`.
- **Recommended QUARANTINE** the 3 PNGs into a baselines-only PR merged first (required
  `Example Playwright smoke` green = byte-correctness proof; only non-required `fast_checks` reds),
  so the terminal PR is all-green. Mirrors Chromatic/Percy/reg-suit "approve baseline → check goes
  green"; the ecosystem never merges a standing red on the artifact of record.
- Footgun cited: `GITHUB_TOKEN`-authored PRs don't retrigger checks (CI/CD doc line 227) → push via PAT.
- Fallback: ship terminal PR with fast_checks red directly (safe, worse DX).

### R2 — CI gate architecture + cheerio
- cheerio fix: **lazy-require after the no-bundles guard** (already a runtime `createRequire`, not a
  static import → clean 2-line move; keeps the deterministic gate; faithful to `--no-optional-deps`
  hygiene). Reorder = fragile/positional; advisory = discards protection; root package.json = heavy.
- Ratchet guards: **confirm, not fresh-climb** — but confirmation must be a LIVE guard run against
  the real merge-base (216 SC-5 lesson), not a doc assertion. Ratchets are mainstream (betterer,
  coverage-ratchet, Notion eslint-seatbelt); `award-guard.mjs` is stronger than a bare counter.

### R3 — Ship PR mechanics + runbook
- Ship: **one full-branch MERGE-COMMIT PR, keep .planning, do NOT squash** (would flatten 76
  conventional commits / gut the granular changelog; release-please hides docs/chore anyway).
  `/gsd-pr-branch` filtered was already tried this wave → PR #70 CLOSED. Merge release-please **PR #66
  first (v1.2.0)**, then v1.44 PR, then regenerated v1.3.0.
- Runbook: not pure confirm — add **3 additive freshness notes** (you-are-here loop disambiguation;
  merge-boundary canary-red is expected; branch-scoped recapture cross-ref) so a zero-context agent
  isn't misled into darwin recapture or misreading the canary red.

## Corrections Made

The user did not correct any assumption; instead requested deep research, which REFINED two areas:
- **SC-3:** initial "ship with fast_checks red" → refined to **quarantine PR first** (all-green
  milestone artifact) after R1 verified the drift is only 3 PNGs. User confirmed "Yes — all 5,
  quarantine PR."
- **SC-2:** initial "confirm as-is" → refined to **confirm + 3 light additive notes** per R3's
  zero-context-agent DX analysis.

## External Research

- Visual-regression baseline approval idioms — Chromatic/Percy/reg-suit/Playwright `--update-snapshots`
  ("approve → green", never merge a red on the feature PR). Sources: desplega.ai, teachmeidea.com,
  percy.io, github.com/reg-viz/reg-suit.
- Ratchet/monotonic CI guards — betterer, jest-coverage-ratchet, imbue-ai/ratchets, Notion
  eslint-seatbelt; footguns (base-branch drift, gaming, permanent-stale lock). Sources: qntm.org,
  dustyburwell.com, notion.com/blog.
- Optional-dependency Node CI idioms (defer-require, don't auto-install). Sources: npm docs,
  betterprogramming.pub; corroborated by `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md`
  (lines 55, 107, 227, 307–324).
- release-please squash-vs-merge + large-PR reviewability + SRE runbook hallmarks. Sources:
  googleapis/release-please, lloydatkinson.net, Google SRE Book, incident.io, emmer.dev.

## Final Decision

User selected "Yes — all 5, quarantine PR" — locked D-01…D-13 in 220-CONTEXT.md.
