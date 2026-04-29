# Phase 92 Deferred Items

Out-of-scope discoveries logged during plan execution. Each entry must
include the discovering plan, the file/area affected, the failure shape,
and a recommended landing point.

## DEF-92-02-01 — InvitationAcceptLive audit-Multi-step name collision

**Discovered during:** Plan 92-02 execution (running `mix test --include
example_app` in `test/example/` to verify Rule 3 follow-through after
Plan 92-01's explicit-only contract).

**Affected:** `lib/sigra/organizations/invitations.ex` `run_accept_multi/4`
(line ~599) AND `lib/sigra/organizations.ex` `add_member_multi/5` (line
~903). Both append an `:audit` step to the Multi via `append_audit/4`,
which collides with `RuntimeError: :audit is already a member of the
Ecto.Multi` when `run_accept_multi` calls `Multi.append/1` on the
add-member Multi and then immediately appends its own audit step.

**Failure shape:**
```
** (RuntimeError) :audit is already a member of the Ecto.Multi:
%Ecto.Multi{operations: [accept_invitation: ..., audit: ..., membership: ...,
add_member_resolve_user: ...], names: MapSet.new([:membership, :audit, ...])}
```

**Test failures observed:** 4 in `ExampleWeb.InvitationAcceptLiveTest`:
- T9: happy path redirects to org members with success flash
- T14: happy path creates user + membership + accepts invitation
- T17: accepting twice returns already_accepted and does not re-stamp
- T18: signed-in User@Ex.com accepts invitation for user@ex.com successfully

**Why deferred:**
- `git blame` on `lib/sigra/organizations/invitations.ex:600-606` puts
  the collision on commit `5e6c026` (2026-04-15 — two weeks before
  Phase 92 started). This is a pre-existing bug, NOT a Phase 92
  regression.
- Fixing it requires renaming one of the `:audit` Multi step names
  (e.g. `:audit_invitation_accepted` vs `:audit_member_added`) plus
  updating `normalize_multi_result_for_mfa_policy/1` and any callers
  that pattern-match on the step name. That's an architectural change
  (Rule 4) crossing two seams, and is out of scope for the Phase 92
  RBAC seam work.

**Recommended landing point:** A small targeted fix plan in the next
phase (Phase 93 wave or earlier) that renames the conflicting Multi
step names, updates the affected match clauses, and re-greens the 4
`InvitationAcceptLiveTest` failures. The fix should:

1. Rename `add_member_multi`'s `:audit` step to `:audit_member_added`
   (or similar discriminated name).
2. Update `normalize_multi_result/1` and `normalize_multi_result_for_
   mfa_policy/1` to match the renamed step.
3. Re-run `mix test --include example_app` from `test/example/` and
   confirm 333/333 tests pass.

The 4 failures do NOT block the Phase 92 RBAC seam contract — the
example app compiles cleanly with `--warnings-as-errors` after Plan
92-02's example-app re-green commit.
