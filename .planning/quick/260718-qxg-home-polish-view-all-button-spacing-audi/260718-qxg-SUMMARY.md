---
quick_id: 260718-qxg
title: "Home polish: View-all spacing, Audit-events microcopy, Sigra/Org-admin seed picker buttons"
status: complete
commit: 3ce8e7b0
---

# Home polish (3 example-only files) — Summary

Three example-only refinements to the demo home page, all routing through the real
prefilled login. Scope confined to `test/example/` — no `priv/templates/`, no `test/fixtures/`.

## Tasks completed

1. **CSS spacing** (`test/example/priv/static/assets/css/app.css`)
   - Added `.vt-panel--operator > .vt-btn { margin-block: var(--sg-space-4); }` after
     the `.vt-panel--operator .vt-copy` rule.
   - Added `.vt-seed-list li .vt-btn { margin-top: var(--sg-space-2); }` after the
     `.vt-panel--operator .vt-operator-list li` rule.

2. **home.html.heex microcopy + seed picker buttons**
   - Relabeled `<dt>Audit rows</dt>` → `<dt>Audit events</dt>`; value `{@audit_row_count}`
     and the other two metrics untouched.
   - Replaced the "Sigra Admin" and "Org admin path" prose `<li>`s with picker-shaped
     items (operator-aside pattern): title + `.vt-copy` blurb + `demo=admin` / `demo=morgan`
     block sign-in buttons. Routes rendered as non-copyable `.vt-code`.
   - `/admin/organizations/acme-corp` preserved; raw `morgan@demo.tasklane.test` prose removed
     (Morgan now reachable via the "Sign in as Morgan" button). First two prose `<li>`s kept verbatim.

3. **Test update** (`page_controller_test.exs`)
   - Dropped the `morgan@demo.tasklane.test` assertion and updated the stale comment.
   - All other assertions kept. `demo=admin` was already asserted at line 15 (optional add satisfied).

## Verification

- `cd test/example && mix compile --warnings-as-errors` — clean.
- `git diff --stat` — exactly the 3 example files (21 insertions, 8 deletions).
- `cd test/example && mix test test/example_web/controllers/page_controller_test.exs --include example_app`
  — **3 tests, 0 failures** (DB was up via `tmp/db.env`). The `/dev/mailbox` compile warning is
  pre-existing in `settings_live.ex` (untouched).

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- Files modified exist and are staged/committed.
- Commit `3ce8e7b0` present on `main`.
