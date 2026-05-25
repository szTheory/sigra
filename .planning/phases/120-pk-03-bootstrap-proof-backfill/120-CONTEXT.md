# Phase 120: PK-03 Bootstrap Proof Backfill - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 120 does not redesign passkey UX, recovery posture, or the WebAuthn substrate. Phase 116 already implemented the `PK-03` behavior; Phase 120 exists to repair the missing proof and truth surfaces around that shipped work.

The fixed scope is:
- create the authoritative `PK-03` verification/validation artifacts for the shipped Phase 116 behavior
- prove the confirmation -> bootstrap banner -> enrollment path end to end on real served routes
- reconcile only the active truth surfaces that would otherwise misstate current `PK-03` status

This phase is not milestone-wide cleanup, not broad Nyquist archaeology, and not a reopening of product decisions already locked in Phase 116.

</domain>

<decisions>
## Implementation Decisions

### Authoritative proof surface
- **D-01:** `PK-03` proof authority belongs to **Phase 116**, not Phase 120.
- **D-02:** Phase 120 should create `.planning/phases/116-recovery-first-passkey-bootstrap/116-VERIFICATION.md` as the authoritative verification artifact.
- **D-03:** Phase 120 should create `.planning/phases/116-recovery-first-passkey-bootstrap/116-VALIDATION.md` as the Nyquist companion for that same shipped behavior.
- **D-04:** `116-VERIFICATION.md` must explicitly supersede `116-01-SUMMARY.md` as the authoritative `PK-03` proof surface.
- **D-05:** Do not make `120-VERIFICATION.md` the primary proof home unless the repo formally changes its repaired-form backfill model. The current preferred model is “backfill phase repairs proof for the original implementation phase.”

### Browser proof breadth
- **D-06:** The minimum honest browser proof for closing `PK-03` is **one canonical end-to-end served-route lane** from signup confirmation through the bootstrap banner/interstitial into explicit passkey enrollment.
- **D-07:** That browser lane should prove the exact seam named in the roadmap:
  - confirmation consumes the signup intent
  - the user lands on the sudo-gated MFA settings passkeys surface
  - the bootstrap banner is visible
  - passkey setup requires an explicit follow-up gesture
  - real WebAuthn enrollment completes on the served example host
- **D-08:** Do not widen the browser requirement into a cross-browser matrix, screenshot suite, or platform portability claim. One canonical Chromium + virtual-authenticator lane is sufficient for this phase.
- **D-09:** ExUnit remains the main authority for branch coverage, copy specifics, and controller/LiveView invariants; Playwright owns only the canonical integration seam proof.

### Scope boundary
- **D-10:** Keep Phase 120 scoped to **`PK-03` closure plus bounded active-truth updates only**.
- **D-11:** Allowed truth updates are only the present-tense files that would otherwise lie or stay stale once `116-VERIFICATION.md` and `116-VALIDATION.md` exist.
- **D-12:** Do not turn Phase 120 into milestone-wide v1.26 cleanup, archive normalization, next-milestone selection, or broad re-audit work. That remains Phase 121 scope.
- **D-13:** Do not reopen `PK-02`, `PK-04`, or `PK-05` wording unless a live file would directly contradict the repaired `PK-03` authority.
- **D-14:** If any historical Phase 116 artifact would mislead a maintainer into reading `116-01-SUMMARY.md` as current authority, add a bounded supersession pointer rather than rewriting broad history.

### Evidence packaging
- **D-15:** Default to **command-first proof** recorded directly in `116-VERIFICATION.md`.
- **D-16:** Reuse the focused proof seams already present in the repo:
  - generator assertions
  - example-app targeted ExUnit
  - canonical Playwright served-route proof
  - targeted grep or planning-truth checks only where they materially confirm active truth alignment
- **D-17:** Do not create a screenshot-heavy evidence bundle for green-path proof.
- **D-18:** Add a thin manifest-backed evidence bundle only if planning determines it materially improves milestone traceability without becoming a second source of truth.
- **D-19:** If any bundle is added, it must remain subordinate to the commands and receipts in `116-VERIFICATION.md`.

### Architecture and proof posture
- **D-20:** Preserve Sigra’s existing ownership model in the proof story:
  - controllers own terminal auth mutation and redirect/session boundaries
  - LiveViews own recoverable bootstrap/interstitial UI state
  - browser hooks own WebAuthn interop
  - generated-host proof must remain thin-host proof, not host-invented lifecycle logic
- **D-21:** The verification artifact must include a clear **Proved / Did Not Prove** boundary so `PK-03` closure does not imply Sigra-owned sync, escrow, transparent portability, or broader milestone closure.
- **D-22:** The verification artifact should mirror the repaired-form style already used successfully by Phases 115, 117, 118, and 119: phase-local authority, exact rerunnable commands, and bounded closeout claims.

### Decision posture for downstream agents
- **D-23:** Shift preference left: downstream researcher/planner/executor agents should choose decisive defaults without reopening implementation-level forks.
- **D-24:** Escalate back to the user only when a choice would materially alter:
  - the security model
  - the public or semver contract
  - the generated-host contract
  - or a user-facing truth claim Sigra cannot honestly prove
- **D-25:** Ordinary questions of proof layout, test factoring, command shape, grep gates, or document wording should be resolved by the agents directly if they stay within the boundaries above.

### the agent's Discretion
- Exact naming and section structure inside `116-VERIFICATION.md` and `116-VALIDATION.md`, provided the artifacts stay phase-local, explicit, and rerunnable.
- Whether the canonical browser proof extends an existing Playwright file or introduces one narrowly scoped new spec, provided the proof remains single-lane and served-route based.
- The precise list of active truth files to reconcile after the new authority lands, provided the set stays bounded to current-state surfaces and does not drift into archive cleanup.
- Whether a thin evidence manifest is worth adding, provided commands remain the real source of truth.

</decisions>

<specifics>
## Specific Ideas

- The cleanest shape is to mirror Phase 119:
  - Phase 120 repairs proof for the original implementation phase
  - `116-VERIFICATION.md` closes `PK-03`
  - `116-VALIDATION.md` maps the evidence seams for Nyquist
  - then only the active truth surfaces are updated

- The canonical browser lane should prove the exact roadmap phrase “confirmation -> bootstrap banner -> enrollment path,” not merely login fallback or settings enrollment in isolation.

- The verification doc should be explicit that:
  - it proves one canonical browser path
  - it does not prove cross-browser portability
  - it does not prove Sigra-owned sync, restore, or recovery beyond what the existing surfaces already claim

- If a thin evidence bundle is introduced, it should look more like an index/manifest than a screenshot archive.

- Preference-left policy to preserve:
  - “decide unless materially impactful”
  - user escalation only for truly contract-shaping or trust-shaping choices

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase and milestone contract
- `.planning/ROADMAP.md` — Phase 120 goal, success criteria, and the explicit `PK-03` closure scope.
- `.planning/REQUIREMENTS.md` — `PK-03` traceability row and milestone constraints.
- `.planning/PROJECT.md` — Sigra’s hybrid lib+generator philosophy, rough-edge DX goals, and preference for decisive recommendations.
- `.planning/STATE.md` — current milestone sequencing and next-step posture.

### Original implementation-phase authority
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-CONTEXT.md` — locked product and UX decisions for the recovery-first bootstrap behavior.
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-PLAN.md` — what Phase 116 set out to prove and how it decomposed the work.
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-01-SUMMARY.md` — historical implementation summary that must be superseded as proof authority.
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-RESEARCH.md` — prior analysis of the exact bootstrap seam and why it mattered.
- `.planning/phases/116-recovery-first-passkey-bootstrap/116-UI-SPEC.md` — exact copy and interaction contract for bootstrap/interstitial/login/MFA surfaces.

### Repaired-form and closeout precedents
- `.planning/phases/119-pk-02-verification-backfill/119-01-PLAN.md` — authoritative-verification-first precedent for a passkey gap-closure backfill.
- `.planning/phases/119-pk-02-verification-backfill/119-02-PLAN.md` — bounded active-truth reconciliation precedent.
- `.planning/phases/119-pk-02-verification-backfill/119-01-SUMMARY.md` — proof-shape precedent and receipts style.
- `.planning/phases/118-generated-host-proof-milestone-closeout/118-VERIFICATION.md` — repaired-form verification with explicit Proved / Did Not Prove boundaries.
- `.planning/phases/118-generated-host-proof-milestone-closeout/118-VALIDATION.md` — validation structure and thin evidence-bundle posture.
- `.planning/phases/117-cross-device-rp-id-trust-rails/117-VERIFICATION.md` — focused proof-seam structure and current-head command style.
- `.planning/phases/106-replay-verification-closeout/106-CONTEXT.md` — precedent for “authoritative verification first, reconcile only active truth.”

### Existing code and proof seams
- `test/example/lib/example_web/controllers/confirmation_controller.ex` — confirmation handoff into the bootstrap passkey return path.
- `test/example/lib/example_web/live/mfa_settings_live.ex` — bootstrap banner/interstitial and explicit passkey-enrollment start.
- `test/example/test/example_web/controllers/confirmation_controller_test.exs` — source-level proof of the confirmation handoff seam.
- `test/example/test/example_web/live/passkey_settings_live_test.exs` — bootstrap banner, interstitial, and passkey-settings assertions.
- `test/example/test/example_web/controllers/passkey_session_controller_test.exs` — controller-owned fallback and passkey completion behavior.
- `test/example/priv/playwright/tests/passkey-login.spec.ts` — existing real-browser passkey posture and settings-enrollment proof seam.
- `test/example/priv/playwright/tests/passkey-options.spec.ts` — existing served-route lifecycle proof seam.
- `test/sigra/install/generator_passkey_primary_login_test.exs` — generated-host assertions for confirmation/login posture.
- `test/sigra/install/generator_passkey_management_test.exs` — generated-host assertions for bootstrap/interstitial/settings posture.
- `test/sigra/install/generator_passkey_mfa_challenge_test.exs` — generated-host assertions for MFA recovery-truth boundaries.
- `guides/recipes/passkeys.md` — public product truth the repaired verification must stay aligned with.

### Prompt corpus and research inputs
- `prompts/Building the gold-standard Elixir:Phoenix authentication library.md` — product direction, hybrid lib+generator expectations, and ecosystem gap framing.
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` — architecture and boundary guidance for this stack.
- `prompts/phoenix-live-view-best-practices-deep-research.md` — LiveView ownership and state-boundary guidance.
- `prompts/phoenix-best-practices-deep-research.md` — Phoenix controller/router/pattern guidance.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — OSS library ergonomics and maintenance posture.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — command-first proof and release/verification discipline.
- `prompts/Phoenix Auth Library — Jobs to Be Done, Personas & User Flows.md` — DX and user-flow priorities.
- `prompts/biggest-gaps-elixir-auth.md` — why cohesive auth proof and DX matter in this ecosystem.
- `prompts/Auth Domain Language — A Field Guide.md` — precise auth vocabulary and anti-claim discipline.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The example app already has the core `PK-03` proof seams split correctly across controller, LiveView, generator, and Playwright layers; Phase 120 should reuse them instead of inventing a new harness.
- `confirmation_controller_test.exs` and `passkey_settings_live_test.exs` already pin the handoff and bootstrap/interstitial semantics at the server layer.
- `passkey-login.spec.ts` and `passkey-options.spec.ts` already provide the virtual-authenticator and served-route groundwork for the canonical browser lane.
- The generator passkey tests already encode the thin-host contract and should remain part of the verification story.

### Established Patterns
- Sigra’s repaired-form proof pattern is now:
  - authoritative phase-local verification
  - explicit rerunnable commands
  - narrow, honest claim boundaries
  - only then active-truth reconciliation
- Browser proof is used selectively for canonical end-to-end routes, not for exhaustive branch matrices.
- The repo treats summaries as implementation history, not durable verification authority.
- Active planning truth is updated deliberately and narrowly after authority changes, rather than through broad opportunistic cleanup.

### Integration Points
- The most important missing integration point is the browser path from confirmation into the passkeys settings bootstrap state; that is the seam Phase 120 must prove.
- `116-VERIFICATION.md` should integrate evidence from generator tests, example-host ExUnit tests, and one canonical Playwright lane.
- `116-VALIDATION.md` should map those same proof seams to `PK-03`, not invent hypothetical future coverage.
- Active truth updates, if needed, should integrate only with current-state files that point to `PK-03` status today.

</code_context>

<deferred>
## Deferred Ideas

- Milestone-wide v1.26 cleanup, re-audit, and remaining Nyquist closure — Phase 121.
- Broad archive normalization or archaeology cleanup unrelated to active `PK-03` truth.
- Cross-browser or cross-platform WebAuthn portability proof.
- Screenshot-heavy evidence bundles for green-path proof.
- Any change that would redefine backfill ownership from the original implementation phase to the later repair phase as a new repo-wide rule.

</deferred>

---

*Phase: 120-pk-03-bootstrap-proof-backfill*
*Context gathered: 2026-05-24*
