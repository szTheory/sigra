# Technology Stack

**Project:** Sigra
**Researched:** 2026-06-01

## Recommended Stack (Post-1.0 Stewardship)

### Infrastructure & Tooling
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Dependabot | Latest | Automated dependency management | Keeps transitive deps updated and flags security alerts without manual intervention. |
| Release Please | Latest | Automated Hex releases & Changelog | Ensures semantic versioning is respected and releases are predictable and traceable. |
| Playwright | v1.x | E2E and visual regression testing | Protects the generated-host UI from regressions; critical for the `test/example/` demo showcase. |

### Core Framework (Target Support)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Phoenix | >= 1.8 | Web Framework | Sigra's primary target. Post-1.0 must rigorously test against the latest 1.8.x and upcoming 1.9.x releases. |
| Ecto | >= 3.x | Database Wrapper | Core dependency for the hybrid lib+generator architecture. |
| OTP | >= 25 | Runtime | Ensure modern Elixir features are supported and deprecation warnings from newer OTP versions are addressed. |

## Supporting Libraries (Strategic Bets Only)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ex_scim | Latest | SCIM Directory Sync | Only if the SCIM strategic bet is prioritized based on enterprise adopter demand. |
| assent | Latest | OIDC Integration | Continued monitoring and bumping; core to the `ENT-SSO` capabilities. |
| wax_ | Latest | Passkeys/FIDO2 | Continued monitoring; core to `PK-LIFECYCLE`. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Release Automation | Release Please | Custom Bash Scripts | Release Please enforces Conventional Commits and reduces the "Bus Factor" of release engineering. |
| Directory Sync | ex_scim | Custom patching logic | Implementing SCIM (RFC 6902 JSON Patch) manually is a security and complexity nightmare. |

## Sources

- Elixir open source maintenance best practices.
- Sigra `.planning/PROJECT.md`