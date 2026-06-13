---
plan: 183-01
phase: 183
status: complete
completed: 2026-06-13
requirements:
  - BRAND2-11
  - BRAND2-12
commits:
  - 71953c48 (feat: propagate D4 admin lockup SVGs to installer + example)
  - 33313ee1 (feat: replace companion marks with D4 abstract rail glyph)
  - b42a9e52 (test: update guard assertions + golden fixture for D4 lockup)
---

# Plan 183-01 Summary — Propagation + Parity (Wave 1)

## Outcome

The ratified D4 Linked Rail logo is propagated into all shipping locations under unchanged filenames; token parity verified unchanged; all logo-related test suites green.

## Per-task

**Task 1 — D4 admin cropped lockups (71953c48).** Pure viewBox reframe of `brandbook/logo-primary{,-dark}.svg`: glyph paths + rail-tittle rect copied verbatim; only `viewBox` → `"20 220 2361 1000"`, `<title>`, `<desc>` (carries "Space Grotesk v2.0") changed. Dark fills: glyphs `#f4f1eb`, rail-tittle `#fdba74`. Written to `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg` AND `test/example/priv/static/images/sigra-logo-primary{,-dark}.svg`. Installer ↔ example byte-identical confirmed (`cmp` exit 0, light + dark).

**Task 2 — companion marks (33313ee1).** `test/example/priv/static/images/rail-accent-mark{,-dark}.svg` content-swapped to the D4 abstract mark from `brandbook/logo-mark.svg`; `prefers-color-scheme` `<style>` removed; explicit fills (light `#151515`/`#c2410c`, dark `#f4f1eb`/`#fdba74`). Filenames unchanged (demo-showcase.spec.ts checks only `src`).

**Task 3 — guard assertions + golden fixture + parity + mix test.**
- Updated the two cropped-lockup guard tests (`test/example/test/example_web/admin_shell_test.exs`, `test/sigra/install/features/admin_test.exs`): `viewBox="20 12 188 54"`→`"20 220 2361 1000"` and `"Inter Display Black v4.1."`→`"Space Grotesk v2.0"`; the 3 structural assertions (has `<path`, no `<text`, no `font-family`) unchanged. (Documented SC1 deviation — see below.)
- **Token parity (BRAND2-12) — verified UNCHANGED, no edits:** brandbook/tokens.json ember-700 `#c2410c`; app.css `--sg-color-brand: #c2410c` + `--sg-logo-rail-accent: #fdba74`; sigra_auth.css `--sigra-auth-light-accent` fallback `#c2410c`. Three-surface ember parity holds.
- Touched suites green: installer `admin_test` 22/0, example `admin_shell_test` 14/0, `golden_diff_test` 2/0.

## Deviations

1. **SC1 wording vs reality (documented in CONTEXT).** The roadmap SC1 said "without modification to test expectations," but the two guard tests pinned v1-specific content (`viewBox` + font provenance). Swapping in the D4 logo necessarily required updating exactly 2 assertion strings per file. The invariant the tests enforce (cropped, path-only, no live text/font-family) is preserved; only the v1-specific values changed. This is intended churn that accompanies a deliberate logo change.

2. **Golden fixture regen — plan gap, fixed in-scope.** The plan (and research) flagged the 2 ExUnit assertion tests but missed that `test/fixtures/install_golden/tree/priv/static/images/sigra-logo-primary{,-dark}.svg` ALSO stores the logo bytes (the installer's byte-for-byte regression barrier). `golden_diff_test` failed on the viewBox diff. Fixed per the documented regen procedure by updating the two fixture logo SVGs to the new template output (SVGs are copied verbatim by the installer; non-config files get only trailing-newline normalization). Same intended-churn class as the assertion updates; squarely within BRAND2-11 ("all installer and example parity tests pass").

## Pre-existing failures (NOT caused by this milestone — surfaced, not masked)

Root `mix test` finished 2381 tests / 12 skipped with **2 remaining failures**, both proven byte-identical to the `main` merge-base (`git diff main...HEAD` shows `core/` unchanged except +9 lines in migration.exs):

- `test/sigra/install/isolation_test.exs:86` — asserts `core/*` contains exactly 49 templates; actual 52. Template-count drift (3 core templates added at/before merge-base without bumping the count). **Pre-existing.**
- `test/mix/tasks/sigra.install_test.exs:166` — `priv/templates/sigra.install/core/auth.ex:554` references undefined EEx binding `app_name` → CompileError when rendering the auth context template. **Pre-existing, and a real generated-template bug** (a host app generated from this template branch would fail to compile the auth context). Deserves its own `/gsd-debug` or `/gsd-quick` cycle — out of scope for logo propagation.

(Background `Postgrex … Chimeway.Repo missing :database` log lines are an unrelated stray-repo connection logger, not test failures.)

## must_have status (Wave 1 portion)

- ✅ Logo under unchanged filenames in installer + example, byte-identical (BRAND2-11)
- ✅ Guard + golden parity tests green after intended assertion/fixture updates (BRAND2-11)
- ✅ Companion marks → D4 (BRAND2-11)
- ✅ sg-*/auth token parity verified unchanged (BRAND2-12)
- ⚠ Full-suite "mix test exits 0" (BRAND2-14, Wave 2 gate): blocked ONLY by the 2 pre-existing unrelated failures above; all logo-related tests pass. To be reconciled in Plan 02 verification (the milestone did not introduce these).

## Hand-off to Plan 02

Wave 2: Playwright baseline recapture (allowlist +3 → 7 slugs, port 4011, `--update-snapshots=all`, restore 3 impersonation-banner canary PNGs, reset allowlist to empty) + hygiene sweep + git clean. Note for the hygiene/verification gate: BRAND2-14's literal "mix test exits 0" cannot be met because of the 2 pre-existing `core/` failures — record them as the reason and confirm no NEW failures were introduced by the milestone.
