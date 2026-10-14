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

## phase253-registration-setup — aliased temp root broke JOSE include link and setup failure lost its receipt

- **Date:** 2026-10-13
- **Error patterns:** JOSE `jose_jwt.hrl` or `jose_jwk.hrl` enoent, `/var/folders` versus `/private/var/folders`, setup fails before HTTP readiness, missing terminal setup receipt
- **Root cause(s):** The runner used an aliased macOS temporary root for `MIX_BUILD_PATH` while Mix resolved dependency source under its canonical path, producing a broken relative JOSE include symlink; shell `errexit` discarded the failing setup command result and raw log.
- **Fix:** Canonicalized temporary roots in both runners; added a bounded setup-only diagnostic that writes each command result and retains its raw log even on failure.
- **Files changed:** scripts/ci/ci-registration-repro.sh, scripts/ci/ci-registration-setup-diagnostic.mjs, scripts/ci/ci-registration-repro.test.sh, scripts/ci/ci-registration-setup-diagnostic.test.mjs
- **Why not caught:** No runner gate covered a symlinked `TMPDIR` or required a retained nonzero setup receipt before the browser phase.
- **Recurrence guard:** `scripts/ci/ci-registration-setup-diagnostic.test.mjs` covers aliased temp paths and failed setup evidence; the final actual entrypoint receipt and 12 raw logs are bound in `.planning/debug/phase253-setup-final-20261013T125238Z/manifest.json`.
- **Scope limit:** Startup passed for all three projects, but the historical registration failure remains unexplained and Phase 253 verification has not started.

---

## 253-native-deadline-not-enforced — native Playwright window ran 29 min past a 120000 ms deadline while the Mac slept

- **Date:** 2026-10-14
- **Error patterns:** work deadline not enforced, Playwright control "hung" 12.6m / 15.4m, group_signals SIGTERM,SIGTERM without SIGKILL, owned cleanup exceeded command limit, database drop failed at cleanup deadline (1 ms budget), SIGKILL escalation test flake under load, node:test process never exits
- **Root cause(s):** the macOS host went into Maintenance Sleep mid-run (pmset `Sleep`/`DarkWake` entries match the hang durations to the second); runLoggedTree used one relative setTimeout with no wall-clock check, no suspension detection and no sleep assertion; the drop budget collapsed to 1 ms after an overrun; the reap poll cached a SIGKILL flag (duplicate SIGKILL); the test helper relied on fs.watch alone (FSEvents can miss an early rename)
- **Fix:** a watchdog of at most 250 ms on max(monotonic, wall) with suspension recording; caffeinate -i -s -m -w <pid> per load slot; halt on suspension and charge the max clock; bounded drop/absence floor; SIGKILL at most once; whenTreeReady watch+poll
- **Files changed:** scripts/ci/ci-registration-recovery.mjs, scripts/ci/ci-registration-recovery.test.mjs
- **Why not caught:** the synthetic tests never modeled a host clock discontinuity (sleep), and the escalation tests asserted exact signal lists on timing alone
- **Recurrence guard:** ci-registration-recovery.test.mjs: "a wall-clock jump past the deadline (host sleep)…", "both clocks jumping across a sleep…", "a group that dies slowly after SIGKILL still receives exactly one SIGKILL", "a host sleep inside the browser command halts the slot…". First diagnostic step for any "hung for N minutes" on a laptop: `pmset -g log | grep -E "Sleep|DarkWake"` around the run.

---
