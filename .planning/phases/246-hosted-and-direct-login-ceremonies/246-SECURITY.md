---
phase: 246
slug: hosted-and-direct-login-ceremonies
status: verified
# threats_open counts OPEN threats at or above workflow.security_block_on (high).
threats_open: 0
asvs_level: 1
created: 2026-08-16
---

# Phase 246 — Security

> Per-phase security contract for hosted and direct first-party app-login ceremonies. This audit verifies the plan-time STRIDE register against completed implementation and deterministic evidence at ASVS L1 depth.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Native client → public ceremony routes | A first-party client starts hosted login or submits direct credentials and MFA factors. | Profile ID, callback, state, PKCE challenge/verifier, password, opaque MFA challenge, factor selector |
| Browser → hosted approval routes | An authenticated browser resumes, approves, or cancels a signed hosted continuation. | Signed continuation, CSRF token, server-owned session identity, approval decision |
| Phoenix transport → Sigra facade | Generated controllers and LiveViews decode bounded scalar input before calling the library. | Untrusted request parameters become fixed atoms and validated facade arguments |
| Sigra facade → host-owned callbacks/config | The library uses finite static profiles and host-provided password/MFA verification callbacks. | Trusted profile policy, user identity, verifier result, registered callback |
| Application → PostgreSQL | Ceremony attempts, approval decisions, audits, and opaque app-session families cross the persistence boundary. | Digests, trusted bindings, lifecycle timestamps, bounded audit facts; never raw bearer secrets |
| Transaction → post-commit response | Raw authorization codes and app-session credentials may leave transaction-local state only after successful commit. | Short-lived authorization code, access token, refresh token |
| Installer templates → generated host | Feature flags and templates emit routes, schemas, migrations, and auth-continuation code into adopter applications. | Server-owned configuration and generated security controls |
| CI proof host → retained evidence | Disposable generated hosts exercise real PostgreSQL ceremonies and publish bounded evidence. | Boolean transition facts, source hashes, immutable run provenance; no cookies, tokens, or secrets |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation / Evidence | Status |
|-----------|----------|-----------|----------|-------------|-----------------------|--------|
| T-246-01 | Elevation of Privilege | hosted exchange | high | mitigate | Digest-addressed `FOR UPDATE`, binding checks, terminal transition, and issuance share one `Ecto.Multi`; `246-01-SUMMARY.md`, `app_login_test.exs`. | closed |
| T-246-02 | Information Disclosure | post-commit result | high | mitigate | Persistence is digest-only and raw credentials are returned only after the outer transaction commits; `246-01-SUMMARY.md`. | closed |
| T-246-03 | Tampering | persistence/audit fault | medium | mitigate | Constraint-fault tests prove rollback restores the code and creates no credential family; `246-01-SUMMARY.md`. | closed |
| T-246-04 | Spoofing | profile/callback lookup | high | mitigate | Finite static profile lookup and literal callback equality precede state creation; `246-02-SUMMARY.md`. | closed |
| T-246-05 | Tampering | continuation/state/PKCE | high | mitigate | Expiry-bound signed continuation, state binding, and strict S256 validation are covered by hosted-login tests; `246-02-SUMMARY.md`. | closed |
| T-246-06 | Elevation of Privilege | browser approval | high | mitigate | Every browser path requires an explicit approve action before code persistence; `246-02-SUMMARY.md`. | closed |
| T-246-07 | Elevation of Privilege | concurrent exchange | high | mitigate | Barrier-controlled PostgreSQL race proves one terminal transition and one issued session; `246-03-SUMMARY.md`. | closed |
| T-246-08 | Repudiation | hosted audit | medium | mitigate | Bounded audit co-fates with issuance and telemetry occurs after commit; `246-03-SUMMARY.md`. | closed |
| T-246-09 | Information Disclosure | fault paths | high | mitigate | Fault coverage excludes raw secrets from results, stored rows, audit metadata, telemetry, and errors; `246-03-SUMMARY.md`. | closed |
| T-246-10 | Information Disclosure | direct failures | high | mitigate | Direct failure cases share the exact public denial domain; `246-04-SUMMARY.md`, `app_login_direct_test.exs`. | closed |
| T-246-11 | Elevation of Privilege | MFA challenge | high | mitigate | Digest-only, user/profile-bound, five-minute, row-locked, single-use challenge completes in the issuance transaction; `246-04-SUMMARY.md`. | closed |
| T-246-12 | Spoofing | browser-required policy | high | mitigate | Static browser-required policy is evaluated before password verification; `246-04-SUMMARY.md`. | closed |
| T-246-13 | Elevation of Privilege | MFA race | high | mitigate | Two-caller PostgreSQL proof permits one MFA completion and one family; `246-05-SUMMARY.md`. | closed |
| T-246-14 | Information Disclosure | error normalization | high | mitigate | Exact serialized response equality is tested across credential, policy, challenge, factor, and fault failures; `246-05-SUMMARY.md`. | closed |
| T-246-15 | Repudiation | rollback/audit | medium | mitigate | Audit co-fates with challenge consumption and post-commit telemetry is bounded; `246-05-SUMMARY.md`. | closed |
| T-246-16 | Elevation of Privilege | feature implication | high | mitigate | Installer matrix is exhaustive and password login without app sessions fails closed; `246-06-SUMMARY.md`. | closed |
| T-246-17 | Tampering | migration allocation | medium | mitigate | Runner-owned deterministic migration slots and rerun assertions prevent allocation drift; `246-06-SUMMARY.md`. | closed |
| T-246-18 | Tampering | generated attempt schema | high | mitigate | Exact generated fields/indexes and digest-only storage are pinned by source tests; `246-07-SUMMARY.md`. | closed |
| T-246-19 | Spoofing | static profiles | high | mitigate | Generated profiles, clients, and callbacks are finite and server-owned, with no registration or secret surface; `246-07-SUMMARY.md`. | closed |
| T-246-20 | Elevation of Privilege | direct delegate emission | high | mitigate | Direct delegate emission has a separate feature predicate and negative inventory assertions; `246-07-SUMMARY.md`. | closed |
| T-246-21 | Information Disclosure | callback/headers/logs | high | mitigate | Redirects use stored callbacks, no-referrer policy, parameter redaction, and no browser credential transport; `246-08-SUMMARY.md`. | closed |
| T-246-22 | CSRF / Tampering | approve/cancel | high | mitigate | Browser pipeline and CSRF protections wrap signed one-time continuations, strict methods, and scalar keys; `246-08-SUMMARY.md`. | closed |
| T-246-23 | Denial of Service | public ceremony routes | medium | mitigate | Dedicated generated rate-limit pipelines have source and runtime coverage; `246-08-SUMMARY.md`. | closed |
| T-246-24 | Elevation of Privilege | login/MFA resume | high | mitigate | Continuation resumes fixed approval only after normal browser login or MFA succeeds; `246-09-SUMMARY.md`. | closed |
| T-246-25 | Tampering | generated-host evidence | high | mitigate | Disposable host/database, exact commands, receipt-last source hashes, and retained failures bind evidence; `246-10-SUMMARY.md`, `246-RUNTIME-PROOF.json`. | closed |
| T-246-26 | Elevation of Privilege | credential feature residue | high | mitigate | Four feature combinations have exact inventories and absent-route probes; `246-10-SUMMARY.md`. | closed |
| T-246-27 | Repudiation | ownership claims | medium | mitigate | Normative ownership and scope prohibitions are machine checked; `246-10-SUMMARY.md`. | closed |
| T-246-28 | Tampering | signed continuation | high | mitigate | Expired or tampered continuations are cleared and cannot use a callback; `246-09-SUMMARY.md`. | closed |
| T-246-29 | Elevation of Privilege | generated hosted approval | high | mitigate | Only trusted `:standard`/`:remember_me` sessions can approve; `:mfa_pending` cannot render or submit; `246-11-SUMMARY.md`. | closed |
| T-246-30 | Tampering | hosted attempt persistence | high | mitigate | Generated successful routes persist the required typed `:hosted_code` attempt row; `246-11-SUMMARY.md`. | closed |
| T-246-31 | Tampering | continuation/callback | high | mitigate | Generated MFA carries only the signed handle and preserves literal callback, state, S256, CSRF, and no-referrer checks; `246-11-SUMMARY.md`. | closed |
| T-246-32 | Repudiation | hosted runtime receipt | medium | mitigate | Receipt-last generated-route assertions make evidence causal; `246-11-SUMMARY.md`. | closed |
| T-246-33 | Tampering | factor decoder | high | mitigate | Factor input is a literal two-value scalar mapping with no dynamic atom/module/callback conversion; `246-12-SUMMARY.md`. | closed |
| T-246-34 | Information Disclosure | invalid factor responses | high | mitigate | Invalid factor responses match all other direct failures in status, body, and headers; `246-12-SUMMARY.md`. | closed |
| T-246-35 | Elevation of Privilege | backup-code completion | high | mitigate | Bound digest challenge, locked backup-code consumption, and session issuance share one transaction; `246-12-SUMMARY.md`. | closed |
| T-246-36 | Repudiation | direct runtime evidence | medium | mitigate | Proof checks persisted factor/challenge consumption before receipt generation; `246-12-SUMMARY.md`. | closed |
| T-246-37 | Spoofing | protected proof route | high | mitigate | Proof authenticates only through generated `FetchAppSession` and asserts bounded trusted session facts; `246-13-SUMMARY.md`. | closed |
| T-246-38 | Elevation of Privilege | hosted/direct replay | high | mitigate | Real-route replay is rejected with exactly one family while the original credential stays valid; `246-13-SUMMARY.md`, runtime receipt. | closed |
| T-246-39 | Information Disclosure | proof response/logs | high | mitigate | Proof responses and retained facts exclude credentials, digests, callbacks, state, challenges, client references, and account secrets; `246-13-SUMMARY.md`. | closed |
| T-246-40 | Tampering / Repudiation | receipt and CI | high | mitigate | Per-transition booleans, exact source hashes, CI parsing, and receipt-last failure semantics bind proof; `246-13-SUMMARY.md`. | closed |
| T-246-41 | Elevation of Privilege | controller/LiveView MFA completion | high | mitigate | Trusted pending-session lookup and rotation through the canonical session seam are executable in both generated transports; `246-14-SUMMARY.md`. | closed |
| T-246-42 | Tampering | LiveView completion transport | high | mitigate | CSRF-protected server state rejects missing and mismatched pending sessions; `246-14-SUMMARY.md`. | closed |
| T-246-43 | Information Disclosure | continuation preservation | medium | mitigate | Only the signed handle survives auth; callback, state, factor, and credential values are absent from flash/log/markup; `246-14-SUMMARY.md`. | closed |
| T-246-44 | Elevation of Privilege | `approve_hosted/5` replay | high | mitigate | A high-entropy nonce digest has a unique database claim and duplicate approval normalizes to invalid continuation; `246-15-SUMMARY.md`. | closed |
| T-246-45 | Tampering | approval transaction | high | mitigate | Digest consumption and hosted-code creation are atomic with rollback proof; `246-15-SUMMARY.md`. | closed |
| T-246-46 | Information Disclosure | nonce/code handling | high | mitigate | Raw nonce is signed, only its digest persists, and the code leaves only after commit with bounded telemetry; `246-15-SUMMARY.md`. | closed |
| T-246-47 | Repudiation | approval replay result | medium | mitigate | Row counts and deterministic sequential/fault evidence make the single-use outcome observable; `246-15-SUMMARY.md`. | closed |
| T-246-48 | Tampering | generated migration/schema | high | mitigate | Prefix-aware and unprefixed migrations emit a binary digest and stable unique index; `246-16-SUMMARY.md`. | closed |
| T-246-49 | Elevation of Privilege | concurrent hosted approval | high | mitigate | Barrier race permits exactly one persisted code/session result; `246-16-SUMMARY.md`. | closed |
| T-246-50 | Information Disclosure | generated attempt row | medium | mitigate | Generated storage retains only the digest and source assertions exclude raw nonce/code/verifier/password/secrets; `246-16-SUMMARY.md`. | closed |
| T-246-51 | Spoofing | installer feature selection | medium | mitigate | APP-01 inventory proves unrelated feature surfaces remain absent; `246-16-SUMMARY.md`. | closed |
| T-246-52 | Spoofing | FetchAppSession equivalence proof | high | mitigate | Both real generated credentials authenticate through the same protected route with matching bounded facts; `246-17-SUMMARY.md`, runtime receipt. | closed |
| T-246-53 | Elevation of Privilege | MFA/replay/browser-policy journeys | high | mitigate | PostgreSQL-backed proof covers MFA rotation, approval/direct replay, and pre-verifier browser policy before receipt publication; `246-17-SUMMARY.md`. | closed |
| T-246-54 | Information Disclosure | CI artifact and retained JSON | high | mitigate | Retained artifacts are allowlisted/redaction-checked and contain only hashes, provenance, and booleans; `246-17-SUMMARY.md`, `246-RUNTIME-PROOF-RUN.json`. | closed |
| T-246-55 | Tampering / Repudiation | durable CI evidence | high | mitigate | One exact-head run is bound to immutable SHA and artifact provenance, with failures retained and no ambiguous redispatch; `246-17-SUMMARY.md`. | closed |
| T-246-SC | Tampering | pinned Actions/Phoenix setup | medium | mitigate | Pinned action SHAs and the audited Phoenix archive remain unchanged; no dependency was added; `246-17-SUMMARY.md`. | closed |
| T-246-56 | Elevation of Privilege | `MFAChallengeController.create/2` | high | mitigate | Generated controller binds a trusted current-user `:mfa_pending` row before either one-time verifier; `246-18-SUMMARY.md`. | closed |
| T-246-57 | Tampering | TOTP/backup one-time state | high | mitigate | Regressions prove rejected session authority cannot consume TOTP replay or backup-code state; `246-18-SUMMARY.md`. | closed |
| T-246-58 | Spoofing | current user/session binding | high | mitigate | Missing, malformed, foreign-user, ordinary, and terminal sessions fail before verification or rotation; `246-18-SUMMARY.md`. | closed |
| T-246-59 | Information Disclosure | browser recovery | low | accept | Existing generic MFA recovery is unchanged and discloses no factor/session reason or app-login protocol fact; accepted in `246-18-PLAN.md`. | closed |
| T-246-60 | Elevation of Privilege | copied signed continuation | high | mitigate | Cancellation commits a terminal row under the shared nonce digest, so copied continuations cannot later mint a code; `246-19-SUMMARY.md`. | closed |
| T-246-61 | Tampering | approve-versus-cancel race | high | mitigate | One PostgreSQL unique constraint selects the sole terminal decision; barrier tests assert state/result invariants; `246-19-SUMMARY.md`. | closed |
| T-246-62 | Repudiation | hosted decision state | medium | mitigate | Explicit `:hosted_cancel` state persists bounded server-selected bindings with no raw nonce or code; `246-19-SUMMARY.md`. | closed |
| T-246-63 | Information Disclosure | cancellation/error response | high | mitigate | Cancellation returns no callback/code/state/credential and retains the generic HTTP 400 surface; `246-19-SUMMARY.md`. | closed |
| T-246-64 | Denial of Service | duplicate decision submissions | low | accept | Duplicate authenticated CSRF-protected decisions incur one bounded unique-constraint rejection with no retry loop or queue; accepted in `246-19-PLAN.md`. | closed |

*Status: open · closed · open — below high threshold (non-blocking).*

*Severity: critical > high > medium > low. Only open threats at or above `workflow.security_block_on: high` count toward `threats_open`.*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-246-01 | T-246-59 | Generic MFA recovery is an existing bounded surface; the phase adds no factor/session reason or app-login fact to it. Residual disclosure likelihood and impact are low. | Phase 246 Plan 18 approval | 2026-08-16 |
| AR-246-02 | T-246-64 | A duplicate decision performs one bounded database rejection on an authenticated, CSRF-protected route; it adds no unbounded retry or queued work. Residual availability impact is low. | Phase 246 Plan 19 approval | 2026-08-16 |

Accepted risks are closed dispositions and do not count toward `threats_open`.

---

## Security Audit 2026-08-16

| Metric | Count |
|--------|-------|
| Threats found | 65 |
| Closed | 65 |
| Open | 0 |

### Audit Basis

- Register origin: plan-time threat models in all 19 `246-*-PLAN.md` files.
- Evidence: matching completed `246-*-SUMMARY.md` files, deterministic focused tests recorded there, and the source-bound generated-host runtime receipt/provenance.
- Summary threat flags: no unresolved flags reported.
- Verification depth: ASVS L1. The clean-register short-circuit applies; no deeper boundary-placement auditor was required.
- Blocking threshold: high. No open threat exists at any severity.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-16 | 65 | 65 | 0 | Codex secure-phase orchestrator |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-16
