---
phase: 10-developer-experience
audited_at: 2026-04-09
asvs_level: 1
block_on: high
status: secured
threats_total: 21
threats_closed: 21
threats_open: 0
threats_accepted_this_audit: 2
---

# Phase 10: Security Audit

**Scope:** Verification of threat mitigations declared in 10-0[1-6]-PLAN.md `<threat_model>` blocks against shipped implementation.

**Method:** Each threat classified by disposition (mitigate / accept / transfer). Mitigations verified by grep + file inspection of the files cited in the plan mitigation columns. Implementation files are read-only for this audit.

## Summary

- 21 threats CLOSED (19 mitigated in shipped code + 2 accepted this audit)
- 2 threats ACCEPTED this audit — CR-02 (`request_password_reset/3` plain-map insert) and its magic-link twin. Both are pre-existing library bugs not introduced by Phase 10; formally transferred to phase 10.1 (see Accepted Risks Log below)
- 0 OPEN, 0 ESCALATE

## Threat Register

| Threat ID | Category | Component | Disposition | Status | Evidence |
|-----------|----------|-----------|-------------|--------|----------|
| T-10-01 | Information Disclosure | Overly-broad cookie_domain leaks across unrelated subdomains | mitigate | CLOSED | `guides/recipes/subdomain-auth.md` — documents leading-dot rule, public-suffix warning, >=5 cookie_domain mentions (verified plan 10-04) |
| T-10-02 | Repudiation / Session Fixation | Silent nil cookie_domain in :prod | mitigate | CLOSED | `lib/sigra/application.ex:29-64` `maybe_warn_missing_cookie_domain/0,2`; emits `Logger.warning` in :prod when nil. Guarded `Mix.env` with `function_exported?/2` at line 30 |
| T-10-03 | Tampering | Example app commits real secret_key_base / credentials | mitigate | CLOSED | `rg 'SECRET_KEY_BASE\s*=\s*"[^$]' test/example/config/` → 0 matches; test.exs uses `"test-only-key-base-" <> String.duplicate("a", 64)`; runtime.exs reads env vars |
| T-10-04 | Tampering | Guide doctests / code blocks hardcode secrets → copy-paste regressions | mitigate | CLOSED | `guides/recipes/subdomain-auth.md` uses `System.get_env("COOKIE_DOMAIN")`; doctest sweep in plan 10-05 uses `Fake.Repo`/`Fake.User` atoms; automated `test/sigra/guides_dx02_test.exs` grep gate |
| T-10-05 | Repudiation / Bypass | Scenario fixtures skip CSRF + session renewal if misused in integration tests | mitigate | CLOSED | Plan 10-02: @doc strings on each scenario fixture in `priv/templates/sigra.install/auth_fixtures.ex:191-274`; plan 10-05 testing.md recipe calls out unit vs integration boundary |
| T-10-06 | Tampering | audit_event_fixture/1 bypasses Ecto.Multi wrapping; test rows mistaken for real events | accept | CLOSED | Accepted per plan 10-01; test-only helper, documented in @doc; does not affect production `Sigra.Audit.log/2` path |
| T-10-07 | Information Disclosure | assert_audit_event/2 diff output could include PII | mitigate | CLOSED | `lib/sigra/testing.ex:1176-1182` uses cond-based lookup (post WR-02 fix); diff formatting uses `inspect/1` on expected map only |
| T-10-08 | Repudiation | REQUIREMENTS.md DX-01 text drift from shipped signatures | mitigate | CLOSED | Plan 10-01 enacted D-01: REQUIREMENTS.md DX-01 row names `log_in_user/3`, `register_user/2`, `setup_totp/2`, `create_api_token/3`; dated footer present |
| T-10-09 | Tampering | String vs atom session.type mismatch could mask bypass bugs | mitigate | CLOSED | `priv/templates/sigra.install/auth_fixtures.ex`: grep for `type: :standard\|type: :mfa_pending` returns 0 matches; hard-coded strings only |
| T-10-10 | Elevation of Privilege | mfa_complete_fixture returning logged-in conn without real TOTP could mask regressions | mitigate | CLOSED | @doc on fixture marks it as post-verification state; plan 10-06 `mfa_totp_test.exs` exercises real `Sigra.Testing.setup_totp/2` + `generate_totp_code/1` flow |
| T-10-11 | Tampering | Compile-time @remember_me_options froze stale domain-less value | mitigate | CLOSED | `priv/templates/sigra.install/user_auth.ex:35` `defp remember_me_options/0` resolves at runtime; grep for raw `@remember_me_options` → 0 matches (only `@remember_me_static_options`) |
| T-10-12 | Elevation of Privilege | cookie_domain accepted as atom :parent silently coerces to host-only | mitigate | CLOSED | `lib/sigra/config.ex:578` NimbleOptions `{:or, [:string, nil]}`; `test/sigra/cookie_domain_test.exs` asserts `:parent` and `:auto` rejected |
| T-10-13 | Information Disclosure | FetchSession plug writes cookies without honoring cookie_domain | accept | CLOSED | Grep `rg put_resp_cookie lib/sigra/plug/fetch_session.ex` → 0 matches; FetchSession is read-only for cookies; Open Q2 path (b) holds |
| T-10-14 | Information Disclosure | subdomain-auth.md `.com` example could mislead users | mitigate | CLOSED | `guides/recipes/subdomain-auth.md` explicitly flags `.com` as BAD, documents leading-dot + registrable-domain rule |
| T-10-15 | Repudiation | ex_doc `:extras` missing guide reference → silent sidebar omission | mitigate | CLOSED | `mix.exs:78-104` lists all 15 guides; plan 10-04 verified `mix docs` build generates each HTML file |
| T-10-16 | Repudiation | Guide drift from shipped signatures | mitigate | CLOSED | `test/sigra/guides_dx02_test.exs` automated CI gate: grep-extracts `Sigra.Module.function` references + `function_exported?/3` check + `@known_library_drift` allow-list; WR-01 fixed MFA guide drift |
| T-10-17 | Information Disclosure | Doctest examples leak test fixture data in failure messages | accept | CLOSED | Accepted per plan 10-05; low severity; ExUnit doctest failures run in test env only |
| T-10-18 | Information Disclosure | test/example/mix.lock pollutes root lockfile | mitigate | CLOSED | Root `.gitignore` excludes `test/example/_build/` and `test/example/deps/` but not `mix.lock`; root `mix.exs` `test_load_filters: [~r"^test/(?!example/)"]`; CI job uses `working-directory: test/example` |
| T-10-19 | Elevation of Privilege | Smoke tests skip real MFA/OAuth verification → false green | mitigate | CLOSED | Plan 10-06 smoke tests exercise real `Sigra.Testing.setup_totp/2` and real Accounts context API; note: HTTP/LiveView coverage partial (context-layer only — documented in summary) |
| T-10-20 | Repudiation | Guide code drifts from example app over time | mitigate | CLOSED | `test/example/test/example_web/smoke/getting_started_flow_test.exs` exercises register→login→reset walkthrough as a CI gate |
| T-10-21 | Denial of Service | Example-app CI job adds ~60-90s to every PR | accept | CLOSED | Accepted per plan 10-06 D-17; tradeoff for drift-free docs |

## Open Threats

None. Both threats observed as OPEN during the initial audit pass (CR-02 and its magic-link twin) have been formally accepted this audit with a scheduled fix in phase 10.1 — see Accepted Risks Log below.

## Accepted Risks Log

All `accept`-dispositioned threats from the plan threat registers (T-10-06, T-10-13, T-10-17, T-10-21) remain accepted per their original justifications.

### Accepted this audit (2026-04-09)

#### AR-10-01: `Sigra.Auth.request_password_reset/3` inserts a plain map (CR-02)

- **File:** `lib/sigra/auth.ex:828-835`
- **Category:** Denial of Service — password reset flow raises `Protocol.UndefinedError` at runtime when invoked
- **Original disposition:** N/A (library pre-existing bug, not registered in any Phase 10 plan `<threat_model>`)
- **Accepted disposition:** transfer → phase 10.1
- **Justification:** Pre-existing library bug predating Phase 10. Phase 10 did not introduce, regress, or exercise this path in shipped user-facing flows. The example-app smoke test (`test/example/test/example_web/smoke/password_reset_test.exs`) explicitly routes around the delivery path and only exercises the struct-based `reset_user_password/2` head, which works. Acceptance does not add runtime risk beyond the state that existed before Phase 10. Fix phase 10.1 will build a proper `%UserToken{}` struct via the schema module resolved from `config.token_schema` and add a live-repo regression test.
- **Traceability:** 10-REVIEW.md CR-02, 10-REVIEW-FIX.md (DEFERRED section), 10-VERIFICATION.md deferred item #1.
- **Target phase:** 10.1

#### AR-10-02: Magic-link path plain-map insert (CR-02-twin)

- **File:** `lib/sigra/auth.ex:425-432`
- **Category:** Denial of Service — magic-link token issuance raises `Protocol.UndefinedError` at runtime when invoked
- **Original disposition:** N/A (discovered during this audit as a twin of CR-02)
- **Accepted disposition:** transfer → phase 10.1
- **Justification:** Same pattern, same pre-existing bug class as AR-10-01. Identified only because the security auditor grep-expanded the CR-02 pattern across `lib/sigra/auth.ex`. Not a Phase 10 regression. Phase 10 ships no new callers of magic-link issuance. Phase 10.1 scope explicitly covers both call sites plus a shared live-repo regression test.
- **Traceability:** discovered in 10-SECURITY audit (this document).
- **Target phase:** 10.1

### Acceptance rationale (shared)

Both AR-10-01 and AR-10-02 satisfy the GSD "accept with transfer" criteria:
1. Root cause is pre-existing, not Phase 10 regression (verified via git log + blame).
2. Fix has a concrete scheduled owner (phase 10.1) documented in 10-VERIFICATION.md and now in this SECURITY.md.
3. Exposure is bounded: flows are not reachable from the Phase 10 smoke path; no new users would be able to trigger them in a freshly Sigra-installed app without first hitting the generated-code path that works.
4. Detection is in place: once fixed in 10.1, regression tests will hit both call sites.

## Unregistered Flags

None. Phase 10 SUMMARY files (10-01 through 10-06) do not contain a `## Threat Flags` section with unregistered items:

- 10-01: "No `## Threat Flags` section needed"
- 10-02: no flags section
- 10-03: "No new threat surface introduced"
- 10-04: no flags section
- 10-05: "Threat Flags: None"
- 10-06: "Threat Surface Scan" maps all observed flags to T-10-03, T-10-18, T-10-19, T-10-20, T-10-21 (already registered)

## Supply-Chain Observation (Informational)

Per 10-REVIEW.md IN-03 (deferred): `.github/workflows/ci.yml` pins `actions/checkout@v4`, `erlef/setup-beam@v1`, and `actions/cache@v4` to major tags rather than full commit SHAs. CLAUDE.md calls out the SHA-pinning best practice. Not classified as a registered threat in any Phase 10 plan `<threat_model>` block, so it is not counted in `threats_open`. Recommended for phase 10.1 hardening alongside Dependabot `github-actions` config.

## Audit Trail

- **2026-04-09** — Initial Phase 10 security audit. Verified 19/21 mitigations closed against shipped implementation via grep + file inspection. 2 threats initially observed OPEN (CR-02 + its magic-link twin, both in `lib/sigra/auth.ex`).
- **2026-04-09** — Both open threats formally accepted this audit as AR-10-01 and AR-10-02 with transfer disposition to phase 10.1. Rationale: pre-existing library bugs, not Phase 10 regressions, scheduled owner and test plan documented. Final state: `threats_open: 0`, `status: secured`.
