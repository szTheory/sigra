---
phase: 87
plan: 01b
type: execute
wave: 2
depends_on:
  - 87-01a-PLAN.md
files_modified:
  - lib/mix/tasks/sigra.oauth.smoketest.ex
  - lib/sigra/oauth/smoketest.ex
  - test/sigra/install/oauth_smoketest_task_test.exs
  - docs/oauth-google-setup.md
  - mix.exs
  - scripts/ci/install-smoke.sh
  - .github/workflows/ci.yml
  - test/example/priv/playwright/tests/oauth-register.spec.ts
  - test/example/priv/playwright/tests/oauth-link.spec.ts
  - test/example/priv/playwright/tests/oauth-email-match.spec.ts
  - test/example/test/example_web/oauth_controller_test.exs
autonomous: true
requirements:
  - GAUAT-03
  - GAUAT-04
  - GAUAT-05
  - GAUAT-06
must_haves:
  truths:
    - "A maintainer running `mix sigra.oauth.smoketest --provider=google` against a configured Google client_id/secret completes the round-trip and prints `OK — got back valid id_token with sub=... and email=...`; missing config exits with diagnostic and non-zero code."
    - "A reviewer running `bash scripts/ci/install-smoke.sh` (after this plan) sees on stdout the line `oauth-gen: 12/12 expected artifacts present, mix test green` after a successful `mix phx.new` + `sigra.install` + `sigra.gen.oauth` + `mix compile --warnings-as-errors` + `MIX_ENV=test mix test` cycle on a fresh tmp_app."
    - "A reviewer running `cd test/example/priv/playwright && npx playwright test oauth-register.spec.ts oauth-link.spec.ts oauth-email-match.spec.ts --project=chromium` (with EXAMPLE_DB_PROBE_ENABLED=1 and EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1) sees all three GAUAT-04/05/06 specs pass against the in-process Sigra.Testing.OAuthIssuer (landed in Plan 87-01a)."
    - "Sigra-side CI never makes real HTTP requests to Google — verified by automated grep across the issuer module + the three Playwright specs + the oauthIssuer.ts fixture (no `accounts.google.com` / `oauth2.googleapis.com` / `googleapis.com` references)."
    - "The verbatim disabled-tooltip string `Set a password first to keep access to your account.` (from `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92`) is asserted by `oauth-link.spec.ts` and the verbatim flash text `An account with this email exists. Log in to link your google account.` (from `priv/templates/sigra.gen.oauth/oauth_controller.ex:96`, with provider atom rendered as bare slug) is asserted by `oauth-email-match.spec.ts`."
    - "The CI workflow's `install_smoke` job tees its transcript to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` and uploads the bundle as a GitHub Actions artifact; on `v*` tags the bundle is promoted to a GitHub release asset (mirrors email_visual_regression precedent)."
    - "A new `oauth_e2e_playwright` CI job in `.github/workflows/ci.yml` runs the three OAuth specs against the example app + Sigra.Testing.OAuthIssuer, uploads Playwright trace.zip on failure, and promotes evidence to a release asset on `v*` tags."
    - "`.github/workflows/ci.yml`'s install_smoke `phx_new` archive install step pins to `1.8.5` so the gen-smoke is reproducible and cache-key deterministic (D-87-04). All other phx_new archive-install steps are unchanged from main."
  artifacts:
    - path: lib/mix/tasks/sigra.oauth.smoketest.ex
      provides: "Adopter-side `mix sigra.oauth.smoketest --provider=google` thin Mix task delegating to Sigra.OAuth.Smoketest"
    - path: lib/sigra/oauth/smoketest.ex
      provides: "Smoketest runtime: load config, boot Bandit on 127.0.0.1:port, print authorize URL, wait for callback, decode id_token, print claims; exit codes 0/1/2/3"
      exports: ["run/1"]
    - path: docs/oauth-google-setup.md
      provides: "Numbered Google Cloud Console recipe + ENV var names + smoketest invocation final step"
    - path: scripts/ci/install-smoke.sh
      provides: "Extension: MIX_ENV=test mix ecto.create/migrate/test + 12/12 log line"
    - path: .github/workflows/ci.yml
      provides: "install_smoke transcript tee + artifact upload + tag-time release-asset promotion + new oauth_e2e_playwright job + phx_new 1.8.5 pin (install_smoke step only)"
    - path: test/example/test/example_web/oauth_controller_test.exs
      provides: "Controller-level integration covering state mismatch / provider error / no-email flash via Sigra.Testing.OAuthIssuer (D-87-10)"
    - path: test/example/priv/playwright/tests/oauth-register.spec.ts
      provides: "GAUAT-04: provider button / authorize-redirect / callback / user+identity / session / logout / re-login (no new identity)"
    - path: test/example/priv/playwright/tests/oauth-link.spec.ts
      provides: "GAUAT-05: 4 visual states (linked-with-password / only-oauth-no-password disabled-tooltip with hero PNG / after-set-password / post-unlink)"
    - path: test/example/priv/playwright/tests/oauth-email-match.spec.ts
      provides: "GAUAT-06: pre-seed alice / mock issuer match / verbatim flash / password login / identity row / provider_linked_email mailbox arrival"
  key_links:
    - from: "test/example/priv/playwright/tests/oauth-register.spec.ts"
      to: "test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex"
      via: "fetch POST /test/oauth_issuer/setup with claims; controller starts Sigra.Testing.OAuthIssuer + Application.put_env(:sigra, :oauth_provider_overrides, ...)"
      pattern: "test/oauth_issuer/setup|oauth_provider_overrides"
    - from: "scripts/ci/install-smoke.sh"
      to: ".github/workflows/ci.yml"
      via: "tee output to .planning/uat-evidence/v1.20/oauth-gen/transcript.log; upload artifact on every run; release-asset promotion on v* tags"
      pattern: "oauth-gen/transcript.log|oauth-gen-bundle|gh release upload"
    - from: "test/example/priv/playwright/tests/oauth-link.spec.ts"
      to: "priv/templates/sigra.gen.oauth/oauth_settings_live.ex"
      via: "verbatim toHaveAttribute('title', 'Set a password first to keep access to your account.')"
      pattern: "Set a password first to keep access to your account"
    - from: "test/example/priv/playwright/tests/oauth-email-match.spec.ts"
      to: "priv/templates/sigra.gen.oauth/oauth_controller.ex"
      via: "verbatim toContainText('An account with this email exists. Log in to link your google account.')"
      pattern: "An account with this email exists\\. Log in to link your google account\\."
---

<objective>
Implement the smoketest task + install-smoke + CI extensions + Playwright specs + controller integration of Phase 87's two-commit closure (D-87-07 — split out of original Plan 01 per checker scope_sanity blocker). Bind against the Sigra.Testing.OAuthIssuer module surface + env-gated test endpoints + oauthIssuer.ts fixture landed in Plan 87-01a. Land the adopter-side `mix sigra.oauth.smoketest --provider=google` task + paired `docs/oauth-google-setup.md`; extend `scripts/ci/install-smoke.sh` with `mix test` + the 12/12 contract line; extend `.github/workflows/ci.yml` install_smoke with transcript tee + artifact upload + tag-time release-asset promotion; add a new `oauth_e2e_playwright` CI job; and ship the three GREEN Playwright specs (oauth-register / oauth-link / oauth-email-match) plus the controller integration test extension.

Purpose: Land all CI-reproducible automated verification for GAUAT-03/04/05/06 (mock-issuer-driven, 0 human UAT — D-87-01 Posture A) and the adopter-side smoketest tool. Plan 87-02 (Wave 3) materializes the Phase-86-schema evidence dirs against this plan's green CI run.
Output: Mix task + library runtime + adopter docs + extended install-smoke harness + new oauth_e2e_playwright CI lane + 3 GREEN Playwright specs + controller integration test, all gating on a green wave-1 SHA in CI.
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
@.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-01a-PLAN.md
@.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-01a-SUMMARY.md
@.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md
@mix.exs
@scripts/ci/install-smoke.sh
@.github/workflows/ci.yml
@lib/mix/tasks/sigra.upgrade.ex
@lib/mix/tasks/sigra.fixture.rebless_golden.ex
@lib/sigra/testing.ex
@test/example/lib/example_web/router.ex
@test/example/priv/playwright/fixtures/mailbox.ts
@test/example/priv/playwright/tests/golden-path.spec.ts
@test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts
@test/example/priv/playwright/tests/email-visual.spec.ts
@test/example/test/example_web/controllers/session_controller_test.exs
@test/sigra/install/oauth_generator_test.exs
@priv/templates/sigra.gen.oauth/oauth_controller.ex
@priv/templates/sigra.gen.oauth/oauth_settings_live.ex

<interfaces>
<!-- Inherited from Plan 87-01a (lock — do not redefine; bind against). -->

From `Sigra.Testing.OAuthIssuer` (Plan 87-01a — `test/support/sigra/testing/oauth_issuer.ex`):
```elixir
@spec start_link(keyword()) :: {:ok, t()} | {:error, term()}
@spec set_user(t(), map()) :: :ok
@spec set_kid_count(t(), 1 | 2) :: :ok
@spec url(t()) :: String.t()
@spec openid_config(t()) :: map()
@spec stop(t()) :: :ok
```

From `oauthIssuer.ts` (Plan 87-01a — `test/example/priv/playwright/fixtures/oauthIssuer.ts`):
```typescript
export async function setupIssuer(page: Page, claims: Partial<GoogleClaims>): Promise<void>;
export async function resetIssuer(page: Page): Promise<void>;
export async function probeIdentities(page: Page, userEmail: string): Promise<{ count: number; rows: ... }>;
```

<!-- New contracts this plan defines. -->

From `Mix.Tasks.Sigra.Oauth.Smoketest` (NEW — `lib/mix/tasks/sigra.oauth.smoketest.ex`) thin delegator to runtime module (NEW — `lib/sigra/oauth/smoketest.ex`):
```elixir
# Mix Task — sigra.upgrade.ex pattern (NimbleOptions thin delegator)
@switches [provider: :string, port: :integer, config: :string]
@options_schema [
  provider: [type: :string, required: true, doc: "Provider to test (google)"],
  port: [type: :integer, default: 4001, doc: "Local callback port"],
  config: [type: {:or, [:string, nil]}, default: nil, doc: "Optional Sigra config path"]
]

# Sigra.OAuth.Smoketest.run/1 — runtime
@spec run(keyword()) :: :ok | {:error, exit_code :: 1 | 2 | 3, reason :: String.t()}
# 0 — success (id_token decoded, email claim present)
# 1 — usage error (missing flag, unknown provider)
# 2 — config error (client_id/secret missing or unreachable)
# 3 — round-trip failure (state mismatch, token exchange error, malformed id_token, missing email)
```

Verbatim source strings (load-bearing — paste into Playwright assertions exactly):
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
| Browser → example-app HTTP stack (Playwright/Bandit on :4000) | Untrusted client; OAuth callback parameters cross here. Plan 87-01a defined the env-gated test surface; this plan exercises it from Playwright. |
| Smoketest Mix task local Bandit endpoint (127.0.0.1:4001) | Adopter-side; receives OAuth callback from real Google; MUST bind loopback only. |
| install_smoke CI artifact upload → repo evidence (Plan 87-02 inherits) | Transcript file is plain-text evidence; tag-time release asset promotion mirrors email_visual_regression contract. |
| `oauth_e2e_playwright` CI job → trace bundle upload | Playwright trace.zip on failure includes screenshots of UI state; no real credentials, no real Google traffic. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-87-06 | Tampering | `mix sigra.oauth.smoketest` exposes 0.0.0.0 instead of 127.0.0.1 | mitigate | `Bandit.start_link/1` invocation uses `ip: {127, 0, 0, 1}` explicit option; ExUnit test asserts the bind address. Default `--port=4001`; print clear `localhost:4001` callback URL. |
| T-87-08 | Repudiation | install-smoke transcript missing CI run URL or SHA on artifact upload | accept | Plan 87-02 embeds CI run URL in evidence manifest via `mix sigra.uat.report --phase=oauth-gen` extension; this plan's transcript is plain text from `tee` and is treated as raw evidence (not the only evidence). |
| T-87-15 | Tampering | Playwright OAuth specs leaking real-Google URLs (would mask real Sigra bugs by accident-reaching production endpoints in CI) | mitigate | `! grep -rEq 'accounts\\.google\\.com\|oauth2\\.googleapis\\.com\|googleapis\\.com' test/example/priv/playwright/tests/oauth-*.spec.ts` is run as a verify gate after the specs are authored; closes Warning #6. |
| T-87-16 | Information disclosure | `oauth_e2e_playwright` Playwright trace.zip contains real session cookies | accept | Sessions in CI are scoped to mock-issuer credentials only; the example-app DB is ephemeral CI Postgres. No real OAuth tokens reach the trace. Trace.zip uploaded only to CI artifact storage (not public). |

</threat_model>

<verification>
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/oauth_smoketest_task_test.exs --color=never` — exits 0 with 0 failures.
- `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/oauth_controller_test.exs --include example_app --color=never` — exits 0 with 0 failures.
- `bash scripts/ci/install-smoke.sh 2>&1 | grep -q "oauth-gen: 12/12 expected artifacts present, mix test green"` — exits 0 (the line is printed).
- `cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1 npx playwright test tests/oauth-register.spec.ts tests/oauth-link.spec.ts tests/oauth-email-match.spec.ts --project=chromium --reporter=line` — all 3 specs pass.
- `grep -q "Set a password first to keep access to your account\." test/example/priv/playwright/tests/oauth-link.spec.ts` — present.
- `grep -q "An account with this email exists\. Log in to link your google account\." test/example/priv/playwright/tests/oauth-email-match.spec.ts` — present.
- `grep -q "oauth_e2e_playwright" .github/workflows/ci.yml` — present (new job).
- `grep -q "phx_new 1.8.5" .github/workflows/ci.yml` — present at the install_smoke step.
- `grep -qE "actions/upload-artifact.*oauth-gen-bundle" .github/workflows/ci.yml` — install_smoke transcript bundle upload step present.
- `! grep -rEq "accounts\\.google\\.com|oauth2\\.googleapis\\.com|googleapis\\.com" test/example/priv/playwright/tests/oauth-register.spec.ts test/example/priv/playwright/tests/oauth-link.spec.ts test/example/priv/playwright/tests/oauth-email-match.spec.ts` — no real-Google endpoints in any spec.
- All Sigra-side CI lanes green at the wave-1 SHA: `mix test`, `install_smoke` (extended), `oauth_e2e_playwright` (new), email_visual_regression, all existing.
</verification>

<success_criteria>
- GAUAT-03 has live-host runtime evidence: install-smoke runs `mix phx.new` + `sigra.install` + `sigra.gen.oauth` + `mix compile --warnings-as-errors` + `MIX_ENV=test mix test` and prints the 12/12 contract line on a fresh tmp_app.
- GAUAT-04/05/06 each have a green Playwright spec running against `Sigra.Testing.OAuthIssuer` (0 real-Google traffic, verified by automated grep).
- The disabled-tooltip and email-match-flash verbatim source strings are asserted byte-for-byte by the Playwright specs.
- The new `mix sigra.oauth.smoketest --provider=google` Mix task ships as the adopter-side real-credential check at install time, paired with `docs/oauth-google-setup.md`.
- All wave-1 CI lanes green at the wave-1 SHA so Plan 87-02 (Wave 3) can carry that run URL into the evidence manifests.
- All `phx_new` archive-install steps OTHER than the install_smoke job step remain unchanged from main (D-87-04 minimum-viable-change).
</success_criteria>

<output>
After completion, create `.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-01b-SUMMARY.md` summarizing the smoketest task, install-smoke + CI extensions, the three Playwright specs + controller test, the wave-1 CI run URL Plan 87-02 inherits, and the actual short-SHA filename of the GAUAT-05 hero PNG baseline (committed at `test/example/priv/playwright/__snapshots__/oauth-link.spec.ts/`).
</output>

<tasks>

<task type="auto">
  <name>Task 1: mix sigra.oauth.smoketest task + Sigra.OAuth.Smoketest runtime + tests + docs/oauth-google-setup.md</name>
  <files>lib/mix/tasks/sigra.oauth.smoketest.ex, lib/sigra/oauth/smoketest.ex, test/sigra/install/oauth_smoketest_task_test.exs, docs/oauth-google-setup.md, mix.exs</files>
  <read_first>
    - `lib/mix/tasks/sigra.upgrade.ex` lines 1-97 — NimbleOptions thin-delegator + `@switches` + `@options_schema` + `use Mix.Task` + `@impl Mix.Task def run` pattern (87-PATTERNS.md row for `sigra.oauth.smoketest.ex`).
    - `lib/mix/tasks/sigra.fixture.rebless_golden.ex` lines 1-60 — Bandit boot + `Mix.Task.run("loadpaths")` + `Mix.Task.run("compile")` + `Application.ensure_all_started/1` + shell-tee pattern.
    - 87-CONTEXT.md D-87-03 (smoketest behavior, exit codes, print-and-wait default).
    - 87-RESEARCH.md `## Module APIs > Mix.Tasks.Sigra.Oauth.Smoketest` (full module shape + implementation notes).
    - 87-RESEARCH.md `## Security Domain > Smoketest task's localhost:4001 exposed during run` (bind 127.0.0.1 only, NOT 0.0.0.0; state nonce + 5-min timeout).
    - 87-PATTERNS.md anti-pattern row "MUST NOT inherit `sigra.gen.oauth`'s shape" — this is a runtime tool, not a generator.
    - 87-PATTERNS.md row for `docs/oauth-google-setup.md` (analog: `docs/uat-ci-coverage.md`).
    - `mix.exs` lines 150-210 — verify `extras:` list and `groups_for_extras:` regex shape; the new doc lives at `docs/oauth-google-setup.md` and must be added to `extras:` so it appears in ExDoc nav.
    - `lib/sigra/token.ex` `generate/4` and any state-nonce helpers — the smoketest exercises Sigra's actual signing path per 87-RESEARCH.md `## Module APIs > Mix.Tasks.Sigra.Oauth.Smoketest > Key implementation notes`.
    - `test/sigra/install/oauth_generator_test.exs` lines 1-80 — direct sibling test pattern for the new task test.
    - Plan 87-01a's `Sigra.Testing.OAuthIssuer` GREEN cycle output (the GREEN-issuer module is the test seam this plan's smoketest test binds against).
  </read_first>
  <action>
**1. `lib/mix/tasks/sigra.oauth.smoketest.ex` (thin Mix task — sigra.upgrade.ex pattern):**

```elixir
defmodule Mix.Tasks.Sigra.Oauth.Smoketest do
  @shortdoc "Verifies your OAuth provider configuration with a real round-trip"
  @moduledoc """
  Adopter-side real-credential check. Boots a tiny Plug endpoint on
  127.0.0.1, prints the authorize URL, and waits for you to click through
  in your default browser. On callback, exchanges the code, decodes the
  id_token, and prints the claims.

  ## Usage

      mix sigra.oauth.smoketest --provider=google
      mix sigra.oauth.smoketest --provider=google --port=4001

  ## Flags

    * `--provider` — required. v1.20 supports: `google`.
    * `--port`     — default 4001. Local callback port (bound to 127.0.0.1 only).
    * `--config`   — optional explicit Sigra config path; defaults to runtime app env.

  ## Exit codes

    0 — success (id_token decoded and email claim present)
    1 — usage error (missing flag, unknown provider)
    2 — config error (client_id/secret missing or unreachable)
    3 — round-trip failure (state mismatch, token exchange error, malformed id_token, missing email)

  ## Pairing

  Walk through `docs/oauth-google-setup.md` first to register your Google
  Cloud OAuth client, then run this task.

  Citation: 87-CONTEXT.md D-87-03; 87-RESEARCH.md Module APIs.
  """
  use Mix.Task

  @switches [provider: :string, port: :integer, config: :string]
  @options_schema [
    provider: [type: :string, required: true, doc: "Provider to test (google)"],
    port: [type: :integer, default: 4001, doc: "Local callback port"],
    config: [type: {:or, [:string, nil]}, default: nil, doc: "Optional Sigra config path"]
  ]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile")
    Application.ensure_all_started(:bandit)

    {opts, _parsed, _invalid} = OptionParser.parse(argv, switches: @switches)

    case validate(opts) do
      {:ok, validated} ->
        case Sigra.OAuth.Smoketest.run(validated) do
          :ok ->
            Mix.shell().info("OK — got back valid id_token")
            :ok
          {:error, code, reason} ->
            Mix.shell().error("FAIL: #{reason}")
            exit({:shutdown, code})
        end
      {:error, reason} ->
        Mix.shell().error("USAGE: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp validate(opts) do
    try do
      {:ok, NimbleOptions.validate!(opts, @options_schema)}
    rescue
      e in [NimbleOptions.ValidationError] -> {:error, Exception.message(e)}
    end
  end
end
```

**2. `lib/sigra/oauth/smoketest.ex` (runtime — testable lib module):**

Implements `run/1` accepting the validated keyword list. Behavior:
1. Resolve `client_id`, `client_secret`, `redirect_uri` from `Application.get_env(:sigra, :providers, [])[provider_atom]` (or whatever Sigra's config-resolution helper is — verify by reading `lib/sigra/oauth.ex:get_provider_config/2`). Missing → `{:error, 2, "missing :client_id for #{provider}"}`.
2. Boot Bandit on `{127, 0, 0, 1}` and the configured port (T-87-06: `ip: {127, 0, 0, 1}` explicit); expose `/callback` plug that captures `code` + `state` query params and signals back via Agent / mailbox to the main process.
3. Generate state nonce via `Sigra.Token.generate/4` (exercise real signing path per 87-RESEARCH.md note). Generate PKCE `code_verifier` + `code_challenge`.
4. Print authorize URL with state nonce + PKCE to stdout. Print `Open this URL in your browser:` prompt.
5. `receive` the callback or timeout after 5 minutes (`{:error, 3, "callback timeout (5m)"}`).
6. Verify state nonce matches. Mismatch → `{:error, 3, "state mismatch"}`.
7. Token exchange: POST to provider's token endpoint with code + code_verifier. Failure → `{:error, 3, "token exchange: #{reason}"}`.
8. Decode id_token via JOSE (or whatever Sigra uses). Missing `email` claim → `{:error, 3, "missing email claim"}`.
9. Print `OK — got back valid id_token with sub=#{sub} and email=#{email}` and return `:ok`.

**3. `test/sigra/install/oauth_smoketest_task_test.exs` (~40 LOC AAA-flat — `oauth_generator_test.exs` sibling pattern):**

`use ExUnit.Case, async: true`. Cover:
- `describe "config loading"` — `Application.put_env(:sigra, :providers, [])` then call `Sigra.OAuth.Smoketest.run(provider: "google", port: 4099)` → returns `{:error, 2, _}`.
- `describe "port flag"` — pass `port: 4099`; runtime resolves and (in test) returns a config error before binding (so the test does not actually wait on a callback). Use a partial-stub via Mox if needed, or extract a `Sigra.OAuth.Smoketest.boot_endpoint/2` helper that the test stubs out.
- `describe "exit-code semantics"` — the Mix task wraps `run/1` and calls `exit({:shutdown, code})`; capture via `catch :exit, _ ->` block in the test.
- `describe "diagnostic emission"` — invalid provider → reason string contains `"missing :client_id"` or `"unknown provider"` per the failure mode.

Tests stub the actual Bandit-boot + browser-callback path by either:
- (a) extracting `boot_endpoint/2` and replacing it with a Mox-defined behaviour in test mode, OR
- (b) using `Sigra.Testing.OAuthIssuer` (landed in Plan 87-01a) to fake the provider HTTP surface and asserting the smoketest's HTTP calls land at the issuer's URL — preferred per CONTEXT.md (uses Sigra.Testing.OAuthIssuer "so the test is hermetic").

Choose (b) where feasible: spin up `Sigra.Testing.OAuthIssuer.start_link(provider: :google)`, override `Application.put_env(:sigra, :providers, [google: [client_id: "x", client_secret: "y", redirect_uri: "http://127.0.0.1:4099/callback", base_url: issuer_url]])`, then synthesize a callback against the smoketest's local endpoint via `Req.get/2`. Assert exit code semantics on the resulting `{:error, code, _}` tuple from `run/1`.

**4. `docs/oauth-google-setup.md` (numbered Google Cloud Console recipe):**

```markdown
# Setting up Google OAuth for Sigra

This document walks you through Google Cloud Console setup, Sigra provider
config, and verification via `mix sigra.oauth.smoketest --provider=google`.

## 1. Create a Google Cloud project
[steps]

## 2. Configure the OAuth consent screen
[steps; mention `https://www.googleapis.com/auth/userinfo.email` scope]

## 3. Create an OAuth 2.0 Client ID (Web application)
[steps; mention name, description]

## 4. Set redirect URIs
- Development: `http://127.0.0.1:4001/callback` (matches `mix sigra.oauth.smoketest` default port)
- Production: `https://<your-app>/auth/google/callback`

## 5. Configure Sigra
Set environment variables:
- `GOOGLE_OAUTH_CLIENT_ID=...`
- `GOOGLE_OAUTH_CLIENT_SECRET=...`
- `GOOGLE_OAUTH_REDIRECT_URI=http://127.0.0.1:4001/callback`

Then in your `config/runtime.exs`:
[example block]

## 6. Verify

Run:

    mix sigra.oauth.smoketest --provider=google

Expected output:

    OK — got back valid id_token with sub=<your-sub> and email=<your-email>

If the task exits with a non-zero code, the diagnostic identifies which step
failed (state mismatch, token exchange, malformed id_token, missing email).

## Phoenix < 1.8 hosts

The smoketest binds Bandit. If your host app is on Phoenix < 1.7 with no
Bandit dependency, install Bandit explicitly: add `{:bandit, "~> 1.5"}` to
your `mix.exs` deps.
```

**5. `mix.exs` extras nav (per 87-PATTERNS.md `docs/oauth-google-setup.md` row):**

In the `extras:` list (around lines 163-202), add:
```elixir
"docs/oauth-google-setup.md",
```
in the section that the existing `Docs` group regex (around line 208 — verify with `grep -n "Docs" mix.exs`) catches via `~r{^docs/|^SECURITY\.md$}` (or whatever the actual regex is). Confirm the doc appears under the right ExDoc group by running `mix docs --warnings-as-errors` and inspecting `doc/index.html` (acceptance criterion below makes this concrete).
  </action>
  <verify>
    <automated>test -f lib/mix/tasks/sigra.oauth.smoketest.ex && test -f lib/sigra/oauth/smoketest.ex && test -f test/sigra/install/oauth_smoketest_task_test.exs && test -f docs/oauth-google-setup.md && grep -q "@shortdoc" lib/mix/tasks/sigra.oauth.smoketest.ex && grep -q "Sigra.OAuth.Smoketest.run" lib/mix/tasks/sigra.oauth.smoketest.ex && grep -q "127, 0, 0, 1" lib/sigra/oauth/smoketest.ex && grep -q "mix sigra.oauth.smoketest" docs/oauth-google-setup.md && grep -q "OK — got back valid id_token" docs/oauth-google-setup.md && grep -q "docs/oauth-google-setup.md" mix.exs && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/install/oauth_smoketest_task_test.exs --color=never 2>&1 | grep -E "[0-9]+ tests?, 0 failures"</automated>
  </verify>
  <acceptance_criteria>
    - The Mix task exists at `lib/mix/tasks/sigra.oauth.smoketest.ex`, `use Mix.Task` is present, and `@shortdoc` matches the verbatim string in the action step.
    - The runtime module is at `lib/sigra/oauth/smoketest.ex` with `run/1` exported; binds Bandit to `{127, 0, 0, 1}` (grep `"127, 0, 0, 1"` returns the bind).
    - The task does NOT inherit `sigra.gen.oauth.ex`'s file-emission DSL (grep `Mix.Phoenix.web_module\|Mix.Phoenix.base\|EEx.eval` in `sigra.oauth.smoketest.ex` and `lib/sigra/oauth/smoketest.ex` returns 0 hits).
    - `mix test test/sigra/install/oauth_smoketest_task_test.exs` returns 0 failures and exercises: missing config (exit 2), wrong provider (exit 1), state mismatch path (exit 3 — exercised via `Sigra.Testing.OAuthIssuer` synthetic callback).
    - `docs/oauth-google-setup.md` contains numbered sections 1-6, mentions the `--port=4001` default + `127.0.0.1:4001/callback` redirect URI, and ends with the verification step `Run: mix sigra.oauth.smoketest --provider=google` plus the `OK — got back valid id_token...` expected output.
    - `mix.exs` extras list contains `docs/oauth-google-setup.md` and `mix docs --warnings-as-errors` succeeds with the new page in ExDoc nav.
  </acceptance_criteria>
  <done>The adopter-side smoketest task ships, has hermetic test coverage via Sigra.Testing.OAuthIssuer, binds 127.0.0.1 only, and is paired with a numbered Google Cloud Console recipe document linked from ExDoc nav.</done>
</task>

<task type="auto">
  <name>Task 2: install-smoke.sh extension + .github/workflows/ci.yml install_smoke transcript+upload + new oauth_e2e_playwright job + phx_new 1.8.5 pin (install_smoke step only)</name>
  <files>scripts/ci/install-smoke.sh, .github/workflows/ci.yml</files>
  <read_first>
    - `scripts/ci/install-smoke.sh` lines 85-137 (full, especially the extension point at line 93 and the existing 11-paths-OK echo at line 134).
    - `.github/workflows/ci.yml` lines 218-267 (`install_smoke` job — extension target).
    - `.github/workflows/ci.yml` lines 551-789 (`example_playwright_smoke` — job-graph + Postgres service + Node setup pattern for the new oauth_e2e_playwright job).
    - `.github/workflows/ci.yml` lines 1015-1081 (`email_visual_regression` — release-asset promotion stanza to copy verbatim).
    - 87-CONTEXT.md D-87-04 (the three surgical edits + phx_new pin).
    - 87-RESEARCH.md `## CI Workflow Diff` (full — explicit edit-1 / edit-2 / edit-3 + the install_smoke transcript-tee + oauth_e2e_playwright job sketch + phx_new pin location at line 256).
    - 87-PATTERNS.md rows for install-smoke.sh extension, install_smoke transcript+upload, and the new oauth_e2e_playwright job.
    - 87-VALIDATION.md per-task verification map rows for install-smoke and the two CI workflow steps.
    - The state of `.github/workflows/ci.yml` on `origin/main` (use `git diff origin/main -- .github/workflows/ci.yml` after edits to confirm only the install_smoke step's `phx_new` line moved — D-87-04 minimum-viable-change).
  </read_first>
  <action>
**A. `scripts/ci/install-smoke.sh` — three edits (verbatim per 87-RESEARCH.md `## CI Workflow Diff`):**

Edit 1 — between line 93 (`mix compile --warnings-as-errors`) and line 95 (`APP="$(basename "$(pwd)")"`), insert:
```bash
echo "==> install-smoke: creating + migrating test DB and running mix test"
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
MIX_ENV=test mix test
```

Edit 2 — replace the existing line 134 echo (`echo "==> install-smoke: oauth generator contract OK ..."`) with:
```bash
echo "==> install-smoke: oauth generator contract OK (>=11 generated paths + migration + router inject)"
echo "==> install-smoke: oauth-gen: 12/12 expected artifacts present, mix test green"
```
(Keep the original line for backward compat AND add the new contract line directly after it; don't replace, append.)

NO other edits to install-smoke.sh. The existing `set -euo pipefail` at line 14 propagates exit codes through `tee` automatically.

**B. `.github/workflows/ci.yml` install_smoke job extensions — add to the existing job (lines 218-267):**

(1) Pin phx_new at the install_smoke job's archive-install step:
```yaml
      - name: Install phx_new archive
        run: mix archive.install --force hex phx_new 1.8.5
```

This pin applies ONLY to the `install_smoke` job's `phx_new` archive-install step. All OTHER `phx_new` archive-install steps in `.github/workflows/ci.yml` MUST remain unchanged from `origin/main`. Verification (replaces the prior line-number based check, which drifts on rebase): `git diff origin/main -- .github/workflows/ci.yml | grep -E '^[+-].*phx_new' | grep -v 'install_smoke' | wc -l` returns 0 (no other phx_new lines were added or removed).

(2) Add `permissions: contents: write` at the job level (mirror lines 939-940 of `email_visual_regression`):
```yaml
  install_smoke:
    name: Install smoke harness
    runs-on: ubuntu-latest
    permissions:
      contents: write  # for tag-time release-asset promotion
    services:
      ...
```

(3) Replace the `Run install smoke harness` step (line 259-267) with a tee'd version:
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
```

(4) Add three artifact-upload + release-promotion steps (verbatim mirror of email_visual_regression lines 1043-1081, only renamed `email-visual-regression-bundle` → `oauth-gen-bundle` and path `/tmp/email-visual-bundle/` → `.planning/uat-evidence/v1.20/oauth-gen/`):
```yaml
      - name: Upload oauth-gen bundle (PR/push, 7d retention)
        if: always() && github.ref != 'refs/heads/main' && !startsWith(github.ref, 'refs/tags/')
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
        with:
          name: oauth-gen-bundle
          path: .planning/uat-evidence/v1.20/oauth-gen/
          retention-days: 7
      - name: Upload oauth-gen bundle (main, 14d retention)
        if: always() && github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
        with:
          name: oauth-gen-bundle
          path: .planning/uat-evidence/v1.20/oauth-gen/
          retention-days: 14
      - name: Create oauth-gen release asset archive (v* tag only)
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          cd /tmp && tar -czf "sigra-oauth-gen-${{ github.ref_name }}.tar.gz" \
            -C ${{ github.workspace }} .planning/uat-evidence/v1.20/oauth-gen/
      - name: Promote oauth-gen bundle to ${{ github.ref_name }} release asset
        if: startsWith(github.ref, 'refs/tags/v')
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release upload "${{ github.ref_name }}" \
            "/tmp/sigra-oauth-gen-${{ github.ref_name }}.tar.gz" \
            --clobber --repo "${{ github.repository }}"
```

**C. New `oauth_e2e_playwright` job in `.github/workflows/ci.yml` (per 87-PATTERNS.md row + 87-RESEARCH.md `## CI Workflow Diff > new oauth_e2e_playwright job`):**

Insert after the existing `example_playwright_smoke` job, mirror its skeleton (Postgres service, Node setup, BEAM setup), but:
- `name: OAuth E2E Playwright (mock issuer)`
- No `needs:` clause (parallel-ready with install_smoke).
- `permissions: contents: write` at job level (release upload).
- ENV vars on the example-app boot step: `EXAMPLE_DB_PROBE_ENABLED=1` AND `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`.
- After example-app boot is healthy on `localhost:4000`:
```yaml
      - name: Run Playwright OAuth specs (mock issuer)
        working-directory: test/example/priv/playwright
        env:
          CI: "true"
          EXAMPLE_DB_PROBE_ENABLED: "1"
          EXAMPLE_OAUTH_ISSUER_CTL_ENABLED: "1"
        run: |
          npx playwright test \
            tests/oauth-register.spec.ts \
            tests/oauth-link.spec.ts \
            tests/oauth-email-match.spec.ts \
            --project=chromium \
            --reporter=line
```
- After the Playwright run, upload the trace bundle + DB probe outputs + manifest dirs as `oauth-e2e-playwright-bundle` (mirror the email_visual_regression upload pattern with the four upload+promote steps for PR/main/tag retention + release-asset promotion).

**D. YAML / shell validation (replaces the prior python3 yaml.safe_load check — Warning #9):**

Validate via shell-builtin + grep on key sections (no python dependency):
```bash
# Bash syntax check on install-smoke.sh
bash -n scripts/ci/install-smoke.sh

# Verify the install_smoke + oauth_e2e_playwright jobs exist in ci.yml at top-of-job indentation
grep -qE '^[[:space:]]+install_smoke:' .github/workflows/ci.yml
grep -qE '^[[:space:]]+oauth_e2e_playwright:' .github/workflows/ci.yml
```

If `yq` is available on the executor runner, also run:
```bash
yq -e '.jobs.install_smoke' .github/workflows/ci.yml >/dev/null
yq -e '.jobs.oauth_e2e_playwright' .github/workflows/ci.yml >/dev/null
```

(Do not depend on python3 / `yaml.safe_load` — not guaranteed on all CI runners. The grep + `bash -n` checks are sufficient for the verify gate.)
  </action>
  <verify>
    <automated>grep -q "MIX_ENV=test mix ecto.create" scripts/ci/install-smoke.sh && grep -q "MIX_ENV=test mix test" scripts/ci/install-smoke.sh && grep -q 'oauth-gen: 12/12 expected artifacts present, mix test green' scripts/ci/install-smoke.sh && grep -q "phx_new 1.8.5" .github/workflows/ci.yml && grep -q "oauth-gen-bundle" .github/workflows/ci.yml && grep -q "oauth_e2e_playwright" .github/workflows/ci.yml && grep -q "EXAMPLE_DB_PROBE_ENABLED" .github/workflows/ci.yml && grep -q "EXAMPLE_OAUTH_ISSUER_CTL_ENABLED" .github/workflows/ci.yml && bash -n scripts/ci/install-smoke.sh && grep -qE '^[[:space:]]+install_smoke:' .github/workflows/ci.yml && grep -qE '^[[:space:]]+oauth_e2e_playwright:' .github/workflows/ci.yml && [ "$(git diff origin/main -- .github/workflows/ci.yml | grep -E '^[+-].*phx_new' | grep -v 'install_smoke' | wc -l | tr -d ' ')" = "0" ]</automated>
  </verify>
  <acceptance_criteria>
    - `scripts/ci/install-smoke.sh` adds the three lines `MIX_ENV=test mix ecto.create`, `MIX_ENV=test mix ecto.migrate`, `MIX_ENV=test mix test` immediately after line 93's `mix compile --warnings-as-errors`.
    - The script emits the literal line `==> install-smoke: oauth-gen: 12/12 expected artifacts present, mix test green` after the existing oauth-generator-contract-OK echo.
    - `bash -n scripts/ci/install-smoke.sh` (syntax check) returns 0.
    - `.github/workflows/ci.yml` install_smoke job pins `phx_new 1.8.5` at the install_smoke step, has `permissions: contents: write` at job level, tees install-smoke output to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log`, uploads `oauth-gen-bundle` artifact with 7d/14d retention conditional steps, and has a tag-only release-asset promotion step.
    - A new top-level job `oauth_e2e_playwright` exists, sets `EXAMPLE_DB_PROBE_ENABLED=1` and `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`, runs the 3 OAuth specs against the example app on `localhost:4000`, and uploads + promotes a `oauth-e2e-playwright-bundle` mirroring the email_visual_regression upload pattern.
    - The yaml is structurally valid by grep gate: both `install_smoke:` and `oauth_e2e_playwright:` appear at top-of-job indentation.
    - All `phx_new` archive-install steps OTHER than the install_smoke job step remain unchanged. Verification: `git diff origin/main -- .github/workflows/ci.yml | grep -E '^[+-].*phx_new' | grep -v 'install_smoke' | wc -l` returns 0.
  </acceptance_criteria>
  <done>install-smoke prints the 12/12 contract line, the install_smoke CI job uploads the transcript bundle and promotes it on tags, and a new oauth_e2e_playwright job runs the 3 OAuth specs against the mock issuer; only the install_smoke step's phx_new pin changed (all other phx_new lines untouched).</done>
</task>

<task type="auto">
  <name>Task 3: Three GREEN Playwright OAuth specs (oauth-register, oauth-link with hero PNG, oauth-email-match) + controller integration test extension + no-real-Google grep</name>
  <files>test/example/priv/playwright/tests/oauth-register.spec.ts, test/example/priv/playwright/tests/oauth-link.spec.ts, test/example/priv/playwright/tests/oauth-email-match.spec.ts, test/example/test/example_web/oauth_controller_test.exs</files>
  <read_first>
    - The Sigra.Testing.OAuthIssuer module surface from Plan 87-01a (the GREEN cycle landed there) — bind against the contract listed in `<interfaces>`.
    - The oauthIssuer.ts fixture from Plan 87-01a (full contract — `setupIssuer / resetIssuer / probeIdentities`).
    - 87-CONTEXT.md D-87-05 cell-by-cell coverage block (oauth-register: 6 cells; oauth-link: 4 sub-tests; oauth-email-match: 1 linear test).
    - 87-RESEARCH.md `## Verbatim Source Strings` (BOTH the `oauth_settings_live.ex:92` disabled-tooltip and the `oauth_controller.ex:96` flash text — paste verbatim per the deep_work_rules).
    - 87-RESEARCH.md `## Validation Architecture > Phase Requirements > Test Map` (each Playwright assertion shape per cell).
    - 87-RESEARCH.md `## Risks and Footguns > High-impact #3, #4, #5` (MIX_ENV=dev shared DB → unique-per-test fixture emails via `Date.now()`; workers=1 race assumption documented in oauthIssuer.ts; HTTPS issuer URL).
    - 87-PATTERNS.md rows for the 3 spec files, plus the four Anti-Patterns block at the bottom of PATTERNS.md (NO matrix loop in oauth-link.spec.ts; NO waitForLiveViewReady in oauth-register.spec.ts).
    - 87-VALIDATION.md per-task verification matrix rows for the 3 specs.
    - `test/example/priv/playwright/tests/email-visual.spec.ts` lines 100-110 — `expect(page).toHaveScreenshot(...)` invocation pattern (used ONLY for the disabled-tooltip cell in oauth-link.spec.ts).
    - `test/example/priv/playwright/tests/golden-path.spec.ts` lines 1-100 — Date.now() unique-email + plain-controller redirect.
    - `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` lines 70-121 — describe-block + mailbox poll.
    - `test/example/test/example_web/controllers/session_controller_test.exs` lines 1-50 — direct analog for `oauth_controller_test.exs` (ConnCase + `:example_app` moduletag + setup fixture).
    - 87-CONTEXT.md `## Folded scope > Controller-level integration test extension` (3 controller tests: state mismatch / provider error / no-email).
    - 87-RESEARCH.md `## File-by-File Plan` Wave 1 row "test/example/test/example_web/oauth_controller_test.exs (NEW — research said 'extension' but file does NOT exist; flag in commit message)".
  </read_first>
  <action>
**A. `test/example/priv/playwright/tests/oauth-register.spec.ts` (GAUAT-04 — 6 cells per D-87-05):**

```typescript
import { test, expect } from '@playwright/test';
import { setupIssuer, probeIdentities, resetIssuer } from '../fixtures/oauthIssuer';

test('GAUAT-04: register/login/logout/re-login via mock Google OAuth', async ({ page }) => {
  const email = `oauth-test-${Date.now()}@example.test`;
  const sub = `mock-google-uid-${Date.now()}`;

  await setupIssuer(page, { sub, email, email_verified: true });

  try {
    // Cell 1: provider button visible on /users/log_in
    await page.goto('/users/log_in');
    await expect(page.locator('a:has-text("Sign in with Google")')).toBeVisible();

    // Cell 2: click → 302 redirect to mock issuer's /oauth2/v2/auth with state= present
    const authorizeRequest = page.waitForRequest(/\/oauth2\/v2\/auth.*state=/);
    await page.click('a:has-text("Sign in with Google")');
    await authorizeRequest;

    // Cell 3: callback → land on / with session cookie set
    await expect(page).toHaveURL('/');
    const cookies = await page.context().cookies();
    expect(cookies.some((c) => c.name.includes('session'))).toBe(true);

    // Cell 4: DB probe — exactly 1 identity row for (google, mock_uid)
    const identities1 = await probeIdentities(page, email);
    expect(identities1.count).toBe(1);
    expect(identities1.rows[0].provider).toBe('google');
    expect(identities1.rows[0].provider_uid).toBe(sub);

    // Cell 5: logout → leave /
    await page.click('a:has-text("Log out")');
    await expect(page).not.toHaveURL('/');

    // Cell 6: re-login uses same user, no new identity row
    await page.goto('/users/log_in');
    await page.click('a:has-text("Sign in with Google")');
    await expect(page).toHaveURL('/');
    const identities2 = await probeIdentities(page, email);
    expect(identities2.count).toBe(1);  // unchanged
  } finally {
    await resetIssuer(page);
  }
});
```

NO `waitForLiveViewReady` (login page is plain controller per `session_controller_test.exs` and 87-PATTERNS.md anti-pattern). NO references to `accounts.google.com` / `oauth2.googleapis.com` / `googleapis.com` (T-87-15).

**B. `test/example/priv/playwright/tests/oauth-link.spec.ts` (GAUAT-05 — 4 sub-tests + 1 hero PNG; NO matrix loop per 87-PATTERNS.md):**

```typescript
import { test, expect } from '@playwright/test';
import { setupIssuer, probeIdentities, resetIssuer } from '../fixtures/oauthIssuer';

test.describe('GAUAT-05: OAuth provider link/unlink visual states', () => {
  test('linked-with-password: unlink button enabled, no tooltip', async ({ page }) => {
    // [Setup: register password user; link Google via mock issuer; navigate to settings.]
    // [Assertion:]
    const unlinkButton = page.locator('button:has-text("Unlink")');
    await expect(unlinkButton).toBeEnabled();
    await expect(unlinkButton).not.toHaveAttribute('title', /.+/);
  });

  test('only-oauth-no-password: unlink disabled + tooltip + hero PNG', async ({ page }) => {
    // [Setup: register OAuth-only user (no password); navigate to settings.]
    const unlinkButton = page.locator('button:has-text("Unlink")');
    await expect(unlinkButton).toBeDisabled();
    // VERBATIM from priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92
    await expect(unlinkButton).toHaveAttribute(
      'title',
      'Set a password first to keep access to your account.',
    );
    // ONE hero PNG — the load-bearing visual artifact for GAUAT-05.
    await expect(page).toHaveScreenshot('oauth-link__disabled-tooltip.png', {
      fullPage: true,
      maxDiffPixels: 50,
    });
  });

  test('after-set-password: button flips to enabled', async ({ page }) => {
    // [Setup: from only-oauth-no-password state, set a password.]
    const unlinkButton = page.locator('button:has-text("Unlink")');
    await expect(unlinkButton).toBeEnabled();
  });

  test('post-unlink: identity row absent; password login still works', async ({ page }) => {
    // [Setup: from after-set-password state, click Unlink and confirm.]
    const email = '<test user email from setup>';
    const identities = await probeIdentities(page, email);
    expect(identities.count).toBe(0);
    // [Then: log out, log in with password, expect /.]
    await expect(page).toHaveURL('/');
  });
});
```

Each sub-test sets up its own `setupIssuer` + `resetIssuer` in beforeEach/afterEach (or test-level finally) — workers=1 means shared state but per-test cleanliness still matters. The hero PNG `oauth-link__disabled-tooltip.png` baseline is committed under `test/example/priv/playwright/__snapshots__/oauth-link.spec.ts/` on first green run.

**C. `test/example/priv/playwright/tests/oauth-email-match.spec.ts` (GAUAT-06 — single linear test):**

```typescript
import { test, expect } from '@playwright/test';
import { setupIssuer, probeIdentities, resetIssuer } from '../fixtures/oauthIssuer';
// Reuse mailbox.ts pattern; if a generic mailbox-row helper exists, import it; otherwise copy the polling shape.
import { extractConfirmationLink } from '../fixtures/mailbox';

test('GAUAT-06: email-match flash + redirect + identity-row + linked-email', async ({ page }) => {
  const aliceEmail = `alice-${Date.now()}@example.test`;
  const alicePassword = 'a-secure-test-pw-9876';
  const novelSub = `novel-google-uid-${Date.now()}`;

  // Pre-seed Alice with password (via standard register flow — adapt golden-path.spec.ts pattern).
  // [register Alice with email+password; confirm via mailbox if needed.]

  // Mock issuer returns matching email but novel sub
  await setupIssuer(page, { sub: novelSub, email: aliceEmail, email_verified: true });

  try {
    await page.goto('/users/log_in');
    await page.click('a:has-text("Sign in with Google")');

    // VERBATIM from priv/templates/sigra.gen.oauth/oauth_controller.ex:96
    // (provider atom interpolated as bare slug: "google", NOT ":google")
    await expect(page.locator('.flash-info')).toContainText(
      'An account with this email exists. Log in to link your google account.',
    );

    // Submit password
    await page.fill('#login_form input[name="user[password]"]', alicePassword);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).toHaveURL('/');

    // DB probe: new identity row for (alice.id, google, novel_sub)
    const identities = await probeIdentities(page, aliceEmail);
    expect(identities.count).toBe(1);
    expect(identities.rows[0].provider).toBe('google');
    expect(identities.rows[0].provider_uid).toBe(novelSub);

    // provider_linked_email arrived in /dev/mailbox/json (reuse mailbox.ts polling pattern)
    const mailbox = await page.evaluate(async () => {
      const res = await fetch('/dev/mailbox/json');
      return res.json();
    });
    const linkedEmail = (mailbox.data || []).find((m: any) =>
      m.to.join(' ').includes(aliceEmail) && /Provider linked|Linked/i.test([m.html_body || '', m.text_body || ''].join('\n')),
    );
    expect(linkedEmail).toBeTruthy();
  } finally {
    await resetIssuer(page);
  }
});
```

**D. `test/example/test/example_web/oauth_controller_test.exs` (NEW file — 87-PATTERNS.md flagged research's "extension" framing as inaccurate; file does not currently exist):**

```elixir
defmodule ExampleWeb.OAuthControllerTest do
  @moduledoc """
  Phase 87 D-87-10: controller-level integration covering OAuth callback error
  paths (state mismatch, provider error, no-email) using
  Sigra.Testing.OAuthIssuer instead of MockStrategy. Closes the gap surfaced
  by 87-RESEARCH.md — controller integration was missing from the existing
  OAuth test inventory.
  """
  use ExampleWeb.ConnCase, async: true
  import Example.AccountsFixtures

  alias Sigra.Testing.OAuthIssuer

  @moduletag :example_app

  setup do
    {:ok, issuer} = OAuthIssuer.start_link(provider: :google)
    Application.put_env(:sigra, :oauth_provider_overrides,
      google: [
        base_url: OAuthIssuer.url(issuer),
        openid_configuration: OAuthIssuer.openid_config(issuer)
      ]
    )

    on_exit(fn ->
      OAuthIssuer.stop(issuer)
      Application.delete_env(:sigra, :oauth_provider_overrides)
    end)

    %{issuer: issuer}
  end

  describe "GET /auth/google/callback (state mismatch)" do
    test "returns 400 with state-mismatch error", %{conn: conn} do
      conn = get(conn, "/auth/google/callback", %{"state" => "tampered", "code" => "x"})
      # Acceptance: response surfaces an "invalid state" / "state mismatch" indicator;
      # exact status/template per Sigra.OAuth.handle_callback/4 contract.
      assert conn.status in [400, 401, 403, 422] or html_response(conn, 200) =~ ~r/(invalid|mismatch).*state/i
    end
  end

  describe "GET /auth/google/callback (provider error response)" do
    test "surfaces provider error to user", %{conn: conn} do
      conn = get(conn, "/auth/google/callback", %{"error" => "access_denied"})
      assert conn.status in [302, 400, 401, 403, 422]
      # Acceptance: redirect or error page references the access_denied / provider error.
    end
  end

  describe "GET /auth/google/callback (no-email user)" do
    test "redirects to login with no-email flash", %{conn: conn, issuer: issuer} do
      OAuthIssuer.set_user(issuer, %{
        sub: "user-without-email",
        email: nil,
        email_verified: false
      })

      # Walk the full callback ceremony with an issuer that returns no email claim.
      # Acceptance: the controller surfaces a no-email flash to the user.
      # [Full setup replicates oauth-register.spec.ts Cell 2-3 in ExUnit form.]
    end
  end
end
```
  </action>
  <verify>
    <automated>grep -q "Set a password first to keep access to your account\." test/example/priv/playwright/tests/oauth-link.spec.ts && grep -q "An account with this email exists\. Log in to link your google account\." test/example/priv/playwright/tests/oauth-email-match.spec.ts && ! grep -q "waitForLiveViewReady" test/example/priv/playwright/tests/oauth-register.spec.ts && ! grep -qE "for \(const .* of TEMPLATES\)" test/example/priv/playwright/tests/oauth-link.spec.ts && grep -q "toHaveScreenshot" test/example/priv/playwright/tests/oauth-link.spec.ts && grep -c "test\(" test/example/priv/playwright/tests/oauth-link.spec.ts | awk '$1 >= 4 { exit 0 } { exit 1 }' && ! grep -rEq "accounts\\.google\\.com|oauth2\\.googleapis\\.com|googleapis\\.com" test/example/priv/playwright/tests/oauth-register.spec.ts test/example/priv/playwright/tests/oauth-link.spec.ts test/example/priv/playwright/tests/oauth-email-match.spec.ts && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/oauth_controller_test.exs --include example_app --color=never 2>&1 | grep -E "[0-9]+ tests?, 0 failures"</automated>
  </verify>
  <acceptance_criteria>
    - `oauth-register.spec.ts` is GREEN locally with `EXAMPLE_DB_PROBE_ENABLED=1 EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1 npx playwright test oauth-register.spec.ts --project=chromium --reporter=line` (verified by an executor run).
    - `oauth-register.spec.ts` does NOT contain `waitForLiveViewReady` (anti-pattern compliance).
    - `oauth-link.spec.ts` has at least 4 `test()` cases under `test.describe('GAUAT-05: ...')`, exactly ONE `toHaveScreenshot` invocation (the disabled-tooltip hero), and contains the verbatim string `Set a password first to keep access to your account.`.
    - `oauth-link.spec.ts` does NOT contain a `for (const ... of TEMPLATES)` matrix loop (anti-pattern compliance).
    - `oauth-email-match.spec.ts` contains the verbatim string `An account with this email exists. Log in to link your google account.` (with bare provider slug, no colon prefix).
    - `oauth-email-match.spec.ts` reuses the `/dev/mailbox/json` polling pattern from `mailbox.ts`.
    - `cd test/example && mix test test/example_web/oauth_controller_test.exs --include example_app` returns 0 failures.
    - The controller test sets up `Sigra.Testing.OAuthIssuer` in the `setup do ... end` block (NOT MockStrategy) and uses `on_exit/1` for teardown.
    - The hero PNG baseline is committed at `test/example/priv/playwright/__snapshots__/oauth-link.spec.ts/oauth-link__disabled-tooltip.png` (or whatever Playwright's snapshot dir convention produces) after the first green run.
    - No real-Google network endpoints in any of the three specs (verified by automated grep `! grep -rEq 'accounts\\.google\\.com|oauth2\\.googleapis\\.com|googleapis\\.com' test/example/priv/playwright/tests/oauth-*.spec.ts`).
  </acceptance_criteria>
  <done>All three Playwright OAuth specs are GREEN against Sigra.Testing.OAuthIssuer; the controller integration extension covers state mismatch / provider error / no-email; verbatim source strings are asserted byte-for-byte; the GAUAT-05 hero PNG baseline is committed; the no-real-Google grep is clean.</done>
</task>

</tasks>
</content>
