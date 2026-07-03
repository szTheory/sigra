---
id: oban-enqueue-unguarded-when-compiled-but-unsupervised
created: 2026-06-24
source: 260623-j59 (session-invalidation fix — surfaced while making the example's deletion path run end-to-end)
severity: bug
area: lib/sigra (account-deletion Oban enqueue) + Sigra.OptionalDeps
resolves_phase: 214
---

# Account-deletion Oban enqueue fires whenever Oban is COMPILED, even if the host doesn't run it

## Problem
The account-deletion flow enqueues an Oban job (`maybe_enqueue_deletion_job`)
gated on `Sigra.OptionalDeps.oban_available?/0`, which is just
`Code.ensure_loaded?(Oban)` — i.e. **true whenever Oban is compiled**, including
when it is only a transitive dep. But "Oban is compiled" does NOT imply the host
app:
- supervises an Oban instance, or
- has run the `oban_jobs` migration.

When Oban is compiled-but-unsupervised / table-missing, the enqueue `INSERT`
raises `42P01 undefined_table`, which **poisons the surrounding audit
transaction** and fails the whole deletion. This bit the example in 260623-j59
(worked around there by adding an `oban_jobs` migration to the example app — a
real-host-app setup, fine for the demo, but it papers over the library gap).

## Why it shipped undetected
Same root cause family as the 260622-nft / 260623-j59 bugs: the public
`Sigra.Auth` deletion path was only ever exercised by mock-based unit tests, so
the real Oban-insert path was never run in a host without a supervised Oban +
migrated table.

## Likely correct fix (investigate before committing to one)
The library already has a dispatch notion — `test/example/config/config.exs:77`
references `dispatch: :auto` resolving to `:sync` when Oban is not supervised.
Options:
- **Detect supervision, not just compilation.** Replace/augment the
  `oban_available?` gate so the enqueue only happens when an Oban instance is
  actually running (e.g. `Oban.whereis/1` / configured name resolves), else fall
  back to inline/sync dispatch — matching the documented `dispatch: :auto → :sync`
  behavior and the "emails send inline if no Oban" posture in CLAUDE.md.
- **Isolate the enqueue from the audit transaction** so a failed/again-unavailable
  enqueue can't poison the deletion commit (enqueue after commit, or in a way
  whose failure is logged, not fatal).
- Confirm the same exposure doesn't exist for the other optional-Oban paths
  (async email delivery, token-cleanup jobs) — fix consistently if so.

## Coverage
Add a library/integration test for a host where Oban is compiled but NOT
supervised and the `oban_jobs` table is absent: deletion must still succeed
(sessions revoked, user soft-deleted) without raising — proving the enqueue is
guarded/inline. The example currently has the table, so this needs a dedicated
setup (separate repo/sandbox without the oban migration, or stub the
supervision check).

## Note
Out of scope for 260623-j59 (which was session invalidation). Filed so the
deeper optional-Oban robustness gap isn't lost behind the example's migration
workaround. Related: [[session-invalidation-missing-store-opts]] (completed).
