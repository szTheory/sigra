# Phase 147: Upgrade And Migration Lanes - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md -- this log preserves the analysis.

**Date:** 2026-05-31
**Phase:** 147-upgrade-and-migration-lanes
**Mode:** assumptions
**Areas analyzed:** Upgrade Guide Shape And Location, Consumer Upgrade Smoke Contract, Migration Lanes Must Be Comparative And Boundary-First, Linking Surfaces For Migration Docs

## Assumptions Presented

### Upgrade Guide Shape And Location
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 147 should add a new public guide at `guides/introduction/upgrading-to-v1.0.md` that follows the existing operational checklist, exact commands, and verification style. | Confident | `guides/introduction/upgrading-to-v1.1.md`, `README.md`, `mix.exs` |

### Consumer Upgrade Smoke Contract
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| UPGRADE-02 needs a dedicated consumer-upgrade smoke lane from latest published `0.3.x` posture to local `1.0.0` candidate source, instead of relying only on current fresh-install smoke or upgrade tests. | Likely | `scripts/ci/install-smoke.sh`, `.github/workflows/ci.yml`, `test/upgrade_test.exs` |

### Migration Lanes Must Be Comparative And Boundary-First
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `phx.gen.auth` and Pow/Guardian/Ueberauth migration docs should focus on when to migrate, when not to migrate, cutover options, and ownership boundaries, not new primitives or feature expansion. | Confident | `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md`, `.planning/phases/146-release-gate-and-maintainer-runbook/146-CONTEXT.md`, `README.md`, `guides/introduction/getting-started.md`, `guides/introduction/contract.md` |

### Linking Surfaces For Migration Docs
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 147 should wire migration docs into README navigation, ExDoc extras/groups, release/evidence docs, and `doc/llms.txt`. | Likely | `README.md`, `mix.exs`, `docs/ga-evidence.md`, `doc/llms.txt` |

## Corrections Made

No corrections -- all assumptions confirmed.

## External Research

- Phoenix `phx.gen.auth`: Phoenix 1.8 docs show generated auth includes scopes, magic links, sudo mode, LiveView/controller variants, and explicit developer ownership of generated auth code. Source: https://hexdocs.pm/phoenix/mix_phx_gen_auth.html
- Guardian: Guardian docs describe token-based authentication, JWT defaults, Plug/Phoenix integration, and no challenge-phase implementation. Source: https://hexdocs.pm/guardian/introduction-overview.html
- Ueberauth: Ueberauth describes itself as a two-phase authentication framework focused on initial provider/challenge flow; request authentication remains the application's responsibility. Source: https://github.com/ueberauth/ueberauth
- Pow: Pow presents itself as a Phoenix/Plug user-management authentication library with out-of-the-box sessions and customization. Source: https://powauth.com/
