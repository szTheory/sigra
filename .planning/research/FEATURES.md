# Feature Research

**Domain:** Batteries-included first-party authentication for Phoenix clients
**Researched:** 2026-08-12
**Confidence:** HIGH

## Feature Landscape

### Table Stakes

| Feature | Why expected | Complexity |
|---|---|---|
| Explicit credential pipelines | Hosts must know whether a route accepts cookie, PAT, app-session, or JWT authority | MEDIUM |
| Hosted native login with PKCE | Supports password, Google, passkeys, and MFA through one ceremony | HIGH |
| Rotating opaque refresh sessions | Mobile users need durable login with server-side revocation | HIGH |
| Optional direct password/MFA login | Some first-party apps require native credential UI | MEDIUM |
| Device/session revocation | Password reset, logout-all, deletion, and theft response must terminate sessions | HIGH |
| Correct PAT and JWT generation | Advertised installer flags must produce runnable, fail-closed hosts | HIGH |
| Account-isolated offline behavior | Cached lessons and queued answers must not cross users | HIGH |

### Differentiators

| Feature | Value | Complexity |
|---|---|---|
| One opaque app-session contract across iOS and Android | Native support without forcing OAuth-server or JWT complexity | HIGH |
| Crosswake projection proof | Demonstrates route/runtime interop while keeping credential authority in Sigra | MEDIUM |
| Physical-iPhone plus Android-emulator evidence | Makes support claims concrete rather than documentation-only | HIGH |
| Language-learning digital twin | Exercises structured data, images, audio, offline lease, and replay without building a product | MEDIUM |

### Anti-Features

| Feature | Why problematic | Alternative |
|---|---|---|
| Sigra as OAuth/OIDC provider | Duplicates Lockspire and introduces consent/client/delegation scope | Keep Lockspire as the authorization server |
| Client-selected scopes during login | Converts identity login into privilege escalation | Host-selected authorization policy |
| Generic offline sync/media framework | Moves product and Crosswake responsibilities into auth | One bounded digital-twin island |
| Full native/Electron SDK suite | Creates permanent platform release obligations | Reference shells and contract vectors |

## Dependency Order

```text
Ownership boundary
  -> explicit credential pipelines
      -> repaired PAT/JWT generation
      -> opaque app-session core
          -> hosted/direct ceremonies
              -> PWA digital twin
                  -> Crosswake native proof
                      -> Electron contract and closeout
```

## Milestone Definition

Launch with explicit credential contracts, secure app sessions, repaired PAT/JWT truth, the PWA/iOS/Android/Crosswake twin, and Electron contract tests. Defer published native SDKs, packaged Electron, additional offline islands, generic media caching, dynamic clients, consent, discovery, and JWKS.

## Sources

- Sigra current implementation and generated-host templates
- Lockspire supported-surface and companion-host documentation
- Crosswake first-adopter brief, offline contracts, and `crosswake_sigra` support matrix
- RFC 8252 and RFC 9700

---
*Feature research for: v1.49 FIRST-PARTY-CLIENT-READINESS*

