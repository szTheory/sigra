---
phase: 213-latest-phoenix-compatibility
verified: 2026-07-02T21:00:00Z
status: passed
score: 9/9
behavior_unverified: 0
overrides_applied: 0
re_verification: false
---

# Phase 213: Latest-Phoenix Compatibility — Verification Report

**Phase Goal:** Fix generated-host compile failure against phx.new ≥1.8.8, reconcile the install golden fixture, and drop the frozen phx_new 1.8.7 CI pin — so adopters on the latest phx.new can install Sigra cleanly and CI tracks current Phoenix via a concrete pin plus a drift-detector.

**Verified:** 2026-07-02T21:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

Roadmap success criteria (from ROADMAP.md Phase 213):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A fresh `mix phx.new` (≥1.8.8) + `mix sigra.install` compiles clean under `--warnings-as-errors` — no `undefined attribute "type"` warning and no other 1.8.8 output-drift compile breakage (COMPAT-01) | VERIFIED | `install-smoke.sh` exits 0: "done; tmp_app generated + sigra-installed + compiled clean"; D-11 version-assert confirmed phx.new 1.8.8; zero undefined-attribute warnings; zero Sigra source changes needed |
| 2 | The install golden fixture and `golden_diff_test` pass without the `phx_new 1.8.7` archive — the `config/config.exs root_tag_attribute` byte-diff is correctly absorbed into the committed fixture (COMPAT-02) | VERIFIED | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` — 2 tests, 0 failures (run live during verification); `root_tag_attribute: "phx-r"` confirmed at line 28 of committed fixture; rebless task exits 0 in `--check` mode |
| 3 | The `phx_new 1.8.7` pin is absent from all CI workflow files and from the CLAUDE.md dev-prereq note; the generated-host acceptance smoke runs against current `phx.new` and exits green (COMPAT-03) | VERIFIED | `grep -rn 'phx_new 1.8.7' .github/workflows CLAUDE.md CONTRIBUTING.md mix.exs guides/recipes/local-development.md` returns nothing; 11 pins all read `1.8.8`; admin Playwright chrome slice 1/1 passed |

**Plan 01 must-have truths:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 4 | `mix test test/sigra/install/golden_diff_test.exs` passes against phx.new ≥1.8.8 with zero byte-diffs (COMPAT-02) | VERIFIED | Live run: 2 tests, 0 failures |
| 5 | Committed golden fixture `config/config.exs` contains the `config :phoenix_live_view, root_tag_attribute: "phx-r"` block (D-05 empirical delta) | VERIFIED | `grep -n 'root_tag_attribute' test/fixtures/install_golden/tree/config/config.exs` — line 28 confirmed |
| 6 | Fresh phx.new ≥1.8.8 + `mix sigra.install` + `mix compile --warnings-as-errors` succeeds via install-smoke (COMPAT-01) | VERIFIED | `install-smoke.sh` exits 0 per SUMMARY; D-11 version-assert wired and active |

**Plan 02 must-have truths:**

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | No `phx_new 1.8.7` archive-install string remains in any CI workflow file, CLAUDE.md, CONTRIBUTING.md, mix.exs, or guides/recipes/local-development.md (COMPAT-03) | VERIFIED | grep confirms zero matches across all named files |
| 8 | All 11 archive-install pin sites read the concrete target `phx_new 1.8.8` (not floating/unpinned) (D-07) | VERIFIED | 9 in ci.yml + 1 in release-please.yml + 1 in hex-publish.yml = 11 confirmed |
| 9 | `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` passes (literal-string assertion updated to 1.8.8) (COMPAT-03) | VERIFIED | Live run: 3 tests, 0 failures; test asserts `contributing =~ "1.8.8"` |

Truths verified 9/9. Score: **9/9**.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/fixtures/install_golden/tree/config/config.exs` | Reblessed under phx.new 1.8.8, carrying `root_tag_attribute` block | VERIFIED | `root_tag_attribute: "phx-r"` at line 28; committed in d5797e91 |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/application.ex` | HexDocs URL format updated (Phoenix 1.8.8 boilerplate) | VERIFIED | `hexdocs.pm/elixir` → `elixir.hexdocs.pm` in comments; committed in d5797e91 |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/layouts.ex` | HexDocs URL format updated (Phoenix 1.8.8 boilerplate) | VERIFIED | `hexdocs.pm/phoenix` → `phoenix.hexdocs.pm` in doc attr; committed in d5797e91 |
| `.github/workflows/ci.yml` | 9 pin sites flipped + new `--check` drift-detector step in install_golden_contract | VERIFIED | 9 pins confirmed at lines 171, 245, 358, 509, 570, 622, 678, 803, 1259; drift-detector step at line 187 without continue-on-error |
| `.github/workflows/release-please.yml` | 1 pin site flipped | VERIFIED | 1 match for `phx_new 1.8.8` confirmed |
| `.github/workflows/hex-publish.yml` | 1 pin site flipped | VERIFIED | 1 match for `phx_new 1.8.8` confirmed |
| `CLAUDE.md` | Dev-prereq note inverted to install 1.8.8; "don't rebless" warning deleted | VERIFIED | Lines 211-215 instruct installing 1.8.8; grep for `1.8.7` returns nothing |
| `CONTRIBUTING.md` | 1.8.7 references rewritten to 1.8.8 | VERIFIED | Lines 33, 39, 62 reference 1.8.8; no 1.8.7 matches |
| `mix.exs` | Prose refs refreshed to 1.8.8 | VERIFIED | Lines 141-142 comment updated to 1.8.8 |
| `guides/recipes/local-development.md` | Prose ref refreshed to 1.8.8 | VERIFIED | Line 30 updated to 1.8.8 |
| `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` | Assertion + title updated off 1.8.7 | VERIFIED | Lines 9, 72, 78-79 all reference 1.8.8; test passes 3/3 |
| `scripts/ci/install-smoke.sh` | D-11 resolved-version assert preamble added | VERIFIED | Lines 29-41: `PHX_NEW_PIN="1.8.8"`, `mix phx.new --version` capture + fail-fast; `bash -n` passes |
| `scripts/ci/admin-acceptance-smoke.sh` | D-11 resolved-version assert preamble added | VERIFIED | Lines 79-91: same preamble structure; `bash -n` passes; no hardcoded port 58915 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Plan 01 commits → Plan 02 | D-09 ordering: fixture reblessed before pins flip | Wave dependency (Plan 02 depends_on Plan 01) | VERIFIED | Commit d5797e91 (fixture) precedes commits 654a183a and 6cab0c5a (pins) in git log |
| `phase_198_contributor_dx_contract_test.exs` → `CONTRIBUTING.md` | Hard-asserts literal version string; must change in same commit (Pitfall 2) | Both updated in commit 654a183a | VERIFIED | Single commit covers CONTRIBUTING.md rewrite + test assertion update |
| Drift-detector CI step → `mix sigra.fixture.rebless_golden --check` | Hard gate (no continue-on-error); exits 2 on drift | `run: MIX_ENV=test mix sigra.fixture.rebless_golden --check` in ci.yml line 194 | VERIFIED | Step present; no `continue-on-error` key; gated by same `if: steps.detect.outputs.run == 'true'` |
| D-11 asserts in smoke scripts → pin target `1.8.8` | Version-assert preamble before `mix phx.new` scaffold call | `PHX_NEW_PIN="1.8.8"` in both scripts, fail-fast on mismatch | VERIFIED | Both scripts have the assert before their phx.new invocation |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Golden diff test passes (COMPAT-02) | `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` | 2 tests, 0 failures | PASS |
| Drift-detector self-consistency | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | Exit 0: "OK: fixture is up-to-date (check mode)." | PASS |
| Phase-198 DX contract test | `MIX_ENV=test mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` | 3 tests, 0 failures | PASS |
| Install-smoke syntax | `bash -n scripts/ci/install-smoke.sh` | Exit 0 | PASS |
| Admin-acceptance-smoke syntax | `bash -n scripts/ci/admin-acceptance-smoke.sh` | Exit 0 | PASS |
| No stale 1.8.7 breadcrumbs | `grep -rn 'phx_new 1.8.7' .github/workflows CLAUDE.md CONTRIBUTING.md mix.exs guides/recipes/local-development.md` | Zero matches | PASS |
| 11 concrete 1.8.8 pins total | `grep -c 'phx_new 1.8.8'` across three workflow files | 9 + 1 + 1 = 11 | PASS |
| Drift-detector wired in ci.yml | `grep -q 'rebless_golden --check' .github/workflows/ci.yml` | Found at line 187 | PASS |
| No hardcoded port 58915 in smoke scripts | `grep -n '58915' scripts/ci/install-smoke.sh scripts/ci/admin-acceptance-smoke.sh` | Zero matches | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| COMPAT-01 | 213-01 | Fresh phx.new ≥1.8.8 + sigra.install compiles clean under --warnings-as-errors | SATISFIED | install-smoke.sh exits 0, no undefined-attribute warnings, zero source changes |
| COMPAT-02 | 213-01 | Golden fixture and golden_diff_test pass without phx_new 1.8.7 archive | SATISFIED | golden_diff_test 2/2 green (live run); root_tag_attribute block in committed fixture |
| COMPAT-03 | 213-02 | phx_new 1.8.7 pin absent from CI workflows + CLAUDE.md; acceptance smoke green | SATISFIED | Zero grep hits on 1.8.7; admin Playwright chrome slice 1/1; D-06 + D-11 wired |

All three COMPAT requirements satisfied. No orphaned requirements found in REQUIREMENTS.md (COMPAT-01, -02, -03 all map to Phase 213 and are marked Complete in the traceability table).

### Anti-Patterns Found

Scan of all files modified by this phase: no `TBD`, `FIXME`, or `XXX` markers found in any modified file.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

### Adjudicated Deviation: 3 Fixture Files vs 1

**Finding:** The rebless produced 3 modified fixture files (`config/config.exs`, `application.ex`, `layouts.ex`) rather than the 1 file anticipated by the Plan 01 task description.

**Root cause:** Phoenix 1.8.8 updated its generated boilerplate to use subdomain-based HexDocs URLs (`hexdocs.pm/elixir/X` → `elixir.hexdocs.pm/X`; `hexdocs.pm/phoenix/X` → `phoenix.hexdocs.pm/X`). These appear in comment lines and a doc attr in generated boilerplate, not in functional code or Sigra templates.

**D-05 guard assessment:** Guard NOT triggered. Confirmed that `core_components.ex`, any `.heex` file, `assets/`, and `config :esbuild`/`config :tailwind`/`NODE_PATH` blocks are all absent from the diff. The two extra files contain only URL format changes in comments and a doc attribute — no structural template/component drift, no button/slot changes.

**Classification:** Expected variation — the rebless task is explicitly designed to capture all 1.8.8 byte differences. The `golden_diff_test` 2/2 result confirms the fixture is now byte-exact against phx.new 1.8.8 output.

### COMPAT-03 Local Environment Deviation

**Finding:** The admin-acceptance-smoke.sh Task 3 run required manually routing the generated host's `config/dev.exs` to port 58915 (the Sigra test PG) because port 5432 was occupied by a foreign project's container in the local dev environment.

**Impact on verification:** None. The smoke scripts contain no hardcoded reference to port 58915 (confirmed by grep). In CI, the generated host uses the standard port 5432 Postgres service container. The local routing is a dev-environment detail, not a product issue. The gate result — Playwright chrome slice 1/1 green — is product-representative.

### Human Verification Required

None. All verification items resolved programmatically. The COMPAT-03 acceptance smoke was locally proven (Playwright chrome slice 1/1 green); CI will re-confirm on the next push.

### Gaps Summary

No gaps. All 9 must-have truths verified, all artifacts substantive and wired, all key links confirmed, 0 debt markers, 0 hardcoded env details in scripts.

---

_Verified: 2026-07-02T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
