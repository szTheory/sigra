---
phase: 16-org-liveviews-switcher
plan: 01
subsystem: auth
tags: [orgs, liveview, phoenix, ecto, plug, slug-alias, sudo, multi-tenancy]

requires:
  - phase: 13-organizations-schemas-context
    provides: Organizations context, last-owner guard, audit append_audit, soft_delete baseline
  - phase: 14-org-plugs-scope-hydration
    provides: PutActiveOrganization single-writer plug, LoadActiveOrganization, scope hydration, session store

provides:
  - rename_organization/4 with audit + name validation
  - update_slug/4 with typed-confirm + password re-verify + 7-day OrganizationSlugAlias row insert
  - soft_delete_organization/4 (BREAKING: was /3) with typed-confirm of org.name + password
  - list_members_with_activity/3 via LEFT LATERAL JOIN on user_sessions scoped to active org
  - count_members/2 aggregate
  - get_active_slug_alias/2 query
  - remove_member/3 now purges user_sessions rows where active_organization_id == org in the SAME Multi (SC-4 force-logout)
  - Sigra.Plug.LoadOrganizationFromSlug with 7-day alias redirect + session pointer refresh
  - Sigra.LiveView.OrganizationScope on_mount parallel (read-only, halt-tuple contract)
  - OrganizationSlugAlias generator schema template
  - organization_slug_aliases migration (Postgres partial-unique + MySQL/SQLite fallback)
  - Reserved-slug list extended with "orgs", "organizations", "switch"
  - :user_session and :organization_slug_alias keys added to the org config schema
  - :not_found added to Sigra.Plug.ErrorHandler error_type union

affects: [16-02, 16-03, 16-04, 16-05, 16-06, 17-invitations, 18-backfill]

tech-stack:
  added: []
  patterns:
    - "Virtual-changeset pattern for confirm-sensitive params: {%{}, types} |> cast |> validate_change to surface per-field form errors without coupling to host schema"
    - "Slug-alias 7-day grace window with partial unique index scoped to expires_at > now() (PG)"
    - "Halt-tuple on_mount contract: return {:halt, socket_with_flag} rather than calling Phoenix.LiveView.redirect/2 directly so the module stays unit-testable without phoenix_live_view as a test dep"

key-files:
  created:
    - lib/sigra/plug/load_organization_from_slug.ex
    - lib/sigra/live_view/organization_scope.ex
    - priv/templates/sigra.install/organizations/organization_slug_alias.ex
    - test/sigra/plug/load_organization_from_slug_test.exs
    - test/sigra/live_view/organization_scope_test.exs
  modified:
    - lib/sigra/organizations.ex
    - lib/sigra/organizations/slug.ex
    - lib/sigra/plug/error_handler.ex
    - priv/templates/sigra.install/organizations/migration.exs
    - test/sigra/organizations/context_test.exs

key-decisions:
  - "Dropped library-side Sigra.Crypto.confirm_sudo side effect (D-11) because the org config does not carry the session hashed_token; deferred to LV layer in Plan 02"
  - "Sigra.Crypto.verify_password/3 takes (password, hashed_password, opts); reads user.hashed_password from scope.user"
  - "Alias redirect is single-hop by construction: target is resolved via fetch_organization to the live org, never to another alias row (T-16-01-08)"
  - "on_mount returns :halt tuples with :sigra_redirect_to / :sigra_not_found socket flags instead of calling Phoenix.LiveView.redirect/2 directly so Sigra.LiveView.OrganizationScope is unit-testable without pulling phoenix_live_view into test deps"
  - "remove_member/3 purge_org_sessions Multi step is a no-op when config.schemas.user_session is nil (backward-compat with pre-Phase-16 org configs like the existing Mox test harness)"
  - "Reserved-slug list additively extended with orgs/organizations/switch; existing entries preserved"

patterns-established:
  - "Virtual-changeset pattern for typed-confirm + password params (avoids coupling to host Organization schema)"
  - "Plug error handler :not_found disposition for enumeration-prevention 404 halts"
  - "LATERAL subquery via parent_as(:membership) for per-row last-activity lookups without cross-tenant leaks"

requirements-completed: [ORG-UX-01, ORG-UX-04, ORG-UX-05, ORG-UX-06, ORG-UX-07, ORG-UX-08]

duration: ~60min
completed: 2026-04-13
---

# Phase 16 Plan 01: Organization Settings Library Foundations Summary

**Ships the library surface for Wave 2 LV work: 5 new Organizations context functions (rename/update_slug/soft_delete/list_members_with_activity/count_members), force-logout-on-remove, slug alias schema + redirect plug, and LV on_mount — all under sudo + typed-confirm gates.**

## Performance

- **Duration:** ~60 min
- **Started:** 2026-04-13 (worktree session)
- **Completed:** 2026-04-13
- **Tasks:** 3
- **Files created:** 5
- **Files modified:** 5

## Accomplishments

- Extended `Sigra.Organizations` with 5 new context functions, all sudo-gated and audit-appended
- `remove_member/3` now purges user_sessions rows scoped to the removed user + org inside the same `Ecto.Multi` (SC-4: force-logout proven inside transaction; last-owner rollback also reverts the purge)
- New `OrganizationSlugAlias` schema template + migration (Postgres partial-unique index scoped to `expires_at > now()`; MySQL/SQLite fallback)
- `Sigra.Plug.LoadOrganizationFromSlug`: URL-driven org loading plug with 7-day alias redirect + session pointer refresh via the single-writer PutActiveOrganization. 404 via `error_handler` on unknown slug AND on not-a-member (D-04 enumeration prevention)
- `Sigra.LiveView.OrganizationScope`: read-only on_mount parallel. Returns halt-tuples with flagged assigns so the module is unit-testable without pulling `phoenix_live_view` into Sigra's test deps
- Reserved-slug list extended with `orgs`, `organizations`, `switch`
- 22 new phase16 tests, all green; full library suite 1568 tests / 0 failures

## Task Commits

1. **Task 1: Reserved slugs + alias schema + migration + force-logout** — `f1556d7` (test), force-logout impl merged into the same commit via the config schema + purge_org_sessions Multi helper
2. **Task 2: rename/update_slug/soft_delete/list_members_with_activity/count_members + get_active_slug_alias** — `3c0a76b` (feat)
3. **Task 3: LoadOrganizationFromSlug plug + OrganizationScope on_mount + ErrorHandler :not_found** — `e67156a` (feat)

_Note: Task 1's RED and GREEN landed in a single commit because the RED tests for Task 2 functions were drafted alongside the Task 1 RED tests and the force-logout implementation is tiny (one private helper + a Multi step)._

## Files Created/Modified

- `lib/sigra/organizations.ex` — added rename_organization/4, update_slug/4, soft_delete_organization/4 (BREAKING from /3), list_members_with_activity/3, count_members/2, get_active_slug_alias/2, purge_org_sessions Multi helper, user_session + organization_slug_alias config schema keys
- `lib/sigra/organizations/slug.ex` — appended orgs/organizations/switch to `@default_reserved_slugs`
- `lib/sigra/plug/load_organization_from_slug.ex` — NEW. URL-driven org loader with alias redirect
- `lib/sigra/live_view/organization_scope.ex` — NEW. on_mount parallel
- `lib/sigra/plug/error_handler.ex` — added :not_found to the error_type union
- `priv/templates/sigra.install/organizations/organization_slug_alias.ex` — NEW template
- `priv/templates/sigra.install/organizations/migration.exs` — appended organization_slug_aliases table in both PG and MySQL/SQLite branches
- `test/sigra/organizations/context_test.exs` — 22 new phase16 tests + updated existing soft_delete/3 → soft_delete/4 test
- `test/sigra/plug/load_organization_from_slug_test.exs` — NEW. 9 plug tests (Mox + Plug.Test)
- `test/sigra/live_view/organization_scope_test.exs` — NEW. 6 on_mount tests (fake socket, Mox)

## Decisions Made

- **Library does NOT call confirm_sudo** inside `update_slug/4` or `soft_delete_organization/4`. The org config doesn't carry the auth-layer `Sigra.Config` or the current session hashed_token that `Sigra.Auth.confirm_sudo/3` requires. Moving that side-effect into the LV (Plan 02) keeps the org context pure and avoids a circular lib dependency. Documented for Plan 02 consumers.
- **Halt-tuple contract for on_mount** instead of direct `Phoenix.LiveView.redirect/2` calls. Sigra's LiveView support is optional and `phoenix_live_view` is not a test dep; the on_mount module returns `{:halt, socket_with_flag}` where the host LV bridge translates `:sigra_redirect_to` / `:sigra_not_found` flags to real redirects / 404 renders.
- **Virtual changeset via `{%{}, types}`** for typed-confirm params so `update_slug/4` and `soft_delete_organization/4` surface per-field changeset errors without coupling the library to the host-app `Organization` schema.
- **Alias redirect also rewrites `org=` query param** in addition to path substitution so the canonical URL does not leak the old slug (added after a test caught the omission).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan assumed `Sigra.Crypto.verify_password(user, password)` and `Sigra.Crypto.confirm_sudo/1`; real signatures differ**
- **Found during:** Task 2 implementation
- **Issue:** `Sigra.Crypto.verify_password/3` is `(password, hashed_password, opts)`, and `confirm_sudo/1` does not exist on `Sigra.Crypto`. `Sigra.Auth.confirm_sudo/3` exists but takes a `Sigra.Config.t()` + hashed session token — neither of which the org config carries.
- **Fix:** `verify_user_password/2` helper extracts `scope.user.hashed_password` and calls `Sigra.Crypto.verify_password/2`; `confirm_sudo` side-effect deferred to LV layer (Plan 02). Plan 02 LVs will call `Sigra.Auth.confirm_sudo/3` directly after a successful library call.
- **Files modified:** lib/sigra/organizations.ex
- **Verification:** update_slug + soft_delete tests cover wrong-password (`{:error, :invalid_password}`), confirm-mismatch (`{:error, changeset}`), and happy path
- **Committed in:** 3c0a76b

**2. [Rule 3 - Blocking] Plan referenced `Sigra.Plug.ErrorHandler.call(:not_found)` which does not exist**
- **Found during:** Task 3 implementation
- **Issue:** `Sigra.Plug.ErrorHandler` is a behaviour host apps implement (`auth_error(conn, error_type, opts)`), not a module with `call/1`.
- **Fix:** Used the existing pattern from `Sigra.Plug.RequireMembership` — `error_handler.auth_error(conn, :not_found, opts) |> Plug.Conn.halt()`. Added `:not_found` to the `error_type` union in `lib/sigra/plug/error_handler.ex`.
- **Files modified:** lib/sigra/plug/load_organization_from_slug.ex, lib/sigra/plug/error_handler.ex
- **Verification:** 9 plug tests cover unknown slug + not-a-member + expired alias + unauthenticated + missing param paths
- **Committed in:** e67156a

**3. [Rule 4 deferred to Rule 3] on_mount cannot raise `Phoenix.Router.NoRouteError` directly**
- **Found during:** Task 3 implementation
- **Issue:** `Phoenix.Router.NoRouteError` requires a populated `Plug.Conn`, which on_mount does not have. Also `phoenix_live_view` is not in Sigra's test deps, so direct LV calls break unit tests.
- **Fix:** on_mount returns `{:halt, socket}` with `:sigra_not_found` or `:sigra_redirect_to` flags in `socket.assigns`. The host LV bridge translates these flags to real 404 renders or redirects at the Phoenix layer.
- **Files modified:** lib/sigra/live_view/organization_scope.ex
- **Verification:** 6 on_mount tests cover unauthenticated, missing param, unknown slug, not-a-member, nil scope, happy path. All halt-tuples inspected directly.
- **Committed in:** e67156a

**4. [Rule 3 - Blocking] Redirect URL leaked old slug in query string**
- **Found during:** Task 3 redirect test
- **Issue:** `String.replace(conn.request_path, old_slug, new_slug)` only touches the path; `conn.query_string` still contained `org=old-slug`.
- **Fix:** Added a second `String.replace` over the query string to swap `org=old-slug` → `org=new-slug`.
- **Files modified:** lib/sigra/plug/load_organization_from_slug.ex
- **Verification:** redirect test asserts location does NOT contain the old slug
- **Committed in:** e67156a

**5. [Rule 2 - Missing critical] Added `:user_session` and `:organization_slug_alias` keys to the org config schema with nil defaults**
- **Found during:** Task 1
- **Issue:** Plan specified adding `:user_session` as a required schema key, but existing Mox tests use a config without it — making it required would break 20+ existing tests. Plan said "fail fast with clear message" but that conflicts with backward-compat.
- **Fix:** Added both keys as `{:or, [:atom, nil]}` with `default: nil`. The `purge_org_sessions` and `get_active_slug_alias` helpers no-op when the key is nil. The thin-wrapper generator template will be populated with real schemas in Plan 02.
- **Files modified:** lib/sigra/organizations.ex
- **Verification:** Existing 40 ContextTest tests still pass. Phase16 backward-compat test asserts that when user_session is missing, the Multi does NOT include :purge_org_sessions.
- **Committed in:** f1556d7

**6. [Rule 3 - Blocking] soft_delete_organization/3 breaking change required updating existing test**
- **Found during:** Task 2
- **Issue:** Pre-existing test at `test/sigra/organizations/context_test.exs:210` called the 3-arity version; the signature change breaks it.
- **Fix:** Updated the test to use the new 4-arity signature with a real argon2 hash.
- **Files modified:** test/sigra/organizations/context_test.exs
- **Committed in:** 3c0a76b

---

**Total deviations:** 6 auto-fixed (3 blocking + 2 missing critical + 1 query-string bug)
**Impact on plan:** All deviations addressed mismatches between plan assumptions and the actual API surface shipped in Phases 13 and 14. Core contracts preserved: URL-driven org loading with 404 enumeration prevention, 7-day alias redirect, force-logout-in-same-Multi, typed-confirm + password gates for destructive actions, cross-tenant-leak guard on `list_members_with_activity/3`.

## Issues Encountered

- None beyond the deviations above. Full library test suite (1568 tests) stayed green at every commit.

## Deferred Issues

- **Sudo refresh side-effect**: library-side `Sigra.Auth.confirm_sudo/3` call deferred to Plan 02 LV layer. Plan 02 must call it after every successful `update_slug/4` and `soft_delete_organization/4` invocation.
- **Slug alias cleanup sweeper**: T-16-01-06 accepted. Aliases expire by the `expires_at > now()` filter but dead rows accumulate until a cleanup job lands in Phase 18 or v1.2. Partial unique index on active rows only prevents conflicts in the meantime.
- **Generator thin-wrapper template update**: `priv/templates/sigra.install/organizations/organizations.ex` still lacks `user_session:` and `organization_slug_alias:` in its `schemas:` keyword list. Plan 02 updates the template as part of the thin-wrapper layer.
- **list_members_with_activity/3 real-DB test**: Mox-level test asserts query delegation and tenant isolation via raise-on-nil-active-org. A live Postgres test (`--only postgres`) to verify the actual `LEFT LATERAL JOIN` executes would be a Plan 02 or integration-sweep add.

## Next Phase Readiness

- All library surface Wave 2 LVs need is in place: rename/slug/delete/remove_member/list_members context functions, slug alias redirect plug, on_mount parallel.
- Plan 02 should consume: `rename_organization/4`, `update_slug/4`, `soft_delete_organization/4`, `list_members_with_activity/3`, `count_members/2`, `Sigra.Plug.LoadOrganizationFromSlug`, `Sigra.LiveView.OrganizationScope`. It must also call `Sigra.Auth.confirm_sudo/3` after each destructive action and update the thin-wrapper template's `schemas:` keyword list with `user_session:` and `organization_slug_alias:` entries.
- No blockers.

## Self-Check: PASSED

- `lib/sigra/plug/load_organization_from_slug.ex` — FOUND
- `lib/sigra/live_view/organization_scope.ex` — FOUND
- `priv/templates/sigra.install/organizations/organization_slug_alias.ex` — FOUND
- `test/sigra/plug/load_organization_from_slug_test.exs` — FOUND
- `test/sigra/live_view/organization_scope_test.exs` — FOUND
- Commit `f1556d7` (test/16-01) — FOUND
- Commit `3c0a76b` (feat/16-01 rename/update_slug) — FOUND
- Commit `e67156a` (feat/16-01 URL-driven plug + on_mount) — FOUND
- Phase 16 tests: 22 new + 15 plug/LV = 37 total, all green
- Full library suite: 1568 tests / 0 failures

---
*Phase: 16-org-liveviews-switcher*
*Completed: 2026-04-13*
