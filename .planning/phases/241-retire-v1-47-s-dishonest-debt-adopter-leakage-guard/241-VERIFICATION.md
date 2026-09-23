---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
verified: 2026-09-23
status: human_needed
score: 4/5 roadmap criteria verified
behavior_unverified: 1
human_verification:
  - test: "Provide a green CI run URL for the full `mix ci` suite at final Phase 241 HEAD `af724d1b`, or authorize publishing this execution branch so CI can run it."
    expected: "A retry-free CI run at head SHA af724d1b completes successfully, including the protected library suite; the run URL is recorded in 241-01-EVIDENCE.md in place of its PENDING marker."
    why_human: "The Phase 241 checkout branch is local and 37 commits ahead of origin; no exact-HEAD CI run exists. Publishing that branch is an external repository change. The existing evidence names local Threadline environmental failures, so a local filtered run cannot substitute for the requested CI result."
---

# Phase 241 verification — outcome and remaining evidence

## Verification stance

All plan summaries and evidence were treated as claims and compared with the current implementation
and test output. Four roadmap criteria have attributable evidence. SC-1's implementation and
focused contracts are present, but its required full-suite CI receipt is still marked pending in
`241-01-EVIDENCE.md`; the verifier cannot treat the missing run as green.

## Roadmap success criteria

| Criterion | Status | Evidence |
|---|---|---|
| SC-1 — ADR supersession, formatter removal, unchanged alias, and green full library suite | UNCERTAIN | ADR 004 and deletion are present; focused Phase 233 and alias contracts pass. `241-01-EVIDENCE.md` explicitly says `CI run URL: PENDING`. No CI run at final HEAD `af724d1b` was found. |
| SC-2 — replacement contract fails first on committed two-owner workflow fixture and retires/retains receipt deliberately | VERIFIED | `241-02-EVIDENCE.md`: fixture RED names both owners; real workflow passes; empty/missing subjects fail closed; compile warnings-as-errors passes; Phase 235's two receipt readers pass. |
| SC-3 — honest-skip parity guard catches the stale documentation citation and the manifest no longer cites a missing file | VERIFIED | `241-03-EVIDENCE.md`: p21 was observed RED on the stale content and fixture; corrected-document guard passes; full prohibition glob and Phase 236 regression pass. |
| SC-4 — composite action pinning guard covers bare and dashed `uses:` forms | VERIFIED | `241-04-EVIDENCE.md`: both committed fixtures produce attributable REDs and the real action tree passes the focused 10-test contract. |
| SC-5 — adopter leakage guards and three independent monotonic ratchets | VERIFIED | `241-05-EVIDENCE.md` and `241-06-EVIDENCE.md`; final verification run: 102 prohibition tests pass; Python and JS doc-range totals both 337; baselines 337/220/58 pass; each modified-baseline fixture fails exactly one counter; security-rationale count is 52. |

**Result: 4/5 verified, 1 human-needed.**

## Requirement traceability

| Requirement | Status | Evidence |
|---|---|---|
| DEBT-01 | SATISFIED | ADR 004 and the formatter retirement recorded in 241-01 artifacts. |
| DEBT-02 | SATISFIED | Derived single-owner invariant and attributable fixture RED in 241-02 artifacts. |
| DEBT-03 | SATISFIED | p21 guard and corrected manifest/document evidence in 241-03 artifacts. |
| DEBT-04 | SATISFIED | Composite action guard directions proven in 241-04 artifacts. |
| SURF-04 | SATISFIED | Three p18 hard-fail classes and independent ratchets implemented in Plans 241-05/06; REQUIREMENTS.md reflects completion. |

## Human verification required

Provide the green full-suite CI run URL for SHA `af724d1b`, or authorize publishing the isolated
execution branch so the exact commit can be tested by CI. The branch currently has no remote ref,
and no run exists at that SHA. Once a matching successful run is recorded in `241-01-EVIDENCE.md`,
re-run phase verification and close out the phase.
