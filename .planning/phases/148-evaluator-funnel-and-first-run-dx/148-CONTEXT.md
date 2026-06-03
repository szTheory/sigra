# Phase 148: Evaluator Funnel And First-Run DX - Context

**Gathered:** 2026-05-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn README, HexDocs, demo, and doctor guidance into one canonical first-10-minutes evaluator path for ADOPT-01 through ADOPT-04. This phase improves public routing, demo explanation, screenshot-grid presentation, and first-run troubleshooting/doctor guidance. It does not add new auth primitives, redesign generated-host UI, change seeded persona behavior, resurrect deferred demo affordances, or package Phase 149 launch announcement/evidence work.

</domain>

<decisions>
## Implementation Decisions

### Canonical First Path
- **D-01:** Make `guides/introduction/demo-showcase.md` the canonical evaluator-first path, then route README, Hex package text/metadata, ExDoc, `doc/llms.txt`, and `test/example/README.md` to that same path.
- **D-02:** The first path must be explicitly runnable in 10 minutes or less using existing demo commands, with README/HexDocs/test-example surfaces agreeing on the command sequence and destination.

### Demo Persona Map
- **D-03:** Use the existing six-persona data as the source of truth; improve explanation and routing, not persona shape or seeded behavior.
- **D-04:** The persona map must explain what each seeded account proves, including admin, happy-path, TOTP/MFA, OAuth-linked identity, locked/unconfirmed rough edge, scheduled-deletion lifecycle, passkey display, and multi-org states.

### Screenshot Grid And Proof Boundaries
- **D-05:** Reuse the four existing committed demo screenshots as the screenshot grid: credentials, admin user list, admin user detail, and audit explorer.
- **D-06:** Keep limitation language honest: screenshots and demo showcase are evaluator proof and inspection aids, not production certification or compliance evidence.

### Doctor / First-Run Verification
- **D-07:** Thread `mix sigra.doctor` into first-run guidance as the immediate post-install verification step.
- **D-08:** Show expected success and common failure output using the existing doctor task states and exit-code contract, especially optional-dependency wiring failures after install.

### Scope Boundary
- **D-09:** Keep this phase to docs, assets, routing, and proof alignment. Do not add new auth primitives, live OAuth credential setup, broad generated-host UI redesign, or the deferred in-app per-persona explainer banner.

### the agent's Discretion

Planning agents may choose the exact section order, headings, link text, and whether to add narrow doc-contract tests, provided the final funnel is visibly unified from README, HexDocs/ExDoc, package metadata, `doc/llms.txt`, and `test/example/README.md`.

### Folded Todos

None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope
- `.planning/ROADMAP.md` — Phase 148 goal and success criteria.
- `.planning/REQUIREMENTS.md` — ADOPT-01 through ADOPT-04 requirements and v1.32 out-of-scope table.
- `.planning/PROJECT.md` — release-adoption posture, north-star, and post-1.0 maintenance boundaries.
- `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md` — public contract, version-axis messaging, ownership boundaries, and non-goals.
- `.planning/phases/147-upgrade-and-migration-lanes/147-CONTEXT.md` — README/ExDoc/AI-index public routing precedent.

### Public Funnel Surfaces
- `README.md` — top-level evaluator/integration routing and first integration commands.
- `mix.exs` — package description, package files, and ExDoc extras list.
- `doc/llms.txt` — AI-consumption table of contents that must point to canonical install, migration, demo, and verification surfaces.
- `guides/introduction/demo-showcase.md` — existing showcase guide and the intended canonical evaluator path.
- `test/example/README.md` — runnable Vaultr demo setup, persona table, rough-edge notes, and dev-tool links.

### Demo Assets And Source Of Truth
- `test/example/lib/example/demo/personas.ex` — canonical six-persona data and `feature_map/0`.
- `test/example/lib/example_web/live/demo/credentials_live.ex` — `/demo/credentials` dev-only cheat-sheet.
- `test/example/priv/playwright/tests/demo-showcase.spec.ts` — isolated demo showcase browser proof and screenshot assertions.
- `guides/assets/demo-credentials-demo-showcase-chromium.png` — credentials screenshot.
- `guides/assets/admin-user-list-demo-showcase-chromium.png` — admin user list screenshot.
- `guides/assets/admin-user-detail-demo-showcase-chromium.png` — admin user detail screenshot.
- `guides/assets/audit-explorer-demo-showcase-chromium.png` — audit explorer screenshot.

### Doctor / Troubleshooting
- `lib/mix/tasks/sigra.doctor.ex` — human output format and exit-code contract.
- `lib/sigra/doctor.ex` — nine-feature diagnostic matrix and structured state definitions.
- `guides/introduction/troubleshooting-install.md` — install troubleshooting surface to extend.
- `guides/recipes/deployment.md` — existing operator diagnostics section and doctor feature-state wording.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Example.Demo.Personas` is the single source of truth for demo emails, passwords, display names, feature descriptions, and rough-edge flags.
- `ExampleWeb.Demo.CredentialsLive` already renders `/demo/credentials` with `data-testid` rows for all six personas and a dev-only badge.
- The committed `guides/assets/*demo-showcase-chromium.png` images are already ExDoc assets and match Playwright baselines.
- `Mix.Tasks.Sigra.Doctor` already formats success, available, missing, and misconfigured rows; docs should quote or paraphrase these states instead of inventing a second diagnostic vocabulary.

### Established Patterns
- README stays a map, not a deep spec; deeper detail belongs in guide pages linked from README.
- Public docs must preserve Phase 145's version-axis distinction and ownership/non-goal language.
- Demo proof language should mirror existing release evidence posture: evidence-backed, inspectable, and honest about non-certification.
- Optional dependencies remain host-owned shared seams; doctor guidance should explain configured-but-broken wiring without treating absent optional deps as errors.

### Integration Points
- README "Pick your lane" and "Reference host: `test/example`" sections should route evaluators into the canonical demo showcase path.
- `mix.exs` package description and docs extras already expose README and `demo-showcase.md`; planning should check whether package metadata needs clearer evaluator wording while staying within Hex package file constraints.
- `doc/llms.txt` should include the canonical demo/doctor first-run route so AI-consumption assets do not fragment the funnel.
- `test/example/README.md` should remain the runnable local app guide while linking back to the canonical showcase explanation and screenshot grid.
</code_context>

<specifics>
## Specific Ideas

- Preserve the existing `cd test/example && mix setup && mix phx.server` demo command as the runnable evaluator path.
- Make `/demo/credentials` the first live stop after the server starts.
- Keep the OAuth limitation explicit: Carol has a seeded GitHub identity row for inspection, while live GitHub OAuth requires the evaluator's own credentials.
- Show `mix sigra.doctor` after install as a first-run verification step, not only as deployment/operator diagnostics.
</specifics>

<deferred>
## Deferred Ideas

- DEMO-03, the in-app per-persona explainer banner, remains future scope.
- Phase 149 owns the launch announcement package, alternatives comparison, compact evidence bundle, and release-note audience guidance.
</deferred>

---

*Phase: 148-evaluator-funnel-and-first-run-dx*
*Context gathered: 2026-05-31*
