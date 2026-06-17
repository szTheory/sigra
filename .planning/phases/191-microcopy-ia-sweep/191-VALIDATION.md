---
phase: 191
slug: microcopy-ia-sweep
status: approved
nyquist_compliant: true
wave_0_complete: true
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
| 191-01 T1 | 01 | 1 | COPY-02 | — | Glossary doc lists every canonical term + banned alias (single source of truth for the guard) | source | `test -f guides/reference/admin-glossary.md && grep -c "Canonical" guides/reference/admin-glossary.md` | ❌ W0 | ⬜ pending |
| 191-01 T2 | 01 | 1 | COPY-02 | T-191-01 (enumeration boundary) | Source-parsing drift guard; honors the branding_live auth-preview carve-out; no auth-boundary string made more specific | unit | `mix test test/sigra/admin/glossary_test.exs` | ❌ W0 | ⬜ pending |
| 191-02 T1 | 02 | 2 | COPY-01, COPY-03 | T-191-01 | Banned synonyms replaced on global vs org surfaces (user ≠ member); empty/warning tone consistent | source | `grep` violation count == 0 (true gate) | ✅ | ⬜ pending |
| 191-02 T2 | 02 | 2 | COPY-01, COPY-02, COPY-03 | T-191-02 (no leaked internals / WR-04) | inspect/1 leak removed at branding_live.ex:731; guard GREEN; @notice_golden updated same-diff | unit | `mix test test/sigra/admin/glossary_test.exs test/sigra/admin/components_test.exs` | ✅ | ⬜ pending |
| 191-03 T1 | 03 | 3 | COPY-01, COPY-03 | — | branding-live L3 row appended; D9/D10 re-score increase-only | guard | `scripts/ci/quality-ledger-monotonic.sh` | ✅ | ⬜ pending |
| 191-04 T1 | 04 | 4 | COPY-01, COPY-03 | — | Recapture 5 affected slugs × 3 projects; canaries never allowlisted; allowlist reset to empty | visual | `scripts/ci/snapshot-recapture-gate.sh <5 slugs>` | ✅ | ⬜ pending |

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

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (glossary doc + glossary test — created in Wave 1 / Plan 01 before Plan 02 consumes them)
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-17
