# Project Research Summary

**Project:** Sigra
**Domain:** First-party Phoenix authentication across web, native, and hybrid runtimes
**Researched:** 2026-08-12
**Confidence:** HIGH

## Executive Summary

Sigra should own first-party authentication, including browser cookies and opaque native app sessions, while Lockspire remains the OAuth/OIDC authorization server for registered external clients. Crosswake consumes freshly projected authentication facts for route and offline behavior but never owns credentials or authority. Product authorization, media, leases, and replay decisions remain in the Phoenix host.

The remaining high-leverage readiness gap is not another auth method or admin UI: Sigra advertises PAT/JWT capability whose generated surface is incomplete, and it lacks a proven native first-party session lifecycle. The recommended milestone repairs that truth, adds independently opted-in opaque app sessions, and proves the contract through a bounded language-learning digital twin across PWA, physical iPhone, Android emulator, Crosswake, and an Electron contract.

The main risks are scope collapse into OAuth-server behavior, client SDK ownership, or a generic offline framework; callback/token lifecycle defects; and support claims exceeding evidence. Explicit ownership, independent installer flags, transactional refresh families, and evidence-classed platform proof contain those risks.

## Key Findings

### Recommended Stack

- Preserve Phoenix/Plug/Ecto/PostgreSQL and the hybrid library-plus-generator model.
- Use opaque digest-only app credentials with database-backed rotation and revocation.
- Keep Joken/JOSE only for repaired advanced JWT support.
- Consume released Crosswake packages and platform-native browser/link/storage primitives.

### Expected Features

**Must have:** explicit credential pipelines, hosted PKCE login, optional direct password/MFA login, rotating opaque refresh sessions, security-event revocation, repaired PAT/JWT generation, account-isolated offline behavior.

**Differentiators:** one first-party session contract across iOS/Android, Crosswake projection proof, physical-device evidence, and a realistic offline-media twin.

**Defer:** OAuth/OIDC provider features, published native SDKs, packaged Electron, generic offline sync/media storage, and additional runtime lines.

### Architecture Approach

Sigra establishes identity and session authority; generated Phoenix code exposes host-controlled routes and policy; app-session credentials authenticate API requests without adding authorization scopes. Crosswake receives only opaque backend projections. The host owns clients, product authorization, offline leases, lesson/media content, and replay outcomes.

### Critical Pitfalls

1. **Autodetected credentials** — replace with explicit pipelines.
2. **Installer/source drift** — require complete flag-matrix and fresh-host runtime proof.
3. **Client-selected authority** — forbid scopes in app login and derive JWT/PAT scopes from server policy.
4. **Refresh reuse races** — consume and rotate inside one transaction with family revocation.
5. **Offline cache as authority** — limit leases to local use and reauthorize replay online.

## Implications for Roadmap

1. **Phase 243:** Lock ownership and credential pipelines before adding another credential type.
2. **Phase 244:** Repair PAT/JWT truth so the foundation is honest.
3. **Phase 245:** Add the opaque session/token-family core and revocation semantics.
4. **Phase 246:** Add hosted/direct ceremonies and complete installer proof.
5. **Phase 247:** Build the PWA language-learning twin and offline lease/replay contract.
6. **Phase 248:** Prove Crosswake, physical iPhone, and Android emulator behavior.
7. **Phase 249:** Contract-test Electron, threat-model the whole slice, and ratify support claims.

This ordering ensures every later runtime proof consumes the same server contract and prevents the twin from hiding defects in generated hosts.

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Stack | HIGH | Uses existing dependencies and official platform/security guidance. |
| Features | HIGH | Derived from stated adopter constraints and current Sigra gaps. |
| Architecture | HIGH | Verified against Sigra, Lockspire, Crosswake, and companion contracts. |
| Pitfalls | HIGH | Includes nine concrete source-level defects plus standards-derived risks. |

## Sources

- [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)
- [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700)
- Sigra source, generated templates, and public guides
- Lockspire supported-surface, architecture, and Sigra companion-host documentation
- Crosswake first-adopter brief, offline contracts, and `crosswake_sigra` support truth

---
*Research completed: 2026-08-12*
*Ready for roadmap: yes*
