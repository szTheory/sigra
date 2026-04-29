---
phase: 92-rbac-seams-b2b-02
plan: 04
subsystem: docs
tags: [rbac, docs, recipe, golden, verification, b2b-02, phase-close]

# Dependency graph
requires:
  - phase: 92-rbac-seams-b2b-02 (Plan 92-01)
    provides: "Sigra.Authz behaviour, role-agnostic explicit-only Organizations seam"
  - phase: 92-rbac-seams-b2b-02 (Plan 92-02)
    provides: "Generated host-owned Sigra.Authz starter, reserved scope :role/:actor_type fields, nullable membership.role storage, explicit roles/owner_role/invitation_admin_roles wrapper config"
  - phase: 92-rbac-seams-b2b-02 (Plan 92-03)
    provides: "scope.role propagation through hydration + active-org transition seams; plug ↔ on_mount parity"
provides:
  - "Published guides/recipes/role-based-access-control.md walking from the generated allow-all Sigra.Authz starter to a host-owned owner/admin/member deny-by-default policy"
  - "ExDoc registration of the new recipe under the Recipes group"
  - "Structural existence coverage for the new recipe in test/sigra/guides_dx02_test.exs (count bumped 17 → 18)"
  - "Phase 92 close: all named merge-gate surfaces pass (authz contract, generator coverage/idempotency, template render/syntax, install golden diff, example-app install compile smoke, docs/compile warnings-as-errors)"
affects: [downstream-recipes-rbac, 93-m2m-tokens]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Recipe-as-deny-by-default-walkthrough: pair a generator-emitted allow-all starter (anchor) with a published recipe (hardening) so adopters always have a stable end-state to copy from."
    - "Recipe references library callbacks via the c:Module.fun/arity ExDoc syntax to keep mix docs --warnings-as-errors green."
    - "Phase-close verification gate: Plan 92-04 runs the named merge-gate surfaces explicitly (authz, generator coverage/idempotency, render/syntax, golden diff, example-app smoke, docs, compile) so Phase 92 closes on the same surfaces it was scoped against."

key-files:
  created:
    - "guides/recipes/role-based-access-control.md"
  modified:
    - "mix.exs"
    - "test/sigra/guides_dx02_test.exs"

key-decisions:
  - "Recipe is published under guides/recipes/ and grouped with Recipes, alongside multi-tenant.md. The two recipes are complementary (RBAC = privilege within membership; multi-tenant = data isolation across orgs) and adopters typically need both."
  - "Concrete role atoms in the recipe (`:owner / :admin / :member`) are framed explicitly as host-owned example values, not library defaults. The recipe states this in two places (top-of-file framing, plus 'Customizing the role taxonomy' section showing `:tenant_lead / :site_admin / :reviewer / :viewer` as an alternative shape) so readers cannot confuse them with a library mandate."
  - "guides_dx02_test.exs gets a count bump (17 → 18) and an explicit comment naming Plan 92-04. The deeper 'Sigra.* references match shipped code' assertion already passes for the new recipe because every API the recipe references — `Sigra.Authz`, `Sigra.Plug.PutActiveOrganization`, `Sigra.Scope.Hydration.hydrate/3`, `Sigra.Plug.RequireMembership`, `Sigra.Plug.LoadActiveOrganization`, `Sigra.Organizations.Query.for_org/2` — is a real shipped module, and the regex-based extractor only triggers on `Module.function` references, of which `Sigra.Organizations.Query.for_org/2` is the only one in the recipe and it already resolves."
  - "Recipe references the `Sigra.Authz.can?/3` callback as `c:Sigra.Authz.can?/3` so ExDoc autolinks it correctly (regular `.fun/arity` syntax warns under `--warnings-as-errors` because callbacks are not `function_exported?` results). Discovered as a Rule 3 fix during Task 1 verification."
  - "Task 2 makes zero file changes. Wave 2 (Plan 92-02) had already regenerated the install golden fixture under its Rule 3 follow-through. Plan 92-03 introduced no template changes (user_auth.ex was deliberately not modified — see 92-03 key decisions). Plan 92-04 introduces no template changes either. The named golden fixture files are therefore already byte-current with the Phase 92 templates; running golden_diff_test.exs as the verification gate confirms this with a 2/2 pass under `--include integration`."

patterns-established:
  - "Recipe-as-hardening pattern: generator emits a behaviorally-neutral starter (allow-all) so existing apps do not change behavior on upgrade; a published recipe walks the host to deny-by-default. Both the start and end states are documented in the starter's moduledoc and the recipe."
  - "ExDoc callback autolink: any guide referencing a `@callback` must use `c:Module.fun/arity` syntax to stay green under `mix docs --warnings-as-errors`."
  - "Phase-close verification ledger: a closing plan in a multi-wave phase explicitly runs the named merge-gate test surfaces from the phase brief (authz contract, generator coverage/idempotency, template render/syntax, install golden diff, example-app smoke, docs, compile) so the phase closes on a single executable list instead of a prose checklist."

requirements-completed: [B2B-02]

# Metrics
duration: 18 min
completed: 2026-04-29
---

# Phase 92 Plan 04: RBAC Recipe + Phase Close Summary

**New `guides/recipes/role-based-access-control.md` walks the host from the generated allow-all `Sigra.Authz` starter to a host-owned `owner/admin/member` deny-by-default policy; recipe registered with ExDoc; named Phase 92 verification gates all green; Phase 92 / B2B-02 closes.**

## Performance

- **Duration:** ~18 min (worktree-agent execution)
- **Started:** 2026-04-29T20:45:53Z
- **Completed:** 2026-04-29T21:03:00Z (approx, post-SUMMARY)
- **Tasks:** 2 (Task 1: recipe + ExDoc registration + structural test bump; Task 2: verification close-out, zero file changes)
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- Published `guides/recipes/role-based-access-control.md` — concrete recipe in the same posture as `guides/recipes/multi-tenant.md`. Frames `Sigra.Authz` as a seam, names the four moving parts (`Sigra.Authz` behaviour, generated `MyApp.SigraAuthz`, generated `MyApp.Organizations` wrapper, `%Scope{role:, actor_type: nil}`), shows the allow-all starter, then walks to a deny-by-default `owner/admin/member` policy with explicit allow rules and a `def can?(_action, _subject, _scope), do: false` fall-through. Includes controller/LiveView call patterns, scope-role propagation explainer (Plan 92-03 seams), `ExUnit` test patterns for the policy (allow paths + deny fall-through), and a "Customizing the role taxonomy" section showing alternative atom shapes (`:tenant_lead / :site_admin / :reviewer / :viewer`).
- Registered the recipe in `mix.exs` `extras:` between `multi-tenant.md` and `passkeys.md` so ExDoc publishes it under the Recipes group.
- Bumped `guides_dx02_test.exs` expected guide count 17 → 18 with the new recipe path; explicit comment names Plan 92-04 so future readers can trace the addition.
- All named Phase 92 verification gates pass green:
  - `MIX_ENV=test mix test test/sigra/authz_test.exs` → 8/8 pass.
  - `MIX_ENV=test mix test test/sigra/install/features/coverage_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs --include integration` → 91/91 pass (3 integration tests included).
  - `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs --include integration` → 2/2 pass (live golden fixture diff).
  - `MIX_ENV=test mix test test/sigra/guides_dx02_test.exs` → 12/12 pass (incl. the bumped count test).
  - `cd test/example && CLOAK_KEY=… MIX_ENV=test mix test test/example_web/smoke/install_compile_test.exs --include example_app` → 4/4 pass.
  - `mix docs --warnings-as-errors` → green.
  - `mix compile --warnings-as-errors` → green.
- 116/116 library tests across the consolidated gate run pass in ~121s (golden_diff dominates wall-clock).

## Task Commits

Each task was committed atomically:

1. **Task 1 — RBAC recipe + ExDoc registration + guides_dx02 count bump** — `b5c7423` (docs)
2. **Task 2 — Phase 92 close: verification only, zero file changes** — no separate commit (Wave 2 had already regenerated the golden fixture; no further template changes in Plans 92-03 or 92-04, so the named golden fixture files were already byte-current and passed `golden_diff_test.exs` cleanly). The plan-completion docs commit follows after this SUMMARY is written.

## Files Created/Modified

**Created:**

- `guides/recipes/role-based-access-control.md` — Published RBAC recipe. Top-of-file framing states explicitly that Sigra ships a seam (not a permission engine) and that concrete role atoms are host-owned examples, not library defaults. Sections: "What Sigra ships", "The generated allow-all starter", "Replace the starter with deny-by-default" (worked example with five clauses + explicit fall-through), "Calling can?/3 from controllers and LiveViews", "How the scope role gets populated" (Plan 92-03 seams + plug ↔ LiveView parity), "Testing your policy" (allow paths + deny fall-through), "Customizing the role taxonomy" (3 alternative shapes), "What can?/3 should NOT decide" (membership presence vs data isolation vs privilege), "Related" (cross-links to Sigra.Authz, multi-tenant, getting-started). Total: ~250 lines, ~1.6KB.

**Modified:**

- `mix.exs` — Added `"guides/recipes/role-based-access-control.md"` to `extras:` between `multi-tenant.md` and `passkeys.md`. The Recipes group regex (`~r{guides/recipes/.?}`) already covers it; no `groups_for_extras` change required.
- `test/sigra/guides_dx02_test.exs` — Bumped expected guide count from 17 to 18 in the structural existence test; added `"recipes/role-based-access-control.md"` to the expected list with an explicit Plan 92-04 comment naming the addition.

## Decisions Made

- **Recipe is published, not a `.planning/` artifact.** The plan's must-haves require the recipe to ship in published docs; `mix docs --warnings-as-errors` is the gate. Putting the recipe under `guides/recipes/` (alongside `multi-tenant.md`) places it in the same hexdocs.pm grouping adopters already browse for cross-cutting recipes.
- **Recipe pairs the allow-all starter with the deny-by-default end state explicitly.** The starter (Plan 92-02) returns `true` to preserve byte-identical behavior on upgrade; the recipe shows the hardening step. Without that pairing, adopters either accept the allow-all forever (silent privilege escalation) or have to invent the policy shape themselves (risk of subtle deny-vs-allow inversions). The recipe's worked example makes the pattern copy-pasteable.
- **Concrete role atoms (`:owner / :admin / :member`) are framed explicitly as host-owned examples, not library defaults.** The recipe states this in two places: top-of-file framing ("the roles you see below — `:owner`, `:admin`, `:member` — are example values supplied by the generated `use Sigra.Organizations` block, not library defaults") and the "Customizing the role taxonomy" section showing alternative shapes (`:tenant_lead / :site_admin / :reviewer / :viewer` — same atoms used in `test/sigra/plug/require_membership_test.exs` after Plan 92-01). This satisfies the threat-mitigation T-92-10 ("State clearly that concrete roles are host-owned examples").
- **`Sigra.Authz.can?/3` callback referenced as `c:Sigra.Authz.can?/3`.** ExDoc treats `Module.fun/arity` and `c:Module.fun/arity` differently: the former resolves against `function_exported?` and warns when the target is a behaviour callback (which `can?/3` is), the latter resolves against `@callback` declarations. Using the callback syntax keeps `mix docs --warnings-as-errors` green without weakening any other autolink.
- **`guides_dx02_test.exs` gets a count bump and explicit Plan 92-04 comment.** The plan permits expansion when the recipe needs structural coverage; the existence assertion is the closest existing surface that captures "the recipe ships". The 'Sigra.\* references match shipped code' assertion already passes for the new recipe — every API it references is a real shipped module — so no allow-list expansion was needed.
- **Task 2 makes zero file changes.** Wave 2 (Plan 92-02) regenerated the install golden fixture under its Rule 3 follow-through (commit `b7d5544`). Wave 3 (Plan 92-03) deliberately did NOT modify any template (per its key decisions, `user_auth.ex` was left structurally unchanged because role propagation in the LiveView mount path happens transparently via the existing `hydrate_scope/2` call). Plan 92-04 introduces no template changes either. The named golden fixture files in the plan's `files_modified` list are therefore already byte-current; running `golden_diff_test.exs` as the verification gate confirms this with 2/2 pass under `--include integration` (~70s for the live `mix sigra.install` round-trip). This is the cleanest possible close-out posture.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `Sigra.Authz.can?/3` reference in the recipe must use callback syntax for `mix docs --warnings-as-errors` to pass**
- **Found during:** Task 1 first verification run.
- **Issue:** Initial draft of the recipe wrote `Sigra.Authz.can?/3` in the top-of-file framing. ExDoc's autolinker resolves `Module.fun/arity` against `function_exported?` and treats `can?/3` as undefined (the module exposes a `@callback`, not a `def`). Under `--warnings-as-errors` this fails the build with: `documentation references function "Sigra.Authz.can?/3" but it is undefined or private`.
- **Fix:** Changed the single occurrence to `c:Sigra.Authz.can?/3` (ExDoc callback autolink syntax). Verified the recipe still reads naturally — the `c:` prefix is invisible in rendered HTML/markdown.
- **Files modified:** `guides/recipes/role-based-access-control.md` (single character-position edit, single occurrence).
- **Verification:** `mix docs --warnings-as-errors` → green. `guides_dx02_test.exs` still passes (the regex extractor matches the same `Sigra.Authz.can?` shape regardless of the leading `c:`).
- **Committed in:** `b5c7423` (Task 1 commit).

---

**Total deviations:** 1 (single Rule 3 callback-syntax fix during Task 1 verification).
**Impact on plan:** Tightly scoped. The plan's `<verify>` for Task 1 (`mix docs --warnings-as-errors`) is the gate that surfaced it; the fix is a single-character syntax change. No scope creep.

## Issues Encountered

- **None.** All Phase 92 verification gates passed cleanly. The pre-existing `:audit` Multi step collision (`DEF-92-02-01`) carried over from Plan 92-02 is unaffected by Plan 92-04 work and is documented for a follow-up plan.

## TDD Gate Compliance

Plan-level frontmatter is `type: execute` (not `type: tdd`); Task 1 is a docs/recipe task and Task 2 is a verification close-out, neither of which fits the RED → GREEN → REFACTOR shape. The recipe's worked example includes a published test pattern (allow paths + deny fall-through) so adopters get a TDD-friendly starting point even though the plan itself does not run a TDD cycle.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries were introduced. Mitigation status against the Phase 92-04 threat register:

- **T-92-10 (T, RBAC recipe)** — Mitigated. The recipe states explicitly in two places (top-of-file framing and "Customizing the role taxonomy") that concrete role atoms are host-owned example values, not library defaults. The "What Sigra ships" section enumerates the four moving parts and identifies which are library-owned (`Sigra.Authz` behaviour) vs host-owned (`MyApp.SigraAuthz`, `MyApp.Organizations`, `%Scope{role:, actor_type: nil}`). The "Replace the starter with deny-by-default" section walks the host from allow-all to per-action allow rules + a `def can?(_action, _subject, _scope), do: false` fall-through.
- **T-92-11 (R, golden fixture refresh)** — Mitigated. Plan 92-04 introduces no template changes, so no golden regen happens. `golden_diff_test.exs` runs as a byte-level gate (2/2 pass under `--include integration`) and confirms the existing fixture is byte-current with the Phase 92 templates.
- **T-92-12 (I, docs/build verification)** — Mitigated. Both `mix docs --warnings-as-errors` and `mix compile --warnings-as-errors` are explicit gates run during this plan's verification close-out.

No threat flags found.

## User Setup Required

None — this plan ships docs and runs verification. Generated host applications already get the host-owned `Sigra.Authz` starter from Plan 92-02 and the role propagation wiring from Plan 92-03; the new recipe walks them through the deny-by-default hardening at their own pace.

## Next Phase Readiness

- **Phase 92 / B2B-02 closes here.** All four plans (92-01 → 92-04) are complete; all named merge-gate surfaces pass; the requirement (B2B-02 — "RBAC seams without an opinionated taxonomy") is fully satisfied with seam + generator + propagation + recipe.
- **Phase 93 (M2M tokens)** is unblocked. Plan 92-02 reserved `:actor_type` on the generated scope struct; Plan 92-03 carries it through `Sigra.Scope.{build,from_opts,from_config}` without library-side branching. Phase 93 populates `:actor_type` for service accounts as a purely additive change.
- **Downstream RBAC recipes** (e.g. attribute-based access, role hierarchies, time-of-day gates) can be layered on the published recipe without changing the library seam — `Sigra.Authz.can?/3` is general-purpose enough that any host policy fits.
- **Pre-existing audit-Multi collision (`DEF-92-02-01`)** carries over to a follow-up plan as documented in `.planning/phases/92-rbac-seams-b2b-02/deferred-items.md`.

## Self-Check: PASSED

- [x] `guides/recipes/role-based-access-control.md` exists — verified via `[ -f ... ]`.
- [x] Recipe contains "deny-by-default" (must-have artifact contains-clause) — verified via `grep -c "deny-by-default" ... → 2`.
- [x] `mix.exs` registers `guides/recipes/role-based-access-control.md` (must-have artifact contains-clause) — verified via `grep "role-based-access-control" mix.exs → 1 match in extras list`.
- [x] `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/sigra_authz.ex` exists and contains `def can?(` — verified via `grep -c "def can?(" ... → 5 matches`.
- [x] `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_membership.ex` exists and contains "role" — verified via `grep -c "field :role, :string" ... → 1 match`.
- [x] All named verification gates pass:
  - `MIX_ENV=test mix test test/sigra/authz_test.exs` → 8/8 pass.
  - `MIX_ENV=test mix test test/sigra/install/features/coverage_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs test/sigra/install/golden_diff_test.exs test/sigra/guides_dx02_test.exs --include integration` → 116/116 pass (incl. 3 integration golden_diff tests + 2 idempotency integration tests).
  - `cd test/example && CLOAK_KEY=… MIX_ENV=test mix test test/example_web/smoke/install_compile_test.exs --include example_app` → 4/4 pass.
  - `mix docs --warnings-as-errors` → green.
  - `mix compile --warnings-as-errors` → green.
- [x] Commit exists:
  - `b5c7423` (Task 1) — verified via `git log`.

## Threat Flags

None — no new security-relevant surface introduced. The recipe is documentation; the generator changes that introduced new surface area landed in Plans 92-01..92-03.

---
*Phase: 92-rbac-seams-b2b-02*
*Completed: 2026-04-29*
