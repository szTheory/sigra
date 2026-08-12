# Stack Research

**Domain:** First-party Phoenix authentication across browser, native, and hybrid clients
**Researched:** 2026-08-12
**Confidence:** HIGH

## Recommended Stack

| Technology | Version/Posture | Purpose | Why |
|---|---|---|---|
| Phoenix / Plug / Ecto | Existing supported versions | Host integration and persistence | Preserve Sigra's established hybrid library-plus-generator architecture. |
| PostgreSQL | Existing requirement | App sessions, one-time codes, token families | Transactions and row locks support atomic refresh rotation and reuse response. |
| Opaque random credentials | New default | Native access and refresh sessions | Revocable, digest-only storage without creating an OAuth authorization server. |
| Joken / JOSE | Existing optional dependency | Advanced JWT support | Retain the existing opt-in surface after fixing validation and generation truth. |
| Crosswake / crosswake_sigra | Released Hex coordinates | Route/runtime projection and offline-island proof | Consume the published contract without sibling source coupling. |
| Playwright, XCUITest, Android instrumentation | Existing/new proof lanes | Browser and native automation | Match each runtime claim to deterministic evidence. |

No new client SDK dependency is required. Native reference shells use system-browser authentication, platform link handling, and OS credential stores.

## Platform Patterns

| Platform | Authentication | Credential storage | Return transport |
|---|---|---|---|
| Phoenix web/PWA | Existing cookie session | Secure, HttpOnly, host-only cookie | HTTPS to Phoenix |
| iOS | System browser + PKCE S256 | Access in memory; refresh in Keychain | Universal Link preferred; exact custom scheme fallback |
| Android | Custom Tab/Auth Tab + PKCE S256 | Access in memory; app-private ciphertext with Keystore key | App Link preferred; exact custom scheme fallback |
| Electron | System browser + PKCE S256 | Main process using OS-backed safe storage | Verified HTTPS or loopback IP; custom scheme fallback |

## What Not to Add

| Avoid | Reason | Use instead |
|---|---|---|
| Embedded WebView login | Loses system-browser security and shared login state | Platform external authentication session |
| Persistent PWA bearer tokens | XSS turns storage into credential exfiltration | Existing BFF-style cookie session |
| Client secrets in native apps | Compiled secrets cannot authenticate a public client | Registered first-party profile + PKCE |
| New OAuth/OIDC authorization-server endpoints | Overlaps Lockspire | Opaque first-party app sessions |
| Universal Sigra client SDK | Platform lifecycle/storage responsibilities differ | Server contract, reference adapters, and conformance vectors |

## Sources

- [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252) — native app external user agents, redirects, and PKCE
- [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700) — current OAuth security best practices
- [Apple Authentication Services](https://developer.apple.com/documentation/authenticationservices) — system authentication sessions
- [Android App Links](https://developer.android.com/training/app-links) — verified application links
- [Electron security checklist](https://www.electronjs.org/docs/latest/tutorial/security) — renderer/main-process boundary

---
*Stack research for: v1.49 FIRST-PARTY-CLIENT-READINESS*

