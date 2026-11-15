---
gsd_state_version: "1.0"
milestone: v1.51
milestone_name: BRAND-IDENTITY-ADOPTION
current_phase: 260
current_phase_name: Deterministic Output, Before Catalog and PNG Park
current_plan: 2
status: executing
stopped_at: Completed 260-01-PLAN.md
last_updated: "2026-11-15T18:07:39.758Z"
last_activity: 2026-11-15
last_activity_desc: Phase 260 execution started
state_head: d45098b0ab2593fd0fbdab9cb2012dc987b8ce82
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 11
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** Authentication that works out of the box with a clear path for Phoenix adopters.
**Current focus:** Phase 260 — Deterministic Output, Before Catalog and PNG Park

## Current Position

Phase: 260 (Deterministic Output, Before Catalog and PNG Park) — EXECUTING
Current Plan: 2
Total Plans in Phase: 11
Status: Ready to execute
Last activity: 2026-11-15 — Phase 260 execution started

Progress: [░░░░░░░░░░] 0% (0/5 phases)

## Deferred Requirements

| Requirement | Status | Closeout decision |
|---|---|---|
| CISPEED-01 | Deferred/open | No successful comparable pairs; median is null. |
| CISPEED-02 | Deferred/open | No valid population; p95 and runner cost are unproved. |
| CIREL-01 | Deferred/open | Selected registration failure was not reproduced. |
| CIDX-02 | Deferred/open | Current diagnostics source lacks matching main/hosted proof. |
| CIMEAS-01 | Adjusted | Accept the dated 2026-10-12 baseline; defer a fresh snapshot. |

## Deferred Items

Items acknowledged by the production audit writer at the v1.50 closeout. Acknowledgment suppresses the audit until an item changes; it does not resolve the underlying work. Forty-two records were newly acknowledged; 54 were already acknowledged by prior closes.

| Category | Item | Status | Deferred At | Milestone |
|---|---|---|---|---|
| debug_sessions | `253-r2-native-controls-all-fail` | diagnosed | 2026-11-10 | v1.50 |
| debug_sessions | `phase253-registration-timeout` | verifying | 2026-11-10 | v1.50 |
| debug_sessions | `phase256-prep-readiness` | investigating | 2026-11-10 | v1.50 |
| debug_sessions | `phase256-source-lineage` | resolved_offline | 2026-11-10 | v1.50 |
| quick_tasks | `260923-uqh-add-deterministic-offline-regression-cov` | missing | 2026-11-10 | v1.50 |
| todos | `2026-09-15-admin-eval-render-isolated-red-has-no-consumer.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-composite-action-outside-supply-chain-guards.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-gate-05-ledger-scope-and-manifest-contradiction.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-honest-skip-parity-guard-does-not-exist.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-p12-evidence-guard-is-pinned-to-phase-230.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-test-01-02-timing-machinery-orphaned.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-dep-off-restore-leaves-threadline-forwarder-a-noop-until-forced-recompile.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-docs-index-goes-stale-on-every-version-bump.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-installer-template-ships-a-dead-planning-link-to-every-adopter.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-phase-241-ratchet-baseline-scans-lib-only-but-guides-render-on-hexdocs-too.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-repo-03-requirement-text-still-asserts-the-stash-push-that-d-09-abandoned.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-upgrade-guide-link-removal-was-lossy-where-a-lossless-fix-existed.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-upgrade-test-never-runs-anywhere-wrong-mix-task-name.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-walkthrough-excerpt-diverges-from-the-template-it-quotes.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-home-directory-paths-are-already-public-in-ten-committed-planning-files.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-p19-bypass-actors-literal-is-constructed-at-runtime-to-route-around-its-own-grep-gate.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-p19-known-bad-fixture-short-circuits-before-its-second-declared-violation.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-tag-ruleset-drift-observer-has-never-run-and-has-two-latent-defects.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-25-fut-02-dependabot-groups-policy.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-25-fut-04-launch-pack-contract-caller.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-10-01-investigate-node-git-stdin-stall.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-10-28-fix-org-config-test-async-capture-log-race.md` | acknowledged | 2026-11-10 | v1.50 |
| seeds | `SEED-261023-9t1` | dormant | 2026-11-10 | v1.50 |
| seeds | `SEED-261023-opm` | dormant | 2026-11-10 | v1.50 |
| uat_gaps | `253/253-UAT.md` | acknowledged | 2026-11-10 | v1.50 |
| verification_gaps | `253/253-VERIFICATION.md` | gaps_found | 2026-11-10 | v1.50 |
| verification_gaps | `245/245-VERIFICATION.md` | gaps_found | 2026-11-10 | v1.50 |
| deferred_items | `252/d4e1f1c5e5f3` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `252/3b881400f79b` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `252/2a488b4a872d` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `255.1/fd966a49e076` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `240/8b4e48b719b8` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `244/534052033cf9` | acknowledged | 2026-11-10 | v1.50 |

## Durable Evidence

- Approved partial-closeout proposal: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/RESCOPE-PROPOSAL.md` (SHA-256 `f2b29ccbae3b8c89f0e5b55942f076e154944986bf8e81aff3fb0c1ecbfc3700`).
- User decision receipt: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/RESCOPE-DECISION-01.json` (SHA-256 `b9d5e34fa7af98323051a7fa9964ccaf4fe0c9419ac9ee09293bbee27d2e43b8`).
- Final audit: `.planning/milestones/v1.50-MILESTONE-AUDIT.md`; requirements: `.planning/milestones/v1.50-REQUIREMENTS.md`; full roadmap: `.planning/milestones/v1.50-ROADMAP.md`.
- Phase trees: `.planning/milestones/v1.50-phases/`; exact recovery archive and status manifest: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/write-ahead/phase-archive-01/`.
- Newly acknowledged item ledger: `.planning/recovery/opengsd-health-20261106/phase253-milestone-closeout-20261110-01/write-ahead/reconcile-06/ACKNOWLEDGMENT-LEDGER.json`.
- Cross-phase integration audit: `.planning/execution/v1.50-audit/INTEGRATION.md` (17/17 connections wired; performance flow has no passing sample).
- Final route write-ahead copy: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/write-ahead/reconcile-08/PRESERVATION.json`.

## Session Continuity

Last session: 2026-11-15T18:07:39.716Z
Stopped at: Completed 260-01-PLAN.md
Resume file: None

No phase command is active. Plan the next phase with `/gsd-plan-phase 260` (v1.51 roadmap: `.planning/ROADMAP.md`). Preserve all halted one-use attempts; do not retry or renew them.

## Performance Metrics

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 259 P01 | 6 min | 3 tasks | 4 files |
| Phase 259 P02 | 5 min | 2 tasks | 3 files |
| Phase 259 P03 | 4 min | 2 tasks | 8 files |
| Phase 259 P04 | 3 min | 1 tasks | 1 files |
| Phase 259 P05 | 5 min | 3 tasks | 4 files |
| Phase 259 P06 | 12 min | 3 tasks | 5 files |
| Phase 259 P07 | 16min | 3 tasks | 2 files |
| Phase 259 P08 | 14min | 2 tasks | 3 files |
| Phase 259 P09 | 11 min | 2 tasks | 7 files |
| Phase 259 P13 | 5 min | 1 tasks | 4 files |
| Phase 259 P10 | 9 min | 3 tasks | 10 files |
| Phase 259 P12 | 12 min | 3 tasks | 3 files |
| Phase 259 P11 | 11 min | 2 tasks | 2 files |
| Phase 259 P14 | 12 min | 3 tasks | 6 files |
| Phase 259 P15 | 6 min | 2 tasks | 7 files |
| Phase 259 P16 | 3 min | 2 tasks | 3 files |
| Phase 259 P17 | 8 min | 3 tasks | 4 files |
| Phase 259 P18 | 4 min | 2 tasks | 5 files |
| Phase 260 P01 | 11 min | 3 tasks | 6 files |

## Decisions

- [Phase 259]: ADR 005 records every brand-adoption decision except #12 as a recommended default awaiting owner confirmation; #12 confirmed 2026-11-13 — Only the pointer-fix approval was given; the rest are research defaults the owner has not yet ratified
- [Phase 259]: v1.51 ships as a minor release: feat/fix/docs only, no bang marker, no BREAKING footer, nothing hand-added under CHANGELOG Unreleased — Every frozen name stays, so no documented API is removed; release-please owns the Unreleased block
- [Phase 259]: Pin the whole tracked brand/ tree and document the consumed subset as a table; install-pin shape enforced now, value bump in Phase 263 — Pruning leaves the book's own index and manifest dangling; a two-segment requirement still resolves to the retired stray 1.20.0
- [Phase 259]: Pin the whole tracked brand/ tree with brand.sha256 and one drift module; privacy scan has no URL rule or allowlist, names are covered by the 259-11 run-time gate — Home paths, emails and SVG/PDF/PNG/JPG metadata are scanned here with planted controls; personal names cannot be written into test source, so Plan 259-11 derives the name at run time
- [Phase 259]: 259-03: login submit selector is '#login_form button:not([type="button"])' (excludes type=button, not [type=submit], because the example host button has no type attribute); exported as a string constant for the one probe call site
- [Phase 259]: 259-03: Playwright behavioral proof of the loginSubmit edits is the PR example_playwright_shard lanes only; local proof is the exactly-one-match ConnTest plus the node import (Playwright not installed locally)
- [Phase 259]: 259-04: install-snippet test asserts shape (anchored three-segment) and set size 1, never a version value, so the later pin bump needs no test edit
- [Phase 259]: 259-04: install-snippet scan has no allow-list or per-file skip; real-tree redness proven only by planted inputs and a tmp_dir tree (no doc edits)
- [Phase 259]: 259-05: Frozen-surface baseline must carry exactly the module's known categories and each needs an extractor, so a renamed source path or dropped extractor fails by name; Profile defaults are frozen as key=inspect(value) strings so a changed default is a removal
- [Phase 259]: 259-05: Msgids, preview HTML and admin copy are not frozen (only the Gettext domain); legacy Branding fixture is generated once behind SIGRA_BRAND_LEGACY=write and never overwritten; frozen baseline extends only through the guarded SIGRA_BRAND_BASELINE=extend union
- [Phase 259]: 259-06: Copy inventory rows are prose-only per lane: host excludes hex design tokens, library keeps capitalized single words and scopes error.ex to safe_message/1, and generated/library never evaluate repo content (regex or Code.string_to_quoted only)
- [Phase 259]: 259-06: Inventory lanes as specified leave raw template literals, HEEx attribute copy and browser JS copy uncovered (listed in SUMMARY Deferred Issues); extending them is a regeneration-flow follow-up, not recorded in the ship ledger
- [Phase 259]: 259-07: password-reset-request and confirmation-resend registered not_proven (example host cannot drive either); 3 of 5 named surfaces are parity
- [Phase 259]: 259-07: added a result compare dimension for library-level rows; LiveView per-mount ids normalized as request ids; known-divergence rows assert exact differing dimensions
- [Phase 259]: 259-07: passkey conditional flow is a sub-case test, not a parity registry row (no identity involved)
- [Phase 259]: 259-08: copy-baseline hits are a multiset (a repeated violating line needs a repeated entry) and carry the matched copy segment, not line numbers or whole source lines
- [Phase 259]: 259-08: admin and generated scopes share one copy-segment scanner (strings, HEEx text, six copy attrs); identifiers, routes, atoms, comments and docs never match; admin keeps the auth-replica carve-out
- [Phase 259]: 259-08: derived brand avoid-words exclude ordinary English (delete, cancel, disable, group, scope, target, subject, suspend, host, consumer) and parenthetical-qualified entries
- [Phase 259]: [259-09] Instruction-file pointer fix landed under the 2026-11-13 owner approval (BPOL-06): CLAUDE.md changed by one line, AGENTS.md and both admin guides point at brand/, and wording says token names stay while values move in a later phase (no alignment claim).
- [Phase 259]: [259-09] test/example/AGENTS.md (no brandbook path) and the orphaned lens guide, scorecard and panel lenses pointers were NOT edited; filed as two pending todos for the owner to assign or extend the approval.
- [Phase 259]: 259-13: missing_files/1 treats an absolute path or a directory as missing and de-duplicates; the three new todo paths are named in the parity test independently of @expected_todos so a dropped registry reference goes red
- [Phase 259]: 259-13: todos record what the harness compared versus what was only read in source (passkey allowCredentials disclosure, generated reset callers skipping the limiter and dummy hash for unknown emails) and never claim a surface is safe; generated reset callers pass a user struct to a binary-only head, logged in deferred-items.md
- [Phase 259]: 259-10: published enumeration claims are bounded to the three parity rows (password sign-in, magic-link request, MFA challenge); the reset request screen is not_proven so no doc says it is tested — Plan 07 registry is the only source for what may be claimed; the sweep test keeps it so
- [Phase 259]: 259-10: where plan wording disagreed with source, the source won (reset primitive returns {:ok, :sent}; throttled reset returns {:error, :rate_limited}, not :ok) — A bare :ok would have been a second inaccuracy in the sentence being fixed
- [Phase 259]: 259-10: the unbounded-claim sweep keeps indented code and uses an empty shrink-only allow-list; every hit is fixed by rewording — A reader still sees a claim in an indented example; allow-listing a hit would defeat BCOPY-07
- [Phase 259]: [259-12] Glossary reconciliation rows say Differs wherever the book and glossary disagree or the glossary has no row; 12 of 23 rows differ — Defaulting to Agrees would hide real gaps; the Banned synonyms cell carries the book avoid text and glossary-only words are named in the rule.
- [Phase 259]: [259-12] The status vocabulary (Active, Unconfirmed, Locked, Deletion scheduled) is recorded as a target, and the shipped Confirmed pill and the missing admin unlock control are stated, not claimed as aligned — Anchors user_show_live.ex:332 and :385 and index_live.ex:96 show the product has not moved; the copy phase owns the rewrite.
- [Phase 259]: [259-12] The vocabulary doc test requires every anchor to sit on a line holding a term registered for its file — The per-pair at-least-one rule let a drifted anchor pass beside a sibling; mutation-checked red.
- [Phase 259]: Clear-space authority recommended as the book's prose rule of 2 T (300 units) over brand.json logo.clearSpace (233.75 units); brand.json disagrees with itself; confirmed by owner 2026-11-15 (ADR 006)
- [Phase 259]: Logo-use wording recommended as unchanged use to refer to Sigra, no implied endorsement, modification needs maintainer approval, worded as a request that leaves the MIT grant intact; a logo carve-out is a separate owner decision (ADR 006)
- [Phase 259]: crosswake_sigra recorded as an apparent own companion (same GitHub owner as source_url), maintainer to confirm; never a third-party conflict, never support for a clearance or trademark claim; the record is a search log, not a clearance (ADR 006)
- [Phase 259]: Claims register status is tested against the surface registry state: only a parity row may read bounded, every other row reads not proven or by design (name_clearance_test.exs)
- [Phase 259]: 259-14: password-reset-request repaired and proven as parity instead of waived (router :new live action, binary email passed unconditionally to the enumeration-safe context function); example host only, the generated reset page is not compared and still carries the same two defects for 259-17 to file
- [Phase 259]: 259-14: the registry flip and the claims-register restatement must land in one plan (commits 8bf865b66 and 7341af79e leave name_clearance_test red, 5c34cd083 turns it green); BCOPY-03 and BCOPY-07 stay open because plans 259-15 to 259-18 also declare them
- [Phase 259]: 259-15: confirmation-resend repaired and proven as parity instead of waived (live_session :confirmation on :mount_current_scope outside the redirect-if-authenticated scope, nil-safe session_user/1); the row proves a visitor-supplied payload email is ignored, not an email-keyed resend form (none exists); example host only, the generated host is not claimed
- [Phase 259]: 259-15: registry flip, probe and register restatement shipped in one commit so name_clearance_test is green at every commit; pre-existing anonymous ?token= crash in the example handle_params is pinned by installer_drift_test fix #9 and logged in deferred-items.md
- [Phase 259]: 259-16: the named-surface rule judges each of the five named ids on its own in three classes (account-existence: password-signin, magic-link-request, password-reset-request; payload-ignored: confirmation-resend; code-kind: mfa-challenge); the parity-or-not_proven tolerance and the at-least-three-of-five floor are deleted, and planted controls prove each branch can fail
- [Phase 259]: 259-16: mfa-challenge is kept as a real parity probe and counted separately rather than removed or reclassified (test-only, reversible with a one-line edit, the owner may revisit); WR-08 residual closed in the brand-harness deferred-findings todo; BCOPY-03 stays open because plans 259-17 and 259-18 also declare it
- [Phase 259]: 259-17: the generated host's reset request defects (live route emitted without :new; user struct passed to the binary-only deliver_user_reset_password_instructions head) are filed as one todo with every generated-host claim labelled read in source, not executed, and wired into the password-reset-request registry row so the parity test requires the reference; no lib/ or priv/ byte changed
- [Phase 259]: 259-17: the generated-confirm todo took the primary outcome (status update, stays pending): the LiveView flavor was repaired in Phase 246 and has an install-smoke probe, the non-live controller flavor still sits in the redirect-if-authenticated scope and reads current_scope.user directly (read in source, not executed); BCOPY-03 and BCOPY-07 stay open because plan 259-18 also declares them
- [Phase 259]: 259-18: the README Enumeration row and the password-reset guide scope paragraph restate only what the parity rows prove (sign-in, magic-link and password-reset requests, single attempt, example application, generated code listed as not covered); the confirmation resend is deliberately not mentioned publicly; the false "tests do not currently run a comparison" clause is retired as a false statement in claims_docs_test, with no sweep allow-list entry
- [Phase 259]: 259-18: phase gate ran green once (example suite 391 tests 0 failures, MIX_ENV=test mix ci exit 0 with 2985 tests and 65 install-golden tests, zero shipped bytes, all six privacy legs pass) and BCOPY-03 and BCOPY-07 were marked complete via requirements.ready-ids; no owner override written; the generated reset request page and non-live confirm flavor stay open, tracked by the two Plan 259-17 todos
- [Phase 260]: [Phase 260-01]: PNG compare is parked at comparison level, not lane level. SIGRA_PNG_COMPARE_SKIP=1 skips only toHaveScreenshot on pull_request/push/schedule; unset compares, so recapture jobs, drift scripts and the Pages workflow need no edit (owner chose author-first-option-a; departs from literal ADR 005 decision 7 wording, plan 11 appends a dated ADR note) — Keeps axe, real-login and behavior specs on the PR path and leaves every if: predicate, the honest-skip manifest and the five required job names untouched; a forgotten setter fails loud (compares) rather than silently green.
- [Phase 260]: [Phase 260-01]: playwright-github-pages.yml is left unedited; it keeps comparing and will report drift after Phase 261 until baselines are recaptured — Not a required context and not in ci-gate; leaving it untouched keeps the park PR a ci.yml-only change. Cost documented in MAINTAINING.md.
