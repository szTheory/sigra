---
phase: "239"
slug: "priv-templates-sweep-one-batched-re-bless"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-17"
---

# Phase 239 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `239-RESEARCH.md` §4 (runnable verification commands) and `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) with the `Sigra.Test.InstallFixture` subprocess harness |
| **Config file** | `mix.exs` `aliases/0` (`ci`, `ci.install_golden`); `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` |
| **Full suite command** | `MIX_ENV=test mix ci` |
| **Estimated runtime** | quick ~60–120s (no DB) · full `mix ci` ~8–12 min (needs Postgres) |

---

## Sampling Rate

- **After every task commit:** `mix format --check-formatted` + `mix compile --warnings-as-errors`;
  after the sweep commit also the `priv/templates/` union-token grep count (must reach `0`).
- **After every plan wave:** `MIX_ENV=test mix ci.install_golden`.
- **After the re-bless commit:** `MIX_ENV=test mix sigra.fixture.rebless_golden --check` → exit 0.
- **Before `/gsd-verify-work`:** `mix ci` green on a **clean tree at the final committed HEAD**,
  plus SC-1 and SC-2 live observations with their output pasted into the SUMMARY.
- **Max feedback latency:** ~120 seconds (quick lane).

---

## Per-Task Verification Map

*Seeded from the requirement→test map in `239-RESEARCH.md`. Task IDs are bound by `/gsd-validate-phase`
once `239-NN-PLAN.md` files exist; the command column below is already resolved and runnable.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 239-TBD | — | 0 | SURF-03 | — | Re-bless diff cannot silently absorb a code change | contract | `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-comment-only-diff-check.sh` (prints `changed_lines`, `files`, `nonconforming`) | ❌ W0 | ⬜ pending |
| 239-TBD | — | 0 | SURF-03 | — | Expected-removed golden line set is frozen pre-sweep | contract | `grep -rnE "$UNION" test/fixtures/install_golden/tree > 239-golden-expected.txt` (expect 139 lines / 35 files) | ❌ W0 | ⬜ pending |
| 239-TBD | — | 1 | SURF-03 | Unscoped rewrite (DoS) | Sweep is path-restricted to `priv/templates/` | unit | `grep -nE "$UNION" $(git ls-files priv/templates) \| wc -l` → `0` | ✅ | ⬜ pending |
| 239-TBD | — | 1 | SURF-03 | Rationale erasure | No security rationale sentence deleted | invariance | `scripts/…/237-security-comment-diff-check.sh <phase-diff>` → `examined_removed_lines>0`, exit 0 | ✅ | ⬜ pending |
| 239-TBD | — | 1 | SURF-03 | HEEx render drift | The 17 EEx-escaped sigil lines still compile | compile gate | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 239-TBD | — | 2 | SURF-03 | — | `test/example/` mirror compiles and its suite passes | regression | `MIX_ENV=test mix ci` | ✅ | ⬜ pending |
| 239-TBD | — | 3 | SURF-03 | Re-bless absorbing code | Golden fixture matches the swept templates | contract | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` → exit 0 | ✅ | ⬜ pending |
| 239-TBD | — | 3 | SURF-03 | — | Installer output byte-identical to committed golden | regression | `MIX_ENV=test mix ci.install_golden` | ✅ | ⬜ pending |
| 239-TBD | — | 3 | SURF-01 | — | Freshly generated app greps clean under `lib/`+`priv/` | integration | `GITHUB_WORKSPACE=$(pwd) TMP_APP_DIR=/tmp/sigra_239_app scripts/ci/install-smoke.sh && grep -rn '\.planning/' /tmp/sigra_239_app/lib /tmp/sigra_239_app/priv` | ✅ | ⬜ pending |
| 239-TBD | — | 3 | SURF-01 | — | Built tarball greps clean under `lib/`+`priv/` | integration | `mix hex.build --unpack && grep -rn '\.planning/' sigra-*/lib sigra-*/priv` → 0 | ✅ | ⬜ pending |
| 239-TBD | — | 3 | SURF-01 | Workflow `name:` rewrite | `.github/` untouched | invariance | `git diff --name-only origin/main -- .github/` → empty | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `239-comment-only-diff-check.sh` — SC-3 classifier using **expected-removed-set containment**
      (not a syntactic `^[+-]\s*#` rule: only 80 of 158 token lines are true comments; 57 are
      `@moduledoc`/`@doc` heredoc prose and 17 are EEx-escaped HEEx tags, so a syntactic rule flags
      78 legitimate lines). Must print `changed_lines`, `files`, `nonconforming`, and fail closed on
      empty input (mirror `237-security-comment-diff-check.sh:47-50`).
- [ ] `239-golden-expected.txt` — pre-sweep snapshot of the 139 expected-removed golden lines
      (35 files), captured before the sweep commit and committed alongside the classifier.
- [ ] No framework install needed. No new test files needed — every other assertion rides an
      existing lane (`mix ci`, `ci.install_golden`, `install-smoke.sh`, the 237 script).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `sigra.upgrade/` templates (3 of 46 edited files) | SURF-01 | `install-smoke.sh` never runs `mix sigra.upgrade`; SC-1 structurally cannot reach them, and Standing Constraint forbids building a new harness | Covered by SC-2 (the tarball grep covers `priv/` in full). State the SC-1 coverage boundary explicitly in the SUMMARY. |
| Rendered-HTML equivalence for the 17 HEEx sigil lines | SURF-03 | Assumption A1 — reasoned from EEx/HEEx semantics, not proven by a render diff | Compile gates catch syntax breakage and the golden byte-diff catches any rendered change reaching a generated file. Treat any non-comment line in the re-bless diff for those 7 files as the stop-the-line event D-12 anticipated. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
