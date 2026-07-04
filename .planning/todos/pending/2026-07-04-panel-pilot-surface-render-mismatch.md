---
created: 2026-07-04T00:00:00.000Z
status: pending
title: LLM panel targets 216 pilot surfaces but 217 render matrix renders board-mg-* — live SC-2 blocked (gap-closure)
area: testing
resolves_phase: 217
files:
  - scripts/ci/admin-panel.sh
  - guides/reference/admin-render-sha.json
  - test/example/priv/playwright/tests/admin-eval.spec.ts
  - scripts/panel/judge.mjs
source: Phase 217-07 Task 3 live off-CI verification (SC-2) — orchestrator-discovered integration gap, deferred as gap-closure per operator decision 2026-07-04
---

## What

The live SC-2 verification (`admin-panel.sh` off-CI panel run against fresh bundles
at HEAD) cannot execute because the panel's target surfaces and the render matrix's
output are **disjoint**:

- `admin-panel.sh` hard-codes `PILOT_SURFACES=("users-index-live" "user-show-live")`,
  and `--all` reads surfaces from `admin-render-sha.json` — whose `cells` (with
  `render_sha256`) contain **only** `users-index-live` + `user-show-live`. These are
  inherited from **phase 216** (216-02 skeleton, 216-07 verify-then-climb); 217-02 only
  rewrote their `open_findings`.
- Phase 217's `admin-eval.spec.ts` render matrix renders **`board-mg-1..11`** boards
  (the design-gallery surfaces seeded by 217-06), NOT the pilot surfaces.

So at HEAD the pilot surfaces have `render_sha256` ledger entries but **no captured
bundle.json on disk**, while the rendered `board-mg-*` surfaces have no `render_sha256`
`cells`. A live `admin-panel.sh` run finds its pilot cells, looks for
`eval/<HEAD>/users-index-live/<cell>/`, finds nothing, and makes **0 API calls**
(`judge.mjs` errors on the missing bundle before any SDK call) — proving nothing.

## Why it matters

SC-2's mechanism (zero LLM calls on unchanged `render_sha256`) is **already hermetically
proven** by `scripts/panel/judge.test.mjs` (11/11, zero real API, content-hash-skip path
with an SDK double), so there is no correctness risk today. But the *live reality-check*
(a must_have in 217-07) can never pass until the panel and the render matrix agree on a
surface set. This is a scoping mismatch the hermetic tests + deterministic guards cannot
catch (they use synthetic fixtures / the board-mg findings pipeline).

SC-4's live "board-autofix-seed companion" IS runnable (board-mg bundles + 12
`auto_eligible` token findings exist; `admin-autofix-loop.sh` is deterministic/API-free),
but was deferred alongside SC-2 to avoid landing fix/revert commits on `main` outside a
gap-closure plan.

## Related: judge.mjs CLI path is stubbed (same gap-closure)

Phase-217 verification also flagged that `scripts/panel/judge.mjs` (~line 609) CLI entry
point passes `excerptDom: ''` and `factsJson: '{}'` to `runJudge` — a `// TODO: read from
bundle dir` stub. The exported `runJudge` function is fully implemented and tested
(`judge.test.mjs` 11/11), but the `admin-panel.sh` → `judge.mjs` CLI wiring to the bundle
filesystem is incomplete. So even after the surface sets are aligned, the CLI must be
wired to read `dom.html` + `facts.json` from the bundle dir before a live SC-2 run is
meaningful. Fold this into the same gap-closure pass.

## Suggested fix (pick one; a scoping decision)

1. **Render the pilot surfaces** — extend `admin-eval.spec.ts` to also capture
   `users-index-live` + `user-show-live` bundles at HEAD, so `admin-panel.sh`'s pilot
   default has real bundles. Smallest change to the panel; keeps 216's pilot choice.
2. **Repoint the panel at the board-mg surfaces** — add `render_sha256` `cells` for the
   `board-mg-*` surfaces to `admin-render-sha.json` and change `admin-panel.sh`
   `PILOT_SURFACES` to a board-mg subset. Aligns the panel with what 217 actually renders.

After the surfaces agree, run the two off-CI live verifications from
`guides/reference/admin-eval-runbook.md` with a real `ANTHROPIC_API_KEY` (SC-2: run twice,
2nd run must report 0 calls + empty `git diff admin-panel-verdicts.json`; SC-4: loop
produces a `Revert "autofix(...)"` commit + restored ledger + settled finding).

## Repro (infra already validated 2026-07-04)

```bash
scripts/db/up.sh   # or reuse an ephemeral PG; example dev DB = example_dev
(cd test/example && PGHOST=127.0.0.1 PGPORT=<port> PGUSER=postgres PGPASSWORD=postgres \
   PGDATABASE=example_dev MIX_ENV=dev PORT=4000 mix phx.server &)   # PORT=4000 matches compile-env
SIGRA_EXAMPLE_URL=http://localhost:4000 bash scripts/ci/admin-eval-harness.sh
bash scripts/ci/admin-panel.sh --dry-run    # observe: pilot cells listed, but no pilot bundles on disk
```
