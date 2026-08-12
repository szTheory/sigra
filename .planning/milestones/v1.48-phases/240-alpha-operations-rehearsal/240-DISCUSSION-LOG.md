# Phase 240: Alpha Operations Rehearsal - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-10T21:11:03Z
**Phase:** 240-alpha-operations-rehearsal
**Mode:** assumptions, expanded by user-directed architecture and ecosystem research
**Areas analyzed:** recipe/evidence boundary, canonical origin and sessions, secrets/Cloak/email, rate limiting, CI claims, device launch gate

## Assumptions Presented

### Canonical recipe boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep one provider-neutral B2C recipe and exact canonical install/OAuth flow. | Confident | `guides/recipes/b2c-alpha.md`; Phase 237–239 context |

### Credential-free CI evidence
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fresh-host and local-OIDC proof run without live provider/email/deployment credentials; dummy values are fixtures. | Confident | `scripts/ci/passkeys-opt-out-smoke.sh`; `scripts/ci/generated-auth-runtime-proof.sh`; `.github/workflows/ci.yml` |

### Host launch-gate claims
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Real Google, transactional email, and iPhone proof stay as explicit host staging gates. | Confident | `guides/recipes/b2c-alpha.md`; `.planning/ROADMAP.md`; Phase 238 context |

### Diagnostics and rate limiting
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Doctor is wiring-only; host must validate effective limits and trusted proxy behavior. | Likely, confirmed after review | `lib/sigra/doctor.ex`; `lib/sigra/plug/rate_limit.ex`; limiter modules |

## Expanded Research Applied

- **Phoenix/Plug:** use one HTTPS origin, host-only secure session cookies by default, and intentional proxy/TLS configuration; library evidence cannot prove deployment behavior.
- **OAuth/provider precedent:** exact Google redirect registration and a real staging callback are host responsibilities; a local OIDC double is the right deterministic library proof.
- **Cloak/Swoosh precedent:** separate runtime wiring from real delivery; runtime secrets remain host-owned and no production value is committed or logged.
- **GitHub Actions precedent:** PR/library CI remains credential-free; fixture literals must not be misrepresented as external credentials.
- **Rate-limit review:** current recipe claim is stronger than the generated B2C enforcement evidence. The user accepted the recommendation to add explicit generated-host enforcement and deterministic proof.

## Corrections Made

- **Rate-limit scope:** Initial assumptions treated the rate-limit check as recipe/preflight wording. Expanded architecture analysis found the generated B2C identity flows do not consistently wire the optional limiter. Decision updated to require explicit generated-host limiter wiring and deterministic exhaustion proof rather than weakening the launch checklist.

## User Confirmation

- User chose no matched historical TODOs for Phase 240.
- User requested broad, expert ecosystem, architecture, SRE, DX, and UX analysis before deciding.
- User approved the resulting cohesive recommendation set with “proceed.”

## External Research

- Phoenix SSL and session guidance: `https://hexdocs.pm/phoenix/1.7.7/using_ssl.html`
- Google OAuth web-server redirects: `https://developers.google.com/identity/protocols/oauth2/web-server`
- Swoosh testing boundary: `https://swoosh.hexdocs.pm/Swoosh.html`
- Cloak Ecto key rotation: `https://hexdocs.pm/cloak_ecto/rotate_keys.html`
- GitHub Actions secure use: `https://docs.github.com/en/actions/reference/security/secure-use`
