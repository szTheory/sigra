# Phase 31: Automation-First Verification - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 31 proves the v1.2 admin milestone through automation and reviewer-facing
artifacts. The phase must cover critical admin workflows in browser automation,
must retain inspectable CI artifacts, and must prove authorization, scope,
impersonation, and export rules outside the browser happy path.

The phase is intentionally verification architecture, not new admin feature
scope. It should convert the milestone's remaining human-only review burden into
automation and retained evidence that reviewers can inspect asynchronously.

</domain>

<decisions>
## Implementation Decisions

### Browser coverage boundary
- **D-01:** Browser verification uses a layered contract model, not a giant
  end-to-end matrix. Playwright should prove a small set of canonical operator
  journeys where real browser semantics matter, while ExUnit and Phoenix test
  helpers continue to own most correctness and failure-path coverage.
- **D-02:** The example app is the primary browser test bed for deep admin flow
  coverage. It already provides the richest deterministic fixtures and should
  remain the place where Sigra proves user-operations, impersonation, and audit
  journeys end to end in a browser.
- **D-03:** Generated-host browser coverage is intentionally shallow and parity-
  focused. It should prove installer/template/runtime parity for the shipped
  seams, not duplicate the example app's full browser journey suite.
- **D-04:** The canonical browser contract set for Phase 31 is:
  1) user search/filter -> open user -> revoke session -> scope remains visible;
  2) global detail -> organization-scoped pivot -> organization scope remains
  explicit; 3) stale sudo redirect, then fresh sudo -> start impersonation ->
  persistent banner on a non-admin page -> stop -> return to admin context;
  4) audit filtering -> impersonation semantics visible -> CSV export ->
  scoped per-user/org path keeps filter semantics aligned.
- **D-05:** Generated-host browser smoke should cover: shell render on desktop
  and mobile, visible scope labels, admin navigation presence, allowed
  organization access, denied global admin response, and not-found out-of-scope
  organization response. Keep generated-host flows narrow and deterministic.
- **D-06:** Do not move broad negative-case matrices into Playwright. Denied
  impersonation attempts, blocked sensitive mutations, malformed params,
  scope-safe export rules, audit attribution, and authorization permutations
  should remain primarily outside the browser.

### Non-browser verification boundary
- **D-07:** Correctness for security-sensitive library behavior stays
  ExUnit-owned. Authorization, scope narrowing, impersonation state
  transitions, timeout handling, audit attribution, and export filtering rules
  should be asserted primarily in in-process tests under `test/sigra/**/*.exs`
  and the example app's controller/LiveView tests.
- **D-08:** Booted-app smoke is intentionally thin and targeted. Use shell/curl
  or similar process-external requests only for wiring/runtime seams that
  in-process ExUnit cannot prove: server boot, route availability, session/cookie
  continuity across real HTTP, generated-host installation/runtime wiring, and
  a few admin-critical denial/success responses.
- **D-09:** Phase 31 adopts a layered model:
  ExUnit owns correctness, targeted booted-app smoke owns runtime/wiring
  confidence, and browser coverage owns operator UX. Do not let shell smoke
  become a second full functional suite.
- **D-10:** Generated-host parity must remain explicit. For admin verification,
  Sigra should verify both the example app and a freshly generated host app:
  the example app remains the rich deterministic test bed, while generated-host
  smoke proves installer/template parity for the shipped seams.
- **D-11:** Generated-host smoke should stay narrow. It should cover install,
  compile, boot, deterministic admin policy/data seeding, and a minimal set of
  admin route checks or focused acceptance flows. It should not duplicate the
  example app's broad ExUnit matrix.
- **D-12:** Non-browser verification should fail on policy and contract
  regressions, not on presentation details. Assertions belong on HTTP status,
  redirect target, audit side effects, CSV schema/filtering, and scope denial
  semantics rather than page copy or layout.
- **D-13:** Direct-path coverage must include negative cases, not only happy
  paths. Explicitly keep denied/out-of-scope/impersonation-blocked/export-scope
  scenarios in ExUnit and targeted HTTP smoke so Phase 31 does not create false
  confidence from browser-only success flows.

### What belongs where
- **D-14:** `test/sigra/**/*.exs` owns library contracts: admin authorizer
  decisions, impersonation start/stop/timeout semantics, dual-actor audit field
  assembly, export query normalization, scope-safe query behavior, and
  impersonation-forbidden mutation guards.
- **D-15:** `test/example/test/**/*_test.exs` owns example host integration:
  controller and LiveView route behavior, redirects, scoped resource loading,
  CSV response shape, return-to handling, and browserless end-to-end flows that
  can run through `Phoenix.ConnTest` and `Phoenix.LiveViewTest`.
- **D-16:** `scripts/ci/*.sh` smoke owns process-external checks only:
  fresh-install compile/migrate, generated-host boot, example-host boot, and a
  few real HTTP requests that prove runtime wiring for admin-critical routes.
- **D-17:** Generated-host smoke must cover the seams Sigra actually ships:
  installer output, generated policy/layout/router/template wiring, and at
  least one deterministic admin journey proving the generated app is not merely
  compilable but operable.
- **D-18:** Do not add shell/curl coverage for detailed LiveView interaction
  flows, complex filtering matrices, pagination behavior, or broad authorization
  permutations already better covered in ExUnit. Those belong in ExUnit or
  Playwright, not bash.

### Artifact policy
- **D-19:** Dedicated admin verification Playwright jobs must upload reviewer-
  usable artifacts on every run, not only on failure. Phase 31 should make
  green runs reviewable, not just debuggable.
- **D-20:** Passing runs retain a lightweight artifact set:
  Playwright HTML report plus explicit curated screenshots for the selected
  desktop/mobile/dark admin checkpoints. Do not retain full trace or full video
  bundles for every passing run.
- **D-21:** Failing runs retain the richer diagnostic bundle:
  Playwright HTML report plus `test-results/` with retained traces, failure
  screenshots, and retained videos where enabled.
- **D-22:** Artifact publication should stay scoped to the dedicated admin
  verification jobs for the example app and generated host. Do not widen this
  policy to every unrelated browser or smoke job in the repository.
- **D-23:** Retention stays intentionally short-lived:
  7 days for PR/push verification artifacts and 14 days for main/nightly/release
  admin verification artifacts.
- **D-24:** Keep `trace: 'on-first-retry'`. Add `screenshot: 'only-on-failure'`
  globally for failure evidence, and use retained video sparingly, ideally on
  failure-oriented admin verification jobs rather than blanket always-on video.
- **D-25:** Reviewer-facing visual checkpoints on passing runs should come from
  explicit test-authored screenshots, not from retaining whole-run raw
  Playwright output directories indiscriminately.

### Mobile and dark-mode gate shape
- **D-26:** Mobile and dark mode are gated through a dedicated checkpoint layer,
  not by rerunning the entire functional suite across every viewport/theme
  combination.
- **D-27:** Keep one main behavioral browser suite for workflow truth, then add
  a compact checkpoint spec that captures retained artifacts for selected admin
  pages in `chromium`, `mobile`, and `dark-chromium`.
- **D-28:** The required checkpoint pages are:
  global user index, user detail, organization-scoped admin page, active
  impersonation state on a non-admin or org-scoped page, and audit explorer.
  These pages collectively prove shell chrome, dense data layout, action
  visibility, scope context, banner persistence, and filter/export usability.
- **D-29:** Dark mode should be invoked primarily through a dedicated Playwright
  project using `colorScheme: 'dark'`. Do not make the artifact gate depend on
  a UI theme toggle interaction.
- **D-30:** Do not adopt a full visual-baseline regime for the admin milestone.
  Use targeted screenshots and assertions as reviewer artifacts, while keeping
  correctness gates grounded in Playwright behavior, ExUnit, and direct-path
  tests.

### the agent's Discretion
- Exact file/module names for any new Playwright checkpoint specs or CI jobs
- Exact split between controller tests and lower-level library tests, as long as
  policy correctness remains library-owned
- Exact screenshot filenames and artifact folder layout, provided the retained
  outputs stay predictable and scoped
- Exact script names and CI job partitioning for the targeted HTTP/admin smoke
- Whether the thin runtime smoke uses `curl` alone or a small Elixir/Req helper,
  provided it stays process-external and minimal

</decisions>

<specifics>
## Specific Ideas

- Follow the Phoenix/LiveDashboard pattern: keep long-lived admin runtime and
  security semantics library-owned, with host apps proving only the mounted
  seams they actually own.
- Keep browser coverage at the operator-journey level, not at the "every rule
  in a browser" level. Playwright should prove UX semantics and real browser
  integration, not replace Phoenix test helpers.
- Treat shell smoke as a canary for packaging/runtime seams, not as the main
  verification engine.
- Keep the richest negative-case matrix where Phoenix is strongest:
  `ConnTest`, `LiveViewTest`, and ordinary ExUnit.
- Generated-host parity should be proven by deterministic setup, not by hoping
  that template/code parity implies runtime parity.
- Phase 30 already left a generated-app parity gap for audit routes/export; the
  Phase 31 model should absorb that kind of gap into automation instead of
  recurring human-only checks.
- Learn from Django admin, Auth0/Clerk/Okta-style admin UX, and Better Auth that
  a few canonical pages can carry most reviewer insight if they keep scope,
  action context, and special session state visible.
- Avoid the classic verification footguns for library-owned admin surfaces:
  broad browser duplication of server-side rules, blanket video retention,
  snapshot-everything visual baselines, and generated-host suites that grow so
  broad they become harder to trust than the example app.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and verification requirements
- `.planning/ROADMAP.md` — Phase 31 goal and success criteria, especially the
  browser plus non-browser verification split
- `.planning/milestones/v1.2-REQUIREMENTS.md` — VFY-01 through VFY-04; VFY-03 is the primary (archived v1.2 requirements)
  requirement for the direct-path boundary and VFY-02/VFY-04 drive artifact and
  mobile/dark-mode decisions
- `.planning/PROJECT.md` — automation-first milestone stance and artifact-first
  review expectations
- `.planning/STATE.md` — current warning that Phase 31 must preserve
  automation-first intent beyond browser happy paths

### Prior verification context
- `.planning/phases/30-audit-exploration-and-export/30-VERIFICATION.md` — shows
  the existing generated-host runtime parity gap that Phase 31 should absorb
  into automation
- `.planning/phases/29-secure-impersonation/29-CONTEXT.md` — security-sensitive
  impersonation contracts whose correctness should remain library-owned
- `.planning/phases/27-admin-access-foundation/27-CONTEXT.md` — admin scope and
  policy seams that direct-path tests must continue to prove

### Existing harnesses and code paths
- `.github/workflows/ci.yml` — current job layout already separating library
  tests, example smoke, install smoke, and generated-host acceptance smoke
- `test/example/priv/playwright/playwright.config.ts` — current Playwright
  projects, reporter, and trace policy that Phase 31 should extend rather than
  replace
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts` — existing
  user-operations browser contract that should become part of the canonical
  Phase 31 suite
- `test/example/priv/playwright/tests/impersonation.spec.ts` — existing
  impersonation browser contract and banner/state journey
- `test/example/priv/playwright/tests/admin-audit.spec.ts` — existing audit
  browser contract and export flow
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — existing
  generated-host parity smoke for shell and denial behavior
- `scripts/ci/http-smoke.sh` — current thin example-host route smoke
- `scripts/ci/install-smoke.sh` — fresh-install compile/migrate harness
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host acceptance setup and
  deterministic seeding pattern
- `test/sigra/**/*.exs` — current library-owned correctness suite
- `test/example/test/**/*.exs` — current example-app controller/LiveView/smoke
  coverage

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/example/priv/playwright/playwright.config.ts` already supplies HTML
  reports, retry traces, and separate `mobile` and `chromium` projects. Phase
  31 can add artifact and dark-mode behavior additively instead of replacing
  the Playwright harness.
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts`,
  `impersonation.spec.ts`, `admin-audit.spec.ts`, and `admin-generated.spec.ts`
  already define most of the canonical browser journeys Phase 31 should formalize.
- `test/sigra/impersonation_test.exs` already demonstrates the right ownership
  boundary for security-critical impersonation rules at the library layer.
- `test/example/test/example_web/controllers/admin/audit_export_controller_test.exs`
  already proves that controller tests are a strong home for CSV contract and
  scoped export semantics.
- `scripts/ci/install-smoke.sh` already proves compile/migrate viability for a
  fresh generated app.
- `scripts/ci/admin-acceptance-smoke.sh` already provides the deterministic
  generated-host scaffold + seed + boot pattern Phase 31 can extend.
- `scripts/ci/http-smoke.sh` already embodies the desired thin-smoke philosophy:
  small route list, real HTTP, fail on runtime breakage.

### Established Patterns
- The repo already separates library tests from example-app tests and from
  process-external smoke in CI.
- Security-sensitive behavior is intentionally library-owned; host apps provide
  narrow policy/layout seams.
- Generated-host verification is already treated as first-class through install
  and acceptance smoke rather than as documentation-only confidence.
- Existing Playwright use is already focused on narrow admin/browser contracts,
  not exhaustive full-surface UI automation.
- The current CI artifact posture is failure-oriented; Phase 31 should evolve it
  into reviewer-oriented admin verification artifacts without widening it repo-wide.

### Integration Points
- Promote the existing admin Playwright specs into an explicit Phase 31 browser
  contract suite and add only the missing checkpoint coverage.
- Extend `test/sigra` for policy and rule matrices that must remain stable
  across hosts.
- Extend example controller/LiveView tests for admin direct-path behavior where
  Phoenix test helpers are sufficient.
- Add or expand one targeted booted-app smoke layer for real HTTP/runtime
  confidence on admin routes.
- Reuse generated-host smoke harness for admin parity rather than inventing a
  second scaffold path.
- Extend Playwright projects and CI upload rules additively for `dark-chromium`
  checkpoints and pass/fail artifact retention.

</code_context>

<deferred>
## Deferred Ideas

- Full visual-regression snapshot baselines across the entire admin surface
- Always-on video retention for every browser run
- Broad shell/curl duplication of behaviors already proven in ExUnit or
  Playwright

</deferred>

---

*Phase: 31-automation-first-verification*
*Context gathered: 2026-04-16*
