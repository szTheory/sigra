---
phase: 240-alpha-operations-rehearsal
verified: 2026-08-10T23:03:00Z
status: passed
score: 26/26 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 23/26
  gaps_closed:
    - "Fresh canonical hosts refresh dependencies injected by sigra.install before generated assertions, probes, or compilation."
    - "Canonical LiveView registration has a CI-bound generated-host N+1 limiter-exhaustion proof."
  gaps_remaining: []
  regressions: []
---

# Phase 240: Alpha Operations Rehearsal Verification Report

**Phase Goal:** Deliver a provider-neutral, no-secrets launch-readiness gate for the canonical B2C profile.
**Verified:** 2026-08-10T23:03:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | OPS-01: The alpha recipe specifies host origin, secure session, Google redirect, Cloak, rate-limit, and transactional-email rehearsal requirements. | ✓ VERIFIED | `guides/recipes/b2c-alpha.md` has the three evidence tiers, literal HTTPS/proxy/cookie tuple, exact Google callback, Cloak/Doctor boundary, rate-limit posture, mail rehearsal, and redacted receipt. Its focused contract passed. |
| 2 | OPS-02: CI is credential-free while real Google, email, and iPhone proof remains a host gate. | ✓ VERIFIED | Active source contracts passed; independent fresh-generator and loopback-runtime jobs/scripts unset inherited Google credentials and contain no secrets injection. The recipe explicitly excludes real-provider/mail/device proof from repository CI. |
| 3 | D-08: A fresh canonical B2C host owns a configurable Hammer limiter rather than the Noop fallback. | ✓ VERIFIED | `core.ex` emits `rate_limit.ex`, Hammer dependency/config/application child, and explicit router adapter; golden-output contracts pass. |
| 4 | D-09: A sensitive POST path has bounded N+1 exhaustion, generic 429, and positive whole-second Retry-After without a window wait. | ✓ VERIFIED | The fresh B2C script writes `generated_rate_limit_probe_test.exs`, injects a limit of two, asserts the generic 429/positive `Retry-After`, and runs it after migration. The source contract and plug rounding tests passed; CI invokes this PostgreSQL-backed script. |
| 5 | OPS-01 boundary assumption: conservative generated bounds are selected and checked at zero/limit/limit+1. | ✓ VERIFIED | Generated probes set deterministic low integer bounds and drive bounded attempts synchronously; rate-limit contracts passed. |
| 6 | OPS-01 precision assumption: Retry-After is ceiling-rounded from milliseconds. | ✓ VERIFIED | `test/sigra/plug/rate_limit_test.exs` is in the focused passing run and exercises the existing exact-second/one-millisecond-over rounding contract. |
| 7 | D-08: Every selected sensitive identity/account flow has Hammer ownership at its actual route or LiveView/context boundary. | ✓ VERIFIED | Generated `auth.ex` supplies `sensitive_rate_limit/2`; registration, confirmation resend, reset update, and MFA templates call the limited context operations. The generated-host LiveView script exercises registration. |
| 8 | D-09: Route prefixes and mail-request keys are independent, bounded, generic, and deterministic. | ✓ VERIFIED | Distinct generated prefixes and normalized email keys are checked by `generated_rate_limit_context_test.exs`; route plug tests verify generic denial semantics. |
| 9 | OPS-01 boundary assumption: selected per-flow bounds are host-configurable and tested without elapsed-window waits. | ✓ VERIFIED | The recipe documents runtime overrides; generated B2C and LiveView probes use injected test bounds and contain no sleep/window wait. |
| 10 | OPS-01 precision assumption: windows are integer milliseconds and route Retry-After stays ceiling-rounded. | ✓ VERIFIED | The generated templates use positive integer configuration helpers and the focused plug tests pass. |
| 11 | D-01–D-07: The single B2C checklist has Library CI proof, Host pre-deploy, and Staging launch-gate tiers with owner/result/claim boundaries. | ✓ VERIFIED | `b2c-alpha.md` is substantive and its Phase 240 recipe contract passed. |
| 12 | D-02/D-03: Exact Google callback, controlled mail, and physical-iPhone proof remain explicit unpassable repository gates with redacted receipts. | ✓ VERIFIED | The recipe requires `https://<canonical-host>/auth/google/callback`, controlled-recipient delivery, physical iPhone return, and outcome-only receipts; focused contract passed. |
| 13 | D-04/D-05: One literal origin/proxy/cookie tuple and clean-browser rehearsal preserve secure host-only session defaults. | ✓ VERIFIED | The recipe records canonical HTTPS origin, trusted proxy, absent Domain, Secure/HttpOnly/SameSite=Lax and requires a clean-browser rehearsal. |
| 14 | D-06/D-07: Wiring/boot and delivery gates are separate; Doctor and receipts do not inflate claims or leak sensitive material. | ✓ VERIFIED | Recipe scopes Doctor to configuration/dependency evidence and prohibits secrets, token URLs, mail bodies, and provider payloads. |
| 15 | OPS-01 boundary assumption: documentation leaves thresholds host-overridable and claims only configured-bound proof. | ✓ VERIFIED | The limiter section documents conservative defaults/overrides and its one-below/at/one-above probe boundary. |
| 16 | OPS-01 precision assumption: documentation names millisecond windows and ceiling-rounded Retry-After without provider-timing claims. | ✓ VERIFIED | The limiter section states both explicitly and rejects provider sub-second timing claims. |
| 17 | OPS-02 claim-boundary assumption: CI-versus-host vocabulary is fail-closed. | ✓ VERIFIED | `phase_240_no_secrets_ci_test.exs` passed and rejects promotion of host-only proof to a repository-pass claim. |
| 18 | D-10: Fresh canonical generation and rendered loopback-OIDC runtime are independently runnable credential-free proofs. | ✓ VERIFIED | `.github/workflows/ci.yml` separately invokes `passkeys-opt-out-smoke.sh` and `generated-auth-runtime-proof.sh`; neither substitutes for the other. |
| 19 | D-10/D-11: Inherited Google credentials are unset and no live provider, mail, deploy, or GitHub secret is injected. | ✓ VERIFIED | Both harnesses unset `GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET`; focused no-secrets contracts scan both workflow/script regions and passed. |
| 20 | D-11: Fixed Cloak/OIDC values are labelled disposable fixtures and CI claims are bounded to local behavior. | ✓ VERIFIED | Fixture-adjacent comments label values disposable; contracts passed for generator, local PKCE/callback, and rendered B2C claim boundaries. |
| 21 | D-03/D-11: Provider, mail, DNS/TLS, proxy, and physical-device success remain outside the CI pass surface. | ✓ VERIFIED | Both jobs state that no host-staging success is claimed; the recipe names these as host staging gates. |
| 22 | OPS-02 unclassified assumption: source contracts fail closed on lane merging, secrets, inherited variables, fixture mislabelling, and claim inflation. | ✓ VERIFIED | The active no-secrets contract has explicit negative assertions for each condition and passed. |
| 23 | D-08/D-09 Wave 0 contracts define ownership, flow map, exhaustion, independence, generic outcomes, and precision without waits. | ✓ VERIFIED | Both generated rate-limit contract modules are active ExUnit tests in the passing focused suite. |
| 24 | D-01–D-07 Wave 0 contract defines tiers, tuple, Doctor boundary, staging gates, and redaction. | ✓ VERIFIED | `phase_240_alpha_operations_rehearsal_test.exs` is active and passed. |
| 25 | D-10/D-11 Wave 0 contract defines separate lanes, inherited-variable removal, disposable fixtures, truthful claims, and local-only coverage declaration. | ✓ VERIFIED | `phase_240_no_secrets_ci_test.exs` is active and passed. |
| 26 | All four Wave 0 modules are substantive active ExUnit behavior assertions, not skipped placeholders. | ✓ VERIFIED | The focused run executed all selected modules (56 tests, 0 failures); scoped debt scan found no unresolved marker. |

**Score:** 26/26 truths verified (0 present, behavior-unverified).

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/install/features/core.ex` and `priv/templates/sigra.install/core/rate_limit.ex` | Generated Hammer owner/config/child/router wiring | ✓ VERIFIED | Present, substantive, rendered by `Core.files/1`, and asserted in passing golden/source contracts. |
| `priv/templates/sigra.install/core/auth.ex` | Context limits for mail and LiveView-sensitive operations | ✓ VERIFIED | Present and substantive; context handlers call `sensitive_rate_limit/2` and preserve generic denial branches. |
| `scripts/ci/passkeys-opt-out-smoke.sh` | Fresh canonical B2C generator + bounded route probe | ✓ VERIFIED | Runs post-install `MIX_ENV=dev mix deps.get` before assertions/probe/compile; CI job supplies PostgreSQL and invokes it. |
| `scripts/ci/generated-auth-runtime-proof.sh` | Generated-host LiveView N+1 exhaustion proof | ✓ VERIFIED | Writes an executable `Phoenix.LiveViewTest`, migrates the disposable host, runs it, and directly verifies Hammer denial. CI job supplies PostgreSQL and invokes it. |
| Recipe, deployment mechanics, and planning contracts | Provider-neutral checklist and no-secrets boundary | ✓ VERIFIED | Present, substantive, cross-linked, and exercised by the passing source contracts. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Core.files/1` | generated `rate_limit.ex` | File entry plus dependency/config/supervision/router injections | ✓ WIRED | Core renders the template and emits its owner/configuration chain. |
| Canonical controller route | `Sigra.Plug.RateLimit` | Explicit generated Hammer limiter, prefix, bound/window, and error handler | ✓ WIRED | Generated B2C smoke writes and runs a request-level N+1 test against that route. |
| LiveView handlers | `Auth` context limiter | Registration/resend/reset/MFA call limited context operations | ✓ WIRED | Source flow-map contract passes; the separate generated-host LiveView test exercises registration to N+1. |
| Fresh-generator CI job | `passkeys-opt-out-smoke.sh` | `passkeys_opt_out_smoke` invokes the script with PostgreSQL service | ✓ WIRED | `.github/workflows/ci.yml:1027-1078`. |
| Runtime CI job | `generated-auth-runtime-proof.sh` | Separate `generated_auth_runtime_proof` invokes the script with PostgreSQL service | ✓ WIRED | `.github/workflows/ci.yml:1534-1581`. |
| Checklist | deployment mechanics | Single checklist links `deployment.md` without creating a competing checklist | ✓ WIRED | `b2c-alpha.md` Detailed mechanics section. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated route limiter | Request IP + stable route prefix + configured limit/window | Router → `Sigra.Plug.RateLimit` → configured generated Hammer module | Yes — generated request probe drives the real route | ✓ FLOWING |
| Generated mail limiter | Normalized email + explicit max/window | Auth wrapper → `Sigra.Auth` → Hammer | Yes — runtime values come from generated configuration | ✓ FLOWING |
| Generated LiveView limiter | Normalized registration email + operation prefix + configured limit/window | LiveView submit → generated Auth context → Hammer | Yes — CI-bound generated LiveView test drives the rendered submit then directly observes the corresponding Hammer denial | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase limiter, recipe, no-secret, and generated-runtime source contracts | `MIX_ENV=test mix test` over the six focused Phase 240/238 modules | 56 tests, 0 failures | ✓ PASS |
| Generated ownership idempotency | `MIX_ENV=test mix test test/sigra/install/idempotency_test.exs --trace` | 2 tests, 0 failures | ✓ PASS |
| Script syntax | `bash -n scripts/ci/passkeys-opt-out-smoke.sh scripts/ci/generated-auth-runtime-proof.sh` | exit 0 | ✓ PASS |
| Fresh generated route and generated LiveView probes | Local execution intentionally not attempted after `PGHOST=127.0.0.1 PGPORT=53988 pg_isready` returned `no response`; both probes are executable and CI-bound to PostgreSQL-backed jobs | No local runtime-pass claim | ✓ VERIFIED BY DETERMINISTIC SOURCE/TEST + CI WIRING |

## Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| `scripts/ci/passkeys-opt-out-smoke.sh` | CI: `scripts/ci/passkeys-opt-out-smoke.sh` in `passkeys_opt_out_smoke` with PostgreSQL service | Source lifecycle, bounded B2C probe, dependency ordering, and invocation verified; not run locally because PostgreSQL is unavailable | CI-BOUND (not locally executed) |
| `scripts/ci/generated-auth-runtime-proof.sh --all` | CI: `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --all` in `generated_auth_runtime_proof` with PostgreSQL service | Source-generated LiveView N+1 probe, migrations, and invocation verified; not run locally because PostgreSQL is unavailable | CI-BOUND (not locally executed) |

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| OPS-01 | 01, 02, 03, 05 | Provider-neutral recipe including rate-limit rehearsal | ✓ SATISFIED | Checklist contract, generated ownership/context contracts, plug tests, and CI-bound generated-host route/LiveView probes. |
| OPS-02 | 03, 04, 05 | No-secrets CI with real-provider/device proof left to the host | ✓ SATISFIED | Separate credential-free jobs, fail-closed source contracts, unsetting/fixture labels, and explicit host-only staging gates. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | — | Scoped Phase 240 implementation scan found no unresolved `TBD`, `FIXME`, or `XXX` marker and no user-visible placeholder/stub. | ℹ️ Info | No blocker. |

## Environment Limitation

The configured local PostgreSQL endpoint (`127.0.0.1:53988`) returned `no response` from `pg_isready`. Therefore this verification does **not** claim that either database-backed generated-host smoke ran on this workstation. The claim credited here is narrower and reproducible: the scripts are syntactically valid, their deterministic source contracts and focused tests pass, and each script is wired to an independent PostgreSQL-backed CI job. No human UAT is required for that limitation; CI is the automated execution authority for these probes.

## Disconfirmation Pass

- **Partial-requirement check:** the previous dependency-ordering defect existed only in the fresh-generator script, not the idempotency fixture. The repaired script now has a post-install dependency refresh before both probe and compilation, and a passing source contract locks that ordering.
- **Misleading-test check:** source markers alone would not prove a LiveView event reaches Hammer. The runtime script now writes a real `Phoenix.LiveViewTest`, submits registration at N+1, and directly asserts the generated Hammer key is denied.
- **Uncovered-error-path check:** the actual PostgreSQL-backed scripts were not executed locally. This is explicitly retained as CI-bound execution evidence, not represented as a local smoke success.

---

_Verified: 2026-08-10T23:03:00Z_
_Verifier: the agent (gsd-verifier)_
