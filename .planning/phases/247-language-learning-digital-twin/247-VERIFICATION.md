---
phase: 247-language-learning-digital-twin
verified: 2026-08-19T14:48:56Z
status: passed
score: 34/34 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 247: Language-Learning Digital Twin Verification Report

**Phase Goal:** The example PWA demonstrates a bounded, account-safe offline lesson experience without treating cached data as authentication authority.
**Verified:** 2026-08-19T14:48:56Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

The four roadmap success criteria and all 34 plan `must_haves.truths` were checked.  The roadmap criteria overlap the detailed plan truths; the score counts the 34 distinct plan truths (including each plan-specific refinement), not the duplicated wording.

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Authenticated learner receives one structured lesson, image, and non-autoplay audio without browser-held app credentials. | ✓ VERIFIED | Authenticated `/app/lesson` routes are under `:require_authenticated`; `LearningTwinController` derives bootstrap/replay from `conn.assigns.current_scope`; `learning_twin.js` renders exactly two media items and an `audio[controls]`. The source-bound Chromium tracer includes the authenticated install/offline/replay path and asserts no `audio[autoplay]`. |
| 2 | Cached media becomes ready only after full byte-length and SHA-256 verification, awaited cache write, and partitioned marker-last promotion. | ✓ VERIFIED | `installItem` reads `arrayBuffer`, compares `byte_size` and `crypto.subtle.digest('SHA-256')`, awaits `cachePut`, then writes `media_markers`; `completeGate` requires both marker and cached response. Chromium has valid, short, same-size-corrupt, interrupted/write-failure, and orphan-cache cases. |
| 3 | A strict, host-configured seven-day lease and every local reader/writer are account-partitioned across expiry, logout, and account switch. | ✓ VERIFIED | `@default_lease_ttl_seconds 604_800`, strict `DateTime.compare(...)=:lt`, server Scope lookup, partition-prefixed IndexedDB keys, `clearCurrent`, and changed-partition invalidation are substantive. The focused ExUnit suite passed 19 tests; Chromium includes expiry/logout/switch isolation. |
| 4 | Reconnect replay is CSRF/cookie/current-Scope reauthorized and records one durable accepted, rejected, or conflict outcome per queued action. | ✓ VERIFIED | Router → `LearningTwinController.replay` → `LearningTwin.replay` uses `current_scope`; the Ecto transaction stores a unique `(account_partition, idempotency_key)` receipt and returns stored terminal state. Browser cases prove accepted, rejected, conflict, duplicate stability, and one visible row. |
| 5 | Worker registration, `/app/` scope, generic offline shell, and credential-free offline activation are bounded to `/app/lesson`. | ✓ VERIFIED | `navigator.serviceWorker.register(..., {scope: '/app/'})`; static paths expose worker/shell; worker only falls back for navigation to `/app/lesson`; `renderOffline` still requires current activation, unexpired lease, state, markers, and cache responses. |
| 6 | Invalid, unavailable, busy, ready, expired, and account-change states fail closed with usable text and controls. | ✓ VERIFIED | The runtime renders explicit unavailable/verifying/retry/available/expired copy, `aria-busy`, and focused recovery heading; Chromium covers media failure, lease expiry, failed bootstrap, and logout cleanup. |
| 7 | Practice validation retains input and writes no receipt/outbox until valid; valid offline input creates one partitioned queued row. | ✓ VERIFIED | `validPractice` gates `queuePractice`; it preserves form values and only then writes a bounded partitioned outbox item. The named Chromium form test inspects the row directly and asserts no credential-like fields. |
| 8 | Receipt UI is semantic, chronological, learner-safe, and reconciles each queued action in place without false success or automatic conflict overwrite. | ✓ VERIFIED | `renderReceipts` creates an ordered list; `replay` verifies correlation/status/timestamp and refuses to replace an existing terminal row. The test matrix covers empty/queued/accepted/rejected/conflict/duplicate states, local Review-lesson focus, timestamp retention, and no internal identifiers. |
| 9 | No Crosswake adapter, expanded offline engine, background sync, native proof, or additional lesson is introduced. | ✓ VERIFIED | Source scan found no Crosswake imports/adapters, Background Sync registration, timers, or browser-held token/session storage. The worker and runtime are bounded to the one lesson and foreground replay. |
| 10 | Deterministic proof is credential-free, source-bound, exact-key, and receipt-last. | ✓ VERIFIED | `phase-247-language-twin-proof.sh` runs focused ExUnit then complete Chromium before `write_evidence_last`; its validator accepts only the exact schema/flags/source key set before atomic rename. Current `247-EVIDENCE.json` passes the same jq schema contract and all ten recomputed SHA-256 values. |

**Score:** 34/34 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/example/priv/repo/migrations/20260819000000_create_learning_twin_tables.exs` | Durable lease and idempotent receipt storage | ✓ VERIFIED | Substantive 53-line migration, partition/user/expiry indexes, and unique replay identity. |
| `test/example/lib/example/learning_twin.ex` | Host-owned lesson, lease, authorization, replay, controller, and LiveView | ✓ VERIFIED | 421 substantive lines; Scope-first bootstrap/replay, strict expiry, transaction, bounded response, and safe render paths. |
| `test/example/lib/example_web/router.ex` and `test/example/lib/example_web.ex` | Authenticated routes and root worker/shell static serving | ✓ VERIFIED | `/app/lesson`, bootstrap/media/replay routes plus both explicit root static filenames. |
| `test/example/priv/static/assets/js/learning_twin.js` | Integrity, partition, offline, outbox, and receipt runtime | ✓ VERIFIED | 311 substantive lines; browser test is the wired consumer and source-bound proof exercises its state transitions. |
| `test/example/priv/static/learning-twin-worker.js` and `learning-twin-offline.html` | Generic `/app/lesson` shell fallback | ✓ VERIFIED | Worker has a narrowly scoped navigation handler; shell has no lesson/account/credential payload and is consumed by the runtime. |
| `test/example/priv/static/assets/css/app.css` | Responsive themed twin styles | ✓ VERIFIED | Existing `vt-twin__*` BEM selectors use shared theme tokens. The plan checker’s literal `.vt-twin-` probe is stale; the underscore form is present and exercised by 320px/theme tests. |
| ExUnit lease/controller/LiveView tests | Host authority and replacement-state behavior | ✓ VERIFIED | All three files are substantive and the focused command passed 19 tests, 0 failures. |
| `test/example/priv/playwright/tests/twin-offline.spec.ts` | Browser integrity, offline, isolation, accessibility, and replay proof | ✓ VERIFIED | 594 lines, exactly 18 Chromium cases listed, including all phase behaviors. |
| `scripts/ci/phase-247-language-twin-proof.sh` | Phase-owned receipt-last proof | ✓ VERIFIED | Runs migrations/scoped ExUnit/Chromium, validates exact JSON, hashes sources, then atomically publishes evidence. |
| `247-EVIDENCE.json` | Credential-free machine evidence | ✓ VERIFIED | Exact schema v1, fourteen true causal flags, ten current hashes, and no runtime payload fields. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Authenticated router | lesson/bootstrap/media/replay | authenticated browser pipeline and current Scope | ✓ WIRED | `router.ex:72-77`; controller receives `conn.assigns.current_scope`. |
| Browser runtime | service worker/shell | explicit `/app/` registration and `navigator.serviceWorker.ready` | ✓ WIRED | Runtime registers worker; worker’s only navigation fallback is `/app/lesson` → generic shell. |
| Runtime | Cache Storage + IndexedDB | verify → await Cache.put → marker → current activation | ✓ WIRED | Direct source trace in `installItem`, `prepare`, and `completeGate`; storage inspected by Chromium. |
| Scope/lease | partitioned bootstrap and local activation | server lookup plus strict lease/partition gates | ✓ WIRED | `active_lease`, `authorize_partition`, `bootstrap_for_current_scope`; `completeGate` enforces local counterpart. |
| Reconnect runtime | backend replay receipt | CSRF POST → current Scope → transaction/unique receipt | ✓ WIRED | `replayQueued`/`replay` → router/controller/context transaction; behavior covered in browser and ExUnit suites. |
| Terminal response | ordered receipt row | stable client-mutation correlation and immutable terminal result | ✓ WIRED | Runtime updates existing outbox row once; accepted/rejected/conflict/duplicate Chromium cases exercise it. |
| Proof runner | retained evidence | validation + source hash gate + temp file atomic rename | ✓ WIRED | `write_evidence_last` is called only after both test commands return successfully. |

The generic key-link command reported several false negatives because its supplied cross-line regexes assume exact token order/spelling (`.vt-twin-`, `learning-twin-worker.js` without its cache-busting query, and synthetic endpoint labels). Manual source traces above prove each actual connection; none is orphaned or partial.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Lesson runtime | `twin` bootstrap payload | authenticated controller → current-Scope lease | Yes — structured lesson and immutable manifest | ✓ FLOWING |
| Offline runtime | activation/state/markers/media cache | partitioned IndexedDB + Cache Storage after verified promotion | Yes — Chromium reloads offline lesson only when complete gate holds | ✓ FLOWING |
| Replay receipt UI | partition-filtered outbox rows | valid local form → reauthorized durable terminal response | Yes — Chromium observes queued → terminal in the same row | ✓ FLOWING |
| Evidence receipt | causal flags/source hashes | focused ExUnit + Chromium commands and SHA-256 files | Yes — exact schema and all current source hashes verified | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Lease boundaries, Scope authorization, replay outcomes, controller, and LiveView safety | `source tmp/db.env && cd test/example && MIX_ENV=test mix ecto.migrate --quiet && MIX_ENV=test mix test test/example/learning_twin/learning_twin_test.exs test/example_web/controllers/learning_twin_controller_test.exs test/example_web/live/learning_twin_live_test.exs` | 19 tests, 0 failures | ✓ PASS |
| Browser phase matrix enumeration | `cd test/example/priv/playwright && npm test -- twin-offline.spec.ts --project=chromium --list` | Exactly 18 named Chromium cases | ✓ PASS |
| Current phase evidence integrity | jq exact-key validation plus recomputation of all ten listed SHA-256 values | Schema/flags valid; 10/10 source hashes match | ✓ PASS |
| JavaScript and whitespace sanity | `node --check .../learning_twin.js` and `git diff --check -- ...` | Both exit 0 | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — Phase 247 declares no `scripts/*/tests/probe-*.sh` probe. Its documented runnable proof is the receipt-last script above; the checked-in, source-bound receipt was independently schema- and hash-validated.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TWIN-01 | 01, 03, 05, 06 | Authenticated structured lesson with image/audio; HttpOnly session and no application credentials in JS/worker. | ✓ SATISFIED | Authenticated Scope route/controller, credential-free worker/runtime scan, tracer, and source-bound proof flag `credential_boundary: true`. |
| OFF-01 | 01, 02, 06 | Exact size/SHA media integrity and fail-closed offline availability. | ✓ SATISFIED | Full-buffer digest/awaited write/marker-last source trace, five negative Chromium integrity paths, and evidence integrity flags. |
| OFF-02 | 01, 03, 04, 05, 06 | Seven-day lease, partitioned local state, logout/switch isolation, exactly-once backend reauthorized replay. | ✓ SATISFIED | 19 focused ExUnit tests, partition/expiry/logout Chromium cases, transaction/unique receipt trace, and accepted/rejected/conflict/duplicate browser matrix. |

Every requirement declared by every Phase 247 plan (`TWIN-01`, `OFF-01`, `OFF-02`) is present in `REQUIREMENTS.md` and accounted for above. `REQUIREMENTS.md` maps no additional requirement to Phase 247; there are no orphaned requirements.

### Anti-Patterns Found

No blocker or warning anti-pattern was found in the Phase 247 implementation/test/proof files. There are no unreferenced `TBD`, `FIXME`, or `XXX` markers; `mktemp` is deliberate temporary proof/evidence publication. No empty render/handler feeds learner output. The runtime/test scan found no autoplay, timer/countdown, background-sync, or browser-held credential-storage path.

### Prohibition Verification

All four retained prohibitions have deterministic evidence, so no human checkpoint is required: offline readiness is described as availability rather than authentication; visible text/pills accompany statuses; audio has no autoplay and no timer exists; and conflict preserves input with a local `Review lesson` focus action rather than showing accepted state or overwriting data.

### Gaps Summary

None. The Phase 247 goal is achieved. There are no gaps to defer to Phases 248 or 249; those later phases add native/desktop proof rather than repair any required PWA behavior.

---

_Verified: 2026-08-19T14:48:56Z_
_Verifier: the agent (gsd-verifier)_
