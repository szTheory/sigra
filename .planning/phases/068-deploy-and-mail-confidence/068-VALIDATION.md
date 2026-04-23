---
phase: 68
slug: deploy-and-mail-confidence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 68 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (documentation phase).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / Mix (no new test framework) |
| **Config file** | `mix.exs` (ExDoc extras unchanged unless plan explicitly adds files) |
| **Quick run command** | `MIX_ENV=dev mix compile --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` (optional if zero Elixir code touched); **`MIX_ENV=dev mix docs --warnings-as-errors`** is mandatory after markdown under `guides/` or `README.md` changes |
| **Estimated runtime** | ~2–15 minutes (docs + full test at executor discretion) |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=dev mix compile --warnings-as-errors`
- **After every plan wave:** Run `MIX_ENV=dev mix docs --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full docs build green; spot-check new anchors
- **Max feedback latency:** 120 seconds (docs-only)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 68-01-01 | 01 | 1 | ACF-01 | T-68-01 / T-68-02 | Checklist does not claim certification; links to OWASP/Phoenix for mechanics | grep + docs | `grep -F '## Production checklist (read first)' guides/recipes/deployment.md` | ✅ | ⬜ pending |
| 68-01-02 | 01 | 1 | ACF-04 | T-68-03 | Honest Oban vs inline; at-least-once footgun named | grep | `grep -iF 'Oban' guides/recipes/deployment.md` AND `grep -iF 'inline' guides/recipes/deployment.md` | ✅ | ⬜ pending |
| 68-02-01 | 02 | 2 | ACF-01 | T-68-01 | Five inbound pointers to deployment checklist anchor | grep | `grep -cF 'guides/recipes/deployment.md' README.md guides/introduction/*.md MAINTAINING.md` (count ≥ agreed threshold in plan) | ✅ | ⬜ pending |
| 68-02-02 | 02 | 2 | ACF-04 | — | `mix help sigra.install` alignment | manual + grep | Executor captures help output; grep for documented switches | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **Existing infrastructure covers all phase requirements** — no new `test/` stubs required unless an executor task adds Elixir code (not expected).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ExDoc anchor resolution | ACF-01 | ExDoc slug rules vary slightly by version | Run `mix docs`, open `doc/deployment.html`, confirm checklist section in TOC and fragment in browser |
| Readability (≤2 min scan) | ACF-01 | Subjective length | Human: start at checklist H2; confirm matrix ≤12 rows per CONTEXT |

---

## Validation Sign-Off

- [ ] All tasks have grep/`mix docs` verify or documented manual steps
- [ ] Sampling continuity: no three consecutive tasks without automated verify
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution completes

**Approval:** pending
