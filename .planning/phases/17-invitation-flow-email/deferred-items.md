# Phase 17 Deferred Items

## From Plan 17-06 execution (2026-04-14)

### Pre-existing install-test debt from Plan 17-04 fragment file

Plan 17-04 added `priv/templates/sigra.install/core/organization_invitation_email.ex`
as a standalone fragment file (documentation snippet, not an assembled module).
This drift broke four install-layout tests that do not know about the fragment:

- `test/sigra/install/isolation_test.exs` — forbidden-reference guard on
  the `emails.ex` template flags the `OrganizationInvitation` string that
  appears in the in-source comment linking to the fragment. Assertion
  target: 47 templates.
- `test/sigra/install/templates_layout_test.exs` — hard-coded expected
  count of 47 core templates; fragment bumps it to 48.
- `test/sigra/install/features/core_test.exs` — the
  `Sigra.Install.Features.Core.files/1` + `migrations/1` coverage map
  does not list `organization_invitation_email.ex`, so the "all on-disk
  files are referenced" invariant fails.

These failures were present BEFORE Plan 17-06 started (verified via
`git stash && mix test test/sigra/install/`). Fix belongs in Plan 17-07
(accept LV) or a dedicated "register Plan 17-04 fragment file with the
install coverage map" fixup plan.

### Pre-existing golden-diff test debt

`test/sigra/install/golden_diff_test.exs` fails on the generated
`emails.ex` tree because the golden fixture was not regenerated after
Plan 17-04's `organization_invitation/4` email builder landed. Same
root cause as above — out of scope for Plan 17-06.
