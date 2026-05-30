---
phase: 144
slug: readme-evaluator-lane-docs-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 144 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | mix test + shell grep assertions (documentation phase) |
| **Config file** | mix.exs |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test`
- **After every plan wave:** Run `mix docs --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite + ExDoc build must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 144-01-01 | 01 | 1 | DOC-01 | — | N/A | grep | `grep -q "Try it locally" test/example/README.md && grep -q "mix setup" test/example/README.md` | ✅ | ⬜ pending |
| 144-01-02 | 01 | 1 | DOC-01 | — | N/A | grep | `grep -q "admin@demo.sigra.dev" test/example/README.md && grep -q "alice@demo.sigra.dev" test/example/README.md` | ✅ | ⬜ pending |
| 144-01-03 | 01 | 1 | DOC-01 | — | N/A | grep | `grep -q "/demo/credentials" test/example/README.md && grep -q "/dev/mailbox" test/example/README.md` | ✅ | ⬜ pending |
| 144-01-04 | 01 | 1 | DOC-01 | — | N/A | grep | `grep -q "dave" test/example/README.md && grep -q "frank" test/example/README.md` | ✅ | ⬜ pending |
| 144-02-01 | 02 | 1 | DOC-02 | — | N/A | file | `ls guides/assets/demo-credentials-demo-showcase-chromium.png guides/assets/admin-user-detail-demo-showcase-chromium.png guides/assets/admin-user-list-demo-showcase-chromium.png guides/assets/audit-explorer-demo-showcase-chromium.png` | ❌ W0 | ⬜ pending |
| 144-02-02 | 02 | 1 | DOC-02 | — | N/A | grep | `grep -q "demo-credentials-demo-showcase-chromium" guides/introduction/demo-showcase.md` | ❌ W0 | ⬜ pending |
| 144-02-03 | 02 | 1 | DOC-02 | — | N/A | mix | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 144-03-01 | 03 | 2 | DOC-03 | — | N/A | mix | `mix test` | ✅ | ⬜ pending |
| 144-03-02 | 03 | 2 | DOC-03 | — | N/A | grep | `grep -q "144-VERIFICATION" docs/ga-evidence.md` | ✅ | ⬜ pending |
| 144-03-03 | 03 | 2 | DOC-03 | — | N/A | file | `test -f .planning/phases/144-readme-evaluator-lane-docs-proof/144-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/assets/` directory created
- [ ] 4 PNG files copied from `test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/` to `guides/assets/`
- [ ] `guides/introduction/demo-showcase.md` file created (Wave 1 task)

*Tasks 144-02-01 and 144-02-02 depend on Wave 0 file creation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Clean-state `mix setup` from scratch | DOC-03 Gate 3 | Requires `mix ecto.drop` + full DB recreation — destructive, not safe to run automatically mid-suite | `cd test/example && mix ecto.drop && mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs` |
| Dep-off CI lane | DOC-03 Gate 2 | Modifies lock file state (`deps.unlock`/`deps.clean`) — disruptive to automate | Follow 140-03-PLAN.md dep-off lane procedure verbatim |
| ExDoc rendered output | DOC-02 | Visual inspection — images render correctly at correct paths | `mix docs && open doc/index.html`, navigate to Demo Showcase guide |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
