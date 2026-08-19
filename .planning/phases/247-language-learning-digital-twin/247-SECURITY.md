---
phase: 247
slug: language-learning-digital-twin
status: verified
# threats_open counts OPEN threats at or above workflow.security_block_on severity.
threats_open: 0
asvs_level: 1
created: 2026-08-19
---

# Phase 247 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| HttpOnly browser session → Phoenix current Scope | Authentication and account authority remain server-side; browser state cannot select an owner. | Session cookie, current user/account authority |
| Manifest metadata → media response | Complete response bytes are untrusted until exact size and SHA-256 verification succeeds. | Immutable image/audio bytes and integrity metadata |
| Cache Storage → IndexedDB readiness | Cache writes and marker records are not transactional, so marker-last promotion and read-time checks are required. | Cached media, partitioned readiness metadata |
| Service worker → `/app/lesson` navigation | The `/app/` worker may return only the static generic shell offline and never caches authenticated HTML. | Navigation response and credential-free shell assets |
| Offline shell → partitioned local stores | Learner data may render only after the activation pointer, current partition, strict lease, markers, and cached media agree. | Lesson, outbox, receipt, lease, and partition metadata |
| Browser replay request → Phoenix controller | JSON fields are untrusted; the cookie/current-Scope/CSRF boundary determines authority. | Bounded practice action and correlation fields |
| Current Scope → active lease/product authorization | Cached lease and partition values are correlation data, never authentication or authorization. | Server-owned user, partition, lease, and authorization state |
| Concurrent replay requests → PostgreSQL | A unique terminal identity and transaction prevent duplicate application and inconsistent receipts. | Idempotency key, mutation correlation, terminal outcome |
| Stored terminal receipt → browser UI | Public responses and rendered rows expose learner-safe terminal data only. | Status and terminal timestamp |
| Proof commands → retained evidence | Evidence is published only after the complete proof succeeds and source hashes match. | Fixed booleans and source SHA-256 values |
| Logout/account switch → prior browser state | Prior activation must be invalidated before navigation or a new account can activate local state. | Activation pointer and partitioned learner data |

---

## Threat Register

Plan-local qualifiers are retained for the duplicate `T-247-06`, `T-247-24`, and `T-247-SC` identifiers authored in separate plan files; distinct threats are not collapsed.

| Threat ID | Category | Component | Severity | Disposition | Mitigation / Evidence | Status |
|-----------|----------|-----------|----------|-------------|-----------------------|--------|
| T-247-01 (P01) | Information Disclosure / Elevation of Privilege | Bootstrap, JS, worker, storage, hooks | high | mitigate | Authenticated routes and `current_scope` keep credentials server-side; browser/storage protocol scans are covered by the Chromium proof and `credential_boundary` evidence flag. | closed |
| T-247-02 (P01) | Tampering | Manifest/media promotion | high | mitigate | `installItem` verifies full byte length and SHA-256, awaits cache writes, writes markers last, and `completeGate` requires marker plus response; corrupt/short/write-failure Chromium cases pass. | closed |
| T-247-03 (P01) | Information Disclosure | Account-partitioned local state | high | mitigate | Partition-leading keys, strict lease checks, current activation, and account-isolation Chromium cases prevent prior-account activation. | closed |
| T-247-04 (P01) | Spoofing / Elevation of Privilege | Replay route | high | mitigate | Replay uses cookie/CSRF/current-Scope, derives ownership from the active server lease, and excludes request-selected ownership. | closed |
| T-247-05 (P01) | Tampering / Repudiation | Replay receipt transaction | high | mitigate | PostgreSQL transaction plus unique `(account_partition, idempotency_key)` identity returns the stored terminal row; duplicate and rollback tests pass. | closed |
| T-247-06 (P01) | Information Disclosure / Spoofing | Service-worker navigation fallback | high | mitigate | Worker is explicitly `/app/` scoped, falls back only for `/app/lesson`, caches only generic shell assets, and offline activation requires the complete local gate. | closed |
| T-247-SC (P01) | Tampering | Package installs | low | accept | No dependency was introduced; the phase retained Phoenix/Ecto, browser APIs, and pinned Playwright. | closed |
| T-247-06 (P02) | Tampering | Media fetch/verification | high | mitigate | Full-buffer size and SHA-256 checks reject short and same-size-corrupt media before persistence; direct browser cases pass. | closed |
| T-247-07 (P02) | Tampering / Repudiation | Cache/marker promotion | high | mitigate | Cache completion precedes marker creation, failures remove markers, and direct Cache Storage/IndexedDB assertions prove state. | closed |
| T-247-08 (P02) | Information Disclosure | Worker failure protocol | medium | mitigate | Worker test controls/messages are bounded to non-secret status/counter data; credential and stored-payload fields are excluded by protocol assertions. | closed |
| T-247-09 (P02) | Denial of Service | Cache rejection/quota | medium | mitigate | Cache failure produces an actionable retry state and deterministic injected write-failure coverage proves no false readiness. | closed |
| T-247-SC (P02) | Tampering | Package installs | low | accept | No dependency was introduced. | closed |
| T-247-10 (P03) | Elevation of Privilege | Lease validation | high | mitigate | Positive bounded TTL and strict microsecond `DateTime.compare(as_of, expires_at) == :lt` deny exact expiry; focused context tests pass. | closed |
| T-247-11 (P03) | Spoofing / Information Disclosure | Partition lookup | high | mitigate | Active lease lookup begins with current-Scope user and only then compares the opaque partition; foreign/missing/expired outcomes fail closed. | closed |
| T-247-12 (P03) | Information Disclosure | Logout/account-switch render | high | mitigate | Activation clearing and replacement rendering remove prior lesson/receipt state; LiveView and same-context account-switch cases prove absence. | closed |
| T-247-13 (P03) | Information Disclosure | HTML/bootstrap diagnostics | medium | mitigate | HTML/JSON expose bounded lesson/runtime data, while tests reject credential-bearing and internal diagnostic fields. | closed |
| T-247-SC (P03) | Tampering | Package installs | low | accept | No dependency was introduced. | closed |
| T-247-14 (P04) | Spoofing / Elevation of Privilege | Replay ownership/CSRF | high | mitigate | Existing authenticated browser and CSRF pipelines plus current-Scope lease lookup enforce replay ownership. | closed |
| T-247-15 (P04) | Tampering | Replay input/checkpoint | high | mitigate | Exact scalar allowlist and byte bounds reject malformed/oversized values; checkpoint outcome is server-classified. | closed |
| T-247-16 (P04) | Tampering / Repudiation | Duplicate/concurrent replay | high | mitigate | Unique receipt identity, one transaction, explicit-barrier concurrency, duplicate stability, and rollback recovery tests pass. | closed |
| T-247-17 (P04) | Information Disclosure | Replay response | medium | mitigate | Controller response is limited to client correlation, terminal status, and timestamp; owner/partition/credential internals are omitted. | closed |
| T-247-18 (P04) | Denial of Service | Oversized replay input | medium | mitigate | Identifier and answer byte limits reject non-scalar and oversized input before transaction work. | closed |
| T-247-SC (P04) | Tampering | Package installs | low | accept | No dependency was introduced. | closed |
| T-247-19 (P05) | Information Disclosure | Account switch/local storage | high | mitigate | Partition-leading records, current bootstrap checks, immediate replacement, and account-switch browser proof prevent cross-account rendering. | closed |
| T-247-20 (P05) | Elevation of Privilege | Expired lease activation/replay | high | mitigate | Strict client and server expiry checks suppress activation/action/replay at the exact boundary; expiry tests pass. | closed |
| T-247-21 (P05) | Information Disclosure | Outbox record | high | mitigate | Outbox uses a bounded field schema; direct IndexedDB assertions exclude cookie/token/credential/digest fields. | closed |
| T-247-22 (P05) | Tampering | Invalid offline action | medium | mitigate | Required bounded values are validated before any outbox record; invalid-input Chromium proof retains input and creates no row. | closed |
| T-247-23 (P05) | Denial of Service / Accessibility | Small viewport/theme states | medium | mitigate | Shared-token responsive CSS, native/text controls, and deterministic 320px plus Light/Dark/System cases pass. | closed |
| T-247-24 (P05) | Information Disclosure / Spoofing | Logout/account-switch followed by offline reload | high | mitigate | Logout awaits activation deletion; offline shell stays generic and requires current partition, lease, markers, and cached media before rendering data. | closed |
| T-247-SC (P05) | Tampering | Package installs | low | accept | No dependency was introduced. | closed |
| T-247-24 (P06) | Tampering / Repudiation | Receipt reconciliation | high | mitigate | Stable local correlation accepts only server terminal responses, preserves the first terminal state/timestamp, and renders one row; replay matrix passes. | closed |
| T-247-25 (P06) | Information Disclosure | Receipt UI/hooks | high | mitigate | Receipt UI exposes learner-safe text and timestamps; tests reject mutation, partition, credential, digest, and authorization internals. | closed |
| T-247-26 (P06) | Tampering / User harm | Conflict/rejection UX | high | mitigate | Distinct recovery text preserves input, focuses Review lesson, and never overwrites conflict/rejection with false acceptance. | closed |
| T-247-27 (P06) | Tampering / Repudiation | Evidence publication | high | mitigate | The proof runner requires complete ExUnit/Chromium success, validates exact keys/current hashes, and atomically renames the evidence last. | closed |
| T-247-28 (P06) | Information Disclosure | Evidence/diagnostics | high | mitigate | Evidence contains fixed booleans and source hashes only; its exact-key validator rejects runtime identity, credential, digest, and media payload categories. | closed |
| T-247-29 (P06) | Denial of Service | Long content/320px | medium | mitigate | Deterministic wrapping, geometry, focus, and role assertions cover every approved small-screen backstop. | closed |
| T-247-SC (P06) | Tampering | Package installs | low | accept | No dependency was introduced; existing Playwright/axe availability is unchanged. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*  
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-247-01 | T-247-SC (P01–P06) | The package-install threat was accepted in every plan because Phase 247 added no dependency or package surface. | Phase 247 plan contracts | 2026-08-19 |

---

## Security Audit 2026-08-19

| Metric | Count |
|--------|-------|
| Threats found | 37 |
| Closed | 37 |
| Open | 0 |

The register was authored at plan time. With ASVS Level 1 and no preliminary open threats, the secure-phase workflow applied its grep-depth short circuit; no deeper auditor run was required. Evidence includes the passed 19-test focused ExUnit suite, 18-case Chromium matrix, exact-key/source-bound `247-EVIDENCE.json`, clean code review, and passed phase verification.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-19 | 37 | 37 | 0 | Codex secure-phase orchestrator |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-19
