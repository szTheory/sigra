# Phase 23: Docs, CI Smoke, Upgrade Guide - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 23 closes the v1.1 developer-experience surface after organizations and passkeys are already functionally shipped.

The deliverable is four-part:
- extend the docs set so a new developer can install, configure, and understand organizations + passkeys quickly
- add a tested upgrade guide for v1.0 -> v1.1
- extend generated and library testing helpers for the new org/passkey surface
- expand CI/browser smoke so org and passkey flows regress in PRs instead of in manual QA

This phase does not redesign organizations or passkey behavior. It documents, exercises, and smooths the surface that prior phases already introduced.

</domain>

<decisions>
## Implementation Decisions

### Documentation shape

- **D-01:** Keep the existing HexDocs taxonomy instead of inventing a new one for Phase 23.

  The repo already groups extras under `guides/introduction/`, `guides/flows/`, and `guides/recipes/` in `mix.exs`. Phase 23 should fit into that structure:
  - `guides/introduction/getting-started.md` gets the new organizations + passkeys walkthrough section
  - `guides/introduction/upgrading-to-v1.1.md` is the upgrade guide
  - roadmap "how-to" guides land under `guides/recipes/` to match the existing sidebar grouping rather than creating a parallel `guides/how-to/` tree

- **D-02:** `getting-started.md` remains a fast happy-path guide, not a full reference dump.

  The current guide is explicitly budgeted for under 30 minutes. Extend it with one coherent "Organizations & Passkeys" continuation after the baseline auth flow instead of rewriting the whole page into a kitchen-sink reference. Keep the narrative runnable against generated scaffolding and preserve the current "do this, see that" structure.

- **D-03:** The new docs must describe the default-on product posture explicitly.

  Organizations and passkeys are the default install path. Docs should treat `mix sigra.install` as the mainline and mention `--no-organizations` / `--no-passkeys` as opt-outs where relevant, not as the primary story.

### Upgrade guide posture

- **D-04:** The v1.0 -> v1.1 guide is operational, not promotional.

  It must cover:
  - prerequisite backup / branch expectations
  - both organization backfill paths
  - passkeys as new generated surface
  - exact upgrade command/test sequence
  - known no-breaking-schema assumptions only if verified in code/tests

  The guide should read like something an engineer can execute in a terminal, not marketing copy.

- **D-05:** Upgrade docs and upgrade automation stay aligned with the actual tested path.

  If the docs prescribe commands, those commands should be exercised by the existing upgrade tests or by a new focused automation path added in this phase. Do not document a "recommended" sequence that the repo never executes.

### Testing helpers

- **D-06:** Extend the generated fixture surface in the existing generated fixtures module pattern rather than fragmenting the API unnecessarily.

  The generated host app already has `auth_fixtures.ex` and imports it broadly. Phase 23 should add the org/passkey helpers there unless a second file is clearly required for readability. The important contract is the helper names and ergonomics, not multiplying files.

- **D-07:** Library-side assertions belong in `Sigra.Testing` and follow the existing narrow-helper style.

  `assert_scope_has_org/2`, `assert_membership/3`, and `assert_audit_logged_for_org/2` should be small, purpose-built assertions consistent with the existing `assert_*` helpers rather than a generic assertion DSL.

- **D-08:** The new helpers are unit/integration accelerators, not substitutes for real route coverage.

  Keep the same line the repo already uses:
  - helpers make tests shorter
  - real auth/organization/passkey gates still need route-backed tests
  - helper docs must say when they bypass real controller/LiveView/session behavior

### Browser and CI smoke

- **D-09:** Reuse the existing example-app Playwright harness and extend it with focused specs instead of building a second E2E framework.

  The canonical browser surface already lives under `test/example/priv/playwright/` and is wired into `.github/workflows/ci.yml`. Phase 23 should extend that harness with org + passkey scenarios and keep the current real-server, real-route posture from the later Phase 21 fixes.

- **D-10:** Keep browser smoke focused on a few load-bearing user journeys.

  Required journeys:
  - organization switcher happy path
  - invitation accept for new-signup path
  - invitation accept for already-authenticated user path
  - passkey registration
  - passkey authentication

  Avoid turning Phase 23 into a giant matrix of browser permutations. The goal is strong regression signal on the main cross-feature workflows.

- **D-11:** Preserve the current split between install/compile smoke and browser smoke.

  The combinatorial install matrix added in earlier phases should stay separate from the browser coverage. Playwright remains the passkey-enabled/org-enabled happy-path guard, not a replacement for generator matrix automation.

### Docs quality gate

- **D-12:** `mix docs --warnings-as-errors` remains a hard gate and the source of truth for sidebar/extras wiring.

  If new guides are added, Phase 23 must update `mix.exs` extras/grouping in the same change so docs generation stays clean and the new pages are actually shipped.

### the agent's Discretion

- Exact section titles and local ordering inside each guide, provided the existing docs voice and structure stay intact.
- Whether the new Playwright coverage extends `organizations.spec.ts` / `passkey-login.spec.ts` or introduces additional focused spec files, provided the resulting suite stays readable.
- Whether generated fixture helpers live in one file or a very small number of files, provided the public helper names and imports stay straightforward.
- Exact assertion wording and helper argument shape inside `Sigra.Testing`, provided it matches the existing helper style.

</decisions>

<specifics>
## Specific Ideas

- Add an "Organizations & Passkeys" continuation to `getting-started.md` that starts from the already-running example app instead of sending the reader through a separate setup branch.
- Keep the multi-tenancy guide anchored on Sigra's logical-tenant model and explicitly explain why schema-per-tenant is rejected.
- The passkeys guide should include the RP ID / origin rename playbook and recovery expectations because those are the most operationally surprising parts for adopters.
- The upgrade guide should include the exact upgrade test invocation so the reader can mechanically validate their branch after running the upgrade.
- Keep Playwright close to real browser behavior: no route fulfillment shortcuts for options endpoints, no fake success responses when a real server response can be observed.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and milestone context
- `.planning/ROADMAP.md` — Phase 23 goal, success criteria, and dependency position after Phases 18 and 22
- `.planning/PROJECT.md` — v1.1 milestone framing, default-on organizations/passkeys product stance, and docs/DX philosophy
- `.planning/REQUIREMENTS.md` — `DX-01` through `DX-09`
- `.planning/STATE.md` — recent sequencing and prior-phase notes

### Prior phase decisions
- `.planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md` — upgrade/backfill and generator-combination posture
- `.planning/phases/21-passkey-liveviews-post-auth-controller/21-CONTEXT.md` — locked passkey UX/controller boundaries and browser smoke posture
- `.planning/phases/22-passkeys-generator-wiring/22-CONTEXT.md` — CI split between install matrix and passkey-enabled browser smoke
- `.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-01-SUMMARY.md` — current install-matrix repair state and scope boundaries

### Existing docs surface
- `guides/introduction/getting-started.md` — baseline happy-path guide to extend
- `guides/recipes/testing.md` — current testing-helper doc style
- `guides/recipes/multi-tenant.md` — existing tenant guidance that Phase 23 should update or supersede carefully
- `mix.exs` — HexDocs extras/groups configuration and docs warnings gate

### Existing code and tests
- `lib/sigra/testing.ex` — library-side helper API surface to extend
- `priv/templates/sigra.install/core/auth_fixtures.ex` — generated fixture pattern to extend
- `test/example/test/support/fixtures/auth_fixtures.ex` — concrete example-app fixture surface including current passkey helper stubs
- `test/example/priv/playwright/tests/organizations.spec.ts` — canonical organization browser smoke style
- `test/example/priv/playwright/tests/passkey-login.spec.ts` — canonical passkey browser smoke style
- `.github/workflows/ci.yml` — required CI jobs and current Playwright/docs gates

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/sigra/testing.ex`: already contains a broad `assert_*` helper surface and is the natural place for the new org-aware assertions.
- `priv/templates/sigra.install/core/auth_fixtures.ex`: generated fixtures already compose scenario helpers and session primitives; Phase 23 should extend this pattern instead of inventing a separate test helper architecture.
- `test/example/test/support/fixtures/auth_fixtures.ex`: demonstrates current passkey fixture/stub techniques that can guide the generated helper design.
- `test/example/priv/playwright/tests/organizations.spec.ts`: already covers real browser org flows, mailbox confirmation extraction, and LiveView readiness helpers.
- `test/example/priv/playwright/tests/passkey-login.spec.ts`: already uses the real options routes and virtual authenticator setup needed for passkey smoke.

### Established Patterns
- HexDocs grouping is explicit in `mix.exs`; new guides must be added to `extras` and match an existing group or a deliberately updated grouping rule.
- Browser smoke in this repo prefers real server responses over Playwright interception shortcuts.
- Generated fixtures are documented with clear caveats about what they bypass; follow that same honesty for org/passkey helpers.
- The repo prefers small, scenario-oriented helpers over generic abstractions.

### Integration Points
- Docs updates touch `guides/**` plus `mix.exs`.
- Generated helper work touches `priv/templates/sigra.install/core/auth_fixtures.ex` and the install/golden tests that lock generated output.
- Library helper work touches `lib/sigra/testing.ex` plus focused unit tests under `test/sigra/`.
- Browser smoke work touches `test/example/priv/playwright/**`, `test/example` support fixtures, and `.github/workflows/ci.yml`.

</code_context>

<deferred>
## Deferred Ideas

- Broader visual/doc UX review of the full HexDocs site beyond `mix docs --warnings-as-errors`
- Additional long-tail Playwright permutations for every org/passkey edge case
- Any redesign of the public docs taxonomy beyond the minimum needed to ship the new guides cleanly

</deferred>

---

*Phase: 23-docs-ci-smoke-upgrade-guide*
*Context gathered: 2026-04-16*
