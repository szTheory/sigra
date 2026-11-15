# Phase 259 code review disposition

Source: `259-REVIEW.md` (standard depth, 22 files, 0 critical / 8 warning / 5 info). Fix report: `259-REVIEW-FIX.md`.

| ID | Severity | Disposition | Reason |
|----|----------|-------------|--------|
| WR-01 | warning | fixed | additive multi-line matching, commit 77f4ae63b |
| WR-02 | warning | fixed | six scanner blind spots closed with planted tests, commit 3c829010c |
| WR-03 | warning | partial | wording fixed (be8faf8aa); scope expansion deferred to todo `2026-11-14-brand-harness-review-deferred-findings.md` |
| WR-04 | warning | deferred | owner/scope decision; tracked in the same todo |
| WR-05 | warning | deferred | owner decision (CI base diff / CODEOWNERS); tracked in the same todo |
| WR-06 | warning | fixed | per-unit claim judgment, commit 18cb6494c |
| WR-07 | warning | fixed | CI guard on all four fixture writers, commit 8a6744b69 |
| WR-08 | warning | fixed | non-empty capture asserted; mfa-challenge parity-count question deferred to the todo, commit 82e8821a1 |
| IN-01 | info | deferred | optional; tracked in the todo |
| IN-02 | info | deferred | optional; tracked in the todo |
| IN-03 | info | deferred | optional; tracked in the todo |
| IN-04 | info | deferred | optional; tracked in the todo |
| IN-05 | info | deferred | optional; tracked in the todo |

## Re-review after gap closure (plans 259-14..259-18)

Source: `259-REVIEW.md` (re-review, standard depth, 21 files, 0 critical / 6 warning / 2 info). It replaces the review above at the same path, so these rows are prefixed `R2-` to stay distinct from the `WR-`/`IN-` rows above.

| ID | Severity | Disposition | Reason |
|----|----------|-------------|--------|
| R2-WR-01 | warning | open | guide snippets still show the user-struct call; fix queued in this gate |
| R2-WR-02 | warning | open | README "show the same message" overstates what the harness proves; fix queued in this gate |
| R2-WR-03 | warning | open | non-vacuity rule accepts a row whose `compare` is only `body`; fix queued in this gate |
| R2-WR-04 | warning | open | scanner misses `<>`-joined literals; no scanned file uses that shape today; to be deferred to the deferred-findings todo |
| R2-WR-05 | warning | open | `sigra.gen.oauth` / `sigra.upgrade` templates outside copy scope; owner decision; to be deferred to the todo |
| R2-WR-06 | warning | open | unbounded-claim recogniser misses wordings; no current doc affected; to be deferred to the todo |
| R2-IN-01 | info | open | README says each flow guide states its scope but 3 of 8 do; fix queued in this gate |
| R2-IN-02 | info | open | three small scanner gaps; to be deferred to the todo |
