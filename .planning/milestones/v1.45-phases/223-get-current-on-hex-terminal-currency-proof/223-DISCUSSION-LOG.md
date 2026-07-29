# Phase 223: Get Current on Hex + Terminal Currency Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-10
**Phase:** 223-get-current-on-hex-terminal-currency-proof
**Mode:** assumptions
**Areas analyzed:** Retire path, PUB-05 verification mechanism, PROOF-01 bundle format, Suite-green evidence capture

## Live Registry State (confirmed at discuss time)

`curl -s https://hex.pm/api/packages/sigra`:
- `latest_stable_version: 1.20.0`
- `latest_version: 1.20.0`
- `retirements: {}`
- releases: `[1.20.0, 1.3.0, 1.2.0, 1.1.0, 1.0.0, 0.3.0, …]`

Consequence: `{:sigra, "~> 1.0"}` resolves to `1.20.0` today. PUB-05 and PROOF-01 are
unsatisfiable until 1.20.0 is retired.

## Assumptions Presented

### Retire path (Area 1)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Un-defer PUB-04; operator mints dashboard write key + `mix hex.retire sigra 1.20.0`; only lever that greens PUB-05/PROOF-01 | Likely (mechanics Confident; decision is Jon's) | retire runbook `2026-07-03-hex-retire-stray-1-20-0.md:39-52`; live API `latest_stable=1.20.0` |

### PUB-05 verification mechanism (Area 2)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Scratch mix project `{:sigra, "~> 1.0"}` + `mix deps.get`, assert `mix.lock` = 1.3.0; do NOT reuse resolve-sigra-source.sh | Confident | `resolve-sigra-source.sh:44` hardcodes `exclude=…1.20.0` → false-green |

### PROOF-01 bundle format (Area 3)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Standalone `223-PROOF.md`, 215/220 observable-truths verbatim-evidence format, complements 223-VERIFICATION.md | Likely | ROADMAP:28 / REQUIREMENTS:33 name it the trust artifact; `215-VERIFICATION.md:36-44` precedent |

### Suite-green evidence capture (Area 4)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Verbatim `mix test` counts (lib + example) + `gh pr checks --required`, per 215 D-03 | Confident | `215-VERIFICATION.md:36-44,119`; CLAUDE.md live-PG prerequisites |

## Corrections Made

**Area 1 — Retire path:** Presented as a high-stakes user-owned decision (Jon had deferred
the retire twice). Asked explicitly rather than assuming.

- **Question:** How should Phase 223 handle the operator-gated retire of stray 1.20.0?
- **User choice:** **"Retire now (real green)"** — operator mints a web-dashboard Hex write
  key + runs `mix hex.retire` during execution; PUB-04 is un-deferred; PUB-05/PROOF-01 close
  for real (`latest_stable → 1.3.0`, `~> 1.0 → 1.3.0`). Chosen over the 220-style
  deferred-execution shape (which would close the milestone with its headline trust claim
  still PENDING).
- **Reason:** Release-currency is the milestone's entire point; the untried dashboard-key
  path is ~2 min of operator effort and expected to work.

Areas 2, 3, 4 — confirmed as presented (no corrections).

## External Research

None performed — the live Hex facts were already confirmed and every mechanism
(resolver, upgrade-smoke harness, prior VERIFICATION bundles, retire runbook) is present
in the codebase.
