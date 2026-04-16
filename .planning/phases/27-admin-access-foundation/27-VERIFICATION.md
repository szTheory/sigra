---
phase: 27-admin-access-foundation
verified: 2026-04-16T19:36:07Z
status: human_needed
score: 8/8 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 6/8
  gaps_closed:
    - "Admin access is determined only by the explicit host policy contract and enforced server-side for generated admin pages, exports, and mutations."
    - "Admin navigation and page chrome keep the active global or organization scope visible for the generated admin surface."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Render a freshly installed host app's `/admin` and `/admin/organizations/:org` pages"
    expected: "The admin layout wraps both routes, the scope chip is visible at the top, and the page does not look visually broken on desktop or mobile."
    why_human: "The generated wiring and tests prove the layout path exists, but visual quality and responsive presentation of the chrome still require a human pass."
  - test: "Trigger forbidden and not-found admin paths in a generated host app"
    expected: "The 403 and 404 responses show the explicit admin error copy instead of a blank or confusing page."
    why_human: "Automated tests cover the response bodies, but a human should confirm the rendered experience is clear in-browser."
---

# Phase 27: Admin Access Foundation Verification Report

**Phase Goal:** Developers can install and trust an admin surface that is default-on, explicitly policy-driven, and scope-safe for both platform admins and org admins.
**Verified:** 2026-04-16T19:36:07Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Developer can generate the admin surface by default and omit it with `--no-admin` without introducing a second frontend stack or third-party admin framework. | ✓ VERIFIED | [`mix.exs`](/Users/jon/projects/sigra/mix.exs#L13) keeps `:phoenix_live_view` as a normal dependency; [`lib/mix/tasks/sigra.install.ex`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L38) registers `Sigra.Install.Features.Admin`, `admin: :boolean`, and `admin?: Keyword.get(opts, :admin, true)`; [`admin_test.exs`](/Users/jon/projects/sigra/test/sigra/install/features/admin_test.exs#L75) covers the default-on and opt-out surface. |
| 2 | Host app can declare platform-admin and org-admin policy decisions explicitly, and Sigra enforces those decisions server-side for admin pages, exports, and mutations. | ✓ VERIFIED | [`policy.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/policy.ex#L1) exposes only the explicit callbacks; [`router_injection.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/router_injection.ex#L1) now wires `Sigra.Plug.RequireAdminAccess`, `Sigra.LiveView.AdminScope`, and the generated policy module into both admin route families; [`require_admin_access.ex`](/Users/jon/projects/sigra/lib/sigra/plug/require_admin_access.ex#L1) and [`authorizer.ex`](/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex#L1) enforce the resolved scope outside the router too. |
| 3 | Org admins only see data and actions inside their allowed organization scope, while platform admins can enter cross-org views intentionally. | ✓ VERIFIED | [`scope.ex`](/Users/jon/projects/sigra/lib/sigra/admin/scope.ex#L31) fails closed on unknown or out-of-scope orgs; [`authorizer_test.exs`](/Users/jon/projects/sigra/test/sigra/admin/authorizer_test.exs#L65) covers global, in-scope, and out-of-scope direct-path access; [`phase_27_integration_test.exs`](/Users/jon/projects/sigra/test/example/test/example_web/integration/phase_27_integration_test.exs#L34) covers `/admin` denial and `/admin/organizations/:org` access end to end. |
| 4 | Admin navigation and page chrome keep the active global or organization scope visible so operators can tell where actions apply. | ✓ VERIFIED | [`layouts.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/components/layouts.ex#L91) renders the admin shell layout; [`admin_shell.ex`](/Users/jon/projects/sigra/test/example/lib/example_web/components/admin_shell.ex#L19) shows `Admin` plus the active scope chip and navigation; [`admin_shell_test.exs`](/Users/jon/projects/sigra/test/example/test/example_web/admin_shell_test.exs#L8) asserts `Global` and organization-name rendering. |
| 5 | Running `mix sigra.install` includes admin scaffolding unless `--no-admin` is passed. | ✓ VERIFIED | [`lib/sigra/install/features/admin.ex`](/Users/jon/projects/sigra/lib/sigra/install/features/admin.ex#L23) defaults `enabled?/1` to true; [`lib/mix/tasks/sigra.install.ex`](/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex#L61) sets `admin: true`; [`admin_test.exs`](/Users/jon/projects/sigra/test/sigra/install/features/admin_test.exs#L6) exercises both paths. |
| 6 | The generated host receives an explicit admin policy seam instead of hidden admin inference. | ✓ VERIFIED | [`policy.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/policy.ex#L1) contains only `platform_admin?/1` and `admin_org_ids/1` TODO seams with no fallback inference; [`lib/sigra/admin/policy.ex`](/Users/jon/projects/sigra/lib/sigra/admin/policy.ex#L1) keeps the helper explicit and opt-in. |
| 7 | Plug and LiveView admin entry paths enforce the same resolved admin scope. | ✓ VERIFIED | [`router_injection.ex`](/Users/jon/projects/sigra/priv/templates/sigra.install/admin/router_injection.ex#L20) pairs the admin plug and `on_mount`; [`require_admin_access_test.exs`](/Users/jon/projects/sigra/test/sigra/plug/require_admin_access_test.exs#L173) and [`admin_scope_test.exs`](/Users/jon/projects/sigra/test/sigra/live_view/admin_scope_test.exs#L133) cover matching allow and deny cases. |
| 8 | Direct-path admin exports, mutations, and query helpers have a library-owned authorization surface. | ✓ VERIFIED | [`authorizer.ex`](/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex#L15) provides `authorize_global!/1`, `authorize_organization!/2`, and `scope_query/2`; [`authorizer_test.exs`](/Users/jon/projects/sigra/test/sigra/admin/authorizer_test.exs#L53) verifies those helpers fail closed. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/install/features/admin.ex` | default-on additive installer feature owner | ✓ VERIFIED | Owns generated files plus router/layout/error-handler injections. |
| `priv/templates/sigra.install/admin/policy.ex` | explicit host-owned policy contract | ✓ VERIFIED | Minimal explicit seam; no hidden admin inference. |
| `priv/templates/sigra.install/admin/router_injection.ex` | generated admin route wiring | ✓ VERIFIED | Wires both admin route families through plug, `live_session`, admin layout, and policy contract. |
| `priv/templates/sigra.install/admin/components/admin_shell.ex` | generated visible scope chrome seam | ✓ VERIFIED | Substantive host-owned shell template with scope labels and nav chrome. |
| `lib/sigra/admin/policy.ex` | library policy behaviour | ✓ VERIFIED | Explicit callbacks and opt-in membership helper. |
| `lib/sigra/admin/scope.ex` | resolved global/org admin scope | ✓ VERIFIED | Fail-closed resolution for global and organization routes. |
| `lib/sigra/admin/authorizer.ex` | direct-path authorization surface | ✓ VERIFIED | Global/org authorization and structural query scoping. |
| `lib/sigra/plug/require_admin_access.ex` | server-side admin route gate | ✓ VERIFIED | Resolves scope, assigns it, and halts through the host error handler. |
| `lib/sigra/live_view/admin_scope.ex` | LiveView enforcement parity | ✓ VERIFIED | Re-resolves admin scope on mount for live navigation parity. |
| `test/example/lib/example/sigra_admin_policy.ex` | example host policy implementation | ✓ VERIFIED | Uses explicit fixture-backed global and org-admin decisions. |
| `test/example/lib/example_web/components/admin_shell.ex` | example scope chrome | ✓ VERIFIED | Renders active scope chip and route switching affordances. |
| `test/example/lib/example_web/router.ex` | example host admin wiring | ✓ VERIFIED | Mirrors the generated router template through plug, `on_mount`, and layout wiring. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/mix/tasks/sigra.install.ex` | `lib/sigra/install/features/admin.ex` | `@features` + `admin` switch/binding | ✓ WIRED | Mix task registers `Sigra.Install.Features.Admin`, parses `admin: :boolean`, and threads `admin?` into binding. |
| `lib/sigra/install/features/admin.ex` | `priv/templates/sigra.install/admin/policy.ex` | `files/1` | ✓ WIRED | Emits `lib/<app>/sigra_admin_policy.ex` from the template. |
| `lib/sigra/install/features/admin.ex` | generated host router/layout/error handler | `injections/1` | ✓ WIRED | Emits router, `Layouts.admin/1`, `AdminShell` import, and admin error-handler injections. |
| `priv/templates/sigra.install/admin/router_injection.ex` | admin enforcement stack | generated admin scopes and `live_session` | ✓ WIRED | Uses `Sigra.Plug.RequireAdminAccess`, `Sigra.LiveView.AdminScope`, `<app>.SigraAdminPolicy`, and `{Layouts, :admin}` for both `/admin` and `/admin/organizations/:org`. |
| `lib/sigra/plug/require_admin_access.ex` | `lib/sigra/admin/scope.ex` | resolved scope assignment | ✓ WIRED | `call/2` resolves through `Scope.resolve/3` and assigns `:admin_scope`. |
| `lib/sigra/live_view/admin_scope.ex` | `lib/sigra/admin/policy.ex` | policy callback dispatch | ✓ WIRED | Mount resolution routes through the policy-provided access decisions. |
| `lib/sigra/admin/authorizer.ex` | `lib/sigra/admin/scope.ex` | direct-path authorization helpers | ✓ WIRED | Uses the resolved `Sigra.Admin.Scope` for route-independent authorization. |
| `test/example/lib/example_web/router.ex` | admin enforcement stack | admin pipeline and `live_session` | ✓ WIRED | Example host matches the generated path with plug, admin layout, and `on_mount` parity. |
| `test/example/lib/example_web/components/layouts.ex` | `test/example/lib/example_web/components/admin_shell.ex` | admin layout hook | ✓ WIRED | `Layouts.admin/1` wraps admin pages with the shell and flash group. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/sigra/admin/live/index_live.ex` | `socket.assigns.admin_scope` | `priv/templates/sigra.install/admin/router_injection.ex` `on_mount` -> `Sigra.LiveView.AdminScope` -> `Sigra.Admin.Scope.resolve/3` | Yes | ✓ FLOWING |
| `lib/sigra/admin/live/organization_live.ex` | `socket.assigns.admin_scope` | `priv/templates/sigra.install/admin/router_injection.ex` org `on_mount` -> `Sigra.LiveView.AdminScope` -> `Sigra.Admin.Scope.resolve/3` | Yes | ✓ FLOWING |
| `test/example/lib/example_web/components/admin_shell.ex` | `@admin_scope` | `test/example/lib/example_web/components/layouts.ex` -> admin layout -> admin LiveView assigns | Yes | ✓ FLOWING |
| `test/example/lib/example/sigra_admin_policy.ex` | `admin_org_ids(scope)` | Membership query via `Repo.all()` on `OrganizationMembership` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Installer/admin focused suite | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs test/sigra/install/purely_additive_test.exs --max-failures 1` | User provided rerun evidence: passing | ✓ PASS |
| Example-host admin shell and routing suite | `cd test/example && mix test test/example_web/admin_shell_test.exs test/example_web/integration/phase_27_integration_test.exs --max-failures 1` | User provided rerun evidence: passing | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `ADMIN-01` | 27-01, 27-03 | Default-on admin install with `--no-admin` opt-out | ✓ SATISFIED | Mix task registration, feature flag threading, and admin installer tests are present. |
| `ADMIN-02` | 27-01, 27-02 | Explicit platform/org admin policy contract, no hidden defaults | ✓ SATISFIED | Generated policy seam plus library behaviour remain explicit and opt-in. |
| `ADMIN-03` | 27-02, 27-03 | Server-side admin enforcement for routes, LiveViews, exports, mutations | ✓ SATISFIED | Generated router template, plug, `on_mount`, and direct-path authorizer are all wired. |
| `ADMIN-04` | 27-02, 27-03 | Org admins remain inside allowed organization scope | ✓ SATISFIED | Resolver, authorizer, plug/live tests, and example integration tests cover in-scope and denied routes. |
| `ADMIN-05` | 27-03 | Visible active-scope chrome | ✓ SATISFIED | Admin layout and shell render scope labels for both global and organization modes. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `priv/templates/sigra.install/admin/policy.ex` | 14 | `TODO` | ℹ️ Info | Intentional host-owned policy seam; not a stub in the library path. |
| `priv/templates/sigra.install/admin/policy.ex` | 22 | `TODO` | ℹ️ Info | Intentional host-owned org-scope seam; expected for generated host customization. |

### Human Verification Required

### 1. Generated Admin Chrome

**Test:** Install Sigra into a fresh Phoenix host and open `/admin` plus `/admin/organizations/:org`.
**Expected:** The admin layout renders the shell, the top chrome shows `Admin` with the active scope, and the page remains readable on desktop and mobile widths.
**Why human:** The code and tests verify wiring and text presence, but not actual rendered layout quality.

### 2. Generated Error Responses

**Test:** In a generated host, hit a forbidden `/admin` path as an org admin and an out-of-scope `/admin/organizations/:org` path.
**Expected:** The browser shows the explicit 403/404 copy instead of a blank or misleading page.
**Why human:** Response-body tests passed, but the in-browser experience still needs visual confirmation.

### Gaps Summary

The two prior generated-host gaps are closed. The installer feature now injects the admin router scopes, the admin layout hook, the admin shell import, and the admin error-handler branches, so the generated path matches the example-host proof instead of leaving those pieces manual-only.

Automated evidence is now sufficient to mark every roadmap truth and every listed requirement as satisfied. What remains is human UI verification for the rendered admin chrome and error-page clarity, so the phase is `human_needed`, not `passed`.

---

_Verified: 2026-04-16T19:36:07Z_
_Verifier: Claude (gsd-verifier)_
