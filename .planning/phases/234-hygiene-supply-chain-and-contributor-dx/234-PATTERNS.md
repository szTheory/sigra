# Phase 234: Hygiene, Supply Chain, and Contributor DX - Pattern Map

**Mapped:** 2026-07-31  
**Files analyzed:** 11 named files/artifacts plus a formatter-driven Elixir cleanup set  
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `mix.exs` | config | batch | `mix.exs` aliases at lines 137-165 | exact |
| `.formatter.exs` | config | transform | `.formatter.exs` lines 1-13 | exact |
| formatted non-golden `*.ex` / `*.exs` files selected by `.formatter.exs` | batch source cleanup | transform | existing formatter input declaration | role-match |
| `CONTRIBUTING.md` | documentation | request-response | `CONTRIBUTING.md` lines 11-56 | exact |
| `.github/workflows/ci.yml` | config | event-driven | library and Playwright job seams in the same workflow | exact |
| `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` | test | transform | itself, plus Phase 233 planning contract | exact |
| `test/sigra/planning/phase_234_hygiene_supply_chain_contract_test.exs` (new) | test | transform | `phase_232_playwright_economics_test.exs`, `phase_233_library_economics_contract_test.exs` | exact |
| `.github/workflows/release-please.yml` | config | event-driven | immutable `uses:` steps in release workflow lines 39-41, 85-94 | exact |
| `.github/dependabot.yml` | config | batch | existing GitHub Actions update entry at lines 1-11 | exact |
| `234-PLAYWRIGHT-INVENTORY.json` (new; name may vary) | config / inventory | transform | `test/support/ci/library_test_partitions.exs` | role-match |
| `SEED-006-admin-design-gallery-ci-baseline-recapture.md` | documentation / evidence | event-driven | Phase 232 evidence ledger and existing seed correction | exact |

## Pattern Assignments

### `mix.exs` (config, batch)

**Analog:** `mix.exs` lines 137-165.

Keep the existing alias list as the sole contributor-facing command. Insert the three locked hygiene legs into this list; do not create a second alias that the workflow expands independently.

**Alias pattern** (lines 137-148):

```elixir
defp aliases do
  [
    ci: [
      "compile --warnings-as-errors",
      "test",
      "ci.install_golden",
      "sigra.dep_off"
    ],
```

**Nested-test/dependency-off pattern** (lines 152-164):

```elixir
"ci.install_golden": [
  "test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs"
],
"sigra.dep_off": [
  "deps.unlock threadline",
  "deps.clean threadline --build",
  "compile --warnings-as-errors --no-deps-check",
  "test --only threadline_guard --no-deps-check"
],
```

### `.formatter.exs` and formatted source set (config + batch cleanup, transform)

**Analog:** `.formatter.exs` lines 1-13.

Narrow the formatter's explicit `test/fixtures` input before running the one-time format cleanup. The generated `test/fixtures/install_golden/tree/**` bytes must remain outside formatter ownership.

**Explicit input-list pattern** (lines 1-13):

```elixir
inputs: [
  "*.{ex,exs}",
  "{config,lib}/**/*.{ex,exs}",
  # Do not use a blanket `test/**` — `test/example/_build` and `deps` contain
  # non-Elixir *.ex copies of install templates that break `mix format`.
  "test/{sigra,support,mix,fixtures}/**/*.{ex,exs}",
  "test/*.{ex,exs}",
  "test/example/{lib,config,test,priv}/**/*.{ex,exs}",
  "test/example/mix.exs"
]
```

### `CONTRIBUTING.md` (documentation, request-response)

**Analog:** `CONTRIBUTING.md` lines 11-56.

Revise the existing local-gate section in lockstep with the alias and remove formatting from the “not in the PR gate” list. Preserve the documented Postgres/archive prerequisites and retain Credo/Dialyzer as optional, not new gates.

**Ordered gate documentation pattern** (lines 11-20):

```markdown
Run `mix ci` to reproduce the locally-faithful portion of the PR-fast required gate without leaving your terminal. It chains exactly four legs in the same order as CI:

1. `compile --warnings-as-errors` — library compiles with zero warnings.
2. `test` — full library test suite.
3. `ci.install_golden` — install golden diff + idempotency contract (`test/sigra/install/`).
4. `sigra.dep_off` — dep-off guard: unlocks `:threadline`, re-compiles without it (`--warnings-as-errors`), then runs the tagged `--only threadline_guard` subset.
```

### `.github/workflows/ci.yml` (config, event-driven)

**Analog:** `.github/workflows/ci.yml` library job/aggregate at lines 497-728 and Playwright matrix at lines 1354-1556.

Add a direct `mix ci` invocation to the selected existing PR library lane, preserving the byte-stable `Library tests` aggregate and its failure aggregation. For the two currently orphaned specs, extend the existing explicit `admin_behavior` command when source intent confirms they remain useful; commands, not `testIgnore` regexes, establish ownership.

**Required aggregate preservation** (lines 695-728):

```yaml
library_tests:
  name: Library tests          # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)
  runs-on: ubuntu-latest
  timeout-minutes: 5
  needs: [library_tests_shard, library_tests_scaffold]
  if: always()
  steps:
    - name: Require all library_tests shards to pass
      env:
        SHARDS: ${{ needs.library_tests_shard.result }}
        SCAFFOLD: ${{ needs.library_tests_scaffold.result }}
      run: |
        set -euo pipefail
        if [[ "$SHARDS" != "success" ]]; then
          exit 1
        fi
```

**Explicit Playwright ownership-command pattern** (lines 1425-1441):

```yaml
- name: Run admin behavior browser truth
  if: ${{ !cancelled() && needs.changes.outputs.docs_only != 'true' && matrix.seam == 'admin_behavior' }}
  working-directory: test/example/priv/playwright
  env:
    CI: "true"
    SIGRA_EXAMPLE_URL: ${{ matrix.base_url }}
  run: |
    npx playwright test \
      tests/admin-user-operations.spec.ts \
      tests/impersonation.spec.ts \
      tests/admin-audit.spec.ts \
      --project=chromium \
      --retries=0
```

**Shared boot seam** (lines 1412-1423):

```yaml
- name: Boot isolated example app
  id: boot
  uses: ./.github/actions/example-playwright-boot
  with:
    database-name: ${{ matrix.database }}
    app-port: ${{ matrix.port }}
    base-url: ${{ matrix.base_url }}
```

### `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` (test, transform)

**Analog:** its repository-root helpers at lines 15-31 and Phase 233's job extractor at `test/sigra/planning/phase_233_library_economics_contract_test.exs` lines 260-266.

Revise this test rather than adding a contradictory second DX-01 contract. Change its stale four-leg/no-format assertion to require all seven alias legs, still prohibit Credo/Dialyzer/mix_audit, and assert the selected workflow job contains a literal `mix ci` call.

**Root-relative source-reading pattern** (lines 15-30):

```elixir
use ExUnit.Case, async: true

defp root do
  Path.expand("../../..", __DIR__)
end

defp read!(rel) do
  root() |> Path.join(rel) |> File.read!()
end

defp aliases_region(mix_exs) do
  case Regex.run(~r/defp aliases do\s*\[(.*?)\]\s*end/s, mix_exs) do
    [_, body] -> body
    _ -> ""
  end
end
```

**Fail-closed workflow extraction** (`phase_233_library_economics_contract_test.exs` lines 260-266):

```elixir
defp job_body(workflow, job_id) do
  pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

  case Regex.named_captures(pattern, workflow) do
    %{"body" => body} -> body
    _ -> flunk("missing workflow job #{job_id}")
  end
end
```

### `test/sigra/planning/phase_234_hygiene_supply_chain_contract_test.exs` (new test, transform)

**Analogs:** `test/sigra/planning/phase_232_playwright_economics_test.exs` lines 1-8, 73-104; `test/sigra/planning/phase_233_library_economics_contract_test.exs` lines 140-222.

Use one focused, async ExUnit source-contract module. It should read the release workflows, Dependabot YAML, inventory artifact, `ci.yml`, Playwright config, and manifests/lockfiles; derive the live `*.spec.ts` universe with `Path.wildcard/1`; then report missing and stale values explicitly. No YAML parser/package is needed for these locked structural invariants.

**Path constants and source contract shape** (`phase_232...` lines 1-8, 73-84):

```elixir
defmodule Sigra.Planning.Phase232PlaywrightEconomicsTest do
  use ExUnit.Case, async: true

  @config_path "test/example/priv/playwright/playwright.config.ts"
  @workflow_path ".github/workflows/ci.yml"
  @boot_action_path ".github/actions/example-playwright-boot/action.yml"

  test "one shared boot action owns the prelude for every example Playwright consumer" do
    workflow = File.read!(@workflow_path)
    assert File.exists?(@boot_action_path)
```

**Live-universe reconciliation pattern** (`test/support/ci/library_test_partitions.exs` lines 84-105, 120-128):

```elixir
eligible_paths =
  root
  |> Path.join("test/**/*_test.exs")
  |> Path.wildcard()
  |> Enum.map(&repository_path(root, &1))
  |> Enum.sort()

missing_paths = MapSet.difference(current_paths, assigned_path_set)
stale_paths = MapSet.difference(assigned_path_set, current_paths)

if MapSet.size(missing_paths) > 0 or MapSet.size(stale_paths) > 0 do
  raise ArgumentError, "current ordinary test manifest mismatch; missing current paths: #{format_paths(missing_paths)}; stale manifest paths: #{format_paths(stale_paths)}"
end
```

### `.github/workflows/release-please.yml` (config, event-driven)

**Analog:** immutable action references in the same workflow, notably lines 39-41 and 85-94.

Replace only the mutable Release Please ref with the decision-locked dereferenced SHA and a same-line version comment. The Phase 234 contract must inventory the deliberately scoped release-critical workflows, require lowercase 40-character SHA refs and comments, and reject the annotated tag-object SHA.

**Pinned-action convention** (lines 39-41):

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  with:
    fetch-depth: 0
```

**Target action seam** (lines 85-94):

```yaml
- name: Run Release Please
  id: release
  if: ${{ steps.release-preflight.outputs.should_run == 'true' }}
  uses: googleapis/release-please-action@v5
  with:
    token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}
```

### `.github/dependabot.yml` (config, batch)

**Analog:** `.github/dependabot.yml` lines 1-11.

Keep `version: 2`, preserve the existing `github-actions` root entry, and use the same `package-ecosystem` / `directory` / weekly schedule nesting for the root `mix` and Playwright-directory `npm` entries. The new Phase 234 contract should additionally assert their manifests and lockfiles exist.

**Existing entry pattern** (lines 1-11):

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "ci"
    labels:
      - "dependencies"
      - "ci"
```

### `234-PLAYWRIGHT-INVENTORY.json` (new inventory, transform)

**Analog:** `test/support/ci/library_test_partitions.exs` lines 71-131; source seams `.github/workflows/ci.yml` lines 1354-1556 and `playwright.config.ts` lines 27-42, 91-117.

Use a committed JSON inventory (preferred over prose because ExUnit can decode it) with one row per current `tests/*.spec.ts`; each row names workflow, job, seam, event set, explicit command marker, and Playwright config/project seam. The Phase 234 contract must compare inventory and glob as exact sets, reject empty ownership, and verify every claimed token resolves in the workflow/config. This is the Phase 235 GATE-05 input.

**Current config-name seam** (`playwright.config.ts` lines 27-42):

```typescript
const ADMIN_BEHAVIOR_SPECS =
  /(admin-user-operations|admin-audit|admin-theme|impersonation|admin-flow-).*\.spec\.ts/;
const ADMIN_CHECKPOINTS_SPEC = /admin-checkpoints\.spec\.ts/;
const ADMIN_DESIGN_SPEC = /admin-design\.spec\.ts/;
const ADMIN_GENERATED_SPEC = /admin-generated\.spec\.ts/;
const ADMIN_MODAL_SPEC = /admin-modal-interaction\.spec\.ts/;
```

**Fail-closed reconciliation/error pattern** (`test/support/ci/library_test_partitions.exs` lines 107-128):

```elixir
assigned_paths = List.wrap(partitions[1].paths) ++ List.wrap(partitions[2].paths)
current_paths = MapSet.new(current_ordinary_paths!(opts))
assigned_path_set = MapSet.new(assigned_paths)
missing_paths = MapSet.difference(current_paths, assigned_path_set)
stale_paths = MapSet.difference(assigned_path_set, current_paths)
```

### `SEED-006-admin-design-gallery-ci-baseline-recapture.md` (documentation/evidence, event-driven)

**Analog:** its existing corrected-root-cause and acceptance sections at lines 76-139, plus Phase 232's receipt at `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` lines 187-216.

Do not reopen UI remediation. Add a delivered closeout that retains the Phase 197 correction/remediation and cites the current gallery-lane receipt; if a new run contradicts it, create a tracked residual instead of weakening the claim.

**Corrected root cause and remediation pattern** (seed lines 86-123):

```markdown
**This premise was factually wrong.** Phase 197 research (D-07) verified conclusively:

- No `@font-face` rule existed anywhere in the served example CSS at time of filing.
...
The correct root cause of the ~20–53px height delta was a **host-OS `system-ui`
font-metric difference** between the macOS machine where baselines were captured ...

1. **Plan 03 (font determinism, D-08):** Self-hosted Space Grotesk variable woff2 ...
2. **Plan 04 (in-CI recapture, D-09):** A new `admin_design_recapture` sibling CI job ...
3. **Plan 05 (re-gate, D-10):** `continue-on-error: true` removed ...
```

**Current live receipt pattern** (`232-EVIDENCE.md` lines 202-216):

```markdown
| `admin_design_recapture` | 629s, success | responding after 3s; warmed `/admin/_design`; 126 design tests, 3 checkpoint compares, and 4 demo compares passed |

... No UI implementation or expected baseline was changed to obtain these receipts.
```

## Shared Patterns

### Hermetic source contracts

**Sources:** `test/sigra/planning/phase_232_playwright_economics_test.exs` lines 73-104; `test/sigra/planning/phase_233_library_economics_contract_test.exs` lines 260-266.  
**Apply to:** Phase 198 parity revision and the new Phase 234 hygiene contract.

Read committed source, use anchored job extraction, and fail via `flunk`/`assert` when a seam vanishes. Do not add external validation packages or network dependencies to the fast test suite.

### Exhaustive inventory reconciliation

**Source:** `test/support/ci/library_test_partitions.exs` lines 84-128.  
**Apply to:** the Playwright JSON inventory and its contract.

Derive the live filesystem universe, normalize repository-relative paths, compare `MapSet`s in both directions, and name missing/stale paths in diagnostics. A hand-maintained list without live reconciliation is not acceptable.

### CI trust boundaries

**Sources:** `.github/workflows/ci.yml` lines 695-728 and 1425-1529.  
**Apply to:** CI alias call-through and spec wiring.

Preserve the required `Library tests` display name, `if: always()` terminal aggregation, explicit `--retries=0`, no advisory shard behavior, and the shared Playwright boot action. Phase scope includes no UI component/style changes, so the `sg-*` UI constraints do not introduce a UI-file pattern here.

### Evidence claims

**Source:** `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` lines 187-229.  
**Apply to:** SEED-006 closeout and Dependabot's post-merge job receipts.

Separate structural proof from GitHub-service proof. Dependabot YAML and inventory are tested locally; GitHub job logs are required to claim service execution. No-update/no-PR is never evidence by itself.

## No Analog Found

None. A standalone shell/Node reconciler is optional only; the closest repository pattern favors an ExUnit planning contract plus JSON inventory, so do not add a script unless the planner can demonstrate it is necessary.

## Metadata

**Analog search scope:** `mix.exs`, `.formatter.exs`, `CONTRIBUTING.md`, `.github/workflows/`, `.github/actions/`, `.github/dependabot.yml`, `test/sigra/planning/`, `test/support/ci/`, `scripts/ci/`, and Phase 232/233 evidence/seed artifacts.  
**Files scanned:** 18 focused analogs/configurations.  
**Pattern extraction date:** 2026-07-31
