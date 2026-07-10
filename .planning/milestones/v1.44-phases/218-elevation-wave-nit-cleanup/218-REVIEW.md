---
phase: 218-elevation-wave-nit-cleanup
reviewed: 2026-07-09T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - scripts/ci/fix-queue-build.mjs
  - scripts/ci/fix-queue-build.test.mjs
  - scripts/uat/up.sh
  - test/example/priv/playwright/lib/eval/probes.ts
  - test/example/priv/playwright/tests/admin-eval.spec.ts
  - test/example/lib/example_web/live/mfa_settings_live.ex
  - test/example/lib/example_web/live/organization_members_live.ex
  - test/example/priv/static/assets/css/app.css
  - test/example/test/example_web/live/organization_members_live_test.exs
  - priv/templates/sigra.install/core/mfa_settings_live.ex
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 218: Code Review Report (gap-closure re-review)

**Reviewed:** 2026-07-09
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Re-review of the gap-closure fixes for the prior 218-REVIEW.md findings
(CR-01 fix-queue determinism, WR-01..07 demo-LiveView correctness, IN-01/02 nits).

**All 10 prior findings are resolved** (resolution table below). The CR-01 determinism
fix is verified sound and now has a dedicated regression test (Test 5) proving
order-independence via forward + reverse seeding.

Remaining findings are **new** and centre on **template↔example drift**: the two
`priv/templates/sigra.install/` files are meant to be logic-mirrors of their
`test/example/` twins, and two fixes that landed in the example were not mirrored back
into the template. The most significant is a security-sensitive drift in
`save_passkey_name` (library-level impersonation guard not engaged in the template).

No hardcoded secrets, injection, or auth-bypass issues found. Role/email inputs remain
funneled through `safe_role_atom`/`safe_invite_role` allowlists and scoped library calls.
`@user_organizations` in `organization_members_live.ex` is supplied by the router
`{ExampleWeb.UserAuth, :assign_user_organizations}` on_mount hook (router.ex:252,
live_session `:organization_scoped`) — verified, not a bug.

### Resolution of prior findings

| Prior | Status | Evidence |
|-------|--------|----------|
| CR-01 fix-queue determinism | ✅ Fixed | `readdirSync(...).sort()` at all 3 levels; rep = `sort((a,b)=>a.finding_id.localeCompare(b.finding_id))[0]`; Test 5 proves order-independence |
| WR-01 `do_confirm_enrollment` non-exhaustive case | ✅ Fixed | `{:error, _reason}` fallthrough present in both twins (example:979, template:920) |
| WR-02 `change_role`/`remove_member` MatchError | ✅ Fixed | nil-guard `handle_event(..., _params, socket)` clauses in both twins; tests T17/T18 |
| WR-03 `find_streamed_member` silent miss | ⚠️ Partially fixed | lookup-miss now flashes (test T19); underlying 1000-row cap unchanged — see IN-01 |
| WR-04 `--vt-color-ok` undefined token | ✅ Fixed | success icon now `color:var(--vt-color-primary)` (example:250) |
| WR-05 `up.sh` reaper single-label filter | ✅ Fixed | dual-label query + `sort -u` (up.sh:643-652) |
| WR-06 `adminEvalEmail` cross-worker collision | ✅ Fixed | `w${worker}${rand}` entropy added (admin-eval.spec.ts:185-187) |
| WR-07 dead `.vt-modal__backdrop` form | ✅ Fixed | example modals no longer emit the vestigial backdrop form |
| IN-01 probe #5 `min-height` fallback | ✅ Fixed | numeric guard `mh > 0 ? mh : parseFloat(cs.height)` (probes.ts:499-500) |
| IN-02 probe #2 doc/logic mismatch | ✅ Fixed | docstring now describes the fractional-offset `(0.05,0.95)` band |

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: MFA `save_passkey_name` drops the library-level impersonation guard in the template twin

**File:** `priv/templates/sigra.install/core/mfa_settings_live.ex:736` (vs `test/example/lib/example_web/live/mfa_settings_live.ex:768`)

**Issue:** The example twin calls the rename with an explicit scope and handles the
library's impersonation rejection:

```elixir
# example (test/example)
case Auth.rename_passkey(user, credential_id, nickname || "", scope: socket.assigns.current_scope) do
  {:ok, _passkey} -> ...
  {:error, :impersonation_forbidden} -> ...   # library-enforced
  {:error, _reason} -> ...
end
```

The template twin omits both the scope and the rejection clause:

```elixir
# template (priv/templates)
case Auth.rename_passkey(user, credential_id, nickname || "") do
  {:ok, _passkey} -> ...
  {:error, _reason} -> ...
end
```

`Auth.rename_passkey/4`'s guard is `forbid_sensitive_operation(opts, user, "passkey.rename")`
(`test/example/lib/example/accounts.ex:982`), which can only detect impersonation when
`scope:` is present in `opts`. Passing no opts means the generated host relies **solely** on
the LiveView-level `impersonating?(socket)` pre-check — the library defense-in-depth layer is
never engaged. This is also internally inconsistent within the template itself: `disable_mfa`
(template:781) and `regenerate_codes` (template:837) both pass
`scope: socket.assigns.current_scope`; only `save_passkey_name` does not.

**Fix:** Mirror the example — pass the scope and handle the rejection so generated hosts get
two-layer enforcement:

```elixir
case Auth.rename_passkey(user, credential_id, nickname || "", scope: socket.assigns.current_scope) do
  {:ok, _passkey} ->
    ...
  {:error, :impersonation_forbidden} ->
    {:noreply, put_flash(socket, :error, "You can't change account security settings while impersonating.")}
  {:error, _reason} ->
    {:noreply, put_flash(socket, :error, "Could not save passkey name. Please try again.")}
end
```

### WR-02: Delete-passkey confirmation copy drifted — template repeats the heading in the body

**File:** `priv/templates/sigra.install/core/mfa_settings_live.ex:361-364` (vs `test/example/lib/example_web/live/mfa_settings_live.ex:383-386`)

**Issue:** The example twin's delete-confirmation body was fixed to read:

```
Title: Delete this passkey?
Body:  You'll still need another sign-in method before removing your last recovery option.
```

The template twin still carries the un-fixed copy, repeating the question inside the body:

```
Title: Delete this passkey?
Body:  Delete this passkey? You'll still need another sign-in method before removing your last recovery option.
```

This is exactly the kind of demo-LiveView copy fix that landed in the example but was not
mirrored to the template, so a freshly generated host ships the redundant wording.

**Fix:** Update the template body (template:363) to drop the leading `Delete this passkey? `
so it matches the example twin.

## Info

### IN-01: WR-03 fix is a flash, not a lookup fix — members beyond row 1000 remain unreachable

**File:** `test/example/lib/example_web/live/organization_members_live.ex:639-650` and template twin `:635-646`

**Issue:** The prior WR-03 concern (rows past the 1000-row cap in `find_streamed_member`
cannot be resolved for role-change/remove) is only partially closed. The gap fix added a
lookup-miss flash ("That member could not be found. Refresh and try again.") in
`open_role_modal`/`open_remove_modal` (test T19 covers it), which removes the *silent* no-op.
But `find_streamed_member` still refetches `list_members_with_activity(scope, limit: 1_000, offset: 0)`
and scans, so an org with >1000 members that has streamed rows beyond index 1000 will now show a
misleading "could not be found" flash for a member that plainly exists in the table. Acceptable
for a demo, but the "at minimum flash" bar is met while the root cause remains.

**Fix (optional / demo-acceptable):** Resolve the single row by id directly, e.g. a scoped
`Organizations.get_member(scope, id)` filtering on `organization_id` + membership id, instead of
scanning a capped list.

### IN-02: `up.sh --help` truncates the last usage line (`--print-env` undocumented)

**File:** `scripts/uat/up.sh:745`

**Issue:** `--help` runs `sed -n '2,25p' "${BASH_SOURCE[0]}"`, but the usage comment block runs
through line 26 (`--print-env`). The `--print-env` flag is fully supported (parsed at
up.sh:740-743) yet is never shown in `--help`, so it is not discoverable there.

**Fix:** Widen the range to cover the full block, e.g. `sed -n '2,26p'`.

### IN-03: `systemicGroup` doc comment overstates alignment with the `finding_id` key space

**File:** `scripts/ci/fix-queue-build.mjs:61-71`

**Issue:** The docstring says the canonicalized systemic group is "matching the finding_id key
space," but `finding_id` (builder line 188 and `admin-eval.spec.ts:enrichFindingsForBundle`)
hashes the **raw** anchor, while `systemic_group` hashes `canonicalizeAnchor(anchor)`. The
behavior is correct and intentional (quote/whitespace anchor variants collapse into one
cross-surface systemic group while keeping distinct finding_ids), but the "matching" wording
could mislead a future maintainer into "fixing" a non-bug.

**Fix:** Reword to state the canonicalization is deliberately *broader* than the finding_id key
(so quote-variants of the same anchor collapse across surfaces), rather than "matching" it.

---

_Reviewed: 2026-07-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
