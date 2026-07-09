# Phase 219: Baseline Recapture + Canary Reconciliation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-09
**Phase:** 219-baseline-recapture-canary-reconciliation
**Mode:** assumptions (+ deep research pass per operator request)
**Areas analyzed:** inventory, compile-blocker, recapture mechanism/trigger, canary/zero-human posture, allowlist reconciliation, generated-host parity, branch topology

## Assumptions Presented

### Inventory
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Exactly 115 baselines = 84 admin-design + 27 admin-checkpoints + 4 demo-showcase; demo-showcase has no recapture job/canary | Confident | `git ls-files … *-snapshots/*.png` = 115; ci.yml:1497/1798; demo-showcase note ci.yml:1776 |

### Compile blocker
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `<.icon style=>` (mfa_settings_live.ex:250,328) fails `mix compile --warnings-as-errors`; example `icon/1` lacks `attr :rest, :global`; blocks all recapture — in 219 scope; example-only, no golden rebless | Confident (verified empirically) | core_components.ex:444-451; subagent ran `mix compile --warnings-as-errors` → non-zero exit; template uses Tailwind not inline style; `git diff <mb>..wave -- priv/templates` empty |

### Recapture mechanism / trigger
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reuse the two existing amd64 recapture jobs; add demo-showcase step; unify checkpoint canary delete-rebirth; fix stale 72/24 comments | Confident | ci.yml:1497,1798,1604-1607,1490,1611; jobs asymmetric (design self-gates, checkpoint doesn't) |
| Green-before-merge requires a branch-scoped trigger — push watches only main; workflow_dispatch blocked by v*-tag release_ref_guard | Likely→Confident | ci.yml:3-20 triggers, 34-52 release_ref_guard, 1500 `if != pull_request` |

### Canary / zero-human
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Zero-human on pixels defensible (218 verified renders) + keep git-diff intent review; canary is the safeguard that makes it safe | Likely | snapshot-recapture-gate.sh "no human review needed"; ecosystem synthesis (Chromatic/Percy/Argos default human, safe-to-skip iff deterministic render + sentinel) |

### Allowlist (SC-2)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both allowlists already empty; guard only diffs (no re-render), so recapture PR must name changed slugs, empty steady-state is a follow-up PR | Confident | both allowlist files comment-only; snapshot-canary-guard.sh added-vs-modified logic |

### Generated-host parity (SC-3)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| SC-3 essentially confirm-only; golden consistent (no template change, ec4dfd12 rebless on main); acceptance-smoke hard-gated, uses own generated app | Likely | golden_diff_test.exs, ci.yml:1369/1448; icon fix is example-only |

### Branch topology (surfaced during research)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| main strictly subsumes PR #70 (has 218-07…10 gap-closure + golden rebless ec4dfd12); PR #70 stale → branch 219 off main, close #70 | Confident | merge-base f2e54612; `git merge-base --is-ancestor ec4dfd12 main` true / wave false; main..wave vs wave..main log |

## Corrections Made

No assumptions were corrected. The operator requested a **deep research pass** (3 parallel
subagents: VRT ecosystem best-practices, Sigra recapture-mechanics deep-dive, prompts-subdir
scan) before locking, then made ONE operator decision on the single impactful fork.

## Operator Decision

- **Recapture trigger (D-04):** chose **Branch-scoped CI dispatch** over post-merge designed
  flow and local-act amd64. Rationale: true CI-native amd64 pixels (no arm64-emulation gamble)
  + green-before-merge (no red on the required `example_playwright_smoke` gate; no merge
  deadlock; honors clean-gate discipline). Cost accepted: modest surgical ci.yml surface.

## External Research

- **VRT ecosystem synthesis** — CI-native (digest-pinned) capture is the settled industry norm;
  cross-OS (darwin→ubuntu) diffing is the classic footgun. Zero-human pixel blessing is
  defensible iff render is deterministic AND a never-allowlistable sentinel is armed; keep the
  git-diff intent review (the safeguard SaaS approval UIs charge for). Empty-steady-state
  allowlist + named-slug intent + reset-on-merge is the minimal-dep analogue of Chromatic.
  Green-before-merge via delete-then-add-at-HEAD. (Playwright #35143, Argos, reg-suit, oneuptime,
  Applitools.)
- **prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md** — cache-vs-artifact
  separation; determinism/strict-pinning; warnings-as-errors gating; required-vs-optional check
  placement; **`GITHUB_TOKEN` does not retrigger downstream workflows** (relevant if a bot commits
  the baseline PR and expects CI to re-run). LiveView doc cautions VRT baselines be tightly scoped.
- **Sigra recapture-mechanics deep-dive** — verified the compile failure empirically; mapped both
  recapture jobs, their asymmetry, the demo-showcase gap, the two guard scripts, and the
  push-only/release-ref-guard trigger constraints that drive D-04.
