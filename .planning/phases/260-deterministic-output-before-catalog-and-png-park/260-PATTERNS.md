# Phase 260: Deterministic Output, Before Catalog and PNG Park - Pattern Map

**Mapped:** 2026-11-15
**Files analyzed:** 31 new/modified files (14 new, 17 modified)
**Analogs found:** 31 / 31 (no file lacks an analog; two are role-match only, see "No Analog Found")
**Source of file list:** `260-RESEARCH.md` (no CONTEXT.md exists for this phase). Wave 0 Gaps, Per-Requirement Findings, Wave Ordering.

All analog paths below were checked with `git ls-files` and are tracked source. The repo also holds gitignored/untracked mirror copies of some tests under `.gsd/**` (for example `.gsd/255.1-*/**/test/sigra/templates/installer_drift_test.exs`). Never cite or copy from `.gsd/**`; use the `test/**` originals named here.

## Planner-critical findings (not in RESEARCH.md, found while mapping analogs)

These change how a plan should be written. Each was verified in the repo this session.

1. **`/admin/_design` does not exist in the `:test` env.** `dev_routes` is set only in `test/example/config/dev.exs:84`; `router.ex:187` gates the route with `Application.compile_env(:example, :dev_routes)`, and `config/test.exs` never sets it. RESEARCH BGEN-08 proposes an example `LiveViewTest` that "mounts `/admin/_design`": `live(conn, "/admin/_design")` will 404 in test. Use a pure render of `ExampleWeb.Admin.DesignGalleryLive.render/1` (the verified Pattern 3 spike in RESEARCH, and `render_component` precedent in `test/example/test/example_web/admin_shell_test.exs:108`). No example test references the gallery today (grep of `test/example/test` is empty), so the render must be spiked once before the plan commits to it. Playwright (dev server) remains the only runtime that reaches the route.
2. **The brand-mark light/dark swap is `opacity`, not `display`.** RESEARCH BGEN-04 says "in light the dark lockup is `display: none`". The real rules (`test/example/priv/static/assets/css/app.css:1826-1865`) stack both `<img>` absolutely and flip `opacity` 0/1 with `transition: opacity var(--sg-motion-fast)`. The generated-host assertion must use Playwright's auto-retrying `toHaveCSS('opacity', ...)`, never an immediate `getComputedStyle` read (transition makes an instant read flaky).
3. **Double-install "raw leg" must be computed on the installer delta, not the whole tracked tree.** `phx.new` writes a random `signing_salt` into `lib/<app>_web/endpoint.ex` (a `lib/` file, not normalized: the normalizer only rewrites salts under `config/`). The golden tree has no `endpoint.ex` because `normalize_tree/2` drops files byte-equal to the pre-install baseline. So "only migration filenames and config salts differ" is true only over the delta (paths whose hash differs from `baseline_paths`, as returned by `InstallFixture.setup_tmp_app/0`). Comparing `snapshot_paths/1` of the two apps directly would also show `endpoint.ex` and fail for a reason unrelated to the installer.
4. **The asset inventory has a seventh file the BGEN-01 table omits.** `find priv/templates/sigra.install -name '*.css' -o -name '*.svg' -o -name '*.js'` yields: `admin/admin_hooks.js`, `admin/sigra-logo-primary.svg`, `admin/sigra-logo-primary-dark.svg`, `admin/sigra_admin.css`, `core/sigra_auth.css`, `passkeys/passkey_browser.js`, `passkeys/passkey_hooks.js`, **`passkeys/app_js_passkeys_injection.js`**. The last is an injection snippet read by `lib/sigra/install/features/passkeys.ex:53` (`read_template!`), not a copied asset. The completeness check will trip on it unless the table classifies it (`:injected_snippet`, no example/golden counterpart). Exact counterpart paths: golden tracks `test/fixtures/install_golden/tree/priv/static/{assets/sigra_admin.css, assets/sigra_auth.css, images/sigra-logo-primary.svg, images/sigra-logo-primary-dark.svg}`; example holds the CSS at `test/example/priv/static/assets/`, the logos at `test/example/priv/static/images/`, and the JS at `test/example/assets/js/` (not under `priv/static`).
5. **`admin-css-conformance.test.sh` Test G fails on a dirty tracked tree.** It runs `git status --short` and fails on any non-untracked change outside `scripts/ci/` and `.planning/` (`admin-css-conformance.test.sh:242-252`). Wiring the `.test.sh` twin into `mix ci` makes `mix ci` red locally mid-L1 for a non-obvious reason (it is green on CI's clean checkout). Wire the two guard scripts themselves through the alias; wire the twin only if Test G is first scoped (or leave the twins as separately-run self-tests).
6. **Option A flag polarity decides whether a forgotten setter is loud or silent.** RESEARCH recommends default-off (`SIGRA_PNG_COMPARE=1` only on dispatch and in the recapture jobs). Callers of the PNG-compare specs that RESEARCH did not list: `scripts/ci/run-playwright-drift.sh:55,65`, `scripts/ci/snapshot-recapture-gate.sh:66,83` (the local compare-mode gate, which `phase_230_design_gallery_split_test.exs:181` says "must keep the full set"), the `cross_lane_compare` step in `admin_design_recapture` (compare mode for checkpoints and demo, ci.yml ~1908-1925) and `playwright-github-pages.yml:136-161`. Default-off silently turns all of them into false greens (the exact failure the repo's "negative results need positive controls" memory describes). Default-on-compare with an explicit skip switch set only on the three PR/push shard steps (`Run admin checkpoints` ci.yml:1330, `Run design gallery behavior and snapshots` :1367, `Run demo showcase` :1406) fails loud when a setter is forgotten and needs zero edits to the recapture jobs, the drift script, the gate script and the Pages workflow. Present both to the owner; recommend default-on with explicit skip.
7. **Option A and the ci-demotion observer.** `scripts/ci/ci-demotion-observer.sh` (line 87 floor `ASSERT_COUNT -lt 2`) and `.github/ci-skip-manifest.tsv` assert that `design_gallery_snapshots` is "observed executing" on non-PR runs. Under Option A the step still runs (its second command runs `--grep-invert '@snapshot'`), so the step-duration checks stay green while the `@snapshot` tests are skipped. That is a semantic gap, not a guard failure. The contract test (below) must pin the skip switch explicitly so the gap is documented in a place a machine reads.
8. **`RegenGuardTest` scans `test/sigra/brand/*.exs` and `test/support/brand/*.ex`** for `System.(get_env|fetch_env|fetch_env!)(` and fails on any file other than itself and `regen_guard.ex` (`test/sigra/brand/regen_guard_test.exs:106-128`). `catalog.ex` and `catalog_test.exs` must put every opt-in read behind `RegenGuard.requested?/3`; `System.cmd` is fine. The example-side catalog test lives outside that scan.
9. **Load/format scope facts for new files.** `mix.exs:27` `test_load_filters: [~r"^test/(?!example/|fixtures/)"]` means nothing under `test/fixtures/brand/before/` is ever loaded as a test; `elixirc_paths(:test)` is `["lib", "test/support"]` (mix.exs:55) so `test/support/brand/catalog.ex` compiles in the root test env. `.formatter.exs` covers `test/{sigra,support,mix}/**` and `test/example/{lib,config,test,priv}/**`, so every new `.ex/.exs` file is checked by the first step of `mix ci`.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/sigra/install/asset_parity_test.exs` (new) | test | transform (byte compare) | `test/sigra/install/features/admin_test.exs:396-407` (DIST-05) + `test/support/brand/copy_inventory.ex:78-82` (unknown type raises) | exact (compare) / role-match (table) |
| `test/sigra/install/double_install_test.exs` (new) | test | file-I/O (scaffold) | `test/sigra/install/idempotency_test.exs` + `test/sigra/install/golden_diff_test.exs` | exact |
| `mix.exs` `ci` / `ci.install_golden` aliases (modify) | config | batch | `mix.exs:149-163, 168` itself (`sigra.dep_off` `cmd bash` idiom) | exact |
| `test/support/brand/catalog.ex` (new) | utility (normalizer + guarded writer) | transform | `test/support/brand/copy_inventory.ex` + `test/support/brand/regen_guard.ex` + `normalize_text/2` in `test/example/test/example_web/enumeration_parity_test.exs:1351-1375` | role-match |
| `test/sigra/brand/catalog_test.exs` (new) | test | transform + file-I/O | `test/sigra/brand/source_pin_test.exs` (manifest + privacy + planted controls) | exact |
| `test/example/test/example_web/catalog_test.exs` (new) | test | request-response | `test/example/test/example_web/enumeration_parity_test.exs` (`@moduletag :example_app`, ConnCase, normalize) + `admin_shell_test.exs` (`render_component`) | role-match |
| `test/fixtures/brand/before/**` + `MANIFEST.json` (new) | fixture | file-I/O | `brand.sha256` pattern (`source_pin_test.exs:326-350`), `test/fixtures/brand/frozen-surface.json` (pretty JSON), `copy-inventory/generated.tsv` header convention | role-match |
| `.gitattributes` (modify) | config | n/a | existing line `brand/** -text linguist-vendored` | exact |
| `test/sigra/planning/phase_260_png_park_contract_test.exs` (new) | test (contract over ci.yml/specs) | request-response (string asserts) | `test/sigra/planning/phase_230_design_gallery_split_test.exs` | exact |
| `scripts/brand/catalog-diff.sh` (new) | utility script | batch | `scripts/ci/check-docs-index.sh` | role-match |
| `test/sigra/brand/catalog_diff_test.exs` (new) | test (shell wrapper) | batch | `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs:85-92` (`System.cmd("bash", ...)`) + `scripts/ci/check-docs-index.test.sh` (planted fixtures) | role-match |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` (modify) | test (browser) | request-response | itself, `:247-275` and `:111-126` | exact |
| `scripts/ci/admin-acceptance-smoke.sh` (modify, `--test catalog`) | utility script | request-response | itself, `case "${TEST_TARGET}"` block `:372-415` + curl probe `:296-312` | exact |
| `test/example/lib/example_web/live/admin/design_gallery_live.ex` (modify) | component (LiveView, static assigns) | transform | itself (board sections) | exact |
| `test/example/test/example_web/live/admin_design_gallery_catalog_test.exs` (new, name proposed) | test | transform | `components_test.exs:130-160` (`render_component`) + `admin_shell_test.exs:108` | role-match |
| `priv/templates/sigra.install/admin/sigra_admin.css` (modify, L1 + stamp) | config (shipped CSS) | n/a | source blocks in `test/example/priv/static/assets/css/app.css:1570-1648, 1807-1870, 1953-2010` | exact (source of moved rules) |
| `test/example/priv/static/assets/sigra_admin.css` (resync) | config | n/a | `cp` of template (DIST-05) | exact |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (rebless) | fixture | file-I/O | `mix sigra.fixture.rebless_golden` (only writer) | exact |
| `test/example/priv/static/assets/css/app.css` (delete moved blocks) | config | n/a | itself; guard `scripts/ci/app-css-corruption-check.sh` | exact |
| `test/example/priv/static/assets/sigra_auth.css` (refresh) | config | n/a | `cp` of `priv/templates/sigra.install/core/sigra_auth.css` | exact |
| `test/sigra/install/features/admin_test.exs` (modify D-11, DIST-05) | test | transform | itself `:396-428`, helpers `:495-562` | exact |
| `scripts/ci/admin-css-conformance.sh` + `.test.sh` (modify) | utility script + self-test | batch | itself `:84-130`, twin `:140-260` | exact |
| `scripts/ci/admin-token-completeness.sh` (wire only) | utility script | batch | `sigra.dep_off` alias entry | exact |
| `.github/workflows/ci.yml` (park PR) | config (CI) | event-driven | itself `:1330-1416`, recapture jobs `:1805-1822, 1905-1925, 2040-2070` | exact |
| `test/example/priv/playwright/tests/{admin-checkpoints,demo-showcase,admin-design}.spec.ts` (modify) | test (browser) | request-response | `assertCheckpointScreenshot` `:158-161`, `assertDemoScreenshot` `:143-155`, `assertBoardScreenshot` `:74-85` | exact |
| `scripts/ci/run-playwright-drift.sh`, `scripts/ci/snapshot-recapture-gate.sh` (check only) | utility script | batch | n/a (callers of the compare specs) | n/a |
| `.github/workflows/playwright-github-pages.yml` (decide) | config (CI) | event-driven | itself `:50, 134-161` | exact |
| `MAINTAINING.md` (modify, Tier-B prose) | docs | n/a | itself `:251-275` | exact |
| CSS version stamp test (new test inside `asset_parity_test.exs` or `admin_test.exs`) | test | transform | `admin_test.exs:396-407` | exact |
| shrink-only undefined-class baseline test (new; BGEN-04 recommendation) | test | transform | `test/sigra/brand/frozen_surface_test.exs:68-91, 213-233` (add-only ratchet; this one is shrink-only) | role-match |

## Pattern Assignments

### `test/sigra/install/asset_parity_test.exs` (test, byte compare)

**Analog 1:** `test/sigra/install/features/admin_test.exs:396-407` (the existing DIST-05 byte-parity, to generalize).

```elixir
describe "DIST-05 example≡template byte-parity (sigra_admin.css)" do
  test "example copy is byte-identical to the installer template" do
    template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
    example = File.read!("test/example/priv/static/assets/sigra_admin.css")

    assert byte_size(template) == byte_size(example),
           "size mismatch — resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"

    assert template == example,
           "content mismatch — example copy has diverged from the installer template; resync with: cp ..."
  end
end
```

Copy: the failure message always names the exact `cp` resync command. Do not use cwd-relative paths in the new file; use the repo-root idiom below.

**Repo root idiom** (`test/sigra/templates/installer_drift_test.exs:361-366`, reason documented there: `File.cwd!/0` breaks when `mix test` runs from a subdirectory):
```elixir
@repo_root Path.expand("../../..", __DIR__)
```
(For a file at `test/sigra/install/`, `Path.expand("../../..", __DIR__)` is the repo root, same depth as `golden_diff_test.exs`.)

**Analog 2 (completeness / "unknown type raises"):** `test/support/brand/copy_inventory.ex:78-82`:
```elixir
@elixir_template_exts [".ex", ".exs"]
@unextracted_template_exts [".css", ".svg", ".json", ".js"]
```
and the enumerate-everything walk at `copy_inventory.ex:133-143` (`Path.join(templates, "**/*") |> Path.wildcard() |> Enum.filter(&File.regular?/1)`). Copy the shape: wildcard every `.css/.svg/.js` under `priv/templates/sigra.install/**`, fail on any path not in the declared table. Classify `passkeys/app_js_passkeys_injection.js` as `:injected_snippet` (finding 4 above).

**Table shape to declare** (relation values from RESEARCH BGEN-01): `{template, example | nil, golden | nil, relation}` with `relation in [:byte_identical, {:documented_divergence, reason}, :injected_snippet]`. Expected initial state: `core/sigra_auth.css` is the intended first red (template 32,072 B vs example 13,867 B; verified `wc -c`). Documented divergence: `admin/admin_hooks.js`, `passkeys/passkey_browser.js`; the shrink-only guard for `admin_hooks.js` can reuse the marker-pair idea of `installer_drift_test.exs` (`@fixtures` with `must_have`).

**Positive control** (pure function unit-tested with a planted one-byte difference): copy `source_pin_test.exs:91-125`:
```elixir
test "reports exactly the changed path when one byte of one file is mutated" do
  contents = read_files(@root)
  path = "brand/brand.json"
  mutated = Map.update!(contents, path, &(&1 <> "x"))
  diff = diff_maps(hash_map(contents), hash_map(mutated))
  assert diff == [{:changed, path}]
end
```
Also copy the non-vacuity assertion style (`assert files != []`, `source_pin_test.exs:66-77`) so an empty glob cannot pass.

**CSS stamp assertion** (BGEN-04): add to this file or `admin_test.exs`; assert the first line of template, example and golden `sigra_admin.css` is the same `/* sigra-admin-css: N */`. The file is EEx-rendered but contains zero `<%` (verified `grep -c "<%"` = 0 for both CSS templates); keep it that way.

---

### `test/sigra/install/double_install_test.exs` (test, scaffold file-I/O)

**Analog:** `test/sigra/install/idempotency_test.exs` (module header and tags, lines 19-36) and `golden_diff_test.exs` (tags 34-44; tree diff helpers 149-229).

**Tags and setup** (`idempotency_test.exs:19-36`):
```elixir
use ExUnit.Case, async: false

alias Sigra.Test.InstallFixture

@moduletag :integration
@moduletag :idempotency
@moduletag timeout: 300_000
@moduletag :scaffold

setup_all do
  {:ok, %{app_dir: app_dir, stdout: first_stdout}} = InstallFixture.setup_tmp_app()
  on_exit(fn -> File.rm_rf!(Path.dirname(app_dir)) end)
  %{app_dir: app_dir, first_stdout: first_stdout}
end
```
Two fresh apps are required: call `InstallFixture.setup_tmp_app/0` twice (each uses its own `System.tmp_dir!()/sigra_golden_<unique_integer>` root, `install_fixture.ex:43-47`). Raise `timeout` above 300_000 (two phx.new + deps.get + compile + install runs; the golden test measured 27.9 s for `--check`, but two scaffolds are roughly double a single one).

**Return shape** (`install_fixture.ex:105-110`): `{:ok, %{app_dir:, stdout:, baseline_paths:}}`. Use `baseline_paths` for the delta (finding 3).

**Normalized leg**, copy the call shape from `golden_diff_test.exs:54-65`:
```elixir
actual = InstallFixture.normalize_tree(app_dir, baseline)   # drops baseline-identical files, TIMESTAMP-izes migrations, salts under config/
expected = ... # second app's normalize_tree
assert_tree_equal(actual, expected)
```
and stdout: `InstallFixture.normalize_stdout(raw, app_dir)` (`install_fixture.ex:434-451`) on each side.

**Raw leg** (confine the difference): use the public `InstallFixture.snapshot_paths(app_dir)` (`install_fixture.ex:305-317`, returns `%{rel_path => sha256}` over `lib`, `priv/repo/migrations`, `priv/static`, `config`, `test/support`) filtered to the delta `Map.get(baseline, rel) != hash`. Assert every differing path satisfies `String.starts_with?(rel, "priv/repo/migrations/") or String.starts_with?(rel, "config/")`. Do NOT compare unfiltered `snapshot_paths` (finding 3).

**Pure compare + planted control:** extract `compare_trees/2` as a private pure function and unit-test it with a planted one-byte change in a plain `test` that needs no scaffold (put it in a separate non-scaffold `describe` or a second file so the planted control runs under plain `mix test --exclude scaffold`). Reuse `assert_tree_equal/2` and `first_mismatch_offset/2` from `golden_diff_test.exs:149-215` verbatim (copy; both are private there).

**Wiring** (`mix.exs:161-163`): `ci.install_golden` is an explicit file list and `test --exclude scaffold` skips scaffold-tagged files, so a new scaffold test never runs unless listed:
```elixir
"ci.install_golden": [
  "test test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/vault_promotion_test.exs test/upgrade_test.exs"
],
```
Append `test/sigra/install/double_install_test.exs`, then prove it executes once with a deliberately failing assertion (RESEARCH Pitfall 8).

---

### `mix.exs` `ci` alias (modify, BGEN-05)

**Analog:** `mix.exs:149-157` (the alias) and `:168` (the `cmd bash` idiom):
```elixir
ci: [
  "format --check-formatted",
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "test --exclude scaffold",
  "ci.install_golden",
  "sigra.dep_off"
],
...
"sigra.dep_off": ["cmd bash scripts/ci/sigra-dep-off.sh"],
```
Add `"cmd bash scripts/ci/admin-css-conformance.sh"` and `"cmd bash scripts/ci/admin-token-completeness.sh"` to the `ci` list. A tiny ExUnit contract (the Wave 0 gap "grep of mix.exs alias") asserts both strings appear in `mix.exs`. See finding 5 before adding the `.test.sh` twins.

---

### `test/support/brand/catalog.ex` (utility: normalizer + guarded writer)

**Analog 1 (module shape, lane/path helpers, guarded writer):** `test/support/brand/copy_inventory.ex:1-50, 86-114`:
```elixir
alias Sigra.Test.Brand.RegenGuard

@root Path.expand("../../..", __DIR__)
@fixture_dir "test/fixtures/brand/copy-inventory"
@regen_env "SIGRA_BRAND_COPY"
@regen_command "SIGRA_BRAND_COPY=regen mix test test/sigra/brand/copy_inventory_test.exs"

@spec regenerate?(RegenGuard.env()) :: boolean()
def regenerate?(env \\ RegenGuard.environment()),
  do: RegenGuard.requested?(@regen_env, "regen", env)

@spec regen_command() :: String.t()
def regen_command, do: @regen_command
```
Copy: moduledoc states the lane, "Nothing here evaluates repo content", and the exact maintainer command. Use `@root Path.expand("../../..", __DIR__)` (file is at `test/support/brand/`).

**Analog 2 (the guard, never read env directly)** `test/support/brand/regen_guard.ex:47-62`:
```elixir
@spec requested?(String.t(), String.t(), env()) :: boolean()
def requested?(name, value, env \\ environment()) do
  cond do
    Map.get(env, name) != value -> false
    ci?(env) -> raise "#{name}=#{value} rewrites a committed brand fixture and is a local maintainer action. ..."
    true -> true
  end
end
```
Add a writer flag (suggested `SIGRA_BRAND_CATALOG=before|after`) only through `RegenGuard.requested?/3`. Update the `RegenGuard` moduledoc env-var list (it enumerates the writers) in the same change.

**Analog 3 (normalizer rule shape):** `test/example/test/example_web/enumeration_parity_test.exs:1351-1375`:
```elixir
defp normalize_text(text, email) when is_binary(text) do
  text
  |> replace_email(email)
  |> then(&Regex.replace(~r/(name="_?csrf[-_]token"[^>]*?(?:value|content)=")[^"]*"/, &1, "\\1{{CSRF}}\""))
  |> then(&Regex.replace(~r/(data-csrf=")[^"]*"/, &1, "\\1{{CSRF}}\""))
  |> then(&Regex.replace(~r/(\bid="phx-)[A-Za-z0-9_-]+"/, &1, "\\1{{REQUEST_ID}}\""))
  |> then(&Regex.replace(~r/(data-phx-(?:session|static)=")[^"]*"/, &1, "\\1{{REQUEST_ID}}\""))
  |> then(&Regex.replace(~r/(request[-_]id["']?\s*[:=]\s*["']?)[A-Za-z0-9_=-]{8,}/i, &1, "\\1{{REQUEST_ID}}"))
end
```
Extend with: relative text only (`just now|\d+[mhd] ago`; never absolute timestamps, RESEARCH Pitfall 5), `?vsn=` asset query, per-render ids like `mg-11-confirm-title-*`, user UUID -> persona label, and whitespace canonicalization. This module lives in `test/support/brand/` so it is compiled in the root test env but cannot reference `Example.*`; keep persona mapping in the example-side test.

**Analog 4 (pure LiveView render, RESEARCH Pattern 3 spike):**
```elixir
assigns = %{__changed__: nil, detail: detail, admin_scope: scope, current_scope: %{}, return_to: "/admin/users"}
html = Phoenix.LiveViewTest.rendered_to_string(Sigra.Admin.Live.UserShowLive.render(assigns))
```
Volatile spots confirmed there: `_csrf_token` hidden input and `relative_activity/1` (`lib/sigra/admin/components.ex:1206-1218`).

**Table of what lives where:** tier 0 = existing `test/fixtures/brand/copy-inventory/*.tsv` (do not rebuild; `CopyInventory` is the analog, not a dependency to extend); tier 1 = root-side pure renders of the eight `lib/sigra/admin/live/*_live.ex` modules; tier 2 = example-side (below); generated lane = generated host (smoke script target, below).

---

### `test/sigra/brand/catalog_test.exs` (test: determinism, normalizer, manifest hash, privacy)

**Analog:** `test/sigra/brand/source_pin_test.exs` (use it nearly 1:1 for the manifest, planted controls and privacy scan).

**Manifest re-hash / diff** (`source_pin_test.exs:319-363`):
```elixir
defp hash_map(contents), do: Map.new(contents, fn {path, bytes} -> {path, sha256_hex(bytes)} end)
defp sha256_hex(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

defp diff_maps(expected, actual) do
  added = for {path, _} <- actual, not is_map_key(expected, path), do: {:added, path}
  removed = for {path, _} <- expected, not is_map_key(actual, path), do: {:removed, path}
  changed = for {path, hex} <- actual, is_map_key(expected, path), expected[path] != hex, do: {:changed, path}
  Enum.sort(added ++ removed ++ changed)
end
```
Use `Path.wildcard(Path.join(@root, "test/fixtures/brand/before/**/*"), match_dot: true) |> Enum.filter(&File.regular?/1) |> Enum.reject(&(Path.basename(&1) == ".DS_Store"))` as `list_files/1` (`source_pin_test.exs:305-313`), and read `MANIFEST.json` with `JSON.decode!/1` (stdlib; `source_pin_test.exs:129`).

**Privacy scan** (reuse the rule set; do not weaken). Home-directory prefixes are built from fragments so the test file itself never contains one (`source_pin_test.exs:41-45`):
```elixir
@slash "/"
@users_dir @slash <> "Users" <> @slash
@home_dir @slash <> "home" <> @slash
```
and `text_kinds/1` (`:418-442`) with the email rule that rejects any domain not ending `.test`. Catalog HTML is text, so only the text rules apply; add `secret_key_base`, `signing_salt` and a CSRF-looking-token rule per RESEARCH Security Domain. Planted-failure controls: copy `source_pin_test.exs:169-200` (home path, Linux home path, non-test email) and the narrowness controls at `:254-300`.

**Write-once / refuse-to-overwrite for "before"** (`legacy_profiles_test.exs:38-48`):
```elixir
setup_all do
  if RegenGuard.requested?(@write_env, "write") and not File.exists?(@fixture_path) do
    File.mkdir_p!(Path.dirname(@fixture_path))
    File.write!(@fixture_path, pretty(...))
  end
  :ok
end
```
`setup_all` (not a `test`) keeps the write ordered ahead of async readers. Do not add a CI-resident test that equals the committed "before" to current sources (RESEARCH Pitfall 6: it goes red in Phase 261 by design). CI-resident tests are: determinism (render twice, equal), normalizer unit tests with planted volatile inputs, manifest integrity, privacy scan, non-vacuity.

**Non-vacuity idiom** (`frozen_surface_test.exs:224-232`):
```elixir
assert baseline_names!(category) != [], "baseline category #{category} is empty (vacuous green)"
assert extract(category) != [], "extractor for #{category} found nothing: its source path moved or the pattern drifted"
```

**Manifest serialization:** the stdlib `JSON.encode!/1` emits compact single-line JSON; copy the sorted-keys, one-element-per-line `pretty/1` recipe from `frozen_surface_test.exs:620-653` (also copied in `legacy_profiles_test.exs`) so a one-entry change is a one-line diff. Do not invent a third serializer: copy it.

**Moduledoc convention** (all brand tests): module `Sigra.Brand.<Name>Test`, `use ExUnit.Case, async: true`, a moduledoc that states what the test protects, how the writer is opt-in, and that red-ness is proven by in-memory controls only.

---

### `test/example/test/example_web/catalog_test.exs` (tier 2, request-response, Postgres)

**Analog:** `test/example/test/example_web/enumeration_parity_test.exs:74-80` for the case template and tag, `test/example/test/example/demo/seeds_test.exs:18-19, 40-56` for running `Example.Demo.Seeds.run/0` in the sandbox, `admin_shell_test.exs:95-135` for `render_component`.

```elixir
use ExampleWeb.ConnCase, async: false
@moduletag :example_app          # example suite excludes it by default; CI uses `mix test --include example_app`
```
`test/example/test/test_helper.exs` is `ExUnit.start(exclude: [:example_app])`; the example suite is run in `example_unit_smoke` as `mix test --include example_app` (ci.yml:775). Remember the example suite is NOT part of `mix ci` (RESEARCH Pitfall 9): run `cd test/example && MIX_ENV=test mix test --include example_app` explicitly.

Personas: `Example.Demo.Personas` (`all/0`, `email/1`, `by_key/1`, `@demo.tasklane.test` domain only; `lib/example/demo/personas.ex:29-56`). `Example.Demo.Seeds.run/0` seeds inside the sandbox. User ids are DB UUIDs and `inserted_at` is wall clock (RESEARCH), so map UUID -> persona label after seeding in the normalizer (do not normalize absolute timestamps; pin data to constants).

Scope reminder (finding 1 in RESEARCH, "the example is not the generated lane"): label every file written by this test with `lane: library-admin (example-mirror shell)` in the manifest. It does not baseline generated auth screens.

---

### `test/fixtures/brand/before/**` + `MANIFEST.json` + `.gitattributes` (fixtures)

**Analog (manifest in `shasum -a 256 -c` format, byte-sorted):** `source_pin_test.exs:326-331`:
```elixir
defp render_manifest(hashes) do
  hashes |> Enum.sort() |> Enum.map_join(fn {path, hex} -> "#{hex}  #{path}\n" end)
end
```
Regenerate-command convention (`source_pin_test.exs:34-35`): the manifest names its own regen command; keep `MANIFEST.json` for the pinned-SHA/coverage fields and put the per-file `sha256` inside it (RESEARCH BGEN-03 Manifest).

**TSV/coverage-statement convention** (header of `test/fixtures/brand/copy-inventory/generated.tsv`): a `WHY THIS FILE EXISTS` block and a `COVERAGE` block with `Covered:` / `Not covered:` lines, because "a clean inventory diff proves nothing about copy in a form that is not covered". Copy this into the manifest coverage statement (which generated screens are baselined by markup only vs by rendered HTML; the Light/Dark/System limit from RESEARCH "Theme dimension").

**`.gitattributes`** currently contains one line: `brand/** -text linguist-vendored`. Add `test/fixtures/brand/before/** -text` and extend the `.gitattributes` assertion (analog test: `source_pin_test.exs:79-88`, which reads the file, normalizes `\r\n`, splits on `\n`, and asserts the exact line is a member).

**Pin precondition** (RESEARCH Pattern 1): the capture command refuses unless `git diff --quiet origin/main -- lib priv` succeeds. Verified at mapping time: `git diff --stat origin/main...HEAD -- lib priv` is empty (origin/main = `4cf5829ea`).

---

### `test/sigra/planning/phase_260_png_park_contract_test.exs` (contract over `ci.yml` and specs)

**Analog:** `test/sigra/planning/phase_230_design_gallery_split_test.exs` (use as the template; no YAML/TS parser exists or should be added).

**Job-body extraction** (lines 27-50, copy verbatim):
```elixir
defp extract_job(content, job_id) do
  job_ids = ~r/^  ([a-z_]+):$/m |> Regex.scan(content, capture: :all_but_first) |> List.flatten()
  idx = Enum.find_index(job_ids, &(&1 == job_id))
  assert idx, "job `#{job_id}:` not found in #{@ci_path}"
  case Enum.at(job_ids, idx + 1) do
    nil -> [_, body] = Regex.run(~r/^  #{job_id}:$(.*)\z/ms, content); body
    next_id -> [_, body] = Regex.run(~r/^  #{job_id}:$(.*?)^  #{next_id}:$/ms, content); body
  end
end
```

**Recapture-job guard** (lines 150-164) is the model for "the recapture jobs and gate script still compare": assert `admin_design_recapture` still contains `--update-snapshots` and no `--grep`; extend with the compare-switch assertion that matches the chosen polarity (finding 6). Also assert the step with `id: design_gallery_snapshots` keeps `github.event_name != 'pull_request'` and the PR step keeps `--grep-invert '@snapshot'` (lines 187-218) so Option A does not collide with the phase 230 test.

**Aggregator guard** (lines 220-232): leave untouched; Option A changes no `if:` and no matrix entry, so `@aggregated_seam_ids` and the `example_playwright_smoke` `needs.example_playwright_shard.result` / `if: always()` assertions still hold.

**Constraints:** the regex at line 194 `~r/name: Run design gallery behavior\n(.*?)run: \|(.*?)- name:/s` captures everything between `name:` and `run: |` as `gallery_meta`; adding an `env:` line there is safe. Do not rename any step or job (`ci-skip-manifest.tsv` pins `id` + `display_name` adjacency; five required job names are ruleset contexts).

Add one assertion per canary rule: `scripts/ci/snapshot-canary-guard.sh` remains referenced from `fast_checks` (the impersonation-banner canary is never allowlisted).

**Also run unmodified, as regression detectors for the park PR:** `node --test scripts/ci/prohibitions/*.test.mjs` (p02 axe-not-reduced, p03 no-green-on-empty-grep, p10 undocumented-demotion, p13 no-lane-green-because-skipped, p17 no-retry-wrapper), `bash scripts/ci/ci-demotion-observer.test.sh`, and `mix test test/sigra/planning/phase_230_design_gallery_split_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` (the latter validates `spec-ownership.json` events `["pull_request","push"]` for checkpoint/demo specs; Option A leaves them valid).

---

### `scripts/brand/catalog-diff.sh` and `test/sigra/brand/catalog_diff_test.exs` (BGEN-07)

**Script analog:** `scripts/ci/check-docs-index.sh:1-60`:
```bash
#!/usr/bin/env bash
set -euo pipefail
usage() { cat <<'EOF'
Usage: check-docs-index.sh [--tracked-path PATH] [--generated-file PATH]
...
EOF
}
fail() { echo "check-docs-index: FAIL: $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracked-path) [[ $# -ge 2 ]] || fail "--tracked-path requires a path"; TRACKED_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done
INDEXED_FILE="$(mktemp)"
trap 'rm -f "$INDEXED_FILE"' EXIT
```
Copy: `set -euo pipefail`, a `fail()` that prefixes the tool name, `usage`, explicit arg validation, `mktemp` + `trap`. For the diff, `diff -ru` (BSD and GNU); do not use `--strip-trailing-cr`. Exit 0 with "no differences" when identical, non-zero and a changed/added/removed summary otherwise.

**BSD-safe idiom** (copy from `scripts/ci/check-docs-index.test.sh:66-68`): `sed -i.bak '...' file; rm -f file.bak`. Never `wc -l | grep -qx "0"` (BSD `wc` pads with spaces; use `test -z "$(...)"` or `[ "$n" -eq 0 ]`). `shasum -a 256`, not `sha256sum`.

**Test wrapper analog:** `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs:85-92`:
```elixir
{banner, 0} = System.cmd("bash", [@verifier, "--semantic-fixture", path], stderr_to_stdout: true)
assert banner =~ "source_complete_semantic_fixture_verified"
...
{output, status} = System.cmd("bash", [@verifier | arguments], stderr_to_stdout: true)
assert status != 0
assert output =~ diagnostic
```
Plant before/after temp dirs under `System.tmp_dir!()` (identical dirs: exit 0 and "no differences"; one changed line: reported; one removed file: reported). Resolve the script path from `Path.expand("../../../scripts/brand/catalog-diff.sh", __DIR__)`, not cwd. This runs under `mix ci` with no `ci.yml` edit.

**`.test.sh` twin** (optional; only if a bash-level self-test is wanted): `scripts/ci/check-docs-index.test.sh:1-32` (`mktemp -d` + `trap`, `PASS_COUNT`/`FAIL_COUNT` helpers, numbered planted cases) or `scripts/ci/admin-css-conformance.test.sh:1-40, 140-170` (hermetic, `set +e` / capture `$?` / `set -e` around the call under test). Do not add a `git status` side-effect test like Test G (finding 5).

---

### `test/example/priv/playwright/tests/admin-generated.spec.ts` (generated-host L1 proof)

**Analog:** the same file. Put the new assertions inside the existing test titled exactly `generated host admin shell renders on desktop and mobile` (line 247): `scripts/ci/admin-acceptance-smoke.sh` selects the `chrome` target with `-g "generated host admin shell renders on desktop and mobile"` (smoke script `:377-379`), and `--test all` runs the whole file, so both are covered without touching the harness or `spec-ownership.json`.

**Existing token proof to extend** (`admin-generated.spec.ts:262-274`):
```ts
const brandColor = await page.evaluate(
  () => getComputedStyle(document.documentElement).getPropertyValue("--sg-color-brand").trim(),
);
expect(brandColor).toBe("#c2410c");
```
**Theme switching pattern to copy** (`:111-126`, existing auth theme test): set the attribute and read computed values.
```ts
await authRoot.evaluate((element, value) => { element.setAttribute("data-theme", value); }, theme);
```
**Auto-retrying CSS assertion to copy** (`:98`): `await expect(alternativesSummary).not.toHaveCSS("box-shadow", "none");`

New assertions (Playwright, computed style, no PNG): after load, `await expect(page.locator('.sg-brand-mark__image--dark')).toHaveCSS('opacity', '0')` and the light image `'1'` (light), then `page.evaluate(() => document.documentElement.setAttribute('data-sg-admin-theme','dark'))` and flip, plus `--sg-color-panel` changes between `data-sg-admin-theme="light"` and `"dark"` (the shell's inline script sets exactly this attribute, `admin_shell.ex:30-39`). Use `toHaveCSS` (retries), never an immediate `getComputedStyle` (finding 2). Selectors confirmed in `priv/templates/sigra.install/admin/components/admin_shell.ex:50-71` (`.sg-brand-mark`, `.sg-brand-mark__image--light/--dark`) and `:79-108` (`.sg-theme-switch__button[data-theme-value]`).

Run locally with: `GITHUB_WORKSPACE=$(pwd) PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test chrome`. Also first prove the assertions go red against the current (pre-L1) template (RESEARCH A1 asks for a before/after look in a real generated host).

---

### `scripts/ci/admin-acceptance-smoke.sh` (modify: add `--test catalog`, optional)

**Analog:** itself. Add a target to the `case` block (`:372-415`):
```bash
case "${TEST_TARGET}" in
  all) PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}"); RUN_CONFIRMATION=true ;;
  chrome) PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}" "-g" "generated host admin shell renders on desktop and mobile") ;;
  ...
  *) echo "unknown --test target: ${TEST_TARGET}" >&2; exit 1 ;;
esac
```
and reuse the boot-then-`curl` shape (`:271-291`, `:296-312`): `curl -sf "http://localhost:${PORT}/"` readiness loop; `curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 5`. The script is monolithic (not sourceable functions, RESEARCH BGEN-03): a `catalog` target must write page bodies to a temp dir (`${TMP_APP_DIR}` is `/tmp/sigra_admin_smoke`, outside the repo) via `curl -s`, then the normalizer runs from the repo-side test, not from bash. Anonymous pages: `/users/log_in`, register, reset, magic link, confirmation resend. Emails: `mix run -e` in the host calling the generated builders in `priv/templates/sigra.install/core/emails.ex` (`confirmation_email/3`, `reset_password_email/2`, `magic_link_email/2`, `suspicious_login_email/2`).

`phase_234_playwright_inventory_contract_test.exs` maps `admin-generated.spec.ts` to the marker `scripts/ci/admin-acceptance-smoke.sh --test all`; a new `catalog` target changes nothing there. Process budget: if the owner declines, fall back to golden tree + inventory for authenticated generated screens and state it in the manifest (RESEARCH A7/G-B).

---

### `test/example/lib/example_web/live/admin/design_gallery_live.ex` (BGEN-08)

**Analog:** itself. Add a new top-level `<section>` before the autofix-seed fixture (line ~1448) following the existing section shape:
```heex
<section class="sg-stack sg-stack--4">
  <h2 class="sg-section-heading">Catalog states</h2>
  <div class="sg-stack sg-stack--6">
    <div id="catalog-auth-login" class="sg-card sg-stack sg-stack--4"> ... </div>
```
Use ids prefixed `catalog-` so they are not in `COMPONENT_BOARDS`/`GROUP_BOARDS`/`CONFIG_BOARDS`; `phase_230_design_gallery_split_test.exs:110-148` pins 13 + 11 + 4 = 28 `board-*` entries and `:52-62` pins the board loop source shape, so no registry or baseline moves. Static literal assigns only, per the moduledoc ("no DB queries"). Draw status states with the existing `sg-status-pill` (not a new `status_mark`; "Components markup must not change"). Suspended appears in the catalog section only (ADR 005 decision 6).

**Isolation:** nothing under `priv/templates/sigra.install/` may contain the substring `design` (`test/sigra/install/design_gallery_isolation_test.exs:26-31`); the gallery is example-only so no template file is added.

**Test:** no route exists in `:test` (finding 1). Render the LiveView function directly, the same way `components_test.exs` renders components:
```elixir
import Phoenix.LiveViewTest

html = rendered_to_string(ExampleWeb.Admin.DesignGalleryLive.render(%{__changed__: nil}))
assert html =~ ~s(id="catalog-auth-login")
assert html =~ "Suspended"
```
(`render_component` precedent: `components_test.exs:130-160`, `admin_shell_test.exs:108` with literal assigns and `@endpoint nil` / `use ExampleWeb.ConnCase`.) Spike this first; if the `~H` template needs assigns beyond `__changed__`, supply them as literals. The page-wide axe test (untagged, `admin-design.spec.ts:268-269`) covers the new section for free in the dev-server Playwright run.

---

### `priv/templates/sigra.install/admin/sigra_admin.css` (modify: L1 + stamp), with example copy and golden

**Source blocks to move** (analog is the example `app.css`; verified line numbers):

| Block | `test/example/priv/static/assets/css/app.css` |
|---|---|
| Explicit light token block | `:1570-~1608` (`.sg-admin-shell[data-theme="light"],\nhtml[data-sg-admin-theme="light"] .sg-admin-shell {`) |
| Explicit dark token block | `:1609-~1648` (`.sg-admin-shell[data-theme="dark"],\nhtml[data-sg-admin-theme="dark"] .sg-admin-shell {`) |
| Brand mark | `:1807-1870` (`.sg-brand-mark`, `__lockup`, `__image`, `--light/--dark` opacity rules, `@media (prefers-color-scheme: dark)` pair, `__section`) |
| Theme switch | `:1953-2010` (`.sg-theme-switch`, `__button`, preference-attribute rules) |

The brand-mark mechanism being moved (excerpt `:1826-1865`):
```css
.sg-brand-mark__image { position: absolute; inset: 0; ... opacity: 0; transition: opacity var(--sg-motion-fast) var(--sg-ease); }
.sg-brand-mark__image--light { opacity: 1; }
.sg-admin-shell[data-theme="dark"] .sg-brand-mark__image--light,
html[data-sg-admin-theme="dark"] .sg-brand-mark__image--light { opacity: 0; }
...
@media (prefers-color-scheme: dark) {
  html:not([data-sg-admin-theme]) .sg-admin-shell:not([data-theme]) .sg-brand-mark__image--light { opacity: 0; }
  ...
}
```

**Layering caveat (RESEARCH Pitfall 7):** `sigra_admin.css` declares `@layer sg-base, sg-components, sg-overrides;` (line 15) while `app.css` rules are unlayered and win. Place the moved rules in the appropriate layer and re-check the example render; deleting them from `app.css` changes precedence in the example.

**D-11 selector trap:** `admin_test.exs:495-545` `extract_css_block/2` matches the FIRST occurrence of the literal selector substring `html[data-sg-admin-theme="dark"] .sg-admin-shell`. In the shipped file the explicit dark token block must be the first occurrence of that substring, and no earlier rule may contain it. The brand-mark rules use `html[data-sg-admin-theme="dark"] .sg-brand-mark__image--light`, which does not contain `.sg-admin-shell`, so they are safe.

**Stamp:** first-line `/* sigra-admin-css: N */` (integer contract level, no `<%`). The CSS currently begins `/* Vaultr/Sigra demo design layer.` (comment block, lines 1-~14); place the stamp line above it.

**Resync commands (both named in `admin_test.exs:402`):**
`cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css` then rebless the golden once:
`MIX_ENV=test mix sigra.fixture.rebless_golden` (writer), verify with `--check` (RESEARCH: ran clean, 27.9 s). Review the diff per directory; the mechanical change goes in a separate commit.

**Unaddressed gap baseline (BGEN-04 recommendation):** a shrink-only test computing classes used by `lib/sigra/admin/**` and `priv/templates/sigra.install/admin/**` markup but undefined in shipped CSS (RESEARCH measured 59 missing, 56 defined only in example `app.css`, 3 defined nowhere). Closest analog for the extraction helpers: `frozen_surface_test.exs:405-421`:
```elixir
defp css_selectors(css, prefix), do: capture_all(css, ~r/\.(#{Regex.escape(prefix)}[A-Za-z0-9_-]*)/)
defp markup_classes(text, prefix) do
  token = ~r/(?<![A-Za-z0-9_-])#{Regex.escape(prefix)}[A-Za-z0-9_-]*/
  ~r/class=(?:"([^"]*)"|\{(.*?)\})/s
  |> Regex.scan(text) |> Enum.flat_map(fn [_whole | groups] -> groups end)
  |> Enum.flat_map(&Regex.scan(token, &1)) |> Enum.map(&hd/1)
  |> Enum.reject(&String.ends_with?(&1, "-"))
end
```
(roots `@admin_markup_roots` at `:39`). Direction is inverted from the frozen-surface ratchet (that one is add-only over names; this one must fail when the undefined set GROWS). Reuse the extraction, write the comparator the other way. The `css_classes_sg` frozen-surface category is add-only and passes on additions without running its extend writer (`frozen_surface_test.exs:8-13`).

---

### `test/sigra/install/features/admin_test.exs` (modify: D-11 and DIST-05)

**Edit sites:** `:409-428` D-11 (`extract_explicit_dark_props` currently reads `app.css`); point it at the shipped file and add the light twin using the existing `extract_css_block/2` and `extract_sg_declarations/1` helpers (`:495-562`). `:396-407` DIST-05 can stay or move into `asset_parity_test.exs`; if it stays, the example resync is mandatory after the template edit. The pinned value that must remain true until Phase 261: `assert "--sg-color-brand-strong: #fdba74;" in admin_dark_props` (`:425`).

---

### `scripts/ci/admin-css-conformance.sh` + `.test.sh` (extend for explicit-theme scope, BGEN-05)

**Analog:** the script itself. The protected-scope detector (CHECK 2 awk, `:84-130`; also repeated for CHECK 3 `:207`):
```awk
if (line ~ /:root[[:space:]]*\{/) {
  in_root = 1
  root_entry_depth = brace_depth + 1
  ...
```
Extend the condition so a selector matching `html[data-sg-admin-theme="..."]` or `.sg-admin-shell[data-theme="..."]` whose body is only `--sg-*` declarations plus `color-scheme` is also a protected scope. The theme-switch active rule currently has a raw `background: #fdba74; color: #151515;` (RESEARCH, verified by running the guard); replace those hexes with tokens during L1. Because both CHECK 2 and CHECK 3 use a copy-pasted awk block, edit both and keep them in step.

**Self-test analog** (`admin-css-conformance.test.sh:40-90, 140-170`): add fixtures via `cat > "$FILE" <<'CSS' ... CSS` heredocs and the Test-C-style planted-failure case:
```bash
RAW_HEX_CSS="${TMPDIR_ROOT}/raw-hex.css"
cat > "$RAW_HEX_CSS" <<'CSS'
:root { --sg-color-x: #abc; }
.foo { color: #fff; }
CSS
set +e; bash "$REAL_GUARD" "$RAW_HEX_CSS" >"$STDOUT_C" 2>"$STDERR_C"; EXIT_C=$?; set -e
[[ "$EXIT_C" -ne 0 ]] && pass "..." || fail "..."
```
Add: (a) explicit-theme blocks with hex inside them exit 0, (b) a raw hex in a normal rule next to an explicit-theme block exits non-zero (planted control), (c) an explicit-theme block containing a non-`--sg-*` declaration with a hex exits non-zero. Heredoc use is fine in shell tests (only the Write-tool rule for agent file creation forbids heredocs; this is test content).

**Token-completeness** (`admin-token-completeness.sh`): no change expected; it passed (100 tokens) and its twin (8/0). Wire only.

---

### `.github/workflows/ci.yml` (park PR), specs, MAINTAINING.md

**Analog:** the shard steps. Verbatim current shape of one PNG-comparing step (`ci.yml:1330-1342`):
```yaml
- name: Run admin checkpoints
  if: ${{ !cancelled() && needs.changes.outputs.docs_only != 'true' && matrix.seam == 'admin_checkpoints' }}
  working-directory: test/example/priv/playwright
  env:
    CI: "true"
    SIGRA_EXAMPLE_URL: ${{ matrix.base_url }}
  run: |
    npx playwright test \
      tests/admin-checkpoints.spec.ts \
      --project=admin-checkpoints-chromium \
      --project=admin-checkpoints-mobile \
      --project=admin-checkpoints-dark \
      --retries=0
```
Edit sites (Option A, no `if:` change): the `env:` map of `Run admin checkpoints` (:1330), `Run design gallery behavior and snapshots` (:1367, event-gated to `!= 'pull_request'`), `Run demo showcase` (:1406). Expression stays in `env:`, never inside `run:` (house ASVS V5 rule; RESEARCH Code Examples):
```yaml
env:
  SIGRA_PNG_COMPARE: ${{ github.event_name == 'workflow_dispatch' && '1' || '0' }}
```
Decide polarity per finding 6. Under default-on, the three shard steps set a skip value on non-dispatch events and the four recapture steps need no edit. Under default-off, the setters needed are: `Recapture admin-checkpoint baselines` (~:2052-2060), `Recapture demo-showcase baselines` (~:2062-2070), the design recapture run (~:1810-1817), the `cross_lane_compare` compare step (~:1908-1925), plus `scripts/ci/snapshot-recapture-gate.sh:66,83` and `scripts/ci/run-playwright-drift.sh:55,65`. Do not add `permissions:` or change recapture jobs' `contents: write`.

**Spec edit sites (gate the compare call only, axe and behavior stay):**
- `admin-checkpoints.spec.ts:158-161` (`assertCheckpointScreenshot`): keep `await assertNoAxeViolations(page, \`axe:${slug}\`);` (line 132 region is the axe helper), guard only `await expect(page).toHaveScreenshot(...)`.
- `demo-showcase.spec.ts:143-155` (`assertDemoScreenshot`): guard only the `toHaveScreenshot` call; its three non-PNG tests (lines 198, 303, 843) are untouched.
- `admin-design.spec.ts:255` loop (`test(\`board: ${boardId}\`, { tag: '@snapshot' }, ...)`): add `test.skip(!compare, reason)` inside the callback so Playwright reports skipped, not silently green. Keep the loop source shape that `phase_230_design_gallery_split_test.exs:56` regex-pins (`for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS]) {\n test(\`board: ${boardId}\`, { tag: '@snapshot' }, async`). The pinned regex ends at `async`, so changing only the callback body is safe.
- `p17-no-playwright-retry-wrapper` forbids `retries` above 0, `waitForTimeout(`, `test.slow(` in the config and specs; `test.skip` is allowed. `p02` pins the axe test (do not tag it `@snapshot`).

**`playwright-github-pages.yml`:** top-level `env:` at `:50` (`SIGRA_EXAMPLE_URL: 'http://localhost:4000'`, `SIGRA_PLAYWRIGHT_PAGES_PUBLISH: '1'`) is the one place to set the switch for this workflow if default-on polarity is chosen and the owner wants it off there (RESEARCH Open Question 4); under default-off no edit is needed.

**MAINTAINING.md** (`:251-275`): Tier-B prose. Add one paragraph for the compare switch; the existing prose is already stale (`design_gallery_snapshots` described as "inside `example_playwright_smoke`", display name "Run design gallery board snapshots (non-PR)" vs ci.yml's "Run design gallery behavior and snapshots"). The manifest pins ci.yml's real `display_name`, so do not "fix" the ci.yml name to match the prose.

**Authoring order:** independent branch off `main` (RESEARCH BGEN-06 ordering): the park PR changes no shipped byte. Merge needs explicit owner approval and happens before Phase 261.

---

## Shared Patterns

### Opt-in writers go through `RegenGuard`
**Source:** `test/support/brand/regen_guard.ex:47-62`; consumers `copy_inventory.ex:105-106`, `frozen_surface_test.exs:63-66`, `legacy_profiles_test.exs:38-48`.
**Apply to:** `catalog.ex`, `catalog_test.exs`, any new writer (before-catalog capture). Enforced by `regen_guard_test.exs:106-128`; extend its env-var list in the `RegenGuard` moduledoc.
```elixir
setup_all do
  if RegenGuard.requested?(@write_env, "write") and not File.exists?(@fixture_path), do: write!()
  :ok
end
```

### Every guard is proven red once (planted control)
**Source:** `source_pin_test.exs:91-125, 169-200, 254-300`; `frozen_surface_test.exs:68-91`; `admin-css-conformance.test.sh` Tests B/C; `regen_guard_test.exs:130-133` ("positive control: the pattern does match a direct read").
**Apply to:** parity table (planted byte), double-install compare (planted byte), catalog normalizer (planted csrf/uuid/relative time), privacy scan (planted home path, non-`.test` email), conformance guard (planted hex), compare switch (a run where the switch is on and a perturbed expectation fails), `ci.install_golden` listing (deliberately failing assertion once), `catalog-diff.sh` (planted change/removal). Never trust "no output".

### Privacy: no personal data in a public repo
**Source:** `source_pin_test.exs:41-45` (fragment-built home prefixes) and `:418-442` (rules; emails must end `.test`).
**Apply to:** every fixture and test written this phase; catalog data uses only seeded `@demo.tasklane.test` addresses (`Example.Demo.Personas`) and generated-host `*.example.test` addresses already used by the smoke script. No names, no home paths, no authoring origin in committed text or PR text; provenance string is "brand book v2.0 (2026-11-13)".

### Repo-root resolution from `__DIR__`, never cwd
**Source:** `installer_drift_test.exs:361-366`, `source_pin_test.exs:29`, `copy_inventory.ex:48`.
**Apply to:** all new `.exs`/`.ex`. Note `design_gallery_isolation_test.exs:17` and `admin_test.exs:398` use cwd-relative paths (works from the repo root only); prefer the `__DIR__` form in new files.

### Scaffold test tagging and the explicit CI list
**Source:** `idempotency_test.exs:23-26`, `golden_diff_test.exs:38-40`, `mix.exs:149-163`.
**Apply to:** `double_install_test.exs` (`@moduletag :scaffold`, long `timeout`, add to `ci.install_golden`). `mix ci` runs `test --exclude scaffold` then `ci.install_golden`, so a scaffold file not on the explicit list never runs.

### Golden fixture writing
**Source:** `lib/mix/tasks/sigra.fixture.rebless_golden.ex` (single writer, `--check` drift detector), run under the pinned `phx_new 1.8.8` archive (`mix archive.install --force hex phx_new 1.8.8`). One rebless per phase, reviewed per directory, mechanical changes in a separate commit. Never hand-edit `test/fixtures/install_golden/**`.

### CI string-contract tests
**Source:** `phase_230_design_gallery_split_test.exs` (`extract_job/2`, regex over raw `ci.yml`), `phase_232_playwright_economics_test.exs` (reads config/spec/workflow as strings).
**Apply to:** `phase_260_png_park_contract_test.exs`. No YAML or TS parser is added.

### BSD/zsh-safe shell on darwin
**Source:** `scripts/ci/check-docs-index.test.sh:66-68` (`sed -i.bak ...; rm -f ...bak`), project memory on `wc -l | grep -qx "0"`.
**Apply to:** `catalog-diff.sh`, any `.test.sh`, the `--test catalog` target: quote globs, `shasum -a 256`, `test -z "$(...)"` instead of padded-`wc` compares, no GNU-only flags, keep any `.mjs` to features valid on Node 20 (CI) as well as the local Node 26.

### `mix ci` is not the whole gate
**Source:** RESEARCH Pitfall 9, `mix.exs:149-157`, ci.yml:775 (`example_unit_smoke` runs `mix test --include example_app`).
**Apply to:** the verification step of every plan: `source tmp/db.env && MIX_ENV=test mix ci`, then `cd test/example && MIX_ENV=test mix test --include example_app`, then `MIX_ENV=test mix sigra.fixture.rebless_golden --check`. New test/support files must be formatted.

## No Analog Found

Files with only a partial/role-match analog (planner should lean on RESEARCH.md where noted):

| File | Role | Data Flow | Reason |
|---|---|---|---|
| Generated-host catalog capture (`--test catalog` target and the host-side email dump) | utility script | request-response | The smoke script boots a generated host and `curl`s status codes only; no existing script persists rendered bodies or emails. The scaffold/boot/curl blocks are copyable, but the persistence and email `mix run -e` step are new. RESEARCH BGEN-03 and Open Question 1 give the design. |
| Shrink-only undefined-CSS-class baseline test | test | transform | Closest is the add-only `frozen_surface_test.exs` ratchet; its extractors are reusable, but its comparator direction (baseline SUBSET-OF current) is the opposite of what this test needs (current undefined set must not grow). No existing shrink-only ratchet. |
| Pure render of the library admin LiveViews into catalog HTML (tier 1) | utility | transform | `components_test.exs` renders function components, not whole LiveView `render/1`. The only precedent is the RESEARCH spike (executed once, not committed). |

## Metadata

**Analog search scope:** `test/sigra/brand`, `test/support/brand`, `test/sigra/install` (+ `features`), `test/sigra/templates`, `test/sigra/planning`, `test/sigra/admin`, `test/example/test`, `test/example/lib/example_web/live/admin`, `test/example/priv/playwright` (specs, spec-ownership, config), `scripts/ci`, `scripts/brand`, `.github/workflows/ci.yml`, `.github/ci-skip-manifest.tsv`, `mix.exs`, `.formatter.exs`, `.gitattributes`, `priv/templates/sigra.install`.
**Files scanned:** ~45 read in part or whole; all named analog paths verified tracked via `git ls-files`.
**Pattern extraction date:** 2026-11-15
