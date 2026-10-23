---
phase: 240-green-main-evidence-honest-pages-script
plan: 04
subsystem: ci
tags: [ci, evidence, green-04, dispatch, p12, d13]
status: complete

requires:
  - "scripts/ci/capture-green-04-evidence.sh (plan 240-03) — the non-steerable SC-1/SC-2 collector"
  - ".github/workflows/green-04-evidence.yml (plan 240-02) — the n>=20 dispatch matrix, on `main` as of abec92c4"
  - "scripts/ci/ensure-github-pages-legacy-branch.sh + its self-test (plan 240-01)"
  - "scripts/ci/prohibitions/p12-run-id-provenance.test.mjs — the ledger grammar this flip must satisfy"
provides:
  - ".planning/phases/240-.../240-GREEN-04-EVIDENCE.json — canonical receipt, schema sigra.green-04-evidence/v1"
  - "dispatch run 35377050754 — 20/20 legs `success` at head_sha abec92c4b33005e21b550a2f899fe1d1e0f817a1"
  - "the declared `main` evidence window 2026-09-16T03:29:55Z .. 2026-09-18T18:11:54Z"
  - ".planning/phases/240-.../240-EVIDENCE.md — five slots `captured` with run ids, one `pending`"
  - "GREEN-04 satisfied and marked complete"
affects:
  - "Plan 240-05 — owns AFTER-ISSUE-231-CLOSED and GREEN-05; the closure comment should cite run 35377050754 and this window"

tech-stack:
  added: []
  patterns:
    - "post-evidence documentation commit (D-13): capture on a clean tree at the final committed HEAD, record head_sha + clean_tree INSIDE the receipt, then let HEAD move — the claim is self-dating"
    - "fail-closed `jq -e` assertion of a receipt, with an explicit negative control proving `jq -e` really reds"
    - "per-lane job table as the verdict (D-08), with the run-level conclusion printed beside it and explicitly labelled NOT the verdict"

key-files:
  created:
    - .planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json
  modified:
    - .planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md

decisions:
  - "Window start is 2026-09-16T03:29:55Z — the `created_at` of run 35052017063, the oldest `main` ci.yml run at or after the Phase 236 flake fix landed at b6e889c4 (2026-09-16T03:29:52Z). Start = that run's own created_at rather than the commit timestamp, so the bound is a fact about the run list rather than about git."
  - "Window end is the capture instant 2026-09-18T18:11:54Z, which includes `main` push run 35377012499 (HEAD abec92c4). That run was still `in_progress` at capture, but only because `Admin eval render + probe` — the non-gate lane — was still running; its `ci-gate` and `Generated admin Playwright smoke` jobs had already concluded `success`. Including it is strictly more honest than trimming the window to end before it, and the D-08 job-level read is exactly what makes it safe to include."
  - "AFTER-PAGES-LOUD-RED and AFTER-P20-GUARD-OBSERVED cite TWO run ids each (35377012499 the `main` push run, 35376244993 the PR run that gated the squash). The plan asked for one; naming both records that the guards ran pre-merge and post-merge, and both ids are corroborated in-slot."
  - "The local `MIX_ENV=test mix ci` gate was WAIVED as exogenous by explicit operator decision — see the waiver section below. This plan changed no Elixir source, test, dep or config file."

metrics:
  duration: ~25m
  completed: 2026-09-18
  tasks: 3
  commits: 2

actuals:
  tokens: 34000
  tasks: 3
  commits: 2
---

# Phase 240 Plan 04: GREEN-04 Live Capture and Ledger Flip Summary

Twenty dispatched legs of the generated-admin Playwright lane concluded `success` at the final
committed HEAD on a clean tree, and the receipt that proves it is self-dating — so the five
capturable ledger slots now carry their run ids under a grammar `p12` actually parses.

## What was done

Tasks 1 and 2 were operator checkpoints and were already discharged before this executor ran:
the fifteen wave-1/2 commits were branched, opened as PR #246, CI-gated green (PR run
`35376244993`), and squash-merged to `main` as **`abec92c4b33005e21b550a2f899fe1d1e0f817a1`**;
`green-04-evidence.yml` was then dispatched once on `main` as run **`35377050754`**
(`event: workflow_dispatch`, `headSha` an exact match to the final committed HEAD — D-13),
concluding `success` with a leg tally of `{"success": 20}`.

**Task 3 (commit `33d5d8db`)** — the live capture and the flip:

1. Confirmed the D-13 preconditions before touching anything: `git status --porcelain` empty,
   `git rev-parse HEAD` = `abec92c4b33005e21b550a2f899fe1d1e0f817a1`, dispatch `head_sha`
   identical, and `gh run list --workflow green-04-evidence.yml` holding exactly one entry (no
   re-dispatch, no rerun, no cancellation).
2. Chose and justified the `main` window bounds, then ran the collector on the clean tree:
   `bash scripts/ci/capture-green-04-evidence.sh --output …/240-GREEN-04-EVIDENCE.json --run-id
   35377050754 --main-window-start 2026-09-16T03:29:55Z --main-window-end 2026-09-18T18:11:54Z`
   → `wrote … (sc1.leg_count=20 verdict=pass)`.
3. Asserted the receipt with fail-closed `jq -e` (never by eye), plus a negative control.
4. Rewrote `240-EVIDENCE.md`: five slots flipped to `captured (run …)` / `captured (runs …)`,
   each naming its run ids and corroborating each id at least twice in its own body; a header
   paragraph declaring the flip a **post-evidence documentation commit**; `AFTER-ISSUE-231-CLOSED`
   left `pending (… obligation …)` for plan 240-05.
5. Re-ran `p12` redirected at the ledger — green, 6/6.

## Receipt — the measured facts

`head_sha`: `abec92c4b33005e21b550a2f899fe1d1e0f817a1` · `clean_tree`: `true`

| Field | Value |
|---|---|
| `sc1.dispatch_run_id` | `35377050754` |
| `sc1.leg_count` | `20` |
| `sc1.verdict` | `pass` (every leg `success`) |
| `sc1.jobs_filter` | `latest` |
| `sc2.window` | `2026-09-16T03:29:55Z` .. `2026-09-18T18:11:54Z` |
| `sc2.run_count` | `8` |
| `sc2.ci_gate_conclusions` | `{"success": 8, "failure": 0, "skipped": 0}` |
| `sc2.flake_attributable_red_count` | `0` |
| `sc2.caveat` | non-empty, names `example_unit_smoke` (D-10) |

The two `main` runs carrying a run-level `failure` in the window (`35052017063`, `35365693716`)
were each read at the job level: their sole non-success job is `Admin eval render + probe`, the
lane `ci.yml:2089-2110` documents as deliberately outside `ci-gate.needs`, with
`Notify on red ci-gate` `skipped` — which per `ci.yml:1645-1655` positively proves `ci-gate` was
not red. That is D-09, now recorded from the live API rather than from memory.

## Verification

| Check | Command | Result |
|---|---|---|
| leg count | `jq -e '.sc1.leg_count >= 20'` | exit 0 |
| verdict | `jq -e '.sc1.verdict == "pass"'` | exit 0 |
| every leg green | `jq -e '[.sc1.legs[].conclusion] \| unique == ["success"]'` | exit 0 |
| clean tree | `jq -e '.clean_tree == true'` | exit 0 |
| head_sha == HEAD | `jq -e --arg h "$(git rev-parse HEAD)" '.head_sha == $h'` | exit 0 |
| jobs filter | `jq -e '.sc1.jobs_filter == "latest"'` | exit 0 |
| no flake reds | `jq -e '.sc2.flake_attributable_red_count == 0'` | exit 0 |
| caveat present | `jq -e '(.sc2.caveat \| length) > 0 and (.sc2.caveat \| test("example_unit_smoke"))'` | exit 0 |
| gate never red | `jq -e '.sc2.ci_gate_conclusions.failure == 0'` | exit 0 |
| **negative control** | `jq -e '.sc1.leg_count >= 999'` | exit 1 — `jq -e` really reds |
| p12 on this ledger | `GSD_PROHIB_SUBJECT=…/240-EVIDENCE.md node --test … p12-run-id-provenance.test.mjs` | **EXIT=0**, 6/6 pass |
| prohibitions glob | `node --test scripts/ci/prohibitions/*.test.mjs` | EXIT=0, 93/93 pass |
| anchor integrity | `node scripts/ci/evidence-anchor-check.mjs` | `PASS (132 bundles, 3808 findings)` |
| slot census | `grep -c '^Status: captured ('` / `'^Status: pending ('` | `5` / `1` |
| single dispatch | `gh run list --workflow green-04-evidence.yml --json databaseId` | length `1` |

Every command was run through `bash -c`, never zsh — zsh does not word-split unquoted parameter
expansions and has produced a confident false negative in this repo before. The negative control
above exists for the same reason: an assertion suite that has never been seen red proves nothing.

## Waived gate — local `mix ci` (exogenous, operator decision)

`MIX_ENV=test mix ci` fails locally with 6 `Sigra.Audit.Forwarders.ThreadlineTest` failures
(`Threadline.attach/1 is undefined`). **Waived as environmental by explicit operator decision,
recorded here as instructed, not investigated.** The evidence for the waiver:

- CI at the base commit and on PR #246 shows the exact corresponding jobs — `Library tests` and
  `Library tests (dep-off — Threadline absent)` — concluding `success`; PR run `35376244993` was
  `ci-gate: pass` with zero failures before the squash merge.
- The `main` push run at the merged HEAD, `35377012499`, likewise shows `Library tests` and
  `Library tests (dep-off — Threadline absent)` both `success`.
- No Elixir source, test, dependency or config file changed in this plan — the only two files this
  plan writes are a JSON receipt and a markdown ledger.

## Deviations from Plan

**None affecting the claim.** Two authoring choices worth naming, both strictly additive:

1. **`AFTER-PAGES-LOUD-RED` / `AFTER-P20-GUARD-OBSERVED` cite two run ids each** rather than the
   single `main` run the plan sketched — `35377012499` (the `main` push at the final HEAD, whose
   `fast_checks` job carries the steps `Pages legacy-branch script self-test` and
   `Phase 230 prohibition guards`) and `35376244993` (the PR run that gated the squash). Both ids
   are corroborated in-slot; p12 is green.
2. **The window deliberately includes an `in_progress` `main` run** (`35377012499`). Justified in
   the decisions block above: its `ci-gate` and `Generated admin Playwright smoke` jobs had both
   already concluded `success`, and only the non-gate `Admin eval render + probe` lane was still
   running. The ledger states this in the table rather than hiding it behind a trimmed window.

No auto-fixes were required (Rules 1–3 did not fire), no architectural decision arose (Rule 4 did
not fire), and no authentication gate was hit.

## Known Stubs

None. This plan writes a measured receipt and a ledger; no code, no placeholders, no TODOs.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or schema change was introduced.
`green-04-evidence.yml` runs with `permissions: contents: read` (T-240-02c, accepted at plan time)
and this plan added no package (T-240-SC).

## Requirement

**GREEN-04 — satisfied and marked complete.** n≥20 legs of the affected job, dispatched rather
than pushed, every leg `success`, captured at the final committed HEAD on a clean tree, with the
run ids on the record and the SC-2 verdict readable from the API job list rather than asserted in
prose. GREEN-05 is **not** this plan's — plan 240-05 marks it after issue #231 is closed.

## Self-Check: PASSED

- `.planning/phases/240-.../240-GREEN-04-EVIDENCE.json` — FOUND
- `.planning/phases/240-.../240-EVIDENCE.md` — FOUND
- `.planning/phases/240-.../240-04-SUMMARY.md` — FOUND
- commit `33d5d8db` (Task 3) — FOUND in `git log --oneline --all`
- `node scripts/ci/evidence-anchor-check.mjs` — PASS after the ledger rewrite
