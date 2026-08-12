# Phase 241: Close gap: OPS-01 — repair controller MFA settings rendering - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-11
**Phase:** 241-close-gap-ops-01-repair-controller-mfa-settings-rendering
**Mode:** assumptions
**Areas analyzed:** Render Ownership, Runtime Proof Boundary, Sudo Test State, Scope Preservation

## Assumptions Presented

### Render Ownership

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The generated controller MFA action should explicitly use the already-emitted `MFASettingsHTML` render module rather than rename that module. | Likely | `priv/templates/sigra.install/core/settings_controller.ex`; `priv/templates/sigra.install/core/mfa_settings_html.ex`; `lib/sigra/install/features/core.ex`; `.planning/v1.48-MILESTONE-AUDIT.md` |

### Runtime Proof Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Closure evidence should be a disposable generated `--no-live` host route test that establishes an authenticated, fresh-sudo session and proves `GET /users/settings/mfa` renders. | Confident | `.planning/v1.48-MILESTONE-AUDIT.md`; `scripts/ci/passkeys-opt-out-smoke.sh`; `.planning/phases/240.2-close-gap-ops-01-add-controller-mode-generated-host-compile-/240.2-VERIFICATION.md` |

### Sudo Test State

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The generated route test must sudo-stamp the same persisted session token used by its logged-in connection, not a separate session returned by `sudo_fixture/1`. | Confident | `priv/templates/sigra.install/core/auth_fixtures.ex`; `priv/templates/sigra.install/core/user_auth.ex`; `lib/sigra/plug/require_sudo.ex`; `test/example/test/example_web/live/passkey_settings_live_test.exs` |

### Scope Preservation

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The phase stops after successful MFA settings GET rendering and deterministic generated-host proof; controller MFA mutations, passkeys, and the LiveView lane remain unchanged. | Confident | `.planning/v1.48-MILESTONE-AUDIT.md`; `.planning/phases/240.2-close-gap-ops-01-add-controller-mode-generated-host-compile-/240.2-CONTEXT.md`; `priv/templates/sigra.install/core/settings_controller.ex` |

## Corrections Made

No corrections — all assumptions confirmed.

## Methodology Applied

- **Decisive Defaulting:** Selected explicit use of the existing emitted HTML module as the smallest repo-consistent repair.
- **Escalation Threshold:** Preserved the generated-host, security, and proof contracts; no implementation-level choice required further escalation.
- **Research Depth Calibration:** Used the milestone audit, prior phase context/verification, generator templates, sudo plug, fixture behavior, and generated-host harness before presenting assumptions.
- **User Experience Bias:** Required a real protected-route render so adopters do not receive a compiling controller host whose account-security link raises at runtime.

