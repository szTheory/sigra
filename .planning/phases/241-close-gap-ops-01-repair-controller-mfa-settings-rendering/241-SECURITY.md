---
phase: 241
slug: close-gap-ops-01-repair-controller-mfa-settings-rendering
status: verified
# threats_open counts OPEN threats at or above workflow.security_block_on (high).
threats_open: 0
asvs_level: 1
created: 2026-08-11
---

# Phase 241 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Generated test connection → authenticated/sudo router pipelines | The route proof exercises the same persisted session consumed by the real authentication and authorization plugs. | Raw test-session token and authenticated user/session identity |
| Generated controller → emitted HTML module | The controller must hand rendering to the generated HTML owner instead of relying on an invalid inferred module. | MFA status and seven existing render assigns |
| Repository harness → disposable generated Phoenix host | Injected proof code and database state remain local, credential-free, deterministic, and controller-leg scoped. | Disposable test source, local session row, and generated-host environment |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-241-01 | Elevation of Privilege | Generated MFA route proof | high | mitigate | The disposable routed probe requires `html_response(200)` and stable `Two-Factor Authentication` content after authentication and sudo processing; redirects cannot pass. | closed |
| T-241-02 | Tampering | Persisted sudo session setup | high | mitigate | The probe reads the logged-in connection's `:user_token`, matches its user/session, selects the persisted row by `session.hashed_token`, and changes only its `sudo_at`. | closed |
| T-241-03 | Denial of Service | `SettingsController.mfa/2` runtime render dispatch | high | mitigate | `mfa/2` selects the emitted `MFASettingsHTML` with `put_view/2` before rendering, and the generated-host route probe exercises the protected request. | closed |
| T-241-04 | Information Disclosure | Generated-host environment | medium | mitigate | The existing disposable lifecycle unsets Google credentials, uses a non-deployment Cloak fixture and local database, installs an exit cleanup trap, and makes no provider call. | closed |
| T-241-05 | Repudiation | OPS-01 closure evidence | medium | mitigate | Commits `987154fe`, `1f3553b4`, and `24056c36` preserve the failing probe introduction, render fix, and focused regression contracts; the summary records focused and four-leg successful runs. | closed |
| T-241-06 | Tampering | Deferred controller mutation and LiveView/passkey lanes | low | accept | Accepted as a bounded non-change: mutation handlers remain `unavailable/1`, the canonical LiveView lane remains separate, and focused contracts enforce the phase's file and behavior fence. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-241-01 | T-241-06 | Phase 241 intentionally repairs only the protected MFA GET render path. Deferred mutation behavior and the independent LiveView/passkey lanes are unchanged and guarded by source contracts; expanding them would exceed D-07/D-08. | Phase 241 plan | 2026-08-11 |

---

## Security Audit 2026-08-11

| Metric | Count |
|--------|-------|
| Threats found | 6 |
| Closed | 6 |
| Open | 0 |

### Evidence

- `priv/templates/sigra.install/core/settings_controller.ex` places the explicit `MFASettingsHTML` view selection before `render(:mfa_settings, ...)` and leaves all six mutation handlers delegated to `unavailable/1`.
- `scripts/ci/passkeys-opt-out-smoke.sh` scopes the exact-session route probe to `sigra_b2c_controller`, rejects redirects through `html_response(200)`, unsets provider credentials, uses bounded cleanup, and contains no sleep.
- `test/sigra/install/generated_rate_limit_contract_test.exs` locks render ownership, exact-session sudo freshening, controller-only lifecycle placement, redirect rejection, no-sleep behavior, and LiveView lane separation.
- `241-01-SUMMARY.md` records successful focused contracts, shell validation, focused generated-host execution, and the complete four-leg smoke.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-11 | 6 | 6 | 0 | Codex (`gsd-secure-phase`) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-11
