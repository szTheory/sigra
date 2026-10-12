# API Coverage — Phase 250 release evidence

> Full coverage by default for the external capabilities this phase uses. This is a scope decision, not proof that the hosted or owner-verification gaps have passed.

The integration surface is GitHub's repository and Actions API for immutable evidence, an isolated receipt canary, and CI/PR reconciliation; Hex and HexDocs are read-only public release sources. The endpoint families below cover that complete Phase 250 use case. Production release and publishing operations are excluded by D-05/D-08 and the phase boundary.

| capability | decision | reason |
|---|---|---|
| GitHub GET repository, branch commit, commit/tree/blob and manifest | INTEGRATE | |
| GitHub GET workflow, Actions permissions and artifact retention | INTEGRATE | |
| GitHub GET exact workflow run, run attempt, jobs and failed-run logs | INTEGRATE | |
| GitHub GET workflow-run lists for exact dispatch/observer correlation | INTEGRATE | |
| GitHub GET exact run artifact lists and artifact ZIP by artifact ID | INTEGRATE | |
| GitHub POST dispatch for the allowlisted canary source and controller workflows | INTEGRATE | |
| GitHub POST cancel for the controller-owned, exact canary run ID | INTEGRATE | |
| GitHub GET protected-environment names and policies, without secret values | INTEGRATE | |
| GitHub GET complete PR population and exact PR head/base identities | INTEGRATE | |
| GitHub GET REST rate-limit status before long watches | INTEGRATE | |
| Hex GET Sigra 1.6.0 release metadata and checksum | INTEGRATE | |
| HexDocs GET versioned 1.6.0 documentation and exact source URL | INTEGRATE | |
| GitHub workflow rerun or cancellation of a production/unowned run | OPT-OUT | D-05/D-06 permit only a fresh authorized canary and cancellation of its own exact child. |
| GitHub release, tag, ref or PR write/merge endpoints | OPT-OUT | Phase 250 closes evidence; D-05 excludes release, tag and PR authority from the canary. |
| GitHub secret-value read/write and deployment or publishing environments | OPT-OUT | D-03/D-05 permit name-and-policy inspection only and forbid canary publish credentials. |
| Hex publish or package mutation API | OPT-OUT | Phase 250 is non-publishing evidence closure under D-05. |
| Scheduled or recurring canary dispatch | OPT-OUT | D-08 requires bounded on-demand proof and defers periodic execution. |

An `INTEGRATE` decision means the existing or planned path must be verified against exact source identity. Plans 250-07–12 still require their own missing evidence; this matrix does not change their halted or blocked status.
