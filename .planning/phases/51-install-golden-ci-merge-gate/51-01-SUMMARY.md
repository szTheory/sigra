---
phase: 51-install-golden-ci-merge-gate
plan: "01"
subsystem: infra
tags: [github-actions, ci, installer-golden]

requires: []
provides:
  - Extended PR diff detector for install_golden_contract and installer_milestone_audit
  - ExUnit structural lock on detector parity
affects: []

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - test/sigra/planning/phase_51_install_golden_ci_contract_test.exs
  modified:
    - .github/workflows/ci.yml
    - MAINTAINING.md

key-decisions:
  - "Limit path extensions to mfa/oauth/account/passkeys under lib/sigra per phase research."

patterns-established:
  - "Both installer jobs share one canonical grep -qE pattern; tests count escaped literal occurrences."

requirements-completed: []

duration: 5min
completed: 2026-04-21
---

# Phase 51 plan 01 — Installer PR path detector

Widened the GitHub Actions PR diff gate so changes under **`lib/sigra/mfa`**, **`oauth`**, **`account`**, and **`passkeys`** run the same installer golden and milestone audit jobs as template/install path edits, with **`MAINTAINING.md`** documentation and a fast ExUnit parity check.

## Task commits

1. **Task 1: ci.yml** — `3e848d2` — `ci(51-01): extend installer PR path detector for MFA/OAuth/account/passkeys`
2. **Task 2: MAINTAINING.md** — `adc7be1` — `docs(51-01): document PR paths for install_golden_contract (phase 51)`
3. **Task 3: ExUnit contract** — `df504a3` — `test(51-01): lock installer path detector parity across CI jobs`

## Self-check

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` — PASS
- `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` — PASS

## Self-Check: PASSED
