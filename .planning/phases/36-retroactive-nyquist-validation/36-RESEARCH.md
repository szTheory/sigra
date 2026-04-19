# Phase 36 — Research

**Status:** Skipped (orchestrator — `gsd-sdk query` unavailable; scope is planning-artifact hygiene).

## Summary

Nyquist validation in this repo means each phase owns a `*-VALIDATION.md` with YAML frontmatter (`nyquist_compliant`, `status`, `wave_0_complete` where applicable), test infrastructure table, sampling expectations, and a per-task map when the phase contains code tasks. Historical phases from v1.0–v1.1 often left `status: draft`. v1.2 execution phases (27–35) trend toward complete artifacts but some remain draft. **999.1** is satisfied by inventory + (file fix **or** centralized waiver with superseding pointer), not by re-running old phase code.

## Validation Architecture

Phase 36’s own execution is **documentation-only**. Feedback loops are:

1. **Regenerate inventory** — shell `find` + `test -f` / `rg` for draft markers.
2. **Grep acceptance** — each plan lists exact `grep`/`test` commands proving files exist and frontmatter keys exist.
3. **No Wave 0 code** — “Existing infrastructure” for ExUnit already covers the product; this phase does not add new `test/` modules unless a later task explicitly scopes one (out of current plans).

## RESEARCH COMPLETE
