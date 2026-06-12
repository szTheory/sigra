---
phase: 179
slug: outlining-toolchain-logo-concept-exploration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-12
---

# Phase 179 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (brand toolchain phase) — structural/scripted validation |
| **Config file** | n/a |
| **Quick run command** | `node scripts/brand/outline-wordmark.mjs` smoke run exits 0 |
| **Full suite command** | Machine-verifiable check table below |
| **Estimated runtime** | ~15 seconds (incl. one script run) |

---

## Sampling Rate

- **After every task commit:** Quick run command (or `ls` of the task's output file)
- **After every plan wave:** Full check table below
- **Before `/gsd:verify-work`:** All checks green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 179-01-* | 01 | 1 | BRAND2-04 | — | No font binaries in git | script | outline script run exits 0 and emits valid SVG with ≥5 `<path>` glyphs and `Font:` provenance in `<desc>`; `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2'` empty | ❌ W0 | ⬜ pending |
| 179-02-* | 02 | 2 | BRAND2-05 | — | N/A | ls+render | `ls brandbook/logo-options/round-3/*.svg \| wc -l` in [5,14] (5–7 candidates × light/dark variants where applicable); each candidate has a recorded render-critique pass (harness screenshots reviewed at 16/32/54/hero, light+dark) | ❌ W0 | ⬜ pending |
| 179-02-* | 02 | 2 | BRAND2-06 | — | N/A | parse+grep | round-3 `index.html` parses, links `../../tokens.css` exactly once, shows favicon-scale previews; `README.md` rationale table ≥ 6 pipe-rows | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/brand/package.json` — opentype.js dependency declaration
- [ ] `scripts/brand/outline-wordmark.mjs` — toolchain script
- [ ] `.gitignore` entries for `scripts/brand/fonts/` and `scripts/brand/node_modules/`
- [ ] `brandbook/logo-options/round-3/` directory

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Candidate aesthetic quality vs rubric | BRAND2-05 | Optical judgment cannot be grepped | Executor self-critiques every candidate's harness screenshots against the brief's 6-row rubric BEFORE gallery inclusion; orchestrator spot-reads the critique notes; final judgment is the Phase 180 human gate |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
