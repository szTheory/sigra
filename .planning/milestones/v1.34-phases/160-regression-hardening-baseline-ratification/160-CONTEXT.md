# Phase 160: Regression Hardening + Baseline Ratification - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Final closure phase of **v1.34 ADMIN-UI-COHERENCE** (phases 154–160). Ratify all new
and re-recorded Playwright baselines on a clean DB, formally close GATE-01 and GATE-02,
ratify the committed component governance contract, fold the criterion-threatening
regression-hardening fixes, and assemble the milestone proof bundle.

**In scope:** baseline ratification (compare-mode), parity-lane closure, governance-contract
verify-and-ratify, the two folded bug fixes below, milestone proof bundle + gate flips.

**Out of scope (hard boundary):** no net-new admin surfaces, no nav/IA restructure, no new
Hex deps / Tailwind / Alpine / `assign_async`, no token-layer or motion-primitive work
(GATE-03 already closed in 159). Pure code-quality cleanups stay deferred.
</domain>

<decisions>
## Implementation Decisions

### Baseline Ratification (criteria 1 & 3)
- **D-01:** The 3 new checkpoint slugs (`global-overview`, `org-overview`, `user-audit`) are
  **NOT re-captured against the seeded demo DB.** They are already captured via ad-hoc per-run
  fixtures (`registerUser`/`createOrganization` with a unique suffix) in 157-04 (`e609b48a`) and
  158-05 (`25ee1bf0`). That ephemeral self-seeding fixture **is** the "clean DB" the criterion
  requires (no accumulated dev-DB seed history can leak into the viewport). This is the path the
  159 D-07 fork already resolved toward (minimal baseline churn).
- **D-02:** Ratification = run committed baselines in **compare mode** via
  `scripts/ci/snapshot-recapture-gate.sh` + `scripts/ci/snapshot-canary-guard.sh` (with
  `--require-all`), proving green. Aside from the deliberate dark re-records in D-06, **zero
  unintended re-records** is the proof of behavior-preservation.
- **D-03:** Reset `test/example/priv/playwright/snapshot-allowlist` to its steady-state empty
  form **after** D-06's deliberate dark re-records are captured and merged — it currently still
  carries the Phase 158 `user-audit`/`audit-explorer` intended-delta entries. The
  `impersonation-banner` canary stays permanently out of the allowlist.

### Parity Lane — GATE-02 (criterion 2)
- **D-04:** GATE-02 closes with one final green run of the **existing** `admin-generated` lane
  via `scripts/ci/admin-acceptance-smoke.sh` (scaffolds throwaway app, installs Sigra, runs
  `admin-generated.spec.ts`). No new parity machinery. If it fails on installer-template drift
  (`priv/templates/sigra.install/` lagging `test/example/`), sync templates to mirror the final
  lib LiveViews (modulo namespace substitution) before closing — this drift is a known recurring
  failure mode, not a surprise.

### Component Governance Contract (criterion 4)
- **D-05:** The contract **already exists** at `guides/reference/admin-design-contract.md`
  (Job→Component map, when-NOT-to-use, ARIA roles, motion specs, 3 page archetypes), committed
  under COMP-03 (Phase 154) and wired into ExDoc (`mix.exs:199`). Criterion 4 is **verify-and-
  ratify**: patch stale "deferred to Phase 155 / target-state" notes so it matches the final
  156–159 component reality, and add the `role="status"` adjudication (see D-08) and the
  dark-AA resolution (see D-06) as documented decisions. Stamp it ratified as of v1.34 close.

### Folded Regression-Hardening Fixes
- **D-06 [FOLD — deliberate intended-delta]:** Fix the dark-mode `--sg-color-brand-strong`
  WCAG-AA contrast gap globally. The dark `:root` block (`app.css:160–184`) lightens tones +
  `brand-soft` but leaves `--sg-color-brand-strong` at `#9a3412`, so every
  `brand-soft`+`brand-strong` combo (scope-pill, scope-switch, `nav-link[aria-current]`,
  `badge--brand`, breadcrumb hover — chrome on **every** dark checkpoint) fails AA (~1.88:1).
  Add a dark-mode `--sg-color-brand-strong` override (inside the dark block / `@layer
  sg-components`) hitting AA on the dark `brand-soft` tint — mirror the chip precedent
  (`app.css:888–893`, `#fdba74`); pick the value deliberately and confirm with an axe dark run.
  - **This is a SANCTIONED exception to the zero-re-record law.** The change re-renders brand
    chrome on dark, so **dark baselines will legitimately re-record.** The allowlist mechanism
    exists precisely for deliberate deltas. **Planner MUST enumerate every dark checkpoint slug
    that renders brand chrome** (not just the 3 new slugs — also `admin-checkpoints-dark` slugs
    and any `demo-showcase` dark frame) and allowlist exactly those re-records, then remove them
    from the allowlist per D-03 after merge. Light-mode and mobile baselines must NOT change.
  - **Outcome:** the criterion-1 "axe green" claim becomes genuinely true (no latent dark-AA gap),
    not green-by-axe-under-detection-of-`color-mix`.

- **D-07 [FOLD — invisible fix, no re-record]:** Fix `needs-review` count/link mismatch. The
  alarm count sums `:locked + :deleted` (`index_live.ex:157`, `organization_live.ex:215`) but
  deep-links to `?locked=true` only — count and destination disagree, and the new FIXT-03
  deletion-scheduled seed now exercises it. **Fix the LINK, not the count** (deletion-scheduled
  accounts genuinely need review, so keep counting them and make the link reach them). The
  Users query AND-composes filters, so a naive `?locked=true&deleted=true` is wrong — introduce
  an OR / dedicated "needs review" filter semantic so the link lands on exactly the counted set.
  Keeping the visible count unchanged means **no checkpoint re-record.** While here, de-duplicate
  the byte-identical `needs_review/1` into a shared `Sigra.Admin` helper (IN-03).

### Verify-Only (already fixed — confirm, then mark resolved)
- **D-08:** `org-notice-nested-p` is **already resolved** — `notice/1` wraps its slot in
  `<div class="sg-text-sm">` not `<p>` (`components.ex:303`). `admin-format-date-naivedatetime`
  is **already resolved** by 159-05 WR-01 (`organization_live.ex:194` has the `%NaiveDateTime{}`
  head). Confirm both still hold and close the todos.

### Milestone Proof Bundle (criteria 1–4 evidence)
- **D-09:** Assemble from existing artifact producers — `snapshot-recapture-gate.sh` output
  (3-project compare + canary `--require-all` + ExUnit component byte-goldens) + green
  `admin-generated` parity run + `demo-showcase` green + per-phase 154–159 VERIFICATION.md set +
  the ratified design contract. Produce a **`v1.34-MILESTONE-AUDIT.md`** mirroring prior-milestone
  precedent. Flip GATE-01 + GATE-02 to Complete in `REQUIREMENTS.md` and advance STATE.md to
  milestone-complete.

### Claude's Discretion
- Exact dark `--sg-color-brand-strong` value (must pass AA on dark `brand-soft`; mirror chip
  precedent and verify empirically with axe).
- Shape of the OR / "needs review" filter semantic in the Users query for D-07.
- Whether the dark re-record wave and the brand-strong CSS land in the same plan as the
  allowlist update or split for reviewability.

### Folded Todos
- `2026-06-04-admin-brand-strong-dark-contrast-gap.md` → **folded (D-06)**.
- `2026-06-04-admin-overview-needs-review-count-link-mismatch.md` → **folded (D-07)**.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 160 entry (success criteria 1–4), GATE-01/02 ownership.
- `.planning/REQUIREMENTS.md` — GATE-01/02/03 definitions + status table (L50–52, L103–105).
- `guides/reference/admin-design-contract.md` — the component governance contract (criterion 4).
- `test/example/priv/playwright/playwright.config.ts` — project partitions (`admin-checkpoints-{chromium,mobile,dark}`, `admin-generated`, `demo-showcase`).
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — checkpoint journey + ad-hoc fixtures (the new slugs).
- `test/example/priv/playwright/snapshot-allowlist` — deliberate-delta manifest (reset per D-03).
- `scripts/ci/snapshot-recapture-gate.sh`, `scripts/ci/snapshot-canary-guard.sh` — ratification gate.
- `scripts/ci/admin-acceptance-smoke.sh` + `tests/admin-generated.spec.ts` — parity lane (GATE-02).
- `test/example/priv/static/assets/css/app.css` — dark `:root` block L160–184; brand-strong combos L359–361/408–410/450/517–518/612–613/1360; chip precedent L888–893.
- `lib/sigra/admin/live/index_live.ex`, `lib/sigra/admin/live/organization_live.ex` — `needs_review/1` (D-07), alarm `role="status"` (D-08 contract).
- `lib/sigra/admin/components.ex` — `notice/1` (verify-only D-08).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Full ratification harness exists: `snapshot-recapture-gate.sh` orchestrates 3-project
  checkpoint compare + canary guard + ExUnit component byte-goldens as one all-green gate
  (matches zero-human-UAT). `RUN_PARITY=1` can bundle the parity lane into the same invocation.
- `admin-acceptance-smoke.sh` already scaffolds a throwaway Phoenix host, installs Sigra, seeds a
  deterministic admin policy, and runs the `admin-generated` parity spec.
- The governance contract is already written, committed, and ExDoc-referenced.
- Chip dark-contrast fix (`app.css:888–893`) is the precedent pattern for D-06's global fix.

### Established Patterns (constraints)
- **Zero unintended re-records** is the milestone's headline proof. D-06's dark re-records are the
  one sanctioned, allowlisted exception — everything else must compare byte-green.
- All new CSS in `@layer sg-components { }`; no unlayered rules.
- `admin-generated` parity is a per-phase gate, already green through 159.
- Verification is automated-only (axe WCAG A/AA + Playwright snapshots + parity).

### Integration Points
- New checkpoint baselines live under `admin-checkpoints.spec.ts-snapshots/`.
- Gate flips: `REQUIREMENTS.md` (GATE-01/02 → Complete), `STATE.md` (milestone-complete),
  new `.planning/milestones/v1.34-MILESTONE-AUDIT.md`.
- Installer-template drift surface: `priv/templates/sigra.install/` vs `test/example/`.
</code_context>

<specifics>
## Specific Ideas

- D-06's dark `--sg-color-brand-strong` value should mirror the chip precedent direction
  (`#fdba74`-family) and be empirically confirmed AA-passing by an axe dark run, not eyeballed.
- D-07 must fix the link target (not the count) so the headline alarm reconciles without any
  visible text change → preserves zero re-record for that fix.
</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
- `2026-06-04-admin-overview-cleanup-misc.md` — dead refute assertions, hardcoded deep-link
  paths, duplicated `runtime_config!/0`, role_tone owner/admin same tone. **Pure code-quality, no
  criterion bearing → deferred.** (IN-02/IN-03 `needs_review/1` dedup is partially picked up by
  D-07; the rest stays deferred.)
- `2026-06-04-admin-overview-notice-role-status.md` — `role="status"` adjudication. **Resolved by
  contract ratification (D-05/D-08), not a code fix** — document it as the intentional post-connect
  announcement rather than removing it.
- `2026-06-03-sg-notice-tone-rule-duplication.md` — **already folded into phase-156** (status:
  folded, shared-selector merge per 156-CONTEXT D-08). Not pending; nothing to do.
</deferred>
