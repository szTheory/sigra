# Phase 18 — Deferred Items

Items discovered during Plan 18-01 execution that are out of scope for
Plan 18-01 but must be addressed before the `--no-organizations` CI
matrix leg (Plan 18-03) can be green.

## DEF-18-01: Pre-existing Phase 16/17 organizations template compile errors (exposed by Plan 18-01 Task 3)

**Severity:** Blocker for Plan 18-03 (install CI matrix cannot run `mix sigra.install --yes` end-to-end until these are fixed). Non-blocker for Plan 18-02 (upgrade-task wave works at the library layer).

**Discovered:** During Plan 18-01 Task 3 verification, after wiring `Sigra.Install.Features.Organizations` into `@features`. Prior to Phase 18, these templates were never rendered by any install test because the feature was not registered; Phase 16/17 shipped these templates but only exercised them via the example-app commit path, not via `mix sigra.install`. Plan 18-01 Task 3 is the first time the generator pipeline evaluates them.

### Failure 1 — `invitation_accept_live.ex` EEx/HEEx confusion

**File:** `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` (line 235)

**Error:**
```
error: undefined variable "assigns"
     |
 235 |       <%= case @branch do %>
(CompileError) cannot compile file
expanding macro: Kernel.var!/1
```

**Root cause:** The template uses `<%= case @branch do %>` inside a `~H""" """` heredoc. Generator EEx evaluation (not runtime HEEx compilation) parses `<%= %>` tags first; it sees `@branch`, expands it to `Kernel.var!(assigns).branch`, and fails because `assigns` is not in the generator binding. Core HEEx templates in `priv/templates/sigra.install/core/*.ex` avoid this by using `{...}` curly-brace HEEx interpolation exclusively; this file is the only one mixing the two styles.

**Fix shape (for follow-up plan):** Either escape the EEx tags (`<%%= case @branch do %%>`) so EEx passes them through verbatim for HEEx to interpret at runtime, OR refactor `render/1` to do Elixir-side `case` with per-branch `~H` sigils.

**Tried during Plan 18-01 execution, reverted:** The `<%%= ... %%>` escape works (verified fixes that specific compile error) but exposes the next cascade failure below. Reverted to keep Plan 18-01 scope tight.

### Failure 2 — Missing `router_injection.ex` template

**File referenced:** `priv/templates/sigra.install/organizations/router_injection.ex` — does NOT exist on disk

**Error:**
```
** (File.Error) could not read file
   "priv/templates/sigra.install/organizations/router_injection.ex":
   no such file or directory
```

**Callsite:** `Sigra.Install.Features.Organizations.router_injection/1` at line 156 reads this file via `read_template!/1`.

**Root cause:** `Sigra.Install.Features.Organizations.injections/1` at line 105 calls `router_injection/1` which calls `read_template!("organizations/router_injection.ex")` — but the template file was never created during Phase 16/17. This is a real bug in the Phase 16 Plan 02 feature manifest implementation that went undetected because no install test ever ran the Organizations feature.

### Failure 3 — (likely) `user_auth_on_mount_assign_user_organizations.ex` also missing

Same pattern as Failure 2. `Sigra.Install.Features.Organizations.user_auth_on_mount_injection/2` at line 167 reads `organizations/user_auth_on_mount_assign_user_organizations.ex` which is probably also missing (not verified yet; Plan 18-01 stopped at Failure 2 to respect scope boundary).

### Consequence for Plan 18-01 acceptance

Plan 18-01 Task 3's acceptance criterion `mix test test/sigra/install/` passing IS violated — but the failures are the above pre-existing bugs newly exposed, NOT regressions my changes introduced. The bugs were always present; they were dormant because the feature was never wired. Plan 18-01's own grep-based acceptance criteria (file edits, compile, unit tests) all pass.

### Recommended resolution

Add a Plan 18-01b (or Plan 18-03 prerequisite) titled **"Phase 16/17 generator template repair"** with three tasks:

1. Fix `invitation_accept_live.ex` EEx/HEEx escape OR Elixir-side case refactor. Add a render test.
2. Create the missing `organizations/router_injection.ex` template with the Phase 16 Plan 02 router scope block content.
3. Create the missing `organizations/user_auth_on_mount_assign_user_organizations.ex` template with the `on_mount :assign_user_organizations` hook content. (Verify existence first.)

Acceptance for that plan: `mix test test/sigra/install/` regains its baseline failure count (5 pre-existing, 0 new) after running with `Features.Organizations` registered. Specifically, `Sigra.Install.IdempotencyTest` and `Sigra.Install.GoldenDiffTest` must reach their setup-all callbacks without blowing up in template rendering. Golden fixture will need regenerating to reflect the new file set.

---

## DEF-18-02: Pre-existing golden fixture and template-count drift (unrelated to Plan 18-01)

**Severity:** Blocker for Plan 18-03 CI matrix. Also fails on the base commit `805eaffe5e841a66cabba2e255eb4292fbb5c341` — Plan 18-01 did not introduce this.

**Failing tests on base commit (before any Plan 18-01 changes):**
1. `Sigra.Install.IsolationTest` — "contains exactly 47 templates" — core/ has 48 files (drift from Phase 17).
2. `Sigra.Install.IsolationTest` — `emails.ex` references `OrganizationInvitation` (Phase 17 regression, not caught before).
3. `Sigra.Install.TemplatesLayoutTest` — "templates relocated under core/ subdirectory" — one or more files are in the wrong subtree.
4. `Sigra.Install.Features.CoreTest` — template coverage mismatch — `organization_invitation_email.ex` is on disk under `core/` but not referenced by `Features.Core.files/1`/`migrations/1`.
5. `Sigra.Install.GoldenDiffTest` — golden fixture drift (1 of 2 GoldenDiffTest tests; the other is DEF-18-01 induced).

Recommended resolution: Fold into the same follow-up plan as DEF-18-01. All five failures are related (they all spring from Phase 17 shipping templates that never got registered in Features.Core).
