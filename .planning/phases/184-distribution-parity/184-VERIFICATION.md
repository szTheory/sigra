---
phase: 184-distribution-parity
verified: 2026-06-14T01:49:45Z
status: passed
score: 6/6 must-haves verified
overrides_applied: 0
runtime_proof:
  - test: "scripts/ci/admin-acceptance-smoke.sh --test chrome (PORT=4017) — fresh phx.new (Phoenix 1.8.8) + mix sigra.install + boot generated host + Playwright admin-generated.spec.ts"
    result: "PASS — '✓ generated host admin shell renders on desktop and mobile (6.3s)'; 1 passed; 'admin-acceptance: success'. HTTP parity probes all green (audit/export/users/org-audit 200, impersonation 403, unknown-org 302). The passing test carries the DIST-06 --sg-color-brand === '#c2410c' computed-style assertion, proving sigra_admin.css loaded and the :root token block parsed in a freshly generated host."
    ran: "2026-06-14T05:54Z (orchestrator-run during execute-phase; shifts the prior human_needed item fully left to automation — zero human UAT)"
---

# Phase 184: Distribution Parity Verification Report

**Phase Goal:** Extract canonical admin `sg-*` CSS into a shipped installer asset (`priv/templates/sigra.install/admin/sigra_admin.css`); link it in the generated admin layout; example consumes the same file; merge-blocking example≡template parity; styled generated-host proof.

**Verified:** 2026-06-14T01:49:45Z
**Status:** passed
**Re-verification:** No — initial verification (DIST-06 runtime proof completed by orchestrator-run generated-host smoke; see `runtime_proof` frontmatter)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `priv/templates/sigra.install/admin/sigra_admin.css` exists with `@layer sg-base, sg-components, sg-overrides;`, zero `var(--vt-*)`, zero `.vt-*`, dark-mode and reduced-motion blocks present | VERIFIED | File exists at 11,012 bytes / 368 lines. `grep -c 'var(--vt-'` = 0; `grep -c '.vt-'` = 0; `grep -c 'VAULTR'` = 0; layer declaration count = 1; dark-mode block count = 1; reduced-motion count = 2; `--sg-pill-h` present |
| 2 | `lib/sigra/install/features/admin.ex` ships the CSS via `files/1` tuple `{:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"}` | VERIFIED | `grep -c 'admin/sigra_admin\.css'` returns 1; line 42-43 confirmed in admin.ex |
| 3 | Generated admin layout links the asset via `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` in `layouts_admin_injection.ex` | VERIFIED | `grep -c 'sigra_admin\.css'` returns 1; line 10 of layouts_admin_injection.ex confirmed; golden fixture layouts.ex line 102 confirmed |
| 4 | Example copy `test/example/priv/static/assets/sigra_admin.css` is byte-identical to template (11,012 bytes); `app.css` no longer defines `@layer sg-` | VERIFIED | `diff` returns IDENTICAL; both show 11,012 bytes; `grep -c '@layer sg-' app.css` = 0 |
| 5 | `mix test test/sigra/install/features/admin_test.exs` passes with DIST-02/DIST-03/DIST-05 parity tests; golden fixture copy also byte-identical to template | VERIFIED | 24 tests, 0 failures. Golden fixture diff returns IDENTICAL. `mix test golden_diff_test.exs --only golden` = 2 tests, 0 failures |
| 6 | `admin-generated.spec.ts` contains DIST-06 `--sg-color-brand` computed-style assertion proving `#c2410c`; snapshot canary stays green with empty allowlist; assertion holds at runtime in a freshly generated host | VERIFIED (static + runtime) | `grep -c 'sg-color-brand'` = 1; `grep -c 'DIST-06'` = 1; `grep -c '#c2410c'` = 1; snapshot-canary-guard exits 0 ("PASS, 0 changed slug(s)"). **Runtime:** `admin-acceptance-smoke.sh --test chrome` against a fresh phx.new+sigra.install host on port 4017 → Playwright `✓ generated host admin shell renders ... (6.3s)`, 1 passed, "admin-acceptance: success" |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `priv/templates/sigra.install/admin/sigra_admin.css` | Canonical template, sg-* only, 11,012 bytes | VERIFIED | 11,012 bytes / 368 lines; zero vt-* contamination |
| `lib/sigra/install/features/admin.ex` | files/1 tuple for sigra_admin.css | VERIFIED | Tuple at lines 42-43; `grep -c` returns 1 |
| `priv/templates/sigra.install/admin/layouts_admin_injection.ex` | Body-level `<link>` tag at line 10 | VERIFIED | Link tag confirmed at line 10, before `<.admin_shell>` |
| `test/example/priv/static/assets/sigra_admin.css` | Byte-identical copy of template | VERIFIED | `diff` returns IDENTICAL; 11,012 bytes |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` | Byte-identical golden fixture copy | VERIFIED | `diff` returns IDENTICAL; 11,012 bytes |
| `test/fixtures/install_golden/STDOUT.txt` | `* creating priv/static/assets/sigra_admin.css` line present | VERIFIED | Line confirmed in STDOUT.txt |
| `test/fixtures/install_golden/tree/lib/.../layouts.ex` | `<link>` tag at line 102 | VERIFIED | Line 102 confirmed |
| `test/sigra/install/features/admin_test.exs` | DIST-02, DIST-03, DIST-05 parity assertions | VERIFIED | Lines 46-49 (DIST-02), lines 91-92 (DIST-03), lines 317-326 (DIST-05); 24 tests, 0 failures |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | DIST-06 `--sg-color-brand` assertion | VERIFIED (static) | Lines 89-97 confirmed; all pre-existing tests (shell/scope/denial/CSV/impersonation) intact |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/sigra/install/features/admin.ex` files/1 | `priv/templates/sigra.install/admin/sigra_admin.css` | `{:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"}` | WIRED | Confirmed at lines 42-43 |
| `priv/templates/sigra.install/admin/layouts_admin_injection.ex` | `priv/static/assets/sigra_admin.css` | `<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />` | WIRED | Line 10 confirmed |
| `test/sigra/install/features/admin_test.exs` | `priv/templates/sigra.install/admin/sigra_admin.css` | `File.read!` byte-compare (DIST-05) | WIRED | Lines 317-326; test passes |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | `priv/static/assets/sigra_admin.css` | `getComputedStyle(document.documentElement).getPropertyValue("--sg-color-brand")` | WIRED (runtime-proven) | Lines 89-97; runtime proof PASSED via orchestrator-run generated-host smoke (port 4017, 1 passed) |

### Data-Flow Trace (Level 4)

Not applicable. This phase produces a CSS distribution pipeline and test assertions — no dynamic data rendering or state management involved.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Template CSS has zero vt-* contamination | `grep -c 'var(--vt-' sigra_admin.css` | 0 | PASS |
| Template CSS layer declaration present | `grep -c '@layer sg-base, sg-components, sg-overrides;'` | 1 | PASS |
| admin.ex ships CSS tuple | `grep -c 'admin/sigra_admin\.css' admin.ex` | 1 | PASS |
| layout injects link tag | `grep -c 'sigra_admin\.css' layouts_admin_injection.ex` | 1 | PASS |
| Example copy is byte-identical | `diff template example_copy` | IDENTICAL | PASS |
| Golden fixture is byte-identical | `diff template golden_fixture` | IDENTICAL | PASS |
| app.css has no sg-layers | `grep -c '@layer sg-' app.css` | 0 | PASS |
| admin_test.exs passes (24 tests) | `mix test admin_test.exs` | 24 tests, 0 failures | PASS |
| golden_diff_test passes | `mix test golden_diff_test.exs --only golden` | 2 tests, 0 failures | PASS |
| Playwright assertion present | `grep -c 'sg-color-brand' admin-generated.spec.ts` | 1 | PASS |
| Snapshot canary green | `bash scripts/ci/snapshot-canary-guard.sh` | PASS (0 changed slugs) | PASS |
| `--sg-color-brand` token value in template | `grep -n '\-\-sg-color-brand:' sigra_admin.css` | Line 67: `--sg-color-brand: #c2410c;` | PASS |

### Probe Execution

No probes (`scripts/*/tests/probe-*.sh`) are declared or conventional for this CSS distribution phase. Snapshot canary (`scripts/ci/snapshot-canary-guard.sh`) was run directly and returned exit 0.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DIST-01 | 184-01 | Admin sg-* CSS extracted into canonical installer template; vt-* NOT extracted | SATISFIED | Template at 11,012 bytes; zero vt-* grep; all three @layer blocks present |
| DIST-02 | 184-02 | Installer ships CSS via admin.ex files/1 | SATISFIED | Tuple confirmed at admin.ex:42-43; admin_test.exs line 49 asserts it |
| DIST-03 | 184-02 | Generated admin layout links the stylesheet | SATISFIED | Link tag at layouts_admin_injection.ex:10; test asserts at admin_test.exs:91-92 |
| DIST-04 | 184-02 | Example app consumes same canonical CSS; app.css reduced | SATISFIED | Byte-identical copy confirmed; app.css @layer sg- count = 0 |
| DIST-05 | 184-02 | Merge-blocking parity test proves example byte-identical to template | SATISFIED | DIST-05 describe block at admin_test.exs:317-326; 24 tests pass |
| DIST-06 | 184-03 | Freshly generated host renders styled admin UI (via generated_admin_playwright_smoke) | SATISFIED (static) / HUMAN NEEDED (runtime) | Playwright assertion wired correctly; CI job picks it up via --test all; runtime verification requires CI run against freshly generated host |

**Note on DIST-06 and `RUN_PARITY=1`:** REQUIREMENTS.md cites `RUN_PARITY=1` as the mechanism for DIST-06. The RESEARCH.md (line 282) and Plan 03 both document that `RUN_PARITY=1` does NOT exist in `admin-acceptance-smoke.sh` — it is a description of the job's intent in the requirements document, not an actual env var. The correct mechanism is `--test all` which runs `admin-generated.spec.ts` including the new DIST-06 assertion. The implementation is correct; the requirements text used shorthand notation for the parity lane.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

No TBD, FIXME, XXX, TODO, HACK, PLACEHOLDER, or stub patterns found in any phase-modified file.

### Human Verification Required

#### 1. DIST-06 Runtime Proof — Playwright Styled Assertion Against Generated Host

**Test:** Run `scripts/ci/admin-acceptance-smoke.sh --test all` (or trigger the `generated_admin_playwright_smoke` CI job) against a freshly generated host application that has Sigra installed.

**Expected:** The assertion at `admin-generated.spec.ts:89-97` passes:
- `getComputedStyle(document.documentElement).getPropertyValue("--sg-color-brand").trim()` returns `"#c2410c"`
- Full test suite: 0 failures across all admin-generated spec tests (shell/denial/users/CSV/impersonation + DIST-06)

**Why human:** The DIST-06 Playwright assertion must run against a browser-rendered page in a freshly phx_new-generated host that has `sigra.install` run against it. This requires: `mix phx.new` scaffold, `mix sigra.install`, Phoenix server boot, Playwright browser launch, and navigation to `/admin`. The verifier environment cannot perform this end-to-end scaffold without compromising isolation.

**Static evidence confirming the assertion is correctly placed and will pass when CI runs:**
- `--sg-color-brand: #c2410c;` is confirmed at `sigra_admin.css:67`
- The token is not defined in `app.css` or `default.css` (only in `sigra_admin.css`)
- The installer tuple (DIST-02) ships the CSS to the generated host
- The layout injection (DIST-03) links it with `phx-track-static`
- The `assets` path is in the example endpoint's `Plug.Static :only` list (confirmed by code review)
- The pattern is identical to the proven `sigra_auth.css` precedent

### Code Review Context (184-REVIEW.md)

The code review found 0 critical issues, 2 warnings, and 3 info items — all advisory robustness items with no blockers for the phase goal:

- **WR-01** (Warning): `sigra_admin.css` runs through `EEx.eval_file` even though it is a static asset. If a future edit introduces a `<%` sequence, the installer will corrupt or error. Recommended fix: add a `:text`/`:copy` file mode to the runner, or add a guard test asserting the CSS template is EEx-inert.
- **WR-02** (Warning): DIST-05 pins `template ≡ example` but there is no direct `template ≡ golden_fixture` byte assertion (the golden diff path normalizes content before comparing). Recommended fix: add a direct byte-parity test for the golden fixture copy.
- **IN-01** (Info): DIST-06 assertion hardcodes `#c2410c`, coupling a "did-CSS-load" canary to a brand hex value. A brand retune will break the assertion.
- **IN-02** (Info): `phx-track-static` on a non-digested asset may warn in production; same behavior as the pre-existing `sigra_auth.css`.
- **IN-03** (Info): `files/1` tests pass `web_module:` which is unused for CSS/SVG paths.

These findings do not gate phase goal achievement but are recommended for follow-up (WR-01 and WR-02 are the higher priority items).

### Gaps Summary

No gaps block the phase goal. All 6 must-have truths are verified in the codebase. The single human verification item (DIST-06 runtime Playwright execution) cannot be performed without a running browser + generated host scaffold — all static evidence confirms the assertion is correctly wired and will pass in CI.

---

_Verified: 2026-06-14T01:49:45Z_
_Verifier: Claude (gsd-verifier)_
