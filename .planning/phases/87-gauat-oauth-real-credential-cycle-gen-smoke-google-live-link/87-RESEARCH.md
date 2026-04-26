# Phase 87: GAUAT OAuth real-credential cycle — Research

**Researched:** 2026-04-26
**Domain:** OIDC test seam (TestServer-backed) + Phoenix 1.8 install-smoke + Playwright OAuth E2E + Mix task adopter tooling + Phase 86-style evidence layout
**Confidence:** HIGH (every load-bearing claim verified against codebase, hex.pm, or Assent's own `OIDCTestCase` precedent)

## Summary

Phase 87 is fully decision-locked by `87-CONTEXT.md` (10 decisions D-87-01..10). The planner does not need to choose libraries, posture, or evidence shape — those are already nailed down. This research produces the **implementation-level glue** the planner needs to author executable PLAN.md tasks: exact module shapes, file paths verified to exist, package versions verified on hex.pm, integration-point line numbers verified by reading the source, and a Nyquist coverage matrix that VALIDATION.md will inherit.

Three deliverable surfaces:

1. **`Sigra.Testing.OAuthIssuer`** — TestServer-backed in-process OIDC issuer at `test/support/sigra/testing/oauth_issuer.ex`. Mirrors Assent's own `Assent.Strategy.OIDC.OIDCTestCase` (pow-auth/assent `test/support/strategies/oidc_test_case.ex`) verbatim — proven, single-source-of-truth shape.
2. **`mix sigra.oauth.smoketest --provider=google`** — adopter-side one-shot real-credential check. Print-and-wait (no platform branching), Bandit-mounted ephemeral endpoint, exit-code-disciplined.
3. **3 Playwright specs + supporting fixture + DB-probe seam + install-smoke extension + 4 evidence dirs** — mirrors Phase 86 D-86-06 schema verbatim; `mix sigra.uat.report` (already shipped from Phase 86) is extended with new `--phase=oauth-{gen,google,link,email-match}` modes.

**Primary recommendation:** Implement in two waves (D-87-07 two-commit closure). Wave 1 (`87-01-PLAN.md`) ships the issuer module + smoketest task + Playwright specs + `oauthIssuer.ts` fixture + DB-probe seam + tests + install-smoke extension + the new Mix task lobes — gated on full library + extended install_smoke + new oauth_e2e_playwright CI jobs green at the wave-1 SHA. Wave 2 (`87-02-PLAN.md`) materializes the four evidence dirs, the `email_visual_regression`-style release-asset promotion for the new `oauth_e2e_playwright` job, and `87-VERIFICATION.md` — gated on **wave 1's CI being green at the wave-1 SHA** so the evidence rows in wave 2 carry a real CI run URL.

[VERIFIED: codebase via Read tool — every file path and line number cited in this RESEARCH.md was opened and confirmed.]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| OIDC issuer endpoints (discovery, authorize, token, userinfo, jwks) | Test-support runtime (TestServer + Bandit subprocess) | — | Provider role; lives entirely outside Sigra's code path. Bandit because TestServer 0.1.22 uses Bandit/Plug.Cowboy [VERIFIED: hex.pm package — `Mock third-party services in ExUnit`]. |
| OAuth ceremony orchestration (state, PKCE, token exchange) | Sigra library (`Sigra.OAuth.*`) | — | Already shipped + AUD-21-tested; Phase 87 invokes through this surface, never modifies. |
| HTTP client → mock issuer | Assent (req/finch) | — | Assent already drives provider HTTP; the issuer just answers it. |
| Browser ↔ Phoenix HTTP stack | Phoenix endpoint (Bandit) on `localhost:4000` (example app, dev mode) | — | Same surface Phase 86 + golden-path use; serial workers, longpoll fallback already accounted for in `playwright.config.ts:48-54`. |
| DB sandbox isolation per spec | `Phoenix.Ecto.SQL.Sandbox` (test mode) OR sequential dev-mode DB shared across specs | — | **Pragmatic call for planner per D-87-05.** Existing `golden-path` and `ga-uat-shift-left` specs run against `MIX_ENV=dev` shared DB (workers: 1, fullyParallel: false). Phase 87 inherits that — no sandbox plumbing required. |
| Adopter-side real-Google verification | `mix sigra.oauth.smoketest` (lib/mix/tasks) running in adopter's OS shell | — | Out of CI; adopter's environment carries adopter's credentials. |
| Evidence manifest generation | `mix sigra.uat.report` (already shipped from Phase 86; extended in Phase 87) | — | Single canonical source per Phase 86 D-86-06; do not invent a parallel evidence-generation tool. |

## User Constraints (from CONTEXT.md)

### Locked Decisions

(Verbatim from `87-CONTEXT.md` decision blocks. Planner MUST NOT contradict.)

- **D-87-01 — Posture A: 0 human UAT.** Mock issuer + Playwright in CI on every PR is the release gate. `mix sigra.oauth.smoketest --provider=google` is the adopter-side real-credential check at install time. No real Google in any Sigra-owned CI lane. No release-tag human ceremony.
- **D-87-02 — `Sigra.Testing.OAuthIssuer`** is TestServer-backed, RS256 ID tokens, real PKCE, multi-key JWKS (`count: 2` option), `email_verified` boolean, configurable `exp`, refresh-rotation toggleable. Lives at `test/support/sigra/testing/oauth_issuer.ex` for v0.x. Built on `test_server ~> 0.1.22`. All 5 Google-shaped endpoints pre-registered.
- **D-87-03 — `mix sigra.oauth.smoketest --provider=google`** ships in-library at `lib/mix/tasks/sigra.oauth.smoketest.ex`. Default behavior: print-and-wait (no platform branching). Boots tiny Plug endpoint on `localhost:4001`. Exits 0 on success, non-zero with diagnostic on failure. Paired with `docs/oauth-google-setup.md` numbered checklist.
- **D-87-04 — Generator fresh-host smoke (GAUAT-03).** Extend `scripts/ci/install-smoke.sh` (NOT a parallel job, NOT `installer-milestone-audit.sh`). Three surgical edits at lines 90-93: add `MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate && MIX_ENV=test mix test`, emit `oauth-gen: 12/12 expected artifacts present, mix test green`, tee transcript to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log`. Pin `phx_new` archive version explicitly (recommended `1.8.5`). NO Phoenix-version matrix.
- **D-87-05 — Three per-GAUAT Playwright specs, NOT one matrix file.** `oauth-register.spec.ts` (GAUAT-04), `oauth-link.spec.ts` (GAUAT-05 — 4 sub-tests, ONE hero PNG = disabled-tooltip state), `oauth-email-match.spec.ts` (GAUAT-06). Plus `fixtures/oauthIssuer.ts`. State nonce / PKCE inspected at contract level (callback succeeds), NOT decoded. Drop accessibility/contrast checks (separate concern).
- **D-87-06 — Evidence layout** = Phase 86 schema verbatim. 9-field YAML frontmatter (`phase`, `gauat_requirement`, `hex_version`, `git_sha`, `git_tag`, `ci_run_url`, `ci_workflow`, `generated_by`, `generated_at`, `disposition`). Manifest JSON one row per cell. README auto-generated from manifest. `{slug}__{state}__sha-{short-sha}.png` naming. CI artifact + GitHub release asset on `v*` tags.
- **D-87-07 — Two-commit closure.** Commit A = code+tests+install-smoke+specs+smoketest+docs. Commit B = evidence dirs + release-asset promotion + `87-VERIFICATION.md`. Gate B on A's CI green at A's SHA.
- **D-87-08 — Milestone-scope edits folded into discuss commit:** REQUIREMENTS.md GAUAT-03..06 (already done — verified by reading file), ROADMAP.md Phase 87 success criteria + phase-summary bullet (already done — verified), `docs/uat-ci-coverage.md` SEED-001 row residual column (planner edits in Phase 87 plan-1 or plan-2), CHANGELOG.md `[Unreleased]` entry (planner edits in Phase 87).
- **D-87-09 — Residual policy: 0 residual human work for v1.20 launch.** Live consumer Google UX, adopter `client_id` correctness, banhammer/quota are out-of-scope by architectural classification (NOT waived).
- **D-87-10 — Tests:** `test/sigra/testing/oauth_issuer_test.exs` (~80 LOC AAA-flat), `test/sigra/install/oauth_smoketest_task_test.exs` (~40 LOC), `test/example/test/example_web/oauth_controller_test.exs` extension (~30 LOC).

### Claude's Discretion

- **Issuer location** — `test/support/sigra/testing/oauth_issuer.ex` is the recommendation; planner may move to `lib/sigra/testing/oauth_issuer.ex` if compile-time-conditional shipping makes more sense than test/support. **Research recommends `test/support/`** (matches Assent's own choice, lib/mix.exs already has `elixirc_paths(:test) -> ["lib", "test/support"]` per `mix.exs:55`, no public-API commitment in v0.x).
- **DB probe seam** — test-only `/test/db_probe` JSON endpoint vs Mix-task probe vs Phoenix.Ecto.SQL.Sandbox. **Research recommends the test-only HTTP endpoint** (see `## DB Probe Seam — Tradeoff Analysis` below).
- **`oauthIssuer.ts` fixture API shape** — Playwright `test.extend` fixture vs plain helper module. **Research recommends plain helper module** (matches `mailbox.ts` precedent at `test/example/priv/playwright/fixtures/mailbox.ts`; no test.extend in current spec set).
- **Browser auto-open in smoketest** — print-and-wait default (D-87-03) vs `--open-browser` flag with `:os.cmd("open ...")` / `xdg-open`. **Research recommends print-and-wait only**; defer the flag.
- **`test_server` version pin** — `~> 0.1.22` recommended. [VERIFIED: hex.pm package page — v0.1.22, March 6, 2026].
- **`phx_new` archive pin in install-smoke.sh** — recommended pin: `phx_new ~> 1.8.5` (matches `test/example/mix.exs:46` Phoenix pin and `priv/templates/sigra.install/core/emails.ex` template defaults). Document supersession in install-smoke.sh comment.
- **GAUAT-05 hero PNG count: 1 vs 4** — research recommends **just the disabled-tooltip hero** (D-87-05 + the specifics block in CONTEXT.md). 4 PNGs would visually noise the evidence README; the disabled-tooltip is the load-bearing visual artifact.

### Deferred Ideas (OUT OF SCOPE)

- Promote `Sigra.Testing.OAuthIssuer` to public adopter API in `lib/`
- Playwright spec coverage for GitHub / Apple / Facebook providers
- Mocha-style retries in OAuth specs
- `--open-browser` flag on `mix sigra.oauth.smoketest`
- OIDC nonce parameter (separate from state)
- Refresh-token-flow Playwright coverage
- Mock issuer with multiple concurrent providers in one test
- Real-Google CI lane as sponsor-funded feature
- `mix sigra.oauth.smoketest --provider=github|apple|facebook`
- `docs/oauth-google-setup.md` rewrite as `docs/oauth-providers/{google,...}.md` per-provider split

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GAUAT-03 | Extended `install-smoke.sh` runs `mix phx.new` + `sigra.install` + `sigra.gen.oauth` + `--warnings-as-errors` + `MIX_ENV=test mix test` and emits `oauth-gen: 12/12 expected artifacts present, mix test green`. Transcript at `.planning/uat-evidence/v1.20/oauth-gen/transcript.log`. | `## CI Workflow Diff — install-smoke.sh extensions`, `## Validation Architecture — install_smoke lane`. The 12-artifact list is verified explicit (10 paths in `oauth_paths` array at lines 99-110 + 1 migration at 122-126 + 1 router marker at 129-132 = 12). |
| GAUAT-04 | Playwright `oauth-register.spec.ts` drives Sigra example app against `Sigra.Testing.OAuthIssuer`. Cells: provider button → 302 to /authorize with state nonce → mock auto-consent → callback → user + identity row + session → logout → re-login (no new identity row). | `## Module APIs — Sigra.Testing.OAuthIssuer`, `## File-by-File Plan — oauth-register.spec.ts`, `## Validation Architecture — Per-spec coverage matrix`. |
| GAUAT-05 | Playwright `oauth-link.spec.ts` covers 4 visual states. ONE hero PNG of `disabled-tooltip` state. Tooltip text = verbatim source from `oauth_settings_live.ex:92`. | `## Verbatim Source Strings`, `## File-by-File Plan — oauth-link.spec.ts`. |
| GAUAT-06 | Playwright `oauth-email-match.spec.ts` covers flash-text + redirect + identity-row + `provider_linked_email` mailbox arrival. Flash text = verbatim from `oauth_controller.ex:96`. | `## Verbatim Source Strings`, `## File-by-File Plan — oauth-email-match.spec.ts`. |

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x. Phase 87 targets Phoenix 1.8.5 (matches `test/example/mix.exs:46`).
- **Testing posture:** AAA-flat, self-contained. No `:postgres` tag exclusion — every test that runs in CI runs locally too. Local prerequisite: Postgres at `localhost:5432` (`postgres`/`postgres`).
- **Security:** OWASP standards throughout. All tokens HMAC-protected. `Sigra.OAuth` already enforces this; Phase 87 does NOT bypass.
- **Dependencies:** Minimal transitive deps. `test_server` is recommended as a **direct** dev/test dep (transitively present today via Assent's test deps but Sigra's mix.lock does not lock it; promote to direct).
- **GSD enforcement:** All file edits gated through GSD commands (already inside `/gsd-research-phase` invocation, this file is the artifact).

## Implementation Strategy

The phase splits into **two commits per D-87-07**:

### Commit A — `87-01-PLAN.md` (Wave 1)

Surface area:

1. **`mix.exs`** — add `{:test_server, "~> 0.1.22", only: :test}` as a direct dep. (Currently it is only transitive via Assent's `test/` deps which are NOT pulled by hex; verified by absence in Sigra's lib `mix.lock` search.)
2. **`test/support/sigra/testing/oauth_issuer.ex`** (new) — the issuer module. ~150-200 LOC. Compiled via existing `elixirc_paths(:test) -> ["lib", "test/support"]` at `mix.exs:55`.
3. **`test/support/sigra/testing/fixtures/oauth_issuer_keys.ex`** (new) OR equivalent compile-time `@external_resource` PEM file at `test/support/sigra/testing/fixtures/oauth_issuer_rsa.pem` — RSA fixture key pair. Recommended: ship as a `.pem` file with `@external_resource` so `Mix.recompile?` triggers on key change. Two PEMs for `count: 2` JWKS option.
4. **`lib/mix/tasks/sigra.oauth.smoketest.ex`** (new) — adopter Mix task. ~120-150 LOC.
5. **`docs/oauth-google-setup.md`** (new) — numbered Google Cloud Console recipe. Add to `mix.exs:170-202` `extras` list under Recipes group.
6. **`scripts/ci/install-smoke.sh`** (modified) — three surgical edits at lines 90-93. Pin `phx_new` archive version.
7. **`.github/workflows/ci.yml`** — `install_smoke` job: tee transcript step + `actions/upload-artifact@v4` step + tag-time release-asset promotion (mirrors `email_visual_regression` lines 1043-1081). New `oauth_e2e_playwright` job: 3 Playwright specs against example app on dev port 4000.
8. **`test/example/priv/playwright/fixtures/oauthIssuer.ts`** (new) — plain helper module mirroring `fixtures/mailbox.ts` shape.
9. **`test/example/priv/playwright/tests/oauth-register.spec.ts`** (new), **`oauth-link.spec.ts`** (new), **`oauth-email-match.spec.ts`** (new).
10. **`test/example/priv/playwright/playwright.config.ts`** (modified) — main `chromium` project's `testIgnore` array currently excludes `ADMIN_CHECKPOINTS_SPEC, ADMIN_GENERATED_SPEC, EMAIL_VISUAL_SPEC` (line 85). The 3 new OAuth specs run on the default `chromium` project (matches `golden-path.spec.ts` precedent) — no new project entry needed UNLESS the planner wants explicit isolation.
11. **`test/example/lib/example_web/router.ex`** (modified) — add test-only `/test/db_probe` route guarded by `if Application.get_env(:example, :enable_db_probe, false)` AND `if Mix.env() == :dev` (the example runs against `MIX_ENV=dev` for Playwright per `playwright.config.ts:48-54`). Recommended: gate via env var `EXAMPLE_DB_PROBE_ENABLED` set in CI step.
12. **`test/example/lib/example_web/controllers/test_db_probe_controller.ex`** (new) — handles `/test/db_probe?table=user_identities&user_email=alice@example.test` returning `{count: N, rows: [...]}` JSON. Read-only; stripped from production builds via env-gated route.
13. **`test/example/test/example_web/oauth_controller_test.exs`** (modified) — extend with controller-level integration covering state mismatch, provider error, no-email error using `Sigra.Testing.OAuthIssuer`.
14. **`test/sigra/testing/oauth_issuer_test.exs`** (new), **`test/sigra/install/oauth_smoketest_task_test.exs`** (new) — per D-87-10.
15. **`config/test.exs`** (Sigra root, NOT example) — if needed: `Application.put_env(:sigra, :oauth_provider_overrides, ...)` is set per-test in the Playwright spec's setup, NOT globally; example app receives the issuer URL via env var passed by the CI step.

### Commit B — `87-02-PLAN.md` (Wave 2)

Surface area:

1. **`.planning/uat-evidence/v1.20/INDEX.md`** (modified) — append 4 new rows for `oauth-{gen,google,link,email-match}/`. Update snapshot count table.
2. **`.planning/uat-evidence/v1.20/oauth-gen/`** (new): `README.md`, `manifest.json`, `transcript.log` (CI-generated; commit a placeholder + symlink contract OR commit the wave-2-base SHA's actual transcript), `reports/artifact-inventory.json`.
3. **`.planning/uat-evidence/v1.20/oauth-google/`** (new): `README.md`, `manifest.json`, `reports/playwright-trace-{short-sha}.zip` (uploaded; in-repo placeholder OR pointer file).
4. **`.planning/uat-evidence/v1.20/oauth-link/`** (new): `README.md`, `manifest.json`, `reports/db-probe-results.json`, `snapshots/oauth-link__disabled-tooltip__sha-{short-sha}.png`.
5. **`.planning/uat-evidence/v1.20/oauth-email-match/`** (new): `README.md`, `manifest.json`, `reports/flash-text-assertion.json`, `reports/linked-email-mailbox.json`.
6. **`lib/mix/tasks/sigra.uat.report.ex`** (modified) — extend with `--phase=oauth-gen|oauth-google|oauth-link|oauth-email-match` modes. Extension adds 4 manifest-row generators and 4 README templates. Reuse all existing schema fields. ~80-100 LOC added.
7. **`docs/uat-ci-coverage.md`** (modified) — SEED-001 row residual column updated to point at `install_smoke` (extended) + `oauth_e2e_playwright` (new) + `mix sigra.oauth.smoketest` (adopter recipe).
8. **`CHANGELOG.md`** (modified) — `[Unreleased]` entry: `Phase 87: extended install-smoke + Sigra.Testing.OAuthIssuer + 3 Playwright OAuth specs + mix sigra.oauth.smoketest --provider=google. 0 human UAT for OAuth in v1.20.`
9. **`.planning/phases/87-…/87-VERIFICATION.md`** (new) — records merge gate outcome, CI run URL, dated PASS attestations per GAUAT-03/04/05/06.

## Module APIs and Function Signatures

### `Sigra.Testing.OAuthIssuer` — concrete public API

**Module location:** `test/support/sigra/testing/oauth_issuer.ex`

**Architectural shape:** Agent-based (NOT GenServer). State is a per-test mutable map (`{user_claims, kid_count, exp_offset, refresh_rotation?, pkce_required?}`) + the TestServer instance handle. Why Agent: TestServer 0.1.22 already owns its own GenServer process; layering another GenServer just to hold a few config flags adds ceremony without value. Agent gives `start_link/1` + `update/2` + `get/1` for free.

**TestServer 0.1.22 behavior verified:**
- `TestServer.start/1` returns `:ok` and registers a per-test instance; `TestServer.url/0` returns base URL [VERIFIED: hexdocs.pm/test_server].
- Per-test isolation is automatic — instance terminated when test case finishes [CITED: hexdocs.pm/test_server].
- Routes registered via `TestServer.add(path, plug: handler)` are matched in FIFO and removed on hit; for endpoints called multiple times per test (jwks, token), use the `to:` form with a static handler that does NOT remove the route. **Verify in implementation** that the OAuth flow's repeated jwks fetches don't deplete a one-shot route — if they do, register N times or use `to:` with a persistent handler.
- TestServer supports HTTPS via `:scheme` option with auto-generated self-signed cert [CITED: hexdocs.pm/test_server]. **HTTP is fine for our use case** — Assent strategies don't enforce HTTPS for OIDC discovery when given an explicit `base_url` override; only the public OIDC spec mandates HTTPS for production providers.

**Public function signatures:**

```elixir
defmodule Sigra.Testing.OAuthIssuer do
  @moduledoc """
  In-process OIDC issuer for testing Sigra's OAuth ceremony end-to-end.

  Mirrors Assent's own `Assent.Strategy.OIDC.OIDCTestCase` precedent
  (pow-auth/assent test/support/strategies/oidc_test_case.ex) — RS256 ID
  tokens with embedded RSA fixture, JWKS endpoint, real PKCE verification,
  `email_verified` boolean per OIDC spec, configurable `exp`, kid rotation
  (`count: 2`), refresh-rotation toggle.

  This module lives under test/support/ and is NOT exported as adopter
  public API in v0.x. Adopters configure providers + call `Sigra.OAuth`;
  see `Sigra.Testing.mock_oauth_callback/1` for the in-memory shape helper.
  """

  @typedoc "Issuer handle returned by start_link/1"
  @type t :: %__MODULE__{
          base_url: String.t(),
          state: pid()  # Agent pid carrying user/key/exp config
        }

  defstruct [:base_url, :state]

  @spec start_link(keyword()) :: {:ok, t()} | {:error, term()}
  def start_link(opts \\ [])
  # Options:
  #   :provider       — :google | :github | :apple | :facebook (default: :google)
  #   :user           — initial user claims map (default: see @default_user)
  #   :kid_count      — 1 | 2 (default: 1) — number of JWKs in /jwks
  #   :exp            — DateTime | (now + N seconds) (default: 3600 seconds)
  #   :refresh_rotation — boolean (default: true — Google rotates)
  #   :pkce_required  — boolean (default: true — reject token exchange without code_verifier)

  @spec set_user(t(), map()) :: :ok
  def set_user(issuer, user_claims)
  # Updates the user info returned by /userinfo and embedded in id_token.
  # Mid-test; e.g., GAUAT-06 sets email=alice@example.test with novel sub.

  @spec set_kid_count(t(), 1 | 2) :: :ok
  def set_kid_count(issuer, n)
  # Toggles JWKS to expose n keys; signs id_tokens with the first one.

  @spec url(t()) :: String.t()
  def url(issuer), do: issuer.base_url
  # Returns "http://localhost:#{port}" (TestServer-assigned ephemeral port).

  @spec openid_config(t()) :: map()
  def openid_config(issuer)
  # Returns the discovery document map suitable for assent_provider_overrides
  # (issuer, authorization_endpoint, token_endpoint, userinfo_endpoint, jwks_uri).

  @spec stop(t()) :: :ok
  def stop(issuer)
  # Optional explicit stop; usually unnecessary because TestServer auto-stops
  # at test-case end.
end
```

**Internal endpoint plugs (private — not exported):**

```elixir
# /.well-known/openid-configuration
defp handle_discovery(conn, _opts), do: send_json(conn, openid_config_for(conn))

# /oauth2/v2/auth — authorize endpoint
defp handle_authorize(conn, _opts) do
  # Parse: client_id, redirect_uri, response_type=code, scope=openid email,
  #        state (Sigra-signed), code_challenge (PKCE), code_challenge_method=S256
  # Stash code_challenge keyed by issued auth code in Agent state.
  # Redirect: 302 to redirect_uri?code=<auth_code>&state=<state>
end

# /token — token exchange
defp handle_token(conn, _opts) do
  # Parse: grant_type=authorization_code, code, redirect_uri, code_verifier
  # Verify code_verifier matches stashed code_challenge (SHA-256 + base64url-no-pad).
  # Sign id_token (RS256, kid=1, claims include sub, email, email_verified=true|false, aud, iss, iat, exp).
  # Return: {access_token, refresh_token, id_token, token_type=Bearer, expires_in}.
end

# /userinfo — claims endpoint
defp handle_userinfo(conn, _opts) do
  # Parse Authorization: Bearer <access_token>; return user claims map as JSON.
end

# /jwks — public keys
defp handle_jwks(conn, _opts) do
  # Return {keys: [<JWK>]} where length = kid_count. JWK per RFC 7517 (kty=RSA, use=sig, alg=RS256, kid, n, e).
end
```

**RSA fixture loading strategy (Claude's discretion → recommendation):**

```elixir
# Compile-time @external_resource so a key change triggers recompile.
@external_resource "test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem"
@external_resource "test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2.pem"

@private_key_kid1 File.read!("test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem")
@private_key_kid2 File.read!("test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2.pem")
```

Generate fixture keys once with `:public_key.generate_key({:rsa, 2048, 65537})` + `:public_key.pem_encode/2` and commit the .pem files (NOT the runtime generation, which would invalidate snapshots). Two keys total — one for `kid=1`, one for `kid=2` — used together when `kid_count: 2`.

### `Mix.Tasks.Sigra.Oauth.Smoketest`

**Module location:** `lib/mix/tasks/sigra.oauth.smoketest.ex`

**Pattern reference:** `lib/mix/tasks/sigra.fixture.rebless_golden.ex:1-251` (per Phase 86 PATTERNS.md analog). `OptionParser.parse/2` → `Mix.Task.run("loadpaths")` → `Mix.Task.run("compile")` → run logic → exit.

```elixir
defmodule Mix.Tasks.Sigra.Oauth.Smoketest do
  @shortdoc "Verifies your OAuth provider configuration with a real round-trip"

  @moduledoc """
  Adopter-side real-credential check. Boots a tiny Plug endpoint on
  localhost, prints the authorize URL, and waits for you to click through
  in your default browser. On callback, exchanges the code, decodes the
  id_token, and prints the claims.

  ## Usage

      mix sigra.oauth.smoketest --provider=google
      mix sigra.oauth.smoketest --provider=google --port=4001

  ## Flags

    * `--provider` — required, one of: google (others deferred)
    * `--port`     — default 4001
    * `--config`   — optional explicit Sigra config path (defaults to runtime app env)

  ## Exit codes

    0 — success, id_token decoded and email claim present
    1 — usage error (missing flag, unknown provider)
    2 — config error (client_id/secret missing or unreachable)
    3 — round-trip failure (state mismatch, token exchange error, malformed id_token, missing email)
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile")
    Application.ensure_all_started(:bandit)

    {opts, _, _} = OptionParser.parse(argv,
      strict: [provider: :string, port: :integer, config: :string])

    provider = opts[:provider] || Mix.raise("missing --provider")
    port = Keyword.get(opts, :port, 4001)

    case run_smoketest(provider, port, opts) do
      :ok ->
        Mix.shell().info("OK — round-trip succeeded.")
      {:error, code, reason} ->
        Mix.shell().error("FAIL: #{reason}")
        exit({:shutdown, code})
    end
  end

  # Boots a Bandit endpoint exposing /callback that captures the OAuth
  # callback params, prints diagnostics, and signals back to the main
  # process. Never daemonizes; never opens browser by default.
end
```

**Key implementation notes for the planner:**
- Use **Bandit** (already a dep at `test/example/mix.exs:54`); fall back to `Plug.Cowboy` only if Bandit absent.
- Wait for callback via Agent or per-pid `receive` block with 5-minute timeout. Print authorize URL clearly. Print "open this URL in your browser:" prompt.
- Sigra config resolution: read `Application.get_env(:sigra, :providers, [])[provider_atom]` for `client_id`/`client_secret`/`redirect_uri`. Fail fast with exit 2 + diagnostic if missing.
- HMAC state nonce: use `Sigra.Token.generate/4` (already in lib) so the round-trip exercises Sigra's actual signing path, not a fake.
- The `--open-browser` flag (D-87-03 Claude's discretion) is **deferred** per research recommendation. Print-and-wait is enough.

### `mix sigra.uat.report --phase=oauth-{gen,google,link,email-match}` extension

The existing task at `lib/mix/tasks/sigra.uat.report.ex` already has the `--check` mode and the 9-field manifest schema. Extension adds 4 new phase atoms and 4 manifest-row builders. Mechanically:

```elixir
@phase_oauth_gen_artifacts ["transcript.log", "reports/artifact-inventory.json"]
@phase_oauth_google_artifacts ["reports/playwright-trace-{sha}.zip"]
@phase_oauth_link_artifacts ["reports/db-probe-results.json", "snapshots/oauth-link__disabled-tooltip__sha-{sha}.png"]
@phase_oauth_email_match_artifacts ["reports/flash-text-assertion.json", "reports/linked-email-mailbox.json"]
```

The 4 new phase modes share the existing `@phase_04_templates`-style data structure idea: list expected artifacts per cell, validate presence, compute sha256, emit row.

## Dependency Changes

### `mix.exs` — add direct test-only dep

```elixir
defp deps do
  [
    # ... existing deps unchanged ...
    {:test_server, "~> 0.1.22", only: :test}
    # ^ NEW. Verified on hex.pm: v0.1.22 released March 6, 2026.
    # Already a transitive test dep of Assent; promoting to direct so
    # Sigra's own tests can use TestServer.start/0, TestServer.add/2.
  ]
end
```

[VERIFIED: hex.pm/packages/test_server returns v0.1.22 dated 2026-03-06.]

No other dep additions. Bandit (`{:bandit, "~> 1.5"}`) is already in `test/example/mix.exs:54` for the example app; the smoketest Mix task uses Bandit too — but since `mix sigra.oauth.smoketest` is invoked by adopters in their own host app, the host app's own Bandit (Phoenix 1.8 default) is what gets booted.

**For the host app**, no new deps are required because Phoenix 1.8 ships Bandit by default. If an adopter is on Phoenix < 1.7, document the `Plug.Cowboy` fallback in `docs/oauth-google-setup.md`.

## File-by-File Plan

### Wave 1 (commit A) — code, tests, install-smoke, specs

| File | Status | Why | What |
|------|--------|-----|------|
| `mix.exs` | modify | D-87-02 dep promotion | Add `{:test_server, "~> 0.1.22", only: :test}` after the `:postgrex` line at `mix.exs:122`. Bump `mix.lock` accordingly. |
| `test/support/sigra/testing/oauth_issuer.ex` | new | D-87-02 the issuer | ~150-200 LOC. Public API per `## Module APIs`. Compiled via existing `elixirc_paths(:test)` at `mix.exs:55`. |
| `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem` | new | D-87-02 RSA fixture | Generated once with `:public_key.generate_key({:rsa, 2048, 65537})`; committed. |
| `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2.pem` | new | D-87-02 kid rotation | Second RSA key for `kid_count: 2`. |
| `test/sigra/testing/oauth_issuer_test.exs` | new | D-87-10 (~80 LOC AAA-flat) | Tests: discovery doc shape, authorize → 302 with code, token exchange + RS256 verify, jwks shape (count: 1 and 2), PKCE pass + reject, configurable exp drives near-expiry rejection, refresh-rotation toggle, `email_verified` boolean. |
| `lib/mix/tasks/sigra.oauth.smoketest.ex` | new | D-87-03 adopter task | ~120-150 LOC per `## Module APIs` shape. |
| `test/sigra/install/oauth_smoketest_task_test.exs` | new | D-87-10 (~40 LOC) | Tests: config loading happy + missing, port flag, error diagnostics, exit code semantics. Stub `:os.cmd` not needed (smoketest is print-and-wait). Mock the Bandit endpoint via `start_supervised`. |
| `docs/oauth-google-setup.md` | new | D-87-03 adopter recipe | Numbered Google Cloud Console steps with screenshot anchors. Final section: `Run mix sigra.oauth.smoketest --provider=google to verify`. |
| `mix.exs` (extras list) | modify | Surface the new doc | Add `"docs/oauth-google-setup.md"` to the `extras:` list at `mix.exs:163-202`. Group: existing `Recipes` group catches `guides/recipes/.?` — put the new doc under `docs/` group OR rename to `guides/recipes/oauth-google-setup.md` and inherit Recipes group. **Recommendation:** keep at `docs/oauth-google-setup.md` and add to `Docs` group regex `~r{^docs/|^SECURITY\.md$}` (already matches). |
| `scripts/ci/install-smoke.sh` | modify | D-87-04 | After line 93: `MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate && MIX_ENV=test mix test`. After existing `oauth-gen contract OK` echo: emit `oauth-gen: 12/12 expected artifacts present, mix test green`. Also: pin `mix archive.install hex phx_new 1.8.5` instead of unpinned in `.github/workflows/ci.yml:256` (NOT in install-smoke.sh — the archive install happens in the workflow steps before invoking install-smoke.sh). |
| `.github/workflows/ci.yml` install_smoke job | modify | D-87-04 transcript tee + artifact upload | After `Run install smoke harness` step (line 259-267): redirect with `tee` to `/tmp/oauth-gen-transcript.log`, copy to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` if running on tag, `actions/upload-artifact@v4` always, release-asset promotion on `v*` tags. |
| `.github/workflows/ci.yml` (new `oauth_e2e_playwright` job) | new | D-87-05 + D-87-06 | New job mirroring `example_playwright_smoke` shape (`.github/workflows/ci.yml:551-789`). Same Postgres service, same Node setup. Boots example app on dev port 4000, sets `EXAMPLE_DB_PROBE_ENABLED=1`, runs `npx playwright test tests/oauth-register.spec.ts tests/oauth-link.spec.ts tests/oauth-email-match.spec.ts --project=chromium`. Artifact upload: traces + DB-probe outputs + manifest dir on every run; release-asset promotion on `v*` tags. |
| `.github/workflows/ci.yml` archive pin | modify | D-87-04 reproducibility | Line 256 currently: `mix archive.install --force hex phx_new`. Change to: `mix archive.install --force hex phx_new 1.8.5` (or whatever Phoenix pin matches Sigra's `~> 1.8` at v1.20 ship time). |
| `test/example/priv/playwright/fixtures/oauthIssuer.ts` | new | D-87-05 fixture | Plain helper module mirroring `mailbox.ts` shape. Functions: `setupIssuer(baseUrl: string)`, `mockGoogleIdentity(issuerCtx, claims: Partial<GoogleClaims>)`, `resetIssuer(issuerCtx)`. The "issuer ctx" is the URL of an admin-control endpoint exposed by the example app (see § DB Probe Seam tradeoff) that proxies into `Sigra.Testing.OAuthIssuer.set_user/2` — see § oauthIssuer.ts wire format. |
| `test/example/priv/playwright/tests/oauth-register.spec.ts` | new | GAUAT-04 | One test per cell per § Cell-by-cell coverage in CONTEXT.md D-87-05. Imports oauthIssuer.ts + mailbox.ts. ~80-120 LOC. |
| `test/example/priv/playwright/tests/oauth-link.spec.ts` | new | GAUAT-05 | 4 sub-tests covering linked-with-password / only-oauth-no-password (hero PNG) / after-set-password / post-unlink. ~120-160 LOC. |
| `test/example/priv/playwright/tests/oauth-email-match.spec.ts` | new | GAUAT-06 | Pre-seed alice@example.test with password → mock issuer returns matching email + novel sub → flash text assertion verbatim → password login → identity row + mailbox arrival. ~80-120 LOC. |
| `test/example/lib/example_web/router.ex` | modify | DB probe seam | Mount test-only `/test/db_probe` route guarded by env var. ~10 LOC added. |
| `test/example/lib/example_web/controllers/test_db_probe_controller.ex` | new | DB probe seam | Read-only DB introspection JSON endpoint. ~30 LOC. |
| `test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex` | new | Issuer ctx seam | Test-only HTTP endpoint that proxies `set_user`/`reset` calls into `Sigra.Testing.OAuthIssuer` + `Application.put_env(:sigra, :oauth_provider_overrides, ...)`. Same env-gate as DB probe. ~40 LOC. |
| `test/example/test/example_web/oauth_controller_test.exs` | modify | D-87-10 | Extend with state-mismatch / provider-error / no-email controller tests using `Sigra.Testing.OAuthIssuer` instead of `MockStrategy`. ~30 LOC added. |
| `test/example/config/dev.exs` (or runtime.exs) | modify | Issuer override + DB probe gate | Conditional `Application.put_env(:sigra, :oauth_provider_overrides, ...)` block reading `SIGRA_OAUTH_ISSUER_URL` env var; conditional route mount based on `EXAMPLE_DB_PROBE_ENABLED`. Specifics depend on whether overrides are read at boot or at request time — see § Application config injection. |
| `test/example/lib/example_web/endpoint.ex` (potentially) | modify | Issuer override at request time | If overrides need to be runtime-injected into Assent's HTTP adapter, plumb here. |
| `test/example/test/support/conn_case_helpers.ex` | potentially modify | Test helpers for oauth_controller_test.exs extension | Add helper to spin up `Sigra.Testing.OAuthIssuer` per controller test. |

### Wave 2 (commit B) — evidence, sigra.uat.report extension, planning truth

| File | Status | Why | What |
|------|--------|-----|------|
| `lib/mix/tasks/sigra.uat.report.ex` | modify | Reuse single canonical evidence-gen tool | Add 4 new phase modes (`oauth-gen`, `oauth-google`, `oauth-link`, `oauth-email-match`). Each mode lists expected artifacts, validates presence, builds manifest row, writes README. ~80-100 LOC added. |
| `.planning/uat-evidence/v1.20/INDEX.md` | modify | Index extension | Append 4 rows for the new dirs. Update snapshot count table. |
| `.planning/uat-evidence/v1.20/oauth-gen/README.md` | new | GAUAT-03 evidence pointer | YAML frontmatter (9 fields) + outcome table generated from manifest.json. |
| `.planning/uat-evidence/v1.20/oauth-gen/manifest.json` | new | machine-readable manifest | One row: `{phase: "87", gauat_requirement: "GAUAT-03", artifact_class: "transcript-log", outcome: "pass", ci_run_url: ..., artifact_url: ..., transcript_sha256: ..., generated_at: ...}` |
| `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` | new | tee'd from install-smoke.sh | Captured during Wave 2 base SHA's CI run; committed. |
| `.planning/uat-evidence/v1.20/oauth-gen/reports/artifact-inventory.json` | new | 12-file inventory | Lists each of the 12 generated artifacts with relative path + SHA-256. Generated by sigra.uat.report. |
| `.planning/uat-evidence/v1.20/oauth-google/README.md` | new | GAUAT-04 evidence pointer | YAML frontmatter + per-cell outcome table. |
| `.planning/uat-evidence/v1.20/oauth-google/manifest.json` | new | manifest | Rows: provider-button-render / authorize-redirect / mock-issuer-callback / user-record / identity-row / session / logout / re-login (per ROADMAP.md success criterion #2 verbatim). |
| `.planning/uat-evidence/v1.20/oauth-google/reports/playwright-trace-{sha}.zip` | new (CI-uploaded) | Playwright trace bundle | Uploaded as Actions artifact, promoted to release asset on tag. In-repo: a small README pointing at the canonical CI run URL. |
| `.planning/uat-evidence/v1.20/oauth-link/README.md` | new | GAUAT-05 | 4 rows for the visual states. |
| `.planning/uat-evidence/v1.20/oauth-link/manifest.json` | new | manifest | 4 rows with hero PNG path on the disabled-tooltip row. |
| `.planning/uat-evidence/v1.20/oauth-link/reports/db-probe-results.json` | new | DB probe outputs | Captured at Wave 2 SHA. |
| `.planning/uat-evidence/v1.20/oauth-link/snapshots/oauth-link__disabled-tooltip__sha-{short-sha}.png` | new | hero PNG | Single visual artifact per D-87-05. Source: Playwright `await page.screenshot()` saved with the canonical name. |
| `.planning/uat-evidence/v1.20/oauth-email-match/README.md` | new | GAUAT-06 | 4 rows: flash-text / redirect / identity-row / mailbox-arrival. |
| `.planning/uat-evidence/v1.20/oauth-email-match/manifest.json` | new | manifest | Same 4-row shape. |
| `.planning/uat-evidence/v1.20/oauth-email-match/reports/flash-text-assertion.json` | new | flash text capture | `{expected: "An account...", actual: "An account...", verbatim_source: "priv/templates/sigra.gen.oauth/oauth_controller.ex:96"}`. |
| `.planning/uat-evidence/v1.20/oauth-email-match/reports/linked-email-mailbox.json` | new | mailbox capture | `/dev/mailbox/json` snapshot for the `provider_linked_email` row. |
| `docs/uat-ci-coverage.md` | modify | D-87-08 SEED-001 row residual | Update residual column for items 3-6 to point at install_smoke (extended) + oauth_e2e_playwright + sigra.oauth.smoketest. |
| `CHANGELOG.md` | modify | D-87-08 [Unreleased] | Add Phase 87 bullet. |
| `.planning/phases/87-…/87-VERIFICATION.md` | new | Phase close attestation | CI run URL + dated PASS attestations per GAUAT-03/04/05/06 + snapshot/artifact counts. |

## CI Workflow Diff

### `scripts/ci/install-smoke.sh` — three surgical edits

The script currently ends after line 136 with `echo "==> install-smoke: done; tmp_app generated + sigra-installed + compiled clean"`. Extend in two places (NOT one — the sequencing matters):

**Edit 1 — between lines 93 and 95 (after `mix compile --warnings-as-errors`, before `APP=$(...)`):**

```bash
echo "==> install-smoke: creating + migrating test DB and running mix test"
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
MIX_ENV=test mix test
```

**Edit 2 — after line 134 (the existing 11-paths-OK echo) and before line 136 (the done echo):**

```bash
echo "==> install-smoke: oauth-gen: 12/12 expected artifacts present, mix test green"
```

The artifact count is 12 (verified by counting): 10 in `oauth_paths` array (lines 99-110) + 1 migration matched at line 122-126 + 1 router marker at line 129-132. The 12 number is the contract.

**Edit 3 — phx_new pin in `.github/workflows/ci.yml`:**

Lines 256, 304-305, 356, 475, 822 all do `mix archive.install --force hex phx_new`. The install-smoke job (line 256) is the load-bearing one for D-87-04. Change to `mix archive.install --force hex phx_new 1.8.5` for that step. Other jobs CAN remain unpinned (research recommendation: pin all six for cache-key determinism, but minimum-viable change is the install-smoke step).

### `.github/workflows/ci.yml` — `install_smoke` transcript capture

Modify the `Run install smoke harness` step at lines 259-267 to tee output:

```yaml
- name: Run install smoke harness (with transcript tee)
  env:
    PGUSER: postgres
    PGPASSWORD: postgres
    PGHOST: localhost
    GITHUB_WORKSPACE: ${{ github.workspace }}
    CLOAK_KEY: MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=
  run: |
    mkdir -p .planning/uat-evidence/v1.20/oauth-gen/
    scripts/ci/install-smoke.sh 2>&1 | tee .planning/uat-evidence/v1.20/oauth-gen/transcript.log
    # tee return code in the absence of pipefail: rely on `set -euo pipefail` inside install-smoke.sh
- name: Upload oauth-gen transcript bundle (PR/push, 7d retention)
  if: always() && github.ref != 'refs/heads/main' && !startsWith(github.ref, 'refs/tags/')
  uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
  with:
    name: oauth-gen-bundle
    path: .planning/uat-evidence/v1.20/oauth-gen/
    retention-days: 7
- name: Upload oauth-gen transcript bundle (main, 14d retention)
  if: always() && github.ref == 'refs/heads/main'
  uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
  with:
    name: oauth-gen-bundle
    path: .planning/uat-evidence/v1.20/oauth-gen/
    retention-days: 14
- name: Promote oauth-gen bundle to release asset (v* tag only)
  if: startsWith(github.ref, 'refs/tags/v')
  env:
    GH_TOKEN: ${{ github.token }}
  permissions:
    contents: write
  run: |
    cd /tmp && tar -czf "sigra-oauth-gen-${{ github.ref_name }}.tar.gz" \
      -C ${{ github.workspace }} .planning/uat-evidence/v1.20/oauth-gen/
    gh release upload "${{ github.ref_name }}" \
      "/tmp/sigra-oauth-gen-${{ github.ref_name }}.tar.gz" \
      --clobber --repo "${{ github.repository }}"
```

**`tee` portability note:** `tee` is POSIX and works identically on Linux + macOS. `set -euo pipefail` inside install-smoke.sh ensures the exit code propagates even through the pipe (verified at install-smoke.sh:14).

**Note on `permissions:`** — top-level workflow has `contents: read` (line 14). The release-upload step needs `contents: write` — already established by the `email_visual_regression` job at line 939-940. Mirror that pattern at the install_smoke job level.

### `.github/workflows/ci.yml` — new `oauth_e2e_playwright` job

Mirror `example_playwright_smoke` shape (lines 551-789). Key differences:

- Boot example app in `MIX_ENV=dev` (matches existing Playwright pattern; longpoll fallback is already accounted for in `playwright.config.ts:48-54`).
- Set `EXAMPLE_DB_PROBE_ENABLED=1` and `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1` env vars to gate the test-only routes.
- Run only the 3 new specs: `npx playwright test tests/oauth-register.spec.ts tests/oauth-link.spec.ts tests/oauth-email-match.spec.ts --project=chromium`
- Upload artifacts per `email_visual_regression` precedent (lines 1043-1081).

**Job graph:** `oauth_e2e_playwright` does NOT depend on `install_smoke` (parallel-ready). They're independent surface areas.

## DB Probe Seam — Tradeoff Analysis

D-87-05 explicitly leaves this to planner discretion. Three viable approaches:

### Option A — Test-only HTTP endpoint at `/test/db_probe` (RECOMMENDED)

**How:** Mount in `test/example/lib/example_web/router.ex` guarded by `if Application.get_env(:example, :enable_db_probe, false)`. Serve JSON: `GET /test/db_probe?table=user_identities&user_email=alice@example.test → {count: 1, rows: [{id, provider, provider_uid}]}`. Read-only. ~30 LOC controller.

**Pros:**
- Zero new infra. Standard Phoenix endpoint.
- Playwright's existing `page.evaluate(async () => fetch('/dev/mailbox/json'))` pattern (verified at `mailbox.ts:25` and `ga-uat-shift-left.spec.ts:79-82`) generalizes 1-line.
- Easy env-gating prevents production exposure.

**Cons:**
- Adds a route to the example app that "shouldn't be there." Mitigated by the env gate.

**Why recommended:** Matches existing pattern (`/dev/mailbox/json` is already a test-time-only endpoint). Lowest cognitive overhead. Compatible with both `MIX_ENV=dev` (Playwright) and `MIX_ENV=test` (controller tests).

### Option B — Mix-task probe via Playwright `cmd:`

**How:** Create `mix example.db_probe table=user_identities user_email=alice@example.test` task. Playwright `child_process.execSync('cd ../.. && mix example.db_probe ...')`.

**Pros:**
- No HTTP route in the app.

**Cons:**
- Cross-process: Playwright runs Node, the Mix task starts a separate BEAM. They don't share Ecto sandbox state, so a write in Playwright's webapp wouldn't be visible to the Mix task.
- Slow (BEAM cold start per probe).
- Bizarre debugging path.

**Why NOT recommended:** Cross-process Ecto state mismatch is a fatal flaw for an OAuth flow that's writing identity rows mid-test.

### Option C — Phoenix.Ecto.SQL.Sandbox + `Phoenix.Endpoint.config(:check_origin)`

**How:** Wire Phoenix.Ecto.SQL.Sandbox so each Playwright test gets its own sandbox checkout. Embed sandbox token in cookies; Playwright reads + reuses it.

**Pros:**
- Genuinely-isolated per-test DB state.

**Cons:**
- The Sandbox+Playwright pattern (Phoenix.Ecto.SQL.Sandbox.Plug) requires `phoenix_ecto ~> 4.5` (already a dep at `test/example/mix.exs:42`) BUT Sigra's existing Playwright specs run against `MIX_ENV=dev` with shared DB (workers: 1, fullyParallel: false at `playwright.config.ts:44-45`). Switching just OAuth specs to MIX_ENV=test+Sandbox is a major architectural change.
- Doesn't actually solve the DB probe question — you still need to **assert** what's in the DB from Playwright.

**Why NOT recommended:** Excessive scope creep for the stated need. If Sandbox+Playwright integration ever makes sense, it's a separate phase.

**RECOMMENDATION: Option A.** Single ~30-LOC controller, env-gated route, matches existing patterns, no new infrastructure.

## `oauthIssuer.ts` Wire Format

Mirror `mailbox.ts` shape at `test/example/priv/playwright/fixtures/mailbox.ts:1-52` — plain helper module, no `test.extend`.

```typescript
import { Page } from '@playwright/test';

type GoogleClaims = {
  sub: string;
  email: string;
  email_verified: boolean;
  name?: string;
  picture?: string;
};

export async function setupIssuer(
  page: Page,
  claims: Partial<GoogleClaims>,
): Promise<void> {
  // Calls test-only POST /test/oauth_issuer/setup which spins up
  // Sigra.Testing.OAuthIssuer in the example app process and registers it
  // as the :google override. Returns 200 OK with the issuer base_url.
  const response = await page.evaluate(async (claims) => {
    const res = await fetch('/test/oauth_issuer/setup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider: 'google', user: claims }),
    });
    return res.json();
  }, claims);
  if (!response.ok) throw new Error(`oauthIssuer setup failed: ${JSON.stringify(response)}`);
}

export async function resetIssuer(page: Page): Promise<void> {
  await page.evaluate(async () => {
    await fetch('/test/oauth_issuer/reset', { method: 'POST' });
  });
}

export async function probeIdentities(
  page: Page,
  userEmail: string,
): Promise<{ count: number; rows: Array<{ provider: string; provider_uid: string }> }> {
  return page.evaluate(async (email) => {
    const res = await fetch(
      `/test/db_probe?table=user_identities&user_email=${encodeURIComponent(email)}`,
    );
    return res.json();
  }, userEmail);
}
```

## Application Config Injection

The example app's runtime config needs to receive the issuer's base URL at test time without restarting Phoenix per test (Playwright runs serial; one Phoenix instance covers all 3 OAuth specs).

**Pattern (matches Sigra's existing `Application.get_env`-based config):**

```elixir
# test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex
defmodule ExampleWeb.TestOAuthIssuerController do
  use ExampleWeb, :controller

  def setup(conn, %{"provider" => "google", "user" => user_claims}) do
    {:ok, issuer} = Sigra.Testing.OAuthIssuer.start_link(provider: :google, user: atomize_claims(user_claims))
    Application.put_env(:sigra, :oauth_provider_overrides, [
      google: [
        base_url: Sigra.Testing.OAuthIssuer.url(issuer),
        openid_configuration: Sigra.Testing.OAuthIssuer.openid_config(issuer),
      ]
    ])
    Process.put({__MODULE__, :issuer}, issuer)  # so reset/0 can stop it
    json(conn, %{ok: true, base_url: Sigra.Testing.OAuthIssuer.url(issuer)})
  end

  def reset(conn, _params) do
    case Process.get({__MODULE__, :issuer}) do
      nil -> :ok
      issuer -> Sigra.Testing.OAuthIssuer.stop(issuer)
    end
    Application.delete_env(:sigra, :oauth_provider_overrides)
    json(conn, %{ok: true})
  end
end
```

**Critical implementation note:** `Application.put_env/3` at request time only works if `Sigra.OAuth` reads provider config at *callback time* (not at boot time). Verify this in `lib/sigra/oauth.ex:get_provider_config/2` — the call shape is `get_provider_config(config, provider)` from `authorize_url/3` line ~63, suggesting per-call resolution. **Planner must verify** by reading `lib/sigra/oauth/strategies/google.ex` and `lib/sigra/oauth/strategies.ex` to confirm Assent's HTTP base_url is plumbed through dynamic config, not compile-time.

## Verbatim Source Strings

These strings MUST be asserted verbatim by the Playwright specs. Source line references verified by reading the files.

### `priv/templates/sigra.gen.oauth/oauth_controller.ex:96` — GAUAT-06 flash text

```
"An account with this email exists. Log in to link your #{provider} account."
```

When rendered for `provider = :google` (an atom), Elixir's `to_string/1` produces `"google"`, so the final asserted string in the Playwright spec is:

```
An account with this email exists. Log in to link your google account.
```

[VERIFIED: `priv/templates/sigra.gen.oauth/oauth_controller.ex:94-97` reads:
```
            |> put_flash(
              :info,
              "An account with this email exists. Log in to link your #{provider} account."
            )
```
The `provider` interpolation is the atom passed via `assigns[:provider]`; Phoenix renders it via `Phoenix.HTML.html_escape/1` which calls `to_string/1` on atoms — yielding the bare provider slug.]

### `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92` — GAUAT-05 disabled-tooltip text

```
"Set a password first to keep access to your account."
```

[VERIFIED: `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:90-96` reads:
```html
<button
  disabled
  title="Set a password first to keep access to your account."
  class="text-sm text-red-600 bg-red-50 rounded-md px-3 py-1.5 opacity-50 cursor-not-allowed"
>
  Unlink
</button>
```
This is HEEx — the `title="..."` attribute is rendered as-is into the DOM. Playwright assertion: `await expect(button).toHaveAttribute('title', 'Set a password first to keep access to your account.')`.]

## Validation Architecture

> Phase 87 inherits Sigra's nyquist_validation framing. The relevant `.planning/config.json` flag is unverified by direct read here, but the project ships `docs/nyquist-posture-matrix.md` (referenced in `mix.exs:194`) so we treat the framework as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit 1.18 (Elixir stdlib) + Playwright 1.x (Node) |
| Config files | `mix.exs`, `test/example/mix.exs`, `test/example/priv/playwright/playwright.config.ts` |
| Quick run command (issuer module) | `mix test test/sigra/testing/oauth_issuer_test.exs` |
| Quick run command (smoketest task) | `mix test test/sigra/install/oauth_smoketest_task_test.exs` |
| Quick run (controller integration) | `cd test/example && mix test test/example_web/oauth_controller_test.exs --include example_app` |
| Quick run (Playwright OAuth specs) | `cd test/example/priv/playwright && npx playwright test tests/oauth-register.spec.ts tests/oauth-link.spec.ts tests/oauth-email-match.spec.ts --project=chromium` |
| Full library suite | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| Full install-smoke | `GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| GAUAT-03 | Fresh-host smoke runs end-to-end on Phoenix 1.8.5 | install-smoke | `scripts/ci/install-smoke.sh` (extended per D-87-04) | Wave 0: extension lands in Wave 1 |
| GAUAT-03 | 12 expected artifacts present | structural assertion | `oauth_paths` array verification at install-smoke.sh:99-119 | ✅ exists |
| GAUAT-03 | Generated `mix test` green | live-host runtime | `MIX_ENV=test mix test` inside install-smoke | Wave 1 ships |
| GAUAT-04 | Provider button visible on login | Playwright DOM | `await expect(page.locator('a:has-text("Sign in with Google")')).toBeVisible()` | Wave 1 ships |
| GAUAT-04 | Authorize redirect to issuer | Playwright network | `page.waitForRequest(/oauth2\/v2\/auth.*state=/)` | Wave 1 ships |
| GAUAT-04 | User + identity row created | DB probe via Option A | `await probeIdentities(page, email)` returns `count: 1` | Wave 1 ships |
| GAUAT-04 | Re-login uses same user | DB probe | `count: 1` after second login (no new row) | Wave 1 ships |
| GAUAT-05 | linked-with-password: unlink enabled | Playwright DOM | `await expect(button).toBeEnabled()` | Wave 1 ships |
| GAUAT-05 | only-oauth-no-password: unlink disabled + tooltip | Playwright DOM + screenshot | `await expect(button).toBeDisabled()` + `toHaveAttribute('title', VERBATIM)` + `toHaveScreenshot('oauth-link__disabled-tooltip.png')` | Wave 1 ships |
| GAUAT-05 | post-unlink: row absent + password login | DB probe + Playwright | `count: 0` for `(google, mock_uid)` after unlink | Wave 1 ships |
| GAUAT-06 | Flash text verbatim | Playwright DOM | `await expect(page.locator('.flash-info')).toContainText("An account with this email exists. Log in to link your google account.")` | Wave 1 ships |
| GAUAT-06 | Identity row created after password login | DB probe | `count: 1` for `(alice.id, google, novel_sub)` | Wave 1 ships |
| GAUAT-06 | `provider_linked_email` arrives | mailbox.ts | `extractMailboxRow(page, alice@example.test, /Provider linked/)` | Wave 1 ships |

### Sampling Rate

Per Nyquist principle: each cell must be hit at a frequency ≥ twice the rate of the failure mode it monitors.

**Frequency-amplitude grid for the OAuth issuer endpoints:**

| Endpoint | Frequency (how often called) | Amplitude axis 1 | Amplitude axis 2 | Sampled By |
|----------|------------------------------|-------------------|-------------------|------------|
| `/.well-known/openid-configuration` | once per Sigra cold-config-load (~1× per spec) | well-formed | malformed (404) | `oauth_issuer_test.exs` happy-path; planned LOW-confidence: malformed coverage NOT in CI scope (Sigra cannot meaningfully test Assent's response to malformed OIDC discovery without coordinating with Assent — covered by Assent's own suite) |
| `/oauth2/v2/auth` | once per Playwright spec (3 specs) | with PKCE | without PKCE | `oauth_issuer_test.exs` covers both; specs cover only WITH (real flow always has PKCE) |
| `/token` | once per spec | good code_verifier | bad code_verifier | `oauth_issuer_test.exs` covers both; specs cover only good (real flow) |
| `/userinfo` | once per spec | claims with email | claims without email | `oauth_issuer_test.exs` covers both; controller-extension test covers no-email branch |
| `/jwks` | called by Assent during id_token verify (~1-2× per token) | kid_count: 1 | kid_count: 2 | `oauth_issuer_test.exs` covers both; specs cover kid_count: 1 only (rotation is a unit-test-only concern) |

**Frequency-amplitude grid for `email_verified` claim:**

| Amplitude | Sampled By | Coverage |
|-----------|-----------|----------|
| `true` (boolean) | All 3 Playwright specs (default) | ✅ |
| `false` (boolean) | `oauth_controller_test.exs` extension (D-87-10 controller test for no-email/unverified) | ✅ |
| missing | `oauth_controller_test.exs` extension + `oauth_issuer_test.exs` | ✅ |
| `"true"` (string — wrong shape) | `oauth_issuer_test.exs` regression test | ✅ — Sigra has been bitten by this shape per D-87-02 |

**Frequency-amplitude grid for the install-smoke extension:**

| Frequency | Amplitude (Phoenix version) | Sampled By |
|-----------|------------------------------|------------|
| Per PR | 1.8.5 (pinned in workflow) | install_smoke job (extended) |
| Per minor Phoenix bump | n/a | Manual: bump pin when Phoenix bumps minor (D-87-04 instruction) |

**Coverage gap:** Phoenix-version matrix is explicitly NOT introduced (D-87-04). The risk is that Phoenix 1.8.6 ships a generator-shape change that breaks `mix sigra.gen.oauth`'s assumptions. Mitigation: pin bump on minor Phoenix releases, not patch.

**Frequency-amplitude grid for `mix sigra.oauth.smoketest`:**

| Frequency | Amplitude | Sampled By |
|-----------|-----------|------------|
| Per adopter at install time | `client_id` valid | Adopter's own observation (NOT Sigra's release gate) |
| Per adopter at install time | `client_id` invalid | Adopter sees exit-code-3 + diagnostic |
| Sigra CI: NEVER runs against real Google | Module unit test | `oauth_smoketest_task_test.exs` covers config loading + port flag + diagnostic emission + exit codes by stubbing Bandit + the OAuth round-trip |

**Per task commit:**
- Library + smoketest task tests: `mix test`
- Issuer-specific test: `mix test test/sigra/testing/oauth_issuer_test.exs`
- Controller integration: `cd test/example && mix test test/example_web/oauth_controller_test.exs --include example_app`

**Per wave merge:**
- Full library suite: `mix test` (~5-10 min, including all new Phase 87 tests)
- Full install-smoke (extended): `scripts/ci/install-smoke.sh` (~3 min cold, ~105s warm cache)
- Playwright OAuth specs: `npx playwright test tests/oauth-{register,link,email-match}.spec.ts --project=chromium` (~2-4 min)

**Phase gate (Wave 2 commit before merge):**
- All CI jobs green at Wave 2 SHA: library_tests, install_smoke (extended), oauth_e2e_playwright (new), email_visual_regression, all existing jobs.
- `mix sigra.uat.report --phase=oauth-gen --check && --phase=oauth-google --check && --phase=oauth-link --check && --phase=oauth-email-match --check` all exit 0.
- Manifest matches README table per evidence dir.

### Wave 0 Gaps

- ❌ `test/sigra/testing/oauth_issuer_test.exs` — Wave 1 ships
- ❌ `test/sigra/install/oauth_smoketest_task_test.exs` — Wave 1 ships
- ❌ `test/example/test/example_web/oauth_controller_test.exs` — extension in Wave 1
- ❌ `test/example/priv/playwright/tests/oauth-{register,link,email-match}.spec.ts` — Wave 1 ships
- ❌ `test/example/priv/playwright/fixtures/oauthIssuer.ts` — Wave 1 ships
- ✅ Test framework infrastructure exists (`mix.exs:55` already has `elixirc_paths(:test) -> ["lib", "test/support"]`)
- ✅ Playwright harness exists (`playwright.config.ts:42-235`)
- ✅ Postgres + sandbox setup exists (`test/example/config/test.exs:6-12`)
- ✅ `mix sigra.uat.report` exists from Phase 86 — extension only

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `Sigra.Auth` — already shipped + AUD-21 closed; Phase 87 does NOT modify |
| V3 Session Management | yes | `Sigra.Session` — Phase 87 invokes via OAuth callback; does NOT modify |
| V4 Access Control | yes | `Sigra.Plug.RequireAuth` — Phase 87 does not modify |
| V5 Input Validation | yes | Plug + Ecto changesets in OAuth controller; PKCE verifier validation in issuer (CRITICAL — must reject bad verifier per D-87-02 footgun mitigation) |
| V6 Cryptography | yes | RS256 signing via Erlang `:public_key` + `:crypto` (issuer); HMAC state via `Sigra.Token.generate/4`; SHA-256 hashing for tokens. **NEVER hand-roll;** the issuer module wraps `:public_key.sign/4` and `:crypto.hash(:sha256, ...)` only. |
| V8 Data Protection | partial | Test-only DB probe endpoint must NEVER ship in production (env-gated; documented). |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Test-only `/test/db_probe` endpoint shipped to production | Information disclosure | Env-gated route mount + assert in plug-level test that production config disables it |
| Test-only `/test/oauth_issuer/setup` POST endpoint shipped to production | Tampering | Same env gate as DB probe |
| Mock issuer's RSA fixture key leaked or reused as production signing key | Spoofing | Fixture lives at `test/support/sigra/testing/fixtures/oauth_issuer_rsa_*.pem` — package files list (`mix.exs:146`) does NOT include `test/`, so fixtures are excluded from hex publish. **VERIFY** by reviewing the published-package contents before v1.20 hex.publish. |
| Mock issuer accepts any PKCE verifier | Tampering | D-87-02 footgun mitigation: real PKCE verification (`:crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)` matches stashed `code_challenge`) |
| Mock issuer's `email_verified` returns string instead of boolean | Spec violation that masks real Sigra bugs | D-87-02 mitigation: explicit boolean shape; regression-tested |
| Smoketest task's localhost:4001 exposed during run | Tampering | Bind to `127.0.0.1` only (NOT `0.0.0.0`); state nonce + 5-min timeout |

## Risks and Footguns

### High-impact

1. **Application.put_env at request time vs at boot time.** `lib/sigra/oauth.ex:get_provider_config/2` MUST be confirmed to read provider config dynamically per call. If it reads at boot, the issuer-URL injection won't work without restarting Phoenix per spec (which fails Playwright's serial-shared-app pattern). **Planner action:** read `lib/sigra/oauth.ex:get_provider_config/2` and `lib/sigra/oauth/strategies/google.ex` end-to-end before locking implementation; if config is cached, plan a reload mechanism (`Sigra.OAuth.reload_config!/0` test helper).

2. **TestServer route lifetime.** `TestServer.add` registers a one-shot route that's removed when matched (FIFO per the WebFetch on hexdocs.pm/test_server). Sigra's OAuth flow may re-fetch JWKS during id_token verification (depends on Assent's caching). **Planner action:** verify in `oauth_issuer.ex` that `/jwks`, `/userinfo`, `/.well-known/openid-configuration`, and `/token` are registered with persistent handlers (the `to:` form), not one-shot `plug:` form. If TestServer 0.1.22's API forces FIFO removal, register N copies (where N = expected hit count per spec) OR mount our own Bandit endpoint instead and skip TestServer's route DSL. **CONFIDENCE: MEDIUM** — TestServer behavior verified at high level via WebFetch but exact route-persistence semantics need codebase verification when the planner reads `pow_assent/test/support/test_provider.ex` (the canonical precedent — but that file 404'd via WebFetch; planner needs to clone Assent's repo or read the latest source).

3. **MIX_ENV=dev vs MIX_ENV=test for Playwright.** Existing specs run against `MIX_ENV=dev` (verified at `playwright.config.ts:48`). MIX_ENV=dev does NOT use Ecto.Adapters.SQL.Sandbox (verified at `test/example/config/dev.exs` would have to be checked but the comment at `playwright.config.ts:48` confirms). DB state therefore persists across spec test runs — MUST add explicit cleanup (DELETE FROM users WHERE email LIKE 'oauth-test-%') or use unique-per-test fixture emails (`Date.now()` suffix per `golden-path.spec.ts:21`).

4. **`Application.put_env(:sigra, :oauth_provider_overrides, ...)` race conditions.** If two Playwright specs run concurrently (workers > 1), they trample each other's overrides. Mitigated by `playwright.config.ts:45 workers: 1`, but the planner should put a comment in `oauthIssuer.ts` documenting the assumption.

5. **OIDC spec compliance: HTTPS for issuer URL.** Production OIDC providers MUST be HTTPS. Assent strategies don't enforce this when `base_url` is overridden in config — but they MAY validate the `iss` claim against `https://...`. Planner should set the issuer's `iss` claim to match the test issuer's actual base_url (`http://localhost:port`), NOT a synthetic `https://google.test`. If `iss` mismatch causes Assent to reject, document and fix in implementation.

### Medium-impact

6. **`oauth_settings_live.ex:92` is a HEEx attribute, not a plain HTML element.** The disabled-tooltip assertion needs to match attribute value verbatim, NOT inner text. Playwright: `toHaveAttribute('title', VERBATIM)` not `toHaveText`.

7. **`oauth_controller.ex:96` flash interpolation:** `provider` is an atom from `assigns`; final string is `"...your google account."` not `"...your :google account."`. Verified above; planner must NOT include the colon in the assertion.

8. **`mix sigra.oauth.smoketest` and Phoenix 1.7 hosts:** Bandit is the Phoenix 1.8 default but a Phoenix 1.7 adopter could hit this. Document in `docs/oauth-google-setup.md` that Phoenix < 1.7 needs a Plug.Cowboy fallback OR exit-code-2 with a clear "Phoenix 1.8+ required" message. Recommended: fail fast with a version check.

9. **`test_server` per-test isolation cost.** TestServer.start spawns a process. ~100 specs × ~10ms each = ~1s per suite — negligible. But if oauth_issuer_test.exs has 8 tests and each starts a TestServer, that's 80ms. Acceptable.

10. **`config/dev.exs` vs `runtime.exs` for issuer override.** Phoenix 1.8 prefers `runtime.exs` for env-driven config. The example app's `config/dev.exs` is checked in; `runtime.exs` may not exist — verify at planning time.

### Low-impact

11. **Hex package files list excludes `test/`** at `mix.exs:146`. Fixture RSA keys at `test/support/sigra/testing/fixtures/*.pem` are NOT shipped to adopters. Verify by reviewing Hex publish output before v1.20.

12. **Playwright trace.zip file size.** Traces can be 5-50 MB. Release-asset cap is 2 GB; tag-time tar.gz of 4 evidence dirs + traces is unlikely to exceed 100 MB. Acceptable.

## Open Questions for Planner

1. **DB probe seam: Option A confirmed?** Research strongly recommends Option A (test-only `/test/db_probe`). If the planner picks B or C, document why in the plan.

2. **`oauthIssuer.ts` shape: plain helper module OR Playwright `test.extend` fixture?** Research recommends plain module (matches `mailbox.ts`). If `test.extend` is preferred, accept slight API divergence from `mailbox.ts`.

3. **Fixture RSA key generation: at-test-time vs committed `.pem`?** Research recommends committed `.pem` files with `@external_resource` (deterministic, no boot cost). Generate once with a script at `test/support/sigra/testing/fixtures/gen.exs` (NOT run in CI; documented as a one-time-by-maintainer script).

4. **Plan-1 vs plan-2 splitting: split-by-surface (issuer + smoketest in plan-1, specs+install-smoke in plan-2) OR split-by-commit (everything in plan-1, evidence in plan-2)?** D-87-07 implies the second. Research recommends a single Wave-1 plan covering all of commit A's surface (issuer + smoketest + specs + install-smoke + tests) and a single Wave-2 plan for the evidence + verification commit. **Total: 2 plans.** Same shape as Phase 86's plan structure (4 plans there because of L1/L2/L3/L4 layers; OAuth has fewer layers).

5. **`docs/oauth-google-setup.md` ExDoc group:** Recipes vs Docs. `Docs` group already exists per `mix.exs:208`. Recommend Docs.

6. **Wave 2 evidence freshness:** the manifests need a real `git_sha` and `ci_run_url`. Two approaches:
   - (a) Wave 2 commit captures Wave 1's CI run URL (what got us here was wave-1 SHA's CI run).
   - (b) Wave 2 commits placeholder URLs and `mix sigra.uat.report` regenerates them at next CI run (the email_visual_regression precedent at `.github/workflows/ci.yml:1019-1033`).
   Recommendation: **option (b)** — `mix sigra.uat.report` is invoked in the CI workflow itself, so the manifest auto-fills CI run URL on every run (matches Phase 86 pattern). Wave 2 commits just the README/manifest skeleton + `git_sha` of wave 2's HEAD.

7. **What to do with `87-DISCUSSION-LOG.md`?** This file already exists at the start of Phase 87. The planner should leave it untouched; it's the discuss-phase artifact.

## Sources

### Primary (HIGH confidence)

- `87-CONTEXT.md` (Phase 87 decisions) — opened in full; every decision D-87-01..10 quoted verbatim
- `86-CONTEXT.md` (Phase 86 precedent — D-86-06 evidence schema, D-86-08 milestone-scope edits, D-86-09 residual policy, D-86-11 two-commit closure) — opened in full
- `86-01-PLAN.md`, `86-02-PLAN.md`, `86-04-PLAN.md` (Phase 86 plan structure precedent) — read for plan shape
- `.planning/REQUIREMENTS.md` GAUAT-03/04/05/06 (current text) — verified
- `.planning/ROADMAP.md` Phase 87 success criteria — verified
- `scripts/ci/install-smoke.sh` (lines 1-137 — full file) — line 90-93 extension point and 12-artifact count both verified
- `.github/workflows/ci.yml` (full file) — `install_smoke` job at lines 218-267, `email_visual_regression` job at lines 928-1081 (release-asset promotion precedent), `example_playwright_smoke` job at lines 551-789 (job-graph precedent)
- `priv/templates/sigra.gen.oauth/oauth_controller.ex` (lines 85-103) — flash text verbatim
- `priv/templates/sigra.gen.oauth/oauth_settings_live.ex` (lines 75-110) — disabled-tooltip verbatim
- `test/example/priv/playwright/playwright.config.ts` (full file) — project structure, serial mode, longpoll-aware timeouts
- `test/example/priv/playwright/fixtures/mailbox.ts` (full file) — fixture precedent
- `test/example/priv/playwright/tests/email-visual.spec.ts` (full file) — Playwright-spec-with-template-iteration precedent
- `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` (full file) — describe-block + DB-via-mailbox precedent
- `test/example/priv/playwright/tests/golden-path.spec.ts` (lines 1-100) — `waitForLiveViewReady` + register-confirm precedent
- `lib/sigra/testing.ex` (lines 990-1095) — `mock_oauth_callback/1` complementary helper
- `lib/sigra/oauth.ex` (lines 1-80) — public API confirmation
- `lib/sigra/oauth/strategies.ex` (full) — provider resolution
- `lib/mix/tasks/sigra.gen.oauth.ex` (lines 1-120) — generator shape
- `lib/mix/tasks/sigra.uat.report.ex` (lines 1-100) — task to extend
- `mix.exs` (full) — dep + ExDoc extras + elixirc_paths verification
- `test/example/mix.exs` (lines 1-80) — example app deps (Bandit, Assent, swoosh, premailex)
- `test/example/config/test.exs` (lines 1-60) — Postgres + sandbox config
- `test/sigra/install/oauth_generator_test.exs` (lines 1-80) — existing structural test (NOT modified)
- `test/example/test/example_web/smoke/oauth_test.exs` (full) — existing controller smoke (extended in Phase 87)
- `.planning/uat-evidence/v1.20/INDEX.md` — top-level index pattern
- `.planning/uat-evidence/v1.20/email-phase-04/README.md` and `manifest.json` — schema templates
- `.planning/STATE.md` — v1.20 leg-2 framing

### Secondary (HIGH-MEDIUM confidence)

- [hex.pm/packages/test_server](https://hex.pm/packages/test_server) — v0.1.22 dated March 6, 2026 [VERIFIED via WebFetch]
- [hexdocs.pm/test_server/TestServer.html](https://hexdocs.pm/test_server/TestServer.html) — public API: start/1, add/2, url/0, plug/1, stop/0; per-test isolation; HTTPS scheme support [VERIFIED via WebFetch]
- [github.com/pow-auth/assent test/support/strategies/oidc_test_case.ex](https://github.com/pow-auth/assent) — RS256 + RSA fixture + JWKS + kid rotation precedent [VERIFIED via WebFetch — embedded RSA keypairs, gen_id_token/1 with RS256/HS256/none, gen_keys/1 with kid count, expect_openid_config_request/2, expect_oidc_jwks_uri_request/1]

### Tertiary (LOW confidence — verify if load-bearing)

- [pow_assent test/support/test_provider.ex](https://github.com/pow-auth/pow_assent) — composition pattern; the WebFetch returned 404 for the canonical path; planner should clone the repo OR read the file via `mix deps.get pow_assent && find deps/pow_assent` if precedent verification is critical. Status: low confidence on exact file shape but the conceptual pattern (TestServer + RSA fixture + JWKS) is confirmed by Assent's own `oidc_test_case.ex`.
- TestServer route persistence semantics (one-shot FIFO vs persistent `to:` form) — documented at high level in WebFetch but not exhaustively. Planner should write a small probe test in implementation phase to confirm before locking the issuer's route registration shape.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `lib/sigra/oauth.ex:get_provider_config/2` reads provider config at request time, not boot time | Module APIs > Application Config Injection | If false, `Application.put_env` injection in test_oauth_issuer_controller doesn't take effect until Phoenix restart — Playwright pattern breaks. Mitigation: Sigra.OAuth.reload_config!/0 test helper. **Planner MUST verify before locking implementation.** |
| A2 | Phoenix 1.8.5 is the right pin for `mix archive.install hex phx_new` | CI Workflow Diff | If a later 1.8.x patch ships before v1.20, the pin is stale. Low risk; trivial to update. |
| A3 | TestServer 0.1.22's `add(path, plug:)` form removes the route after first hit; `add(path, to:)` form persists | Module APIs > internal endpoint plugs; Risks #2 | If wrong direction, JWKS endpoint depletes mid-flow. **Planner MUST verify** by writing a small probe test before locking the issuer's registration shape. |
| A4 | Sigra hex package excludes `test/` files (verified by reading `mix.exs:146`) | Security Domain | If false, RSA fixture keys ship to adopters. Low risk — `mix.exs:146` files list is `~w(lib priv docs ...)` — verified by direct read. |
| A5 | Assent strategies don't enforce HTTPS-issuer URL when `base_url` is overridden | Risks #5 | If Assent rejects HTTP issuers, planner must plumb HTTPS via TestServer's `:scheme` option (supported per WebFetch on hexdocs.pm/test_server). |
| A6 | Postgres at `localhost:5432` (postgres/postgres) is available in the example app's CI runs | DB Probe Seam | Confirmed by reading `.github/workflows/ci.yml:225-231` and CLAUDE.md "Local development prerequisites." |
| A7 | The `chromium` Playwright project's `testIgnore` array (line 85) does NOT need updating to include the 3 new OAuth specs | File-by-File Plan > playwright.config.ts | The 3 new specs run on the default chromium project (matching golden-path's behavior). If the planner wants explicit isolation, add a new `oauth-e2e` project; otherwise leave `chromium` as-is. |
| A8 | The 12-file artifact count in install-smoke.sh comes from the `oauth_paths` array (10 entries) + 1 migration glob match + 1 router marker | CI Workflow Diff | Verified by counting lines 99-110 (`oauth_paths` 10 entries) and lines 122-126 + 129-132. |

## Metadata

**Confidence breakdown:**
- Module API shape (Sigra.Testing.OAuthIssuer): HIGH — Assent's `OIDCTestCase` precedent confirmed via WebFetch; mirrors the only proven Elixir-OIDC test seam.
- TestServer route lifetime semantics: MEDIUM — public API verified at high level; exact persistence rules need a small probe test in implementation.
- `Application.put_env` runtime override pattern: MEDIUM — assumed based on Sigra's existing `Application.get_env` discipline, but `lib/sigra/oauth.ex:get_provider_config/2` was not opened in full; planner verification required.
- Verbatim source strings (oauth_controller.ex:96, oauth_settings_live.ex:92): HIGH — both files opened, lines verified.
- 12-artifact count in install-smoke.sh: HIGH — directly counted from script.
- Phase 86 evidence schema reuse: HIGH — manifest.json + README.md + INDEX.md all opened.
- `mix sigra.uat.report` extension surface: HIGH — task already opened, schema+modes documented.
- Playwright fixture pattern: HIGH — `mailbox.ts` opened in full; matches the recommended `oauthIssuer.ts` shape.
- Risk #1 (config caching): MEDIUM — surfaced as an assumption; planner verifies.

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (30 days for stable; refresh if Phoenix 1.8.6 or test_server 0.2.x ships)

## RESEARCH COMPLETE
