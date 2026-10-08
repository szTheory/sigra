---
phase: "247"
slug: "release-candidate-and-repository-readiness"
status: passed
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-06"
audited: "2026-10-08"
---

# Phase 247 — Validation Strategy

> Deterministic ledger checks, exact-source CI, the curated adopter documentation, unpacked package evidence, and an authenticated non-publishing Hex dry run pass for the current reviewed source. The release candidate remains open and unpublished for the independent Phase 247 verifier to assess.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node.js built-in test runner for the phase validator; Mix/Hex and required GitHub CI for candidate/package evidence |
| **Config file** | `validate-release-readiness.mjs`; `mix.exs`; `.github/workflows/ci.yml` |
| **Focused command** | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` |
| **Final ledger command** | `node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage final .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` |
| **Candidate package commands** | `cd tmp/phase-247-candidate && mix hex.publish --dry-run --yes`; `cd tmp/phase-247-candidate && mix hex.build --unpack --output tmp/sigra-hex-inspect` |
| **Exact-source CI** | PR #224 head `d76d7f2306f6099063a80a420d2d8a4e04c7785f`; required run `37800067568` passed |

## Per-Task Verification Map

| Task ID | Requirement | Behavior under test | Test type | Command / evidence | Result |
|---------|-------------|----------------------|-----------|-------------------|--------|
| 247-01-01 | READY-02 | Reject omitted live PRs and duplicate stable path keys; accept explicit empty sets only when fresh observations are empty; preserve immutable entry snapshot. | Unit/contract | Focused suite | **green** — tests 1–4, 19 |
| 247-01-02 | READY-02 | Candidate worktree must be clean and pinned to reviewed source with exact Phase 246 evidence. | Unit/contract + live ledger | Focused suite; final live validator | **green** — test 5 passes; candidate worktree is clean at the recorded source SHA |
| 247-02-01 | READY-01 | Candidate version, PR/base/main/tested SHAs and exact-source promotion evidence must agree; stale identity and unreviewed non-fast-forward changes reject. | Unit/contract + exact-source CI | Focused suite; PR #224 run `37700772880` at `563f411bc2659bb9ac1652d552ce58ffb0c876b1` | **green** — tests 6, 8–9, 11–14; exact required CI passed |
| 247-02-02 | READY-01 | Candidate changelog summary and ExDoc source reference match the release version; misplaced summary rejects. | Unit/contract + CI docs build | Focused suite; required run `37700772880` | **green** — tests 7, 10; warning-free docs build passed in exact-head CI |
| 247-03-01 | READY-01 | README → v1.6 guide → 1.6.0 changelog path and source/evidence-backed adopter claims. | Unit/contract + CI docs build | Focused suite; required run `37700772880`; `git show --check` at candidate head | **green** — test 17; exact-head docs build passed |
| 247-04-01 | READY-01, READY-02 | Final readiness rejects missing dry-run evidence, changed candidate head, broken links, incomplete dispositions, and unresolved severe findings. | Unit/contract + live final ledger | Focused suite; final ledger command | **green** — 24/24 tests pass and live final validator is ready |
| 247-04-package | READY-01 | Build and inspect unpacked 1.6.0 package; publish dry run validates candidate package metadata. | Package integration | `mix hex.build --unpack --output tmp/sigra-hex-inspect` | **green** — 1.6.0 metadata, README, CHANGELOG, and package contents were inspected |
| 247-04-docs | READY-01 | Candidate documentation builds without warnings at exact locked dependencies. | Package integration | `mix docs --warnings-as-errors` with isolated `/private/tmp` dependency/build paths | **green** — exit 0; generated HTML and Markdown docs |
| 247-04-dry-run | READY-01 | Hex validates the exact 1.6.0 candidate without publishing. | Protected workflow integration | Trusted-main run `37803817504`, artifact `247-HEX-DRY-RUN-RECEIPT.json` | **green** — authenticated dry run succeeded; boolean-only key-presence evidence and 404 before/after are recorded |

## Adversarial Test Execution

```text
node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
tests 24 | pass 24 | fail 0 | skipped 0 | exit 0
```

The tests cover omitted and duplicate populations, explicit empty sets, candidate identity and metadata, stale refs, non-fast-forward movement, source promotion/CI receipts, broken adopter links, missing or stale dry-run evidence, exact evidence-only main movement, incomplete dispositions, and final readiness rejection. Regression cases prove incomplete planning/evidence dispositions are refreshed while unrelated source paths remain fail-closed.

The exact candidate lockfile resolved with `mix deps.get --check-locked` in an isolated `/private/tmp` Mix/Hex environment. All 65 locked packages resolved at their recorded versions; the candidate lockfile and worktree remained unchanged. Local `mix docs --warnings-as-errors` then passed. The dry-run built the Sigra 1.6.0 package summary but Hex 2.5.1 exited 1 because the isolated Hex home has no authenticated user/API key. The [Hex task source](https://github.com/hexpm/hex/blob/v2.5.1/lib/mix/tasks/hex.publish.ex#L1657-L1777) shows the owner lookup still runs before the dry-run skips uploading the package.

Final readiness passed at `2026-10-08T16:05:38.855Z`. The validator checked PR #224 head `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, reviewed base `d135cbce343947499a0810736c500ef5f1cb5c32`, trusted main `a494f3ee3878da93aab4f70712ffddeefd77a802`, exact-head CI run `37800067568`, authenticated dry-run run `37803817504`, candidate cleanliness, docs/package evidence, and current inherited inventory (400 commits, 1,301 paths, 14 open PRs). It requires the separate trusted checkout to be clean at the exact observed live-main SHA and accepts only the four evidence paths in the reviewed-base-to-main advance. The primary shared checkout was left untouched.

## Exact-Source Evidence

PR #224 remains open at exact head `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, based on reviewed main `d135cbce343947499a0810736c500ef5f1cb5c32`. Required CI run `37800067568` passed on that head. The unpacked Hex package and warning-free docs build passed at that source. Trusted-main run `37803817504` passed the authenticated `mix hex.publish --dry-run --yes` without publishing.

## Blocker and Forward Evidence Route

The readiness validator now passes. The first trusted-main dispatch `37803560621` stopped before authentication because the merged evidence PR's pre-merge ref had been deleted. Recovery restored only the exact verified evidence ref, and the single bounded retry passed. The failure and recovery are documented in [247-08-DRY-RUN-RECOVERY.md](./247-08-DRY-RUN-RECOVERY.md). The remaining phase-level judgment belongs to the independent verifier; this report does not claim the release candidate was merged or published.

| Gap | Classification | Required evidence |
|-----|----------------|-------------------|
| Independent phase verification | **FOLLOW-UP** | Run the normal Phase 247 verifier against the current ledger and review its evidence-based result. |

## Validation Sign-Off

- [x] Focused deterministic validator suite passed; 25/25.
- [x] Meaningful validator acceptance/rejection cases are covered, including the dirty planning-path regression.
- [x] Exact-source required CI, unpacked Hex package, and local warning-free docs evidence are recorded.
- [x] Latest live inherited inventory has complete dispositions.
- [x] Authenticated `mix hex.publish --dry-run --yes` passes for the exact candidate without publishing.
- [x] Final validator passes and READY-01/READY-02 are ready for independent verification.
- [x] `nyquist_compliant: true` — deterministic acceptance and rejection evidence is present.
