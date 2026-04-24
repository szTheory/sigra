# ADR 001: Defer optional `sigra_lockspire` (or similar) glue package

**Status:** Accepted  
**Date:** 2026-04-23  
**Context:** Sigra trajectory + Lockspire integration brainstorm plan.

## Context

Sigra is the **end-user authentication** stack (sessions, passwords, MFA, passkeys, Assent-based **login with** external IdPs, audit, admin). A separate embedded library (**Lockspire**) is the **OAuth/OIDC authorization server** for **third-party clients** of the same Phoenix host. Both projects already record the decision: **separate packages**, narrow **host seam** (`AccountResolver` / equivalent), no mandatory cross-dependency.

## Decision

**Do not** add a Hex-published optional package such as `sigra_lockspire` in the near term.

Integration remains:

1. **Documentation + recipes** in Sigra (and companion docs in Lockspire) describing layering and subject/claims expectations.
2. **Generated host code** in the companion installer (e.g. `--sigra-host` stubs) that the host edits — not library-to-library calls in core paths.

## Consequences

- **Positive:** Sigra keeps minimal transitive deps; Lockspire can ship on its own cadence; no version-lock matrix between cores.
- **Negative:** Hosts hand-wire a few lines until a future glue package exists — acceptable while companion Phase **3** (OIDC interoperability) and Phase **6** (install DX) mature.

## Revisit triggers

- Lockspire **Phase 6** (`RELS-01` / `RELS-02`) is shipped and stable.
- `AccountResolver` (or successor seam) APIs are semver-stable on both sides.
- At least one **public** reference app exists that exercises both libraries under CI.
