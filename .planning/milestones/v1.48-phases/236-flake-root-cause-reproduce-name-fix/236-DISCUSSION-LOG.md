# Phase 236: Flake Root Cause — Reproduce, Name, Fix - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-09-15
**Phase:** 236-flake-root-cause-reproduce-name-fix
**Mode:** assumptions
**Areas analyzed:** Root Cause Diagnosis, Fix Shape in `lib/`, Reproduction Mechanics,
Prohibition Guard + Dead Env Var, Scope Boundary

## Assumptions Presented

### Root Cause Diagnosis

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Genuine product race: plain `<a href>` presets + `<form method="get">` inside a connected LiveView cause full teardown → rejoin, and the fill+Enter is swallowed in that window | Likely | `audit_index_live.ex:59-74,76`; module has zero `handle_event/3` and zero `phx-*` bindings |
| DB collision ruled out — the assertion is URL-only, chip renders from params not rows | Confident | `admin-generated.spec.ts:459-460` |
| Value-wipe sub-mechanism ruled out — URL keeps **no** `actor=` key across 19 polls; a submitted-but-wiped form would serialize `actor=` empty | Confident | todo `2026-07-30-...-actor-filter-race.md` symptom report |
| Controlled differential: the example lane drives the identical form and is stable because it calls `waitForLiveViewReady` around each click | Likely | `admin-audit.spec.ts:127-146` vs `admin-generated.spec.ts:441-459` |
| SC-1's captured trace is the decider; diagnosis stays falsifiable | Confident | ROADMAP SC-1 ("no fix is accepted without it") |

### Stale Citations

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Spec uses `press("Enter")` at `:457`, not an "Apply filters" click; failing assertion is `:459` not 428 | Confident | `git log -S'actorFilter.press("Enter")'` → `2a96d72f` (#168), post-dates the todo |
| Both todos cite `audit_live.ex`, which does not exist; real module is `audit_index_live.ex` | Confident | `ls lib/sigra/admin/live/` |

### Fix Shape in `lib/`

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Presets → `<.link patch>`; form keeps `method="get"`/`action=` and **adds** `phx-submit`; new `handle_event` → `push_patch`; `handle_params` stays sole loader; Export CSV stays `<a href>` | Confident | LiveView Live Navigation guide; `push_patch/2` (`phoenix_live_view.ex:1124`) |
| Do **not** add `phx-change` — `bindForms` external-submit branch keys off `phx-change && !phx-submit` | Confident | `live_socket.js:1158-1197` |
| `method="get"` + `action=` alongside `phx-submit` is sanctioned, no double-navigation; `preventDefault()` is unconditional when `phx-submit` present | Confident | `live_socket.js:1158-1197` |
| DOM delta is exactly `data-phx-link` + `data-phx-link-state`; no class/tag change → PNG baselines cannot move | Confident | `phoenix_component.ex:3090-3120`; `tag_engine.ex:1538` strips `phx-no-format` |
| `push_patch` legality is same-module + same-`live_session`, path scope irrelevant; `AuditIndexLive` is in two sessions but all filter paths stay in-scope | Confident | `route.ex:31-49`; `router_injection.ex:28-41,56-69`; `audit_index_live.ex:286-289` |
| `push_patch(to:)` must be a local path (`validate_local_url!`) | Confident | `phoenix_live_view.ex:1162-1167` |
| JS and no-JS param shapes must produce the same URL (native fallback submits blanks) | Confident | `live_socket.js` bindForms behaviour |
| Controller/dead-view demotion rejected — router is a generated template, so it changes the adopter contract | Confident | `priv/templates/sigra.install/admin/router_injection.ex` |
| Zero `push_patch` precedent in `lib/sigra/admin/` — a deliberate divergence to be stated | Confident | `grep -rn "\.link patch\|live_patch\|push_patch" lib/sigra/admin/` → 0 hits |
| No `priv/templates/` or `test/example/lib/` mirror of this LiveView | Confident | `grep -rn "audit_index_live" priv/templates/ test/example/lib/` → 1 comment only |

### Reproduction Mechanics

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No trace exists today; RED must be manufactured | Confident | `playwright.config.ts:59` `retries: 0`, `trace: 'on-first-retry'` |
| Stale `head_ref` gate already fixed — job runs on every event incl. `pull_request`, no `if:` | Confident | `ci.yml:1401-1421` (Phase 231 GATE-02/D-06) |
| `workflow_dispatch` on a branch is hard-failed by `release_ref_guard` unless `recapture_branch` is set → SC-3 means repeated **push** runs harvested from the Actions API | Confident | `ci.yml:80-96` |
| Local repro feasible but the smoke script has no Playwright flag pass-through | Likely | `admin-acceptance-smoke.sh:28,255-256,398-404` |
| Post-fix, a submit during dead-render still does a native GET; tests must await `phx:connected` | Confident | `live_socket.js` bindForms |

### Prohibition Guard + Dead Env Var

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `p17` free; 236 claims it, Phase 241 SURF-04 moves to `p18` (one-line REQUIREMENTS edit) | Confident | `ls scripts/ci/prohibitions/` (p01-p16); `REQUIREMENTS.md:37` names `p17-*` for SURF-04 |
| One guard, one substitutable subject (`playwright.config.ts`), pure `retryWrapperIssue(text)`, spec files as secondary artifacts, with non-vacuity floors | Likely | `_lib.mjs` one-subject contract; `p16` shape |
| Comment-stripping load-bearing — config prose says "Retries stay at zero everywhere" | Confident | `playwright.config.ts:16-18` |
| Committed fixture (p01-p13 convention), not inline-only (p14-p16) — SC-4 demands committed | Confident | `ls test/fixtures/prohibitions/`; ROADMAP constraint 6 |
| `ci.yml:393` glob auto-discovers; zero workflow edits; outside `mix ci` | Confident | `ci.yml:385-393` |
| Delete `PLAYWRIGHT_RETRIES: 1` — zero readers repo-wide; wiring it would violate the guard written in the same phase | Confident | full-repo grep → only `ci.yml:1460` + `.planning/` prose |

### Scope Boundary

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `audit_user_live.ex` / `users_index_live.ex` share the pattern but stay out; file a todo | Confident | ROADMAP SC-2 names one file; PNG recapture constraint |
| `2026-07-18-admin-audit-impersonation-filter-not-applying.md` already fixed — the flaking test *is* its regression test | Likely → **verified Confident** | `sg-filter-chip` now only at `users_index_live.ex:352`; `admin-generated.spec.ts:445-446`; added in `40240903` |
| SC-5 quarantine writes an 8-column TSV row (`parseSkipManifest` throws under 8) and obliges a `MAINTAINING.md` entry; **no column exists for SC-5's required date+owner** | Likely | `_lib.mjs:parseSkipManifest`; `.github/ci-skip-manifest.tsv:1-11` |

## Corrections Made

No corrections — all assumptions confirmed ("Yes, proceed").

## Orchestrator Verifications (beyond the analyzer's report)

Four checks run directly in the main context to close risks the analyzer flagged as open:

1. **`live_session` risk resolved.** `AuditIndexLive` is mounted in two sessions
   (`:admin_global`, `:admin_organization`) — the analyzer's "if wrong" scenario was real. But
   `index_path/1` branches on `%Scope{mode: :organization}` (`audit_index_live.ex:286-289`) and
   every filter helper (`preset_path`, `sort_path`, `page_path`, `remove_chip_path`) derives
   from it, so patches never cross sessions. D-12 records this as a property the planner must
   preserve. `export_path` is a `.csv` controller route → stays `href`.
2. **Generated-router confirmation.** The route lives in
   `priv/templates/sigra.install/admin/router_injection.ex`, confirming the controller-demotion
   option would change the adopter-visible contract (D-15).
3. **Impersonation-chip todo confirmed stale.** `grep -rn "sg-filter-chip" lib/` returns only
   `users_index_live.ex:352` — the markup the todo describes is gone from the audit surface
   (D-31).
4. **Admin LiveView precedent survey.** `handle_event` exists in `branding_live.ex`,
   `user_sessions_live.ex`, `users_index_live.ex`; the last is only a `toggle_filters` UI
   toggle. No `push_patch` anywhere. Confirms D-16's divergence framing.

## External Research

Verified against the repo's **actual locked** `phoenix_live_view 1.1.33` (from `mix.lock`),
reading `deps/phoenix_live_view` source as primary, plus 1.1.33 hexdocs guides.

- **Blessed idiom for a URL-owning filter form:** `phx-submit` → `handle_event` →
  `push_patch` → `handle_params` loads. `phx-change` + debounce is correct only for
  search-as-you-type; for a multi-field panel it pushes a history entry per keystroke and
  re-enters `handle_params` mid-typing. `JS.patch/1` cannot carry form values, so a server
  `handle_event` is structurally required. (Live Navigation guide; form-bindings guide;
  `phoenix_live_view.ex:1124`) — High confidence.
- **`method="get"` + `action=` alongside `phx-submit`:** sanctioned progressive enhancement, no
  double-navigation. `bindForms` calls `preventDefault()` whenever `phx-submit` exists; the
  native-submit branch requires `phx-change && !phx-submit`. (`live_socket.js:1158-1197`) —
  High confidence.
- **`push_patch` scope rule:** same LiveView module **and** same `live_session`; path scope
  irrelevant. Server-side `push_patch` to a foreign view/session **raises `ArgumentError`**
  (does not degrade); client-side `<.link patch>` to a foreign route degrades to a full page
  navigation. `push_patch(to:)` must be a local path (`validate_local_url!`).
  (`route.ex:31-49`; `channel.ex:138-154,913-930,938-951`;
  `phoenix_live_view.ex:1162-1167`) — High confidence.
- **`<.link patch>` DOM output:** identical `<a>` + exactly two attributes (`data-phx-link`,
  `data-phx-link-state`); `class`/`id`/`aria-*` pass through via `:global` `@rest`;
  `phx-no-format` is stripped at compile time. **PNG baselines cannot move.**
  (`phoenix_component.ex:3090-3120`; `tag_engine.ex:1538`) — High confidence.

The analyzer's second research topic — Playwright's actionability semantics when morphdom
replaces a node between locator resolution and key dispatch — was **deliberately not pursued**.
SC-1's captured trace answers it empirically, and the ROADMAP makes that trace the decider.
