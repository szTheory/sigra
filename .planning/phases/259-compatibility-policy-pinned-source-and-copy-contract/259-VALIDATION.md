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
| BPOL-04 | Name-clearance record titled "search log, not clearance", names `crosswake_sigra` | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-05 | Seven recorded decisions present in ADR | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-06 | No remaining "Rail Accent … from `brandbook/`" instruction in instruction files/guides | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BPOL-07 | Upgrade-note skeleton present | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-01 | Vocabulary table with the five required rulings | doc-contract ExUnit | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-02 | New violations fail; vanished baseline entries fail; scanner planted-term control | unit | `mix test test/sigra/brand/copy_contract_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-03 | Parity per pre-auth surface; known divergences asserted; positive control yields exactly one `:diff` | example ConnTest/LiveViewTest | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-04 | Inventory files equal extraction for three lanes | unit | `mix test test/sigra/brand/copy_contract_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-05 | Three install-snippet segments all equal, non-vacuous | unit | `mix test test/sigra/brand/install_snippet_test.exs` | ❌ W0 | ⬜ pending |
| BCOPY-06 | No `has-text("Log in")` outside comments; specs pass in CI shards | grep + CI | `! grep -rn 'has-text("Log in")' test/example/priv/playwright` then PR `example_playwright_shard` | ❌ W0 | ⬜ pending |
| BCOPY-07 | Claim sites reworded; each `known_divergence` row referenced by claims register | doc-contract ExUnit + review | `mix test test/sigra/brand/policy_docs_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/brand/source_pin_test.exs` — BPOL-02
- [ ] `test/sigra/brand/frozen_surface_test.exs` + `test/fixtures/brand/frozen-surface.json` — BPOL-03
- [ ] `test/sigra/brand/legacy_profiles_test.exs` + `test/fixtures/brand/legacy-profiles.json` — BPOL-03
- [ ] `test/sigra/brand/copy_contract_test.exs` + `copy-baseline.json` + `copy-inventory/*.tsv` + `test/support/brand/copy_scan.ex` — BCOPY-02/04
- [ ] `test/sigra/brand/install_snippet_test.exs` — BCOPY-05
- [ ] `test/sigra/brand/policy_docs_test.exs` — BPOL-01/04/05/06/07, BCOPY-01/07 (headings and key terms only; do not over-pin prose)
- [ ] `test/example/test/example_web/enumeration_parity_test.exs` + `test/fixtures/brand/public-surfaces.json` — BCOPY-03
- [ ] `test/example/priv/playwright/helpers/loginSubmit.ts` — BCOPY-06
- [ ] Framework install: none (local Playwright needs `npm ci`; proof is the PR's CI shards)

---

## Phase-Gate Shell Checks

Record outputs in the verification report (base commit `aeda7273d`):

```bash
git diff --stat aeda7273d..HEAD -- lib priv brandbook          # must print nothing
git diff --stat aeda7273d..HEAD -- .github scripts              # nothing, or within the plan's stated budget
git diff aeda7273d..HEAD -- test/fixtures/brand/frozen-surface.json | grep '^-[^-]'   # nothing (ratchet only grew)
git diff aeda7273d..HEAD --text | grep -n -E '/Users/[^/ ]+|/home/[^/ ]+'              # nothing
printf 'x /Users/someone/y\n' | grep -E '/Users/[^/ ]+'                                 # planted-failure control: must print a match
shasum -a 256 -c brand.sha256 | grep -vc ': OK$'                                       # 0
```

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
