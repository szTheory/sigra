# Phase 241: Close gap: OPS-01 — repair controller MFA settings rendering - Context

**Gathered:** 2026-08-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the remaining OPS-01 integration gap identified by the v1.48 milestone audit: make the generated `--no-live` authenticated, sudo-protected `GET /users/settings/mfa` route render through its emitted HTML module, and prove the real generated route deterministically. Preserve the canonical LiveView lane and the existing generated-host ownership boundary. This phase does not implement controller MFA mutations, passkey behavior, general MFA capability, or unrelated controller repairs.

</domain>

<decisions>
## Implementation Decisions

### Render ownership
- **D-01:** Keep the existing generated `<WebModule>.MFASettingsHTML` module and make `SettingsController.mfa/2` render explicitly through it. Do not rename the emitted module to `SettingsHTML` or broaden the generated-file/module contract to accommodate Phoenix's inferred controller view.
- **D-02:** Preserve the existing `:mfa_settings` template function and assign contract; the defect is the controller-to-HTML-module connection, not the MFA settings presentation or data model.

### Runtime proof boundary
- **D-03:** Close the gap with a disposable generated `--no-live` host route test that establishes an authenticated, fresh-sudo session, requests `GET /users/settings/mfa`, and asserts successful rendered output. Template/source assertions, warning-free compilation, root readiness, or an unauthenticated redirect are insufficient proof.
- **D-04:** Integrate the route proof into the established deterministic generated-host harness rather than creating a parallel browser suite or relying on manual UAT. Keep it bounded, readiness-driven, credential-free, and free of fixed sleeps.

### Sudo test state
- **D-05:** Mark the exact persisted session token used by the logged-in test connection as sudo-fresh before issuing the route request. Do not rely on `sudo_fixture/1` alone because it creates a separate session from the one placed in the request connection.
- **D-06:** Assert that the request reaches and renders the protected controller action, so a redirect to the sudo gate cannot masquerade as route success.

### Scope preservation
- **D-07:** Stop after successful MFA settings GET rendering and deterministic generated-host evidence. Leave `disable`, `regenerate`, `revoke_trust`, `enroll`, `confirm`, and `complete` mutation behavior unchanged, including their existing `unavailable/1` handling.
- **D-08:** Do not modify the canonical LiveView route/runtime lane, add passkey behavior, change public APIs, add dependencies, or claim broader MFA management support.

### the agent's Discretion
- Choose the smallest idiomatic Phoenix mechanism for explicitly selecting `MFASettingsHTML` from `SettingsController.mfa/2` while preserving the current template function and assigns.
- Choose the exact generated-host test module location, fixture setup helpers, and stable rendered assertion, provided the test exercises the real authenticated and sudo-authorized route.
- Choose the narrowest harness/contract updates needed to make the new runtime proof part of the existing controller-mode lane without duplicating lifecycle setup.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Gap and requirement boundary
- `.planning/v1.48-MILESTONE-AUDIT.md` — authoritative controller-to-HTML mismatch, affected OPS-01 requirement, and required authenticated-route closure.
- `.planning/REQUIREMENTS.md` — OPS-01 acceptance requirement and milestone out-of-scope boundary.
- `.planning/ROADMAP.md` — Phase 241 ordering and dependency on Phase 240.

### Prior generated-host decisions
- `.planning/phases/237-canonical-b2c-generator-contract/237-CONTEXT.md` — canonical B2C generator profile that must remain stable.
- `.planning/phases/238-generated-auth-runtime-proof/238-CONTEXT.md` — independent LiveView/browser runtime proof boundary.
- `.planning/phases/240-alpha-operations-rehearsal/240-CONTEXT.md` — provider-neutral, no-secrets operations evidence contract.
- `.planning/phases/240.2-close-gap-ops-01-add-controller-mode-generated-host-compile-/240.2-CONTEXT.md` — distinct controller-mode lane, shared fresh-host lifecycle, and canonical LiveView preservation decisions.
- `.planning/phases/240.2-close-gap-ops-01-add-controller-mode-generated-host-compile-/240.2-VERIFICATION.md` — current controller lane proof boundary, which stops at compile/boot/root readiness.
- `.planning/phases/240.2-close-gap-ops-01-add-controller-mode-generated-host-compile-/240.2-REVIEW.md` — prior finding and candidate repair for the MFA render-module mismatch.

### Implementation and proof seams
- `priv/templates/sigra.install/core/settings_controller.ex` — broken generated action and explicitly deferred mutation endpoints.
- `priv/templates/sigra.install/core/mfa_settings_html.ex` — existing generated HTML owner and `mfa_settings/1` assign contract.
- `lib/sigra/install/features/core.ex` — `--no-live` file emission and authenticated/sudo MFA route generation.
- `priv/templates/sigra.install/core/auth_fixtures.ex` — generated authentication and sudo fixture behavior.
- `priv/templates/sigra.install/core/user_auth.ex` — generated request-session token handling.
- `lib/sigra/plug/require_sudo.ex` — persisted-session freshness check enforced by the protected route.
- `test/example/test/example_web/live/passkey_settings_live_test.exs` — established pattern for marking the logged-in connection's actual session sudo-fresh.
- `scripts/ci/passkeys-opt-out-smoke.sh` — canonical four-leg disposable generated-host lifecycle and controller-mode lane.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MFASettingsHTML.mfa_settings/1` already renders the complete settings surface with the assigns produced by `SettingsController.mfa/2`; no new template or presentation design is required.
- `scripts/ci/passkeys-opt-out-smoke.sh` already creates, compiles, migrates, boots, and tears down an isolated `sigra_b2c_controller` host generated with `--no-live`.
- Generated auth fixtures and connection helpers already create users, log them in, and expose the persisted session model needed to make the exact request session sudo-fresh.

### Established Patterns
- Controller and HTML modules may be separate generated owners; when Phoenix inference does not match, the controller must select the intended HTML module explicitly rather than rename unrelated generated surfaces.
- Sensitive routes must be exercised after both authentication and sudo authorization. Redirect-only success is not evidence that the target controller/template ran.
- Generated-host acceptance evidence uses disposable local infrastructure, deterministic ExUnit/browser automation, bounded readiness checks, and no inherited provider credentials.

### Integration Points
- Repair `SettingsController.mfa/2` at the render call while leaving status lookup, assigns, routes, and mutation actions intact.
- Add the authenticated route proof to the generated controller host produced by `scripts/ci/passkeys-opt-out-smoke.sh` or its directly owned test payload.
- Update focused generator/source contracts only as needed to require the explicit render ownership and real protected-route execution.

</code_context>

<specifics>
## Specific Ideas

- The proof should fail on the current module mismatch and should also fail if it merely receives an authentication or sudo redirect.
- Keep the repair visibly controller-specific so maintainers do not mistake it for a change to the canonical LiveView B2C profile.

</specifics>

<deferred>
## Deferred Ideas

- Implementing or removing controller-mode MFA mutation routes remains separately tracked noncritical debt.
- Passkey-enabled controller registration intent, malformed controller registration fallback behavior, general MFA capability changes, and auth/admin UI work remain outside this phase.

### Reviewed Todos (not folded)
- The automatic todo matcher returned broad historical auth UI, admin, security, release, configuration, and CI items. None was semantically related to the controller MFA render-module gap, so none was folded into Phase 241.

</deferred>

---

*Phase: 241-close-gap-ops-01-repair-controller-mfa-settings-rendering*
*Context gathered: 2026-08-11*
