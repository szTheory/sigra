# Phase 137 — Learnings

## Milestone-boundary assessment (2026-05-29)

Recorded here because it was produced during Phase 137 execution (v1.30 still in flight). A milestone
next-step + adoption-evidence assessment ran 3 parallel repo-inspection passes (planning truth,
lib/+tests reality check, adoption evidence). Full investigation lives in the thread
`.planning/threads/adoption-evidence-and-demo-showcase.md`.

### Findings

- **Done-band: 90–95% (near-done / diminishing returns soon) for stated scope.** Every major auth
  flow is real and tested in `lib/`; ~2252 lib tests + 236-test example app + install-golden +
  greenfield install-smoke + 11-spec Playwright golden-path + 977-line CI with a dep-off lane.
- **Adoption evidence is NOT a blocker.** The E2E / install-verification / happy-path automation
  backbone already exists and is strong. The genuine gap is narrow: an empty
  `test/example/priv/repo/seeds.exs` and the absence of an evaluator-facing demo *showcase*
  (realistic domain/personas, one-command populated spin-up, screenshots).
- **Next build wedge = "Demo Showcase"** (extend `test/example/`, not a new repo). The unbuilt
  remainder of SUITE-INTEGRATION's "reference starter app" (MILESTONE-ARC.md:205).
- **Doc drift noted:** working branch `v1.28-data-lifecycle` stale vs active v1.30; STATE.md progress
  block stale vs git (137-02/137-03 merged).

### Graduation candidates (cross-phase — promote when next milestone opens)

1. **"Adoption is the bottleneck, not features."** Sigra is feature-done for its scope; the honest
   constraint on "is it done?" is the lack of real adopters. Future milestone selection should weight
   the 1.0 Hex cut + adoption push above further feature wedges. → candidate for PROJECT.md North Star
   / Selection Guidance.
2. **"Demo Showcase = evaluator conversion surface; reuse `test/example/` + existing E2E/CI infra."**
   The example app already proves correctness; the missing piece is its use as an *evaluation funnel*
   for the README "Evaluating" lane. Low net-new code, high adopter leverage. → candidate for
   MILESTONE-ARC.md Candidates (added 2026-05-29) and Selection Guidance ordering.
