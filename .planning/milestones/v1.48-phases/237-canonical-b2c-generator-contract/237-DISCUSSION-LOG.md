# Phase 237: Canonical B2C Generator Contract - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-04
**Phase:** 237-canonical-b2c-generator-contract
**Mode:** assumptions
**Areas analyzed:** Canonical Installer Profile, Google OAuth Generated-Host Contract, Negative Surface Boundary, Proof Boundary and Sequencing

## Assumptions Presented

### Canonical Installer Profile
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The B2C profile uses the explicit non-interactive installer command with all three opt-outs, retaining email/password and magic links. | Confident | `lib/mix/tasks/sigra.install.ex`, `guides/recipes/b2c-alpha.md`, `scripts/ci/passkeys-opt-out-smoke.sh` |

### Google OAuth Generated-Host Contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `cloak_ecto`, then generate Google OAuth and prove the identity, vault, controller/routes, and migration artifacts. | Confident | `lib/mix/tasks/sigra.gen.oauth.ex`, `priv/templates/sigra.gen.oauth/oauth_migration.exs`, `priv/templates/sigra.gen.oauth/user_identity.ex`, `scripts/ci/passkeys-opt-out-smoke.sh` |

### Negative Surface Boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Verify absence from generated output across routes, files, dependencies/assets, and configuration—not merely command flags. | Confident | `lib/sigra/install/features/admin.ex`, `lib/sigra/install/features/organizations.ex`, `lib/sigra/install/features/passkeys.ex`, `test/sigra/install/generator_passkeys_opt_out_test.exs` |

### Proof Boundary and Sequencing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Use a deterministic no-secrets fresh-host smoke through boot; browser/runtime proof is Phase 238 and real provider/email work is staging-only. | Confident | `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `scripts/ci/passkeys-opt-out-smoke.sh`, `guides/recipes/b2c-alpha.md` |

## Corrections Made

No corrections — the user instructed the workflow to follow its recommendations automatically.
