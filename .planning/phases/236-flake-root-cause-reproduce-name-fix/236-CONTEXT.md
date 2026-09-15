# Phase 236: Flake Root Cause — Reproduce, Name, Fix - Context

**Gathered:** 2026-09-15 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

`main`'s aggregate gate stops flipping red on an unchanged SHA — because the
`Generated admin Playwright smoke` failure has a **named, fixed cause**, not because it was
retried into silence.

Fixed surface is `lib/sigra/admin/live/audit_index_live.ex` **only**, plus the reproduction
artifact, the `p17` prohibition guard, and the dead `PLAYWRIGHT_RETRIES` env var. This phase
runs in parallel with 237 and 238; Phase 237's `lib/` doc sweep skips `audit_index_live.ex`
because 236 owns it.

This phase is the milestone spine: the flake reds `ci-gate` → `ci-gate` gates release-please's
`gate-ci-green` → `gate-ci-green` gates `publish-hex`. One flaky assertion taxes every merge.

**Pre-authorized scope exception (ROADMAP standing constraint 4):** the milestone's
"found-while-cleaning → todo, never an in-phase fix" rule is explicitly waived here — if the
root cause is a genuine product race in `lib/`, **fixing it is in scope**.
</domain>

<decisions>
## Implementation Decisions

### Root Cause Diagnosis

- **D-01:** The working diagnosis is a **genuine product race**, not a harness race and not a
  DB collision. `/admin/audit` renders plain `<a href>` preset links
  (`audit_index_live.ex:59-74`) and a plain `<form method="get">` (`:76`) *inside a connected
  LiveView* that defines only `mount/3`, `handle_params/3`, `render/1` — **zero
  `handle_event/3` and zero `phx-*` bindings**. LiveView JS intercepts neither construct, so
  each preset click is a real browser navigation: full document teardown → dead render →
  websocket rejoin → morphdom patch. The subsequent `fill` + `press("Enter")` lands inside that
  unsynchronized rejoin window and the implicit GET submit is dispatched into a form node the
  join-patch is replacing — producing no navigation at all.

- **D-02:** DB collision is **ruled out** for this assertion: it is URL-only and needs no
  matching audit rows; the `Actor: <uuid>` chip renders from params, not rows.

- **D-03:** The "LiveView patch wiped the typed value" sub-mechanism is **ruled out** by the
  reported symptom: the URL keeps **no `actor=` key at all** across 19 polls / ~15s. A form that
  submitted with a wiped input would still serialize `actor=` (empty) — the key would be
  present. Its total absence means no submission occurred.

- **D-04:** The controlled differential that seals it: the example-lane spec
  `test/example/priv/playwright/tests/admin-audit.spec.ts:127-146` drives the **identical** GET
  filter form and is stable — because it calls `waitForLiveViewReady(page)` immediately before
  the fill *and* after the click. `admin-generated.spec.ts:441-459` calls it only after the
  initial `goto`, and **not after either preset link click** — both full navigations that
  restart the dead→connected cycle.

- **D-05:** **SC-1's captured trace is the decider, not this diagnosis.** The plan must not skip
  it or treat D-01 as established. If the trace shows `actor=` present-but-empty, the cause is
  the connect-patch value-wipe instead and the fix shape changes (the form needs `phx-change`
  value ownership, not just submit ownership). If no keydown reached the document at all, it is
  pure harness actionability, no `lib/` change is warranted, and GREEN-02 goes to its SC-5
  quarantine branch.

### Stale Citations to Correct Before Planning

- **D-06:** The ROADMAP (SC-1, "line 428") and the todo (lines 454-458) both cite a
  `getByRole("button", {name:"Apply filters"}).click()`. **The spec at HEAD does not do that.**
  It uses `actorFilter.press("Enter")` at `admin-generated.spec.ts:457`, changed by commit
  `2a96d72f` ("ci: authenticate Playwright once, then shard", #168) *after* the 2026-07-30 todo
  was filed. The failing assertion is at **`:459`**; the test starts at **`:427`**. Plans must
  target the real lines — a plan written against the cited button-click edits a line that is not
  there, and an SC-1 RED captured against it proves nothing.

- **D-07:** Both todos point at `lib/sigra/admin/live/audit_live.ex`, **a file that does not
  exist**. The real module is `audit_index_live.ex` (siblings: `audit_user_live.ex`).

### Fix Shape in `lib/`

- **D-08:** Keep `AuditIndexLive` a LiveView and make it the **sole owner of its URL**:
  1. Presets (`:59-74`), chip-remove (`:140`), sort (`:155`), pagination (`:188-189`), `Clear`
     (`:121`) and `Clear all` (`:142`, `:180`) anchors become `<.link patch={...}>`.
  2. The filter form (`:76`) **keeps** `method="get"` and `action={index_path(...)}` and simply
     **adds** `phx-submit="apply_filters"`.
  3. A new `handle_event("apply_filters", params, socket)` normalizes/whitelists params and
     returns `{:noreply, push_patch(socket, to: <local path>)}`.
  4. `handle_params/3` stays the **one and only** loader.
  5. `Export CSV` (`:122`) stays a plain `<a href>` — it is a controller CSV download and must
     remain a document navigation.
  6. Keep `<button type="submit">Apply filters</button>` — the example lane clicks it by role
     (`admin-audit.spec.ts:142`) and it is in the PNG baselines.

- **D-09:** **Do NOT add `phx-change`.** `live_socket.js#bindForms` keys its external-submit
  branch off `phx-change && !phx-submit`; adding both changes debounce/validation semantics for
  no benefit. `phx-change` + debounce is the correct idiom only for search-as-you-type, not a
  multi-field filter panel (every keystroke would push a history entry and re-enter
  `handle_params` mid-typing).

- **D-10:** Keeping `method="get"` + `action=` alongside `phx-submit` is **sanctioned and
  hazard-free**, not dead markup. `bindForms` (`live_socket.js:1158-1197`) calls
  `preventDefault()` unconditionally whenever `phx-submit` is present, so the native GET never
  fires while connected; the native-submit branch cannot double-fire. `action=` stays live in
  two real windows: JS disabled, and the dead render before socket connect. Exactly one path
  fires in every case. This preserves progressive enhancement for adopters.

- **D-11 (baseline safety — load-bearing):** `<.link patch>` renders an `<a>` with exactly two
  added attributes — `data-phx-link="patch"` and `data-phx-link-state="push"`. Same tag, same
  `href` string, `class`/`id`/`aria-*` pass through untouched via the `:global` `@rest`
  (`phoenix_component.ex:3090-3120`). The `phx-no-format` seen in the source is a compile-time
  hint the HEEx engine strips before render (`tag_engine.ex:1538`). **No class, tag or layout
  change → the committed audit PNGs cannot move**, `scripts/ci/snapshot-canary-guard.sh` stays
  green, and no recapture lane opens (standing constraint). Every existing class/attribute must
  be carried over verbatim.

- **D-12 (`live_session` legality — verified safe):** `push_patch` is legal only to the **same
  LiveView module in the same `live_session`**; path scope is irrelevant
  (`route.ex:31-49`). `AuditIndexLive` is mounted in **two** sessions —
  `:admin_global` (`/admin/audit`) and `:admin_organization`
  (`/admin/organizations/:org/audit`) — per
  `priv/templates/sigra.install/admin/router_injection.ex:28-41,56-69`. **This is safe** because
  every filter path derives from `index_path(admin_scope)`, which resolves to the *current*
  scope's own route (`audit_index_live.ex:286-289`), so patches never cross sessions. The
  planner must preserve that property. A server-side `push_patch` to a foreign view/session
  **raises `ArgumentError`** — it does not degrade gracefully.

- **D-13:** `push_patch(to:)` must be a **local path**, never a full URL with host — it runs
  `validate_local_url!`. (`<.link patch>` tolerates a full URL; `push_patch/2` does not.)

- **D-14:** The `handle_event` param shape and the native GET fallback param shape must produce
  the **same URL**. The native fallback submits every named input including blanks — normalize
  blanks away in `handle_event` and make `handle_params` treat missing == blank, or the JS and
  no-JS paths will disagree.

- **D-15 (rejected alternative, recorded):** Demoting `/admin/audit` to a controller + dead view
  is **rejected on blast radius**. The router is a **generated template**
  (`priv/templates/sigra.install/admin/router_injection.ex`), so `live "/audit"` → `get` changes
  the adopter-visible generated-host contract — an escalation — and it would break every
  `waitForLiveViewReady(page)` call that waits on `[data-phx-session].phx-connected`
  (`admin-audit.spec.ts:126,130`).

- **D-16 (divergence, stated deliberately):** There is **zero** `push_patch` / `<.link patch>` /
  `live_patch` precedent anywhere in `lib/sigra/admin/` (grep → 0 hits). The repo idiom today is
  URL state via plain GET forms + `<a href>`, with `handle_event` reserved for non-URL ephemeral
  state (`users_index_live.ex:66` `toggle_filters`; `user_sessions_live.ex:38-71` modal confirm).
  The closest precedent for a form owning its own state is `branding_live.ex:155-156`, a real
  `phx-change`/`phx-submit` mutation form — mirror its `phx-submit` + `handle_event` shape. The
  plan must **state this divergence explicitly and cite the zero-hit grep**, so it reads as a
  deliberate first-of-its-kind choice rather than an oversight.

- **D-17:** There is **no `priv/templates/` or `test/example/lib/` mirror** of this LiveView —
  it ships purely as library code. The only outside mention is a comment at
  `test/example/lib/example_web/live/admin/design_gallery_live.ex:1329`, a static design board,
  unaffected. Re-verify with one grep before planning (installer-template-drift precedent).

### Reproduction Mechanics (GREEN-01 / SC-1, SC-3)

- **D-18:** No trace exists today and none can be harvested: `playwright.config.ts:59` hardcodes
  `retries: 0` and `trace: 'on-first-retry'`. The RED must be **manufactured deliberately**.

- **D-19:** The stale-`head_ref` finding is **already fixed at HEAD** —
  `generated_admin_playwright_smoke` has **no `if:` at all** and runs on every event including
  `pull_request` (`ci.yml:1401-1421`, with a comment forbidding reintroduction). So a RED is
  capturable on an ordinary PR. Close
  `.planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md`
  as already-resolved citing `ci.yml:1408-1420`; do **not** re-fix it.

- **D-20 (SC-3 mechanism — important):** `release_ref_guard` (`ci.yml:80-96`) **hard-fails a
  `workflow_dispatch` whose ref is not `refs/tags/v*`** unless the `recapture_branch` input is
  non-empty (an input semantically meant for baseline recapture). Therefore SC-3's "dispatched
  repeatedly against the fix" is honestly satisfied by **repeated push runs on the fix branch**,
  harvested from the GitHub Actions API run list — **not** `gh workflow run --ref <branch>`.
  Observed from the API, never from reading YAML.

- **D-21:** Local reproduction is feasible —
  `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test chrome`, `PORT` defaults
  to 4017, needs `PGUSER`/`PGPASSWORD`/`PGHOST` and the phx_new 1.8.8 archive. **But** the script
  hardcodes its Playwright invocation (`:398-404`) with no flag pass-through. So repro means
  either (a) boot the app via the script, then run
  `npx playwright test tests/admin-generated.spec.ts -g "generated audit presets" --repeat-each=30 --trace=on`
  by hand against the booted port, or (b) a temporary, **reverted-before-merge** `trace: 'on'` in
  `playwright.config.ts` plus a dispatch run. Either artifact (local trace zip or run id) is
  accepted by the ROADMAP; record whichever with its path or run id.

- **D-22:** Post-fix, the original race is not fully gone until connect — a submit during the
  dead-render window still does a native GET. That is correct-by-fallback, but any test asserting
  patch behaviour must wait for `phx:connected` first.

### Prohibition Guard + Dead Env Var (SC-4)

- **D-23:** Phase 236 claims **`p17`**; Phase 241's SURF-04 moves to **`p18`**, with a one-line
  edit to `.planning/REQUIREMENTS.md:37` (which currently names `p17-*` for SURF-04). 236 runs
  first; 241 is the later, still-unwritten requirement. Two colliding `p17-*` files would both
  run and break nothing functionally, but the numbering would stop being a stable id.

- **D-24:** Guard file `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs`, with
  **one substitutable subject** (`test/example/priv/playwright/playwright.config.ts` via
  `subjectPath()`) per the `_lib.mjs` contract, exposing a pure `retryWrapperIssue(text)` checker
  applied to the subject and — as secondary artifacts read from their real locations — every
  `tests/*.spec.ts`. Assertions over **comment-stripped** content (`stripJsComments`):
  `retries:` present and literally `0`; no `retries` read from `process.env`; no per-project
  `retries:` override; no `test.describe.configure({ retries`; no `waitForTimeout(`; no
  `test.slow(`. Plus the mandatory non-vacuity floors (the config parse found a `retries:` line;
  the spec walk found ≥10 spec files).

- **D-25:** **Comment-stripping is load-bearing:** `playwright.config.ts:16-18` literally reads
  *"Retries stay at zero everywhere; CI shard commands repeat `--retries=0` explicitly"* — a
  naive `/retries/` match reds on the very prose that documents compliance.

- **D-26:** Ship a **committed** known-bad fixture
  `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` carrying all three violations at
  once (`retries: Number(process.env.PLAYWRIGHT_RETRIES ?? 1)` inside a `defineConfig`, a
  `page.waitForTimeout(500)`, and a `test.slow()`), fed in as `GSD_PROHIB_SUBJECT`; the clean half
  runs against the real config. Follow the `p01`–`p13` committed-fixture convention, **not** the
  inline-only negative controls of `p14`–`p16` — SC-4 demands a committed known-bad and
  ROADMAP constraint 6 says a guard never observed RED does not count.

- **D-27:** The `ci.yml:393` glob
  (`node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`, inside `fast_checks`)
  auto-discovers the new guard — **zero workflow edits**, and correctly outside `mix ci` per
  standing constraint 5.

- **D-28:** **Delete** `PLAYWRIGHT_RETRIES: 1` (`ci.yml:1460`); do not wire it. It has **zero**
  readers repo-wide outside `.planning/` prose. Wiring it would make the flagship parity job
  actually retry — the precise retry-wrap that GREEN-02, SC-4 and `ARCHITECTURE.md:275-277`
  prohibit — and would instantly violate the `p17` guard written in the same phase.

- **D-29:** Correct the two now-false claims at `.planning/research/STACK.md:81-82,195-204` that
  traces already exist (`SUMMARY.md:33` K5 already records the contradiction).

### Scope Boundary

- **D-30:** `audit_user_live.ex:98` and `users_index_live.ex:126` carry the **identical**
  `<form method="get">`-inside-a-LiveView pattern but stay **out of Phase 236**. SC-2 names
  `audit_index_live.ex` alone; the failing assertion is on `/admin/audit` alone; widening puts
  `user-audit-*.png` ×3 and the users-index baselines at recapture risk on top of
  `audit-explorer-*.png` ×3, against the standing "no PNG recapture lane opens" constraint.
  `users_index_live.ex` is additionally more entangled (existing `toggle_filters` `phx-click`
  and a `<.quick_filter>` component). **File a new pending todo** for both — a named deferral,
  not a silent one.

- **D-31:** `.planning/todos/pending/2026-07-18-admin-audit-impersonation-filter-not-applying.md`
  is **out of scope and already fixed** — close as resolved-by-verification. The
  duplicate-`action_prefix` checkbox chip it describes no longer exists on this surface; presets
  are now single-param `<a href>` links, and **the very test that is flaking is that bug's
  regression test** (`admin-generated.spec.ts:445-446` asserts `[name="outcome"]` and
  `[name="action_prefix"]` each `toHaveCount(1)`), added in `40240903` (v1.46). Verified:
  `sg-filter-chip` now survives only at `users_index_live.ex:352`.

- **D-32 (SC-5 fallback contract — planner must not trip on this):** The quarantine fallback
  writes a row into `.github/ci-skip-manifest.tsv`, an **8-column tab-separated** file
  (`tier, kind, id, parentJobId, displayName, gateLevel, gate, observer`) parsed by
  `_lib.mjs:parseSkipManifest`, which **throws on any row with fewer than 8 cells** — a 7-column
  row hard-fails `fast_checks` for every subsequent run. Adding a row also obliges a matching
  `MAINTAINING.md` entry, because the honest-skip-parity check asserts manifest ⇔ `ci.yml` ⇔
  `MAINTAINING.md` in every direction. **Open question for the planner:** SC-5 requires a *dated
  entry naming an owner*, and the current 8-column schema has **no column for date or owner** —
  either put them in the `observer` cell or extend the schema to 9 columns (extending is safe;
  the parser only rejects under-filled rows). Decide deliberately and record it.

- **D-33:** Retry-wrapping is **never** the fallback. The only accepted non-root-cause close is
  the D-32 dated, attributed quarantine entry.

### Claude's Discretion

- Exact naming of the `handle_event` message and its param-normalization helper.
- Whether `handle_params/3` gains a shared param-normalizer with the new `handle_event` or they
  stay separate (D-14 only requires the two produce identical URLs).
- Internal structure of `retryWrapperIssue(text)` and whether the spec-file walk is a helper or
  inline, so long as the non-vacuity floors of D-24 hold.
- Plan/commit granularity, subject to repro-before-fix ordering (SC-1 gates the fix).

### Folded Todos

- `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md`
  (tagged `resolves_phase: 236`) — folded; this phase resolves it. Note its citations are stale
  per D-06/D-07.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — `### Phase 236` (5 success criteria), the **Standing Constraints**
  (1-7) and **Scope Discipline** blocks under `# v1.48 CLEAN-BASELINE (active)`
- `.planning/REQUIREMENTS.md` — GREEN-01, GREEN-02, and the **Out of Scope** table (binding)
- `.planning/METHODOLOGY.md` — Decisive Defaulting, Escalation Threshold, Prompt And Prior-Art
  Weighting
- `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md`
- `.planning/todos/pending/2026-07-18-admin-audit-impersonation-filter-not-applying.md` (close
  per D-31)
- `.planning/todos/pending/2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md`
  (close per D-19)
- `lib/sigra/admin/live/audit_index_live.ex` — the fixed surface
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — lines 427-459
- `test/example/priv/playwright/tests/admin-audit.spec.ts` — lines 126-146 (the stable control)
- `test/example/priv/playwright/playwright.config.ts` — `retries: 0`, `trace`, `expect.timeout`
- `.github/workflows/ci.yml` — `:80-96` `release_ref_guard`, `:393` prohibition glob,
  `:1401-1421` the smoke job, `:1460` the dead env var
- `scripts/ci/prohibitions/_lib.mjs` — guard authoring contract (`subjectPath`,
  `stripJsComments`, `parseSkipManifest`)
- `scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs` — closest shape precedent
- `scripts/ci/admin-acceptance-smoke.sh` — `:28`, `:255-256`, `:398-404`
- `.github/ci-skip-manifest.tsv` + `MAINTAINING.md` — SC-5 fallback contract
- `priv/templates/sigra.install/admin/router_injection.ex` — `:28-41`, `:56-69` (two
  `live_session`s)
- `lib/sigra/admin/live/branding_live.ex` — `:155-156`, the in-repo `phx-submit` +
  `handle_event` precedent
- `guides/reference/admin-ui-principles.md`, `guides/reference/admin-design-contract.md`
  (CLAUDE.md mandate for any admin UI change)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`scripts/ci/prohibitions/_lib.mjs`** — the full guard contract: one substitutable subject via
  `subjectPath()`, secondary artifacts from real locations, `stripJsComments`, and
  `parseSkipManifest` (8-column, throws under-filled). `p01`–`p13` show the committed-fixture
  convention; `p16` shows the pure-function-plus-negative-control shape.
- **`ci.yml:393` glob** — new `*.test.mjs` guards are auto-discovered inside `fast_checks`; zero
  workflow wiring, and correctly outside `mix ci`.
- **`admin-audit.spec.ts:127-146`** — a *working* control driving the identical GET filter form.
  It is both the differential evidence for D-01 and the model for how the generated spec should
  sequence `waitForLiveViewReady`.
- **`branding_live.ex:155-156`** — the only in-repo `phx-submit` + `handle_event` form.
- **FAST-01 n=52 dispatch machinery** (v1.47) — reusable for repeat-run evidence; the ROADMAP
  forbids building a new harness.

### Established Patterns

- **URL state via plain GET form + `<a href>`** is repo-wide across all three admin index views
  (`audit_index_live.ex:76`, `audit_user_live.ex:98`, `users_index_live.ex:126`). `handle_event`
  is reserved for non-URL ephemeral state. **Zero `push_patch`/`<.link patch>` anywhere in
  `lib/sigra/admin/`** — D-08 is a deliberate divergence (D-16).
- **Path helpers resolve to the current scope** — `index_path/1` branches on
  `%Scope{mode: :organization}` (`:286-289`), so all filter links stay in-session (D-12).
- **Committed PNG baselines + `snapshot-canary-guard.sh`** — any rendered class/layout change
  forces a recapture lane, which this milestone forbids. D-11 is what keeps the fix admissible.
- **Guards must be observed RED** against a committed known-bad fixture (standing constraint 6).

### Integration Points

- `audit_index_live.ex` ↔ the generated router's **two** `live_session`s (D-12).
- `audit_index_live.ex` ↔ `lib/sigra/admin/components.ex` (shared row/table/mobile-card
  components, `:670-728`, `:1149-1166`) — untouched by D-08, which changes only anchors and one
  form attribute.
- `ci.yml` `generated_admin_playwright_smoke` → `ci-gate` → release-please `gate-ci-green` →
  `publish-hex`. This is why the phase is the milestone spine.
- `test/example/test/example_web/live/admin_audit_index_live_test.exs` — existing ExUnit
  coverage that must keep passing under `mix ci`.
</code_context>

<specifics>
## Specific Ideas

- **Repro before fix is a hard gate.** SC-1's captured RED is recorded with its run id or local
  artifact path, and *no fix is accepted without it*. D-05 keeps the diagnosis falsifiable.
- **`mix ci`, never root `mix test`**, before every push (standing constraint 3) — root
  `mix test` misses formatting and `test/example`.
- **Evidence at final committed HEAD on a clean tree** (standing constraint 2, the SC-5 lesson).
  A bundle rendered at a pre-commit SHA is invalid.
- **Count-only acceptance is rejected at review** (standing constraint 1). Observations come from
  the GitHub Actions API run list, not from reading YAML.
- If `trace: 'on'` is temporarily set in `playwright.config.ts` for D-21(b), it **must be
  reverted before merge** — otherwise the `p17` guard reds on its own repo.
</specifics>

<deferred>
## Deferred Ideas

- **The same GET-form-in-a-LiveView race on `/admin/users` and the per-user audit view** —
  `users_index_live.ex:126`, `audit_user_live.ex:98`. File as a new pending todo (D-30). Out of
  scope: SC-2 names one file, and widening risks 6+ more PNG baselines.
- **Template↔example parity guard** — already tracked as FUT-01 in the milestone's scope
  discipline; not this phase.
- **Repo-wide convergence on `<.link patch>` for admin filter panels** — a coherent follow-up
  once D-08 proves out, but explicitly not a v1.48 concern (this is not a UI milestone).

### Reviewed Todos (not folded)

- `2026-07-18-admin-audit-impersonation-filter-not-applying.md` — **close as
  resolved-by-verification** (D-31), do not carry into 236.
- `2026-07-28-generated-host-parity-verified-on-no-pr-while-gate-reports-green.md` — **close as
  already-resolved** by Phase 231 GATE-02/D-06 (D-19), citing `ci.yml:1408-1420`.
- `2026-06-20-playwright-parallelization-per-shard-db.md` — tagged `resolves_phase: 232`, not
  236; keyword-matched only. Leave pending.
- `2026-07-28-admin-eval-render-burns-17m-per-pr-*`, `2026-07-29-example-unit-smoke-required-*`,
  `2026-07-29-github-pages-source-builds-main-root-*`,
  `2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` — all `ci`-area keyword matches
  owned by Phases 231/237/241 or later. Leave pending.
- The remaining 30+ matches scored 0.6/0.4 on generic keywords (`audit`, `phase`, `gate`) and are
  unrelated to this phase's domain. Leave pending; Phase 243 (QUEUE-04) owns full todo triage.
</deferred>
