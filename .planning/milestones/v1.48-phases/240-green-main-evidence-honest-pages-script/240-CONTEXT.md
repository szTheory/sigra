# Phase 240: Green-Main Evidence + Honest Pages Script - Context

**Gathered:** 2026-09-18 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

"main is green" becomes a **measured** claim backed by GitHub Actions run ids, and the scripts
that report green can no longer report green while failing.

In scope (GREEN-04, GREEN-05):
- SC-1: n>=20 green runs of the previously-flaky lane via `workflow_dispatch`, every run id listed
  from the GitHub Actions API, captured at the **final committed HEAD on a clean tree**.
- SC-2: across that same window, `ci-gate` on `main` shows no red attributable to the flake, and the
  aggregate verdict is readable from the API run list rather than asserted in prose.
- SC-3: `scripts/ci/ensure-github-pages-legacy-branch.sh` fails loudly instead of logging and
  continuing, demonstrated RED against a stubbed/denied API response.
- SC-4: issue #231 closed with a comment citing those run ids and the live Pages state, verified via
  `gh issue view 231`; the two owning todos closed with the same evidence.

Out of scope (named, deliberately not fixed here):
- Adding `example_unit_smoke` to `ci-gate.needs` (disclosed in SC-2, owned by its own pending todo).
- Creating the missing `release-lane-rot` GitHub label (separate pending todo).
- The three `|| true` Pages **build-trigger** swallows (see D-13).
- Renaming or re-shaping any `ci.yml` job id (Phase 241 SC-3/SC-5 pin them).
</domain>

<decisions>
## Implementation Decisions

### A. The n>=20 repeat mechanism (SC-1)

- **D-01:** The repeats ship as a **new dispatch-only evidence workflow**, `.github/workflows/green-04-evidence.yml`, with `on: workflow_dispatch`, `if: github.ref == 'refs/heads/main'`, and a single job carrying `strategy: { fail-fast: false, max-parallel: 5, matrix: { repeat: [1..20] } }`. The live `ci.yml` job is **not** given a matrix and is **not** renamed.
- **D-02:** The evidence job body is a **byte-faithful copy** of `ci.yml`'s `generated_admin_playwright_smoke` steps (`ci.yml:1401-1533`): checkout, setup-beam, setup-node, hex/rebar, `mix archive.install --force hex phx_new 1.8.8`, `npm ci`, `npx playwright install --with-deps chromium webkit`, `scripts/ci/admin-acceptance-smoke.sh --test all`. Any drift makes the proof worthless — 20 green runs of a *sibling* harness say nothing about the lane that reds `ci-gate`.
- **D-03:** The copy is committed with an explicit comment citing `ci.yml:1401-1533` as its source of truth. A structural parity guard asserting the two step lists agree is **in scope if cheap** — new guards drop into `scripts/ci/prohibitions/*.test.mjs` with zero workflow edits (picked up by the glob at `ci.yml:393`, ROADMAP standing constraint 5).
- **D-04:** `max-parallel: 5` is **load-bearing, not cosmetic**. GitHub's concurrent-job ceiling is per-**account**, not per-repo, and public repos get no exemption (Free = 20, Pro = 40). An unset `max-parallel` means "take everything available", so a bare 20-wide matrix consumes 100% of a Free budget and queues every job of any concurrently-triggered PR behind it. 5 leaves 15 slots free and is safe on either tier; wall clock is 4 sequential waves.
- **D-05 (rejected alternative, recorded):** Dispatching `ci.yml` itself 20x. Zero divergence risk, but ~20x full-DAG runner cost, and it re-runs 20 copies of `admin_eval_render` — currently red on `main` — polluting the very run list SC-2 reads.
- **D-06 (rejected alternative, recorded):** Adding `matrix.repeat` to the live `generated_admin_playwright_smoke` job. Zero divergence, but `ci.yml:559-565` documents that a bare matrix suffixes the job name (`Library tests (1)`/`(2)`), which churns the PR lane and moves a job id that Phase 241 SC-3/SC-5 are about to pin. ("Generated admin Playwright smoke" is **not** one of the five ruleset-14941512 required contexts per `MAINTAINING.md:100-121`, so required-check orphaning is not the objection — PR-lane churn and 241 coupling are.)
- **D-07:** Cost is bounded and known: `ci.yml:1401-1407` records the job's measured duration as **3.73m** (230-EVIDENCE.md), so 20 repeats is roughly 75-100 runner-minutes in one dispatch.

### B. What "green" is read from (SC-1 + SC-2)

- **D-08:** Both SC-1 and SC-2 are measured at the **job conclusion** level — `GET /repos/szTheory/sigra/actions/runs/<id>/jobs`, selecting by job `name` — **never** at the run conclusion. This is the Phase 238 lesson inverted: read the job, not the run.
- **D-09:** The phase must state in prose that `ci.yml`'s **run-level** conclusion on `main` is currently `failure` for a reason outside `ci-gate`. Measured live: run **35365693716** (HEAD `bca3ad72`, the Phase 239 merge) concludes `failure`, but its only non-success job is `Admin eval render + probe`, which `ci.yml:2087-2106` documents as *not in `ci-gate.needs`*; and `Notify on red ci-gate` is `skipped` on that run, which per `ci.yml:1651-1652` positively proves `ci-gate` itself was not red. A naive `gh run list --branch main` would report red and misattribute it to the flake.
- **D-10:** The SC-2 verdict is reported as a **per-lane job table over the `main` window**, not as `ci-gate`'s conclusion alone, and the report **names in writing** that `example_unit_smoke` is absent from `ci-gate.needs` (`ci.yml:1547-1557` lists exactly ten entries) while being independently required by ruleset 14941512 — so a `ci-gate: success` is a nine-of-ten claim. `research/SUMMARY.md` OQ7 rules this "file it as a todo": Phase 240 **discloses** the caveat, it does not fix it.
- **D-11 (must-fix, research-upgraded):** Every Actions API read in the evidence tooling passes **`?per_page=100`** and asserts **`(.jobs|length) == .total_count`** (or uses `gh api --paginate`). The `/jobs` endpoint's default `per_page` is **30** and `ci.yml` expands to **exactly 30 jobs**. It returns all 30 today with page 2 empty, so it looks correct — one additional job or matrix leg and an unpaginated call silently drops it with no error and no signal. The `total_count`-vs-length assertion converts a future silent truncation into a hard failure. The `filter` parameter (default `latest`, vs `all` for superseded re-run attempts) is chosen **explicitly**, not left to default.
- **D-12:** The capture ships as a new **`scripts/ci/capture-green-04-evidence.sh` + `.test.sh` pair** modelled on `capture-fast-01-remeasurement.sh` (rate-limit preflight, paginated `gh api`, contiguous-page and terminal-empty-page assertions, fail-closed `jq -e` schema, canonical JSON with `schema_version` / `runs[].run_id` / `url` / `conclusion`), emitting a committed `240-EVIDENCE.md` in the `## BEFORE-*` / `## AFTER-*` slot grammar with `Status: captured (runs <id>, <id>, ...)`. That grammar is mechanically enforced by `scripts/ci/prohibitions/p12-run-id-provenance.test.mjs:26-60`; `236-EVIDENCE.md` is the adjacent worked example. `capture-fast-01-remeasurement.sh` itself is **not** extended — its cutoff SHA/timestamp are hardcoded protected constants (`:5-9`) pinned by `test/sigra/planning/phase_235_fast_01_*_contract_test.exs`, and editing it reopens v1.47 debt that Phase 241 owns.
- **D-13 (the SC-1 trap, load-bearing):** The capture must happen on a **clean tree at the final committed HEAD**. Phase 216's SC-5 precedent: a render-then-commit harness green at a *pre-commit* sha is invalid, because the stale-render guard rejects `bundle_sha != HEAD`. The plan must order the dispatch **after** the last code commit, not before.

### C. The honest Pages script (SC-3)

- **D-14 (research flipped this):** The fix covers **both** lenient paths in `scripts/ci/ensure-github-pages-legacy-branch.sh`, not just the 403 branch. The pre-research position was a surgical revert of the PUT-403 tolerance only, filing the rest as a todo; two findings overturned it.
- **D-15:** `:19` is **not** a `404 -> create` split today. `if ! pages_json=$(gh api "repos/${REPO}/pages" 2>/dev/null); then` treats *every* non-2xx — 403, 422, 500, a network blip, a rate limit — as "no Pages site yet" and falls through to POST-create. It is an `any-error -> create` split.
- **D-16:** The safe split is **available and verified**: on a **public** repo, `GET /pages` requires no admin, so 404 genuinely means "no site configured". Live-probed across 8 repos — `microsoft/TypeScript`, `rust-lang/rust`, `github/docs` -> 404; `elixir-lang`, `phoenixframework/phoenix`, `twbs/bootstrap`, `facebook/react`, `jekyll/jekyll` -> 200 where the prober is not an admin. GitHub's 404-masking-403 policy applies to *private* resources only. So: `404 -> create`, `200 -> inspect`, `* -> print body, exit 1`.
- **D-17:** The 403 **detection** on the PUT branch (`:66-68`) is replaced by an explicit status-code read. Today it is `if echo "${put_out}" | grep -qE '403|Resource not accessible by integration'` over a `2>&1`-merged blob — a bare unanchored `403` that matches inside a `documentation_url`, a request id, a rate-limit number, or a 500-page body, and can therefore swallow a genuine unrelated failure as "expected 403, carry on".
- **D-18:** The replacement uses **`gh api -i`**, and `-i` is **required, not stylistic**: a successful `PUT /pages` returns **204 No Content** with an empty body, so there is no JSON to parse and only the status line exists. Real `gh` 2.95.0 shape, captured live: status line is **stdout line 1** as `HTTP/2.0 403 Forbidden` (HTTP/2 wire version), then headers, blank line, then the JSON error body on stdout; `gh: <message> (HTTP 403)` goes to **stderr**; exit code is **1 for any HTTP failure** (so rc cannot discriminate 403 from 404 from 500); and **`--jq` is bypassed entirely on an error response**, dumping the raw error object. Branch on `204|200` -> ok, `403` -> the documented-tolerable case, `*` -> print body and `exit 1`.
- **D-19:** The tolerable-403 case remains tolerable **for the PUT specifically**: the caller declares `permissions: {contents: write, pages: write}` (`playwright-github-pages.yml:36-38`), and `pages: write` permits requesting a build but is **not** repo-admin — which is exactly why a settings-source PUT legitimately 403s. What SC-3 fixes is that this was previously indistinguishable from real failure, and that every *other* status fell through the same hole.
- **D-20:** The RED proof is a **`scripts/ci/ensure-github-pages-legacy-branch.test.sh` using a fake `gh` on `PATH`**, not a live observation — and this is **forced, not preferred**. `gh api repos/szTheory/sigra/pages` now returns `{"status":"built","build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}` (verified live), so `:49-53`'s "already gh-pages /" branch exits 0 before the PUT ever runs. **The 403 branch is unreachable on the real repo** — Phase 237's operator repoint (`237-PAGES-SETTING-RECORD.md`, D-07) removed the trigger. A plan that budgets a live 403 observation will stall with nothing to observe and be tempted into deliberately misconfiguring Pages on a public repo, an outward-facing settings mutation Phase 237 went to lengths to record and make revertible.
- **D-21:** The stub must reproduce **all four observable channels** of real `gh`, each verified against a real 403: (1) exit `1`; (2) status line as stdout line 1, `HTTP/2.0 403 Forbidden`; (3) JSON error body on **stdout** after a blank line; (4) `gh: <msg> (HTTP 403)` on **stderr**. A companion **success** stub emitting `HTTP/2.0 204 No Content` + headers + empty body, exit 0, is mandatory — that is the case a body-parsing implementation gets wrong. The idiom is already load-bearing here: `capture-terminal-ratification-evidence.test.sh:71-123` (`FAKE_MODE=api_failure`, `FAKE_GH_LOG`) and `capture-fast-01-remeasurement.test.sh:49-95` (`FAKE_HTTP=429`).
- **D-22:** The three `gh api .../pages/builds --method POST >/dev/null 2>&1 || true` **build-trigger** swallows (`:31`, `:52`, final line) are **left alone**, each with a one-line reason comment. Reddening the publisher on a transient build-trigger failure is the opposite of this milestone's "no red for a reason unrelated to the diff" posture. The no-token early `exit 0` (`:14-17`) likewise stays.
- **D-23:** `ensure-github-pages-legacy-branch.sh` is currently one of the few `scripts/ci/` scripts with **no sibling `.test.sh`** (~20 pairs exist). This phase closes that gap as a side effect of SC-3.

### D. Issue #231 and todo closure (SC-4)

- **D-24:** Issue **#231** is still **OPEN** (verified live: `ci-gate red on main (release-lane-rot)`) and is closed **last** in the phase, in this order: `gh issue comment` carrying the run-id list plus the live Pages payload, then `gh issue close`, then re-read via `gh issue view 231 --json state` as the verification artifact.
- **D-25:** Of the two owning todos, **only `2026-07-30-admin-generated-audit-presets-actor-filter-race.md` is still pending**. `2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` is **already in `.planning/todos/completed/`** (closed by Phase 237) — so SC-4 for that one is a **verification plus evidence-append**, not a move. A plan that budgets a move for it is burning a step.
- **D-26 (sharp edge):** The pending todo's body cites **a file that does not exist** (`lib/sigra/admin/live/audit_live.ex`) and stale line numbers (454-458, an "Apply filters" button HEAD's spec does not have). `236-CONTEXT.md` D-06/D-07 corrected these to `audit_index_live.ex` and `admin-generated.spec.ts:459`. The closure comment must cite the **corrected** coordinates, or it closes a todo against a description that was never true.
- **D-27:** The closure comment states an explicit **evidence window** (`runs <ids>`, `<start>..<end>`) rather than implying permanence, because `notify_release_lane_rot` (`ci.yml:1647-1684`) is a machine that opens/updates an issue titled exactly `ci-gate red on main (release-lane-rot)` — the title of #231 — on any `failure` of `ci-gate` on a non-PR event. Future re-filing is **correct behaviour**, not a falsification of this phase's claim.
- **D-28:** The known-missing `release-lane-rot` GitHub label (`.planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md`) is **named, not fixed** — an adjacent defect owned by its own todo. Fixing it here is scope creep (ROADMAP standing constraint 4).

### Claude's Discretion

- Exact file/step naming inside `green-04-evidence.yml` and `capture-green-04-evidence.sh`, provided D-02's byte-faithfulness and D-11's pagination assertions hold.
- Whether the step-list parity guard (D-03) ships as a `prohibitions/*.test.mjs` or as a comment-only invariant, judged on cost during planning.
- The precise `case` / `awk` shape of the status-code read in D-18, provided it reads the status line rather than grepping a merged blob.
- Whether the `404 -> create` split in D-16 and the PUT status read in D-18 land as one commit or two.

### Folded Todos

- `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md` — named by SC-4 as an owning todo; closed with this phase's evidence, citing the D-26 corrected coordinates.
- `.planning/todos/completed/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` — named by SC-4; already closed, so verification plus evidence-append only (D-25).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — lines 30-76 (standing constraints + scope discipline), lines 257-271 (Phase 240 verbatim)
- `.planning/REQUIREMENTS.md` — lines 17-21 (GREEN-01..05), lines 125-139 (Out of Scope)
- `.planning/research/SUMMARY.md` — K9 (line 37), Pages rows (lines 80-82), OQ5 (line 298), OQ7 (line 300)
- `.planning/METHODOLOGY.md` — decisive defaulting and escalation threshold
- `.github/workflows/ci.yml` — `1401-1533` (`generated_admin_playwright_smoke`), `1534-1637` (`ci-gate`), `1547-1557` (the ten `needs:`), `1647-1684` (`notify_release_lane_rot`), `506-580` (shard+aggregator naming precedent), `2087-2110` (`admin_eval_render`, not in `ci-gate.needs`), `1-35` (dispatch inputs), `393` (prohibitions glob), `559-565` (matrix-name hazard)
- `scripts/ci/ensure-github-pages-legacy-branch.sh` — whole file; SC-3 targets are `:19` and `:66-74`
- `.github/workflows/playwright-github-pages.yml` — `:36-38` (permissions), `:196-211` (the sole caller)
- `.github/workflows/fast-01-remeasurement-evidence.yml` + `scripts/ci/capture-fast-01-remeasurement.sh` + `scripts/ci/capture-fast-01-remeasurement.test.sh`
- `.github/workflows/generated-app-login-runtime-proof.yml` — precedent for a dispatch-only duplicated generated-host job
- `scripts/ci/capture-terminal-ratification-evidence.test.sh:60-125` — the fake-`gh` stub idiom
- `scripts/ci/prohibitions/p12-run-id-provenance.test.mjs`, `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs`, `scripts/ci/prohibitions/_lib.mjs`
- `scripts/ci/honest-skip-verdict.sh` (+ `.test.sh`) — already emits the `example_unit_smoke` advisory NOTE that D-10 cites
- `scripts/ci/admin-acceptance-smoke.sh` — `:29-31` (defaults), `:53-68` (arg parse), `:361-398` (`--test` dispatch)
- `.planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md`, `236-CONTEXT.md` (D-06/D-07 stale-citation corrections), `236-VERIFICATION.md` (the `deferred:` block hands GREEN-04 to Phase 240 explicitly)
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-PAGES-SETTING-RECORD.md` — pre-change Pages payload + D-07 rationale
- `.planning/todos/pending/2026-07-30-admin-generated-audit-presets-actor-filter-race.md`
- `.planning/todos/completed/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
- `.planning/todos/pending/2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md`
- `MAINTAINING.md:100-124` — the five ruleset-required contexts (`ci-gate` is not one)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Evidence-collector triad** — `scripts/ci/capture-fast-01-remeasurement.sh` / `.test.sh` /
  `.github/workflows/fast-01-remeasurement-evidence.yml`: paginated `gh api`, rate-limit preflight,
  fail-closed `jq -e` canonical JSON, `actions/attest-build-provenance` + `upload-artifact`,
  `if: github.ref == 'refs/heads/main'`, `permissions: {contents: read, actions: read, id-token: write, attestations: write}`.
  This is the model for D-12, copied rather than extended.
- **Fake-`gh`-on-PATH stub harness** — `capture-terminal-ratification-evidence.test.sh`
  (`FAKE_MODE=api_failure`, `FAKE_GH_LOG`) and `capture-fast-01-remeasurement.test.sh`
  (`FAKE_RUNS`, `FAKE_HTTP=429`, `FAKE_REMAINING`). Ready-made mechanism for D-20/D-21.
- **Duplicated generated-host dispatch job** — `generated-app-login-runtime-proof.yml`: an existing,
  accepted precedent for copying `ci.yml` generated-host steps into a dispatch-only workflow,
  including a receipt-validation step. Directly validates D-01.
- **Evidence-ledger slot grammar** — `236-EVIDENCE.md` table plus `## BEFORE-*` / `## AFTER-*`
  sections, parsed by `_lib.mjs`'s `parseEvidenceSlots`.
- `scripts/ci/honest-skip-verdict.sh` — already emits the `example_unit_smoke` advisory NOTE.

### Established Patterns

- **Guards are offline and structural, never live-API, on the PR critical path**
  (`p12:8-20`, `p19:15-22`); the live half goes in `ci-observe.yml` or a dispatch evidence workflow.
- **A guard must be observed RED against a committed known-bad fixture** under
  `test/fixtures/prohibitions/` in the commit it is born (ROADMAP standing constraint 6; the
  `p17`/`p19` idiom: non-vacuity floor test plus negative control).
- **New prohibition guards drop into `scripts/ci/prohibitions/*.test.mjs` with zero workflow edits**
  (glob at `ci.yml:393`); never into `mix ci` (standing constraint 5).
- **Shell scripts under `scripts/ci/` carry a sibling `*.test.sh`** — roughly 20 pairs exist;
  `ensure-github-pages-legacy-branch.sh` is one of the few without (D-23).
- **Job names are load-bearing** — `ci.yml:559-565` documents matrix-name suffixing as a
  required-check orphaning hazard.

### Integration Points

- `ci-gate.needs` (`ci.yml:1547-1557`) is the ten-lane list; `honest-skip-verdict.sh`'s lane flags
  (`ci.yml:1592-1601`) and `_lib.mjs`'s `NEVER_DOCS_GATED` must stay in three-way parity with it.
  **Do not touch without re-reading Phase 241 SC-3.**
- `release-please.yml`'s `gate-ci-green` polls `ci-gate` and nothing else (via
  `scripts/ci/wait-for-ci-gate.sh`) — which is why SC-2's verdict shape matters for Phase 242's cut.
- `playwright-github-pages.yml:206-211` is the sole caller of the Pages script, guarded by
  `if: steps.gh_pages_push.outcome == 'success'` with `pages: write` on the job. A loud `exit 1`
  there reddens the publisher job (intended); that job is **not** in `ci-gate.needs`.
- `notify_release_lane_rot` (`ci.yml:1647-1684`) is the machine that files issues titled
  `ci-gate red on main (release-lane-rot)` — the producer of #231.

### Live State Verified During Analysis (2026-09-18)

- Pages: `{"status":"built","build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}`
- Issue #231: **OPEN**
- Latest `main` run `35365693716` (HEAD `bca3ad72`): run conclusion `failure`; sole non-success job
  `Admin eval render + probe` (outside `ci-gate`); `notify_release_lane_rot` **skipped**, which
  proves `ci-gate` was not red.
- `ci.yml` expands to **exactly 30 jobs** on a real run; `/jobs` default `per_page` is 30.
- `gh` version 2.95.0; repo `szTheory/sigra` is public, owner type User.
</code_context>

<specifics>
## Specific Ideas

- The evidence dispatch must run **after** the final code commit on a clean tree (D-13) — this is
  the Phase 216 SC-5 trap, and it constrains plan ordering, not just plan content.
- `240-EVIDENCE.md` follows `236-EVIDENCE.md`'s slot grammar exactly, because `p12` parses it.
- The #231 closure comment is the last action of the phase and cites: the 20 run ids, the live Pages
  payload, the corrected todo coordinates (D-26), and an explicit evidence window (D-27).
</specifics>

<deferred>
## Deferred Ideas

- **Add `example_unit_smoke` to `ci-gate.needs`** — disclosed by D-10, fixed by its own pending todo.
  `research/SUMMARY.md` OQ7 already routed it this way.
- **Create the missing `release-lane-rot` GitHub label** — D-28; owned by
  `2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md`.
- **Harden the three Pages build-trigger `|| true` swallows** — D-22; deliberately left lenient.
- **A general `total_count`-vs-length pagination audit across all existing `capture-*` collectors** —
  D-11 fixes it in the new script only; the existing collectors paginate the *runs* endpoint, not
  the *jobs* endpoint, and were not re-audited here. Worth a todo.

### Reviewed Todos (not folded)

66 todos keyword-matched Phase 240; the roadmap boundary is fixed, so only the two SC-4-named todos
were folded. The near-misses, each left out for a stated reason:

- `2026-07-29-example-unit-smoke-required-but-absent-from-ci-gate-needs.md` — informs D-10's
  disclosure but is not fixed here.
- `2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` — D-28, named not fixed.
- `2026-09-15-admin-eval-render-isolated-red-has-no-consumer.md` and
  `2026-07-28-admin-eval-render-burns-17m-per-pr-for-an-unread-red.md` — `admin_eval_render` is the
  job making run-level `main` red (D-09). Relevant as context, out of scope to fix.
- `2026-09-15-p12-evidence-guard-is-pinned-to-phase-230.md` — p12 is hardcoded to phase 230, so it
  will not automatically guard `240-EVIDENCE.md`. Noted; extending it is Phase 241's call.
- `2026-09-16-*` / `2026-09-17-*` docs and bookkeeping todos — Phase 241 (DEBT/SURF) territory.
</deferred>
