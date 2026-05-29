---
phase: 137
slug: optional-dependency-source-of-truth
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-29
---

# Phase 137 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Phase 137 was a pure delegation refactor: scattered `Code.ensure_loaded?(Mod)`
optional-dependency checks were consolidated into a single source of truth,
`Sigra.OptionalDeps`. No new external input crosses any boundary; predicates take
only module atoms and `encryption_active?/1` reads host config. All branch bodies,
raise blocks, timing-protection else-clauses, and compound-guard liveness/arity
halves were preserved byte-for-byte.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| (none new) | Internal refactor. No new external input boundary. Predicates take only module atoms; `encryption_active?/1` reads read-only host config. | None |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-137-01 | Information Disclosure | `OptionalDeps.encryption_active?/1` | mitigate | Config-driven via `__sigra_encryption_mode__() != :stub` (`optional_deps.ex:198-207`, mirrors `application.ex:218-230`) — NOT a `Code.ensure_loaded?(Cloak)` load check. Closes the silent at-rest-encryption-disabled regression (ASVS V6); stub→false. | closed |
| T-137-02 | Tampering | `OptionalDeps` predicates | mitigate | All 9 predicates are un-memoized one-to-one `Code.ensure_loaded?(Mod)` wrappers (`optional_deps.ex:79-170`); no caching/ETS/persistent_term that could stale a truth value. | closed |
| T-137-03 | Information Disclosure (timing) | `crypto.ex` / `hashers/bcrypt.ex` | mitigate | bcrypt-verify timing-protection else-branches byte-preserved (`crypto.ex:246-251` `no_user_verify(); false`; `hashers/bcrypt.ex:42-43` Argon2 fallback); only the load-check token swapped. | closed |
| T-137-04 | Tampering / DoS | `jwt/signer.ex` + 5 oauth strategies | mitigate | Raise-guards still RAISE on dep absence (`jwt/signer.ex:18-24`; `oauth/strategies/{apple:76,facebook:80,github:77,generic:83,google:74}`). | closed |
| T-137-05 | Tampering | scope fence | mitigate | Plan 02/03 touched ONLY enumerated Bucket A single-leaf sites; no `workers/*`, `credo/*`, `testing.ex`, or compound-guard changes. | closed |
| T-137-06 | Denial of Service / availability | `delivery.ex` / `forwarders.ex` Oban `:auto` routing | mitigate | Only the load half delegated; the liveness half `and Process.whereis(Oban) != nil` stays literal (`delivery.ex:114`, `forwarders.ex:99`) — prevents `:sync`→`:async` flip that would crash an app adding `:oban` without supervising it. | closed |
| T-137-07 | Tampering | `forwarders.ex` test-override branch | mitigate | The `{:ok, oban_override}` branch (named process, no load check) byte-unchanged (`forwarders.ex:91-94`). | closed |
| T-137-08 | Tampering | `deletion.ex` internal-worker leg | mitigate | Line 307 Oban leg delegates; line 308 internal-worker leg stays literal `Code.ensure_loaded?(Sigra.Workers.AccountDeletion)` — no predicate invented for the conditionally-compiled internal worker. | closed |
| T-137-SC | Tampering | npm/pip/cargo/mix installs | accept | No new packages installed — all 9 referenced deps pre-existing (8 `optional: true` in `mix.exs`, `req` transitive); `mix.exs` untouched, no install task added. See Accepted Risks Log. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-137-SC | T-137-SC | Supply-chain checkpoint N/A — phase installs no new packages. All 9 referenced optional deps already declared in `mix.exs`; refactor only re-routes existing in-repo load checks. | gsd-security-auditor | 2026-05-29 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-29 | 9 | 9 | 0 | gsd-security-auditor |

### Security Audit 2026-05-29
| Metric | Count |
|--------|-------|
| Threats found | 9 |
| Closed | 9 |
| Open | 0 |

Register authored at plan time (all 3 PLANs carried `<threat_model>` blocks);
auditor ran in verify-mitigations-exist mode. Verdict: `## SECURED`.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-29
