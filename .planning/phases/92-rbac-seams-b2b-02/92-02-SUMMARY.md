---
phase: 92-rbac-seams-b2b-02
plan: 02
subsystem: auth
tags: [rbac, organizations, generator, templates, authz, install]

# Dependency graph
requires:
  - phase: 92-rbac-seams-b2b-02 (Plan 92-01)
    provides: "Sigra.Authz behaviour, required :roles / :owner_role / :invitation_admin_roles config keys, role-agnostic Organizations seam"
provides:
  - "priv/templates/sigra.install/core/sigra_authz.ex (new) — host-owned Sigra.Authz starter mirroring admin/policy.ex stub posture"
  - "Reserved :role and :actor_type fields on the generated Scope struct (Phase 92 active; Phase 93 prep)"
  - "Nullable host-owned :role storage in OrganizationMembership schema + organizations migration (membership table only — invitation table out of scope)"
  - "Generator wrapper template now passes explicit roles / owner_role / invitation_admin_roles to use Sigra.Organizations"
  - "Frozen Plan 92-02 ownership split (Features.Core owns sigra_authz.ex; Features.Organizations owns membership templates) via coverage + idempotency tests"
affects: [92-03, 92-04, 93-m2m-tokens, downstream-recipes-rbac]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Generator-emits-host-starter pattern (mirrors admin-policy stub): generator ships a host-owned `@behaviour` implementer with allow-all defaults; recipe walks the host to deny-by-default."
    - "Reserve-now-populate-later scope-struct pattern: add `:actor_type` as nil-only Phase 92 prep so populating it in Phase 93 stays additive (no breaking scope-struct change)."
    - "Frozen ownership-split tests: per-feature `files/1` membership assertions in coverage_test.exs prevent silent template-ownership drift across plans."
    - "Idempotency-narrow-assertion: dedicated test asserts the new core/organizations split surfaces are byte-identical across two `mix sigra.install` runs."

key-files:
  created:
    - "priv/templates/sigra.install/core/sigra_authz.ex"
    - "test/sigra/install/authz_template_test.exs"
    - ".planning/phases/92-rbac-seams-b2b-02/deferred-items.md"
  modified:
    - "lib/sigra/install/features/core.ex"
    - "priv/templates/sigra.install/core/scope.ex"
    - "priv/templates/sigra.install/organizations/organization_membership.ex"
    - "priv/templates/sigra.install/organizations/migration.exs"
    - "priv/templates/sigra.install/organizations/organizations.ex"
    - "test/sigra/install/scope_template_fields_test.exs"
    - "test/sigra/install/scope_template_invariants_test.exs"
    - "test/sigra/install/features/coverage_test.exs"
    - "test/sigra/install/features/organizations_test.exs"
    - "test/sigra/install/features/core_test.exs"
    - "test/sigra/install/idempotency_test.exs"
    - "test/sigra/install/isolation_test.exs"
    - "test/sigra/install/templates_layout_test.exs"
    - "test/sigra/organizations/invitations_test.exs"
    - "test/example/lib/example/organizations.ex"
    - "test/example/lib/example/sigra_admin_policy.ex"
    - "test/fixtures/install_golden/STDOUT.txt"
    - "test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_membership.ex"
    - "test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex"
    - "test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/organizations.ex"
    - "test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/sigra_authz.ex (new — auto-emitted)"
    - "test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_organizations.exs"

key-decisions:
  - "Host-owned `Sigra.Authz` starter returns true from can?/3 (allow-all). Plan 92-04 walks hosts to deny-by-default; until then, allow-all preserves byte-identical behavior with the no-defaults world."
  - "`:actor_type` reserved on the scope struct as Phase 93 prep ONLY — no Phase 92 code branches on it anywhere. Adding it now keeps Phase 93 additive (no breaking scope-struct change)."
  - "Membership role storage: `:role` is plain `:string`, nullable, no `Ecto.Enum`, no `default: \"member\"`. Hosts bring their own taxonomy via `use Sigra.Organizations` `:roles`. The host-owned schema can be edited to add an Ecto.Enum cast if the host wants strict validation."
  - "Generator wrapper supplies `roles: [:owner, :admin, :member]`, `owner_role: :owner`, `invitation_admin_roles: [:owner, :admin]` as host-themed starter values. The values are explicitly editable host data — the seam is open."
  - "Invitation role storage is OUT of scope. Plan 92-02's must-haves explicitly call out `*membership* role storage`; the invitations.role column / schema enum stay as-is for now."
  - "`core/sigra_authz.ex` is owned by Features.Core (not Features.Admin or a separate Features.Authz). The Authz seam is core-scoped — it exists even with `--no-organizations` because the scope struct (which it reads) is core-owned."

patterns-established:
  - "Generator-emits-host-starter mirrors admin-policy stub: small `@behaviour`-implementing module under `lib/<otp_app>/sigra_*.ex` with TODO walking hosts to a hardening recipe."
  - "Reserve-now-populate-later for additive scope fields: docstring explicitly forbids branching on the field under the current phase to keep behavior frozen."
  - "Frozen ownership-split tests: future plans cannot silently move templates between Features without tripping the coverage_test.exs ownership-split describe block."

requirements-completed: [B2B-02]

# Metrics
duration: 41 min
completed: 2026-04-29
---

# Phase 92 Plan 02: RBAC Generator Surface Summary

**Generated host now ships a `Sigra.Authz` allow-all starter, reserves `:role` + `:actor_type` on the scope struct, drops opinionated membership-role enum/default in the schema + migration, and supplies explicit `roles` / `owner_role` / `invitation_admin_roles` config to `use Sigra.Organizations`.**

## Performance

- **Duration:** 41 min (worktree-agent execution)
- **Started:** 2026-04-29T19:17:56Z
- **Completed:** 2026-04-29T19:59:19Z
- **Tasks:** 2 (both TDD: RED → GREEN; no REFACTOR pass needed — templates were small and focused)
- **Files modified:** 22 (3 created including 1 deferred-items log; 19 modified)

## Accomplishments

- New `priv/templates/sigra.install/core/sigra_authz.ex` template emitted under `lib/<otp_app>/sigra_authz.ex` — host-owned `@behaviour Sigra.Authz` implementer with `can?/3` returning `true` for every input, mirroring the admin-policy stub posture. Moduledoc walks the host to the Plan 92-04 deny-by-default recipe and explicitly forbids branching on `:actor_type` under Phase 92.
- Generated scope struct now includes `:role` (atom() | nil) and `:actor_type` (atom() | nil) in both `defstruct` and `@type t`. `:role` carries the active membership's host-defined role atom; `:actor_type` is reserved Phase 93 prep with NO behavior attached anywhere in the library or the generated starter.
- `OrganizationMembership.role` is now plain `:string` storage (not `Ecto.Enum`), with `:role` removed from the changeset's `validate_required` list. Both adapter branches (postgres + mysql/sqlite) of the migration drop `null: false, default: "member"` for the membership table; invitation role storage is unchanged (out of plan scope).
- Generated `organizations.ex` wrapper now passes explicit `roles: [:owner, :admin, :member]`, `owner_role: :owner`, and `invitation_admin_roles: [:owner, :admin]` to `use Sigra.Organizations`, closing the Plan 92-01 explicit-only contract loop. The previously failing `CR-01 regression` compile test in `features/organizations_test.exs` now passes naturally.
- Frozen the Plan 92-02 ownership split: a new describe block in `features/coverage_test.exs` asserts `Features.Core` owns `core/sigra_authz.ex` and `Features.Organizations` owns the membership/migration templates. A new test in `idempotency_test.exs` proves both surfaces survive a second `mix sigra.install` run byte-identically.

## Task Commits

Each task was committed atomically (TDD: RED → GREEN):

1. **Task 1 RED — failing tests for host authz starter + reserved scope RBAC fields** — `fc1a96c` (test)
2. **Task 1 GREEN — host-owned Sigra.Authz starter + reserved scope fields** — `f5ea600` (feat)
3. **Task 2 RED — failing tests for nullable membership role + locked generator ownership** — `ac738b9` (test)
4. **Task 2 GREEN — nullable membership role + explicit host-owned wrapper config** — `be272fc` (feat)
5. **Task 2 Rule 3 — re-green Sigra.Organizations.InvitationsTest fixture (add :invitation_admin_roles)** — `e5fb9fe` (fix)
6. **Task 2 Rule 3 — regenerate install_golden fixture for Plan 92-02 template changes** — `b7d5544` (chore)
7. **Task 2 Rule 3 — re-green test/example scaffold compile** — `0739999` (fix)
8. **Task 2 Rule 3 — log DEF-92-02-01 deferred audit-Multi-collision** — `d6c41ae` (docs)

## Files Created/Modified

**Created:**

- `priv/templates/sigra.install/core/sigra_authz.ex` — Host-owned `@behaviour Sigra.Authz` starter. Returns `true` from `can?/3` for every input. Moduledoc walks the host to the Plan 92-04 deny-by-default recipe and forbids `:actor_type` branching under Phase 92.
- `test/sigra/install/authz_template_test.exs` — 6 tests asserting the new template exists, declares `@behaviour Sigra.Authz`, implements `can?/3` returning `true`, documents the host-owned posture, and is registered in `Features.Core.files/1` under `lib/<otp_app>/sigra_authz.ex`.
- `.planning/phases/92-rbac-seams-b2b-02/deferred-items.md` — Logs DEF-92-02-01: pre-existing `:audit` Multi step name collision in `lib/sigra/organizations/invitations.ex` `run_accept_multi/4` (committed Apr 15, predates Phase 92). Out of plan scope.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/sigra_authz.ex` — Auto-emitted by the regenerated golden fixture (consequence, not authored).

**Modified (lib):**

- `lib/sigra/install/features/core.ex` — Register the new `core/sigra_authz.ex` template in `base_files` under `lib/<otp_app>/sigra_authz.ex`.

**Modified (templates):**

- `priv/templates/sigra.install/core/scope.ex` — Add `role: nil` and `actor_type: nil` to `defstruct`. Add `role: atom() | nil` and `actor_type: atom() | nil` to `@type t`. Moduledoc documents the Phase 92 active vs Phase 93 reservation contract.
- `priv/templates/sigra.install/organizations/organization_membership.ex` — Drop `Ecto.Enum, values: [:owner, :admin, :member]` from the role field — now plain `field :role, :string`. Drop `:role` from `validate_required` so accept-invite-then-pick-role flows work.
- `priv/templates/sigra.install/organizations/migration.exs` — Drop `null: false, default: "member"` from `organization_memberships.role` across both postgres and mysql/sqlite branches. Invitation table unchanged.
- `priv/templates/sigra.install/organizations/organizations.ex` — Pass explicit `roles: [:owner, :admin, :member]`, `owner_role: :owner`, and `invitation_admin_roles: [:owner, :admin]` to `use Sigra.Organizations`.

**Modified (tests):**

- `test/sigra/install/scope_template_fields_test.exs` — Added 3 assertions for role + actor_type in defstruct, @type, and moduledoc reservation contract.
- `test/sigra/install/scope_template_invariants_test.exs` — Added describe block introspecting the rendered Scope struct to prove `:role` and `:actor_type` are present and default to nil.
- `test/sigra/install/features/coverage_test.exs` — New "Phase 92 Plan 92-02 ownership split" describe block freezing the core-vs-organizations ownership boundary across both Feature modules.
- `test/sigra/install/features/organizations_test.exs` — New tests for: explicit role config in wrapper template; nullable schema role field (no Ecto.Enum, no validate_required); nullable migration role column with no `default: "member"` for the membership table.
- `test/sigra/install/features/core_test.exs` — Bump file-count fixtures (38 → 39 default; 32 → 33 --no-live) for the new `core/sigra_authz.ex` template.
- `test/sigra/install/idempotency_test.exs` — New test asserting both Plan 92-02 surfaces (sigra_authz.ex + organization_membership.ex) land on first run AND survive byte-identically across a second `mix sigra.install` run.
- `test/sigra/install/isolation_test.exs` — Bump core/ template count from 49 to 50.
- `test/sigra/install/templates_layout_test.exs` — Add `sigra_authz.ex` to `@manifest_post_move` and bump count from 49 to 50.
- `test/sigra/organizations/invitations_test.exs` — Add `invitation_admin_roles: [:owner, :admin]` to the fixture config map (Rule 3 follow-through for Plan 92-01's required-options contract).
- `test/example/lib/example/organizations.ex` — Add `roles`, `owner_role`, `invitation_admin_roles` to `use Sigra.Organizations` so the example app compiles after Plan 92-01.
- `test/example/lib/example/sigra_admin_policy.ex` — Switch `admin_org_ids_from_memberships(memberships)` (arity 1) to the new `admin_org_ids_from_memberships(memberships, roles: [:owner, :admin])` (arity 2) shape.

**Modified (golden fixture — auto-emitted via regen script):**

- `test/fixtures/install_golden/STDOUT.txt`
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_membership.ex`
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex`
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/organizations.ex`
- `test/fixtures/install_golden/tree/priv/repo/migrations/TIMESTAMP_create_organizations.exs`

## Decisions Made

- **Host authz starter is allow-all**, not deny-by-default. Returning `true` preserves byte-identical behavior versus the pre-Plan-92-01 world (where the library shipped no host authz module at all). Plan 92-04 owns the recipe that walks hosts to deny-by-default — landing deny-by-default in Plan 92-02 would silently change every install's authorization posture before the host has even read the recipe.
- **`:actor_type` is nil-only Phase 92 prep, with NO behavior attached.** Documented this explicitly in three places (scope.ex moduledoc, scope.ex inline comment, sigra_authz.ex moduledoc). The Phase 92 → 93 transition stays additive: Phase 93 populates `:actor_type` for service accounts without changing the scope struct.
- **`organization_invitation.ex` and the invitation-table role column stay as-is.** Plan 92-02 explicitly scopes "membership role storage" only. Touching the invitation role would expand scope into a separate seam (invitation-side role validation) that has different consumers and a different audit story.
- **Generator wrapper supplies `[:owner, :admin, :member]` etc. as starter values, not empty lists.** Empty lists would require host editing before the app compiles (NimbleOptions validates non-emptiness). Starter values match the pre-Plan-92-01 implicit defaults so the upgrade is no-op for typical host apps.
- **`core/sigra_authz.ex` is owned by Features.Core.** The Authz seam is intrinsically core-scoped — the scope struct it reads is core-owned, and the seam exists even with `--no-organizations`. Putting it under Features.Admin or a new Features.Authz would couple it to that feature's optional flag.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Bump file-count test fixtures in `test/sigra/install/features/core_test.exs`**
- **Found during:** Task 1 GREEN verification
- **Issue:** Two tests assert hard counts of `Core.files/1` output (38 default, 32 --no-live). Adding `core/sigra_authz.ex` to the file list bumps these to 39 / 33; the fixtures had to follow.
- **Fix:** Updated the count assertions and added Phase 92 Plan 92-02 explanation comments naming the new template.
- **Files modified:** `test/sigra/install/features/core_test.exs`
- **Verification:** All 33 tests in `Sigra.Install.Features.CoreTest` pass.
- **Committed in:** `f5ea600` (Task 1 GREEN)

**2. [Rule 3 - Blocking] Bump core/ template count + add to manifest in isolation/layout tests**
- **Found during:** Task 2 GREEN broader test sweep (all install tests under `test/sigra/install/`)
- **Issue:** `Sigra.Install.IsolationTest` asserts the core/ subdirectory contains exactly 49 templates. `Sigra.Install.TemplatesLayoutTest` asserts a hard `@manifest_post_move` list of 49 basenames. Adding `core/sigra_authz.ex` bumps both to 50 and the manifest must include the new basename.
- **Fix:** Updated both count assertions and added `sigra_authz.ex` to `@manifest_post_move`. Inline comments name the Plan 92-02 source of the bump.
- **Files modified:** `test/sigra/install/isolation_test.exs`, `test/sigra/install/templates_layout_test.exs`
- **Verification:** All 5 tests across the two files pass.
- **Committed in:** `be272fc` (Task 2 GREEN)

**3. [Rule 3 - Blocking] Re-green `Sigra.Organizations.InvitationsTest` fixture (add :invitation_admin_roles)**
- **Found during:** Plan-context verification (running `test/sigra/organizations/`)
- **Issue:** Plan 92-01 made `:invitation_admin_roles` a required NimbleOptions key. The fixture-level config map in `test/sigra/organizations/invitations_test.exs` builds its own config directly (not via `use Sigra.Organizations`), so the contract change broke 22 tests with `ArgumentError: requires :invitation_admin_roles`. The plan's `<context>` block calls these out as expected re-green work for Plan 92-02.
- **Fix:** Added `invitation_admin_roles: [:owner, :admin]` to the fixture's config map.
- **Files modified:** `test/sigra/organizations/invitations_test.exs`
- **Verification:** 46/46 invitations tests pass; 193/193 across `test/sigra/organizations/`.
- **Committed in:** `e5fb9fe` (separate Rule 3 commit)

**4. [Rule 3 - Blocking] Regenerate `test/fixtures/install_golden/` for Plan 92-02 template changes**
- **Found during:** Post-GREEN broad verification (running `test/sigra/install/golden_diff_test.exs --include integration`)
- **Issue:** `golden_diff_test.exs` byte-diffs the live `mix sigra.install` output against the committed golden tree. Plan 92-02 legitimately changes 4 templates (scope.ex, organization_membership.ex, migration.exs, organizations.ex) and adds 1 new (sigra_authz.ex), so the live output diverges from the committed fixture. Without regeneration the `install_golden_contract` and `library_tests` CI jobs would both fail.
- **Fix:** Wrote a one-shot regen script (`/tmp/regen_golden_fixture.exs`) that runs the existing `Sigra.Test.InstallFixture.setup_tmp_app/0` + `normalize_tree/2` + `normalize_stdout/2` pipeline and writes the result back into `test/fixtures/install_golden/`. Procedure mirrors the runbook in `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md`.
- **Files modified:** 5 fixture files (4 modified + 1 new sigra_authz.ex; STDOUT.txt also bumps for the new "creating" line).
- **Verification:** `mix test test/sigra/install/golden_diff_test.exs --include integration` passes 2/2 tests in 63s.
- **Committed in:** `b7d5544` (separate Rule 3 commit)

**5. [Rule 3 - Blocking] Re-green `test/example/` scaffold compile after Plan 92-01 contract change**
- **Found during:** Post-GREEN integration check (running `mix test --include example_app` from `test/example/`)
- **Issue:** The example app's `lib/example/organizations.ex` uses `use Sigra.Organizations` without the new required keys, and `lib/example/sigra_admin_policy.ex` calls `Sigra.Admin.Policy.admin_org_ids_from_memberships/1` (now arity 2). Both fail at `mix compile --warnings-as-errors`, which the `example_unit_smoke` CI job runs.
- **Fix:** Added `roles: [:owner, :admin, :member]`, `owner_role: :owner`, `invitation_admin_roles: [:owner, :admin]` to the wrapper. Switched the admin-policy call to the new arity-2 form with explicit `roles: [:owner, :admin]`.
- **Files modified:** `test/example/lib/example/organizations.ex`, `test/example/lib/example/sigra_admin_policy.ex`
- **Verification:** `mix compile --warnings-as-errors` passes cleanly from `test/example/`.
- **Committed in:** `0739999` (separate Rule 3 commit)

---

**Total deviations:** 5 auto-fixed (all Rule 3 — blocking follow-through to Plan 92-01's contract change and Plan 92-02's template changes).
**Impact on plan:** All deviations are tightly scoped Rule 3 fixes. The first two are file-count fixture updates (a direct consequence of adding 1 new template). The third is the Plan 92-01 expected re-green explicitly called out in the plan's `<context>` block. The fourth is the runbook-documented golden-fixture regeneration. The fifth re-greens the example scaffold compile so the `example_unit_smoke` CI job passes. No scope creep — every change is required by the plan's contract surface.

## Issues Encountered

- **Pre-existing `:audit` Multi step collision in `Sigra.Organizations.Invitations.run_accept_multi/4`.** Discovered while running `mix test --include example_app` from `test/example/` to verify the Rule 3 example-app re-green. 4 tests in `ExampleWeb.InvitationAcceptLiveTest` (T9, T14, T17, T18) fail with `RuntimeError: :audit is already a member of the Ecto.Multi`. `git blame` puts the collision on commit `5e6c026` (2026-04-15 — two weeks before Phase 92 started), so it predates Plan 92-01 and 92-02. Fixing it requires renaming Multi step names across two seams (Rule 4 architectural change), which is out of plan scope. Logged as `DEF-92-02-01` in `.planning/phases/92-rbac-seams-b2b-02/deferred-items.md` with a recommended landing point and reproducer. The example app's `mix compile --warnings-as-errors` step still passes — only the runtime invitation-acceptance tests trip the collision.

## User Setup Required

None — no external service configuration required. The generator template change is fully self-contained: a fresh `mix sigra.install` produces a host that compiles and behaves identically to the pre-Plan-92-01 world (the host-owned `Sigra.Authz` starter returns `true` for every input, matching the implicit allow-all that was effectively there before). Hosts who want deny-by-default semantics will follow the Plan 92-04 recipe.

## Next Phase Readiness

- **Plan 92-03 (current_scope :role propagation)** is unblocked. Plan 92-02 reserved `:role` and `:actor_type` on the generated scope struct; Plan 92-03 wires the actual hydration code to populate `:role` from the active membership during scope creation.
- **Plan 92-04 (RBAC recipe + golden/docs/authz verification gates)** is unblocked. The host-owned starter is a stable anchor point for the deny-by-default recipe — the recipe walks hosts from the allow-all starter to per-action allow rules + a deny fall-through, with both the start and end states already documented in the starter's moduledoc.
- **Phase 93 (M2M tokens)** is unblocked. The `:actor_type` reservation is in place; Phase 93 populates it for service accounts without a breaking scope-struct change.
- **Pre-existing audit-Multi collision (DEF-92-02-01)** is the only outstanding test failure under `test/example/`. It blocks 4 of 333 example tests (1.2%) and is documented for a follow-up plan to address.

## Self-Check: PASSED

- [x] `priv/templates/sigra.install/core/sigra_authz.ex` exists — verified via `[ -f ... ]`.
- [x] `test/sigra/install/authz_template_test.exs` exists — verified via `[ -f ... ]`.
- [x] `.planning/phases/92-rbac-seams-b2b-02/deferred-items.md` exists — verified via `[ -f ... ]`.
- [x] All in-scope tests pass:
  - Task 1 verify (`scope_template_fields + scope_template_invariants + template_render + template_syntax + authz_template_test`): 100/100 pass.
  - Task 2 verify (`features/coverage_test + features/organizations_test + idempotency_test`): 75/75 pass (incl. integration idempotency).
  - Wider install sweep (`mix test test/sigra/install/ --exclude integration --exclude golden`): 579/579 pass.
  - Plan-context fixture re-green (`test/sigra/organizations/`): 193/193 pass.
  - Golden-diff regen (`test/sigra/install/golden_diff_test.exs --include integration`): 2/2 pass.
- [x] Plan verification regex `rg -n "Ecto.Enum, values: \[:owner, :admin, :member\]|default: \"member\"|actor_type: nil|role: nil" priv/templates/sigra.install` returns: `core/scope.ex:44 role: nil` + `core/scope.ex:45 actor_type: nil` (the EXPECTED Plan 92-02 GREEN matches) plus 3 invitation-table matches (out of plan scope per the plan's must-haves wording "membership role storage").
- [x] Commits exist:
  - `fc1a96c` (Task 1 RED) — verified via `git log`.
  - `f5ea600` (Task 1 GREEN) — verified via `git log`.
  - `ac738b9` (Task 2 RED) — verified via `git log`.
  - `be272fc` (Task 2 GREEN) — verified via `git log`.
  - `e5fb9fe` (Rule 3: invitations fixture) — verified via `git log`.
  - `b7d5544` (Rule 3: golden fixture regen) — verified via `git log`.
  - `0739999` (Rule 3: example app re-green) — verified via `git log`.
  - `d6c41ae` (Rule 3: deferred-items log) — verified via `git log`.

## TDD Gate Compliance

Both tasks followed RED → GREEN. Plan-level frontmatter is `type: execute` (not `type: tdd`), so the gate sequence is per-task rather than global; both per-task TDD cycles are intact in the commit log:

```
fc1a96c test(92-02): add failing tests for host-owned authz starter + reserved scope RBAC fields  # Task 1 RED
f5ea600 feat(92-02): emit host-owned Sigra.Authz starter + reserve scope RBAC fields              # Task 1 GREEN
ac738b9 test(92-02): add failing tests for nullable membership role + locked generator ownership  # Task 2 RED
be272fc feat(92-02): nullable membership role + explicit host-owned wrapper config                # Task 2 GREEN
```

Rule 3 follow-through commits (e5fb9fe, b7d5544, 0739999, d6c41ae) are intentionally separate from the per-task TDD cycle so they remain reviewable as discrete fixes against the contract change.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries were introduced beyond what the plan's `<threat_model>` already declared. Mitigation status against the Phase 92-02 threat register (T-92-04..T-92-06):

- **T-92-04 (T, generated authz stub)** — Mitigated. The host-owned starter is an explicit allow-all anchor. The moduledoc + inline TODO walk hosts directly to the Plan 92-04 deny-by-default recipe so the starter's posture is visible rather than implicit. The behaviour-only library contract (no library-side `can?/3`) means hosts cannot accidentally inherit the allow-all from the library.
- **T-92-05 (T, membership role column)** — Mitigated. The `role` column is nullable, has no opinionated default, and uses plain `:string` storage. Hosts declare role taxonomy explicitly via `:roles` in `use Sigra.Organizations`; the schema does not enforce a canonical universe.
- **T-92-06 (E, generated wrapper config)** — Mitigated. The wrapper template passes `roles`, `owner_role`, and `invitation_admin_roles` as explicit values at the `use Sigra.Organizations` call site. The privilege taxonomy is visible in source for every host and reviewable at code-review time.

No threat flags found.

---
*Phase: 92-rbac-seams-b2b-02*
*Completed: 2026-04-29*
