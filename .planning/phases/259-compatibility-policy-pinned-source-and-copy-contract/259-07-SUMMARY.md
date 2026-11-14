---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 07
subsystem: testing
tags: [exunit, enumeration, parity, registry, phoenix-liveview, conntest, passkeys]

requires:
  - phase: 259-01
    provides: the compatibility policy that bounds what a registry row may claim
provides:
  - test/fixtures/brand/public-surfaces.json, a 13-row registry of pre-auth surfaces with asserted states (parity, known_divergence, by_design, not_proven)
  - test/example/test/example_web/enumeration_parity_test.exs, an example-host harness with one pure comparator, limited normalization, per-state assertions and a positive control
  - the exact todo path each row carries, fixed as strings for Plan 259-13 to assert against
affects: [259-10, 259-11, 259-13, 262, 263]

actuals:
  tokens: 11200
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 78de3d8cc3a3bcf95b1e5a2568b45057ed0ff773
plan_head_after: b13e65508cb72aacf7fb661184f17a043ec9f621

tech-stack:
  added: []
  patterns:
    - "Registry-driven parity harness: the registry row's compare list is the only set of dimensions the comparator looks at, so the claim and the code cannot drift apart"
    - "Shrink discipline: a known_divergence row asserts the divergence still exists on exactly the registered dimensions, so any fix forces the row to change"
    - "Positive control in the test module only: a leak string appended to one surface's unknown-identity response must produce exactly one diff, and every parity row is leaked in turn to prove each can go red"
    - "Citation rot guard: every blocker path:line must resolve to a real file and an existing line"

key-files:
  created:
    - test/fixtures/brand/public-surfaces.json
    - test/example/test/example_web/enumeration_parity_test.exs
    - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md
  modified: []

key-decisions:
  - "password-reset-request and confirmation-resend are registered not_proven, not parity: the example host cannot drive either (route has no :new live action; resend raises for anonymous visitors and redirects signed-in ones). Exactly three of the five named surfaces are parity (password-signin, magic-link-request, mfa-challenge)"
  - "Added a result compare dimension for library-level rows, needed to express the lockout divergence (account_locked versus invalid_credentials) that no HTTP dimension shows at the example controller"
  - "LiveView per-mount ids (id=phx-..., data-phx-session, data-phx-static) are normalized as request ids, a documented reading of the plan's 'request ids'; CSRF tokens, request ids and the echoed email remain the only normalized classes"
  - "The email-less passkey conditional flow is a sub-case test inside the known-divergence group, not a registry parity row: it involves no identity, so a parity row would read as a claim about passkey enumeration safety that it cannot support"
  - "MFA flash is read from the LiveView process state (:sys.get_state) because the example challenge view does not render flash in its own markup; the row note says so"
  - "Known-divergence rows assert the exact set of differing dimensions (registration body+flash, passkey json_keys, lockout result), so a partial fix also forces a registry edit"

patterns-established:
  - "Mutation proof: registering the registration row as parity turned five tests red by name, then the registry was restored"

requirements-completed: [BCOPY-03]

coverage:
  - id: D1
    description: "Surface registry with schema version, example-host limitation note, 13 well-formed rows, unique ids, fixed todo path strings and path:line blockers that resolve to real lines"
    requirement: BCOPY-03
    verification:
      - kind: unit
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#registry"
        status: pass
    human_judgment: false
  - id: D2
    description: "One pure comparator and normalization limited to CSRF tokens, request ids and the echoed email, with unit tests that a real difference survives normalization"
    requirement: BCOPY-03
    verification:
      - kind: unit
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#comparator and #normalization"
        status: pass
    human_judgment: false
  - id: D3
    description: "Parity probes for password sign-in, magic-link request and MFA challenge (existing versus unknown identity, same request)"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#parity surfaces"
        status: pass
    human_judgment: false
  - id: D4
    description: "Positive control: a leak on exactly one parity surface yields exactly one diff with at least two other parity rows staying same, and every parity surface goes red when leaked"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#positive control"
        status: pass
    human_judgment: false
  - id: D5
    description: "Asserted known divergences (registration, passkey options, lockout) and by-design rows (invitation accept, enterprise SSO), with none of the five leaks registrable as parity"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#known divergences and #by design"
        status: pass
    human_judgment: false
  - id: D6
    description: "Whether three parity rows out of the five named surfaces satisfies the roadmap success criterion that parity tests pass for every pre-auth surface"
    verification: []
    human_judgment: true
    rationale: "Two named surfaces (password-reset-request, confirmation-resend) are not_proven because the example host cannot drive them; the plan allows this with a path:line blocker, but whether that meets the intent of SC-4 is the owner's call, and the example-host defects behind them are logged in deferred-items.md"

duration: 16min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 07: Enumeration parity registry and harness Summary

**A 13-row public-surfaces registry and an example-host harness that proves three pre-auth surfaces identical for existing versus unknown identities, asserts three known leaks (passkey options, registration, lockout) still differ, and goes red exactly once on a planted leak.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-11-14T16:19:00Z (approximate; start time was not captured, taken from the previous plan's final commit)
- **Completed:** 2026-11-14T16:36:00Z
- **Tasks:** 3
- **Files modified:** 2 (both created) plus the phase's `deferred-items.md`; zero bytes under lib/, priv/, brandbook/, brand/, .github/ or scripts/

## Accomplishments

- Task 1 (tracer): registry schema, one pure comparator, normalization (CSRF tokens, request ids, echoed email), password sign-in as the first parity surface, and the positive control, end to end.
- Task 2: magic-link request and MFA challenge probed as parity; password-reset request and confirmation resend registered `not_proven` with path:line blockers because the example host cannot drive them. Registry-level assertions for the five named ids, the three-of-five parity floor, and citation resolution.
- Task 3: asserted known divergences (registration, passkey sign-in options, repeat-attempt lockout), by-design rows (invitation accept, enterprise SSO discovery), `not_proven` rows for the two rate-limit channels and the library-claims row `lib-moduledoc-claims`, and the fixed todo path strings.
- 20 tests in the module; the full example suite is 363 tests, 0 failures, so the passkey environment changes do not leak into other tests.

## Task Commits

1. **Task 1: Registry schema, comparator, password sign-in parity and the positive control (tracer)** - `9419aee4f` (test)
2. **Task 2: Controller- and LiveView-level parity surfaces** - `15d5cbac5` (test)
3. **Task 3: Asserted known divergences, by-design rows, not_proven rows, the library-claims row and the fixed todo paths** - `b13e65508` (test)

**Plan metadata:** the `docs(259-07)` close-out commits that carry this SUMMARY, STATE.md, ROADMAP.md and REQUIREMENTS.md.

Tracer gate: `gate` not `blocking-human`, `human_verify_mode` end-of-phase, tracer `<verify>` automated-only, so the tracer slice was re-run (8 tests green); logged "Tracer verified end-to-end - expanding".

## Registry states (what may and may not be claimed)

| Row | State | What is asserted |
|-----|-------|------------------|
| `password-signin` | parity | status, redirect, flash, body for one failed attempt, existing versus unknown email |
| `magic-link-request` | parity | status, redirect, flash, body for one request |
| `mfa-challenge` | parity | outcome, redirect and flash (including the remaining-attempts count) for a wrong authenticator code versus a wrong backup code; body not compared |
| `password-reset-request` | not_proven | example router has no `:new` action, mount raises |
| `confirmation-resend` | not_proven | resend raises for anonymous visitors, signed-in visitors are redirected before mount |
| `registration` | known_divergence | new email sets `phx-trigger-action`; duplicate shows only an info flash (differs on body and flash) |
| `passkey-signin-options` | known_divergence | unknown email returns key `error`, existing returns key `options` (differs on json_keys) |
| `password-signin-repeat-attempts` | known_divergence | library returns `account_locked` for an existing account after the threshold and `invalid_credentials` forever for an unknown one; masked at the example controller (asserted) |
| `invitation-accept` | by_design | same signup branch for invitees with and without an account |
| `enterprise-sso-discovery` | by_design | per-domain answer, identical for a registered and an unregistered address on one domain |
| `magic-link-rate-limit`, `password-reset-rate-limit` | not_proven | example host passes no rate limiter, so the existing-users-only throttle cannot be driven |
| `lib-moduledoc-claims` | not_proven | prose over-claims in library moduledocs; not a request surface |

## Deviations from Plan

### Plan-sanctioned downgrades (not deviations, recorded for the verifier)

- `password-reset-request` and `confirmation-resend` are `not_proven` rather than parity. The plan's escape hatch (a deterministic probe is impossible in the example host, so register `not_proven` with a path:line blocker, keep at least three of five parity) was used exactly as written. Parity count among the five: 3.
- `magic-link-rate-limit` and `password-reset-rate-limit` are `not_proven` rather than `known_divergence`, per the plan's rule that a divergence needs a deterministic assertion under the example's rate-limiter config and the example has none.

### Interpretation choices (no behavior outside the plan's files)

1. **`result` compare dimension added** for library-level rows. The plan lists status, redirect, flash, body and JSON keys; the lockout divergence is a library return value (`account_locked` versus `invalid_credentials`) and is invisible on every HTTP dimension at the example controller. The row note and a separate test state the masking.
2. **LiveView per-mount ids and session/static tokens are normalized as request ids.** Needed for the invitation row, where `live/2` returns the full page. Documented in the module doc and covered by a normalization unit test that also proves other ids (`id="login_form"`) are untouched.
3. **Passkey conditional sub-case is a test, not a registry row** (see key-decisions).
4. **Two tests beyond the plan** because they close real gaps: every blocker citation must resolve to a real file and line, and every parity surface is leaked in turn so a probe that ignores the response cannot hide as parity.
5. **`mfa-challenge` identity is code kind**, not account existence; the pending-versus-absent MFA session comparison was not cheap to reproduce and is listed as not compared in the row note.
6. **`unique` fixtures per probe**: `prepare/1` shares one org and owner between the two probes of the invitation and SSO rows so only the invitee or email differs.

### Auto-fixed Issues

None.

---

**Total deviations:** 0 auto-fixed, 2 plan-sanctioned downgrades, 6 interpretation choices
**Impact on plan:** All within the two files; the claim surface is narrower than a naive reading of "parity for every pre-auth surface", which is the intent of T-259-21.

## Deferred Issues

Logged in `deferred-items.md` (phase directory), not fixed:

1. Example host cannot mount the password-reset request page (`router.ex:112`, `reset_password_live.ex:146`), and the same view passes a struct to a binary-only function.
2. Example host cannot complete a confirmation resend in either session state (`confirmation_live.ex:158`, `router.ex:106`); the generated host has the same defect (existing todo).
3. Example login and MFA challenge pages do not render the flash in their own markup (observation; intent unverified).

Not recorded in `.planning/WINDOWS.md`: these are scope limits of the example host, and an open ledger entry would block `/gsd-ship`.

## Issues Encountered

None blocking. Two probes could not be driven (see Deferred Issues) and were registered `not_proven` as the plan permits.

## Authentication Gates

None.

## Known Stubs

None. No stub patterns, skipped tests or unrun verifies in the files created.

## Threat Flags

None. Test-only files; no new network, auth or file-access surface. The pre-existing leaks (passkey options, registration, lockout) are the subject of the registry and are tracked by todos that Plan 259-13 files.

## Verification Results

- `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs`: 20 tests, 0 failures. Full example suite `--include example_app`: 363 tests, 0 failures.
- `mix test test/sigra/brand` (root): 142 tests, 0 failures.
- `mix format --check-formatted`: clean. No compiler warnings from the new module.
- Zero-shipped-bytes gate (Verification item 3): PASS. Privacy gate (item 4) with planted-failure control: PASS.
- Acceptance criteria: parity rows = 3 (at least 3); five named ids = 5; blocker rows = 5; known_divergence = 3 (at least 2); not_proven plus known_divergence = 8 (at least 6); by_design = 2; fixed todo path lines = 5 (at least 5); `lib-moduledoc-claims` id = 1; `Path.expand("../../../fixtures/brand/public-surfaces.json"` appears once; leak string in `lib`/`priv` = 0 (control: 1 match in the test module).
- Live red proof: registering `registration` as `parity` turned five tests red by name (parity row, both positive controls, the known-divergence test and the never-parity rule); the registry was restored and the module went green.

## Next Phase Readiness

Plan 259-13 can create the three todo files and add its existence assertion; the registry already carries the exact strings. Plan 259-11's claims register must reference every non-parity row id: `password-reset-request`, `confirmation-resend`, `registration`, `passkey-signin-options`, `password-signin-repeat-attempts`, `invitation-accept`, `enterprise-sso-discovery`, `magic-link-rate-limit`, `password-reset-rate-limit`, `lib-moduledoc-claims`. Plan 259-10 prose may cite only what the three parity rows prove, on the dimensions their notes list.

## Self-Check: PASSED

Created files exist on disk; commits `9419aee4f`, `15d5cbac5`, `b13e65508` are ancestors of HEAD; every task acceptance criterion and the plan-level verification commands were re-run green after the last code commit; no stub patterns found.
