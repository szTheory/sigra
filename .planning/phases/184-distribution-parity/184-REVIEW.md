---
phase: 184-distribution-parity
reviewed: 2026-06-14T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/sigra/install/features/admin.ex
  - priv/templates/sigra.install/admin/layouts_admin_injection.ex
  - priv/templates/sigra.install/admin/sigra_admin.css
  - test/sigra/install/features/admin_test.exs
  - test/example/priv/playwright/tests/admin-generated.spec.ts
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 184: Code Review Report

**Reviewed:** 2026-06-14
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 184 extracts the canonical admin `sg-*` design system into an installer
template (`sigra_admin.css`), wires it through the install pipeline (`admin.ex`
`files/1`) and the generated admin layout (`layouts_admin_injection.ex`), and
adds a merge-blocking Playwright styled assertion (DIST-06).

The core wiring is **correct and well-tested**. I verified the full
ship-and-link chain end to end:

- `files/1` ships the CSS to `priv/static/assets/sigra_admin.css`; the layout
  injection links `~p"/assets/sigra_admin.css"` with `phx-track-static`. Paths
  match.
- `assets` is in `ExampleWeb.static_paths/0` and the endpoint `Plug.Static`
  `:only` list, so `/assets/sigra_admin.css` is actually served.
- The pattern is identical to the already-shipping `sigra_auth.css`
  (`priv/static/assets/` + `~p"/assets/sigra_auth.css"` + `phx-track-static`),
  so the precedent is proven.
- The golden fixture lands the `<link>` correctly
  (`test/fixtures/install_golden/tree/.../layouts.ex:102`).

The DIST-06 Playwright assertion is **robust**: I confirmed `--sg-color-brand`
(the base token, value `#c2410c`) is defined ONLY in `sigra_admin.css` at
`:root` — it appears in neither `default.css` nor `app.css` (app.css defines
`--sg-color-brand-soft/-strong/...` but never the base token, and *uses*
`var(--sg-color-brand)` 15 times, so it depends on the admin CSS supplying it).
The base token is not overridden by the dark-mode `@media` block, so the exact
`#c2410c` assertion holds across light/dark. The comment on the assertion is
accurate.

The DIST-05 example≡template byte-parity test correctly fails on any drift
(size + content assertions with actionable resync messages).

Findings below are robustness/maintainability concerns, not correctness bugs in
the shipped behavior.

## Warnings

### WR-01: Hand-authored CSS is run through `EEx.eval_file` — a future `<%` literal would crash or corrupt install

**File:** `lib/sigra/install/features/admin.ex:42-43` (consumed by `lib/sigra/install/runner.ex:81`)
**Issue:** The installer only supports one file mode, `:eex`, and the runner
unconditionally calls `EEx.eval_file(template_path, binding)` on every entry —
including the new `sigra_admin.css`. CSS is a static asset with no template
substitutions, but it is now passed through the EEx compiler. The current file
happens to contain no `<%`/`<%=`/`<%%` sequences (verified by grep), so it is an
inert pass-through today. However, this is a large, frequently-edited,
hand-authored stylesheet. The moment anyone introduces an EEx-significant
sequence — e.g. a CSS comment, a generated-content rule, or a copy-pasted
snippet containing `<%` — `mix sigra.install` will either raise a compile error
or silently corrupt the generated CSS. Nothing in the test suite guards against
this: the DIST-05 parity test compares the *template* bytes to the *example*
bytes (both pre-EEx), so it would not catch EEx mangling at install time, and no
test asserts the CSS template is free of EEx tokens.

This same fragility applies to the two `.svg` entries, but a hand-tuned logo SVG
is far less likely to acquire a `<%` than a living design-system stylesheet, so
the new CSS materially raises the exposure.

**Fix:** Preferred — add a `:text`/`:copy` file mode to the runner for static
assets and use it for `.css`/`.svg`:
```elixir
# runner.ex
defp render_file({:text, source, target}, r, _binding) do
  # copy verbatim, no EEx
end
defp render_file({:eex, source, target}, r, binding) do
  content = EEx.eval_file(find_template(source), binding)
  ...
end
```
and in `admin.ex`:
```elixir
{:text, "admin/sigra_admin.css",
 Path.join(["priv", "static", "assets", "sigra_admin.css"])}
```
Lighter-weight alternative if the file-mode refactor is out of phase scope — add
a guard test so drift fails loudly rather than at a user's install:
```elixir
test "sigra_admin.css contains no EEx-significant sequences (rendered via EEx.eval_file)" do
  source = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
  refute source =~ "<%", "CSS template must stay EEx-inert; it is rendered through EEx.eval_file/2"
end
```

### WR-02: DIST-05 parity test pins example↔template but leaves the golden-fixture CSS copy un-pinned to the template

**File:** `test/sigra/install/features/admin_test.exs:317-328`
**Issue:** The phase description states the design system is checked in as
"byte-identical example + golden-fixture copies (enforced by parity tests)." The
DIST-05 test enforces `template == test/example/.../sigra_admin.css` only. The
golden-fixture copy (`test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`)
is verified by `golden_diff_test.exs`, but that path applies
`InstallFixture.normalize_content_for_golden/2` to every file before comparison
(`golden_diff_test.exs:143,172-184`). If that normalizer ever touches CSS bytes
(e.g. trailing-newline or whitespace normalization), the golden fixture is NOT a
byte-exact guarantee of the template, and there is no direct
`template == golden_fixture` byte assertion to backstop it. The result is a
two-way pin (template↔example) plus a normalized pin (template↔golden via the
generator), with no transitive byte guarantee that example == golden. A drift
that is normalized away in golden_diff but real on disk could ship.

**Fix:** Add a direct byte-parity assertion mirroring DIST-05 for the golden
copy (and optionally example↔golden), so all three copies are pinned by an
explicit `==` rather than relying on the normalizing golden-diff path:
```elixir
test "golden fixture copy is byte-identical to the installer template" do
  template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
  golden = File.read!("test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css")
  assert template == golden,
         "golden fixture sigra_admin.css drifted from template; resync the fixture"
end
```

## Info

### IN-01: DIST-06 assertion hardcodes the brand hex, coupling a "did-CSS-load" canary to a brand value

**File:** `test/example/priv/playwright/tests/admin-generated.spec.ts:97`
**Issue:** `expect(brandColor).toBe("#c2410c")` doubles as both "CSS loaded" and
"brand is exactly burnt-orange." If the brand hex is ever retuned in
`sigra_admin.css` (the file explicitly labels itself "TOKENS (v2)" and the repo
has a history of brand revisions — Brand v2 / D4), this Playwright assertion
breaks even though the CSS loaded perfectly, producing a confusing
merge-blocking failure in a host-parity smoke test that is conceptually about
*loading*, not *palette*. The hardcoded value also has to stay manually in sync
with the token.
**Fix:** Either accept the coupling deliberately (document it), or weaken the
canary to "token is present and non-empty" so it survives brand retunes:
`expect(brandColor).toMatch(/^#[0-9a-f]{6}$/i);` — still proves the `:root`
block loaded, without pinning the exact hue.

### IN-02: `phx-track-static` on a non-digested asset will warn in a generated host's production build

**File:** `priv/templates/sigra.install/admin/layouts_admin_injection.ex:10`
**Issue:** `phx-track-static` expects the referenced asset to appear in the
production `cache_manifest.json` (digested). `sigra_admin.css` is copied raw into
`priv/static/assets/` and is not part of a host's `esbuild`/`tailwind` digest
pipeline, so `Phoenix.HTML.Tag`/`static_path` will fall back and may log a
"no digest" warning in `MIX_ENV=prod` for host apps. This is **not new** — the
shipping `sigra_auth.css` uses the identical attribute
(`core/sigra_auth_components.ex:27`), so admin merely follows established
precedent. Flagging only so the known behavior is on record for the phase.
**Fix:** No action required for parity. If the auth-CSS warning is ever
addressed (e.g. documenting `mix phx.digest` coverage or dropping
`phx-track-static` for raw library assets), apply the same fix to both CSS
links together.

### IN-03: `files/1` accepts `web_module` in tests but the CSS/SVG paths derive `web` from `otp_app`

**File:** `lib/sigra/install/features/admin.ex:26-45` (tests `admin_test.exs:20,33,47`)
**Issue:** Minor consistency note: the `files/1` tests pass
`web_module: "MyAppWeb"`, but `files/1` ignores it and computes `web` as
`"#{otp_app}_web"`. The new CSS entry uses neither (`priv/static/assets/...` is
literal), so there is no bug. Noting because passing an unused, plausibly-load
-bearing arg (`web_module`) in the tests can mislead a future reader into
thinking the web module name flows into these paths when it does not.
**Fix:** Optional — drop `web_module:` from the `files/1` test bindings (it is
not consulted), or add a one-line comment on `files/1` that the web segment is
derived from `otp_app`, not the passed `web_module`.

---

_Reviewed: 2026-06-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
