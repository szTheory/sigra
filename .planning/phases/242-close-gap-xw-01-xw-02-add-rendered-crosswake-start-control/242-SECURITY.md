---
phase: 242
slug: close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
status: verified
# threats_open counts OPEN threats at or above workflow.security_block_on (high).
threats_open: 0
asvs_level: 1
created: 2026-08-12
---

# Phase 242 — Security

> Per-phase security contract for the rendered Crosswake start control, deterministic continuation evidence, and formatting-only certification closure.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Authenticated `/app` document → `POST /crosswake/start` | The rendered native action enters the existing CSRF-protected authenticated controller pipeline. | Authenticated browser session and CSRF token. |
| Browser-observed return navigation → host continuation/controller | Server-generated opaque correlation values appear transiently during the return journey but must not become browser authority, logs, final navigation, or DOM content. | Opaque continuation and state values. |
| Source-contract test → Phase 240.3 security owners | Rendered-edge guards preserve controller, continuation, adapter, evaluator, and P14 ownership without creating a competing security implementation. | Source assertions and deterministic test evidence. |
| Shared `example_test` rows → sandboxed continuation test | Pre-existing database residue must not influence bounded cleanup evidence. | Test-only continuation rows. |
| Formatter configuration → submitted Crosswake files | Automated rewriting must remain canonical, scoped, and non-semantic. | Source layout only; no new runtime data flow. |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-242-01 | Spoofing / Tampering | Native `/app` start form | high | mitigate | Native action-bearing POST form with Phoenix CSRF mechanics in the authenticated browser pipeline; rendered contract asserts action, method, CSRF field, and no LiveView event. | closed |
| T-242-02 | Elevation of Privilege | Rendered Crosswake control | high | mitigate | Form submits no application-owned authority inputs; the unchanged controller owns session resolution and evaluation. | closed |
| T-242-03 | Information Disclosure | Browser return journey | high | mitigate | Exact callback keys, encrypted HttpOnly session transport, absent Referer, fixed `/app`, and URL/DOM disclosure sentinels are preserved. | closed |
| T-242-04 | Repudiation | XW-01/XW-02 closure evidence | medium | mitigate | Focused rendered/source contracts, role-driven serial zero-retry browser proof, and the adapter/continuation/controller/P14 matrix provide deterministic evidence. | closed |
| T-242-05 | Denial of Service | Focused browser proof | low | accept | The existing bounded runner owns readiness, port selection, cleanup, and timeouts; Phase 242 adds no retry, worker, poller, or delay. Residual local runner availability risk is accepted. | closed |
| T-242G-01 | Tampering / Repudiation | Shared-database cleanup test | medium | mitigate | Test setup clears and asserts only transaction-visible rows after sandbox checkout while retaining the exact 500-row and live-claim assertions. | closed |
| T-242G-02 | Elevation of Privilege | Production continuation authority | high | mitigate | Change is test-only; unchanged adapter, continuation, controller, and P14 controls retain production authority and fixed navigation. | closed |
| T-242G-03 | Information Disclosure | Crosswake security evidence | high | mitigate | P14 repository, deliberate fail-first, and clean controls pass; setup emits no continuation values. | closed |
| T-242G-04 | Denial of Service | Bounded cleanup proof | low | accept | The fixture retains the production maximum of 500 rows and adds no retry, polling, delay, or unbounded generation. Residual bounded test cost is accepted. | closed |
| T-242G2-01 | Tampering | Formatter scope | medium | mitigate | Both formatters used exact paths; commit `26f094f5` changes exactly the declared three files and scoped checks pass. | closed |
| T-242G2-02 | Elevation of Privilege | Crosswake start and return contracts | high | mitigate | Route, input, secrecy, and navigation literals remain guarded by passing AppLive and Phase 240.3 source-contract suites. | closed |
| T-242G2-03 | Repudiation | Formatter compliance evidence | medium | mitigate | Explicit-path formatter checks and focused tests propagate failures; the bounded runner uses `set -euo pipefail`. | closed |
| T-242G2-04 | Information Disclosure | Formatting-only artifacts | low | accept | Formatting adds no data flow or logging path and the existing secret/correlation assertions remain green. The unchanged residual disclosure risk is accepted. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-242-01 | T-242-05 | The browser proof is already bounded by readiness, timeout, cleanup, one worker, and zero retries; further availability machinery would add complexity without reducing product risk. | User, via `$gsd-secure-phase 242` checkpoint | 2026-08-12 |
| AR-242-02 | T-242G-04 | The deterministic cleanup fixture is capped at the production 500-row bound and executes only in tests; its bounded resource cost is acceptable. | User, via `$gsd-secure-phase 242` checkpoint | 2026-08-12 |
| AR-242-03 | T-242G2-04 | Canonical formatting creates no runtime data path and all secrecy guards remain unchanged; the pre-existing residual disclosure risk is not increased. | User, via `$gsd-secure-phase 242` checkpoint | 2026-08-12 |

---

## Security Audit 2026-08-12

| Metric | Count |
|--------|-------|
| Threats found | 13 |
| Closed | 13 |
| Open | 0 |

The ASVS L1 audit verified all ten mitigation dispositions in implementation and deterministic evidence. Three planned low-severity acceptance dispositions were supported by implementation evidence and explicitly accepted by the user. There are no unregistered summary threat flags and no threats open at or above the configured `high` blocking threshold.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-12 | 13 | 13 | 0 | `gsd-security-auditor` and Codex orchestrator |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-12
