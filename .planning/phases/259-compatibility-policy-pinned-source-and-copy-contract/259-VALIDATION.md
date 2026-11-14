---
phase: "259"
slug: compatibility-policy-pinned-source-and-copy-contract
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-13"
---

# Phase 259 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `259-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5); Playwright Test 1.59.1 for BCOPY-06 only |
| **Config file** | `test/test_helper.exs` (root), `test/example/test/test_helper.exs`; example tests use `@moduletag :example_app` |
| **Quick run command** | `mix test test/sigra/brand` (needs Postgres: `scripts/db/up.sh` then `source tmp/db.env`) |
| **Full suite command** | `MIX_ENV=test mix ci` and `cd test/example && MIX_ENV=test mix test --include example_app` |
| **Estimated runtime** | quick ~5 s once compiled (first compile ~2 min); full suite several minutes |

---

## Sampling Rate

- **After every task commit:** `mix test test/sigra/brand` plus `mix format --check-formatted` on touched files
- **After every plan wave:** `mix test test/sigra/brand test/sigra/admin/glossary_test.exs test/sigra/error_test.exs test/sigra/branding_test.exs test/sigra/planning/phase_242_shift_left_contract_test.exs test/sigra/architecture_guides_contract_test.exs` plus the example parity file
- **Before `/gsd-verify-work`:** `MIX_ENV=test mix ci` green, example suite green, phase-gate shell checks recorded
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command | File Exists | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| BPOL-01 | ADR, `contract.md` section and guide contain required headings/terms | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-02 | Manifest drift red on one changed byte; privacy scan clean; planted failure red | unit | `mix test test/sigra/brand/source_pin_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-02 | `brandbook/` untouched; zero bytes in `lib`/`priv` | shell gate | `git diff --stat aeda7273d..HEAD -- lib priv brandbook` (prints nothing) | n/a | ⬜ pending |
| BPOL-03 | Frozen-surface superset per category; comparator red on a removal | unit | `mix test test/sigra/brand/frozen_surface_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-03 | Legacy profiles byte-identical | unit | `mix test test/sigra/brand/legacy_profiles_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-04 | Name-clearance record titled "search log, not clearance", names `crosswake_sigra` | doc-contract ExUnit | `mix test test/sigra/brand/name_clearance_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-05 | Seven recorded decisions present in ADR | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-06 | No remaining "Rail Accent … from `brandbook/`" instruction in instruction files/guides | doc-contract ExUnit | `mix test test/sigra/brand/instruction_pointers_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-07 | Upgrade-note skeleton present | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-01 | Vocabulary table with the seven rulings (Active/Unconfirmed/Locked/Deletion scheduled, sign in, Suspended out of scope, revoke/delete/remove, Admin not Admin (operator), Review users) and test-verified anchors (Plan 12) | doc-contract ExUnit | `mix test test/sigra/brand/vocabulary_docs_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-02 | New violations (banned terms and Do-not-say lexicon in admin and generated scopes; lexicon in README/top guides) fail; vanished baseline entries fail; scanner planted-term control | unit | `mix test test/sigra/brand/copy_contract_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-03 | Parity per pre-auth surface (five named, at least three parity, downgrades carry a file:line blocker); known divergences asserted; todo paths exist (Plan 13); positive control yields exactly one `:diff` | example ConnTest/LiveViewTest | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-04 | Inventory files equal extraction for three lanes | unit | `mix test test/sigra/brand/copy_inventory_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-05 | Three install-snippet segments all equal, non-vacuous | unit | `mix test test/sigra/brand/install_snippet_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-06 | No `has-text("Log in")` outside comments; selector matches exactly one button (example host render + generated template source); specs pass in CI shards only | grep + ConnTest + CI | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/login_submit_selector_test.exs`, then PR `example_playwright_shard` | ❌ W0 | ⬜ pending |
| BCOPY-07 | Claim sites reworded; repo-wide unbounded-claim sweep; each non-parity registry row referenced by the claims register | doc-contract ExUnit + review | `mix test test/sigra/brand/claims_docs_test.exs test/sigra/brand/name_clearance_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/brand/source_pin_test.exs` — BPOL-02
- [ ] `test/sigra/brand/frozen_surface_test.exs` + `test/fixtures/brand/frozen-surface.json` — BPOL-03
- [ ] `test/sigra/brand/legacy_profiles_test.exs` + `test/fixtures/brand/legacy-profiles.json` — BPOL-03
- [ ] `test/sigra/brand/copy_contract_test.exs` + `copy-baseline.json` + `copy-inventory/*.tsv` + `test/support/brand/copy_scan.ex` — BCOPY-02/04
- [ ] `test/sigra/brand/install_snippet_test.exs` — BCOPY-05
- [ ] `test/sigra/brand/policy_docs_test.exs` — BPOL-01/05/07; `instruction_pointers_test.exs` — BPOL-06; `name_clearance_test.exs` — BPOL-04; `vocabulary_docs_test.exs` — BCOPY-01; `claims_docs_test.exs` — BCOPY-07 (headings and key terms only; do not over-pin prose)
- [ ] `test/example/test/example_web/enumeration_parity_test.exs` + `test/fixtures/brand/public-surfaces.json` — BCOPY-03
- [ ] `test/example/priv/playwright/helpers/loginSubmit.ts` and `test/example/test/example_web/login_submit_selector_test.exs` — BCOPY-06
- [ ] Framework install: none (local Playwright needs `npm ci`; proof is the PR's CI shards)

---

## Phase-Gate Shell Checks

Record outputs in the verification report (base commit `aeda7273d`):

```bash
# Every check captures git output first so a failing git cannot read as clean; controls are the non-empty checks.
D=$(git diff --stat aeda7273d -- .planning) && test -n "$D" && L=$(git ls-files -- lib priv brandbook brand .github scripts | head -1) && test -n "$L" && Z=$(git diff --stat aeda7273d -- lib priv brandbook brand .github scripts) && test -z "$Z" && U=$(git status --porcelain -- lib priv brandbook brand .github scripts) && test -z "$U"
F=$(git diff aeda7273d -- test/fixtures/brand/frozen-surface.json) && test -n "$F" && test -z "$(printf '%s\n' "$F" | grep '^-[^-]')" && printf '%s\n' "$F" | grep -q '^+[^+]'
D=$(git diff aeda7273d --text -- . ':(exclude).planning/phases/259-*') && test -n "$D" && test -z "$(printf '%s\n' "$D" | grep -E '/Users/[^/ ]+|/home/[^/ ]+')" && printf 'x /Users/someone/y\n' | grep -qE '/Users/[^/ ]+'
S=$(shasum -a 256 -c brand.sha256) && test -n "$S" && test "$(printf '%s\n' "$S" | grep -vc ': OK$')" = 0 && test "$(printf '%s\n' "$S" | grep -c ': OK$')" = "$(grep -c . brand.sha256)"
```

The vendored-origin check (host derived from `brand/index.html` at run time, never written down) is step 6 of Plan 11 Task 2.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Owner approval of the owner-decision defaults (SemVer level, msgid policy, vendoring scope, clear-space/logo-use authority) | BPOL-05, BPOL-04 | Decisions belong to the project owner | Owner reviews the ADR "Recorded decisions" table before merge |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
