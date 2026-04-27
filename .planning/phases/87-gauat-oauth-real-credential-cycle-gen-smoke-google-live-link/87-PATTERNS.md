# Phase 87: GAUAT OAuth real-credential cycle — Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 21 new + 7 modified = 28 surfaces
**Analogs found:** 25 / 28 (3 surfaces have NO in-repo analog — flagged below)

## File Classification

### Wave 1 (Commit A — code, tests, install-smoke, specs)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `mix.exs` | config | dep-list mutation | `mix.exs:122` (insertion point) | exact |
| `test/support/sigra/testing/oauth_issuer.ex` | test-support module | request-response (mock OIDC issuer) | **NO local analog**; closest is `lib/sigra/testing.ex:1015` (in-memory shape, complementary not similar) | **LOW** |
| `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem` | fixture (binary) | static asset | **NO in-repo analog** (no committed RSA fixtures exist; nearest cousin is `priv/templates/sigra.gen.oauth/*` template files) | **LOW — greenfield** |
| `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid2.pem` | fixture (binary) | static asset | **NO in-repo analog** | **LOW — greenfield** |
| `test/sigra/testing/oauth_issuer_test.exs` | ExUnit test (AAA-flat) | request-response | `test/example/test/example_web/smoke/oauth_test.exs` (testing-module-shape verification) + `test/sigra/oauth/oauth_test.exs` (HTTP-stack OAuth assertion shape) | role-match |
| `lib/mix/tasks/sigra.oauth.smoketest.ex` | Mix task | request-response (one-shot) | `lib/mix/tasks/sigra.upgrade.ex` (NimbleOptions-driven thin lib delegator) + `lib/mix/tasks/sigra.fixture.rebless_golden.ex` (boot-Bandit-and-shell pattern) | exact |
| `test/sigra/install/oauth_smoketest_task_test.exs` | ExUnit test | request-response | `test/sigra/install/oauth_generator_test.exs` (direct sibling — same dir, same role) | exact |
| `docs/oauth-google-setup.md` | docs markdown | static reference | `docs/uat-ci-coverage.md` (closest semantic match — heavy table + cross-ref style) + `docs/audit-semantics.md` | role-match |
| `scripts/ci/install-smoke.sh` (extension) | bash script | sequential pipeline | The same file lines 90-93 (extension point) | exact (self-extension) |
| `.github/workflows/ci.yml` install_smoke transcript+upload (extension) | CI YAML | sequential | `.github/workflows/ci.yml:1019-1081` (`email_visual_regression` release-asset promotion) | exact |
| `.github/workflows/ci.yml` `oauth_e2e_playwright` job (new) | CI YAML | sequential | `.github/workflows/ci.yml:218-267` (`install_smoke`) + `.github/workflows/ci.yml:551-789` (`example_playwright_smoke`) + `.github/workflows/ci.yml:1019-1081` (artifact + release promotion) | exact |
| `test/example/priv/playwright/fixtures/oauthIssuer.ts` | Playwright fixture (helper module) | request-response | `test/example/priv/playwright/fixtures/mailbox.ts` (direct sibling, established pattern) | exact |
| `test/example/priv/playwright/tests/oauth-register.spec.ts` | Playwright spec | event-driven UI | `test/example/priv/playwright/tests/golden-path.spec.ts` (LiveView + register/login lifecycle) + `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` (mailbox + describe-block) | exact |
| `test/example/priv/playwright/tests/oauth-link.spec.ts` | Playwright spec (4 sub-tests + 1 PNG) | event-driven UI | `test/example/priv/playwright/tests/golden-path.spec.ts` + `email-visual.spec.ts` (for the `toHaveScreenshot` cell only — see ANTI-PATTERN below) | partial |
| `test/example/priv/playwright/tests/oauth-email-match.spec.ts` | Playwright spec | event-driven UI + mailbox poll | `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` (closest semantic — flash + mailbox arrival) | exact |
| `test/example/lib/example_web/router.ex` (extension) | Phoenix router | mount route | `test/example/lib/example_web/router.ex:172-177` (existing `if Application.compile_env(:example, :dev_routes)` env-gated mount block) | exact (self-extension) |
| `test/example/lib/example_web/controllers/test_db_probe_controller.ex` | Phoenix controller (test-only) | request-response (read-only DB introspection) | `test/example/lib/example_web/controllers/page_controller.ex` (smallest existing controller; closest skeleton) | role-match |
| `test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex` | Phoenix controller (test-only) | request-response (Application.put_env proxy) | Same as above + `lib/sigra/testing.ex:1015` (Application.put_env discipline) | role-match |
| `test/example/test/example_web/oauth_controller_test.exs` (NEW — research says "extension" but file does NOT exist yet) | ExUnit ConnCase test | request-response | `test/example/test/example_web/controllers/session_controller_test.exs` (HTTP-stack + `:example_app` moduletag + ConnCase) | exact |

### Wave 2 (Commit B — evidence, sigra.uat.report extension, planning truth)

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/sigra.uat.report.ex` (extension) | Mix task | batch (manifest+README gen) | The same file lines 1-100 + 80-93 (`@phase_04_templates`, `@phase_08_templates`) | exact (self-extension) |
| `.planning/uat-evidence/v1.20/INDEX.md` (extension) | docs markdown | static reference | The same file (existing 4-row format) | exact (self-extension) |
| `.planning/uat-evidence/v1.20/oauth-gen/README.md` | docs markdown | YAML frontmatter + table | `.planning/uat-evidence/v1.20/email-phase-04/README.md` (verbatim 9-field schema) | exact |
| `.planning/uat-evidence/v1.20/oauth-gen/manifest.json` | JSON manifest | array of cell rows | `.planning/uat-evidence/v1.20/email-phase-04/manifest.json` (verbatim row shape) | exact |
| `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` | log file (CI-tee'd) | static asset | **NO in-repo analog** (Phase 86 has no transcript.log; the install-smoke transcript is novel) | **LOW — greenfield** |
| `.planning/uat-evidence/v1.20/oauth-gen/reports/artifact-inventory.json` | JSON report | static manifest | `.planning/uat-evidence/v1.20/email-phase-04/reports/byte-budget.csv` (closest peer — auxiliary report) | role-match |
| `.planning/uat-evidence/v1.20/oauth-google/{README.md,manifest.json}` | docs + JSON | as above | `email-phase-04/{README.md,manifest.json}` | exact |
| `.planning/uat-evidence/v1.20/oauth-link/{README.md,manifest.json,reports/db-probe-results.json,snapshots/oauth-link__disabled-tooltip__sha-{short-sha}.png}` | docs + JSON + PNG | as above | `email-phase-04/snapshots/{slug}__{engine}__{theme}__sha-{short-sha}.png` (naming convention) | exact |
| `.planning/uat-evidence/v1.20/oauth-email-match/{README.md,manifest.json,reports/{flash-text-assertion,linked-email-mailbox}.json}` | docs + JSON | as above | `email-phase-04` directory structure | exact |
| `docs/uat-ci-coverage.md` (SEED-001 row update) | docs markdown | row-edit | The same file lines 9-12 (already has the SEED-3..6 rows pointing at Phase 87) | exact (self-extension) |
| `CHANGELOG.md` (`[Unreleased]` entry) | docs markdown | append | (Existing CHANGELOG `[Unreleased]` block) | exact (self-extension) |
| `.planning/phases/87-…/87-VERIFICATION.md` | docs markdown | static reference | Phase 86's `86-VERIFICATION.md` (if exists) — verify at planning time | role-match (presumed) |

## Pattern Assignments

### Wave 1

---

### `mix.exs` extension — direct test-only dep promotion

**Analog:** `mix.exs:117-130` (existing deps block — exact insertion point at the line before `:postgrex`)

**Pattern to apply:** Sigra's deps list groups deps by purpose with end-of-line comments; `only:` constrained deps are commented for clarity. New entry should follow the same shape.

**What to copy** (read `mix.exs` lines around 117-130 to verify exact insertion point and surrounding deps):
```elixir
# After the line for the last test-only dep, add:
{:test_server, "~> 0.1.22", only: :test}
```

**What to change:** add only the one line; `mix deps.get` regenerates `mix.lock`. Verify via `mix deps | grep test_server`.

**Confidence:** HIGH — the dep list pattern is consistent throughout the file.

---

### `test/support/sigra/testing/oauth_issuer.ex` (NEW — TestServer-backed mock issuer)

**Analog:** **NO direct local analog.** Closest local cousins:
- `lib/sigra/testing.ex` (the `Sigra.Testing` namespace; lines 1-50 for `@moduledoc` style)
- `test/support/oauth_helpers.ex` (test-support namespace pattern — verify exists at planning time)
- External: Assent's own `test/support/strategies/oidc_test_case.ex` (the canonical Elixir-OIDC test seam — research recommends mirroring verbatim)

**Imports / module-doc pattern** (from `lib/sigra/testing.ex:1-30` — adapt the moduledoc voice):
```elixir
defmodule Sigra.Testing.OAuthIssuer do
  @moduledoc """
  In-process OIDC issuer for testing Sigra's OAuth ceremony end-to-end.

  Mirrors Assent's own `Assent.Strategy.OIDC.OIDCTestCase` precedent — RS256
  ID tokens with embedded RSA fixture, JWKS endpoint, real PKCE verification,
  `email_verified` boolean per OIDC spec, configurable `exp`, kid rotation.

  Lives under test/support/ and is NOT exported as adopter public API in v0.x.
  See `Sigra.Testing.mock_oauth_callback/1` for the in-memory shape helper.
  """
end
```

**Architectural shape** (per RESEARCH.md `## Module APIs`):
```elixir
defstruct [:base_url, :state]
@type t :: %__MODULE__{base_url: String.t(), state: pid()}

@spec start_link(keyword()) :: {:ok, t()} | {:error, term()}
@spec set_user(t(), map()) :: :ok
@spec set_kid_count(t(), 1 | 2) :: :ok
@spec url(t()) :: String.t()
@spec openid_config(t()) :: map()
@spec stop(t()) :: :ok
```

**RSA fixture loading** (compile-time `@external_resource` per RESEARCH.md):
```elixir
@external_resource "test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem"
@private_key_kid1 File.read!("test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem")
```

**What to change vs Assent's `OIDCTestCase`:**
- Sigra's API surface is the public-facing `start_link/1` (Agent-backed) — Assent's is `ExUnit.CaseTemplate`. Different consumer pattern; the cryptographic guts (RS256 + JWKS + PKCE + claims map) are the parts to mirror verbatim.
- Per-provider claims-shape map (Google/GitHub/Apple/Facebook), v1.20 ships Google only.
- Print clear error if `Sigra.Token.generate/4` is called for state nonce — don't reimplement.

**Confidence:** LOW (no in-repo analog) — but Assent's external precedent is concrete; planner should fetch `deps/assent/test/support/strategies/oidc_test_case.ex` after `mix deps.get` to read it verbatim.

---

### `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid{1,2}.pem` (NEW — RSA key fixtures)

**Analog:** **NO in-repo analog.** No committed RSA/key PEM fixtures exist anywhere in the repo (`find test -name '*.pem' -o -name '*.key'` returns empty per planner verification).

**Pattern to mirror:** Assent's `priv/keys/` layout (Assent ships test keys this way).

**What to create:**
```bash
# Run once by maintainer; commit the .pem files
elixir -e '
  {:ok, key} = :public_key.generate_key({:rsa, 2048, 65537})
  pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
  File.write!("test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid1.pem", pem)
'
```

**What to change:**
- Generate two distinct 2048-bit RSA private keys (`kid1.pem`, `kid2.pem`) — for `kid_count: 2` JWKS rotation coverage.
- Verify `mix.exs:146` `package` files list excludes `test/` — these MUST NOT ship to adopters via Hex.
- Document generation script at `test/support/sigra/testing/fixtures/gen.exs` (optional helper; NOT run in CI).

**Confidence:** LOW — greenfield. Cite Assent's precedent for "RSA fixture in test/support/" and document one-time generation in commit message.

---

### `test/sigra/testing/oauth_issuer_test.exs` (NEW — ~80 LOC AAA-flat)

**Analog:** `test/example/test/example_web/smoke/oauth_test.exs` (testing-module-shape verification — same `Code.ensure_loaded!` + `function_exported?` pattern for the public API surface) + `test/sigra/oauth/oauth_test.exs` (HTTP-stack OAuth assertion shape).

**Imports / setup pattern** (from `test/example/test/example_web/smoke/oauth_test.exs:1-10`):
```elixir
defmodule Sigra.Testing.OAuthIssuerTest do
  use ExUnit.Case, async: true

  alias Sigra.Testing.OAuthIssuer
end
```

**AAA-flat test pattern** (from `test/sigra/install/oauth_generator_test.exs:8-37`):
```elixir
describe "start_link/1 — provider :google" do
  test "discovery doc shape contains Google-shaped endpoints" do
    # Arrange
    {:ok, issuer} = OAuthIssuer.start_link(provider: :google)

    # Act
    config = OAuthIssuer.openid_config(issuer)

    # Assert
    assert is_binary(config["authorization_endpoint"])
    assert is_binary(config["token_endpoint"])
    assert is_binary(config["jwks_uri"])
    assert config["issuer"] == issuer.base_url
  end
end
```

**What to change:**
- Cover all 7 D-87-10 cells: discovery shape, authorize → 302, token + RS256 verify, jwks count: 1 vs 2, PKCE good vs bad, configurable exp near-expiry, refresh-rotation toggle, `email_verified` boolean shape.
- ExUnit `async: true` (TestServer is per-process isolated).
- AAA-flat blank-line-separated, NOT helper-extracted.

**Confidence:** HIGH — pattern is well-established in `test/sigra/install/`.

---

### `lib/mix/tasks/sigra.oauth.smoketest.ex` (NEW — adopter-side Mix task)

**Analog:** `lib/mix/tasks/sigra.upgrade.ex:1-97` (NimbleOptions-driven thin delegator + `@switches` + `@options_schema` + `use Mix.Task` + `@impl Mix.Task def run`) — most modern Mix-task pattern in the repo.

**Imports / moduledoc pattern** (from `sigra.upgrade.ex:1-50`):
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
  ...
  """

  use Mix.Task
end
```

**OptionParser + NimbleOptions pattern** (from `sigra.upgrade.ex:52-93`):
```elixir
@options_schema [
  provider: [type: :string, required: true, doc: "Provider to test (google)"],
  port: [type: :integer, default: 4001, doc: "Local callback port"],
  config: [type: {:or, [:string, nil]}, default: nil, doc: "Optional Sigra config path"]
]

@switches [provider: :string, port: :integer, config: :string]

@impl Mix.Task
def run(args) do
  {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
  validated = NimbleOptions.validate!(opts, @options_schema)
  Sigra.OAuth.Smoketest.run(validated)
end
```

**Bandit-boot + shell pattern** (from `lib/mix/tasks/sigra.fixture.rebless_golden.ex:46-57`):
```elixir
Mix.Task.run("loadpaths")
Mix.Task.run("compile")
Application.ensure_all_started(:bandit)
Mix.shell().info("==> sigra.oauth.smoketest: ...")
```

**What to change:**
- Delegate runtime to a `Sigra.OAuth.Smoketest` lib module (per `sigra.upgrade.ex` → `Sigra.Upgrade` pattern). The Mix task is a thin wrapper.
- Exit codes per RESEARCH.md: 0 success / 1 usage / 2 config / 3 round-trip fail.
- Print-and-wait (no `:os.cmd` browser open; defer per D-87-03).
- Use `Sigra.Token.generate/4` for state nonce — exercise Sigra's actual signing path.
- Bind to `127.0.0.1`, NOT `0.0.0.0` (security per RESEARCH.md `## Security Domain`).

**Confidence:** HIGH — `sigra.upgrade.ex` is the canonical 2026 task pattern; `rebless_golden.ex` covers the loadpaths+compile+Bandit boot incantation.

---

### `test/sigra/install/oauth_smoketest_task_test.exs` (NEW — ~40 LOC)

**Analog:** `test/sigra/install/oauth_generator_test.exs:1-80` (direct sibling — same dir, same role-shape).

**Imports / setup pattern**:
```elixir
defmodule Sigra.Install.OauthSmoketestTaskTest do
  use ExUnit.Case, async: true
end
```

**describe-block pattern** (from `oauth_generator_test.exs:8-37`):
```elixir
describe "config loading" do
  test "fails fast with exit code 2 when client_id is missing" do
    # Arrange
    Application.put_env(:sigra, :providers, [])

    # Act + Assert
    assert {:exit, 2} = capture_exit(fn ->
      Mix.Tasks.Sigra.Oauth.Smoketest.run(["--provider=google"])
    end)
  end
end
```

**What to change vs `oauth_generator_test.exs`:**
- This task does not mutate files; tests focus on config validation, port-flag handling, exit-code semantics, diagnostic emission.
- Stub the actual Bandit-boot via `start_supervised` or by extracting the round-trip into a testable lib module.
- NO `:os.cmd` test (smoketest is print-and-wait per D-87-03).

**Confidence:** HIGH.

---

### `docs/oauth-google-setup.md` (NEW — adopter recipe)

**Analog:** `docs/uat-ci-coverage.md:1-46` (closest semantic — heavy table + cross-ref + `mix sigra.*` invocation references). Also `docs/audit-semantics.md` for tone.

**Header / structure pattern** (from `docs/uat-ci-coverage.md:1-15`):
```markdown
# Setting up Google OAuth for Sigra

This document walks adopters through Google Cloud Console setup, Sigra
provider config, and verification via `mix sigra.oauth.smoketest`.

**Verification:** Run `mix sigra.oauth.smoketest --provider=google` after
configuration to confirm round-trip.

## 1. Create a Google Cloud project
## 2. Configure the OAuth consent screen
## 3. Create an OAuth 2.0 Client ID (Web application)
## 4. Set redirect URIs
## 5. Configure Sigra
## 6. Verify via `mix sigra.oauth.smoketest --provider=google`
```

**ExDoc nav addition** (from `mix.exs:163-202` — verify the `extras:` and `groups_for_extras:` shape at planning time):
```elixir
# In mix.exs `extras:` list, add:
"docs/oauth-google-setup.md",
# Group inheritance — research recommends "Docs" group; verify mix.exs:208 regex.
```

**What to change:**
- Numbered checklist style (cite Google Cloud Console exact button labels).
- End with the smoketest verification step.
- No screenshots (Sigra docs convention; describe the path verbally).
- Add to `mix.exs` `extras:` list and confirm `Docs` group regex match.

**Confidence:** MEDIUM — closest analogs are coverage/semantics docs, not "adopter setup recipe" docs. Sigra has no "getting started" recipe beyond `guides/introduction/getting-started.md`.

---

### `scripts/ci/install-smoke.sh` extension (D-87-04 surgical edits at lines 90-93, 134, archive pin)

**Analog:** The same file lines 60-94 (existing surgical-edit pattern for `mix sigra.install` + `mix sigra.gen.oauth`).

**Existing pattern at `scripts/ci/install-smoke.sh:90-93`** (the extension point):
```bash
echo "==> install-smoke: mix sigra.gen.oauth (greenfield generator contract)"
mix sigra.gen.oauth --providers google,github
mix ecto.migrate
mix compile --warnings-as-errors
```

**Edit 1 — between line 93 (after `mix compile --warnings-as-errors`) and line 95 (before `APP=$(...)`)**:
```bash
echo "==> install-smoke: creating + migrating test DB and running mix test"
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
MIX_ENV=test mix test
```

**Edit 2 — after line 134 (the existing 11-paths-OK echo) before line 136 (the done echo)**:
```bash
echo "==> install-smoke: oauth-gen: 12/12 expected artifacts present, mix test green"
```

**Edit 3 — `.github/workflows/ci.yml:256` (NOT install-smoke.sh; the archive install lives in the workflow step)**:
```yaml
# Before:
- name: Install phx_new archive
  run: mix archive.install --force hex phx_new
# After:
- name: Install phx_new archive
  run: mix archive.install --force hex phx_new 1.8.5
```

**What to change:** ONLY the 3 surgical edits above. Existing `set -euo pipefail` at line 14 propagates exit codes through `tee` (verified per RESEARCH.md `## CI Workflow Diff`).

**Confidence:** HIGH — the file already does exactly this pattern; we extend it by 6 lines + a pin.

---

### `.github/workflows/ci.yml` `install_smoke` transcript+upload (D-87-04 + D-87-06)

**Analog:** `.github/workflows/ci.yml:1019-1081` (`email_visual_regression` release-asset promotion — verbatim mirror).

**Existing release-asset promotion pattern** (from `.github/workflows/ci.yml:1043-1074`):
```yaml
# Upload the raw bundle artifact on every run (branch/PR and tags)
- name: Upload email visual regression bundle (main, 14d retention)
  if: always() && github.ref == 'refs/heads/main'
  uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
  with:
    name: email-visual-regression-bundle
    path: /tmp/email-visual-bundle/
    retention-days: 14
- name: Upload email visual regression bundle (PR/push, 7d retention)
  if: always() && github.ref != 'refs/heads/main' && !startsWith(github.ref, 'refs/tags/')
  uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a  # v7.0.1
  with:
    name: email-visual-regression-bundle
    path: /tmp/email-visual-bundle/
    retention-days: 7
- name: Create release asset archive (v* tag only)
  if: startsWith(github.ref, 'refs/tags/v')
  run: |
    cd /tmp && tar -czf "sigra-email-visual-regression-${{ github.ref_name }}.tar.gz" email-visual-bundle/
- name: Promote bundle to ${{ github.ref_name }} release asset
  if: startsWith(github.ref, 'refs/tags/v')
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    gh release upload "${{ github.ref_name }}" "/tmp/sigra-email-visual-regression-${{ github.ref_name }}.tar.gz" \
      --clobber \
      --repo "${{ github.repository }}"
```

**What to change:**
- Replace `email-visual-regression-bundle` with `oauth-gen-bundle`.
- Path: `.planning/uat-evidence/v1.20/oauth-gen/` (single dir, not `/tmp/email-visual-bundle/`).
- Add `tee` redirect at the existing `Run install smoke harness` step:
  ```yaml
  run: |
    mkdir -p .planning/uat-evidence/v1.20/oauth-gen/
    scripts/ci/install-smoke.sh 2>&1 | tee .planning/uat-evidence/v1.20/oauth-gen/transcript.log
  ```
- Add `permissions: contents: write` at the job level for the release-upload step (mirrors `email_visual_regression` job at line 939-940).

**Confidence:** HIGH — verbatim copy with surface-area renaming.

---

### `.github/workflows/ci.yml` new `oauth_e2e_playwright` job (D-87-05 + D-87-06)

**Analog:** `.github/workflows/ci.yml:551-789` (`example_playwright_smoke`) for job-graph + Postgres service + Node setup; `.github/workflows/ci.yml:218-267` (`install_smoke`) for the simpler `services:` + `steps:` skeleton; `.github/workflows/ci.yml:1019-1081` (artifact + release promotion).

**Job skeleton pattern** (from `install_smoke` lines 218-235):
```yaml
oauth_e2e_playwright:
  name: OAuth E2E Playwright (mock issuer)
  runs-on: ubuntu-latest
  permissions:
    contents: write  # for release upload on tags
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      ports: ['5432:5432']
      options: >-
        --health-cmd pg_isready --health-interval 10s
        --health-timeout 5s --health-retries 5
  steps:
    - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2
    - uses: erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93  # v1.24.0
      with:
        version-file: .tool-versions
        version-type: strict
```

**Playwright invocation step** (mirror `example_playwright_smoke` env + run shape):
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
      --project=chromium
```

**What to change:**
- Job graph: NO `needs:` clause (parallel-ready with install_smoke).
- Boot example app in `MIX_ENV=dev` on `localhost:4000` (matches `playwright.config.ts:48` longpoll-aware pattern).
- Set `EXAMPLE_DB_PROBE_ENABLED=1` + `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1` to gate test-only routes.
- Upload artifacts: traces + manifest dirs + DB probe outputs.
- Release-asset promotion on `v*` tags (mirror `email_visual_regression`).

**Confidence:** HIGH — the 3 referenced jobs together span every needed pattern.

---

### `test/example/priv/playwright/fixtures/oauthIssuer.ts` (NEW — Playwright helper module)

**Analog:** `test/example/priv/playwright/fixtures/mailbox.ts:1-52` (direct sibling, established pattern, ONE module in fixtures dir).

**Imports + type pattern** (from `mailbox.ts:1-9`):
```typescript
import { Page } from '@playwright/test';

type GoogleClaims = {
  sub: string;
  email: string;
  email_verified: boolean;
  name?: string;
  picture?: string;
};
```

**Polling / page.evaluate pattern** (from `mailbox.ts:22-49`):
```typescript
export async function setupIssuer(
  page: Page,
  claims: Partial<GoogleClaims>,
): Promise<void> {
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

**What to change vs `mailbox.ts`:**
- Plain helper module (NOT `test.extend` Playwright fixture) — matches mailbox.ts precedent.
- 3 functions: `setupIssuer`, `resetIssuer`, `probeIdentities`. (mailbox.ts has 2: `extractConfirmationLink`, internal `extractConfirmationHref`.)
- POSTs JSON to a test-only example-app endpoint (NEW server-side controller — see below).
- Document the `workers: 1` shared-state assumption in a top-of-file comment per RESEARCH.md `## Risks #4`.

**Confidence:** HIGH — `mailbox.ts` is the exact precedent.

---

### `test/example/priv/playwright/tests/oauth-register.spec.ts` (NEW — GAUAT-04)

**Analog:** `test/example/priv/playwright/tests/golden-path.spec.ts:1-100` (LiveView wait + register + login + cookie + redirect lifecycle).

**Imports + helper pattern** (from `golden-path.spec.ts:13-34`):
```typescript
import { test, expect } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';
import { setupIssuer, probeIdentities, resetIssuer } from '../fixtures/oauthIssuer';

test('GAUAT-04: register/login/logout/re-login via mock Google OAuth', async ({
  page,
  request,
}) => {
  const email = `oauth-test-${Date.now()}@example.test`;

  // Set up mock issuer with Google-shaped claims
  await setupIssuer(page, {
    sub: `mock-google-uid-${Date.now()}`,
    email,
    email_verified: true,
  });

  try {
    // Cell 1: provider button visible on /users/log_in
    await page.goto('/users/log_in');
    await expect(page.locator('a:has-text("Sign in with Google")')).toBeVisible();

    // Cell 2: click → 302 redirect to issuer's /oauth2/v2/auth with state
    const authorizeRequest = page.waitForRequest(/\/oauth2\/v2\/auth.*state=/);
    await page.click('a:has-text("Sign in with Google")');
    await authorizeRequest;

    // Cell 3: callback → land on / with session cookie set
    await expect(page).toHaveURL('/');

    // Cell 4: DB probe — exactly 1 user + 1 identity
    const identities = await probeIdentities(page, email);
    expect(identities.count).toBe(1);
    expect(identities.rows[0].provider).toBe('google');

    // Cell 5: logout
    await page.click('a:has-text("Log out")');
    await expect(page).not.toHaveURL('/');

    // Cell 6: re-login uses same user (no new identity row)
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

**Date-suffixed unique email** (from `golden-path.spec.ts:21`):
```typescript
const email = `oauth-test-${Date.now()}@example.test`;
```

**What to change vs `golden-path.spec.ts`:**
- NO `waitForLiveViewReady` (login page is a plain controller per `session_controller_test.exs:42-50`; OAuth callback redirects to `/` which is also plain controller).
- Mock issuer setup/teardown via the new `oauthIssuer.ts` fixture.
- DB probe assertion via `probeIdentities` instead of mailbox `extractConfirmationLink`.
- 6 cells per RESEARCH.md `## Validation Architecture > Phase Requirements > Test Map`.

**Confidence:** HIGH.

---

### `test/example/priv/playwright/tests/oauth-link.spec.ts` (NEW — GAUAT-05, 4 sub-tests + 1 hero PNG)

**Analog:** `test/example/priv/playwright/tests/golden-path.spec.ts` (sub-test structure + LiveView readiness for `/users/settings/oauth` LV) + `test/example/priv/playwright/tests/email-visual.spec.ts:103-106` (the `toHaveScreenshot` invocation pattern, AND ONLY that — see ANTI-PATTERN below).

**Sub-test structure pattern** (from `ga-uat-shift-left.spec.ts:111-121`):
```typescript
test.describe('GAUAT-05: OAuth provider link/unlink visual states', () => {
  test('linked-with-password: unlink button enabled, no tooltip', async ({ page }) => { ... });
  test('only-oauth-no-password: unlink disabled + tooltip + hero PNG', async ({ page }) => { ... });
  test('after-set-password: button flips to enabled', async ({ page }) => { ... });
  test('post-unlink: identity row deleted; password login still works', async ({ page }) => { ... });
});
```

**Hero PNG screenshot cell** (from `email-visual.spec.ts:103-106` — verbatim shape):
```typescript
await expect(page).toHaveScreenshot('oauth-link__disabled-tooltip.png', {
  fullPage: true,
  maxDiffPixels: 50,
});
```

**Disabled-tooltip attribute assertion** (verbatim from `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92`):
```typescript
await expect(unlinkButton).toBeDisabled();
await expect(unlinkButton).toHaveAttribute(
  'title',
  'Set a password first to keep access to your account.',
);
```

**What to change vs `email-visual.spec.ts`:**
- DO NOT inherit `email-visual.spec.ts`'s matrix-driven `for (const template of TEMPLATES)` structure — see ANTI-PATTERN below.
- 4 separate `test()` cases under one `describe` block (NOT 4 cells in a matrix).
- ONE PNG total (the disabled-tooltip hero), not 4.
- The other 3 sub-tests use only DOM/DB assertions, no screenshots.

**Confidence:** HIGH — pattern follows golden-path's describe-block discipline; the screenshot incantation is one-line verbatim from email-visual.spec.

---

### `test/example/priv/playwright/tests/oauth-email-match.spec.ts` (NEW — GAUAT-06)

**Analog:** `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts:111-121` (closest semantic — flash + mailbox arrival pattern).

**Mailbox-poll + flash-text pattern** (from `ga-uat-shift-left.spec.ts:71-72` and `mailbox.ts:23-49`):
```typescript
import { test, expect } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';
import { setupIssuer, probeIdentities, resetIssuer } from '../fixtures/oauthIssuer';

test('GAUAT-06: email-match flash + redirect + identity-row + linked-email', async ({
  page,
}) => {
  // Pre-seed alice@example.test with password (via standard register flow)
  const aliceEmail = `alice-${Date.now()}@example.test`;
  // ... register Alice with password ...

  // Mock issuer returns matching email + novel sub
  await setupIssuer(page, {
    sub: `novel-google-uid-${Date.now()}`,
    email: aliceEmail,
    email_verified: true,
  });

  // Click "Sign in with Google" → land on /users/log_in with verbatim flash text
  await page.goto('/users/log_in');
  await page.click('a:has-text("Sign in with Google")');

  // Verbatim flash text from priv/templates/sigra.gen.oauth/oauth_controller.ex:96
  await expect(page.locator('.flash-info')).toContainText(
    'An account with this email exists. Log in to link your google account.',
  );

  // Submit password → land on /
  await page.fill('#login_form input[name="user[password]"]', alicePassword);
  await page.click('#login_form button:has-text("Log in")');
  await expect(page).toHaveURL('/');

  // DB probe: new identity row for (alice.id, google, novel_sub)
  const identities = await probeIdentities(page, aliceEmail);
  expect(identities.count).toBe(1);

  // provider_linked_email arrives in /dev/mailbox/json (reuse mailbox.ts pattern)
  const linkedEmail = await waitForMailboxRow(page, aliceEmail, /Provider linked/);
  expect(linkedEmail).toBeTruthy();
});
```

**What to change vs `ga-uat-shift-left.spec.ts`:**
- Reuse `mailbox.ts` polling logic — extract or replicate `extractMailboxRow` per RESEARCH.md.
- Verbatim flash assertion `An account with this email exists. Log in to link your google account.` — provider atom interpolated as `"google"` (NOT `":google"`). Cite `priv/templates/sigra.gen.oauth/oauth_controller.ex:96` source-of-truth in a comment.
- One linear test, not 4 sub-tests.

**Confidence:** HIGH.

---

### `test/example/lib/example_web/router.ex` extension (env-gated test routes)

**Analog:** `test/example/lib/example_web/router.ex:172-177` (existing `if Application.compile_env(:example, :dev_routes) do ... end` env-gated mount block).

**Existing pattern** (verbatim from `router.ex:168-177`):
```elixir
# Dev-only routes for local UAT — Swoosh local-mailbox preview at /dev/mailbox
# so manual testers can inspect rendered emails (confirmation, password reset,
# lockout, suspicious login, account lifecycle). Compile-only gate ensures
# this scope is excluded from prod and test builds.
if Application.compile_env(:example, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
```

**What to add (mirror the pattern):**
```elixir
# Test-only DB probe + OAuth issuer control endpoints, env-gated. Read-only
# DB introspection + Application.put_env proxy for Sigra.Testing.OAuthIssuer.
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

**What to change vs the dev_routes pattern:**
- Use `System.get_env(...) == "1"` instead of `Application.compile_env(...)` — research recommends env var (set in CI step) for runtime gating; matches D-87-05 Claude's discretion.
- Pipeline `:api` (JSON), not `:browser`.
- Add the controllers below.

**Confidence:** HIGH.

---

### `test/example/lib/example_web/controllers/test_db_probe_controller.ex` (NEW)

**Analog:** `test/example/lib/example_web/controllers/page_controller.ex` (closest skeleton — smallest existing controller).

**Skeleton pattern**:
```elixir
defmodule ExampleWeb.TestDbProbeController do
  @moduledoc """
  Test-only read-only DB introspection endpoint for Playwright OAuth specs.
  Mounted only when `EXAMPLE_DB_PROBE_ENABLED=1`. Never ship to production.
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
end
```

**What to change:**
- Read-only via `Repo.all`; no writes.
- Whitelisted `table` parameter (only `user_identities` initially); return 400 for any other.
- Documentation note: "Never ship to production" + env-gate reminder.

**Confidence:** MEDIUM — small skeleton; the join shape may need adjustment based on the example app's actual schema (verify `Example.Accounts.UserIdentity` exists per RESEARCH.md `## Existing code insights`).

---

### `test/example/lib/example_web/controllers/test_oauth_issuer_controller.ex` (NEW)

**Analog:** Same as test_db_probe (smallest controller skeleton). Plus `lib/sigra/testing.ex` for `Application.put_env` discipline.

**Skeleton + Application.put_env pattern** (verbatim from RESEARCH.md `## Application Config Injection`):
```elixir
defmodule ExampleWeb.TestOAuthIssuerController do
  @moduledoc """
  Test-only HTTP endpoint that proxies set_user/reset calls into
  Sigra.Testing.OAuthIssuer + Application.put_env for :oauth_provider_overrides.
  Mounted only when `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`.
  """
  use ExampleWeb, :controller

  def setup(conn, %{"provider" => "google", "user" => user_claims}) do
    {:ok, issuer} = Sigra.Testing.OAuthIssuer.start_link(
      provider: :google,
      user: atomize_claims(user_claims)
    )

    Application.put_env(:sigra, :oauth_provider_overrides, [
      google: [
        base_url: Sigra.Testing.OAuthIssuer.url(issuer),
        openid_configuration: Sigra.Testing.OAuthIssuer.openid_config(issuer),
      ]
    ])

    Process.put({__MODULE__, :issuer}, issuer)
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

**What to change vs page_controller:**
- POST endpoints (not GET) — reflects mutation surface (Application.put_env + spawning issuer process).
- Process dict storage for cleanup handle (`Process.put({__MODULE__, :issuer}, issuer)`).
- Atomize the user-claims map keys in a private helper.

**Confidence:** MEDIUM — research provides exact code; planner must verify `Sigra.OAuth` reads provider config at request time (RESEARCH.md `## Risks > High-impact #1` + Assumption A1).

---

### `test/example/test/example_web/oauth_controller_test.exs` (NEW — research labeled "extension" but file does NOT exist)

**IMPORTANT FINDING:** `find /Users/jon/projects/sigra/test/example -name "oauth*" -type f` returns ONLY `test/example/test/example_web/smoke/oauth_test.exs`. The path `test/example/test/example_web/oauth_controller_test.exs` does NOT exist. RESEARCH.md says "extension (~30 LOC)" but this is a NEW file. Planner should clarify this in PLAN.md.

**Analog:** `test/example/test/example_web/controllers/session_controller_test.exs:1-50` (HTTP-stack ConnCase test + `:example_app` moduletag + setup fixture).

**Imports / setup pattern** (from `session_controller_test.exs:1-29`):
```elixir
defmodule ExampleWeb.OAuthControllerTest do
  @moduledoc """
  Phase 87 D-87-10: controller-level integration covering OAuth callback error
  paths (state mismatch, provider error, no-email) using
  Sigra.Testing.OAuthIssuer. Closes the gap surfaced by research — controller
  integration was missing from the existing OAuth test inventory.
  """
  use ExampleWeb.ConnCase, async: true
  import Example.AccountsFixtures

  alias Sigra.Testing.OAuthIssuer

  @moduletag :example_app

  setup do
    {:ok, issuer} = OAuthIssuer.start_link(provider: :google)
    Application.put_env(:sigra, :oauth_provider_overrides, [
      google: [base_url: OAuthIssuer.url(issuer)]
    ])

    on_exit(fn ->
      OAuthIssuer.stop(issuer)
      Application.delete_env(:sigra, :oauth_provider_overrides)
    end)

    %{issuer: issuer}
  end
end
```

**describe-block pattern** (from `session_controller_test.exs:31-51`):
```elixir
describe "GET /auth/google/callback (state mismatch)" do
  test "returns 400 with state-mismatch error", %{conn: conn} do
    conn = get(conn, "/auth/google/callback", %{"state" => "tampered", "code" => "x"})
    assert html_response(conn, 400) =~ "Invalid state"
  end
end
```

**What to change:**
- Per D-87-10: 3 controller tests covering state mismatch, provider error response, no-email flash.
- Use `OAuthIssuer` (not `MockStrategy`) per CONTEXT.md `## Folded scope`.
- Cite the research-flagged "this file is NEW, not extension" in commit message.

**Confidence:** HIGH — pattern from session_controller_test is direct.

---

### Wave 2

---

### `lib/mix/tasks/sigra.uat.report.ex` extension (D-87-06 + sigra.uat.report extension)

**Analog:** The same file lines 65-93 (`@phase_04_templates`, `@phase_08_templates` — identical structure for the new 4 phase atoms).

**Existing module-attribute pattern** (verbatim from `sigra.uat.report.ex:80-93`):
```elixir
@phase_04_templates [
  "lockout-notification",
  "suspicious-login"
]

@phase_08_templates [
  "email-change-confirmation",
  ...
]
```

**Pattern to add** (per RESEARCH.md `## mix sigra.uat.report extension`):
```elixir
@phase_oauth_gen_artifacts ["transcript.log", "reports/artifact-inventory.json"]
@phase_oauth_google_artifacts ["reports/playwright-trace-{sha}.zip"]
@phase_oauth_link_artifacts [
  "reports/db-probe-results.json",
  "snapshots/oauth-link__disabled-tooltip__sha-{sha}.png"
]
@phase_oauth_email_match_artifacts [
  "reports/flash-text-assertion.json",
  "reports/linked-email-mailbox.json"
]
```

**OptionParser extension** (from `sigra.uat.report.ex:97`):
```elixir
{opts, _, _} = OptionParser.parse(argv, strict: [phase: :string, check: :boolean])
# Accepts --phase=04 | 08 | oauth-gen | oauth-google | oauth-link | oauth-email-match
```

**What to change:**
- 4 new phase atoms threaded through dispatch logic.
- Each phase has its own artifact list (different shape than email-phase templates).
- README + manifest generators per phase reuse the existing 9-field schema.
- ~80-100 LOC added per RESEARCH.md.

**Confidence:** HIGH — direct extension of existing structure.

---

### `.planning/uat-evidence/v1.20/oauth-{gen,google,link,email-match}/README.md` (NEW × 4)

**Analog:** `.planning/uat-evidence/v1.20/email-phase-04/README.md` (verbatim 9-field schema).

**Verbatim YAML frontmatter pattern** (from `email-phase-04/README.md:1-12`):
```markdown
---
phase: 04
gauat_requirement: GAUAT-01
hex_version: 0.2.5
git_sha: 6ce3cd3
git_tag: 
ci_run_url: 
ci_workflow: .github/workflows/ci.yml / email_visual_regression
generated_by: mix sigra.uat.report --phase=04
generated_at: 2026-04-26T18:47:22Z
disposition: pass
---
```

**Table pattern** (from `email-phase-04/README.md:20-29`):
```markdown
| Template | Engine | Theme | Outcome | SHA-256 (first 16) | Bytes |
|----------|--------|-------|---------|--------------------|-------|
| lockout-notification | chromium | light | pass | `b6436e2c37dce18d` | 46983 |
```

**What to change:**
- Adapt frontmatter `phase` → `87`, `gauat_requirement` → `GAUAT-03`/04/05/06, `ci_workflow` → `install_smoke` or `oauth_e2e_playwright`, `generated_by` → `mix sigra.uat.report --phase=oauth-{slug}`.
- Adapt table columns per evidence dir (artifact-class / outcome / ci_run_url / sha-256).
- Generated by `mix sigra.uat.report` extension (Wave 2 commit) — manual edits only for skeleton.

**Confidence:** HIGH — schema is locked.

---

### `.planning/uat-evidence/v1.20/oauth-{gen,google,link,email-match}/manifest.json` (NEW × 4)

**Analog:** `.planning/uat-evidence/v1.20/email-phase-04/manifest.json` (verbatim row shape).

**Verbatim row pattern** (from `email-phase-04/manifest.json:1-16`):
```json
[
  {
    "template": "lockout-notification",
    "engine": "chromium",
    "theme": "light",
    "viewport": "640x1200",
    "byte_size": 46983,
    "byte_budget_max": 100000,
    "contrast_min_ratio": 4.5,
    "outcome": "pass",
    "git_sha": "6ce3cd3",
    "hex_version": "0.2.5",
    "ci_run_url": "",
    "artifact_url": "",
    "snapshot_sha256": "b6436e2c37..."
  }
]
```

**What to change:**
- Replace `template`/`engine`/`theme` with `gauat_requirement`/`artifact_class`/`outcome` per the OAuth surface (e.g., `oauth-google`: rows for `provider-button-render`, `authorize-redirect`, `mock-issuer-callback`, `user-record`, `identity-row`, `session`, `logout`, `re-login`).
- Keep `git_sha`, `hex_version`, `ci_run_url`, `artifact_url`, `outcome` columns verbatim.

**Confidence:** HIGH.

---

### `.planning/uat-evidence/v1.20/oauth-link/snapshots/oauth-link__disabled-tooltip__sha-{short-sha}.png`

**Analog:** `.planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__chromium__light__sha-6ce3cd3.png` (naming convention).

**Naming convention** (from `INDEX.md:21-32`):
```
{template-slug}__{engine}__{theme}__sha-{short-sha}.png
```

**For OAuth-link:** `oauth-link__disabled-tooltip__sha-{short-sha}.png` (drop the engine+theme fields since OAuth-link is single-engine; keep the double-underscore separator + sha-{short-sha} tail).

**Confidence:** HIGH.

---

### `.planning/uat-evidence/v1.20/INDEX.md` extension

**Analog:** The same file lines 14-17 (existing 2-row format for email-phase-04 / email-phase-08).

**Pattern to add (mirror lines 14-17):**
```markdown
- [oauth-gen](oauth-gen/README.md) — GAUAT-03: install-smoke transcript + 12-artifact inventory
- [oauth-google](oauth-google/README.md) — GAUAT-04: register/login/logout/re-login Playwright trace
- [oauth-link](oauth-link/README.md) — GAUAT-05: 4 visual states + 1 hero PNG
- [oauth-email-match](oauth-email-match/README.md) — GAUAT-06: flash + redirect + identity + linked-email
```

**Snapshot count table extension** (from `INDEX.md:36-40`):
```markdown
| 87 (OAuth) | 4 evidence dirs | -- | 1 hero PNG (oauth-link) |
```

**Confidence:** HIGH.

---

### `docs/uat-ci-coverage.md` SEED-001 row update

**Analog:** The same file lines 9-12 (existing SEED-3..6 rows already point at Phase 87 surfaces — verify in planning).

**EXISTING TEXT** (verbatim from `docs/uat-ci-coverage.md:9-12` — already references Phase 87 work):
```markdown
| **3** | `mix sigra.gen.oauth` greenfield | **`install_smoke` CI job (Phase 87 extended)** → ...; transcript at `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` ... | ... |
| **4** | Google OAuth E2E | ... **`oauth_e2e_playwright` CI job (Phase 87)** ... | ... |
| **5** | Provider linking / last-method unlink | ... **`oauth_e2e_playwright` CI job (Phase 87)** — `oauth-link.spec.ts` ... | ... |
| **6** | Email-match confirmation / invitation lock | ... **`oauth_e2e_playwright` CI job (Phase 87)** — `oauth-email-match.spec.ts` ... | ... |
```

**FINDING:** The doc already has Phase 87 references in place — D-87-08 says it should be updated, but the rows already point at the new artifacts. The Wave 2 edit is to confirm this matches the actual evidence dirs created in Wave 2 (residual-column verb tense, ci-run-url linkage).

**What to change:**
- Verify the residual column for items 3-6 reads correctly post-Wave 2.
- Confirm any pre-Wave-1 placeholder phrasing is replaced with concrete CI job names.

**Confidence:** HIGH (rows already exist; only minor wording refinement needed).

---

### `CHANGELOG.md` `[Unreleased]` append

**Analog:** Existing `CHANGELOG.md` `[Unreleased]` block (read at planning time).

**Per D-87-08 + RESEARCH.md `## File-by-File Plan` Wave 2 #8:**
```markdown
- Phase 87: extended install-smoke + Sigra.Testing.OAuthIssuer + 3 Playwright OAuth specs + mix sigra.oauth.smoketest --provider=google. 0 human UAT for OAuth in v1.20.
```

**Confidence:** HIGH.

---

## Shared Patterns

### Phase 86 Evidence Schema (D-87-06)
**Source:** `.planning/uat-evidence/v1.20/email-phase-04/{README.md,manifest.json}`
**Apply to:** All 4 new evidence dirs (oauth-gen, oauth-google, oauth-link, oauth-email-match)

**9-field YAML frontmatter** (verbatim):
```yaml
phase: 87
gauat_requirement: GAUAT-{03|04|05|06}
hex_version: {sigra version}
git_sha: {short SHA}
git_tag: {empty until v* tag promotion}
ci_run_url: {populated by mix sigra.uat.report at CI time}
ci_workflow: .github/workflows/ci.yml / {install_smoke | oauth_e2e_playwright}
generated_by: mix sigra.uat.report --phase=oauth-{slug}
generated_at: {ISO 8601 UTC}
disposition: pass
```

### Two-Commit Closure (D-87-07, mirrors Phase 86 D-86-11)
**Source:** RESEARCH.md `## Implementation Strategy` + `87-CONTEXT.md` D-87-07
**Apply to:** Wave 1 plan + Wave 2 plan structure (NOT a code pattern but a planning pattern the planner must enforce)

- Wave 1: code + tests + install-smoke + specs + smoketest + docs. Gate: full library suite + extended install_smoke + new oauth_e2e_playwright CI jobs all green.
- Wave 2: evidence dirs + sigra.uat.report extension + release-asset promotion + 87-VERIFICATION.md. Gate: Wave 1 CI green at Wave 1 SHA.

### Mix Task Skeleton
**Source:** `lib/mix/tasks/sigra.upgrade.ex:1-97`
**Apply to:** `lib/mix/tasks/sigra.oauth.smoketest.ex` + the `sigra.uat.report.ex` extension
```elixir
@shortdoc "..."
@moduledoc """..."""

use Mix.Task

@options_schema [...]  # NimbleOptions
@switches [...]        # OptionParser

@impl Mix.Task
def run(args) do
  {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
  validated = NimbleOptions.validate!(opts, @options_schema)
  Sigra.SomeModule.run(validated)
end
```

### Env-Gated Test Routes
**Source:** `test/example/lib/example_web/router.ex:172-177`
**Apply to:** `/test/db_probe` + `/test/oauth_issuer/{setup,reset}` mount blocks
```elixir
if System.get_env("EXAMPLE_X_ENABLED") == "1" do
  scope "/test", ExampleWeb do
    pipe_through :api
    get/post "/...", FooController, :action
  end
end
```

### Verbatim Source Strings (D-87-05, D-87-06 — load-bearing assertions)
**Source:** `priv/templates/sigra.gen.oauth/oauth_controller.ex:96` + `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92`
**Apply to:** GAUAT-05 disabled-tooltip + GAUAT-06 flash-text Playwright assertions

```typescript
// GAUAT-05 (oauth_settings_live.ex:92)
'Set a password first to keep access to your account.'

// GAUAT-06 (oauth_controller.ex:96 — provider atom interpolated as bare slug, no colon)
'An account with this email exists. Log in to link your google account.'
```

### Playwright Helper Module (NOT test.extend fixture)
**Source:** `test/example/priv/playwright/fixtures/mailbox.ts`
**Apply to:** `test/example/priv/playwright/fixtures/oauthIssuer.ts`
- Plain TS module exporting async functions
- Use `page.evaluate(async () => fetch('/test/...'))` for DB / control endpoints
- Document the `workers: 1` shared-state assumption in a top-of-file comment

---

## Anti-Patterns (DO NOT inherit)

### `oauth-link.spec.ts` MUST NOT inherit `email-visual.spec.ts`'s matrix structure

**Why this is an anti-pattern (per D-87-05):**
- `email-visual.spec.ts:65-108` uses `for (const template of TEMPLATES) { test(\`...${template}\`, ...) }` because every cell has the same assertion (`toHaveScreenshot`).
- `oauth-link.spec.ts` has **divergent assertions per cell**: linked-with-password (DOM), only-oauth-no-password (DOM + tooltip + ONE PNG), after-set-password (DOM), post-unlink (DB).
- A matrix loop would force identical assertion shape; the GAUAT-05 cells legitimately diverge.

**Correct shape:** 4 separate `test()` cases under one `test.describe('GAUAT-05: ...')` block — closer to `ga-uat-shift-left.spec.ts:111-121` than `email-visual.spec.ts:65-108`.

### `mix sigra.oauth.smoketest` MUST NOT inherit `sigra.gen.oauth`'s shape

**Why this is an anti-pattern:**
- `sigra.gen.oauth.ex` is a generator (file emission, EEx templates, idempotent injection — ~300 LOC of file-system mutation logic).
- `sigra.oauth.smoketest.ex` is a one-shot verification tool (boots Bandit, prints URL, waits for callback, exits with diagnostic — ~150 LOC of round-trip orchestration).
- Don't pull in `Mix.Phoenix.web_module()`, `Mix.Phoenix.base()`, EEx binding lists, or the file-emission DSL.

**Correct analog:** `sigra.upgrade.ex` (NimbleOptions thin delegator) + `sigra.fixture.rebless_golden.ex` (Bandit-boot + shell-tee orchestration). Both are runtime tools, not generators.

### `Sigra.Testing.OAuthIssuer` MUST NOT replace `Sigra.Testing.mock_oauth_callback/1`

**Why:** They are complementary, not substitutes (per CONTEXT.md `## Existing code insights`):
- `mock_oauth_callback/1` (`lib/sigra/testing.ex:1015`): in-memory shape helper for unit tests (returns a map; no HTTP).
- `OAuthIssuer` (new): TestServer-backed HTTP-stack issuer for integration tests (real OIDC ceremony).

Don't deprecate `mock_oauth_callback/1`. Don't migrate existing unit tests to `OAuthIssuer`. Only the 3 new Playwright specs + the controller-integration extension test use the issuer.

### `test/example/priv/playwright/fixtures/oauthIssuer.ts` MUST NOT use `test.extend`

**Why (per RESEARCH.md `## Application Config Injection`):** The closest precedent (`mailbox.ts`) is a plain helper module — `test.extend` introduces fixture-injection idioms not present elsewhere in the spec set. Stay consistent with `mailbox.ts`.

### `oauth-register.spec.ts` MUST NOT use `waitForLiveViewReady`

**Why (per `golden-path.spec.ts:30-34` + `session_controller_test.exs:42-50`):** The login page (`/users/log_in`) is a **plain controller** (post-Plan-04), NOT a LiveView — no `data-phx-session.phx-connected` element. The OAuth callback redirects to `/` which is also a plain controller. Adding `waitForLiveViewReady` would hang on a non-existent selector.

Use `golden-path.spec.ts:55-66` (the post-confirm bare login flow) as the precedent, NOT `golden-path.spec.ts:36-45` (the LiveView register flow).

---

## No Analog Found

Files genuinely without close in-repo precedent (planner should use RESEARCH.md + external citations instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/support/sigra/testing/oauth_issuer.ex` | TestServer-backed mock OIDC issuer | request-response | No similar test-support module exists; closest is Assent's `OIDCTestCase` (external). Mirror that verbatim per D-87-02 + RESEARCH.md `## Module APIs`. |
| `test/support/sigra/testing/fixtures/oauth_issuer_rsa_kid{1,2}.pem` | RSA fixture keys | static asset | No committed RSA/key PEMs anywhere in repo. Generate once with `:public_key.generate_key/1`; commit; verify `mix.exs:146` package list excludes `test/`. |
| `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` | tee'd CI install-smoke transcript | static log | Phase 86 has no transcript.log artifact (its evidence is purely PNG + JSON). The transcript-tee + release-asset promotion shape is novel. Mirror `email_visual_regression`'s upload-and-promote pattern but with a single `.log` file (not a bundle). |

---

## Metadata

**Analog search scope:** `lib/`, `test/`, `test/support/`, `test/example/`, `test/example/priv/playwright/`, `lib/mix/tasks/`, `scripts/ci/`, `.github/workflows/`, `.planning/uat-evidence/`, `docs/`, `priv/templates/sigra.gen.oauth/`

**Files Read (verified):** `mix.exs`, `lib/mix/tasks/sigra.upgrade.ex`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `lib/mix/tasks/sigra.gen.oauth.ex`, `lib/mix/tasks/sigra.uat.report.ex`, `lib/sigra/testing.ex` (lines 990-1099), `test/sigra/install/oauth_generator_test.exs`, `test/example/test/example_web/smoke/oauth_test.exs`, `test/example/test/example_web/controllers/page_controller_test.exs`, `test/example/test/example_web/controllers/session_controller_test.exs`, `test/example/lib/example_web/router.ex` (lines 1-200), `test/example/priv/playwright/fixtures/mailbox.ts`, `test/example/priv/playwright/tests/golden-path.spec.ts` (lines 1-100), `test/example/priv/playwright/tests/email-visual.spec.ts`, `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` (lines 1-120), `test/example/priv/playwright/playwright.config.ts` (lines 40-130), `scripts/ci/install-smoke.sh` (full), `.github/workflows/ci.yml` (lines 218-267, 1015-1081), `.planning/uat-evidence/v1.20/INDEX.md`, `.planning/uat-evidence/v1.20/email-phase-04/README.md`, `.planning/uat-evidence/v1.20/email-phase-04/manifest.json`, `docs/uat-ci-coverage.md` (lines 1-50)

**Pattern extraction date:** 2026-04-26

**Cross-references:**
- CONTEXT.md decisions D-87-01..10
- RESEARCH.md `## Module APIs`, `## File-by-File Plan`, `## CI Workflow Diff`, `## Verbatim Source Strings`, `## DB Probe Seam — Tradeoff Analysis`, `## oauthIssuer.ts Wire Format`
- Phase 86 precedent: `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md` (D-86-06, D-86-08, D-86-09, D-86-11)
