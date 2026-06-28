---
created: 2026-06-25T00:00:00.000Z
status: pending
resolves_phase: 205
title: Phase 199 code-review INFO findings — fixture/self-test hardening
area: test
files:
  - test/example/lib/example/demo/seeds.ex
  - test/example/test/example/demo/seeds_test.exs
  - scripts/ci/quality-ledger-monotonic.test.sh
  - guides/reference/admin-quality-ledger.md
source: 199-REVIEW.md (gsd-code-review, standard depth) — INFO findings, deferred from execution
---

The 4 WARNING findings from `199-REVIEW.md` were fixed during Phase 199 execution
(commits 5be6445b, 5464a93e, 6e3efdd7). These 5 INFO findings were deferred as
non-blocking hardening for the Tier-2 fixture/guard substrate. Pick up before or
during Phases 200–204 (which build the Tier-2 ratchet on this substrate). Most
valuable: **IN-02** and **IN-05**.

- **IN-01** — `seed_bulk_users/0` confirm-branch (`seeds.ex:139-148`): the
  `if user.confirmed_at -> user` true-branch is only reachable on a partial-cohort
  re-fetch. Add a comment noting it exists for partial-cohort recovery, else it
  reads as defensive cruft.

- **IN-02** *(recommended)* — `@bulk_cohort_size 36` is duplicated independently in
  `seeds.ex:47` and `seeds_test.exs:43`. Expose `Seeds.bulk_cohort_size/0` and have
  the test reference it (mirror how `Personas.all/0` is the single source for the
  persona count), so the two cannot drift.

- **IN-03** — Magic number `86_400` (seconds/day) repeated at `seeds.ex:500,779,802`.
  Extract `@seconds_per_day 86_400` (or use `DateTime.add(ts, -offset, :day)`).
  Low priority; correct as-is.

- **IN-04** — `admin-quality-ledger.md:97-112` "Terminal Ratification" prose
  hard-codes the forward phase range "200-204" inline in a machine-parseable
  reference doc; it will rot once those phases execute. Replace with a dated note
  or a pointer to ROADMAP.

- **IN-05** *(recommended)* — `quality-ledger-monotonic.test.sh` only covers 2→1
  (decrease fails) and no-change-passes. Add **Test C** (1→2 increase exits 0 — the
  exact operation Phases 200–204 will perform) and optionally **Test D** asserting
  the guard's behavior on a decorated column-4 (e.g. `2*`), which the ledger doc
  warns is a false-pass vector — converting that prose warning into an enforced
  contract.
