# Phase 239: Hosted Session Interop - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-08
**Phase:** 239-hosted-session-interop
**Mode:** assumptions
**Areas analyzed:** Backend session authority, personal-account scope, fail-closed validation, return-evidence boundary

## Assumptions Presented

### Backend Session Authority
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Crosswake receives a projection only after host-side SIGRA session/user resolution; it never accepts a browser token or return payload as proof. | Confident | `priv/templates/sigra.install/core/auth.ex`, `lib/sigra/session.ex`, `lib/sigra/session_stores/ecto.ex`, `guides/recipes/b2c-alpha.md` |

### Personal-Account Scope
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Personal sessions remain `org_id: nil`, with no organization selection, hydration, or creation. | Confident | `guides/recipes/b2c-alpha.md`, `priv/templates/sigra.install/core/user_auth.ex`, `.planning/phases/237-canonical-b2c-generator-contract/237-CONTEXT.md` |

### Fail-Closed Validation and Account Binding
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Each authority decision revalidates the SIGRA session and binds opaque session/subject refs; missing, revoked, expired, or mismatched state denies. | Confident | `lib/sigra/plug/fetch_session.ex`, `lib/sigra/plug/require_authenticated.ex`, `lib/sigra/auth.ex`, `guides/recipes/b2c-alpha.md` |

### Return and OAuth Evidence Boundary
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Hosted returns and OAuth callbacks are evidence/navigation only; no credential or token enters Crosswake authority. | Confident | `priv/templates/sigra.gen.oauth/oauth_controller.ex`, `guides/recipes/b2c-alpha.md` |

## Corrections Made

### Crosswake contract compatibility
- **Original assumption:** The released Crosswake companion could directly carry the locked `org_id: nil` personal scope.
- **User correction:** Approved the recommended public-contract change to permit `org_id: nil` for personal sessions rather than fabricate organization scope.
- **Reason:** A synthetic organization would violate the canonical B2C personal-account boundary.

## External Research

- Crosswake evaluator is pure and requires host-side revalidation: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/evaluator.ex
- Released contracts require nonblank `org_id`, blocking personal scope until changed: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/contracts.ex
- Return objects remain reference-only evidence and cannot grant authority: https://github.com/szTheory/crosswake/blob/e3d6cbfa4ab8ce6b8c4eb761afc05ea650f75c9c/packages/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex
