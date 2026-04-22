# Phase 51: Install golden receipt & CI merge coupling — Context

**Created:** 2026-04-21 (gap closure from `/gsd-plan-milestone-gaps` on `v1.4-MILESTONE-AUDIT.md`)  
**Status:** Ready to execute (2× `*-PLAN.md`; `50-VERIFICATION.md` uses CI-as-truth — do not resurrect pasted **PASS** rows)

## Scope

Closes audit YAML integration gaps **PHASE-50-INSTALL-GOLDEN**, **CI-PATH-COUPLING**, **GA-WAIVERS-vs-INSTALL-RECEIPT**, and the related **flows** (PR regression without installer contract; local merge gate receipt for **50-VERIFICATION**).

**Primary artifacts:** `.planning/phases/50-nyquist-ci-gate-hygiene/50-VERIFICATION.md`, CI workflows / `mix` aliases, short cross-link from GA waiver evidence to install-golden attestation.

**Out of scope:** Re-opening discrete **GA-01..AUD-08** product requirements (already satisfied); this phase is **process + CI + attestation** only.
