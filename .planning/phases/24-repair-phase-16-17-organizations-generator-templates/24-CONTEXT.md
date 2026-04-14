# Phase 24: Repair Phase 16/17 organizations generator templates — Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Source:** /gsd-discuss-phase (interactive)

<domain>
## Phase Boundary

Fix pre-existing defects in Phase 16/17 organizations generator templates (DEF-18-01) and Phase 17 Features.Core registration drift (DEF-18-02) so that:

1. `mix sigra.install --yes` (default, Features.Organizations enabled) runs end-to-end without a template compile error.
2. `mix test test/sigra/install/` returns to a clean baseline — specifically, the six pre-existing failures surfaced by Phase 18 Plan 18-01 Task 3 are eliminated with no new regressions.
3. Phase 18 Plan 18-03 (install CI matrix `--yes` leg) is unblocked.

**Not in scope:** Any functional or visual change to the organizations LiveViews / invitation UI beyond what is required to make the existing templates compile and register correctly. No new features. No v1.2 work. No new migrations. The phase is a repair phase, not a redesign.
</domain>

<decisions>
## Implementation Decisions

### D-01: `invitation_accept_live.ex` render/1 refactor (DEF-18-01 Failure 1)

**Locked:** Refactor `render/1` to do an **Elixir-side `case assigns.branch`** that returns a per-branch `~H` sigil. Remove the `<%= case @branch do %>` construct entirely from inside the `~H"""` heredoc.

**Why:** The current code uses `<%= case @branch do %>` **inside** a `~H` heredoc. EEx (the generator-side template engine) evaluates the heredoc contents first and sees `@branch`, which it expands to `Kernel.var!(assigns).branch`. `assigns` is not in the generator binding, so the template fails to compile at generator-render time (`CompileError: undefined variable "assigns"`). Phase 16/17 core HEEx templates use `{...}` curly-brace HEEx interpolation **exclusively** and avoid `<%= %>` inside `~H` — `invitation_accept_live.ex` is the sole outlier. Pulling the case into plain Elixir and dispatching to per-branch helpers (or a small inline `case` returning a sigil per branch) matches the rest of the codebase and permanently eliminates the EEx/HEEx ambiguity. It is strictly cleaner than the `<%%= ... %%>` escape (which works but leaves an understood-only-by-readers-who-know-EEx pattern in a generated LiveView).

**Shape:**
```elixir
def render(assigns) do
  case assigns.branch do
    :signup -> render_signup(assigns)
    :accept -> render_accept(assigns)
    :mismatch -> render_mismatch(assigns)
    :invalid -> render_invalid(assigns)
    :expired -> render_expired(assigns)
    :revoked -> render_revoked(assigns)
    :already_accepted -> render_already_accepted(assigns)
  end
end
```
Each `render_<branch>/1` already exists and returns a `~H` sigil — no new helpers needed. The top-level `<div id="invitation-accept-page">` + flashes wrapper must be preserved — either lift it into each branch's sigil or wrap the `case` result in a parent `~H` that interpolates `{render_branch(assigns)}` via a thin dispatcher. Planner picks concrete shape.

### D-02: DEF-18-01 Failures 2 & 3 (missing templates) — verify-only, no creation

**Locked:** Verify and drop from scope. `priv/templates/sigra.install/organizations/router_injection.ex` and `priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex` **already exist on disk** as of commit `1e918cb feat(16-02): populate Features.Organizations manifest + router scope + on_mount + thin wrapper delegates`.

**Why:** DEF-18-01 was written after Plan 18-01 Task 3 hit the first failure and did not verify Failures 2 & 3 against the live tree. A simple `ls priv/templates/sigra.install/organizations/` confirms both files are present. Planner should add a single verification step (grep for `File.exists?` or `read_template!("organizations/router_injection.ex")`) that proves the `read_template!` call in `Sigra.Install.Features.Organizations.router_injection/1` succeeds — no creation work, no plan task for it.

### D-03: Plan shape — single repair plan

**Locked:** One plan: `24-01-repair-phase-16-17-org-templates-PLAN.md`. All of DEF-18-01 and DEF-18-02 fold into the same plan.

**Why:** The failures are interrelated — the GoldenDiffTest suite cannot be regenerated until the `invitation_accept_live.ex` compile error is gone, so DEF-18-02's fixture rebless is gated on D-01 anyway. Splitting into 24-01/24-02 would create a forced dependency with no independent shipping value. Single plan → atomic commit chain, one verification pass, fast execution. The plan itself should have clearly numbered tasks so commits remain granular.

### D-04: DEF-18-02 emails.ex + organization_invitation_email.ex resolution

**Locked:**
1. Register `priv/templates/sigra.install/core/organization_invitation_email.ex` (the dedicated "fragment" file currently sitting under `core/` but unreferenced) under `Features.Organizations` — **not** under `Features.Core`. Its canonical home is Organizations; it was accidentally dropped into `core/` during Phase 17.
2. Move the file from `core/` to `organizations/` on disk so the subdir layout matches its feature ownership (consistent with Phase 11 CD-01: subdir mirrors feature).
3. Keep the inline `OrganizationInvitation` copy in `core/emails.ex` **intact**. The comment in that file explicitly declares it a canonical inline copy synced to the fragment. The planner must add a sync/conditional-generation strategy so that:
   - On `--no-organizations` install, `core/emails.ex` omits the `organization_invitation/4` function (conditional EEx block, keyed on the `organizations?` binding flag).
   - On the default install, `core/emails.ex` renders the function as today.
4. Update `Features.Core.files/1` so core drops `organization_invitation_email.ex` from its manifest, and `Features.Organizations.files/1` picks it up.
5. Update `Sigra.Install.IsolationTest` "contains exactly 47 templates" to the new correct core count (whatever `core/` ships after the move — planner recounts).

**Why:** The `organization_invitation_email.ex` fragment is clearly Organizations-owned (the comment in `core/emails.ex:1-3` names it the documentation reference for the inline copy). Moving it under `organizations/` and registering it there resolves:
- DEF-18-02 Failure 1 (template count 47 → 48): count becomes correct.
- DEF-18-02 Failure 2 (`emails.ex` references `OrganizationInvitation`): conditional generation makes the `--no-organizations` leg clean.
- DEF-18-02 Failure 3 (TemplatesLayoutTest subtree drift): file is now in the correct subtree.
- DEF-18-02 Failure 4 (Features.CoreTest coverage mismatch): `Features.Core.files/1` no longer claims a file it shouldn't own.

The inline duplication stays because the comment documents it as intentional: the `core/emails.ex` function is the runtime implementation, and `organization_invitation_email.ex` is a doc/reference fragment for users who want to see the function in isolation. Rather than re-architecting into an injection, the conditional-generation approach keeps the existing structure while making it work under both install legs.

### D-05: Golden fixture regeneration strategy

**Locked:** After D-01 + D-04 land, regenerate the golden fixture by running the generator against the fixture app, diffing the output, and blessing the new state. The diff must be reviewed in the planner's self-verification step — the expected diff shape is:
- New file(s) under `organizations/` reflecting the moved `organization_invitation_email.ex`.
- Updated `lib/.../auth/emails.ex` rendering under the default leg (and a second fixture for the `--no-organizations` leg if one exists).
- Updated byte counts + STDOUT.txt reflecting the new file list.

No blanket "rebless without reading." Planner must call out in the task's acceptance criteria that the diff was visually inspected and matches the expected shape.

**Why:** Golden fixtures are the last line of defense against silent generator drift. A blind rebless would defeat the point.

### D-06: Regression test suite to land with this phase

All four of the following are **locked** and must be added or unblocked as part of the plan:

1. **Generator-render unit test for every `organizations/**/*.ex` template.** Walk the template tree, for each `.ex` template call `EEx.eval_file/2` with a minimal fixture binding (`web_module: Fixtures.Web, app_name: "fixture_app", organizations?: true`, etc.), assert the returned string compiles via `Code.string_to_quoted/1` (or `Code.compile_string/1` in a `:try` block with rescued exceptions). Fast unit signal — catches the invitation_accept_live bug class without paying the full install-fixture cost. Add as `test/sigra/install/template_render_test.exs` (or similar — planner names it).

2. **Features.Core / Features.Organizations file-coverage lint.** For each `feat` in `[Features.Core, Features.Organizations]`, assert that every file under `priv/templates/sigra.install/<feat_subdir>/` (recursively, excluding migrations) is referenced by `feat.files/1` OR `feat.migrations/1`. Prevents future template-count drift. Add under the existing `Sigra.Install.Features.CoreTest` (or a new `Features.CoverageTest` that tests every registered feature).

3. **HEEx-inside-EEx guard.** Narrow grep/lint test: walk `priv/templates/sigra.install/**/*.ex`, for each file find any `~H"""` heredoc and assert its body contains no `<%=` or `<%` tags (they must be escaped as `<%%=` / `<%%` or lifted to Elixir-side code). Add under `Sigra.Install.IsolationTest` (or a new `TemplateSyntaxTest`). This is the narrowest guard for the exact DEF-18-01 bug — cheap to run, high signal.

4. **Unblock the `mix sigra.install --yes` CI matrix leg.** Phase 18 Plan 18-03 defined a CI matrix leg that runs `mix sigra.install --yes` (default org-enabled) against a scratch app; that leg was blocked on DEF-18-01. After D-01 + D-04 + the tests above, the leg can be un-skipped / added to `.github/workflows/ci.yml`. If the matrix leg is not yet scaffolded in ci.yml, Phase 24 adds it.

**Why:** Item (1) makes the bug class fast-detectable, (2) prevents the drift class that caused DEF-18-02, (3) prevents the exact syntax collision that caused DEF-18-01 Failure 1, and (4) closes the CI gap that allowed these bugs to ship undetected through Phase 16/17. All four together convert this repair phase into a durable fix rather than a point patch.

### Claude's Discretion

- **Concrete file naming** for the new test modules — planner picks paths under `test/sigra/install/` consistent with existing conventions.
- **Fixture binding shape** for the generator-render unit test — planner picks minimal binding that satisfies every template.
- **Conditional-generation mechanism** for the `organization_invitation/4` function in `core/emails.ex` — EEx `<% if @organizations? do %>` block vs. a compile-time helper vs. a post-process removal. Planner picks whichever keeps the template readable and matches Phase 11 CD-01 conventions.
- **Whether to lift the `invitation_accept_live` wrapper `<div>` + flashes** into each branch's sigil or into a thin dispatcher wrapper. Either is acceptable as long as rendered output is unchanged from the current design.
- **Exact fixture app paths** for golden regeneration.
- **Acceptance thresholds** for the per-feature coverage lint — whether the test diffs the registered set against disk or asserts-each-file.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Deferred-items origin (authoritative statement of the bugs)
- `.planning/phases/18-backfill-organizations-generator-wiring/deferred-items.md` — DEF-18-01 and DEF-18-02 definitions + recommended resolution shape.
- `.planning/phases/18-backfill-organizations-generator-wiring/18-01-foundation-schema-and-flag-SUMMARY.md` — discovery context (Plan 18-01 Task 3) + why Plan 18-01 punted.
- `.planning/phases/18-backfill-organizations-generator-wiring/18-02-upgrade-task-and-backfill-SUMMARY.md` — confirms DEF-18-01/02 block full `mix test` and names the 5 pre-existing failures.

### Phase 11 feature-manifest architecture (the system these templates plug into)
- `.planning/phases/11-generator-feature-system/11-CONTEXT.md` — D-01 (Feature behaviour contract), D-02 (Injection struct shape), CD-01 (subdir override path semantics), D-06/D-07 (Report contract).
- `lib/sigra/install/features/core.ex` — `files/1`, `migrations/1`, `injections/1` for the Core feature.
- `lib/sigra/install/features/organizations.ex` — `files/1`, `injections/1` for the Organizations feature, including the `router_injection/1` and `user_auth_on_mount_injection/2` callsites that read templates via `read_template!/1`.

### Phase 16/17 template source + conventions
- `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md` — org LiveView decisions.
- `.planning/phases/17-invitation-flow-email/17-CONTEXT.md` — invitation flow decisions + email fragment provenance.
- `priv/templates/sigra.install/core/emails.ex` — inline canonical copy of `organization_invitation/4` with sync comment at top of file.
- `priv/templates/sigra.install/core/organization_invitation_email.ex` — the dedicated fragment file to be moved under `organizations/`.
- `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` — the file with the EEx/HEEx collision at line 235.
- Core HEEx templates using the `{...}` curly-brace convention (reference exemplars for D-01): `priv/templates/sigra.install/core/live/*.ex`.

### Install-test suite (the tests that must return to baseline)
- `test/sigra/install/isolation_test.exs` — "contains exactly 47 templates", forbidden future-feature references, emails.ex reference check.
- `test/sigra/install/templates_layout_test.exs` — subtree layout enforcement.
- `test/sigra/install/features/core_test.exs` — template-coverage invariant for Features.Core.
- `test/sigra/install/golden_diff_test.exs` — byte-for-byte fixture + STDOUT diff.
- `test/sigra/install/idempotency_test.exs` — second-run idempotency (currently blocked on setup_all by the compile error).
- `test/support/install_fixture.ex` — `setup_tmp_app/1` harness used by GoldenDiff + Idempotency.

### Phase 18 downstream consumers
- `.planning/phases/18-backfill-organizations-generator-wiring/18-03-*PLAN.md` (if present) — the CI matrix leg that this phase unblocks.
- `.github/workflows/ci.yml` — CI config to audit for existing `mix sigra.install --yes` matrix leg and amend or add it.

### Project-level
- `CLAUDE.md` — stack, OWASP/security constraints, Phoenix 1.8+ target.
- `.planning/PROJECT.md` — hybrid lib+generator architecture statement.
- `.planning/STATE.md` — line 60: "Phase 24 added — addresses DEF-18-01 and DEF-18-02".

</canonical_refs>

<specifics>
## Specific Ideas

- **Phase 16/17 convention (carry forward):** core HEEx templates use `{...}` curly-brace interpolation exclusively. Any new or refactored HEEx in Phase 24 must follow the same convention. The HEEx-inside-EEx guard test (D-06 item 3) enforces this going forward.
- **Phase 11 CD-01 (carry forward):** subdir location mirrors feature ownership, with no flat-legacy fallback. Moving `organization_invitation_email.ex` from `core/` to `organizations/` is mandated by this rule, not optional aesthetic.
- **EEx vs HEEx evaluation order (reference for planner and researcher):** at generator time, `mix sigra.install` calls `EEx.eval_file/2` on the template. EEx sees the raw file content including the `~H"""..."""` heredoc. Anything the generator wants to interpolate at install time must be regular EEx tags (`<%= web_module %>`). Anything that must survive to runtime HEEx compilation must either (a) use `{...}` curly-brace HEEx interpolation (EEx passes those through untouched because they are not EEx syntax) or (b) be escaped as `<%%= ... %%>`.
- **The `organizations?` binding flag** (or equivalent — planner confirms exact name in `lib/mix/tasks/sigra.install.ex` binding construction) is the conditional-generation key for D-04 item 3.
- **Features.Core.files/1 current list** — planner reads this to build the expected diff for golden regen.

</specifics>

<deferred>
## Deferred Ideas

- **Re-architecting `core/emails.ex` into feature-injected blocks.** Considered in the discuss-phase as an option for DEF-18-02 but deferred — too large for a repair phase. Conditional EEx (`<% if @organizations? do %>`) is the minimum-viable fix.
- **Merging DEF-18-01 and DEF-18-02 into a single Plan 18-01b under Phase 18.** Originally recommended in `deferred-items.md` but superseded by the decision to create Phase 24 as a distinct repair phase (per STATE.md line 60).
- **Any redesign of the invitation_accept_live 7-branch UX.** Out of scope — repair only.
- **Enforcement of template render tests for `core/` templates** in addition to `organizations/`. The D-06 item 1 test is scoped to `organizations/` to keep the phase tight; extending it to `core/` is a follow-up if the pattern proves its worth.
- **Promoting the HEEx-inside-EEx guard into a credo check.** Considered a nicer implementation than a grep test; deferred because adding a custom credo check is its own project.

</deferred>

---

*Phase: 24-repair-phase-16-17-organizations-generator-templates*
*Context gathered: 2026-04-14 via /gsd-discuss-phase*
