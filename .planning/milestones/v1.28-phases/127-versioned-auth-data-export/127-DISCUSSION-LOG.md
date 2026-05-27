# Phase 127: Versioned Auth Data Export - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 127-versioned-auth-data-export
**Mode:** assumptions
**Areas analyzed:** Public Contract Boundary, Payload Shape, Lifecycle Truth, Optional Schema Degradation, Sensitive Auth Material

## Assumptions Presented

### Public Contract Boundary
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 127 should stabilize `Sigra.DataExport.export_auth_data/3` as the library-owned payload contract; generated-host code only supplies schemas or thin wrappers. | Likely | `lib/sigra/data_export.ex`; `lib/sigra/admin/audit/export.ex`; `priv/templates/sigra.install/admin/audit_export_controller.ex`; `.planning/phases/32-generated-installer-admin-surface-parity/32-RESEARCH.md` |

### Versioned Payload Shape
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Preserve the structured top-level map with version metadata, account, sessions, identities, audit, MFA, organizations, enterprise exclusion, and omissions. | Confident | `lib/sigra/data_export.ex`; `test/sigra/data_export_test.exs`; `.planning/ROADMAP.md`; `.planning/REQUIREMENTS.md` |

### Lifecycle Truth
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Include raw lifecycle fields plus a derived lifecycle state consistent with `Sigra.Account.Deletion.status/1`, without broadening into host retention semantics. | Likely | `lib/sigra/data_export.ex`; `test/sigra/data_export_test.exs`; `priv/templates/sigra.install/core/user.ex`; `lib/sigra/account/deletion.ex` |

### Optional Schema Degradation
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Missing optional schemas should produce present empty sections and explicit omission notes for every omitted optional Sigra-owned section. | Confident | `.planning/REQUIREMENTS.md`; `lib/sigra/data_export.ex`; `test/sigra/data_export_test.exs`; `.planning/phases/22-passkeys-generator-wiring/22-CONTEXT.md` |

### Sensitive Auth Material
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Credential-related records should be curated summaries or safe field subsets, not raw structs with hashes, encrypted secrets, OAuth tokens, or passkey credential material; backup codes remain summary-only. | Likely | `lib/sigra/data_export.ex`; `priv/templates/sigra.install/core/user_session.ex`; `priv/templates/sigra.gen.oauth/user_identity.ex`; `priv/templates/sigra.install/core/user_mfa_credential.ex`; `priv/templates/sigra.install/passkeys/user_passkey.ex`; `priv/templates/sigra.install/core/user_backup_code.ex` |

## Corrections Made

No corrections — all assumptions proceeded under the repo's assumptions-mode methodology.

## External Research

No external research was performed. Codebase and planning artifacts provided enough authority for Phase 127 assumptions.
