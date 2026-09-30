---
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
  status: unknown
---

# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## phase-234-wave2-contract-glossary — stale CI contract and admin glossary noun after Phase 234

- **Date:** 2026-07-31
- **Error patterns:** CI contract assertion mismatch, Run contributor CI gate, library_tests_shard, login, sign-in, admin glossary
- **Root cause(s):** The Phase 58 OA-01 CI contract retained retired Phase 233 partition assertions after Phase 234-01 changed the sole library-suite owner to `Run contributor CI gate` / `MIX_ENV=test mix ci`; independently, components.ex's attr documentation used the banned `login` noun rather than canonical `sign-in`.
- **Fix:** Updated the OA-01 structural contract to assert Phase 234's contributor gate and retained its OAuth-exclusion prohibition; changed only the components attr documentation noun to `sign-in`.
- **Files changed:** test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs, lib/sigra/admin/components.ex
- **Why not caught:** The Phase 234-01 topology change had focused DX contracts, but the older Phase 58 OA-01 contract was not updated in the same change; the glossary test correctly caught the stale documentation noun during Wave 2 verification.
- **Recurrence guard:** `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` now asserts the canonical CI owner and command while retaining the OAuth-exclusion prohibition; `test/sigra/admin/glossary_test.exs` enforces `sign-in` in scanned admin chrome.

---

## coordinator-symbolic-head-hook — pinned Git capability probe bypassed by PATH subprocess

- **Date:** 2026-09-30
- **Error patterns:** coordinator_symbolic_head_hook_unsupported, symbolic HEAD capability, ambient PATH Git, skipped coordinator integration
- **Root cause(s):** The capability probe's `env ... git` child resolved Homebrew Git 2.41.0 from PATH instead of pinned `/usr/bin/git` 2.50.1; the coordinator and pruning shell fixtures accepted unsupported capability as success before their integration assertions; the pruning fixture's PATH shim could not intercept pinned Git.
- **Fix:** Execute the validated absolute Git path in the capability child; require supported capability and full integration completion in both fixtures; synchronize the pruning race through a disposable chained reference-transaction hook and run competing mutation with pinned Git.
- **Files changed:** scripts/maintainers/repo-mutation-coordinator.sh, scripts/maintainers/repo-mutation-coordinator.test.sh, scripts/maintainers/prune-stale-branches.test.sh
- **Why not caught:** The original poison-PATH check exercised the shell `git()` function but not the `env` subprocess; unsupported-success branches skipped the lock, lease, worktree, and pruning checks.
- **Recurrence guard:** The coordinator shell fixture poisons PATH during install, proves `/usr/bin/git` hook denial and unchanged linked HEAD, and requires its final integration marker. The pruning fixture requires supported capability and uses a chained hook to prove pinned deletion and competing-attach rejection. The exact source-line revert makes the coordinator fixture fail.

---
