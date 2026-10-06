# Phase 240: Green-Main Evidence + Honest Pages Script - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-09-18
**Phase:** 240-green-main-evidence-honest-pages-script
**Mode:** assumptions
**Areas analyzed:** Repeat mechanism (SC-1), Green-verdict source (SC-1+SC-2), Honest Pages script (SC-3), Issue/todo closure (SC-4)

## Assumptions Presented

### A. The n>=20 repeat mechanism (SC-1)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New dispatch-only `green-04-evidence.yml` with a 20-wide matrix; live `ci.yml` job untouched | Likely | `fast-01-remeasurement-evidence.yml`, `terminal-ratification-evidence.yml`, `generated-app-login-runtime-proof.yml` (3 existing precedents); `ci.yml:559-565` matrix-name hazard; `ci.yml:1401-1407` measured 3.73m |
| `max-parallel: 5`, not unset | Confident (post-research) | GitHub concurrency is per-account: Free=20, Pro=40, no public-repo exemption; `max-parallel` default is "maximize ... depending on runner availability" |

Alternatives weighed and rejected: dispatch `ci.yml` 20x (cost + pollutes SC-2's run list with `admin_eval_render` red); matrix on the live job (renames a job id Phase 241 SC-3/SC-5 pin).

### B. What "green" is read from (SC-1 + SC-2)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Measure at job conclusion, never run conclusion | Confident | Live: run `35365693716` = `failure`, sole non-success job `Admin eval render + probe` (`ci.yml:2087-2106`, not in `ci-gate.needs`); `notify_release_lane_rot` skipped per `ci.yml:1651-1652` proves `ci-gate` not red |
| SC-2 discloses `example_unit_smoke` absence in writing | Confident | `ci.yml:1547-1557` (ten `needs:`); `research/SUMMARY.md` OQ7 routes it to a todo |
| `per_page=100` + `length == total_count` assertion | Confident (post-research) | `/jobs` default `per_page` = 30; `ci.yml` expands to exactly 30 jobs — at the truncation boundary |
| New `capture-green-04-evidence.sh` + `.test.sh` modelled on `capture-fast-01-remeasurement.sh` | Likely | `p12-run-id-provenance.test.mjs:26-60` enforces the slot grammar; `236-EVIDENCE.md` worked example; `capture-fast-01-*` has protected constants at `:5-9` pinned by a contract test, so it is copied not extended |

### C. The honest Pages script (SC-3)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fix both `:19` and `:66-74`, not the 403 branch alone | Confident (post-research; this REVERSED the pre-research position) | `:19` is `any-error -> create`, not `404 -> create`; 8-repo live probe shows `GET /pages` needs no admin on public repos, so 404 is unambiguous |
| Read the status line via `gh api -i`, not a stderr grep | Confident (post-research) | Bare unanchored `403` matches inside `documentation_url`/request-id/rate-limit/500-body; `gh` rc is 1 for ALL HTTP failures; `--jq` is bypassed on error responses; successful PUT is 204 with an empty body so `-i` is mandatory |
| RED proof is a fake-`gh` stub, not a live observation | Confident | Live: Pages = `built`/`legacy`/`gh-pages`/`/`, so `:49-53` exits 0 before the PUT — the 403 branch is unreachable on the real repo after Phase 237's repoint |
| The three build-trigger `|| true` swallows stay | Confident | Reddening the publisher on a transient build trigger inverts the milestone's "no red unrelated to the diff" posture |

### D. Issue #231 and todo closure (SC-4)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| #231 still OPEN; closed last, comment -> close -> re-read | Confident | Live `gh issue view 231` -> OPEN, title `ci-gate red on main (release-lane-rot)` |
| Only the audit-presets todo is pending; the Pages todo is already completed | Confident | `.planning/todos/completed/` holds the Pages todo; `.planning/todos/pending/` holds the audit-presets one |
| Closure comment cites CORRECTED coordinates | Confident | Pending todo cites `lib/sigra/admin/live/audit_live.ex` (does not exist) and stale lines 454-458; `236-CONTEXT.md` D-06/D-07 corrects to `audit_index_live.ex` + `admin-generated.spec.ts:459` |
| State an explicit evidence window; name but do not fix the missing label | Likely | `ci.yml:1647-1684` re-files this exact title on any future red `ci-gate` on main |

## Corrections Made

No corrections — all assumptions confirmed at the gate ("Yes, proceed").

Note for the record: two assumptions were revised **by research, before** presentation, not by the user.
- Area C moved from "surgical revert of the PUT-403 branch only, file the rest as a todo" to
  "fix both swallows" once the live probe established that `:19` is an `any-error -> create` split
  and that a `404 -> create` split is safe on a public repo.
- Area B's pagination item was upgraded from a theoretical concern to must-fix once `ci.yml` was
  measured at exactly 30 jobs against a default `per_page` of 30.

## External Research

Four gaps were flagged by the codebase analyzer and researched before the assumptions were presented.

1. **20-wide matrix concurrency on a public repo** — Concurrency ceiling is per-**account**, not
   per-repo; public repos get unlimited *minutes* but no concurrency exemption. Free = 20 concurrent
   jobs, Pro = 40, Team = 60, Enterprise = 500. Over-cap jobs **queue** (they are not cancelled).
   `max-parallel` unset means "take everything available", so a bare 20-wide matrix consumes 100% of
   a Free budget and starves any concurrent PR. Matrix cap is 256 jobs/run.
   Recommendation: `max-parallel: 5` — safe on Free or Pro, 4 sequential waves.
   (Source: docs.github.com/en/actions/reference/limits; workflow-syntax `max-parallel`.)
   *Resolves D-04 at high confidence. Account tier (Free vs Pro) was not readable, but 5 is safe either way.*

2. **`/actions/runs/{id}/jobs` pagination** — Paginates; `per_page` default **30**, max 100; `page`
   default 1. `total_count` is the true total and is NOT capped by `per_page` (proven: `per_page=5`
   -> `total_count=30`, `jobs|length=5`, plus a `Link:` header with `rel="next"`/`rel="last"`).
   `filter` default is `latest` (most recent execution only); `all` includes superseded re-run
   attempts, which can double-report a job name if matching by name.
   Live: run `35365693716` has exactly **30** jobs — at the default boundary. `--paginate` sums to 30
   across 6 pages.
   (Source: docs.github.com/en/rest/actions/workflow-jobs; live probes.)
   *Resolves D-11 at very high confidence, and upgrades it from theoretical to must-fix.*

3. **GitHub Pages API failure taxonomy** — `GET /pages` documents 200 and 404 only (no 403);
   `POST` documents 201/409/422; `PUT` documents 204/400/409/422. GET carries no admin requirement,
   POST/PUT require repo admin or "manage GitHub Pages settings". Live 8-repo probe confirms GET is
   effectively a public read on public repos: `microsoft/TypeScript`, `rust-lang/rust`, `github/docs`
   -> 404 (genuinely no site); `elixir-lang`, `phoenixframework/phoenix`, `twbs/bootstrap`,
   `facebook/react`, `jekyll/jekyll` -> 200 where the prober is not an admin. GitHub's
   404-instead-of-403 masking applies to *private* resources.
   Caveat carried forward: a real `GITHUB_TOKEN` (App installation token) could not be exercised
   against `/pages` without mutating state, so a 403-on-GET cannot be 100% excluded if `pages`
   permission were ever dropped — which is itself an argument for the explicit status branch.
   (Source: docs.github.com/en/rest/pages/pages; live probes.)
   *Resolves D-15/D-16 at high confidence and reversed the Area C recommendation.*

4. **`gh api` exit code and output shape on 403** — Observed against a real 403 on `gh` 2.95.0.
   Exit code is **1 for any HTTP failure** (2 = cancelled, 4 = auth required), so rc cannot
   discriminate 403 from 404 from 500. JSON error body goes to **stdout** (carrying a
   `"status":"<code>"` field); a one-line `gh: <message> (HTTP 403)` goes to **stderr**. `--jq` is
   **bypassed** on an error response and dumps the raw error object. `gh api -i` is reliable: the
   status line is stdout line 1, format `HTTP/2.0 403 Forbidden` (HTTP/2 wire version), then headers,
   blank line, body. A successful `PUT /pages` is **204 No Content** with an empty body, so `-i` is
   required — there is no JSON to parse.
   (Source: `gh help exit-codes`; live 403 probe via a read-only GET the token cannot access.)
   *Resolves D-17/D-18/D-21 at very high confidence, and yields a stub spec that provably matches
   real `gh` on all four observable channels.*

## Todo Cross-Reference

66 todos keyword-matched phase 240 (13 at score 0.9, the rest 0.6/0.4). The ROADMAP boundary is
fixed, so only the two SC-4-named todos were folded; the near-misses and their exclusion reasons are
recorded in CONTEXT.md's `<deferred>` section. No AskUserQuestion was raised for todo selection —
per METHODOLOGY.md, the roadmap had already decided the boundary.
