---
phase: 87
plan: 01a
type: execute
wave: 1
depends_on: []
files_modified:
  - mix.exs
  - test/support/sigra/testing/oauth_issuer.ex
  - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_private.pem
  - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_public.pem
  - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_private.pem
  - test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_public.pem
  - test/support/sigra/testing/fixtures/README.md
  - test/sigra/testing/oauth_issuer_test.exs
  - test/example/lib/example_web/router.ex
  - test/example/lib/example_web/controllers/test_db_probe_controller.ex
  - test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex
  - test/example/test/example_web/test_endpoints_test.exs
  - test/example/priv/playwright/fixtures/oauthIssuer.ts
autonomous: true
requirements:
  - GAUAT-03
  - GAUAT-04
  - GAUAT-05
  - GAUAT-06
must_haves:
  truths:
    - "A maintainer running `mix test test/sigra/testing/oauth_issuer_test.exs` exercises every Sigra.Testing.OAuthIssuer endpoint (discovery / authorize / token / userinfo / jwks) and proves RS256 signing, multi-kid JWKS rotation, real PKCE rejection, configurable exp, refresh-rotation toggle, and `email_verified` boolean shape — all green."
    - "Sigra-side CI never makes real HTTP requests to Google — verified by automated grep at execute time across the issuer module + Playwright spec files (no `accounts.google.com` / `oauth2.googleapis.com` / `googleapis.com` references)."
    - "The test-only `/test/db_probe` and `/test/oauth_issuer/{setup,reset}` routes are mounted only when `EXAMPLE_DB_PROBE_ENABLED=1` / `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1` env vars are set; the gates are evaluated at runtime via `System.get_env/1` so the routes never appear in the prod release boot."
    - "A maintainer running `EXAMPLE_DB_PROBE_ENABLED=0 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=0 mix test test/example/test/example_web/test_endpoints_test.exs` sees the test endpoints return 404 — proving the env gates fail-safe-closed (T-87-01 / T-87-02 mitigation)."
    - "The `oauthIssuer.ts` Playwright helper module exposes `setupIssuer / resetIssuer / probeIdentities` against the env-gated test endpoints; downstream Plan 87-01b's three Playwright specs bind against this fixture surface without further codebase exploration."
  artifacts:
    - path: mix.exs
      provides: "test_server ~> 0.1.22 dev/test dep promotion"
      pattern: ":test_server"
    - path: test/support/sigra/testing/oauth_issuer.ex
      provides: "TestServer-backed in-process OIDC issuer (5 endpoints, RS256, multi-kid JWKS, real PKCE, email_verified boolean, configurable exp, refresh-rotation toggle)"
      exports: ["start_link/1", "set_user/2", "set_kid_count/2", "url/1", "openid_config/1", "stop/1"]
    - path: test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_private.pem
      provides: "RSA 2048-bit private key fixture for kid=1 ID-token signing — TEST FIXTURE ONLY"
    - path: test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_private.pem
      provides: "RSA 2048-bit private key fixture for kid=2 multi-kid JWKS coverage — TEST FIXTURE ONLY"
    - path: test/sigra/testing/oauth_issuer_test.exs
      provides: "AAA-flat ExUnit coverage for all issuer endpoints, RS256 sign/verify roundtrip, kid rotation, PKCE good+bad, exp, refresh-rotation, email_verified boolean"
    - path: test/example/lib/example_web/router.ex
      provides: "Env-gated /test/db_probe + /test/oauth_issuer/{setup,reset} mounts"
    - path: test/example/lib/example_web/controllers/test_db_probe_controller.ex
      provides: "Read-only DB introspection endpoint for Playwright DB probes"
    - path: test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex
      provides: "POST /test/oauth_issuer/setup spawns Sigra.Testing.OAuthIssuer + injects :sigra :oauth_provider_overrides; POST /reset stops and clears"
    - path: test/example/test/example_web/test_endpoints_test.exs
      provides: "Env-gate fail-safe-closed regression (T-87-01 / T-87-02): without env vars, routes 404; with env vars, routes work"
    - path: test/example/priv/playwright/fixtures/oauthIssuer.ts
      provides: "Plain helper module mirroring mailbox.ts: setupIssuer / resetIssuer / probeIdentities"
  key_links:
    - from: "test/sigra/testing/oauth_issuer_test.exs"
      to: "test/support/sigra/testing/oauth_issuer.ex"
      via: "alias Sigra.Testing.OAuthIssuer + start_link/1, set_user/2, set_kid_count/2, openid_config/1, url/1, stop/1"
      pattern: "Sigra.Testing.OAuthIssuer"
    - from: "test/example/test/example_web/test_endpoints_test.exs"
      to: "test/example/lib/example_web/router.ex"
      via: "ConnCase test that exercises both env-gated mounts: with env unset → 404; with env set → 200/400"
      pattern: "EXAMPLE_DB_PROBE_ENABLED|EXAMPLE_OAUTH_ISSUER_CTL_ENABLED|404"
    - from: "test/example/priv/playwright/fixtures/oauthIssuer.ts"
      to: "test/example/lib/example_web/controllers/test_db_probe_controller.ex"
      via: "page.evaluate fetch /test/db_probe?table=user_identities&user_email=..."
      pattern: "/test/db_probe|table=user_identities"
---

<objective>
Implement Wave 0 + the Sigra.Testing.OAuthIssuer GREEN cycle of Phase 87's two-commit closure (D-87-07 — split out of original Plan 01 per checker scope_sanity blocker). Land the in-process `Sigra.Testing.OAuthIssuer` (TestServer-backed OIDC issuer mirroring Assent's `OIDCTestCase`) with full RS256 signing + real PKCE + kid rotation + boolean `email_verified` + configurable `exp` + refresh-rotation toggle; the env-gated example-app test routes + controllers + the new env-gate regression test (`test_endpoints_test.exs` — closes checker task_completeness blocker T-87-01/T-87-02 mitigation chain); the `oauthIssuer.ts` Playwright fixture skeleton; and pass `mix test test/sigra/testing/oauth_issuer_test.exs` GREEN.

Purpose: Land the test-seam fixtures + mock-issuer module + env-gated test endpoints so Plan 87-01b can immediately bind its smoketest task + CI extensions + 3 Playwright specs against a working contract surface. This plan owns the `Sigra.Testing.OAuthIssuer` GREEN cycle so all of D-87-02's footgun mitigations are unit-test-locked before the integration layer (Plan 87-01b) executes.
Output: Library mock-issuer module + 4 RSA fixture PEMs + 5 endpoint implementations + 9-describe-block test suite green; example-app env-gated test routes + 2 test-only controllers + env-gate regression test green; oauthIssuer.ts fixture exporting `setupIssuer / resetIssuer / probeIdentities`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-CONTEXT.md
@.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-RESEARCH.md
@.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-PATTERNS.md
@.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VALIDATION.md
@.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md
@mix.exs
@lib/sigra/testing.ex
@test/example/lib/example_web/router.ex
@test/example/priv/playwright/fixtures/mailbox.ts
@test/example/test/example_web/controllers/session_controller_test.exs
@test/sigra/install/oauth_generator_test.exs
@priv/templates/sigra.gen.oauth/oauth_controller.ex
@priv/templates/sigra.gen.oauth/oauth_settings_live.ex

<interfaces>
<!-- Locked contracts the executor implements against. Source-of-truth: 87-RESEARCH.md `## Module APIs` + `## oauthIssuer.ts Wire Format`. -->

From `Sigra.Testing.OAuthIssuer` (NEW — `test/support/sigra/testing/oauth_issuer.ex`):
```elixir
@type t :: %__MODULE__{base_url: String.t(), state: pid()}
defstruct [:base_url, :state]

@spec start_link(keyword()) :: {:ok, t()} | {:error, term()}
# Options:
#   :provider          — :google (v1.20 only; structure leaves room for :github | :apple | :facebook)
#   :user              — initial user claims map (default: see @default_user)
#   :kid_count         — 1 | 2 (default: 1) — number of JWKs in /jwks
#   :exp               — DateTime | seconds-from-now (default: 3600)
#   :refresh_rotation  — boolean (default: true)
#   :pkce_required     — boolean (default: true — bad code_verifier MUST 400)

@spec set_user(t(), map()) :: :ok
@spec set_kid_count(t(), 1 | 2) :: :ok
@spec url(t()) :: String.t()             # http://127.0.0.1:<ephemeral-port>
@spec openid_config(t()) :: map()        # discovery doc map (issuer / authorization_endpoint / token_endpoint / userinfo_endpoint / jwks_uri)
@spec stop(t()) :: :ok

# Endpoints (Google-shaped paths per D-87-02):
#   GET  /.well-known/openid-configuration
#   GET  /oauth2/v2/auth     -> 302 to redirect_uri?code=...&state=...
#   POST /token              -> JSON {access_token, refresh_token, id_token, token_type=Bearer, expires_in}
#   GET  /userinfo           -> JSON user_claims (incl. email_verified BOOLEAN)
#   GET  /jwks               -> JSON {keys: [<JWK>...]}  length = kid_count
```

From `oauthIssuer.ts` (NEW — `test/example/priv/playwright/fixtures/oauthIssuer.ts`):
```typescript
import { Page } from '@playwright/test';

export type GoogleClaims = {
  sub: string;
  email: string;
  email_verified: boolean;
  name?: string;
  picture?: string;
};

export async function setupIssuer(page: Page, claims: Partial<GoogleClaims>): Promise<void>;
export async function resetIssuer(page: Page): Promise<void>;
export async function probeIdentities(
  page: Page,
  userEmail: string,
): Promise<{ count: number; rows: Array<{ provider: string; provider_uid: string }> }>;
```

From `ExampleWeb.TestOAuthIssuerController` (NEW — `test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex`):
```elixir
def setup(conn, %{"provider" => "google", "user" => user_claims}) :: Plug.Conn.t()
def reset(conn, _params) :: Plug.Conn.t()
# setup spawns Sigra.Testing.OAuthIssuer + sets Application.put_env(:sigra, :oauth_provider_overrides, [google: [...]])
# reset stops it and Application.delete_env/2
```

From `ExampleWeb.TestDbProbeController` (NEW — `test/example/lib/example_web/controllers/test_db_probe_controller.ex`):
```elixir
# GET /test/db_probe?table=user_identities&user_email=<email>
# -> JSON %{count: integer, rows: [%{provider: String.t(), provider_uid: String.t()}, ...]}
def show(conn, %{"table" => "user_identities", "user_email" => email}) :: Plug.Conn.t()
```

Verbatim source strings (load-bearing — Plan 87-01b Playwright specs paste these into assertions; this plan only needs to avoid mutating them in any inherited file):
```
# priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92 (HEEx title attribute)
Set a password first to keep access to your account.

# priv/templates/sigra.gen.oauth/oauth_controller.ex:96 (flash interpolation; provider atom -> bare slug)
An account with this email exists. Log in to link your google account.
```
</interfaces>
</context>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Browser → example-app HTTP stack (Playwright/Bandit on :4000) | Untrusted client; Plan 87-01b's OAuth callback parameters cross here. This plan defines the env-gated test surface. |
| Example-app → Sigra.Testing.OAuthIssuer (loopback HTTP on 127.0.0.1:<ephemeral>) | Trusted in-process test boundary; MUST NOT bind 0.0.0.0. |
| Test-only HTTP endpoints `/test/db_probe` + `/test/oauth_issuer/{setup,reset}` | Pre-production-only routes; env-gated mount; MUST NOT compile into a release. |
| Committed RSA test fixture PEMs (kid1 / kid2) | Must be excluded from Hex package files list (mix.exs:146 excludes `test/`); marked TEST FIXTURE in fixture README; MUST NOT be reused for production signing. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-87-01 | Information disclosure | `/test/db_probe` shipped to production | mitigate | Mount via `if System.get_env("EXAMPLE_DB_PROBE_ENABLED") == "1" do ... end` block in `test/example/lib/example_web/router.ex` (mirrors lines 172-177 dev_routes pattern); `test/example/test/example_web/test_endpoints_test.exs` asserts `EXAMPLE_DB_PROBE_ENABLED=0` → `GET /test/db_probe` returns 404 (regression-locked); document at top of controller file `# Never ship to production`. |
| T-87-02 | Tampering | `/test/oauth_issuer/{setup,reset}` shipped to production | mitigate | Same env-gate (`EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`); `test_endpoints_test.exs` covers both env vars in the same regression suite; whitelist provider param to `"google"` and atomize claims via a private helper that drops unknown keys. |
| T-87-03 | Spoofing | RSA fixture private key reused as production signing key | mitigate | Files at `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid{1,2}_private.pem` outside Hex package files list (`mix.exs:146` is `~w(lib priv docs ...)` — no `test/`); each PEM has an ASCII header comment `# TEST FIXTURE — Sigra.Testing.OAuthIssuer; never use for production signing`; `test/support/sigra/testing/fixtures/README.md` documents the role + regeneration procedure. |
| T-87-04 | Tampering | Mock issuer accepts any PKCE code_verifier (would mask real Sigra bugs) | mitigate | `Sigra.Testing.OAuthIssuer` token endpoint computes `:crypto.hash(:sha256, code_verifier) \|> Base.url_encode64(padding: false)` and matches against the stashed `code_challenge`; mismatch returns 400; explicit ExUnit case `test "rejects bad code_verifier"` in oauth_issuer_test.exs. |
| T-87-05 | Spec violation (masks real Sigra bugs) | `email_verified` returned as string (e.g. "true") instead of boolean | mitigate | Issuer always returns `email_verified` as JSON boolean; explicit regression test asserts `Jason.decode!(body)["email_verified"] === true` (atom-level identity, not string). D-87-02 footgun coverage. |
| T-87-07 | Information disclosure | TestServer base URL leaks into production via `Application.put_env(:sigra, :oauth_provider_overrides, ...)` | mitigate | Override env is set only by `TestOAuthIssuerController.setup/2` (env-gated mount T-87-02); `reset/2` calls `Application.delete_env/2`; `oauthIssuer.ts:resetIssuer` is invoked in test `finally` blocks (Plan 87-01b); controller-test setup uses `on_exit/1` to clean up. |

</threat_model>

<verification>
- `mix deps.get && mix compile --warnings-as-errors` — succeeds with `:test_server` resolved at ~> 0.1.22.
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/testing/oauth_issuer_test.exs --color=never` — exits 0 with non-zero test count and 0 failures.
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test EXAMPLE_DB_PROBE_ENABLED=0 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=0 mix test test/example_web/test_endpoints_test.exs --include example_app --color=never` — exits 0 (env-gate fail-safe-closed regression green).
- `! grep -rEq "accounts\\.google\\.com|oauth2\\.googleapis\\.com|googleapis\\.com" test/sigra/testing/oauth_issuer.ex test/example/priv/playwright/fixtures/oauthIssuer.ts` — no real-Google URLs in test/test-support code (Warning #6 mitigation).
- All Sigra-side library CI lanes still green at the wave-1 SHA: `mix test`, all existing.
</verification>

<success_criteria>
- `Sigra.Testing.OAuthIssuer` ships with all 5 endpoints implemented (RS256 signing, multi-kid JWKS, real PKCE, configurable exp, refresh rotation, email_verified boolean) and the unit test suite is GREEN with at least 9 describe blocks covering every D-87-02 footgun.
- The example-app env-gated test mounts (`/test/db_probe`, `/test/oauth_issuer/{setup,reset}`) compile, route only when their respective env vars are `"1"`, and the `test_endpoints_test.exs` regression assertion holds (env-unset → 404).
- `oauthIssuer.ts` Playwright helper exports the three contract functions (`setupIssuer / resetIssuer / probeIdentities`) for Plan 87-01b to bind against.
- No real-Google network endpoints referenced in any committed test or test-support file.
- The four RSA PEM fixtures are committed with TEST-FIXTURE header comments, parse via `:public_key.pem_decode/1`, and the README documents the regeneration procedure + threat-model citation.
</success_criteria>

<output>
After completion, create `.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-01a-SUMMARY.md` summarizing the issuer module surface, env-gate regression, oauthIssuer.ts contract, and any deviations from this plan's `<interfaces>` block. Plan 87-01b inherits this surface verbatim.
</output>

<tasks>

<task type="auto">
  <name>Task 1: Wave-0 stubs + scaffolding — test_server dep, RSA fixture PEMs, Sigra.Testing.OAuthIssuer skeleton, oauthIssuer.ts impl, env-gated test routes/controllers, env-gate regression test</name>
  <files>mix.exs, test/support/sigra/testing/oauth_issuer.ex, test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_private.pem, test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_public.pem, test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_private.pem, test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_public.pem, test/support/sigra/testing/fixtures/README.md, test/sigra/testing/oauth_issuer_test.exs, test/example/priv/playwright/fixtures/oauthIssuer.ts, test/example/lib/example_web/router.ex, test/example/lib/example_web/controllers/test_db_probe_controller.ex, test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex, test/example/test/example_web/test_endpoints_test.exs</files>
  <read_first>
    - `mix.exs` (full) — confirm `elixirc_paths(:test) -> ["lib", "test/support"]` already at line 55 and find dep insertion point at line 122 (after `:postgrex`).
    - `test/example/lib/example_web/router.ex` lines 168-200 — copy the env-gated mount block style verbatim (`Application.compile_env(:example, :dev_routes)` analog → `System.get_env(...) == "1"` runtime gate).
    - `test/example/priv/playwright/fixtures/mailbox.ts` (full) — pattern reference for the new `oauthIssuer.ts` plain helper module (NOT `test.extend` per 87-PATTERNS.md anti-pattern row).
    - 87-CONTEXT.md `## decisions` blocks D-87-02 (issuer shape) + D-87-05 (per-spec design — read for context, this plan implements the test-seam, Plan 87-01b implements the specs themselves).
    - 87-RESEARCH.md `## Module APIs and Function Signatures > Sigra.Testing.OAuthIssuer` (full module API), `## oauthIssuer.ts Wire Format`, `## DB Probe Seam — Tradeoff Analysis` (Option A confirmed), `## Application Config Injection`, `## Risks and Footguns > High-impact #1, #2, #3, #4`.
    - 87-PATTERNS.md rows for `test/support/sigra/testing/oauth_issuer.ex`, RSA pem fixtures, `oauthIssuer.ts`, `test/example/lib/example_web/router.ex` extension, `test_db_probe_controller.ex`, `test_oauth_issuer_controller.ex`, and the four Anti-Patterns block at the bottom.
    - 87-VALIDATION.md `## Wave 0 Requirements` row "Test-only DB probe / OAuth-issuer-setup endpoint" (the row that mandates `mix test test/example/test/example_web/test_endpoints_test.exs`) and the per-task verification matrix rows for issuer / oauthIssuer.ts / test endpoints.
    - `lib/sigra/oauth.ex:get_provider_config/2` and `lib/sigra/oauth/strategies.ex` and `lib/sigra/oauth/strategies/google.ex` — verify Assumption A1 (provider config read at request time, not boot time). If Sigra caches at boot, surface and add a `Sigra.OAuth.reload_config!/0` test helper as part of this task before locking the implementation.
    - `lib/sigra/testing.ex` lines 1-30 (moduledoc voice) and lines 990-1095 (`mock_oauth_callback/1` complementary helper — DO NOT deprecate per 87-PATTERNS.md anti-pattern row).
  </read_first>
  <action>
**1. mix.exs dep promotion (per D-87-02 + 87-RESEARCH.md `## Dependency Changes`):**

Insert after the `:postgrex` line (mix.exs:122), before the closing `]` of `defp deps`:
```elixir
      {:test_server, "~> 0.1.22", only: :test}
```

Run `mix deps.get` and commit the resulting `mix.lock` change.

**2. RSA fixture PEMs (per 87-RESEARCH.md `## Module APIs > RSA fixture loading strategy` + 87-PATTERNS.md greenfield-fixture row):**

Generate two distinct 2048-bit RSA keypairs and commit four PEM files. The reproducible incantation (run once, document in fixtures/README.md):
```bash
mkdir -p test/support/sigra/testing/fixtures
for kid in 1 2; do
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
    -out test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid${kid}_private.pem
  openssl rsa -in test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid${kid}_private.pem \
    -pubout -out test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid${kid}_public.pem
done
```

Each PEM file MUST start with the ASCII header comment line `# TEST FIXTURE — Sigra.Testing.OAuthIssuer; never use for production signing` PRECEDING the `-----BEGIN ...-----` marker. (Most PEM tooling treats lines preceding `-----BEGIN` as ignored prelude — verify with `:public_key.pem_decode/1` round-trip in the issuer test before committing.)

Commit `test/support/sigra/testing/fixtures/README.md` documenting:
- Role of each PEM (kid1 = primary signing key; kid2 = multi-kid JWKS rotation coverage when `kid_count: 2`).
- Regeneration command (verbatim copy of the bash above).
- Threat model note: keys MUST NOT be reused for production signing; `mix.exs:146` package files list excludes `test/` so they do not ship to adopters via Hex.
- Citation: D-87-02, T-87-03 in this plan's threat register.

**3. `test/support/sigra/testing/oauth_issuer.ex` — TestServer-backed issuer skeleton (Wave-0 surface — Task 2 fills handlers):**

Implement the `defstruct [:base_url, :state]` shape, the public function signatures (`start_link/1`, `set_user/2`, `set_kid_count/2`, `url/1`, `openid_config/1`, `stop/1`) per the `<interfaces>` block, and the Agent-state container. Endpoint handlers (`/.well-known/openid-configuration`, `/oauth2/v2/auth`, `/token`, `/userinfo`, `/jwks`) are implemented as `defp handle_*` private functions; Task 2 fills them with full RS256 + PKCE + JWKS logic. Module compiles cleanly under `mix compile --warnings-as-errors`.

Module shape: `defstruct [:base_url, :state]`; `state` is an Agent pid carrying `%{user_claims, kid_count, exp_offset, refresh_rotation?, pkce_required?, code_challenges_by_code: %{}}`.

RSA fixture loading: compile-time `@external_resource` for both PEM files; pre-compute and cache JWK structures (`%{"kty" => "RSA", "use" => "sig", "alg" => "RS256", "kid" => "1", "n" => ..., "e" => ...}`).

Module moduledoc verbatim from 87-PATTERNS.md row + cite D-87-02 in the doc body.

**4. `test/sigra/testing/oauth_issuer_test.exs` — Wave-0 RED stubs (Task 2 brings to GREEN):**

`use ExUnit.Case, async: true`. `alias Sigra.Testing.OAuthIssuer`. Define the 9 describe blocks with `@tag :pending` placeholders if needed; they MUST be present in the file so Task 2's GREEN cycle is a fill-in (NOT add-block), and the file must compile under `mix compile --warnings-as-errors` even with stub bodies. The 9 describe blocks (matching Task 2's GREEN expectations):
- `start_link/1 — provider :google`
- `/.well-known/openid-configuration`
- `/oauth2/v2/auth → 302 redirect`
- `/token RS256 sign+verify roundtrip`
- `/token with bad code_verifier`
- `/jwks`
- `configurable exp`
- `refresh-token rotation toggle`
- `email_verified boolean shape`

**5. `test/example/priv/playwright/fixtures/oauthIssuer.ts` — full impl (the contract surface Plan 87-01b binds against):**

Implement verbatim per the `<interfaces>` block. Top-of-file comment MUST document:
```typescript
// NOTE: Playwright workers are pinned to 1 in playwright.config.ts (line ~45 — verify),
// so the Application.put_env-mediated provider overrides set by /test/oauth_issuer/setup
// are safe across these specs. Do NOT enable parallel workers without rewiring this.
```

Three exported functions: `setupIssuer(page, claims)`, `resetIssuer(page)`, `probeIdentities(page, userEmail)`. Each uses `page.evaluate(async () => fetch('/test/...'))` per `mailbox.ts:23-49` precedent. NO references to `accounts.google.com`, `oauth2.googleapis.com`, or `googleapis.com` (T-87-05 — verified by automated grep below).

**6. `test/example/lib/example_web/router.ex` — env-gated test routes (per 87-PATTERNS.md row + T-87-01 / T-87-02):**

Add immediately after the existing `if Application.compile_env(:example, :dev_routes) do ... end` block (around lines 172-177), still inside the same module:
```elixir
  # Test-only DB probe + OAuth-issuer control endpoints — env-gated at runtime so
  # the routes never appear in a production release boot.
  # Citation: 87-CONTEXT.md D-87-05; threat model T-87-01 / T-87-02.
  if System.get_env("EXAMPLE_DB_PROBE_ENABLED") == "1" do
    scope "/test", ExampleWeb do
      pipe_through :api
      get "/db_probe", TestDbProbeController, :show
    end
  end

  if System.get_env("EXAMPLE_OAUTH_ISSUER_CTL_ENABLED") == "1" do
    scope "/test/oauth_issuer", ExampleWeb do
      pipe_through :api
      post "/setup", TestOAuthIssuerController, :setup
      post "/reset", TestOAuthIssuerController, :reset
    end
  end
```

**7. `test/example/lib/example_web/controllers/test_db_probe_controller.ex` (per 87-PATTERNS.md skeleton row):**

```elixir
defmodule ExampleWeb.TestDbProbeController do
  @moduledoc """
  Test-only read-only DB introspection endpoint for Playwright OAuth specs.
  Mounted only when `EXAMPLE_DB_PROBE_ENABLED=1`. Never ship to production.
  Citation: 87-CONTEXT.md D-87-05; threat model T-87-01.
  """
  use ExampleWeb, :controller
  alias Example.Repo
  alias Example.Accounts.UserIdentity
  import Ecto.Query

  def show(conn, %{"table" => "user_identities", "user_email" => email}) do
    rows =
      from(ui in UserIdentity,
        join: u in assoc(ui, :user),
        where: u.email == ^email,
        select: %{provider: ui.provider, provider_uid: ui.provider_uid}
      )
      |> Repo.all()

    json(conn, %{count: length(rows), rows: rows})
  end

  # Whitelist: only `user_identities` in v1.20. Returns 400 for any other table.
  def show(conn, _params), do: conn |> put_status(:bad_request) |> json(%{error: "unsupported probe"})
end
```
Verify the actual schema module name matches (`Example.Accounts.UserIdentity`) and the field name is `provider_uid` (not `uid` or similar) before committing — read `test/example/lib/example/accounts/user_identity.ex`.

**8. `test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex` (per 87-PATTERNS.md skeleton row + T-87-02 / T-87-07):**

```elixir
defmodule ExampleWeb.TestOAuthIssuerController do
  @moduledoc """
  Test-only HTTP endpoint that proxies set_user/reset calls into
  Sigra.Testing.OAuthIssuer + Application.put_env for :oauth_provider_overrides.
  Mounted only when `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`. Never ship to production.
  Citation: 87-CONTEXT.md D-87-02 / D-87-05; threat model T-87-02 / T-87-07.
  """
  use ExampleWeb, :controller

  def setup(conn, %{"provider" => "google", "user" => user_claims}) do
    {:ok, issuer} =
      Sigra.Testing.OAuthIssuer.start_link(
        provider: :google,
        user: atomize_claims(user_claims)
      )

    Application.put_env(:sigra, :oauth_provider_overrides,
      google: [
        base_url: Sigra.Testing.OAuthIssuer.url(issuer),
        openid_configuration: Sigra.Testing.OAuthIssuer.openid_config(issuer)
      ]
    )

    Process.put({__MODULE__, :issuer}, issuer)
    json(conn, %{ok: true, base_url: Sigra.Testing.OAuthIssuer.url(issuer)})
  end

  def setup(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "provider must be google"})

  def reset(conn, _params) do
    case Process.get({__MODULE__, :issuer}) do
      nil -> :ok
      issuer -> Sigra.Testing.OAuthIssuer.stop(issuer)
    end

    Application.delete_env(:sigra, :oauth_provider_overrides)
    json(conn, %{ok: true})
  end

  defp atomize_claims(map) when is_map(map) do
    allowed = ~w(sub email email_verified name picture)
    for {k, v} <- map, k in allowed, into: %{}, do: {String.to_atom(k), v}
  end
end
```

**9. `test/example/test/example_web/test_endpoints_test.exs` — env-gate regression (closes checker Blocker #2; covers T-87-01 + T-87-02):**

```elixir
defmodule ExampleWeb.TestEndpointsTest do
  @moduledoc """
  Phase 87 T-87-01 / T-87-02 regression: the test-only DB probe + OAuth-issuer
  control endpoints MUST be 404 when their env gates are not "1". The router
  evaluates `System.get_env/1` at compile time of the route block, so this
  test is run in two modes:

  1. Default mode (env vars unset / not "1") — routes return 404.
  2. Enabled mode (env vars set to "1") — routes are reachable; this is the
     mode the Playwright OAuth specs (Plan 87-01b) rely on.

  Note: in this codebase the router uses `System.get_env/1` at compile time
  via the `if ... do ... end` block in router.ex. To exercise both modes
  cleanly we either (a) run this test once per gate state (preferred — single
  invocation per ExUnit run, with the env state set up in `setup_all/1`), or
  (b) split into two test files. Pick (a) — assert the env-unset path; the
  enabled path is covered structurally by Plan 87-01b's Playwright specs
  running with the env vars set.
  """
  use ExampleWeb.ConnCase, async: false

  @moduletag :example_app

  describe "T-87-01: GET /test/db_probe is 404 without EXAMPLE_DB_PROBE_ENABLED=1" do
    test "returns 404 when env var is absent", %{conn: conn} do
      assert System.get_env("EXAMPLE_DB_PROBE_ENABLED") in [nil, "0", ""],
             "test/example expects EXAMPLE_DB_PROBE_ENABLED unset for default test runs"

      conn = get(conn, "/test/db_probe", %{"table" => "user_identities", "user_email" => "x@example.test"})
      assert conn.status == 404
    end
  end

  describe "T-87-02: POST /test/oauth_issuer/setup is 404 without EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1" do
    test "returns 404 when env var is absent", %{conn: conn} do
      assert System.get_env("EXAMPLE_OAUTH_ISSUER_CTL_ENABLED") in [nil, "0", ""],
             "test/example expects EXAMPLE_OAUTH_ISSUER_CTL_ENABLED unset for default test runs"

      conn = post(conn, "/test/oauth_issuer/setup", %{"provider" => "google", "user" => %{}})
      assert conn.status == 404
    end

    test "POST /test/oauth_issuer/reset is 404 when env var is absent", %{conn: conn} do
      conn = post(conn, "/test/oauth_issuer/reset", %{})
      assert conn.status == 404
    end
  end
end
```

This test runs in CI without the env vars set (`EXAMPLE_DB_PROBE_ENABLED=0` / unset), proving the env-gate fail-safe-closed. The ENABLED path is covered structurally by Plan 87-01b's Playwright job.

Verify Assumption A1 (provider config read at request time): if confirmed, proceed. If `lib/sigra/oauth.ex` caches provider config at boot, ALSO add a `Sigra.OAuth.reload_config!/0` test helper at the same time as the issuer module so `TestOAuthIssuerController.setup/2` can call it after `Application.put_env/3`.
  </action>
  <verify>
    <automated>mix deps.get && mix compile --warnings-as-errors 2>&1 | grep -qv "warning:" && grep -q ":test_server" mix.exs && test -f test/support/sigra/testing/oauth_issuer.ex && grep -q "def start_link" test/support/sigra/testing/oauth_issuer.ex && grep -q "TestServer" test/support/sigra/testing/oauth_issuer.ex && test -s test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_private.pem && test -s test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2_private.pem && grep -q "TEST FIXTURE" test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1_private.pem && grep -q "TEST FIXTURE" test/support/sigra/testing/fixtures/README.md && test -f test/example/priv/playwright/fixtures/oauthIssuer.ts && grep -q "export async function setupIssuer" test/example/priv/playwright/fixtures/oauthIssuer.ts && grep -q "EXAMPLE_DB_PROBE_ENABLED" test/example/lib/example_web/router.ex && grep -q "EXAMPLE_OAUTH_ISSUER_CTL_ENABLED" test/example/lib/example_web/router.ex && test -f test/example/lib/example_web/controllers/test_db_probe_controller.ex && test -f test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex && test -f test/example/test/example_web/test_endpoints_test.exs && grep -q 'EXAMPLE_DB_PROBE_ENABLED' test/example/test/example_web/test_endpoints_test.exs && grep -qE '404|conn\.status == 404' test/example/test/example_web/test_endpoints_test.exs && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test EXAMPLE_DB_PROBE_ENABLED=0 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=0 mix test test/example_web/test_endpoints_test.exs --include example_app --color=never 2>&1 | grep -E "[0-9]+ tests?, 0 failures"</automated>
  </verify>
  <acceptance_criteria>
    - `mix.exs` deps list contains `{:test_server, "~> 0.1.22", only: :test}` (grep `:test_server` returns the line; `mix deps | grep test_server` shows the resolved version after `mix deps.get`).
    - All four PEM files exist, are non-empty, parse via `:public_key.pem_decode/1` round-trip, AND each starts with the line `# TEST FIXTURE — Sigra.Testing.OAuthIssuer; never use for production signing` before the BEGIN marker.
    - `test/support/sigra/testing/fixtures/README.md` contains the regeneration command and the threat-model citation (T-87-03).
    - `test/support/sigra/testing/oauth_issuer.ex` defines `start_link/1`, `set_user/2`, `set_kid_count/2`, `url/1`, `openid_config/1`, `stop/1` with the spec from `<interfaces>`; module compiles via `mix compile --warnings-as-errors`.
    - `test/sigra/testing/oauth_issuer_test.exs` exists with at least 9 `describe` blocks (RED stubs at this checkpoint OK; will become GREEN in Task 2).
    - `test/example/priv/playwright/fixtures/oauthIssuer.ts` exports the 3 functions per `<interfaces>` block; uses `page.evaluate(...)` for cross-process state mutation; documents the workers=1 assumption.
    - The router has the two `if System.get_env("EXAMPLE_..._ENABLED") == "1"` blocks; without those env vars set, `cd test/example && mix phx.routes 2>&1 | grep -c "/test/db_probe\|/test/oauth_issuer"` returns 0.
    - The two test-only controllers exist with the contracts in `<interfaces>`; both modules compile.
    - `test/example/test/example_web/test_endpoints_test.exs` includes `EXAMPLE_DB_PROBE_ENABLED` AND `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED` env-var checks AND assertions of `conn.status == 404` (or equivalent 404 assertion) — verified by grep AND by running the test green with `EXAMPLE_DB_PROBE_ENABLED=0 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=0`.
    - For Assumption A1: a comment in `test/support/sigra/testing/oauth_issuer.ex` documents whether `Sigra.OAuth` reads provider config at request time (research recommendation) OR adds a `Sigra.OAuth.reload_config!/0` test helper if it caches at boot. Either way is acceptable, but the choice MUST be documented inline.
  </acceptance_criteria>
  <done>The mock-issuer skeleton, RSA fixtures, env-gated test endpoints, oauthIssuer.ts fixture, and the env-gate regression test all exist; library compiles --warnings-as-errors; the regression test is GREEN under env-unset; Task 2 has a working module surface to bind against.</done>
</task>

<task type="auto">
  <name>Task 2: Sigra.Testing.OAuthIssuer GREEN — implement all 5 endpoints, RS256 signing, kid rotation, real PKCE, and pass oauth_issuer_test.exs (incl. no-real-Google grep)</name>
  <files>test/support/sigra/testing/oauth_issuer.ex, test/sigra/testing/oauth_issuer_test.exs</files>
  <read_first>
    - The Wave-0 skeleton from Task 1 (read it back to confirm structure before extending).
    - 87-RESEARCH.md `## Module APIs and Function Signatures > Sigra.Testing.OAuthIssuer` (full, including the "Internal endpoint plugs (private — not exported)" subsection — implement those four `defp handle_*` functions verbatim).
    - 87-RESEARCH.md `## Risks and Footguns > High-impact #2` (TestServer route lifetime — confirm `to:` form for the persistent JWKS/token/userinfo/discovery handlers; if FIFO, fall back to a Bandit Plug.Router subprocess instead).
    - 87-RESEARCH.md `## Risks and Footguns > High-impact #5` (HTTPS issuer URL — set `iss` claim to `issuer.base_url` not a synthetic `https://google.test`).
    - 87-CONTEXT.md D-87-02 footgun mitigations block (real PKCE, email_verified boolean, configurable exp, refresh-rotation toggle, kid rotation).
    - 87-PATTERNS.md row for `test/sigra/testing/oauth_issuer_test.exs` (AAA-flat pattern from `test/sigra/install/oauth_generator_test.exs:8-37`).
    - 87-VALIDATION.md per-task verification map row for the issuer module test.
    - The two RSA PEM files committed in Task 1 (use `File.read!/1` + `:public_key.pem_decode/1` to parse; cache the parsed `{:RSAPrivateKey, ...}` records as module attributes).
    - `lib/sigra/testing.ex` lines 1-30 (moduledoc voice) — the `Sigra.Testing.OAuthIssuer` moduledoc must match this voice.
  </read_first>
  <action>
Replace the Wave-0 skeleton's `defp handle_*` stubs with full implementations. Implement each of the five OIDC endpoints with TestServer-registered persistent handlers (`to:` form, NOT one-shot `plug:`):

**A. `/.well-known/openid-configuration`** — `Plug.Conn` returns:
```elixir
%{
  "issuer" => issuer.base_url,
  "authorization_endpoint" => issuer.base_url <> "/oauth2/v2/auth",
  "token_endpoint" => issuer.base_url <> "/token",
  "userinfo_endpoint" => issuer.base_url <> "/userinfo",
  "jwks_uri" => issuer.base_url <> "/jwks",
  "response_types_supported" => ["code"],
  "subject_types_supported" => ["public"],
  "id_token_signing_alg_values_supported" => ["RS256"],
  "scopes_supported" => ["openid", "email", "profile"],
  "token_endpoint_auth_methods_supported" => ["client_secret_post"]
} |> Jason.encode!()
```

**B. `/oauth2/v2/auth`** — parse `client_id`, `redirect_uri`, `response_type=code`, `scope`, `state`, `code_challenge`, `code_challenge_method=S256`. Generate a fresh `auth_code` (random 32 bytes URL-safe-base64). Stash `%{code_challenge: ..., redirect_uri: ..., state: ...}` keyed by `auth_code` in Agent state. Respond 302 to `<redirect_uri>?code=<auth_code>&state=<state>`.

**C. `/token`** — accept POST with `grant_type=authorization_code`, `code`, `redirect_uri`, `code_verifier`. Look up stashed code_challenge by `code`. Compute `Base.url_encode64(:crypto.hash(:sha256, code_verifier), padding: false)` and compare. On mismatch return 400 `{"error":"invalid_grant","error_description":"PKCE verifier mismatch"}`. On match, build id_token claims (`%{sub: ..., email: ..., email_verified: BOOLEAN, iss: issuer.base_url, aud: client_id, iat: now, exp: now + exp_offset, ...}`), sign with kid=1 private key (RS256: `:public_key.sign(payload_bytes, :sha256, private_key)`), assemble JWS Compact `<base64url(header)>.<base64url(payload)>.<base64url(signature)>`. Return JSON `%{access_token: random_token, refresh_token: random_token, id_token: jws, token_type: "Bearer", expires_in: exp_offset}`. If `refresh_rotation: false`, the refresh_token is deterministic across calls (e.g. `"static-refresh-#{auth_code}"`).

**D. `/userinfo`** — parse `Authorization: Bearer <access_token>` header (if present); return current `user_claims` Agent state as JSON. `email_verified` MUST be a JSON boolean.

**E. `/jwks`** — return `%{"keys" => [<JWK1>, <JWK2_if_kid_count_2>]}`. Each JWK is `%{"kty"=>"RSA", "use"=>"sig", "alg"=>"RS256", "kid"=>"1" | "2", "n"=>base64url(modulus), "e"=>base64url(exponent)}`. Modulus + exponent extracted from the parsed RSAPrivateKey records.

Then expand `test/sigra/testing/oauth_issuer_test.exs` to GREEN per the 9 describe blocks listed in Task 1 step 4 (discovery shape, authorize→302, token RS256 roundtrip, bad code_verifier, jwks count 1+2, configurable exp, refresh-rotation toggle, email_verified boolean shape). Use `Req.request/1` (already in deps via Assent) to drive HTTP requests against the issuer base_url; OR use `:httpc` if Req is not available in the lib-test path. AAA-flat — blank-line-separated, no helper extraction.

The `email_verified` boolean test MUST use `Jason.decode!(body)["email_verified"] === true` (atom-identity `===`, NOT `==`) so a string `"true"` would fail.

NO references to `accounts.google.com` / `oauth2.googleapis.com` / `googleapis.com` in either file (verified by automated grep below — Warning #6 mitigation).
  </action>
  <verify>
    <automated>PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/testing/oauth_issuer_test.exs --color=never 2>&1 | grep -E "[0-9]+ tests?, 0 failures" && grep -c "describe " test/sigra/testing/oauth_issuer_test.exs | awk '$1 >= 9 { exit 0 } { exit 1 }' && grep -q "=== true" test/sigra/testing/oauth_issuer_test.exs && ! grep -rEq "accounts\\.google\\.com|oauth2\\.googleapis\\.com|googleapis\\.com" test/sigra/testing/oauth_issuer.ex test/example/priv/playwright/fixtures/oauthIssuer.ts</automated>
  </verify>
  <acceptance_criteria>
    - `mix test test/sigra/testing/oauth_issuer_test.exs` returns 0 failures with at least 9 describe blocks (one per cell from 87-RESEARCH.md `## Validation Architecture > Per-spec coverage matrix > Frequency-amplitude grid for OAuth issuer endpoints`).
    - The `/jwks` endpoint exposes 1 key with `kid_count: 1` and 2 keys with `kid_count: 2` — explicit assertions.
    - `/token` returns 400 with body `~r/invalid_grant/` when `code_verifier` is wrong.
    - `id_token` produced by `/token` parses as JWS Compact; signature verifies against the JWK from `/jwks`; claims include `sub`, `email`, `email_verified` boolean true, `iss == issuer.base_url`, `iat`, `exp`.
    - `Jason.decode!(body)["email_verified"] === true` assertion is present in the test file (use grep: `grep -q "=== true" test/sigra/testing/oauth_issuer_test.exs`).
    - No real-Google network traffic during the test run (TestServer only); the automated grep `! grep -rEq 'accounts\\.google\\.com|oauth2\\.googleapis\\.com|googleapis\\.com' test/sigra/testing/oauth_issuer.ex test/example/priv/playwright/fixtures/oauthIssuer.ts` returns 0 hits.
  </acceptance_criteria>
  <done>Sigra.Testing.OAuthIssuer fully implements all 5 endpoints with RS256 signing, multi-kid JWKS, real PKCE, configurable exp, refresh rotation, and email_verified boolean shape; the unit test suite is GREEN and covers every D-87-02 footgun; the no-real-Google grep is clean.</done>
</task>

</tasks>
</content>
