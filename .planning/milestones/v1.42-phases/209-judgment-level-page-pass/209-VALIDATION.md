---
phase: 209
slug: judgment-level-page-pass
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-30
---

# Phase 209 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `209-RESEARCH.md` § Validation Architecture (verified against live guards/config).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Playwright (browser baselines) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts`; ExUnit via `mix test` |
| **Quick run command** | `mix test test/sigra/admin/glossary_test.exs` |
| **Full suite command** | `mix test` + CI Playwright checkpoint/design lanes + `fast_checks` guards |
| **Estimated runtime** | ~30s (glossary + monotonic guard); full CI lanes minutes |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/admin/glossary_test.exs` + `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main`
- **After every plan wave:** Run the full `fast_checks` guard set (`snapshot-canary-guard.sh` checkpoint + design, `quality-ledger-monotonic.sh`, self-test)
- **Before `/gsd-verify-work`:** ubuntu CI checkpoint recapture green, both allowlists empty, canary byte-stable, PR #63 `fast_checks` lane green
- **Max feedback latency:** ~30 seconds (local guards); CI lanes gate the phase

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 209-panel | panel | 1 | PAGE-01 | — | 8 docs + roll-up exist, schema-valid, column-4 clean | doc-lint / guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ | ⬜ pending |
| 209-copy | remediation | 2 | PAGE-02 | — | Copy remediations pass glossary; no banned synonyms | unit | `mix test test/sigra/admin/glossary_test.exs` | ✅ | ⬜ pending |
| 209-tier | remediation | 2 | PAGE-02 (SC-3) | — | No Tier-2 page regresses | guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ | ⬜ pending |
| 209-baseline | recapture | 3 | PAGE-02 (SC-4) | — | Touched slugs recaptured; canary byte-stable; allowlists empty | guard | `bash scripts/ci/snapshot-canary-guard.sh --base origin/main` (+ design lane) | ✅ (recapture JOB = OQ-3) | ⬜ pending |
| 209-render | remediation | 2 | PAGE-02 | — | Remediated pages still render/behave | browser | `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **Checkpoint-lane CI recapture job** (OQ-3) — `admin_design_recapture` exists in `.github/workflows/ci.yml`; the checkpoint analog does NOT. If the plan chooses CI-native checkpoint recapture (D-09 forbids darwin), an early-wave enabler task must add the ubuntu-native mechanism (mirror `admin_design_recapture`).
- [ ] No new ExUnit test files required — `glossary_test.exs` already scopes all 8 LiveViews + `components.ex`; existing checkpoint/modal/flow specs cover behavior.

*Otherwise: Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Adversarial persona/JTBD verdict quality (forced-finding floor, DOM anchors) | PAGE-01 | Judgment cannot be asserted by an automated test — the rubric requires human/agent adversarial reading against live DOM | Follow `guides/reference/admin-persona-jtbd-rubric.md` verbatim; every (lens × question) cell holds a DOM-anchored finding or the `NONE — searched for: <what>` token |
| Waiver rationale correctness (intentional asymmetries) | PAGE-02 | Whether an asymmetry is "intentional/documented" is a design judgment | Per-surface doc must carry `Waiver: <rationale>` for each non-fixed actionable verdict (D-07) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (OQ-3 checkpoint recapture job)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (local guards)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
