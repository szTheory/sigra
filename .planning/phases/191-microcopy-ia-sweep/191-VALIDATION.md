---
phase: 191
slug: microcopy-ia-sweep
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-17
---

# Phase 191 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Authoritative validation detail lives in `191-RESEARCH.md` → `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`mix test`) + Playwright (`npx playwright test`) for admin snapshots |
| **Config file** | `test/test_helper.exs` (ExUnit); `test/example/priv/playwright/playwright.config.ts` (visual) |
| **Quick run command** | `mix test test/sigra/admin/glossary_test.exs test/sigra/admin/components_test.exs` |
| **Full suite command** | `mix test` (requires live Postgres at localhost:5432, postgres/postgres) |
| **Estimated runtime** | ExUnit ~suite-dependent; glossary test < ~2s (source-parse only, no DB) |

> The glossary drift guard (`test/sigra/admin/glossary_test.exs`) is the primary new
> executable evidence (COPY-02). It parses `.ex`/`.heex` source structurally and runs in
> the normal `mix test` job — no extra `ci.yml` step. The monotonic ledger guard
> (`scripts/ci/quality-ledger-monotonic.sh`) gates the ledger raise (COPY-01..03), and
> `scripts/ci/snapshot-recapture-gate.sh` (compare 3/3 + canary `--require-all`) approves
> the in-phase baseline recapture for the 5 affected slugs with zero human review.

---

## Sampling Rate

- **After every task commit:** Run the quick command for the files touched (glossary test once it exists; affected ExUnit goldens).
- **After every plan wave:** Run `mix test` (full suite).
- **Before `/gsd:verify-work`:** Full `mix test` green + recapture gate green for declared slugs.
- **Max feedback latency:** < ~120s for the ExUnit lane.

---

## Per-Task Verification Map

> Populated by the planner from `191-RESEARCH.md` → Validation Architecture + Exhaustive
> String Inventory. Each COPY requirement maps to executable evidence below.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (planner fills) | — | — | COPY-01 | T-191-01 (enumeration boundary) | Auth/reset/magic-link error copy stays uniform/generic | unit | `mix test test/sigra/admin/glossary_test.exs` | ❌ W0 | ⬜ pending |
| (planner fills) | — | — | COPY-02 | — | One-term-per-concept glossary; banned synonyms fail the drift guard | unit | `mix test test/sigra/admin/glossary_test.exs` | ❌ W0 | ⬜ pending |
| (planner fills) | — | — | COPY-03 | — | Consistent empty/success/warning tone; ledger monotonic-raised | guard | `scripts/ci/quality-ledger-monotonic.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/admin/glossary_test.exs` — new source-parsing drift guard (COPY-02); honors the
      `branding_live.ex` ~580–610 `sigra-auth--preview` carve-out (D-09).
- [ ] `guides/reference/admin-glossary.md` — the machine-parseable canonical-term + banned-aliases
      table the test reads.

*Existing ExUnit + Playwright infrastructure covers everything else.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | — | — | — |

*All phase behaviors have automated verification (glossary ExUnit test + recapture gate + monotonic ledger guard). Zero-human UAT per project preference.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (glossary doc + glossary test)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
