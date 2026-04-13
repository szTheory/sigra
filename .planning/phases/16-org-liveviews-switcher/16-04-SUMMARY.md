---
phase: 16-org-liveviews-switcher
plan: 04
subsystem: auth
tags: [phoenix, liveview, organizations, settings, sudo, progressive-disclosure, destructive-actions]

requires:
  - phase: 16-org-liveviews-switcher
    plan: 01
    provides: "Sigra.Organizations.{rename_organization,update_slug,soft_delete_organization}/4; Sigra.Plug.LoadOrganizationFromSlug 7-day alias redirect; virtual-changeset error shapes"
  - phase: 16-org-liveviews-switcher
    plan: 02
    provides: "Features.Organizations manifest; thin-wrapper 2-arg delegates (rename/update_slug/soft_delete) on the generated Organizations module; :org_scoped router pipeline with RequireMembership"

provides:
  - "priv/templates/sigra.install/organizations/live/organization_settings_live.ex — three-section single-page OrganizationSettingsLive template with progressive disclosure + inline sudo + typed-confirm"
  - "7 phx event handler contract: rename / open_slug_form / close_slug_form / update_slug / open_delete_form / close_delete_form / soft_delete"
  - "Error-remap helper shape (remap_slug_errors/2 + remap_delete_errors/2) mapping library changeset messages to exact UI-SPEC copy"
  - "Features.Organizations.files/1 now ships the settings LV template at lib/<web>/live/organization_settings_live.ex"

affects: [16-05, 16-06]

tech-stack:
  added: []
  patterns:
    - "Inline error remap via a small table of (field, library_message) → UI copy, driven off `Ecto.Changeset.errors` with a `{%{}, types}` virtual changeset rebuild so forms preserve submitted values on error"
    - "Progressive disclosure via two boolean assigns (`:slug_form_open?` / `:delete_form_open?`) flipped by dedicated open_*/close_* phx-click handlers; reset to a blank form on open AND close to avoid stale errors"
    - "Template-content tests (inherited from Plan 02) instead of runtime example-app LV tests — Plan 06 smoke harness will exercise the instantiated generator output"

key-files:
  created:
    - priv/templates/sigra.install/organizations/live/organization_settings_live.ex
  modified:
    - lib/sigra/install/features/organizations.ex
    - test/sigra/install/features/organizations_test.exs

key-decisions:
  - "Tests target the raw template on disk, not a runtime LiveView — follows Plan 02's inherited test strategy because the example app does not yet instantiate Phase 16 templates (Plan 06 will)"
  - "Error remap uses a dedicated helper (remap_slug_errors/2, remap_delete_errors/2) that reads the library changeset's errors list and rebuilds a virtual {%{}, types} changeset with mapped messages; this keeps LV helpers pure and the generated user-owned code readable"
  - "Form-open handlers call `blank_slug_form()` / `blank_delete_form()` on BOTH open and close so cancel+reopen starts clean and the next error cycle does not leak prior errors"
  - "Slug success redirect points at `~p\"/organizations/#{org.slug}/settings\"` (new slug). The LoadOrganizationFromSlug plug from Plan 01 handles the 7-day alias → old slug continues to resolve to this same settings page until expiry."
  - "The sudo-refresh side effect (Sigra.Auth.confirm_sudo/3) noted in Plan 01's 'deferred to LV' list is NOT called here: the library's update_slug/4 and soft_delete_organization/4 already verify the password inline and return {:error, :invalid_password} on mismatch; the extra confirm_sudo side effect is deferred again because it requires the session hashed_token which the settings LV does not have an explicit handle to. Phase 17 or v1.2 can add an on_mount that threads the session token into socket assigns if sudo-refresh needs to be user-visible."
  - "No admin role check in this LV — the :org_scoped pipeline + RequireMembership role filter enforces owner-only at the plug layer. The LV trusts its inputs (SC-3: 403 at plug, not hidden in UI)."

requirements-completed:
  - ORG-UX-04
  - ORG-UX-05

duration: ~25min
completed: 2026-04-13
---

# Phase 16 Plan 04: OrganizationSettingsLive Summary

**Ships the generator template for the Phase 16 settings surface — a single-page LiveView with three stacked sections (General / Slug / Danger Zone), progressive disclosure for destructive actions, inline sudo via current_password, and exact UI-SPEC error / success copy.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-13 (Wave 2 parallel worktree)
- **Completed:** 2026-04-13
- **Tasks:** 1 (TDD: RED → GREEN)
- **Files created:** 1
- **Files modified:** 2

## Accomplishments

- Created `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` with:
  - Three sections matching v1.0 `settings_live.ex` conventions (D-10): `bg-base-200 p-6 rounded-lg` cards for General + Slug; `border-l-4 border-l-error` red-zone card for Danger Zone.
  - Progressive disclosure state (`@slug_form_open?`, `@delete_form_open?`) with `open_*` / `close_*` phx-click handlers.
  - Inline sudo (D-11): `current_password` field on both destructive forms; no `RequireSudo` redirect, no state loss on mismatch.
  - Typed-confirm: slug form requires typing the CURRENT slug; delete form requires typing the CURRENT org.name.
  - 7-day redirect warning banner inside the slug form with exact copy from UI-SPEC §Destructive Action Confirmations.
  - Success redirects: slug → `~p"/organizations/#{new_slug}/settings"` (alias redirect handled by Plan 01's LoadOrganizationFromSlug); delete → `~p"/organizations"`.
- Wired the template into `Features.Organizations.files/1` at `lib/<web>/live/organization_settings_live.ex`.
- Added 13 template-content assertions tagged `:phase16` covering module name, event handler names, progressive-disclosure state, wrapper call sites, exact UI-SPEC button + flash copy, 7-day warning copy, red-zone styling, `:invalid_password` remap, typed-confirm remap, reserved + collision slug error remap, redirect targets, and three-section layout.

## Task Commits

1. **Task 1 RED — failing template-content tests** — `5e9cfaa` (test)
2. **Task 1 GREEN — template + files/1 wiring + pipe-form test regex** — `9f684ed` (feat)

## Event Handler Contract (for Plan 05)

The settings LV exports these exact phx-event names. Plan 05's members LV should mirror the `open_*` / `close_*` pattern for its own progressive-disclosure surfaces (change-role modal, remove-member modal):

| Handler            | Trigger          | Payload shape                                              |
| ------------------ | ---------------- | ---------------------------------------------------------- |
| `rename`           | phx-submit       | `%{"organization" => %{"name" => String.t()}}`             |
| `open_slug_form`   | phx-click        | `%{}`                                                      |
| `close_slug_form`  | phx-click        | `%{}`                                                      |
| `update_slug`      | phx-submit       | `%{"slug_change" => %{"slug", "password", "confirm_slug"}}` |
| `open_delete_form` | phx-click        | `%{}`                                                      |
| `close_delete_form`| phx-click        | `%{}`                                                      |
| `soft_delete`      | phx-submit       | `%{"delete_org" => %{"password", "confirm_name"}}`         |

## Error Key → UI Copy Mapping

Both `remap_slug_errors/2` and `remap_delete_errors/2` rebuild a virtual `{%{}, types}` changeset from the submitted params and re-seed it with mapped error messages so the form surfaces the exact UI-SPEC strings inline without losing user input.

**Slug form (`remap_slug_errors/2`):**

| Field          | Library message                  | UI copy                                              |
| -------------- | -------------------------------- | ---------------------------------------------------- |
| `:password`    | (via `{:error, :invalid_password}`) | `That password is incorrect.`                        |
| `:slug`        | `is reserved`                    | `That slug is reserved. Try another.`                |
| `:slug`        | `has already been taken`         | `That slug is already in use. Try another.`          |
| `:slug`        | `has invalid format`             | `Slugs can only contain lowercase letters, numbers, and hyphens.` |
| `:confirm_slug`| `does not match current slug`    | `Type {current_slug} exactly to confirm.`            |

**Delete form (`remap_delete_errors/2`):**

| Field          | Library message                    | UI copy                                              |
| -------------- | ---------------------------------- | ---------------------------------------------------- |
| `:password`    | (via `{:error, :invalid_password}`) | `That password is incorrect.`                        |
| `:confirm_name`| `does not match organization name` | `Type {org_name} exactly to confirm.`                |

On `{:error, :invalid_password}` (either form), the handler rebuilds the form from the submitted params with only a single `[{:password, "That password is incorrect."}]` error — the form re-renders open, the password input is highlighted, and every other field (new slug, typed-confirm, etc.) retains its submitted value.

## Plug-Layer 403/404 Verification (SC-3)

**Cross-wave note:** The plan's Task 1 behavior list includes Tests 16 (non-owner 403) and 17 (non-member 404) asserting plug-layer rejection via raw `get conn` calls. Those tests target a runtime example-app route (`/organizations/:slug/settings`) which does not exist in the current example app — the Phase 16 generator templates are not yet instantiated there. **Plan 06 (smoke harness) owns empirical verification of these route-level assertions.**

What Plan 04 guarantees via template-content assertions instead:

- The router injection template declares the settings route inside the `scope "/organizations/:org"` block piped through `:org_scoped` (verified by Plan 02's `Phase 16 router_injection template defines POST /organizations/switch BEFORE scoped block` test).
- `:org_scoped` uses `Sigra.Plug.LoadOrganizationFromSlug` + `Sigra.Plug.RequireMembership` (verified by Plan 02).
- `RequireMembership` with `role: [:owner]` returns 403 via the host app's `AuthErrorHandler` (verified by Sigra library tests in `test/sigra/plug/require_membership_test.exs`).
- `LoadOrganizationFromSlug` returns 404 via `ErrorHandler.auth_error(:not_found, ...)` for unknown slugs AND for slugs the current user is not a member of (verified by Plan 01 library tests).

The SC-3 guarantee ("non-owner is 403'd at plug layer, not just hidden in UI") is therefore structurally satisfied: the LV has zero role-visibility logic in its mount or render paths — any non-owner who reaches the LV would be a plug-layer bug, not a UI-hidden-but-still-accessible leak. Plan 06 will close the loop empirically.

## Decisions Made

- **Tests target raw templates, not runtime LiveViews.** Plan 02 established this pattern because the example app does not yet instantiate Phase 16 templates, and creating an ad-hoc generator-instantiation test harness is out of scope for Wave 2. Plan 06 (smoke harness) will run the originally-scoped runtime LV tests (Phoenix.LiveViewTest `live/2` calls + raw `get conn` plug-layer assertions) against an instantiated example app.

- **Error-remap via virtual changeset rebuild.** The library's `update_slug/4` and `soft_delete_organization/4` return a virtual changeset `{%{}, types}` that is not connected to a schema. To preserve the user's submitted values while showing UI-SPEC error copy, the LV rebuilds a fresh virtual changeset from the submitted params and re-seeds it with remapped errors. This keeps both (a) field values visible and (b) errors showing on the correct inputs. An alternative — mutating the library's changeset in place — would couple the LV to library internals.

- **Sudo-refresh (confirm_sudo) is NOT called here.** Plan 01 noted the side effect as "deferred to LV layer" but the settings LV has no explicit handle to the session `hashed_token`. The library already verifies the password inline before mutating, so the security posture is preserved; the `confirm_sudo` side effect would only affect the 15-minute sudo window for OTHER actions. Deferring this to v1.2 (or Phase 17 invitation revoke, which also needs sudo-refresh) is safe and explicitly documented.

- **No admin role check in LV.** The settings route is behind `:org_scoped` with `RequireMembership role: [:owner]` at the plug layer — the LV trusts its inputs (SC-3). No duplicate role check in mount/render.

- **Progressive-disclosure state reset on both open AND close.** `open_slug_form` and `close_slug_form` (and their delete counterparts) both call `blank_slug_form()` / `blank_delete_form()` to avoid leaking stale errors or submitted values across cancel+reopen cycles.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Test strategy pivot: template-content assertions instead of runtime example-app LV tests**
- **Found during:** Task 1 (initial test drafting)
- **Issue:** The plan's `<action>` block specifies writing tests at `test/example/test/example_web/live/organization_settings_live_test.exs` using `Phoenix.LiveViewTest.live/2` and raw `Phoenix.ConnTest.get/2` calls against an instantiated example app route. The example app (`test/example/`) does not have Phase 16 templates instantiated — `mix sigra.install` has not been run against the example harness for Phase 16, and creating that harness is Plan 06's work. Plan 02 encountered the identical blocker and pivoted to template-content tests (see Plan 02 deviation 1).
- **Fix:** Added 13 template-content assertions to `test/sigra/install/features/organizations_test.exs` under the existing `describe "files/1"` block (tagged `:phase16`), matching the existing Plan 02 tests' style. Each assertion maps 1:1 to an acceptance criterion in Plan 16-04's `<acceptance_criteria>` block. Plan 06 will run the originally-scoped runtime LV + plug-layer tests against an instantiated generator output.
- **Files modified:** `test/sigra/install/features/organizations_test.exs`
- **Verification:** `mix test test/sigra/install/features/organizations_test.exs --only phase16` → 21 tests, 0 failures.
- **Committed in:** `5e9cfaa` (RED) + `9f684ed` (GREEN)

**2. [Rule 1 — Bug] Initial template had `assign(socket, :key, val)` inside a pipe chain (`socket |> assign(socket, :key, val)`)**
- **Found during:** GREEN run
- **Issue:** I wrote `socket |> assign(socket, :slug_form_open?, true)` in four places, which passes `socket` twice — compiled but semantically wrong (the outer `socket` becomes the implicit pipe arg, and the explicit `socket` as first positional arg is the one `assign` operates on; redundant at best).
- **Fix:** Changed all four to `socket |> assign(:key, val)`.
- **Files modified:** `priv/templates/sigra.install/organizations/live/organization_settings_live.ex`
- **Verification:** Template compiles clean; test regex accepts either `assign(socket, :key, val)` OR pipe form.
- **Committed in:** `9f684ed`

**3. [Rule 1 — Bug] RED test assertion was too strict about pipe style**
- **Found during:** First GREEN run (20/21 passing)
- **Issue:** RED test asserted literal `assign(socket, :slug_form_open?, true)` but the GREEN template used pipe form `|> assign(:slug_form_open?, true)`. Functionally identical but string-different.
- **Fix:** Relaxed the assertion to a regex `assign\([^)]*:slug_form_open\?,\s*true\)` that matches both forms.
- **Files modified:** `test/sigra/install/features/organizations_test.exs`
- **Verification:** 21/21 phase16 tests passing.
- **Committed in:** `9f684ed` (same commit — adjustment was part of going GREEN)

---

**Total deviations:** 3 auto-fixed (1 test strategy blocker + 2 code-style bugs).
**Impact on plan:** The test strategy pivot is inherited from Plan 02 and well-documented. The two code bugs were caught immediately by the same test suite that verified the template contents. No security posture changes; no architectural deviations; all `must_haves.truths` entries remain satisfied by the template as shipped.

## Issues Encountered

- None beyond the deviations above.

## Deferred Issues

- **Runtime LV tests** (plan Tests 1–17) — deferred to Plan 06 smoke harness. Specifically: renaming happy + validation, slug progressive disclosure happy + wrong-password + typed-confirm mismatch + reserved + collision, soft-delete happy + wrong-password + typed-confirm mismatch, non-owner 403 (plug), non-member 404 (plug), 7-day alias resolution via `LoadOrganizationFromSlug`.
- **Sudo-refresh side effect (`Sigra.Auth.confirm_sudo/3`)** — Plan 01 noted it as "deferred to LV layer"; Plan 04 keeps it deferred because the settings LV has no session-token handle. The library's inline password verification already gates destructive mutations; `confirm_sudo` would only affect the sudo window for subsequent actions. Revisit in Phase 17 or v1.2.
- **Unique-constraint surfacing on slug collision** — The library's `update_slug/4` uses `Ecto.Changeset.change(org, %{slug: new_slug})` without `unique_constraint` on the org changeset; Postgres unique-violation may bubble as a raw error rather than a changeset error. The LV's `remap_slug_errors/2` handles the `has already been taken` message if it arrives, but if the Multi returns `{:error, :constraint_violation}` tuples instead, Plan 06 will need to add a catch-all error branch. Flagged as a Plan 06 concern.

## Verification Evidence

```
$ mix test test/sigra/install/features/organizations_test.exs --only phase16
21 tests, 0 failures (15 excluded)

$ mix test test/sigra/install/
373 tests, 0 failures

$ mix test
1588 tests, 0 failures (1 excluded)

$ mix compile --warnings-as-errors
==> sigra
Compiling 97 files (.ex)
Generated sigra app

$ mix credo --strict lib/sigra/install/features/organizations.ex
9 mods/funs, found no issues.

$ ls priv/templates/sigra.install/organizations/live/organization_settings_live.ex
priv/templates/sigra.install/organizations/live/organization_settings_live.ex
```

## Next Plan Readiness

- **Plan 16-05** (OrganizationMembersLive) can mirror this LV's conventions: three phx-event naming (domain verb, no prefix); progressive disclosure via `:form_open?` booleans with dedicated `open_*` / `close_*` handlers; inline form rebuild on error; error-remap helper shape. Plan 05 will also reuse `remap_*_errors/2` concept for member role-change + remove errors.
- **Plan 16-06** (smoke harness) owns the runtime LV tests originally scoped to Plan 04 Task 1 behaviors 1–17, including the SC-3 plug-layer 403/404 empirical verification and the 7-day alias resolution round-trip. Plan 06 will instantiate the generator output into the example app and run `mix sigra.install` against it.

## Self-Check: PASSED

- File existence:
  - FOUND: priv/templates/sigra.install/organizations/live/organization_settings_live.ex
  - FOUND (modified): lib/sigra/install/features/organizations.ex
  - FOUND (modified): test/sigra/install/features/organizations_test.exs
- Commits:
  - FOUND: 5e9cfaa (test RED)
  - FOUND: 9f684ed (feat GREEN)
- Tests: `mix test test/sigra/install/features/organizations_test.exs --only phase16` → 21/21 passing
- Broader: `mix test test/sigra/install/` → 373/373 passing
- Library suite: `mix test` → 1588/1588 passing
- Compile: clean with `--warnings-as-errors`
- Credo: clean

---
*Phase: 16-org-liveviews-switcher*
*Plan: 04*
*Completed: 2026-04-13*
