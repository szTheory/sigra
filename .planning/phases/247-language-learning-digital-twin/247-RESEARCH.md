# Phase 247: Language-Learning Digital Twin - Research

**Researched:** 2026-08-18
**Domain:** Phoenix-hosted PWA offline island with integrity-verified media and backend-authorized replay
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Session and lesson authority
- **D-01:** Extend the existing authenticated browser experience rooted at `/app` and use only Sigra's secure HttpOnly cookie-backed browser session. Page JavaScript and the service worker must never receive, store, derive, or forward an app-session, PAT, JWT, refresh token, or other credential.
- **D-02:** The Phoenix host owns lesson authorization, lesson data, media policy, offline leases, account partition identifiers, and replay decisions. Cached lesson data grants no server authority.

#### Verified immutable media
- **D-03:** The host provides a versioned immutable lesson/media manifest containing the trusted URL, expected byte size, and SHA-256 for the single image and audio asset.
- **D-04:** The PWA fully reads each media response, checks its exact byte length, computes and compares SHA-256, then awaits a successful Cache Storage write. Only after that succeeds may it write an account-partitioned IndexedDB availability marker.
- **D-05:** Media is reported offline-ready only when both the matching availability marker and cached response exist. Marker-last promotion is the fail-closed cross-API convention: failed reads, digest mismatch, short content, cache rejection, or quota exhaustion must never create a ready marker; an orphan cache entry after interruption remains unavailable.

#### Account-bound lease and local isolation
- **D-06:** The Phoenix host issues an opaque account partition and an account-bound offline lease with a host-configurable seven-day default. The lease permits bounded local lesson use only; it is not an authentication credential and cannot authorize replay.
- **D-07:** Lesson state, media metadata, availability markers, and every outbox entry are keyed or namespaced by the host-provided account partition. A missing, expired, or changed partition fails closed.
- **D-08:** Logout and account switch must prevent activation, display, or replay of the prior account's local state. Physical immutable cache bytes may remain for bounded storage reuse only when they are unreachable without matching account metadata and a current valid lease.

#### Backend-reauthorized exactly-once replay
- **D-09:** Queued actions use stable Crosswake-compatible vocabulary and identity fields: `client_mutation_id`, idempotency key, base checkpoint, and terminal `accepted`, `rejected`, or `conflict` outcomes. Phase 247 adds the required account partition locally.
- **D-10:** Reconnect submits queued actions to a host endpoint that reloads the current Sigra Scope, verifies the active account partition and current product authorization, and durably records exactly one terminal outcome per action. Retries return the existing outcome and never apply the action twice.
- **D-11:** Reuse Crosswake-compatible semantics without coupling the PWA implementation to new Crosswake modules or adapter proof. Released-package integration and native/Crosswake runtime evidence remain Phase 248.

#### Deterministic proof
- **D-12:** Prove the phase through the repository's pinned Chromium/Playwright runtime using stable readiness hooks or a bounded worker message protocol, pre-armed event/response waits, direct Cache Storage and IndexedDB inspection, and browser-context offline control. Do not use sleeps or human UAT.
- **D-13:** Exercise valid, short, same-size corrupt, interrupted/write-failure, offline, lease-expiry, logout, account-switch, reconnect, duplicate-replay, rejected, and conflict paths. Chromium quota forcing may supplement proof but, because it is experimental and browser-specific, must not be the only cache-write-failure evidence.

### the agent's Discretion
- Exact Phoenix context/module/controller/LiveView boundaries, database schema names, endpoint paths, service-worker filename, cache names, IndexedDB schema, and internal helper names.
- Exact lesson copy and UI composition, provided it remains a bounded host example, uses the existing Tasklane/example-app presentation patterns, and visibly distinguishes installed, unavailable, expired, rejected, and conflicted states.
- Exact immutable URL/versioning format and readiness-hook shape, provided the integrity, partition, lease, credential, replay, and deterministic-test boundaries above remain mechanically provable.

### Deferred Ideas (OUT OF SCOPE)
- Released Crosswake module/adapter integration, Crosswake route projection, and native-runtime proof — Phase 248.
- Physical-iPhone and Android-emulator execution, credential-store proof, and kill/relaunch evidence — Phase 248.
- Generic offline sync, background sync, generalized media caching/storage adapters, additional lessons/offline islands, and published client SDKs — future requirements only after adopter evidence.
- Electron runtime/package implementation — outside this milestone's packaged scope; Phase 249 defines contract coverage only.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| TWIN-01 | Authenticated lesson with structured data, image, audio, and no credential exposure to JS/SW. | Existing `/app` authenticated browser boundary, static asset extension, service-worker registration without token plumbing. |
| OFF-01 | Verify byte size and SHA-256 before immutable media is available. | Full `ArrayBuffer` verification, reconstructed `Response`, awaited cache write, marker-last IndexedDB promotion. |
| OFF-02 | Seven-day lease, account-local state/outbox, isolation, and backend-reauthorized exactly-once terminal replay. | Host-issued partition/lease, partition-keyed client stores, server transaction + uniqueness constraint for terminal receipts, Playwright storage/offline proof. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- This is a customer-facing Tasklane example page, not admin UI; use the approved UI contract's `vt-*` BEM/cascade conventions and preserve Light, Dark, and System rendering. [VERIFIED: 247-UI-SPEC.md]
- Use deterministic Playwright automation: role selectors first, stable hooks only when essential, LiveView readiness, pre-armed waits, and no sleeps. [VERIFIED: AGENTS.md]
- Replace UAT with deterministic tests and committed machine-readable evidence; do not waive unprovable requirements. [VERIFIED: AGENTS.md]

## Summary

Implement this as one host-owned offline island beneath the existing authenticated `/app` browser boundary, not as a Sigra feature or generic offline abstraction. The current endpoint's encrypted, HttpOnly, SameSite=Lax cookie and the router's current-Scope authenticated pipeline already provide the only authentication mechanism needed. The service worker may cache public immutable bytes and coordinate readiness, but receives no credentials and never decides authorization. [VERIFIED: test/example/lib/example_web/endpoint.ex] [VERIFIED: test/example/lib/example_web/router.ex]

The critical client invariant is a two-store commit protocol: fetch complete bytes; verify exact size and SHA-256; build a fresh `Response`; await `Cache.put`; then write the matching partitioned ready marker in IndexedDB. At display/activation time require both marker and cache response plus a current matching lease. Web Crypto digest is non-streaming, so the deliberately one-image/one-audio scope makes full-buffer verification appropriate. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest] [CITED: https://developer.mozilla.org/en-US/docs/Web/API/Cache/put]

Replay needs a host Ecto context and durable unique identity scoped by account partition plus idempotency key (and/or client mutation ID). In one database transaction, load the current Scope, revalidate product authorization and partition, lock or insert the receipt, decide exactly one terminal outcome, and return the pre-existing terminal outcome on every retry. This mirrors the existing Crosswake journal vocabulary without importing or extending Crosswake runtime modules. [VERIFIED: test/example/deps/crosswake/lib/crosswake/offline/journal.ex] [VERIFIED: test/example/deps/crosswake/lib/crosswake/offline/replay.ex]

**Primary recommendation:** Build a small `Example.LearningTwin` host context plus authenticated lesson/bootstrap/replay endpoints, a single static worker/client module, partitioned IndexedDB stores, and one dedicated Chromium Playwright proof lane; add no packages.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Browser-session authentication and current identity | API / Backend | Frontend Server (SSR) | Router/UserAuth load the Sigra Scope from the HttpOnly cookie; script/worker never see a credential. [VERIFIED: test/example/lib/example_web/router.ex] |
| Lesson authorization, manifest, partition, lease | API / Backend | Frontend Server (SSR) | Host is the authority for each of these facts and renders/bootstrap-delivers them to the current account. [VERIFIED: 247-CONTEXT.md] |
| Media size/digest verification and cache promotion | Browser / Client | CDN / Static | Browser owns response bytes, Web Crypto, Cache Storage, and IndexedDB; immutable media is served as static/host assets. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest] |
| Offline activation and local outbox | Browser / Client | API / Backend | Client may use a valid local lease but must fail closed; backend is needed only on reconnect. [VERIFIED: 247-CONTEXT.md] |
| Replay idempotency and terminal outcome | API / Backend | Database / Storage | Current Scope and product authorization are server facts; unique durable records prevent duplicate mutation. [VERIFIED: 247-CONTEXT.md] |
| Automated evidence | Browser / Client | API / Backend | Playwright controls network/storage/worker state and asserts UI plus host outcome. [CITED: https://playwright.dev/docs/service-workers] |

## Standard Stack

### Core

| Library / Platform | Version | Purpose | Why Standard |
|---|---|---|---|
| Phoenix LiveView / Plug | existing repository lock | Authenticated lesson presentation and CSRF/current-Scope browser routes | Existing `/app` host surface, authenticated pipeline, and LiveView readiness pattern should be extended. [VERIFIED: test/example/lib/example_web/live/app_live.ex] |
| Ecto + PostgreSQL | existing repository lock; PostgreSQL client 14.17 available | Leases, replay receipt persistence, transaction, lock, unique terminal identity | Existing example host uses Ecto schemas/migrations and PostgreSQL supports the required durable outcome boundary. [VERIFIED: test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs] |
| Browser Web Crypto + Cache Storage + IndexedDB | browser built-ins | SHA-256, immutable bytes, partitioned markers/state/outbox | No package or credential holder is needed; APIs work in secure contexts and workers. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest] [CITED: https://developer.mozilla.org/en-US/docs/Web/API/Cache/put] |
| `@playwright/test` | pinned 1.59.1 (lockfile) | Chromium proof of worker, storage, offline, and account transitions | Existing repository harness already pins this exact runtime. [VERIFIED: test/example/priv/playwright/package-lock.json] |

### Supporting

| Library / Platform | Version | Purpose | When to Use |
|---|---|---|---|
| `@axe-core/playwright` | pinned by existing lockfile | Existing accessibility check helper | Use only if the new dedicated PWA spec extends current axe patterns; it is not required for integrity/replay proof. [VERIFIED: test/example/priv/playwright/package-lock.json] |
| Crosswake offline vocabulary | vendored existing source | Field/status names only | Mirror `client_mutation_id`, idempotency key, base checkpoint, `accepted`, `rejected`, and `conflict`; do not add adapter coupling. [VERIFIED: test/example/deps/crosswake/lib/crosswake/offline/replay.ex] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Explicit marker-last protocol | `Cache.addAll()`/implicit precache | It cannot prove manifest-specific byte/digest verification or cross-API promotion order. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/Cache/put] |
| Foreground reconnect replay | Background Sync / generic sync framework | Deferred; it broadens runtime behavior and makes current-Scope reauthorization evidence less bounded. [VERIFIED: 247-CONTEXT.md] |
| Existing browser cookie session | Browser-accessible app token | Contradicts D-01 and makes the worker a credential sink. [VERIFIED: 247-CONTEXT.md] |

**Installation:** None — use the existing dependencies and browser APIs. [VERIFIED: test/example/priv/playwright/package.json]

## Package Legitimacy Audit

No external package is installed by this phase. Existing pinned `@playwright/test` and optional `@axe-core/playwright` remain unchanged; therefore the package-install gate does not apply. [VERIFIED: test/example/priv/playwright/package-lock.json]

## Architecture Patterns

### System Architecture Diagram

```text
authenticated browser GET /app
  -> Phoenix current Scope + host lesson bootstrap
  -> manifest {immutable URL, byte_size, sha256} + {partition, lease}
  -> page/worker fetch complete media bytes
     -> exact size + SHA-256 match? --no--> unavailable; no marker
     -> yes -> await Cache Storage write
        -> success -> IndexedDB partitioned ready marker -> available
        -> failure -> unavailable; no marker

offline activation
  -> matching partition + unexpired lease + marker + cache response?
     -> yes -> bounded local lesson/outbox
     -> no -> suppress local data and require reconnect/sign-in

reconnect outbox POST (cookie transport only)
  -> Phoenix reloads current Scope + validates partition/authorization
  -> PostgreSQL unique receipt transaction
  -> accepted | rejected | conflict (exactly once) -> same receipt row
```

### Recommended Project Structure

```text
test/example/
├── lib/example/learning_twin/             # host context, lesson/lease/replay schemas
├── lib/example_web/controllers/           # bootstrap, manifest/media, replay JSON endpoints
├── lib/example_web/live/                  # /app lesson entry or nested LiveView component
├── priv/static/assets/                    # worker/client JS and immutable lesson media
├── priv/repo/migrations/                  # lease/replay receipt persistence and uniqueness
├── test/example/learning_twin/            # context/controller/LiveView tests
└── priv/playwright/tests/twin-offline.spec.ts # Chromium integration proof
```

### Pattern 1: Marker-last media promotion
**What:** Verify the complete response before any cache write; create the availability marker only after the cache write resolves. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest]

**When to use:** For each of the exactly two manifest media assets, and only with an authenticated, current-account bootstrap. [VERIFIED: 247-CONTEXT.md]

**Example:**

```typescript
// Source: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest
const source = await fetch(item.url, { cache: 'no-store', credentials: 'same-origin' });
if (!source.ok) throw new Error('media fetch failed');
const bytes = await source.arrayBuffer();
if (bytes.byteLength !== item.expectedBytes) throw new Error('wrong size');
const digest = hex(await crypto.subtle.digest('SHA-256', bytes));
if (digest !== item.sha256) throw new Error('wrong digest');
await (await caches.open(CACHE_NAME)).put(item.url, new Response(bytes, { headers: source.headers }));
await readyStore.put({ partition, mediaVersion: item.version, url: item.url }); // marker last
```

Do not use the original `Response` after `arrayBuffer()`; its body has been consumed. Use fresh bytes in a fresh `Response` for `Cache.put`. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/Cache/put]

### Pattern 2: Partition-first local activation
**What:** Every IndexedDB record has `partition` as a required leading key; cache metadata stores only manifest/version identifiers. Every reader receives the current bootstrap partition and lease, and returns no lesson/outbox data when either does not match. [VERIFIED: 247-CONTEXT.md]

**When to use:** Bootstrap, worker messages, lesson rendering, outbox enqueue, replay selection, logout, and account-switch transition. [VERIFIED: 247-CONTEXT.md]

### Pattern 3: Server terminal-receipt idempotency
**What:** Treat terminal receipt creation as the mutation boundary. The host transaction uses the server-derived account/current Scope and a unique identity for the client mutation/idempotency key; it returns the stored terminal result when the request repeats. [VERIFIED: 247-CONTEXT.md]

**When to use:** Every reconnect replay request; never accept a request-selected owner or cached lease as replay authority. [VERIFIED: 247-CONTEXT.md]

### Anti-Patterns to Avoid

- **Caching via the fetch handler before verification:** A partially read or same-size-corrupt response could be served as ready. Verify first and promote marker last. [VERIFIED: 247-CONTEXT.md]
- **One global `offline-ready` key or cache-name-as-authorization:** It leaks readiness/state between accounts. Require current partition + lease at every reader. [VERIFIED: 247-CONTEXT.md]
- **Keeping a bearer/session value in IndexedDB, cache, `postMessage`, or test hook:** It violates D-01 even if encrypted or hidden in UI. [VERIFIED: 247-CONTEXT.md]
- **Client-side terminal replay state without a server receipt:** A retry can double apply or change result. Persist the outcome transactionally on the host. [VERIFIED: 247-CONTEXT.md]
- **Quota forcing as the only failed-write proof:** Chromium-specific quota behavior cannot prove the portable fail-closed branch; expose a bounded injected cache-write failure for test. [VERIFIED: 247-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| SHA-256 implementation | JavaScript hashing routine | `crypto.subtle.digest('SHA-256', bytes)` | Built-in Web Crypto provides the required SHA-256 operation in secure contexts/workers. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest] |
| Persistent media bytes | Custom blob/localStorage store | Cache Storage | Cache Storage stores request/response pairs and is available to workers. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/Cache/put] |
| Structured partitioned state | Serialization blobs or localStorage | IndexedDB with explicit partitioned records | Structured records permit exact partition/index checks and test inspection. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API] |
| Idempotent replay serialization | In-memory map/worker mutex | PostgreSQL transaction + Ecto uniqueness/locking | Durable outcome must survive reload, reconnect, and concurrent requests. [VERIFIED: 247-CONTEXT.md] |

**Key insight:** The browser stores bytes and bounded local study state, but only the host can grant or confirm an outcome; browser storage APIs do not provide a cross-store transaction, so marker-last is the deliberate fail-closed seam. [VERIFIED: 247-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Digesting a response that has not been completely retained
**What goes wrong:** Media can be marked ready after a partial or altered response. [VERIFIED: 247-CONTEXT.md]
**How to avoid:** Read `arrayBuffer`, compare `byteLength`, then SHA-256; only cache bytes reconstructed from the verified buffer. `SubtleCrypto.digest` is non-streaming. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest]

### Pitfall 2: Cross-API split brain
**What goes wrong:** A cache entry exists after interruption, so UI assumes it is ready. [VERIFIED: 247-CONTEXT.md]
**How to avoid:** Require cache response *and* matching marker at read time; write marker only after awaited `Cache.put`; failed marker writes remain unavailable. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/Cache/put]

### Pitfall 3: Account switch resurrects prior learner state
**What goes wrong:** Page/worker reads generic IndexedDB data or replays a prior outbox. [VERIFIED: 247-CONTEXT.md]
**How to avoid:** Partition every client record and deny activation/replay on missing, expired, or changed partition; clear current UI immediately on logout/switch. [VERIFIED: 247-CONTEXT.md]

### Pitfall 4: Duplicate replay outcome
**What goes wrong:** Reconnect retry applies an action twice or creates two visible receipts. [VERIFIED: 247-CONTEXT.md]
**How to avoid:** Make the transaction keyed by server-derived partition plus idempotency identity, store only a terminal outcome, and return that record on retry. [VERIFIED: 247-CONTEXT.md]

### Pitfall 5: Non-deterministic worker tests
**What goes wrong:** Tests race worker activation/cache completion or hide bugs behind waits. [VERIFIED: AGENTS.md]
**How to avoid:** Pre-arm worker/response waits; use bounded non-secret worker acknowledgements, `BrowserContext.setOffline`, and direct Cache/IndexedDB inspection. [CITED: https://playwright.dev/docs/service-workers] [CITED: https://playwright.dev/docs/api/class-browsercontext#browser-context-set-offline]

## Code Examples

### Bounded worker readiness observation

```typescript
// Source: https://playwright.dev/docs/service-workers
const workerPromise = context.waitForEvent('serviceworker');
await page.goto('/app');
const worker = context.serviceWorkers()[0] ?? await workerPromise;
await context.setOffline(true);
// Assert only bounded test status; never request cookie/token/partition/digest values.
```

### Replay request boundary

```elixir
# Host derives owner from conn.assigns.current_scope; client fields are identifiers, never authority.
with {:ok, outcome} <- LearningTwin.replay(conn.assigns.current_scope, replay_params) do
  json(conn, outcome)
end
```

The context must validate partition equality, current authorization, checkpoint, and idempotency within its database transaction, then return only the durable terminal outcome. [VERIFIED: 247-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Treat cache presence as offline readiness | Verify bytes, await cache write, then marker-last readiness | Locked for this phase in D-04/D-05 | Corrupt/partial/orphan bytes are never reported ready. [VERIFIED: 247-CONTEXT.md] |
| Browser-held token for offline retry | HttpOnly cookie transport + backend reauthorization | Locked for this phase in D-01/D-10 | Worker/cache are not authentication authority or credential stores. [VERIFIED: 247-CONTEXT.md] |

**Deprecated/outdated:** Generic sync/background-sync/PWA framework expansion is out of scope; retain a bounded foreground reconnect path. [VERIFIED: 247-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | A dedicated `Example.LearningTwin` context/module split is the best internal naming/shape. [ASSUMED] | Recommended Project Structure | Low; implementation can choose equivalent host-owned modules. |

## Open Questions

1. **Which authenticated route owns the lesson screen?**
   - What we know: It must be rooted in the existing `/app` experience and use the authenticated pipeline. [VERIFIED: 247-CONTEXT.md]
   - What's unclear: Whether it is `/app/lesson` or an `AppLive` child/action.
   - Recommendation: Choose a dedicated `/app/lesson` LiveView/route so the bounded artifact and Playwright target are explicit; preserve `/app` as current home. [ASSUMED]
2. **What exact terminal-record uniqueness columns best express identity?**
   - What we know: Partition and stable idempotency/client-mutation fields are mandatory; outcome must be durable and exactly once. [VERIFIED: 247-CONTEXT.md]
   - Recommendation: Enforce unique `(account_partition, idempotency_key)` and retain `client_mutation_id` as an independently validated/display-keyed field; validate with concurrent replay test. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir/Mix | Phoenix host/tests | ✓ | OTP 28 runtime | — |
| Node/npm | worker bundle and Playwright | ✓ | Node 22.14.0 / npm 11.1.0 | — |
| pinned Playwright Chromium | deterministic browser proof | ✓ | 1.59.1 | — |
| PostgreSQL client | host persistence/test operations | ✓ | 14.17 | repository test DB harness |

**Missing dependencies with no fallback:** None. [VERIFIED: local environment audit]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit/Phoenix LiveViewTest plus pinned `@playwright/test` 1.59.1 [VERIFIED: test/example/priv/playwright/package-lock.json] |
| Config file | `test/example/priv/playwright/playwright.config.ts` [VERIFIED: test/example/priv/playwright/playwright.config.ts] |
| Quick run command | `cd test/example && mix test test/example_web/live/app_live_test.exs` |
| Full suite command | `cd test/example && mix test && cd priv/playwright && npm test -- --project=chromium` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| TWIN-01 | Authenticated `/app` lesson has structured data/image/audio and no credential-bearing bootstrap/worker protocol | LiveView/controller + Chromium | `mix test test/example/test/example_web/...` and `npm test -- twin-offline.spec.ts --project=chromium` | ❌ Wave 0 |
| OFF-01 | Valid, short, same-size corrupt, and cache-write-failure media do/do not create marker or ready UI correctly | Chromium integration + client unit helpers | `npm test -- twin-offline.spec.ts --project=chromium` | ❌ Wave 0 |
| OFF-02 | Lease expiry, partition isolation/logout/switch, and accepted/rejected/conflict/duplicate replay resolve exactly once | Ecto concurrency/controller + Chromium | `mix test test/example/test/example/learning_twin/...` and Playwright spec | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** focused ExUnit tests plus the affected `twin-offline.spec.ts` scenario.
- **Per wave merge:** `cd test/example && mix test` and dedicated Chromium twin lane.
- **Phase gate:** full suite green with deterministic cache/IndexedDB inspection and no sleeps before `$gsd-verify-work`. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] `test/example/test/example/learning_twin/*_test.exs` — lease, authorization, transaction/idempotency, conflict/rejection tests.
- [ ] `test/example/test/example_web/controllers/learning_twin_controller_test.exs` — authenticated bootstrap/replay/CSRF and owner derivation tests.
- [ ] `test/example/test/example_web/live/learning_twin_live_test.exs` — authenticated markup/state contract tests.
- [ ] `test/example/priv/playwright/tests/twin-offline.spec.ts` — storage, worker, offline, corruption, switch, and replay end-to-end proof.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | Existing HttpOnly cookie and current-Scope pipeline; no JS/SW credentials. [VERIFIED: test/example/lib/example_web/endpoint.ex] |
| V3 Session Management | yes | Existing encrypted/signed cookie session plus normal logout disconnect/session renewal. [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| V4 Access Control | yes | Host derives owner from current Scope and reauthorizes every replay. [VERIFIED: 247-CONTEXT.md] |
| V5 Input Validation | yes | Validate manifest/replay schema, immutable URL fields, client IDs, checkpoint, and partition equality server-side. [VERIFIED: 247-CONTEXT.md] |
| V6 Cryptography | yes | Browser Web Crypto SHA-256 only for immutable-byte integrity; do not hand-roll hash or credential crypto. [CITED: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest] |

### Known Threat Patterns for Phoenix PWA Offline Island

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Corrupt/truncated media marked ready | Tampering | Exact byte length + SHA-256 + awaited cache write + marker last. [VERIFIED: 247-CONTEXT.md] |
| Cached prior-account lesson/outbox visible after switch | Information disclosure | Current partition/lease required for every activation/read/replay; replace UI on transition. [VERIFIED: 247-CONTEXT.md] |
| Worker/bootstrap leaks credential | Information disclosure | No app session/PAT/JWT/refresh token in page data, storage, or worker messages. [VERIFIED: 247-CONTEXT.md] |
| Duplicate or stale queued mutation | Tampering | Server transaction, current Scope reauthorization, durable unique terminal receipt, retry returns same receipt. [VERIFIED: 247-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `247-CONTEXT.md` — locked ownership, integrity, lease, replay, and deterministic-proof decisions.
- `test/example/lib/example_web/{endpoint,router,user_auth}.ex` — current HttpOnly cookie, Scope, logout, authenticated route boundaries.
- `test/example/deps/crosswake/lib/crosswake/offline/{journal,replay}.ex` — vocabulary to mirror.
- `247-UI-SPEC.md` — approved Tasklane visual and stable test-hook contract.

### Secondary (MEDIUM confidence)

- https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest — SHA-256 API, complete buffer, worker/secure-context posture.
- https://developer.mozilla.org/en-US/docs/Web/API/Cache/put — cache write semantics and consumed response bodies.
- https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API — structured browser state store.
- https://playwright.dev/docs/service-workers and https://playwright.dev/docs/api/class-browsercontext#browser-context-set-offline — worker observation and offline control.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing repository dependencies, runtime, and host seams verified.
- Architecture: HIGH — locked phase decisions map directly onto verified current Scope/cookie and Crosswake vocabulary boundaries.
- Pitfalls: HIGH — each is explicitly named in locked decisions or authoritative browser documentation.

**Research date:** 2026-08-18
**Valid until:** 2026-09-17 (recheck pinned Playwright/browser behavior if the lockfile changes).
