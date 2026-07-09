---
created: 2026-07-09
source: 218-REVIEW.md (gap-closure re-review)
resolves_phase:
severity: warning
tags: [installer-template-drift, admin-demo, harness-doc]
---

# Phase 218 re-review follow-ups (5 findings — pre-existing drift/nits, NOT in 218 gap scope)

The Phase 218 gap-closure re-review confirmed all 10 prior findings (CR-01, WR-01..07,
IN-01/02) are correctly resolved. It surfaced 5 **new** findings — all pre-existing
template↔example drift or nits, none blocking, none security-critical. Captured here so
they are not lost. Recommended handling: `/gsd-code-review 218 --fix` (the fixer agent
handles the template edit + golden re-bless cleanly) OR fold into Phase 219.

## Warnings

- **WR-01 — installer template drops `scope:` on `save_passkey_name`.**
  `priv/templates/sigra.install/core/mfa_settings_live.ex:~736` calls `Auth.rename_passkey/4`
  WITHOUT `scope:` and omits the `{:error, :impersonation_forbidden}` clause that the example
  twin (`test/example/lib/example_web/live/mfa_settings_live.ex`) has. `rename_passkey`'s
  impersonation guard (`forbid_sensitive_operation(opts, ...)`) only fires when `scope:` is in
  `opts`, so **generated hosts lose the library-level defense-in-depth** and rely solely on the
  LV `impersonating?` pre-check. Internally inconsistent — `disable_mfa`/`regenerate_codes` in
  the same template DO pass scope. Fix: mirror the example (add `scope:` + the error clause),
  then re-bless the golden fixture. See [[reference_installer_template_drift]].

- **WR-02 — delete-passkey confirmation copy drift (template only).**
  The template's delete-passkey confirmation body redundantly repeats "Delete this passkey?"
  (heading + body); the example was already fixed. Cosmetic; mirror the example + re-bless golden.

## Info

- **IN-01 — WR-03 fix is a flash, not a real lookup fix.** `open_role_modal`/`open_remove_modal`
  now flash on lookup miss, but orgs with >1000 members still can't reach members beyond the
  loaded page (root cause is the bounded member list, not the modal). Acceptable for the demo;
  note for any real pagination pass.
- **IN-02 — `up.sh --help` truncates `--print-env` usage.** The `sed -n '2,25p'` window in the
  help printer cuts the `--print-env` usage line. Widen the window.
- **IN-03 — `systemicGroup` doc comment overstates finding_id-keyspace alignment** in
  `scripts/ci/fix-queue-build.mjs`. Reword the comment to match the actual grouping semantics.
