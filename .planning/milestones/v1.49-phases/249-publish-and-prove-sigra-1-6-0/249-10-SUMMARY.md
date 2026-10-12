---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 10
subsystem: release-automation
tags: [github-actions, release-please, ex-doc, security, ci]
requires:
  - phase: 249-09
    provides: ten-path source-bound release candidate on current protected main
provides:
  - reviewed fourteen-path local candidate ready for Plan 11
  - trusted-main docs refresh integration and exact-head writer checks
  - regression coverage against symlinked candidate write destinations
affects: [release-automation, phase-249-promotion]
requirements-completed: []
key-decisions:
  - Keep the docs build unprivileged and transfer only the validated generated index plus candidate identity.
  - Reject both a symlinked doc directory and a symlinked doc/llms.txt in the candidate before the privileged writer copies the generated artifact.
  - Preserve the package-source receipt byte-for-byte; its SHA and original successful CI identity remain separate from candidate and main heads.
  - Run the full contributor gate outside the command sandbox because two existing Phase 235 tests invoke sandbox-exec, which the sandbox rejects.
  - Keep known baseline actionlint/ShellCheck diagnostics explicit; no unrelated lint cleanup was added.
actuals:
  duration: 74min
  tasks: 2
  commits: 1
  files_changed: 4
  candidate_head: 10246c8dbcc2acd3c49432844e84a34ae0bd01c1
  candidate_base: e2fa303017364c7e496c3c620f7b709c8e90c8fb
  candidate_paths: 14
---

# Phase 249 Plan 10: Complete and Review the Release Candidate

**The isolated release candidate now includes the trusted Release Please docs refresh path, passes the contributor gate, and contains exactly fourteen scoped paths.**

## Accomplishments

- Added the Plan 03 Release Please candidate capture, credential-free ExDoc build, data-only artifact transfer, and narrow writer to the clean Plan 09 candidate.
- The writer rechecks trusted main and candidate identity before writing, applies only `doc/llms.txt`, uses a non-force push, and waits for ordinary CI registration on the exact refreshed SHA.
- Internal security review found that a symlink at the candidate's `doc/` or `doc/llms.txt` destination could redirect the privileged copy. The writer now rejects both cases before copying. Regression fixtures prove an external sentinel remains unchanged and no push occurs.
- The candidate is based on `e2fa303017364c7e496c3c620f7b709c8e90c8fb` and ends at `10246c8dbcc2acd3c49432844e84a34ae0bd01c1`. Its complete base-to-head diff is exactly the fourteen paths listed in `249-10-CANDIDATE.json`.
- The receipt remains byte-identical at SHA-256 `c1a58f6a36656194387b0006dac9aab447d8f445cce9b060dcfb638ba6c4fff5`; it continues to name package source `9e80cb78d6374b1ed4074d5fef6b613fee879dca` and CI run `37875238741` on that source head.
- No push or PR was created. The temporary Postgres container was stopped after the gate completed.

## Verification

- `bash scripts/ci/refresh-release-docs.test.sh` — 13 passed, including file and parent-directory symlink attacks.
- `bash scripts/ci/release-candidate-preflight.test.sh` — 27 passed.
- `bash scripts/ci/release-public-proof.test.sh` — 44 passed.
- `bash scripts/ci/check-docs-index.test.sh` — 6 passed.
- The Plan 248/249 workflow contract tests — 15 passed.
- `MIX_ENV=test mix ci` — passed outside the command sandbox with the required `phx_new` 1.8.8 archive in a temporary Mix home and an ephemeral Postgres container: 2,636 main tests, 19 installer/golden tests, and 65 Threadline-off tests all passed; no failures.
- `mix docs --warnings-as-errors` and `check-docs-index.sh` passed. The receipt blob remained unchanged.
- Actionlint passed for the changed workflows and for all three workflows with ShellCheck integration disabled. Plain actionlint reports six ShellCheck warnings in unchanged `ci.yml`, independently present on the candidate base. Bash syntax and ShellCheck passed across the candidate scripts when excluding the intentional `SC2016` jq-string notices and the existing `SC2034` unused assignment in the public-proof helper.
- Closeout preservation validates with no blockers and the single historical handoff identity still explicitly classified as an accepted loss.

## Review Notes and Deviations

The first sandboxed aggregate test run could not execute two existing Phase 235 tests that invoke macOS `sandbox-exec`. Their captured error was `sandbox_apply: Operation not permitted`; the full contributor gate passed when rerun outside the command sandbox. The required archive and database were isolated to temporary test locations and cleaned up afterward.

Hex dependency resolution also reports existing OSV advisories for `cloak 1.1.4` and `cloak_ecto 1.3.0`. No dependency changes were in scope; the candidate's vaults use AES-GCM, and Sigra source does not use the affected PBKDF2 field path.

## Next

Plan 249-11 rechecks live protected main and complete PR/worktree inventory immediately before pushing and opening the exact reviewed candidate. It then records exact-head required CI, review, and protected-merge evidence without touching unrelated PRs.
