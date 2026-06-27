---
phase: 199-foundation-tier-2-scorecard-stress-fixtures
reviewed: 2026-06-25T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - .github/workflows/ci.yml
  - guides/reference/admin-fractal-scorecard.md
  - guides/reference/admin-quality-ledger.md
  - scripts/ci/quality-ledger-monotonic.test.sh
  - test/example/lib/example/demo/seeds.ex
  - test/example/priv/playwright/tests/admin-design.spec.ts
  - test/example/test/example/demo/seeds_test.exs
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 199: Code Review Report

**Reviewed:** 2026-06-25
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 199 is a documentation + fixtures + CI-wiring foundation phase. Reviewed: the
Tier-2 scorecard/ledger docs, the new hermetic bash self-test for the quality-ledger
monotonic guard (plus its CI wiring), the demo-seed extensions (36-user bulk cohort,
≥25-event audit trail, multi-session/multi-org breadth), and the un-skipped Playwright
content-equivalence test.

The core machinery is sound: seeds idempotency is correctly all-or-nothing via
`Repo.transaction`, count-threshold guards are arithmetically consistent (43 demo-tied
audit events = threshold, 36 bulk = threshold), the bulk cohort is correctly excluded
from both persona-count queries via the `loadtest-%` prefix, and the self-test's
hermetic temp-repo design correctly exercises both the decrease-fails and no-change-passes
paths of the real guard.

No BLOCKER-class defects (no security holes, no data-loss, no crash-on-happy-path). The
findings below are robustness/determinism gaps and brittle test couplings that should be
hardened before the Tier-2 ratchet phases (200-204) build on this fixture substrate.

## Warnings

### WR-01: Pagination determinism depends on ≥26 admin events, but the guard test only asserts ≥25

**File:** `test/example/test/example/demo/seeds_test.exs:310-320`, `test/example/priv/playwright/tests/admin-design.spec.ts:383-392`

**Issue:** The Playwright content-equivalence test asserts `Previous page` / `Next page`
links are attached on the per-user audit page. Those links render only when
`multi_page?(@meta)` is true, which requires **more than** one page — i.e. **≥26** admin
events at `@default_limit` 25 (`lib/sigra/admin/live/audit_user_live.ex:246`). The seed
invariant test, however, only guards `admin_tied >= 25`
(`seeds_test.exs:319`). 25 events render as a single page (`multi_page?` false → the
`<nav>` is not rendered), so a future seed reduction to exactly 25 would keep the ExUnit
guard green while silently breaking the Playwright pagination assertion — the exact
data-dependence the phase set out to eliminate. The threshold-of-record protecting the
Playwright test should be the value that actually triggers pagination.

**Fix:** Raise the ExUnit guard to the pagination-triggering boundary so the unit test
fails first if a regression drops below it:
```elixir
# FIXT-01: >25 (not >=25) — pagination renders only when multi_page? is true,
# which needs strictly more than one page at @default_limit 25.
assert admin_tied > 25,
       "expected >25 self-tied admin audit events so the per-user audit feed paginates (FIXT-01); got #{admin_tied}"
```
(Current real count is 29, so this is non-breaking and locks in the true contract.)

### WR-02: Audit-feed ordering is by `inserted_at`, not the pinned `occurred_at` — "deterministic spread" comment is misleading and the determinism is incidental

**File:** `test/example/lib/example/demo/seeds.ex:776-820` (and the `data-tone` read at `admin-design.spec.ts:175-177`)

**Issue:** The seeds deliberately pin `occurred_at` off `@seed_reference_ts`
(seeds.ex:778-779) and the comment claims this makes the feed "spread … deterministically."
But the admin audit feed's default order is `inserted_at` desc, not `occurred_at`
(`lib/sigra/admin/audit/explorer.ex:14-15` — `@default_order_by "inserted_at"`). All 43
rows are inserted inside one `Repo.transaction` within microseconds, so the first-listed
row (whose `data-tone` `assertAuditResultEquivalence` compares between desktop and mobile)
is the **last-inserted** admin row, determined by insertion order in the code — not by the
pinned `occurred_at` at all. The test passes today only because insertion order is fixed
and the cursor has an `event.id` tiebreak; the pinned timestamps do nothing for feed
ordering. This is a latent trap: a reorder of `persona_audit_events/0` or `@audit_actions`
silently changes which tone the test compares, and a maintainer reading the
"deterministic `occurred_at` spread" comment would not expect that.

**Fix:** Either (a) correct the comment to state that feed ordering is by `inserted_at`
and that first-row tone is a function of insertion order, not `occurred_at`; or (b) make
the equivalence assertion order-independent (compare the set of tones present desktop vs
mobile rather than `.first()` tone) so it cannot break on an insertion-order change.

### WR-03: `upsert_user/1` is reused for the bulk cohort but its contract/spec assumes a persona map

**File:** `test/example/lib/example/demo/seeds.ex:133-138`, `179-205`

**Issue:** `seed_bulk_users/0` calls `upsert_user(%{email:, display_name:, password:})`
— a bare 3-key map — but `upsert_user/1` is documented and shaped as taking a *persona*
(its error branches reference `persona.email` and the surrounding module treats personas
as richer maps with `:confirmed`, `:locked`, etc.). It works today because only `.email`
is dereferenced on the error path, but this is an undocumented coupling: any future change
to `upsert_user/1` that reads another persona key (e.g. `persona.display_name` in a raise
message, or a `patch_user_state` call moved inside) would crash on the bulk path with a
`KeyError` that only surfaces on a re-run/`:email_taken` branch — i.e. not on first seed,
making it easy to miss in local testing.

**Fix:** Either extract a narrow `register_or_fetch(email, display_name, password)` helper
that both call sites share, or add a typespec/guard documenting that `upsert_user/1`
requires only `%{email, display_name, password}` and must never dereference other keys.

### WR-04: Self-test mutation is coupled to exact whitespace and would silently stop testing the decrease path if the fixture row is reformatted

**File:** `scripts/ci/quality-ledger-monotonic.test.sh:92`

**Issue:** Test A mutates the fixture via
`sed -i.bak 's/| 2    | axe gate passing/| 1    | axe gate passing/'`. The match depends on
the exact four-space padding after `2` and the literal `axe gate passing` evidence text in
the heredoc fixture (lines 79-80). If the heredoc is reformatted (e.g. column widths
change, or `gofmt`-style table alignment is applied), the `sed` silently matches nothing,
the working tree is left identical to the committed Tier-2 baseline, the guard correctly
exits 0 — and **Test A passes for the wrong reason** (it asserts non-zero exit on a
decrease, but no decrease was actually introduced, so the guard's pass would be reported
as a FAIL... actually the inverse: a no-op sed leaves tier=2, guard exits 0, and Test A's
`GUARD_EXIT_A -ne 0` assertion FAILs). Either way the self-test's signal is whitespace-
fragile and gives a confusing failure mode rather than a clear "fixture mutation didn't
apply."

**Fix:** Assert the mutation actually changed the file before running the guard:
```bash
sed -i.bak 's/| 2    | axe gate passing/| 1    | axe gate passing/' "$LEDGER_PATH"
rm -f "${LEDGER_PATH}.bak"
grep -q '| 1    | axe gate passing' "$LEDGER_PATH" \
  || { echo "FATAL: self-test fixture mutation did not apply (heredoc reformatted?)" >&2; exit 2; }
```

## Info

### IN-01: `seed_bulk_users/0` confirm-branch is effectively dead on the happy path

**File:** `test/example/lib/example/demo/seeds.ex:139-148`

**Issue:** The `then/2` block confirms each bulk user only `if user.confirmed_at` is nil.
`register_user/1` → `SigraAuth.register/3` returns an unconfirmed user, so on first insert
the `else` branch always runs (good). But on the `:email_taken` re-fetch branch the user is
already confirmed, so the `if user.confirmed_at` short-circuit handles it. The structure is
correct but the `if user.confirmed_at -> user` true-branch is only reachable on a
re-fetch that, by construction, only happens when `existing < @bulk_cohort_size` (a partial
prior cohort) — a narrow window. Consider a comment noting the true-branch exists only for
the partial-cohort recovery case, otherwise it reads as defensive cruft.

### IN-02: `@bulk_cohort_size` is duplicated across module and test with no shared source

**File:** `test/example/lib/example/demo/seeds.ex:47`, `test/example/test/example/demo/seeds_test.exs:43`

**Issue:** `@bulk_cohort_size 36` is defined independently in both the seed module and the
test module. If one is changed without the other, the idempotency/exclusion tests
(`seeds_test.exs:393-428`) will assert against a stale target and fail confusingly rather
than tracking the source of truth.

**Fix:** Expose the size from the seed module (e.g. `Seeds.bulk_cohort_size/0`) and have the
test reference it, mirroring how `Personas.all/0` is the single source for the persona count.

### IN-03: Magic number `86_400` repeated for day-offset arithmetic

**File:** `test/example/lib/example/demo/seeds.ex:500`, `779`, `802`

**Issue:** `-offset * 86_400` (seconds per day) appears three times. A module attribute
(`@seconds_per_day 86_400`) or `DateTime.add(ts, -offset, :day)` (Elixir supports `:day`
unit since 1.11 for `DateTime.add/3` via `:second` only — verify) would remove the magic
number. Low priority; deterministic and correct as-is.

### IN-04: Ledger doc still references "~35 cells" and milestone phases as if static

**File:** `guides/reference/admin-quality-ledger.md:97-112`

**Issue:** The "Terminal Ratification" prose now states Tier 2 is "objectively earnable"
and that "Ratcheting … begins in Phases 200-204," embedding a forward phase plan into a
machine-parseable reference doc. This is fine as documentation but will rot once 200-204
execute. Consider a dated note or a pointer to ROADMAP rather than hard-coding the future
phase range inline.

### IN-05: Self-test only covers 2→1; does not assert 1→2 (increase) stays green or that an unparseable column-4 is rejected

**File:** `scripts/ci/quality-ledger-monotonic.test.sh:88-136`

**Issue:** The self-test proves "decrease fails" and "no-change passes" — the two most
important cases. It does not exercise (a) a legitimate **increase** (1→2) exiting 0, which
is the very operation Phases 200-204 will perform and which the new "Asserting Tier 2" doc
encourages; nor (b) a decorator-in-column-4 (e.g. `2*`) which the ledger doc explicitly
warns "will cause false-pass CI" (`admin-quality-ledger.md:38-39`). Given the doc raises
the decorator hazard as a known false-pass vector, a self-test case asserting the guard's
behavior on a decorated column-4 would convert that prose warning into an enforced contract.

**Fix:** Add a Test C (1→2 increase exits 0) and optionally a Test D documenting/asserting
the guard's actual behavior when column-4 carries a decorator, so the documented false-pass
hazard is pinned by a test rather than only by prose.

---

_Reviewed: 2026-06-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
