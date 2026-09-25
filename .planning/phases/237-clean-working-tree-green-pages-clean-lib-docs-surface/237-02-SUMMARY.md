---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 02
subsystem: ci
tags: [github-pages, jekyll, repo-settings, docs]
status: complete

requires:
  - "repository admin permission on the Pages API (measured: admin true)"
  - "origin/gh-pages exists with a root .nojekyll (measured in 237-RESEARCH §C.4)"
provides:
  - "GitHub Pages served from the dedicated publish branch, status built"
  - "a committed, literal revert value for the Pages source setting"
affects:
  - "the public site at https://sztheory.github.io/sigra/ — it now serves the Playwright report index instead of a failing Jekyll build of the source repository root"

tech-stack:
  added: []
  patterns:
    - "outward-facing settings change: record the prior value in a committed file BEFORE the mutation, so the revert is a known value"
    - "a write's own response is not an observation of the resulting state — read back live, and fetch the real surface"

key-files:
  created:
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-PAGES-SETTING-RECORD.md
  modified:
    - guides/introduction/code-walkthrough.md

decisions:
  - "D-07 applied as written: Pages repointed main -> gh-pages; a root .nojekyll on main was NOT added"
  - "SC-2's '.nojekyll backstop' recorded as already-satisfied on the publish branch, not re-done"
  - "SC-2's 'no longer crashes the legacy Jekyll builder' clause is vacuously true under D-07; the guide edit is defence in depth, not the cause of the green check"

metrics:
  duration: ~20m
  completed: 2026-09-16
  tasks: 2

actuals:
  tokens: 9000
  tasks: 2
  commits: 3

plan_head_before: 3bd5146111a14571395aaf542068ada1aa9e492f
commits_note: >
  `git rev-list --count 3bd5146..HEAD` reports 6, but this plan executed in the SHARED main
  working tree alongside concurrent sibling plans 237-01 and 237-03, whose commits fall inside
  the same range. This plan's own commits, measured with
  `git rev-list --count --grep='(237-02)' 3bd5146..HEAD`, are 3. Both numbers are recorded so
  the discrepancy is visible as tree-sharing rather than as a miscount.
---

# Phase 237 Plan 02: Green Pages Summary

GitHub Pages now builds `built` and serves HTTP 200 from the dedicated `gh-pages` publish branch
instead of erroring on a Jekyll build of the default branch's repository root — the root cause of
eight consecutive `pages build and deployment` failures, fixed at its source rather than at its
symptom, with the prior setting committed first as a literal revert value.

## What was done

### Task 1 — record, repoint, prove (tracer)

**Order was record → change → observe, uncompressed.**

1. Captured `gh api repos/szTheory/sigra/pages` verbatim at `2026-09-16T13:08:27Z` into
   `237-PAGES-SETTING-RECORD.md` — full payload, plus the literal one-line revert command that
   restores the recorded `build_type` + `source` pair, plus the swallowed-403 history explaining
   why the publisher workflow could never do this itself. **Committed as `06169df2` before the
   PUT.**
2. Performed the PUT exactly as D-07 specifies. Result: **HTTP 204, no body, exit 0** — no 403.
   The local token authenticates with repository `admin: true`; the Actions default token, which
   had been 403ing since 2026-07-31, does not.
3. Requested a build (`POST …/pages/builds` → `queued`) and observed the outcome **twice,
   independently**. The PUT returned no body at all, so nothing here rests on its echo.

**Observation 1 — live API read-back.** The polling loop (60 × 10s; `built` passes,
`building`/`null` polls on, anything else fails immediately) **settled on the first iteration**:
`status` had moved from `errored` to `built`. The build record for the explicitly-requested build
confirms it completed cleanly:

```
{"commit":"29e6ad40bf3e892d7582e7c07ed1fa7cc7910ec1","created_at":"2026-09-16T13:09:38Z",
 "duration":25514,"error":{"message":null},"status":"built","updated_at":"2026-09-16T13:10:03Z"}
```

`commit` is a `gh-pages` tip, not a `main` commit, so the builder is demonstrably sourcing the
publish branch. Final state, re-read at `2026-09-16T13:11:21Z`:
`{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"},"status":"built"}`.

**Observation 2 — real HTTP fetch.** `curl -sSI https://sztheory.github.io/sigra/` →
`HTTP/2 200`, with `last-modified: Wed, 16 Sep 2026 13:10:03 GMT` — **exactly** the build's
`updated_at`, so the served bytes are the output of the build observed above, not a stale cache.
The 2xx assertion was run with a negative control in the same block (a nonexistent path under the
same host → exit 1), so the pass is not an artifact of a check that cannot fail.

### Task 2 — remove the Liquid-crashing construct (defence in depth)

`guides/introduction/code-walkthrough.md:174` interpolated a map literal directly inside a path
sigil, producing the two-character sequence the legacy builder's templating engine reads as an
unterminated opening tag. The map is now bound to a local on its own line and the local is
interpolated instead:

```
-      |> redirect(to: ~p"/organizations/#{slug}/sso?#{%{routing_source: "local_policy"}}")
+      query = %{routing_source: "local_policy"}
+
+      conn
+      …
+      |> redirect(to: ~p"/organizations/#{slug}/sso?#{query}")
```

The redirect target, query key and query value are byte-identical; only the expression's shape
changed. The rewritten snippet was parse-checked with `Code.string_to_quoted/1` (**PARSE_OK**,
with a deliberately-broken control that failed as expected, so the OK is not vacuous). No
templating-engine escape wrapper was used — it would render as literal noise in the HexDocs build
that also renders this guide. The file now contains **zero** occurrences of the tag-shaped
sequence (positive control: `grep -c redirect` → 4, so the search ran).

**This edit is not the cause of the green check.** Under D-07 the legacy builder never parses
repository guides at all, so SC-2's "no longer crashes the legacy Jekyll builder" clause is
vacuously true. The edit exists so the failure cannot recur if the source is ever repointed at the
default branch.

## Verification

Every check re-run end to end after the final commit, at the tracer feedback gate and again at
close:

| Check | Result |
|---|---|
| `gh api …/pages --jq .source.branch` = `gh-pages` | exit 0 |
| status poll settles on `built` | exit 0, **1 iteration** |
| `curl … \| grep -Eqx "2[0-9][0-9]"` on the published URL | exit 0 (control on a 404 path: exit 1) |
| record file tracked **and** contains the verbatim pre-change `"branch": "main"` | exit 0 |
| `! grep -Fq '#{%{'` in the guide | exit 0 |
| `routing_source` still present (positive control for the above) | exit 0 |
| `local_policy` and `/sso` still present | exit 0 |
| user-enumeration rationale comment survives verbatim (`grep -Fq`) | exit 0 |
| no root Jekyll-bypass marker tracked on the default branch | no output (control: `git ls-files CLAUDE.md` → `CLAUDE.md`) |
| `scripts/ci/ensure-github-pages-legacy-branch.sh` byte-unchanged vs `git merge-base origin/main HEAD` | exit 0 |
| issue #231 still `OPEN` | `OPEN` |
| `git diff --stat` on the guide | 1 file, +3 −1, confined to the routing example |

## Prohibitions honoured

- **No Jekyll-bypass marker was added to the default branch root.** The explicitly rejected
  option in D-07; adding one would have published `CLAUDE.md`, `AGENTS.md`, `brandbook/` and
  `.planning/` as a public static site.
- **`scripts/ci/ensure-github-pages-legacy-branch.sh` was not touched** and **issue #231 was not
  closed** — both belong to Phase 240 (GREEN-05). Verified against the phase merge-base, not a
  revisionless diff.
- **No Elixir semantics changed** in the routing snippet.
- **Pages was not declared fixed on the PUT's response.** The PUT had no response body; both
  observations are independent live reads.

## Deviations from Plan

**1. [Procedural] Commits made on the default branch `main`.**
The executor contract normally halts rather than committing to a protected/default branch. The
orchestrator directive for this plan explicitly specified `isolation: none`, "work on `main`", and
"do NOT create a git worktree"; `.planning/config.json` sets `git.branching_strategy: "none"`.
Proceeded as directed and recording it here so the choice is visible rather than silent.

**2. [Measurement] `commits:` recorded as this plan's own 3, not the ledger range's 6.**
The ledger-measured range `3bd5146..HEAD` contains 6 commits because sibling plans 237-01 and
237-03 committed into the same shared working tree concurrently. Both numbers are recorded in the
frontmatter (`actuals.commits: 3`, `commits_note` carrying the raw 6 and the command for each) so
the discrepancy reads as tree-sharing rather than as a miscount.

No auto-fixes under deviation Rules 1–3 were required; no architectural decisions arose.

## Notes for downstream phases

- The pending todo
  `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` now has
  its "Required owner action" **performed** — steps 1 and 2 of its checklist are satisfied and its
  premise is resolved. It was deliberately **left in place, unmoved and unclosed**: relocating it to
  `resolved/` and closing issue #231 are Phase 240's SC-4.
- The swallowed 403 in `scripts/ci/ensure-github-pages-legacy-branch.sh` is still swallowed. Now
  that the source is already correct, that script's PUT will be a no-op rather than a failure — so
  the 403 stops masking a broken site, but the loud-failure repair (Phase 240 / GREEN-05) is still
  needed to keep it from masking a future regression.
- Three same-shaped **non-fatal** Liquid warnings remain in `MAINTAINING.md` (copied workflow
  YAML). They are warnings only, they are out of this plan's scope, and under D-07 the builder
  never parses that file either.

## Known Stubs

None. No stub values, placeholder text, skipped tests, or unrun `<verify>` commands were produced
by this plan — every verification in the table above was executed and its exit status recorded.

## Self-Check: PASSED

- `FOUND: .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-PAGES-SETTING-RECORD.md`
- `FOUND: guides/introduction/code-walkthrough.md`
- `FOUND: 06169df2` — docs(237-02): record pre-change GitHub Pages configuration and revert command
- `FOUND: 188ea7c5` — feat(237-02): repoint GitHub Pages at the gh-pages publish branch (D-07)
- `FOUND: e0d98092` — docs(237-02): remove the Liquid-crashing interpolated map literal
