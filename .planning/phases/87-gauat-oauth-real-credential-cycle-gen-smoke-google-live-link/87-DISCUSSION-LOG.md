# Phase 87: GAUAT OAuth real-credential cycle — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 87-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link
**Areas discussed:** Verification posture, Mock OIDC issuer shape & location, Generator fresh-host smoke (GAUAT-03), Playwright spec scope (GAUAT-04/05/06)

**Discussion mode:** One-shot synthesized recommendation set per user instruction ("research using subagents... pros/cons/tradeoffs ... think deeply one-shot a perfect set of recommendations so I don't have to think, all recommendations are coherent/cohesive with each other"). Single load-bearing confirmation question (verification posture); other areas resolved via the synthesized recommendation. Saved as GSD-wide preference in `feedback_discuss_one_shot.md`.

---

## Verification posture (the reshape — load-bearing)

| Option | Description | Selected |
|--------|-------------|----------|
| Confirm: 0 human UAT, ship smoketest task (Recommended) | Posture A. Mock OIDC issuer + Playwright in CI on every PR is Sigra's release gate. `mix sigra.oauth.smoketest --provider=google` ships for adopters to verify their own client_id at install time. Launch language: "tested like Assent / Spring Security / Auth.js test." Strongest SOC 2 posture (continuous evidence). Zero banhammer risk. Matches Phase 86 reshape pattern. | ✓ |
| Hybrid: mock for PRs + 1 human ceremony at v1.20.0 tag | Posture B. Same automation as A on PRs, but add a one-time human-driven real-Google click-through at v1.20.0 tag, captured as dated screenshot bundle. Reads strongest at launch announcement; stale by v1.20.5. Adds ~1 hour to release process. SOC 2-equivalent to A (auditors don't scope one-time ceremonies). | |
| Real Google in tag-only CI job | Posture C. Mock for PRs; on every `v*` tag, run a CI job that drives real Google with a dedicated test user via Playwright. Strongest claim possible. Also most fragile — datacenter-IP bot detection, test-user banhammer, no quoted flakiness rate from anyone who's done it. Unprecedented in mature OSS auth libs. | |

**User's choice:** Posture A (Recommended)

**Notes:** Research finding was unambiguous: zero mainstream OSS auth lib (Assent itself, pow_assent, Auth.js/next-auth, OmniAuth, ueberauth, Spring Security) hits real Google in CI. Auth.js explicitly recommends against it. Playwright + real Google is documented as bot-detection-flagged on GitHub Actions IPs with no quoted flakiness rate. Posture C is unprecedented; Posture B is performative (strongest at launch, stale by v1.20.5; SOC 2 auditors care about control evidence over the period). The real residual ("adopter's specific client_id will work") is properly located in the adopter's environment — solved by `mix sigra.oauth.smoketest`, which converts a marketing weakness into an adopter benefit (strict superset of next-auth/Devise+omniauth/pow_assent/dwyl/elixir-auth-google).

---

## Mock OIDC issuer shape & location

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra.Testing.OAuthIssuer (TestServer-backed) in test/support/ for v0.x | TestServer-wrapping module mirroring Assent's own `OIDCTestCase` (the only proven Elixir-OIDC test seam). RSA fixture, RS256 ID tokens, real PKCE, 5 OIDC endpoints, multi-key JWKS. Built on `test_server ~> 0.1.22` (Schultzer / pow-auth, March 2026). Not promoted to `lib/` until a real adopter asks. | ✓ |
| Inline Bypass-style fake per Playwright spec | Each spec stands up its own Plug-based fake (~30 LOC each). Not reusable. Bypass last released Nov 2020 (legacy in 2026). Duplicates ~30 LOC per spec; "Sigra correctly walks Apple's nonsense ID-token shape" becomes a footnote per spec instead of a tested invariant. | |
| Dockerized navikt/mock-oauth2-server in CI compose | JVM-based, used by enterprise Java/Kotlin shops. Heavy dep (Docker image, JVM, port mgmt, arm64 image). Kills CI hermeticity. Provides nothing the in-process issuer can't for Phase 87's needs. | |

**User's choice:** Sigra.Testing.OAuthIssuer (synthesized recommendation, accepted as part of one-shot rec set)

**Notes:** Mirrors Assent's own `OIDCTestCase` deliberately — the only proven Elixir-OIDC test seam in the ecosystem. Diverging would be inventing protocol; matching gets protocol conformance for free. Footgun mitigations from `mock-oauth2-server` README and Assent precedent: multi-key JWKS for kid-mismatch coverage, real PKCE verification, configurable `exp`, refresh-token rotation toggleable, `email_verified` boolean shape locked. v0.x ships in `test/support/` — adopters don't write new OAuth strategies; promotion to `lib/sigra/testing/oauth_issuer.ex` is deferred until a real adopter asks.

---

## Generator fresh-host smoke (GAUAT-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing scripts/ci/install-smoke.sh | The script already does `mix phx.new` + `sigra.install` + `sigra.gen.oauth` + `mix compile --warnings-as-errors` (verified at lines 90-93). Add `MIX_ENV=test mix test`, emit `oauth-gen: 12/12 expected artifacts present, mix test green` log line, tee transcript. ~105s warm cache, ~3min cold. Zero new CI cost. | ✓ |
| Full mix phx.new in a parallel CI job | Truly fresh, but duplicates ~3min CI per PR for ~0 marginal coverage (existing install-smoke already does the fresh phx.new). Wasteful. | |
| Reuse test/example as the host | Cleanest from CI cost. NOT fresh. Defeats GAUAT-03 "freshly-generated" intent. | |

**User's choice:** Extend install-smoke.sh (synthesized recommendation, accepted as part of one-shot rec set)

**Notes:** Phoenix's own installer suite is *file-emission only* (no compile, no test); Sigra's existing `install-smoke.sh` is already the ecosystem outlier on the strict side. Phase 87 just adds `mix test` and transcript capture. Decompose GAUAT-03 claim: structural ("12 files, routes/config/vault wired") via `test/sigra/install/oauth_generator_test.exs` (every PR, <1s) + live-host ("compiles --warnings-as-errors and `mix test` green") via extended install-smoke (every PR, ~2min, transcript-evidenced). Phoenix-version matrix NOT introduced (cost/benefit doesn't justify); pin `phx_new` archive version explicitly for reproducibility. `installer-milestone-audit.sh` is wrong target (static-grep INT-01..03 contract, not runtime).

---

## Playwright spec scope (GAUAT-04/05/06)

| Option | Description | Selected |
|--------|-------------|----------|
| Three per-GAUAT specs | `oauth-register.spec.ts` (GAUAT-04), `oauth-link.spec.ts` (GAUAT-05 with 4 sub-tests = 4 visual states), `oauth-email-match.spec.ts` (GAUAT-06). Per-file failure isolation; 1:1 with evidence rows. Matches consensus from next-auth E2E, Supabase community E2E, Devise+omniauth. | ✓ |
| One unified oauth-flows.spec.ts (matrix-driven) | Single file mirroring email-visual.spec.ts. Phase 86 precedent. But Phase 86 worked because every cell had the SAME assertion (toHaveScreenshot); GAUAT-04/05/06 have divergent assertions (session+DB / disabled-tooltip+DB-delete / flash-text+redirect+DB+sent-email). Wrong fit. | |
| Extend existing golden-path.spec.ts | Adds OAuth as another step in golden-path. Mixes register/login/MFA with OAuth; harder to run OAuth-only; couples failures across unrelated concerns. | |

**User's choice:** Three per-GAUAT specs (synthesized recommendation, accepted as part of one-shot rec set)

**Notes:** Phase 86's single-file matrix is precedent for *uniform-assertion visual coverage*, not for *behavior tests with per-cell divergence*. File boundaries match evidence boundaries (`.planning/uat-evidence/v1.20/oauth-{google,link,email-match}/`). Per-spec failure isolation worth 2 extra files. Cell minima per GAUAT enumerated in CONTEXT.md D-87-05; deliberately drops state nonce / PKCE content inspection (test the contract, not the cipher), CTA text in linked email (Phase 86 covers email rendering), separate "destination URL" cell for GAUAT-06 (covered by post-login landing assertion). One hero PNG (disabled-tooltip state in GAUAT-05) — the rest are pure behavior assertions.

---

## Folded into the same commit (per user-confirmed reshape, Phase 86 D-86-08 pattern)

- **`mix sigra.oauth.smoketest --provider=google` Mix task** — load-bearing for the launch posture; converts the residual "you never tested real Google" gap into an adopter benefit.
- **`docs/oauth-google-setup.md`** — adopter-facing numbered checklist (Google Cloud Console screenshots + redirect URI + env vars + smoketest invocation).
- **REQUIREMENTS.md GAUAT-03..06 rewording** — replaces "human screen recording / staged screenshots" with the automated harness language.
- **ROADMAP.md Phase 87 success criteria + phase-summary bullet** — same reshape language.
- **`docs/uat-ci-coverage.md` SEED-001 row residual column** — points at `install_smoke` (extended) + `oauth_e2e_playwright` + `mix sigra.oauth.smoketest`.
- **CHANGELOG.md `[Unreleased]`** — verification-approach correction bullet.
- **Controller-level integration test extension** for `oauth_controller.ex` error paths (state mismatch, provider error, no-email) — surfaced as a gap by research.

## Claude's Discretion

- Exact location of `Sigra.Testing.OAuthIssuer` (`test/support/` recommended for v0.x; may move to `lib/` if compile-time-conditional shipping makes more sense — promote only when adopter asks).
- Playwright DB probe shape: test-only `/test/db_probe` JSON endpoint vs. Mix-task probe. Either works.
- `oauthIssuer.ts` fixture API exact shape (Playwright `test.use({ oauthIssuer })` vs. plain helper module). Mirror `mailbox.ts` precedent.
- Whether `mix sigra.oauth.smoketest` opens browser via `:os.cmd("open ...")` or just prints URL and waits. Default: print-and-wait (no platform branching); add `--open-browser` flag later if requested.
- `test_server` version pin (`~> 0.1` or pinned). 0.1.22 is current.
- `phx_new` archive version pin in `install-smoke.sh` — recommended `1.8.5` (current Phoenix minor).
- Whether to ship 4 PNGs (one per GAUAT-05 visual state) or 1 hero PNG (disabled-tooltip only). Research recommended just the disabled-tooltip; planner can decide if 4 PNGs reads better in the README.

## Deferred Ideas

- Promote `Sigra.Testing.OAuthIssuer` to `lib/` as adopter-facing public API (out of v1.20 scope; adopters don't write new OAuth strategies).
- Playwright spec coverage for GitHub / Apple / Facebook providers (issuer is provider-agnostic; GAUAT requirements are Google-only).
- Mocha-style retries for flake mitigation (defer until observed flake; deterministic in-process issuer should not need them).
- `--open-browser` flag for `mix sigra.oauth.smoketest` (defer until interactive devs ask).
- OIDC nonce parameter support (Sigra currently uses state for CSRF; nonce is for ID-token replay — future phase).
- Refresh-token flow Playwright coverage (UI-level; out of v1.20 GAUAT scope).
- Mock issuer with multiple concurrent providers in single test (current GAUAT-05 covers single-provider link/unlink).
- Real-Google CI lane as a sponsor-funded feature (post-launch, in `MAINTAINING.md` "Post-launch monitoring" lane added in Phase 90).
- `mix sigra.oauth.smoketest --provider=github|apple|facebook` (Phase 87 ships Google only).
- `docs/oauth-providers/{google,github,apple,facebook}.md` restructure (single Google doc for now; restructure when more providers land).
