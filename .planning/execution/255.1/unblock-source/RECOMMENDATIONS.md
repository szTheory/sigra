# Phase 255.1 source recovery decisions

User scope: resolve the source blocker, research relevant perspectives, apply coherent defaults, retain prior results, and continue authorized local work. Hosted preparation and measurement remain separate concrete approvals.

Three independent reviews covered history/integration, product/security/generated hosts, and CI/cache/experiment gates. A second adversarial pass checked the combined source and exposed the historical changelog fixture mismatch. Further broad fan-out stopped once no new material decision remained.

| Decision | Chosen approach | Benefit and tradeoff | Evidence/check |
|---|---|---|---|
| Divergent histories | Real two-parent merge of exact main09df342 and phasec8db625. Resolve behavior per path. | Keeps ancestry and both required behaviors; requires reviewing silent automatic merges as well as conflicts. A tree transplant would lose shipped fixes. | Merge9eb8dd091; both source merge previews equal their exact trees. |
| Product/security | Main confirmation token guards/retry cleanup plus phase enumeration-safe registration and flash feedback. Keep generated templates/goldens aligned. | Retains both protections and existing user feedback; no new auth policy or UI design. | Native148 product checks; generated golden/idempotency4 checks; full native gate. |
| Release history/version | Keep shipping main1.7.2, release workflows/source-claim checks, locks and Dependabot configuration. Retain current phase changes, not old abandoned release experiments. | Avoids downgrades and unrelated release redesign; old experiments remain recoverable by their original commits. | Thirty conflict paths lacked v1.50 changes; reviewed main fixes and exact lock/version assertions. |
| CI/cache | Union main's compiled-cache isolation and guarded old evidence route with phase diagnostics, classifier ownership, seven native legs and browser isolation. | Protects cold/warm correctness and failure signals; local structure never proves a hosted warm restore. | CI/connection/control30 tests; honest-skip21 controls plus5 unit cases; dependency-off28 controls. |
| Local versus hosted readiness | Separate local source/merge/trigger/workload readiness from later work/cache/rule/producer receipts. | Lets Plan02 produce its own prerequisite report; keeps missing hosted proof blocked. | Fourteen helper regressions, including real process/Git/classifier checks. |
| Complete warmth | Require every frozen cache component, including browser binaries, exact key/version/eligible ref and independent producer/component receipts. | Rejects partial green aggregates and sibling/fallback caches; requires actual receipts before hosted claims. | Component, producer and ref negative fixtures. |
| Historical test expectations | H2 consumes exact published changelog fixture bytes from09df342 rather than the mutable Unreleased section. | Keeps its historical assertion honest while preserving the rejection rule and new security note. | Release-preflight30 passed; original29/1 failure retained in protected raw logs. |
| Dependency/tool context | Use shipping main locks, supported pinned runtimes and task-local Hex cache. | Avoids stale build proof and shared-cache permission problems; no package added or new framework. | Locked fetch, native source identity, recorded runtimes/seeds. |

## Actual results

The genuine tracer ran52 configuration checks against reconciled source9eb8dd091, seed637948, exit0. It remains local-only and returns insufficient_data for performance. Fresh preflight reports local_status ready, hosted_status blocked, next local Plan02, zero acceptance samples.

The full native mix ci gate on clean source9eb8dd091 passed in328.374 seconds: ordinary2678 passed/12 expected skips/22 exclusions; scaffold22 passed; dependency-off65 passed. All reports are complete with0 failures and retained seeds/IDs. This is local correctness evidence, not CI speed acceptance. See NATIVE-RESULT.json and native-supported/.

The original native run's two sandbox-exec denials remain a failed development attempt. The authorized rerun uses the same source; it does not erase that result or renew an acceptance allowance. Original Phase254 results/closed budgets and Phase255's pinned replay remain unchanged.

Source conflicts and current local readiness are resolved. Report persistence/equal-work checks are Plan02; later source freeze and actual hosted receipts remain required. Phase verification is pending.

## Primary-source checks and limits

Git documents a true merge as incorporating both parents; we verified the actual resulting source tree rather than relying on its commit message. [Git merge](https://git-scm.com/docs/git-merge).

GitHub documents PR execution on the merge ref and requires resolving conflicts before ordinary pull_request workflows run. The local exact-tree proof removes the known conflict, but it is not a hosted trigger/check-origin receipt. [PR events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request).

Cache access depends on actual current/default/base refs and cache version. PR-created merge-ref caches do not warm sibling PRs. Different local input bytes are a diagnostic; they do not prove that all eligible retained caches are absent. Actual frozen-ref eligibility and exact restores remain unproved until the approved readiness stage. [Cache scope and matching](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching).

## General lessons

The reusable prompt is prompts/fan-out-prompt.txt. The decisive lessons were immutable target SHAs inside secondary clones, review of nonconflicting results, preserving both sides' unique protections, source-bound reruns after lock changes, complete component validation, and separating a task's prerequisites from the evidence that task is meant to produce.

One ordinary setup error was preserved explicitly: the first temporary-clone origin/main pointed to the source repository's local main, not its refreshed remote-tracking ref. MERGE-START2.json corrects MERGE-START.json's claimed base and records the exact SHA assertion used before the real merge.
