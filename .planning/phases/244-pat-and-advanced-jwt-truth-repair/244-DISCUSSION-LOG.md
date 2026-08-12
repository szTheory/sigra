# Phase 244: PAT and Advanced JWT Truth Repair - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `244-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-08-12
**Phase:** 244-pat-and-advanced-jwt-truth-repair
**Mode:** assumptions with autonomous defaults
**Areas analyzed:** Independent Generator Contracts, PAT Management Boundary, JWT Claim Contract and Scoped Issuance, Refresh-Family Atomicity

## Assumptions Presented

| Area | Assumption | Confidence | Evidence |
|---|---|---|---|
| Independent Generator Contracts | `--api` and `--jwt` must emit independent PAT and advanced-JWT host contracts. | Confident | `lib/sigra/install/features/core.ex`; Phase 243 explicit plugs |
| PAT Management Boundary | PAT management belongs to authenticated browser sessions with CSRF, `RequireSudo`, and owner-derived operations. | Confident | `lib/sigra/plug/require_sudo.ex`; generated routes; current unconstrained controller/delegate |
| JWT Claim Contract | JWT issuance is server-policy-only and verification requires exact algorithm/type plus mandatory registered claims. | Confident | `priv/templates/sigra.install/core/token_controller.ex`; `lib/sigra/jwt.ex`; `lib/sigra/config.ex` |
| Refresh-Family Atomicity | Rotation and reuse revocation must be transactional with or without auditing. | Confident | `lib/sigra/jwt.ex`; `lib/sigra/jwt/refresh_token.ex`; refresh tests |

## Corrections Made

No corrections — all assumptions were Confident and aligned with locked milestone decisions.

## Auto-Resolved

- All Confident assumptions were accepted under autonomous assumptions mode.
- Audience configuration defaults to exact, case-sensitive membership across RFC-valid scalar/array forms.

## External Research

- Joken 2.6.2 uses `JOSE.JWT.verify_strict/3` with the configured algorithm singleton; no unverified algorithm dispatch is needed.
- `typ` is a protected JOSE header, not a payload claim. Joken does not verify it automatically, so Sigra must validate it alongside successful signature verification.
- Joken claim validators do not require absent claims; mandatory payload fields need `Joken.Hooks.RequiredClaims` or equivalent fail-closed presence enforcement.
- RFC 7519 permits scalar or array `aud`; recipient matching is exact and case-sensitive. RFC 8725 requires audience validation for multi-recipient issuers.
- Sources: RFC 7519 §§4.1.3, 5.1; RFC 8725 §§3.1, 3.9, 3.11; Joken 2.6.2 signer/config/hooks documentation and source.
