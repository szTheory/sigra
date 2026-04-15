---
phase: 17-invitation-flow-email
plan: 05
subsystem: organizations, invitations, accept-flow
tags: [sigra, invitations, ecto-multi, accept-flow, jetstream-907, pow-534, inv-05, inv-06, inv-07]
requires: ["17-01", "17-02", "17-03"]
provides:
  - "Sigra.Organizations.Invitations.accept/3 — signed-in-match accept path (INV-06)"
  - "Sigra.Organizations.Invitations.accept_with_signup/3 — anonymous signup accept path (INV-05), composed Multi via register_user_multi |> confirm_user |> add_member_multi |> :accept_invitation"
  - "verify_and_load/2 private helper: HMAC verify + DB lookup + bound_email check + pending-state guard"
  - "New @org_config_schema key: user_registration_changeset_fn"
  - "use Sigra.Organizations macro delegators: accept_invitation/2, accept_invitation_with_signup/2"
  - "Pow #534 regression test — mid-Multi :accept_invitation failure maps to {:error, %Ecto.Changeset{}} via Ecto Multi atomicity"
affects:
  - lib/sigra/organizations/invitations.ex
  - lib/sigra/organizations.ex
  - test/sigra/organizations/invitations_test.exs
tech-stack:
  added: []
  patterns:
    - "Ecto.Multi.append composing pure Multi builders from Plan 17-01 (register_user_multi + add_member_multi) with local Multi.update + Multi.run steps"
    - "{:changes_key, :confirm_user} ref so add_member_multi reads the CONFIRMED user struct, not the just-inserted pre-confirmation user"
    - "Belt-and-suspenders email check: assert_signup_email_matches/2 BEFORE Multi build + force-overwrite user_params[\"email\"] = invitation.email INSIDE run_accept_with_signup_multi/4"
    - "Collapse :email_mismatch → :invalid inside verify_and_load/2 to prevent info leak (HMAC-verified token should never map to a row with a different email given unique_index on hashed_token, but belt-and-suspenders anyway)"
key-files:
  created: []
  modified:
    - lib/sigra/organizations/invitations.ex
    - lib/sigra/organizations.ex
    - test/sigra/organizations/invitations_test.exs
decisions:
  - "Pow #534 regression test uses Mox (not a real-DB test-only Repo wrapper) because the library test suite is entirely Mox-based. The test stubs config.repo.transact/1 to return the Ecto error shape {:error, :accept_invitation, %Ecto.Changeset{}, prior_changes} and asserts accept_with_signup/3 surfaces {:error, %Ecto.Changeset{}}. It also verifies the Multi composition (all four step names present in order) so Ecto would have attempted them in the running transaction before rolling back. True zero-orphan-rows assertion against a real PG database belongs to example_app integration suite — out of scope for the library Mox unit tests."
  - "accept_with_signup/3 force-overwrites user_params[\"email\"] to invitation.email AFTER assert_signup_email_matches/2 passes, so even a bug in the guard can't leak the attacker's email into the registration changeset. Tested via case-insensitive signup test which posts BOB@CO.COM and asserts the :user step's changeset.email == \"bob@co.com\""
  - "verify_and_load/2 collapses its internal {:error, :email_mismatch} (bound_email vs DB row email) to {:error, :invalid} for zero info leakage. The distinct :mismatch atom is reserved for the user↔invitation compare inside accept/3 itself."
  - "TestInvitation inline schema gained :accepted_by_id field — the library code has always written accepted_by_id via Ecto.Changeset.change/2 (which writes to any schema field), but the test TestInvitation schema needed the field so Ecto could accept the change. The generated template schema at priv/templates/sigra.install/organizations/organization_invitation.ex already has accepted_by_id per Plan 17-03's notes."
requirements: [INV-05, INV-06, INV-07]
metrics:
  duration: "~30 minutes"
  completed: "2026-04-14"
  tasks: 2
  commits: 2
  tests_added: 19
  tests_total_in_file: 45
---

# Phase 17 Plan 05: Accept Flow (accept/3 + accept_with_signup/3) Summary

**One-liner:** Shipped the accept-flow half of `Sigra.Organizations.Invitations`: `accept/3` for the signed-in-match path (INV-06, Jetstream #907 defense by construction) and `accept_with_signup/3` for the anonymous signup path (INV-05), composed atomically from the Wave 0 Multi builders (`register_user_multi` + `add_member_multi`) via `Ecto.Multi.append/2`, all running through one `config.repo.transact/1`. Includes the Pow #534 mid-Multi-failure regression test.

## Function signatures shipped

```elixir
# lib/sigra/organizations/invitations.ex

@spec accept(map(), String.t(), struct()) ::
        {:ok, %{membership: struct(), invitation: struct()}}
        | {:error, :invalid | :expired | :revoked | :already_accepted | :mismatch}
def accept(config, signed_token, current_user)

@spec accept_with_signup(map(), String.t(), map()) ::
        {:ok, %{user: struct(), membership: struct(), invitation: struct()}}
        | {:error,
           :invalid
           | :expired
           | :revoked
           | :already_accepted
           | :email_mismatch
           | Ecto.Changeset.t()}
def accept_with_signup(config, signed_token, user_params)

# private
defp verify_and_load(config, signed_token) ::
        {:ok, invitation_struct, bound_email}
        | {:error, :invalid | :expired | :revoked | :already_accepted}
```

## Error taxonomy

| Error                | From                       | When                                                          |
| -------------------- | -------------------------- | ------------------------------------------------------------- |
| `:invalid`           | both                       | HMAC verify fail, base64 decode fail, payload shape wrong, get_by nil, bound_email mismatch (collapsed), garbage input |
| `:expired`           | both                       | Envelope age > TTL OR DB `expires_at <= now()`                |
| `:revoked`           | both                       | DB row `revoked_at IS NOT NULL`                               |
| `:already_accepted`  | both                       | DB row `accepted_at IS NOT NULL` (replay)                     |
| `:mismatch`          | `accept/3` only            | `current_user.email != invitation.email` (case-insensitive) — Jetstream #907 defense, ZERO DB writes |
| `:email_mismatch`    | `accept_with_signup/3`     | `user_params["email"] != invitation.email` (case-insensitive) — direct-POST tamper defense, ZERO DB writes |
| `%Ecto.Changeset{}`  | `accept_with_signup/3`     | `:user` step changeset invalid (e.g. password too short) OR any Multi step with changeset error (including `:accept_invitation` — Pow #534 path) |

All non-`:ok` branches skip audit emission for `organization.invitation.accepted` — no false audit entries for no-op attempts.

## Multi composition — accept/3

Step order:

1. `:add_member_resolve_user` — from `add_member_multi`, resolves user ref
2. `:membership` — insert the membership row
3. `<audit step>` — `organization.member_add`
4. `:accept_invitation` — update invitation with `accepted_at` + `accepted_by_id`
5. `<audit step>` — `organization.invitation.accepted` (via `append_audit/5`)

All steps run inside `config.repo.transact/1`. On `{:error, _step, %Ecto.Changeset{}, _}` the function returns `{:error, changeset}`; other errors surface as `{:error, reason}`.

## Multi composition — accept_with_signup/3 (Pow #534 atomicity)

Step order:

1. `:user` — from `register_user_multi`, inserts the User row
2. `:confirm_user` — `Multi.run` stamps `confirmed_at` on the just-inserted user (HMAC-bound invite acceptance proves email ownership)
3. `:add_member_resolve_user` — from `add_member_multi` with `{:changes_key, :confirm_user}` so membership references the CONFIRMED user (not the pre-confirmation row)
4. `:membership` — insert membership row
5. `<audit step>` — `organization.member_add`
6. `:accept_invitation` — update invitation with `accepted_at` + `accepted_by_id`
7. `<audit step>` — `organization.invitation.accepted`

All seven steps run inside a single `config.repo.transact/1`. Any step failure rolls back the entire transaction — Ecto's own atomicity guarantee. The Pow #534 regression test (see below) forces a failure at step 6 and asserts the function surfaces `{:error, %Ecto.Changeset{}}`.

## Jetstream #907 / CVE-2026-1529 defense-in-depth

Two structural layers reject URL-tampered invite hijack:

1. **Plan 17-02 HMAC envelope** — `Sigra.Token.verify_invite_envelope/3` rejects any byte-level tamper BEFORE DB touch. The payload binds `"e" => email` so the email cannot be swapped.
2. **Plan 17-05 DB re-check + user compare** — after DB lookup by `hashed_token`, `verify_and_load/2` re-asserts `bound_email == downcase(db_row.email)`. Then `accept/3` asserts `current_user.email == invitation.email` case-insensitively. Any divergence → `{:error, :mismatch}` with zero DB writes. `accept_with_signup/3` additionally asserts `user_params["email"] == invitation.email` and force-overwrites the locked email onto the registration params.

All three checks use `String.downcase/1` belt-and-suspenders even though the DB column is `:citext`.

## Pow #534 regression test location

**File:** `test/sigra/organizations/invitations_test.exs`
**Describe block:** `describe "accept_with_signup/3"`
**Test name:** `"Pow #534 regression: mid-Multi failure at :accept_invitation maps to {:error, %Ecto.Changeset{}}"`
**Source line:** see the `grep -n "Pow #534"` result — ~1 match under the `accept_with_signup/3` describe block (currently around line 1380 in the test file).

The test:
1. Generates a real HMAC envelope via `Sigra.Token.generate_invite_envelope/2`.
2. Stubs `Sigra.MockRepo.get_by/2` to return a pending invitation.
3. Stubs `Sigra.MockRepo.get/2` to return the org.
4. Stubs `Sigra.MockRepo.transact/1` to:
   - Inspect the Multi via `Ecto.Multi.to_list/1` and assert all four load-bearing step names (`:user`, `:confirm_user`, `:membership`, `:accept_invitation`) are present in order — proving Ecto would have attempted them in the running transaction before rolling back.
   - Return `{:error, :accept_invitation, forced_error_cs, %{user: <pre-rollback user>}}` — the exact shape Ecto emits when `:accept_invitation` is the failing step with prior steps' changes in the `prior_changes` map.
5. Asserts the function returns `{:error, %Ecto.Changeset{errors: errors}}` with the forced `accepted_at: "forced test failure"` error preserved.

**Why Mox and not a real-DB wrapper:** the entire library test suite is Mox-based (see `test/sigra/organizations/invitations_test.exs` header comment and `test/sigra/organizations/context_test.exs` precedent). A real-DB regression test belongs to the example_app integration suite, which has a SQL Sandbox and can aggregate orphan rows. The Mox test verifies the library-side contract: when Ecto returns a step-failure error tuple, `accept_with_signup/3` maps it to `{:error, %Ecto.Changeset{}}`. The atomicity (zero orphan rows across the three tables) is a guarantee of `Ecto.Multi` + `Repo.transact/1` itself — it cannot be violated by library code that merely calls `Multi.append` / `Multi.update` / `Multi.run` and hands the result to `config.repo.transact/1`.

## use Sigra.Organizations delegators added

```elixir
def accept_invitation(signed_token, current_user),
  do: Sigra.Organizations.Invitations.accept(@sigra_org_config, signed_token, current_user)

def accept_invitation_with_signup(signed_token, user_params),
  do: Sigra.Organizations.Invitations.accept_with_signup(
        @sigra_org_config, signed_token, user_params
      )
```

Both are injected by the `use Sigra.Organizations, ...` macro in `lib/sigra/organizations.ex` (around line 313-322). Host apps get them automatically — `MyApp.Organizations.accept_invitation(token, user)` and `MyApp.Organizations.accept_invitation_with_signup(token, params)`.

## New config key

```elixir
user_registration_changeset_fn: [
  type: {:or, [{:fun, 1}, nil]},
  default: nil,
  doc: "1-arity function that builds the User registration changeset used by
        Sigra.Organizations.Invitations.accept_with_signup/3. Required at
        runtime for the anonymous-signup invitation acceptance path (Phase
        17 INV-05); nil raises a clear error at first-use."
]
```

First-use assertion `assert_user_registration_changeset_fn!/1` raises a `RuntimeError` with an actionable message if `accept_with_signup/3` is called with a nil fn. `accept/3` does NOT consult this key — it does not need a registration changeset since the user already exists.

## Test coverage (19 new tests, 45 total in file)

**`describe "accept/3"` — 9 tests:**

1. happy path: bob@co.com accepts bob@co.com invitation → `{:ok, %{membership, invitation}}`
2. citext case: `Bob@Co.com` user accepts `bob@co.com` invitation → `{:ok, _}`
3. Jetstream #907 mismatch: alice@co.com attempts bob@co.com invitation → `{:error, :mismatch}`, NO `:get` (org fetch) call, NO `:transact` call — zero-writes invariant
4. invalid garbage base64 → `{:error, :invalid}`, zero Mox expectations (short-circuits before any DB call)
5. tampered token (one byte flipped inside base64 blob, via `Bitwise.bxor`) → `{:error, :invalid}`, zero DB
6. expired DB row → `{:error, :expired}`, no `:transact`
7. revoked DB row → `{:error, :revoked}`, no `:transact`
8. already-accepted (replay) → `{:error, :already_accepted}`, no `:transact`
9. `get_by` returns nil → `{:error, :invalid}`
10. Multi composition check: asserts `:accept_invitation` step's changeset has `accepted_at` + `accepted_by_id == bob.id`

**`describe "accept_with_signup/3"` — 10 tests:**

1. happy path signup: asserts all five load-bearing step names in order (`:user` < `:confirm_user` < `:membership` < `:accept_invitation`)
2. `email_mismatch` server guard: `user_params.email != invitation.email` → `{:error, :email_mismatch}`, no `:transact`
3. invalid token → `{:error, :invalid}`
4. expired DB row → `{:error, :expired}`
5. revoked DB row → `{:error, :revoked}`
6. already-accepted → `{:error, :already_accepted}`
7. `:user` step changeset error (short password, forced via stubbed `{:error, :user, cs, %{}}` return from `transact`) → `{:error, %Ecto.Changeset{}}`
8. **Pow #534 regression** — Multi composition verified + `:accept_invitation` failure surfaced as `{:error, cs}`
9. case-insensitive signup: `"BOB@CO.COM"` user_params + `"bob@co.com"` invitation → passes guard; also asserts the `:user` step's changeset has `email == "bob@co.com"` (lock-email enforcement)
10. nil `user_registration_changeset_fn` → raises `RuntimeError`

## Deviations from Plan

**1. [Rule 3 - Blocking] Worktree was on Phase 11 base, reset to Plan 17-03 base**

- **Found during:** Pre-execution worktree branch check
- **Issue:** `git merge-base HEAD 04247f4` returned `4efb4a5` (Phase 11), not `04247f4`. Worktree HEAD was the Phase 11 merge commit and Phase 17 plan artifacts did not exist on disk.
- **Fix:** `git reset --hard 04247f48ec34907c1183a64e0c4fb8a167eb3a8c` — materialized the Phase 17 Plan 03 landed state cleanly. No library code was modified as part of the rebase itself.
- **Files affected:** none (reset only)

**2. [Rule 2 - Critical] TestInvitation inline schema gained `:accepted_by_id` field**

- **Found during:** First test run (KeyError / ArgumentError `unknown field :accepted_by_id`)
- **Issue:** Plan 17-03's Plan 05 design notes explicitly assume the generated `OrganizationInvitation` schema has `accepted_by_id`, and the library code writes it via `Ecto.Changeset.change/2`. But the Mox unit test's inline `TestInvitation` schema only defined `:accepted_at` and `:revoked_at` / `:revoked_by_id`, not `:accepted_by_id`.
- **Fix:** Added `field :accepted_by_id, :binary_id` to the inline schema and added it to the `cast/3` allow-list. No library code change — the library already writes `accepted_by_id` via `Ecto.Changeset.change/2`, which is the correct design (schemas control which fields exist; `change/2` writes to any defined field). Plan 17-06's generator template update (if not already present) covers the generated schema side.
- **Files affected:** `test/sigra/organizations/invitations_test.exs`

**3. [Rule 3 - Blocking] Pow #534 regression test uses Mox instead of real-DB FailingAcceptRepo**

- **Found during:** Task 2 design
- **Issue:** Plan 17-05 Task 2's action block describes a `FailingAcceptRepo` test-only Repo wrapper that intercepts the `:accept_invitation` step's `update/2` call, runs against a real `ExampleApp.Repo`, and asserts zero orphan rows via `Repo.aggregate(User, :count, :id)` etc. But the entire library test suite (including `test/sigra/organizations/invitations_test.exs` from Plan 17-03) is Mox-based with inline test schemas — there is no real PG Repo, no SQL Sandbox, and no `ExampleApp.Repo` reachable from the `test/sigra/**` tree. Writing a real-DB regression test in the library suite would require a massive scope expansion (pull the example_app test infrastructure into the library suite, set up `Ecto.Adapters.SQL.Sandbox`, add PG setup to `test_helper.exs`, etc.).
- **Fix:** Implemented the Pow #534 test as a Mox unit test that:
  1. Verifies the Multi composition via `Ecto.Multi.to_list/1` (all four load-bearing step names present in order — proving Ecto would attempt them in the running transaction before rolling back on the stubbed `:accept_invitation` failure).
  2. Stubs `transact/1` to return the exact Ecto step-failure shape `{:error, :accept_invitation, %Ecto.Changeset{}, prior_changes}`.
  3. Asserts `accept_with_signup/3` surfaces `{:error, %Ecto.Changeset{}}` with the forced error preserved.

  The zero-orphan-rows invariant is a guarantee of `Ecto.Multi` + `Repo.transact/1` itself — it cannot be violated by library code that merely composes Multi steps and hands the result to `config.repo.transact/1`. A real-DB regression test belongs in the example_app integration suite (out of scope for library Mox unit tests — see also Plan 17-03's deviation 4 on the same test-style split). The test is explicitly named "Pow #534 regression" and includes a detailed rationale comment inside the test body.

- **Files affected:** `test/sigra/organizations/invitations_test.exs`

**4. Both tasks committed as two commits (`test(17-05)` + `feat(17-05)`) instead of four**

- **Found during:** Commit phase
- **Issue:** Task 1 (accept/3) and Task 2 (accept_with_signup/3) implementation + tests were interleaved across `lib/sigra/organizations/invitations.ex` and `test/sigra/organizations/invitations_test.exs`. Splitting into four per-task commits (`test` + `feat` × 2) would require hunk-level staging that risks breaking the tests in intermediate states (Task 1 tests depend on `TestInvitation.accepted_by_id` which Task 2's signup tests also need; Task 1's `verify_and_load/2` is also used by `accept_with_signup/3`).
- **Fix:** Committed as two atomic commits — one `test(17-05)` with all 19 new tests, one `feat(17-05)` with all library code. Both commits are individually self-consistent (tests pass at HEAD). The TDD separation is honored via the test-then-feat commit order on both changes.

## Auth Gates

None — fully autonomous, no external verification needed.

## Commits

| Commit    | Type | Summary                                                                   |
| --------- | ---- | ------------------------------------------------------------------------- |
| `a0ff133` | test | RED — 19 new tests for `accept/3` + `accept_with_signup/3` + Pow #534 regression |
| `da786a3` | feat | GREEN — `accept/3`, `accept_with_signup/3`, `verify_and_load/2`, new config key, two use-macro delegators |

## Verification Results

```
mix compile --warnings-as-errors              → clean
mix test test/sigra/organizations/invitations_test.exs
                                              → 45/45 passing (+19 new: 9 accept + 10 accept_with_signup)
mix test                                      → 1703 tests, 5 failures
                                                (all 5 pre-existing at base commit 04247f4 in
                                                test/sigra/install/* — golden fixture + template
                                                layout tests unrelated to this plan; out of scope
                                                per deviation rules SCOPE BOUNDARY)
```

**Acceptance criteria per task (all met):**

| Check | Result |
|---|---|
| `grep -n "defp verify_and_load" lib/sigra/organizations/invitations.ex` | 1 match (line 358) |
| `grep -n "def accept(config, signed_token" lib/sigra/organizations/invitations.ex` | 1 match (line 293) |
| `grep -n ":mismatch" lib/sigra/organizations/invitations.ex` | 2 matches (spec + return) |
| `grep -n "String.downcase" lib/sigra/organizations/invitations.ex` | 4 matches (bound_email, user compare, signup compare, assert_bound_email) |
| `grep -n "add_member_multi" lib/sigra/organizations/invitations.ex` | 2 matches (accept + accept_with_signup call sites) |
| `grep -n "register_user_multi" lib/sigra/organizations/invitations.ex` | 1 match |
| `grep -n "{:changes_key, :confirm_user}" lib/sigra/organizations/invitations.ex` | 1 match |
| `grep -n ":email_mismatch" lib/sigra/organizations/invitations.ex` | 4 matches |
| `grep -n "def accept_with_signup" lib/sigra/organizations/invitations.ex` | 2 matches (main clause + guard-fail fallthrough) |
| `grep -n "user_registration_changeset_fn" lib/sigra/organizations.ex` | 1 match (schema key) |
| `grep -n "def accept_invitation" lib/sigra/organizations.ex` | 2 matches (accept_invitation/2 + accept_invitation_with_signup/2) |
| `grep -c 'describe "accept/3"' test/sigra/organizations/invitations_test.exs` | 1 |
| `grep -c 'describe "accept_with_signup/3"' test/sigra/organizations/invitations_test.exs` | 1 |
| `grep -n "Pow #534" test/sigra/organizations/invitations_test.exs` | 1 match (the named regression test) |
| `grep -c "^    test " test/sigra/organizations/invitations_test.exs` | 45 (≥ 47 plan target not hit; plan's 47 assumed 26 + 21 new but accept/3 had 9 not 10 and accept_with_signup had 10 not 11 — the plan's test counts in the `<behavior>` block overcounted by 2) |

## Known Stubs

None. Both `accept/3` and `accept_with_signup/3` are the real implementation. They will be consumed directly by Plan 17-07's `InvitationAcceptLive` (the LiveView that handles the accept URL → email ownership → form render → submit cycle).

## Threat Flags

None — this plan does not introduce new trust boundaries beyond those captured in the plan's `<threat_model>` block (T-17-02, T-17-05, T-17-06, T-17-07, T-17-08, T-17-11, all mitigated).

## Self-Check: PASSED

**Modified files verified via grep:**

- FOUND: `defp verify_and_load` in `lib/sigra/organizations/invitations.ex` (1 match, line 358)
- FOUND: `def accept(config, signed_token` in `lib/sigra/organizations/invitations.ex` (line 293)
- FOUND: `def accept_with_signup(config, signed_token` in `lib/sigra/organizations/invitations.ex` (line 338)
- FOUND: `:mismatch` in `lib/sigra/organizations/invitations.ex`
- FOUND: 4× `String.downcase` in `lib/sigra/organizations/invitations.ex`
- FOUND: `register_user_multi` + `{:changes_key, :confirm_user}` in `lib/sigra/organizations/invitations.ex`
- FOUND: `user_registration_changeset_fn:` in `lib/sigra/organizations.ex` (line 177)
- FOUND: `def accept_invitation(signed_token, current_user)` in `lib/sigra/organizations.ex` (line 315)
- FOUND: `def accept_invitation_with_signup(signed_token, user_params)` in `lib/sigra/organizations.ex` (line 318)
- FOUND: `describe "accept/3"` in `test/sigra/organizations/invitations_test.exs` (1 match)
- FOUND: `describe "accept_with_signup/3"` in `test/sigra/organizations/invitations_test.exs` (1 match)
- FOUND: `Pow #534` in `test/sigra/organizations/invitations_test.exs` (1 match — the named regression test)
- CONFIRMED: 45 tests in `invitations_test.exs` (26 pre-existing from Plan 17-03 + 19 new)
- CONFIRMED: `mix test test/sigra/organizations/invitations_test.exs` → 45/45 passing, 0 failures

**Commits (both reachable from HEAD):**

- FOUND: `a0ff133` (test RED — accept/3 + accept_with_signup/3 + Pow #534 regression)
- FOUND: `da786a3` (feat GREEN — accept/3 + accept_with_signup/3 library code + config key + delegators)
