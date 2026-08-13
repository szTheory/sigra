# Phase 246 — Multi-Source Coverage Audit

The nine locked bullets in `246-CONTEXT.md` are enumerated in source order as D-01 through D-09 for plan traceability.

| SOURCE | ID | Feature / Constraint | Plans | Status | Notes |
|---|---|---|---|---|---|
| GOAL | — | Independently selected first-party app sessions obtainable through hosted or policy-gated direct login | 01–10 | COVERED | Library tracer, generator, transport, and fresh-host proof |
| REQ | APP-01 | Independent `--app-sessions`, separately gated `--app-password-login`, API/JWT isolation | 06, 07, 10 | COVERED | Exhaustive matrix plus fresh-host absent-route/file proof |
| REQ | APP-02 | Hosted system-browser PKCE/state/exact callback/explicit continuation/60s one-time atomic exchange | 01, 02, 03, 07–10 | COVERED | Service, generated route, auth continuation, concurrency/fault, fresh-host proof |
| REQ | APP-03 | Optional direct uniform password/MFA, opaque 5m challenge, same session or browser-required | 04, 05, 07–10 | COVERED | Service, route, auth continuation, fault/concurrency, fresh-host proof |
| CONTEXT | D-01 | Independent generator flags and password→app prerequisite only | 06, 07, 10 | COVERED | No optional feature implication |
| CONTEXT | D-02 | Static public profiles, exact callbacks/policy, no client secrets | 02, 07, 10 | COVERED | Config-only profiles; DB only for ceremony state |
| CONTEXT | D-03 | System browser, state, S256, exact callback, explicit continuation, 60s one-time code | 01–03, 08–10 | COVERED | Literal callbacks include only explicitly registered loopback ports |
| CONTEXT | D-04 | One centralized continuation across controller, LiveView, and MFA | 02, 08–10 | COVERED | Shared signed bounded helper and one approval route |
| CONTEXT | D-05 | Direct first-party host feature with uniform failures, not password grant | 04, 05, 08, 10 | COVERED | Exact public response equality tests |
| CONTEXT | D-06 | Opaque digest-only profile/user-bound single-use MFA within five minutes | 04, 05, 07, 10 | COVERED | Exact 300-second boundary and race proof |
| CONTEXT | D-07 | Host policy returns browser-required before authentication/issuance | 04, 05, 07, 08, 10 | COVERED | Callback invocation counters prove ordering |
| CONTEXT | D-08 | Both successes call Phase 245 `Sigra.AppSession.issue/4` contract | 01, 04, 07, 10 | COVERED | Composable internal Multi retains public facade parity |
| CONTEXT | D-09 | Consumption, issuance, optional audit co-fate; locks; post-commit secrets; no-sleep barriers | 01, 03–05, 10 | COVERED | Real PostgreSQL fault and concurrency evidence |
| RESEARCH | architecture | Dedicated library ceremony core with host-owned schemas/static profiles/thin controllers | 01, 02, 07–09 | COVERED | Matches responsibility map |
| RESEARCH | callback resolution | Literal registered callback strings; no variable-port exception/normalization | 02, 08, 10 | COVERED | Recorded in Planning Resolutions |
| RESEARCH | continuation resolution | One signed expiring seam shared by LiveView/controller/MFA | 02, 08–10 | COVERED | Recorded in Planning Resolutions |
| RESEARCH | profile resolution | Static host module/config, PostgreSQL only for code/challenge state | 02, 07 | COVERED | No dynamic registry/UI |
| RESEARCH | security | Exact redirect, state/S256, digest storage, row locks, uniform errors, bounded audit | 01–05, 07–10 | COVERED | STRIDE mitigations and tests in each plan |
| RESEARCH | dependencies | Existing Sigra/Ecto/Phoenix/OTP primitives; no external packages | all | COVERED | No install task or package checkpoint |

## Reachability Audit

| Artifact / behavior | Reachability path | Status |
|---|---|---|
| Static profile | installer selection → generated `FirstPartyApps` → generated delegate → library config validation | REACHABLE |
| Hosted code | generated start route → normal browser login/MFA → explicit approval → callback → exchange route | REACHABLE |
| Direct MFA challenge | separately emitted direct route → host password verifier → challenge row → MFA completion route | REACHABLE |
| App session | hosted exchange or direct success → composable Phase 245 issue Multi → response after commit → `FetchAppSession` protected route | REACHABLE |
| Fresh-host evidence | Plan 10 dedicated CI/runtime script → exact-SHA receipt after real route matrix | REACHABLE |

## Scope-Fence Result

Excluded without gaps: OAuth/OIDC authorization-server behavior, consent/discovery/JWKS/dynamic registration, external delegated tokens, Lockspire source, Crosswake changes, embedded WebView, native SDK/runtime, PWA/offline/media, Electron runtime/package, request-selected scopes/authority, plaintext ceremony secrets, wildcard/normalized callbacks, client secrets, and admin/operator UI. No deferred idea is planned. No source item is missing and no phase split is required.
