# Recipe: Sigra + embedded OAuth/OIDC provider (e.g. Lockspire)

This recipe describes how to run **two roles** in one Phoenix host **without** merging them into one library:

| Role | Typical library | Responsibility |
|------|-----------------|----------------|
| **End-user login** (RP) | **Sigra** | Sessions, passwords, MFA, passkeys, “Log in with Google” (Assent), admin, audit for **your** product users |
| **Developer OAuth server** (AS) | Companion (e.g. **Lockspire**) | Authorization codes, client registry, consent for **third-party apps** calling **your** HTTP API |

Sigra’s project scope explicitly keeps **“acting as OAuth/OIDC identity provider”** out of the core library so security and dependency surfaces stay controlled. A companion library fills the **authorization server** wedge with a **narrow host seam** (`AccountResolver`-style behaviour): the host resolves “who is logged in?” and supplies claims; the companion owns protocol correctness.

## Prerequisites

- **End-user Sigra login works first** — session cookies, plugs, and your normal login/register flows must be green in **`dev`** before you wire **AccountResolver** (the companion authorizes **after** the host can prove who the user is).
- **You actually need an authorization server** — third-party clients, consent, and token issuance for **your** HTTP API. If you only need social login for **your** product users, stay on Sigra + Assent alone (see **When not to use** below).

## Architecture sketch

```text
Browser (end user) ──► Sigra plugs / LiveView ──► your User
Third-party OAuth client ──► Companion /oauth, /token ──► tokens
Companion consent/authorize ──► AccountResolver ──► reads same session / user as Sigra
```

## Rules of thumb

1. **No mandatory Hex edge** between Sigra core and the companion — avoids version lock and keeps Sigra’s minimal-deps story.
2. **Subject (`sub`)** for OIDC should be a **stable** user identifier from your Sigra-backed schema (often the user primary key as string). Do not recycle volatile fields.
3. **Claims** should be built from the same **authorization context** your app already trusts (e.g. org membership), not from ad hoc globals.
4. **Login redirect:** when the companion needs an interactive login, redirect into **your** normal Sigra login route; after session establishment, resume the OAuth interaction.

## Lockspire-specific pointers

If you use **Lockspire**, see also the companion doc in that repository: **`docs/sigra-companion-host.md`**.

Install stubs:

- Run `mix lockspire.install --sigra-host` to generate an **AccountResolver** stub with Sigra-oriented comments (still **host-owned** code you must complete).

## When **not** to use this pattern

- You only need **“Log in with GitHub”** for **your** users → Sigra + Assent is enough.
- **B2C-only SaaS with no third-party OAuth clients** — if every caller is your own first-party web/mobile app, you do not need an embedded AS; add this pattern only when you expose **developer-facing** OAuth for **external** apps calling your API.
- You need enterprise **IdP** features (SAML federation, complex CIAM) → evaluate dedicated products; this recipe targets **embedded** provider for **your** API ecosystem.

## See also

- [OAuth (login with provider) flow](../flows/oauth.html) — **consumer** OAuth, not developer AS.
- [Audit logging](../flows/audit-logging.html)
- [Upgrading notes — toward v1.8](../introduction/upgrading-to-v1.8.html) — maintainer-facing doc map after **v1.7**
- Archived planning: **INTG-01** shipped under **v1.7** (see **`.planning/milestones/v1.7-REQUIREMENTS.md`**)
