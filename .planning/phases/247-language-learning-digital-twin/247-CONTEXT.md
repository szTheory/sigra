# Phase 247: Language-Learning Digital Twin - Context

**Gathered:** 2026-08-18 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver one bounded language-learning PWA lesson in the existing Phoenix example host. The lesson contains structured data, one image, and one audio asset; remains usable under an account-bound offline lease; verifies immutable media before reporting it available; isolates all local state by account; and replays queued actions only after current backend reauthorization with one durable terminal outcome. This phase does not make cached data an authentication authority and does not generalize the proof into an offline framework, SDK, native runtime, or Crosswake adapter.

</domain>

<decisions>
## Implementation Decisions

### Session and lesson authority
- **D-01:** Extend the existing authenticated browser experience rooted at `/app` and use only Sigra's secure HttpOnly cookie-backed browser session. Page JavaScript and the service worker must never receive, store, derive, or forward an app-session, PAT, JWT, refresh token, or other credential.
- **D-02:** The Phoenix host owns lesson authorization, lesson data, media policy, offline leases, account partition identifiers, and replay decisions. Cached lesson data grants no server authority.

### Verified immutable media
- **D-03:** The host provides a versioned immutable lesson/media manifest containing the trusted URL, expected byte size, and SHA-256 for the single image and audio asset.
- **D-04:** The PWA fully reads each media response, checks its exact byte length, computes and compares SHA-256, then awaits a successful Cache Storage write. Only after that succeeds may it write an account-partitioned IndexedDB availability marker.
- **D-05:** Media is reported offline-ready only when both the matching availability marker and cached response exist. Marker-last promotion is the fail-closed cross-API convention: failed reads, digest mismatch, short content, cache rejection, or quota exhaustion must never create a ready marker; an orphan cache entry after interruption remains unavailable.

### Account-bound lease and local isolation
- **D-06:** The Phoenix host issues an opaque account partition and an account-bound offline lease with a host-configurable seven-day default. The lease permits bounded local lesson use only; it is not an authentication credential and cannot authorize replay.
- **D-07:** Lesson state, media metadata, availability markers, and every outbox entry are keyed or namespaced by the host-provided account partition. A missing, expired, or changed partition fails closed.
- **D-08:** Logout and account switch must prevent activation, display, or replay of the prior account's local state. Physical immutable cache bytes may remain for bounded storage reuse only when they are unreachable without matching account metadata and a current valid lease.

### Backend-reauthorized exactly-once replay
- **D-09:** Queued actions use stable Crosswake-compatible vocabulary and identity fields: `client_mutation_id`, idempotency key, base checkpoint, and terminal `accepted`, `rejected`, or `conflict` outcomes. Phase 247 adds the required account partition locally.
- **D-10:** Reconnect submits queued actions to a host endpoint that reloads the current Sigra Scope, verifies the active account partition and current product authorization, and durably records exactly one terminal outcome per action. Retries return the existing outcome and never apply the action twice.
- **D-11:** Reuse Crosswake-compatible semantics without coupling the PWA implementation to new Crosswake modules or adapter proof. Released-package integration and native/Crosswake runtime evidence remain Phase 248.

### Deterministic proof
- **D-12:** Prove the phase through the repository's pinned Chromium/Playwright runtime using stable readiness hooks or a bounded worker message protocol, pre-armed event/response waits, direct Cache Storage and IndexedDB inspection, and browser-context offline control. Do not use sleeps or human UAT.
- **D-13:** Exercise valid, short, same-size corrupt, interrupted/write-failure, offline, lease-expiry, logout, account-switch, reconnect, duplicate-replay, rejected, and conflict paths. Chromium quota forcing may supplement proof but, because it is experimental and browser-specific, must not be the only cache-write-failure evidence.

### the agent's Discretion
- Exact Phoenix context/module/controller/LiveView boundaries, database schema names, endpoint paths, service-worker filename, cache names, IndexedDB schema, and internal helper names.
- Exact lesson copy and UI composition, provided it remains a bounded host example, uses the existing Tasklane/example-app presentation patterns, and visibly distinguishes installed, unavailable, expired, rejected, and conflicted states.
- Exact immutable URL/versioning format and readiness-hook shape, provided the integrity, partition, lease, credential, replay, and deterministic-test boundaries above remain mechanically provable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` § Phase 247 — fixed goal, success criteria, and Phase 248 boundary.
- `.planning/REQUIREMENTS.md` § Language-Learning Digital Twin — normative TWIN-01, OFF-01, and OFF-02 requirements and explicit out-of-scope capabilities.
- `.planning/PROJECT.md` § Current Milestone: v1.49 FIRST-PARTY-CLIENT-READINESS — bounded digital-twin intent and deferral of generalized offline behavior.
- `.planning/METHODOLOGY.md` — decisive-defaulting, escalation, research-depth, UX, and proof-truth lenses that constrain planning.

### Ownership and offline architecture
- `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-CONTEXT.md` — locked Sigra, Phoenix host, Crosswake, and Lockspire ownership boundary.
- `.planning/phases/245-opaque-app-session-core/245-CONTEXT.md` — app-session lifecycle boundary; PWA/offline behavior is outside the app-session core.
- `.planning/phases/246-hosted-and-direct-login-ceremonies/246-CONTEXT.md` — login-ceremony boundary and unchanged PWA/native scope separation.
- `.planning/research/ARCHITECTURE.md` § Digital-Twin Flow — account-bound lease, immutable manifest, verified promotion, Crosswake vocabulary ownership, and backend reauthorization.
- `.planning/research/STACK.md` § Platform Patterns / What Not to Add — existing PWA cookie session and prohibition on persistent browser bearer credentials.
- `.planning/research/PITFALLS.md` — cached-authority, cross-account isolation, logout/account-switch, and replay failure modes.

### Browser and automation standards
- `https://www.w3.org/TR/WebCryptoAPI/` — SHA-256 digest semantics.
- `https://fetch.spec.whatwg.org/` — complete body-consumption behavior used before verification.
- `https://w3c.github.io/ServiceWorker/` — Cache Storage write and batch-failure semantics.
- `https://storage.spec.whatwg.org/` — quota pressure, best-effort storage, and eviction posture.
- `https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/service-workers-js-python.md` — pinned Playwright service-worker control and inspection behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/example/lib/example_web/live/app_live.ex` — authenticated `/app` host surface with real `current_scope`, existing Tasklane/example-app UI vocabulary, and stable test hooks.
- `test/example/lib/example_web/router.ex` — browser pipeline, authenticated LiveView session, CSRF protection, secure headers, and current-Scope loading.
- `test/example/lib/example_web/endpoint.ex` — signed/encrypted HttpOnly SameSite=Lax browser cookie and static asset serving.
- `test/example/lib/example_web/user_auth.ex` and `test/example/lib/example_web/controllers/session_controller.ex` — existing logout/session renewal and current-account authority seams.
- `test/example/priv/playwright/playwright.config.ts` and `test/example/priv/playwright/package-lock.json` — deterministic Chromium harness pinned to Playwright 1.59.1.
- `test/example/deps/crosswake/lib/crosswake/offline/journal.ex` and `test/example/deps/crosswake/lib/crosswake/offline/replay.ex` — released journal/replay vocabulary to mirror without introducing Phase 248 adapter coupling.

### Established Patterns
- Example-host behavior derives identity from server-owned `current_scope`; request data never selects the authenticated owner.
- Security-sensitive proof is automation-first, bounded, receipt/evidence oriented, and uses stable readiness rather than sleeps.
- Host-owned product behavior stays in `test/example`; Sigra library code remains responsible for authentication/session correctness, not curricula, media, leases, or replay policy.
- Retained diagnostics must be bounded and must not include credentials, raw cookie values, or unnecessary learner data.

### Integration Points
- Add the lesson entry and authenticated lesson/data/replay routes beneath the existing browser/current-Scope boundary.
- Register and serve a bounded service worker and immutable lesson media through the example endpoint/static paths without exposing the HttpOnly cookie to worker code.
- Persist replay idempotency and terminal outcomes in host-owned Ecto state so reconnect retries can return prior results exactly once.
- Extend the existing example Playwright suite to control worker readiness, network corruption/offline states, storage partitions, account transitions, and replay receipts deterministically.

</code_context>

<specifics>
## Specific Ideas

- Use marker-last promotion across Cache Storage and IndexedDB: verified cache write first, account-partitioned availability marker second.
- Mirror Crosswake's `client_mutation_id`, idempotency key, base checkpoint, and `accepted` / `rejected` / `conflict` terms so Phase 248 can integrate without redefining the contract.
- Keep browser proof in one context across logout/account switch so the test demonstrates that old local bytes remain inaccessible, plus use a separate fresh context only as an independent isolation control.
- Expose a stable non-secret readiness/state hook or worker message protocol so Playwright never waits by elapsed time.

</specifics>

<deferred>
## Deferred Ideas

- Released Crosswake module/adapter integration, Crosswake route projection, and native-runtime proof — Phase 248.
- Physical-iPhone and Android-emulator execution, credential-store proof, and kill/relaunch evidence — Phase 248.
- Generic offline sync, background sync, generalized media caching/storage adapters, additional lessons/offline islands, and published client SDKs — future requirements only after adopter evidence.
- Electron runtime/package implementation — outside this milestone's packaged scope; Phase 249 defines contract coverage only.

### Reviewed Todos (not folded)

None — no phase-matching todos were found.

</deferred>

---

*Phase: 247-language-learning-digital-twin*
*Context gathered: 2026-08-18*
