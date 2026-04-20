# Phase 38 — Pattern map (evidence + planning docs)

## REPO — Canonical planning doc

**Analog:** `.planning/phases/37-actions-dependency-hygiene/37-01-PLAN.md` — YAML frontmatter + `<objective>` + `<tasks>` with `<read_first>`, `<acceptance_criteria>`, `<threat_model>`.

**Apply to:** `38-01-PLAN.md`, `38-02-PLAN.md` — same envelope; tasks reference markdown paths instead of YAML workflows.

---

## REPO — Prior human UAT results shape

**Analog:** `.planning/v1.0-UAT-RESULTS.md` (referenced from `scripts/uat/RUNBOOK.md`) — checkbox narrative + environment notes.

**Apply to:** `.planning/v1.3-HUMAN-UAT.md` — elevate to **master table** per D-38-09 (single source of truth, not prose-only).

---

## REPO — Evidence index

**Analog:** Phase verification inventories (e.g. `36-INVENTORY.md`) — table of paths + status.

**Apply to:** `.planning/uat-evidence/v1.3.0/INDEX.md` — list every subdirectory asset with owner/date + link to waiver rows.

---

## REPO — UAT harness entrypoints

| File | Role |
|------|------|
| `scripts/uat/up.sh` | Postgres + example deps |
| `scripts/uat/RUNBOOK.md` | Human steps, mailbox URL `http://localhost:4000/dev/mailbox` |
| `test/example/` | Default host (D-38-11) |
| `guides/introduction/getting-started.md` | SEED item 8 target |

---

## CODE — Automation baseline (contrast in waivers)

**Analog:** `test/example/priv/playwright/tests/golden-path.spec.ts`

**Apply to:** Waiver text must cite **what Playwright already proves** vs what remains human-only.
