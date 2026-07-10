---
title: Harden app.css corruption guard against mid-block orphan values
status: pending
resolves_phase: 221
created: 2026-07-02
source: phase-214 verification (W1)
requirement: DEBT-05 (follow-up)
severity: low
---

## What

`scripts/ci/app-css-corruption-check.sh` (added in phase 214-03) detects an
orphaned bare value fragment when it appears as the **first** line inside a
`:root` block, but MISSES one placed immediately **after** a terminated
`property: value;` declaration.

Root cause: the awk `last_was_prop` flag is not reset when a declaration ends
in `;`. An orphan on the next line therefore reads as a legitimate multi-line
property continuation and the guard exits 0 (should exit 1).

Verified during phase-214 verification: injecting an orphan as the first
`:root` line → guard correctly fails; injecting one right after a `;`-terminated
declaration → guard passes (false negative).

## Why deferred, not hot-fixed in 214

The live `app.css` is clean and browser-parse-verified (388 rules), so this is a
regression-guard hardening gap, not a live defect. The fix touches the same awk
context-tracking logic that 214-03 deliberately tuned to avoid false-positives
on legitimate multi-line `--vt-shadow` / `--vt-transition` continuations.
Changing it hastily risks breaking CI on valid CSS. Wants its own small,
test-driven change (add a fixture for the mid-block orphan case).

## Suggested fix

Reset `last_was_prop` to 0 on any line whose trimmed content ends in `;`
(declaration terminated), then re-flag only on a genuine `property:` opener.
Add a corruption fixture covering the "orphan after `;`-terminated declaration"
case and assert exit 1.
