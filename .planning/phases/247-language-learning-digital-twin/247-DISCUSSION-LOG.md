# Phase 247: Language-Learning Digital Twin - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-18
**Phase:** 247-language-learning-digital-twin
**Mode:** assumptions
**Areas analyzed:** Session and Lesson Authority, Verified Immutable Media, Account-Bound Offline Lease and Local Isolation, Backend-Reauthorized Replay Record

## Assumptions Presented

### Session and Lesson Authority

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Extend the existing authenticated `/app` browser experience and use only the secure cookie-backed Sigra session; neither page JavaScript nor the service worker receives, stores, or derives an app credential. | Confident | `test/example/lib/example_web/router.ex`; `test/example/lib/example_web/endpoint.ex`; `.planning/REQUIREMENTS.md` |

### Verified Immutable Media

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use a versioned immutable lesson/media manifest with expected byte size and SHA-256; report media ready only after complete-byte verification, successful Cache Storage write, and marker-last IndexedDB promotion. | Confident | `.planning/research/ARCHITECTURE.md`; Web Crypto, Fetch, Service Worker Cache, and Storage standards |

### Account-Bound Offline Lease and Local Isolation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use a Phoenix-host-issued opaque account partition and a host-configurable seven-day default lease; partition lesson state, media metadata, and outbox locally, failing closed on missing, expired, logout, or changed-account state. | Confident | `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-CONTEXT.md`; `.planning/research/ARCHITECTURE.md`; `.planning/research/PITFALLS.md`; `test/example/lib/example_web/user_auth.ex` |

### Backend-Reauthorized Replay Record

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Submit stable queued-action identities to a host endpoint that reloads current Sigra Scope, reapplies authorization, and durably returns exactly one accepted, rejected, or conflict result per action; reuse Crosswake-compatible vocabulary without Phase 248 adapter coupling. | Confident | `.planning/research/ARCHITECTURE.md`; `.planning/research/PITFALLS.md`; `test/example/deps/crosswake/lib/crosswake/offline/journal.ex`; `test/example/deps/crosswake/lib/crosswake/offline/replay.ex`; `.planning/ROADMAP.md` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- **Browser integrity and Cache Storage semantics:** Web Crypto supplies complete-input SHA-256; Fetch body consumption and Cache Storage writes reject on read/write failures; cache batch operations roll back on failure; storage is best-effort and quota constrained. Marker-last IndexedDB promotion is an explicit implementation convention because Cache Storage and IndexedDB do not share a transaction. Sources: `https://www.w3.org/TR/WebCryptoAPI/`, `https://fetch.spec.whatwg.org/`, `https://w3c.github.io/ServiceWorker/`, `https://storage.spec.whatwg.org/`.
- **Deterministic Playwright proof:** Playwright 1.59.1 can observe Chromium service workers, distinguish worker-owned requests/responses, toggle offline mode, inspect IndexedDB and Cache Storage, and isolate browser contexts. Stable readiness/message hooks and pre-armed waits replace sleeps. Experimental CDP quota forcing must not stand alone as cross-browser cache-failure evidence. Sources: `test/example/priv/playwright/package-lock.json`; `test/example/priv/playwright/playwright.config.ts`; `https://github.com/microsoft/playwright/blob/v1.59.1/docs/src/service-workers-js-python.md`; `https://chromedevtools.github.io/devtools-protocol/tot/Storage/#method-overrideQuotaForOrigin`.
- **Crosswake boundary:** The example already consumes released `crosswake_sigra` 0.1.3 and `crosswake` 0.2.0. Its journal/replay vocabulary matches the action/outcome contract but lacks Sigra's required account partition; Phase 247 mirrors vocabulary locally while Phase 248 owns package adapter/native proof. Sources: `test/example/mix.exs`; `test/example/mix.lock`; `test/example/deps/crosswake/lib/crosswake/offline/journal.ex`; `test/example/deps/crosswake/lib/crosswake/offline/replay.ex`; `.planning/ROADMAP.md`.

## Methodology Applied

- Decisive Defaulting selected the repo-consistent host-owned PWA path.
- Escalation Threshold limited confirmation to credential exposure, cached authority, account isolation, media integrity, replay semantics, and proof truth.
- Research Depth Calibration required prior contexts, current code, local research, browser standards, pinned Playwright documentation, and released Crosswake source inspection before presenting assumptions.
