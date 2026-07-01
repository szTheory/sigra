# Phase 209: Judgment-Level Page Pass - Research

**Researched:** 2026-06-30
**Domain:** Elixir/Phoenix LiveView admin-UI judgment + in-place remediation; Playwright snapshot-gate / monotonic-ledger CI mechanics
**Confidence:** HIGH (every claim grounded in a read file + line; no external package research needed — zero net-new deps)

## Summary

Phase 209 is a **judgment + in-place remediation** pass over 8 existing library-owned admin LiveViews, NOT greenfield. CONTEXT.md (D-01..D-10) and UI-SPEC.md are unusually complete and lock nearly every decision. This research does exactly what the phase description asked: **verify the D-04 file:line anchors against current source, confirm the canonical source-of-truth path, map the gate/recapture mechanics precisely, and surface planning risks** — it does NOT re-derive locked decisions.

**Headline results:**
1. **All D-04 anchors VERIFIED ACCURATE against current source** (only one 1-line drift: revoke copy is `:205` not `:206`). The findings are genuinely still-live — D-03's "page LiveViews never touched by 206/207/208" is confirmed (last edited 2026-06-26, all in `lib/sigra/admin/live/`).
2. **Canonical source-of-truth CORRECTION:** the 8 admin page LiveViews **and** `components.ex` are **library-owned single-source** at `lib/sigra/admin/` — they are NOT generated into host apps and have NO `test/example/` or `install_golden/` copy to keep byte-coherent. The host router references `Sigra.Admin.Live.*` directly. D-06's byte-coherence concern applies ONLY to CSS/JS/shell/injection assets in `priv/templates/sigra.install/admin/`, none of which the D-04 worklist touches. **This materially simplifies the edit surface.**
3. **Two new adversarial findings** the forced-finding floor will surface beyond the D-04 floor: `organization_live.ex:69` has the SAME bare "All clear" bug as `index_live.ex:52` (D-04 cited only index); and `scope_copy/1` is a **per-page private helper duplicated in 5 LiveViews with divergent copy** — branding has none, so the branding remediation is not a trivial "route through existing helper."
4. **The D-10 canary collision is structural and confirmed:** `impersonation-banner` was modified by Phase 204-03 (WCAG contrast fix, STATE:180); the guard forbids canary modify/delete AND the allowlist explicitly bans the canary from being listed. Re-baselining relative to phase HEAD is the ONLY resolution.
5. **The single biggest UNRESOLVED planning risk:** there is a CI-native ubuntu recapture job for the **design lane** (`admin_design_recapture`) but **NONE for the checkpoint lane** — historically checkpoint baselines were recaptured locally via `snapshot-recapture-gate.sh` on :4011. D-09 mandates ubuntu-native checkpoint recapture, so the planner must decide the mechanism.

**Primary recommendation:** Sequence as (1) author the 8 panel docs fresh against live DOM → (2) remediate in-place in `lib/sigra/admin/live/*.ex` + `components.ex` (single source; no coherence chain) → (3) resolve D-10 integration allowlisting + canary re-designation → (4) recapture only the touched checkpoint slugs CI-native on ubuntu, allowlist→clear. Keep panel-authoring BEFORE remediation so the docs capture the pre-fix state as evidence, then append remediation-resolution notes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin page copy/IA/component usage | Library (`lib/sigra/admin/live/*.ex`) | Shared components (`lib/sigra/admin/components.ex`) | Admin LiveViews are library-owned; host apps mount them via `Sigra.Admin.Live.*` in their router. Edits land here directly, single-source. |
| Empty-state / notice / scope_ribbon components | Library (`lib/sigra/admin/components.ex`) | — | `<.empty_state>` (:410), `<.notice>` (:509), `<.scope_ribbon>` (:465) are all library function components. |
| Scope copy computation | Per-page private helper (`defp scope_copy/1`) | — | NOT a shared component helper — duplicated in 5 LiveViews with per-page divergent strings. |
| Panel scoring docs | Planning artifacts (`.planning/uat-evidence/`, `.planning/`) | — | Pure markdown; no code tier. |
| Snapshot baselines | CI-native ubuntu (`test/example/priv/playwright/…-snapshots/`) | — | Platform-pinned (no OS token in pathTemplate); darwin recapture byte-fails ubuntu CI. |
| CSS / JS / shell / router injection | `priv/templates/sigra.install/admin/` | generated `test/example/` copy | Host-shipped; byte-coherence chain applies HERE — but D-04 worklist does not touch these. |

## Standard Stack

**No external packages are installed or researched in this phase.** Phase 209 is zero-net-dep judgment + in-place remediation of existing Elixir/Phoenix LiveView source. The Package Legitimacy Audit and Environment Availability sections below reflect this.

Existing runtime already in use (verified in `lib/sigra/admin/`): Phoenix LiveView (`use Phoenix.LiveView`), the `sg-*` hand-authored BEM/cascade-layer CSS system, Playwright for baselines. All governed by CLAUDE.md's locked stack.

## Package Legitimacy Audit

Not applicable — Phase 209 installs no external packages. It edits existing library source and planning docs only. No `npm install` / `mix deps` changes. (Skipped per the protocol's "phases that install external packages" trigger.)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Re-run the rubric FRESH against current source for all 8 pages; `.planning/v1.42-IA-DIAGNOSTIC.md` is advisory input only, NOT a pre-scored panel to copy. Each per-surface doc = YAML frontmatter (`surface`, `ledger_cell`, `rubric_version: "1.0"`, `disposition`, all 9 `verdicts`, `findings[]`) + markdown body, one section per lens, every (lens × question) cell = DOM-anchored finding OR literal `NONE — searched for: <what>` (forced-finding floor; partial compliance invalidates).
- **D-02:** Author `.planning/uat-evidence/v1.42-persona-jtbd/<surface>.md` for each of 8 surfaces (`<surface>` = ledger row key exactly) + roll-up `.planning/v1.42-PERSONA-JTBD-PANEL.md` (table: `surface | disposition | kill-count | tighten-count | links`). **Column-4 integer prohibition:** never place a bare `0`/`1`/`2` in the 4th pipe column of any table — it false-matches the ledger monotonic guard. Use `keep`/`tighten`/`kill`/`clean`/`actionable`/`blocked`/lens-names.
- **D-03:** Page findings are STILL LIVE. Phases 206/207/208 edited ZERO admin page LiveViews. Verify current source; do not assume earlier phases fixed page-level findings.
- **D-04:** Still-live findings anchored in current `lib/sigra/admin/live/*.ex` (see Verified Anchor Table below).
- **D-05:** Already-resolved / waiver-track items — do NOT re-touch: audit pages already use semantic `<details>` (`audit_index_live.ex:82`, `audit_user_live.ex:105`); the `phx-click` disclosure on `users_index_live.ex:121-128` is acceptable divergence; `<.notice>` alarm is correct; per-user-audit "Effective user" absence is defensible → **waiver, not fix**.
- **D-06:** In-place only; NO net-new admin surfaces/routes/pages. Edit source; keep generated copies byte-coherent (confirm canonical path — DONE in this research).
- **D-07:** Every actionable verdict → committed diff OR explicit written waiver + rationale. Waivers reserved for intentional documented asymmetries (per-user-audit Effective-user; scope_ribbon omitted on the two Overview pages, documented at `organization_live.ex:60`).
- **D-08:** `scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0. 7 Tier-2 pages keep Tier-2; **`user-sessions` (lone Tier-1) must NOT be ratcheted** (Phase 210 owns that). Don't lower any page's evidence.
- **D-09:** Page (checkpoint) baselines recapture **CI-native on ubuntu**, NOT darwin (pathTemplate has no OS token → platform-pinned). Two allowlists (`snapshot-allowlist` checkpoint + `snapshot-allowlist-design`). Discipline: add slug → recapture on CI → clear both allowlists before phase close. **Branding has NO checkpoint slug** (9 slugs listed).
- **D-10:** Phase 209 IS the binding gate for the 200–204 canary drift (user-ratified). (1) Allowlist legitimate drifted slugs (`audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin`) vs stale `origin/main`. (2) Re-designate/re-baseline the `impersonation-banner` canary with documented WCAG-fix rationale — do NOT revert the WCAG fix, do NOT guess-fix. Net effect: PR #63 `fast_checks` snapshot-canary lane goes green. Phase's own recaptures close with both allowlists empty + canary byte-stable vs phase HEAD.

### Claude's Discretion

- Exact per-surface verdicts the fresh adversarial panel produces (D-04 worklist is the expected FLOOR, not a ceiling).
- Which actionable verdicts resolve as in-place diffs vs documented waivers (within the D-07 boundary).
- Whether to run the panel via per-page/per-lens adversarial subagents or direct authoring against live DOM.
- Plan decomposition (panel-authoring → remediation by page cluster → baseline-recapture + canary/allowlist-integration).
- The exact wording of the canary re-designation rationale (D-10 part 2).

### Deferred Ideas (OUT OF SCOPE)

- `user-sessions` Tier-2 elevation + 3 persona flows → **Phase 210** (PAGE-03, FLOW-01). 209 does copy/IA on user-sessions ONLY, not the tier ratchet.
- Terminal ratification (every cell `2`, idempotent recapture, generated-host parity, milestone audit) → **Phase 211** (GATE-01, GATE-02).
- Library shard-2 `NoopTest` log-capture flake (Addendum of the folded canary todo) → milestone cleanup, NOT folded here.
- Net-new admin surfaces (e.g. `board-cfg-org` composite, dedicated invite-flow page) → forbidden by D-06.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PAGE-01 | Adversarial persona panel renders one committed scored review doc per surface (`.planning/uat-evidence/v1.42-persona-jtbd/<surface>.md`) for all 8 pages, 3-persona verdicts + per-surface disposition, indexed by roll-up (`.planning/v1.42-PERSONA-JTBD-PANEL.md`). | Rubric output schema fully extracted (§Rubric Instrument); ledger row keys confirmed (§Ledger Tier State); column-4 prohibition mechanics confirmed (§Gate Mechanics). |
| PAGE-02 | Judgment-level remediations applied across pages — every actionable verdict remediated with diff or explicitly waived — monotonic guard green + baselines recaptured under allowlist→clear. | All D-04 anchors verified (§Verified Anchor Table); single-source edit surface confirmed (§Canonical Source); recapture/canary mechanics mapped (§Gate Mechanics); D-10 collision + resolution path documented. |
</phase_requirements>

## Verified Anchor Table (HIGHEST-VALUE OUTPUT)

Every D-04 anchor opened against current `lib/sigra/admin/live/*.ex` (files last modified 2026-06-26; D-03 "never touched by 206/207/208" CONFIRMED). `[VERIFIED: <file>:<line>]`.

| # | Anchor (D-04) | Current status | Corrected location / note |
|---|---------------|----------------|---------------------------|
| 1 | `index_live.ex:52` bare "All clear" | **ACCURATE** | `:52` `All clear` in the `else` of the zero-risk notice. `[VERIFIED: index_live.ex:52]` |
| 2 | `index_live.ex:88` "Total users" (Overview) | **ACCURATE** | `:88` `label="Total users"`; also `:90` `value_suffix="total users"`. `[VERIFIED: index_live.ex:88]` |
| 3 | `users_index_live.ex:188` "Total users" (Users-List strip) | **ACCURATE** | `:188` `label="Total users"` — the duplication partner of #2. `[VERIFIED: users_index_live.ex:188]` |
| 4 | `organization_live.ex:95` bare `<p class="sg-section-copy">` members empty-state | **ACCURATE** | `:95` opens the bare `<p>`. `[VERIFIED: organization_live.ex:95]` |
| 5 | `organization_live.ex:96` members empty-state dead-end (no invite link) | **ACCURATE** | `:96` copy "No members yet — invite members…" is prose with NO link. **See Open Question OQ-1: no admin invite route exists.** `[VERIFIED: organization_live.ex:96]` |
| 6 | `organization_live.ex:117` bare `<p>` pending-invitations empty-state | **ACCURATE** | `:117` opens the bare `<p>`. `[VERIFIED: organization_live.ex:117]` |
| 7 | `organization_live.ex:60` documented scope_ribbon omission | **ACCURATE** | `:60` comment: "scope_ribbon intentionally omitted on Overview…". Waiver anchor per D-07. `[VERIFIED: organization_live.ex:60]` |
| 8 | `user_show_live.ex:57` sessions count in `<dl class="sg-summary-facts">` | **ACCURATE** | `:57` `{length(@detail.sessions)}`. `[VERIFIED: user_show_live.ex:57]` |
| 9 | `user_show_live.ex:84` Sessions panel sub-heading count (dup of #8) | **ACCURATE** | `:84` `{pluralize(length(@detail.sessions), "active session")}`. `[VERIFIED: user_show_live.ex:84]` |
| 10 | `user_show_live.ex:86` "Manage sessions" secondary button | **ACCURATE** | `:86-88` `<a class="sg-btn sg-btn--secondary sg-btn--sm">Manage sessions`. `[VERIFIED: user_show_live.ex:86]` |
| 11 | `user_show_live.ex:115/:146/:182/:202` four `<.empty_state>` copies | **ALL ACCURATE** | `:115` sessions, `:146` identities, `:182` orgs, `:202` audit. `[VERIFIED: user_show_live.ex:115,146,182,202]` |
| 12 | `user_show_live.ex:47` kicker "User" | **ACCURATE** | `:47` `<p class="sg-page-kicker">User</p>`. `[VERIFIED: user_show_live.ex:47]` |
| 13 | `user_sessions_live.ex:108` `<h1>Sessions` heading divergence | **ACCURATE** | `:108` `<h1 class="sg-page-title">Sessions</h1>`; kicker "User" at `:107`. Sibling detail pages use entity-name H1. `[VERIFIED: user_sessions_live.ex:108]` |
| 14 | `user_sessions_live.ex:206/:209` revoke copy "They can sign in again" | **DRIFTED (1 line)** | Actual: `:205` (`revoke_session_copy`) and `:209` (`revoke_all_sessions_copy`). Anchor said `:206`; correct line is **`:205`**. `:209` accurate. `[VERIFIED: user_sessions_live.ex:205,209]` |
| 15 | `users_index_live.ex:107-114` chips INSIDE `<form>` | **ACCURATE** | `<form>` opens `:90`, closes `:176`; chips `:107-114` are inside. Per UI-SPEC this is CANONICAL (List Archetype) — confirm no regression, NOT a fix. `[VERIFIED: users_index_live.ex:90,107-114,176]` |
| 16 | `users_index_live.ex:121-128` phx-click disclosure | **ACCURATE** | `:121-128` `toggle_filters` button, `aria-expanded`. D-05 says acceptable divergence → likely `keep`/waiver. `[VERIFIED: users_index_live.ex:121-128]` |
| 17 | `audit_index_live.ex:56` scope_ribbon BELOW header | **ACCURATE** | `</header>` at `:55`, `<.scope_ribbon>` at `:56` — the lone outlier (siblings render it above). `[VERIFIED: audit_index_live.ex:55-56]` |
| 18 | `audit_index_live.ex:91` "Effective user" filter | **ACCURATE** | `:91` `<span class="sg-field-label">Effective user</span>`. `[VERIFIED: audit_index_live.ex:91]` |
| 19 | `audit_index_live.ex:142-149` chips OUTSIDE form | **ACCURATE** | `</form>` at `:140`, chips `:142-147`. `[VERIFIED: audit_index_live.ex:140,142-149]` |
| 20 | `audit_index_live.ex:82` `<details>` disclosure | **ACCURATE** (D-05 already-resolved) | `:82` semantic `<details>`. Do NOT touch. `[VERIFIED: audit_index_live.ex:82]` |
| 21 | `audit_user_live.ex:105` `<details>` disclosure | **ACCURATE** (D-05 already-resolved) | `:105`. Do NOT touch. `[VERIFIED: audit_user_live.ex:105]` |
| 22 | `audit_user_live.ex:163-172` chips OUTSIDE form | **ACCURATE** | `</form>` at `:161`, chips `:163-172`. `[VERIFIED: audit_user_live.ex:161,163-172]` |
| 23 | `audit_user_live.ex` "Effective user" ABSENT (waiver) | **CONFIRMED ABSENT** | 0 matches for "Effective user" / "effective_user" — per-user audit is subject-scoped → **waiver per D-05/D-07**. `[VERIFIED: audit_user_live.ex grep count = 0]` |
| 24 | `branding_live.ex:106` hardcoded scope_ribbon literal | **ACCURATE** | `:106` `<.scope_ribbon copy="Global auth/email profile" />`. **NOTE: branding has NO `defp scope_copy/1` helper** — see Open Question OQ-2. `[VERIFIED: branding_live.ex:106]` |
| 25 | `components.ex:410` `<.empty_state>` | **ACCURATE** | `:410` `def empty_state(assigns)`; attrs `title` (required) + `inner_block` slot for body/CTA. `[VERIFIED: components.ex:410]` |
| 26 | `components.ex` `<.scope_ribbon>` + `scope_copy/1` | **PARTIALLY DRIFTED** | `<.scope_ribbon>` at `components.ex:465` (attr `:copy` required, `:461`). But `scope_copy/1` is **NOT** in components.ex — it is a `defp` duplicated in 5 LiveViews. `[VERIFIED: components.ex:461,465 + grep scope_copy]` |

**New adversarial findings (beyond the D-04 floor — the forced-finding floor will surface these):**
- **NEW-1:** `organization_live.ex:69` ALSO renders bare "All clear" (same bug as index_live:52). D-04 cited only index_live. Both Overview alarm notices share the defect → remediate both for consistency (or the panel's Question-3 "coherence / diverges from sibling" will flag it). `[VERIFIED: organization_live.ex:69]`
- **NEW-2:** `scope_copy/1` returns **divergent** copy per page: `"Global user operations"` (user_show, user_sessions, users_index) vs `"Global audit explorer"` (audit_index, audit_user). A shared helper is not a drop-in — the branding fix must add a context-appropriate string, not blindly reuse an existing helper. `[VERIFIED: grep scope_copy across lib/sigra/admin/live/]`

## Canonical Source-of-Truth (D-06 research target — RESOLVED)

**Finding:** The 8 admin page LiveViews AND `components.ex` are **library-owned, single-source**, NOT generated into host apps.

| Path | Ownership | Coherence chain |
|------|-----------|-----------------|
| `lib/sigra/admin/live/*.ex` (8 pages) | **Library single-source** | NONE — no generated copy. Host router references `Elixir.Sigra.Admin.Live.*` directly (`[VERIFIED: test/example/lib/example_web/router.ex:280-286,313-316]`). |
| `lib/sigra/admin/components.ex` | **Library single-source** | NONE — one copy only (`[VERIFIED: find components.ex → single result]`). |
| `priv/templates/sigra.install/admin/sigra_admin.css` | Host-shipped generated | → `test/example/` copy + `install_golden/` must stay byte-coherent. **Not touched by D-04.** |
| `priv/templates/sigra.install/admin/admin_hooks.js`, `components/admin_shell.ex`, `router_injection.ex`, `layouts_admin_injection.ex` | Host-shipped generated | Byte-coherence chain — **not touched by D-04.** |

**Implication for the planner:** Every D-04 remediation edits a single library file (`lib/sigra/admin/live/*.ex` or `components.ex`). There is **no `priv/templates` mirror to update and no `install_golden` fixture to regenerate** for these edits. D-06's "edit source so the generated copy stays byte-coherent" is a real constraint but applies to a DIFFERENT file set that this phase's worklist does not touch. Do NOT search for or attempt to sync a generated copy of the LiveViews — there isn't one. (If a remediation unexpectedly requires a CSS change in `sigra_admin.css`, THEN the coherence chain + design-lane recapture apply.)

## Rubric Instrument (exact output schema — `guides/reference/admin-persona-jtbd-rubric.md`)

**3 lenses** (entry-point + intent bound, not credential): Platform admin (`/admin`, triage, `admin@demo.tasklane.test`), Support investigator (`/admin/users/:id`, investigate, admin acting on a target), Org admin (`/admin/organizations/:slug`, bound, `morgan@demo.tasklane.test`).

**3 verdict questions** (refutation prompts): (Q1) Earning its place? [verbosity/info-dump], (Q2) Is the IA muddy? [hierarchy], (Q3) Redundant / coherent / least-surprising? [redundancy/coherence]. Each has a `NONE — searched for: <what>` path.

**Verdict scale:** `keep` / `tighten` / `kill`. Element disposition = **worst verdict across the 3 lenses**.

**Surface disposition rollup (rubric §77-80):** any `kill` element → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

> ⚠ **Terminology reconciliation (planner MUST handle):** The rubric maps "any kill → `blocked`". But SC-1/SC-2/D-07 treat BOTH tighten and kill as "actionable verdicts to remediate," and a `blocked` disposition in SC-1's `clean`/`actionable`/`blocked` set means "blocked by external dep" (per UI-SPEC L144). A page whose worst verdict is `kill` but which CAN be remediated in-place this phase should resolve to a remediation diff, not sit in a `blocked` limbo. **Recommendation:** treat the rubric's mechanical rollup (`kill→blocked`) as the *raw* disposition, then in the roll-up index reflect the *resolved* state — a `kill` remediated in-place moves to `clean`; a `kill` that genuinely cannot be fixed this phase (external dep) stays `blocked` with rationale; anything left `tighten` unremediated is `actionable`. The planner should define this mapping explicitly in the panel-authoring plan so SC-2 ("no unresolved actionable verdicts") is unambiguous.

**YAML frontmatter (all keys required):**
```yaml
---
surface: <ledger row key, e.g. "users-index-live">
ledger_cell: <same as surface for L3>
rubric_version: "1.0"
disposition: clean | actionable | blocked
verdicts:
  platform_admin: {earning_its_place: …, ia_muddy: …, redundant_coherent_surprising: …}
  support_investigator: {…}
  org_admin: {…}
findings:
  - element: "<DOM anchor>"
    lens: platform_admin | support_investigator | org_admin
    question: earning_its_place | ia_muddy | redundant_coherent_surprising
    refutation: "<one-line failure>"
    disposition_action: tighten | kill
---
```
All 9 `verdicts` keys always present. `findings: []` when `clean`.

**Markdown body:** one section per lens, ordered `## Platform Admin Lens` → `## Support Investigator Lens` → `## Org Admin Lens`; each has 3 subsections (`### Earning its place?`, `### Is the IA muddy?`, `### Redundant / coherent / least-surprising?`), each ending in a cited finding OR `NONE — searched for: <what>`.

**Roll-up index format** (`v1.42-PERSONA-JTBD-PANEL.md`):
```
| surface | disposition | kill-count | tighten-count | links |
```
`disposition` column holds `clean`/`actionable`/`blocked` — NEVER `0`/`1`/`2`. `[CITED: admin-persona-jtbd-rubric.md:288-294]`

## Ledger Tier State (`guides/reference/admin-quality-ledger.md`)

The **8 ledger row keys** (= D-02 `<surface>` filenames, verified `[VERIFIED: admin-quality-ledger.md:85-92]`):

| Ledger key (`<surface>.md`) | Checkpoint slug | Level | Tier | Notes |
|-----------------------------|-----------------|-------|------|-------|
| `index-live` | `global-overview` | L3 | **2** | key ≠ slug — note the mapping |
| `organization-live` | `org-overview` | L3 | **2** | |
| `users-index-live` | `global-user-index` | L3 | **2** | |
| `user-show-live` | `user-detail` | L3 | **2** | owns confirm-dialog evidence via modal spec |
| `user-sessions` | `user-sessions` | L3 | **1** | **LONE Tier-1 — do NOT ratchet (D-08); Phase 210** |
| `audit-index-live` | `audit-explorer` | L3 | **2** | |
| `audit-user-live` | `user-audit` | L3 | **2** | |
| `branding-live` | *(none)* | L3 | **2** | **NO checkpoint slug** — evidence is modal-interaction spec |

Additional non-page slugs present in checkpoint snapshots but NOT page rows: `org-scoped-admin`, `impersonation-banner` (the canary). Flow rows `flow-platform-admin` / `flow-support-investigator` / `flow-org-admin` are L4 Tier-1 (Phase 210).

**Monotonic guard parse (`quality-ledger-monotonic.sh`):** `grep -E '^\| [a-z]'` then `awk -F'|'` extracting `$2` (item) and `$4` (tier) **only when `$4 ~ /^[012]$/`**. Fails if any HEAD tier `< base tier`. This is the exact mechanism the **column-4 integer prohibition (D-02)** protects — a bare `0/1/2` in the 4th pipe column of any panel/roll-up table would be parsed as a phantom ledger row. `[VERIFIED: quality-ledger-monotonic.sh:22-56]`

## Gate Mechanics (SC-3, SC-4, D-08, D-09, D-10)

### `scripts/ci/snapshot-canary-guard.sh` `[VERIFIED: full read]`
- Default `BASE=HEAD` (`:19`); CI passes `--base origin/${base_ref}` for PRs (`ci.yml:66-75` → `steps.base.outputs.ref`).
- Default `CANARY=impersonation-banner` (`:20`); design-lane invocation overrides `--canary board-notice` + `SNAP_DIR=…admin-design…-snapshots` + `--allowlist …-design` (`ci.yml:104-108`).
- `slug_of` strips BOTH `-admin-checkpoints-{chromium,mobile,dark}.png` AND `-admin-design-*` suffixes (`:53-57`) — one line covers all 3 projects.
- Compares tracked diff vs BASE + untracked (`??`) PNGs. Any changed slug NOT in the allowlist → FAIL (`:106-108`).
- **Canary rule (`:93-104`):** canary is NOT allowlistable. `added` canary (first-establishment) → OK. `modified`/`deleted`/`mixed` canary → **hard FAIL** ("must stay byte-green"). **This is the D-10 collision.**
- `--require-all` (`:114-121`): every allowed slug MUST have changed (used by the recapture gate to prove intent).

### `scripts/ci/quality-ledger-monotonic.sh` `[VERIFIED: full read]`
- See parse mechanics above. `--base origin/main` (D-08) compares against integration base. Exits 0 iff no tier decreased. Self-test: `quality-ledger-monotonic.test.sh` (`ci.yml:112`).

### `playwright.config.ts` `[VERIFIED: :64-67]`
- `toHaveScreenshot.pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'` — **NO `{platform}` token** → baselines are platform-pinned to the capturing OS (ubuntu CI). D-09 darwin prohibition confirmed: darwin recapture ≠ ubuntu bytes → CI byte-fail.
- 3 checkpoint projects: `admin-checkpoints-{chromium,mobile,dark}` (`:114-145`).

### `admin-checkpoints.spec.ts` + `-snapshots/` `[VERIFIED: grep + ls]`
- **9 checkpoint slugs exactly:** `audit-explorer`, `global-overview`, `global-user-index`, `impersonation-banner`, `org-overview`, `org-scoped-admin`, `user-audit`, `user-detail`, `user-sessions`. **branding has NO slug** (SC-4 confirmed — no branding baseline to recapture).
- Canary captured at `:301-302` (`captureAndVerify` + `assertCheckpointScreenshot` for `impersonation-banner`).

### Allowlists (current state) `[VERIFIED: cat both files]`
- `test/example/priv/playwright/snapshot-allowlist` — EMPTY (comments only). Explicitly: "The `impersonation-banner` canary must NEVER appear here."
- `test/example/priv/playwright/snapshot-allowlist-design` — EMPTY (comments only). Design canary = `board-notice`; "must NEVER appear here." Slugs use hyphenated filename form.

### CI recapture jobs `[VERIFIED: ci.yml grep + read]`
- **Design lane HAS a CI-native ubuntu recapture job:** `admin_design_recapture` (`:1386`) — deletes existing canary PNG so recapture is `added` not `modified` (`:1494`), recaptures 72 design PNGs, gates via `snapshot-canary-guard.sh`, commits to `ci/recapture-admin-design-<run_id>` branch + opens a PR for review (`:1560-1579`). NOT in `ci-gate.needs`.
- **Checkpoint lane has NO analogous CI recapture job.** Historically recaptured via the MANUAL `snapshot-recapture-gate.sh` on a booted example at :4011 (Phase 183 evidence, STATE:71) — which on a dev machine is darwin. **This is the central D-09 tension → Open Question OQ-3.**
- The `wip/recapture-trigger` branch/guard-relax pattern referenced in 208.1 was a one-time guard relaxation **deleted at 208.1-04 close** (ROADMAP:165) — it is NOT a standing recapture mechanism to reuse.

## Common Pitfalls

### Pitfall 1: Assuming a `priv/templates` LiveView copy exists to keep coherent
**What goes wrong:** Planner adds tasks to edit + byte-sync a generated copy of the 8 LiveViews.
**Why it happens:** D-06 phrasing emphasizes byte-coherence; CONTEXT hedged ("confirm canonical source path").
**How to avoid:** There is NO generated LiveView copy (this research proved single-source). Edit `lib/sigra/admin/**` directly; no `install_golden` regen for these edits. Coherence chain applies only if a CSS/JS asset is touched.
**Warning sign:** A task referencing `priv/templates/sigra.install/admin/*_live.ex` — that path does not exist.

### Pitfall 2: Column-4 bare integer in a panel/roll-up table
**What goes wrong:** `quality-ledger-monotonic.sh` false-matches a `0/1/2` in the 4th pipe column of a panel doc as a ledger row, corrupting the monotonic check.
**How to avoid:** D-02 rule — use `keep`/`tighten`/`kill`/`clean`/`actionable`/`blocked`/lens-names in column 4. `kill-count`/`tighten-count` columns in the roll-up are columns 3-4 → keep them non-`^[012]$` (e.g. write counts as `2 kills` / `×2`, or place them in columns beyond 4, or ensure the row does not start with `| [a-z]`). Verify: run `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` locally after authoring docs.
**Warning sign:** A roll-up row like `| audit-index-live | actionable | 0 | 2 | …` — the `0` in column 3 is fine (guard reads column 4), but `| foo | bar | baz | 1 |` would false-match. Design the table so column 4 is never a bare integer.

### Pitfall 3: Recapturing checkpoint baselines on darwin
**What goes wrong:** Local `--update-snapshots` on a Mac produces pixel-different PNGs that byte-fail ubuntu CI (no OS token in pathTemplate).
**How to avoid:** D-09 — recapture CI-native on ubuntu only. See OQ-3 for the mechanism decision.

### Pitfall 4: Trying to allowlist the canary to clear D-10
**What goes wrong:** Adding `impersonation-banner` to the allowlist — the guard ignores the allowlist for the canary (`:93-99`) and the allowlist file explicitly forbids it.
**How to avoid:** D-10 part 2 — re-baseline the canary. Once the new baseline is committed, `--base HEAD` shows it unchanged (byte-stable). The `--base origin/main` integration comparison is resolved by the re-baseline landing in the phase's commits (the canary's `origin/main` version is superseded), with a documented rationale artifact. Do NOT revert the WCAG fix.

### Pitfall 5: Over-remediating D-05 already-resolved items → needless baseline churn
**What goes wrong:** "Fixing" the `<details>` disclosures or the acceptable `phx-click` divergence recaptures baselines and burns allowlist discipline for no benefit.
**How to avoid:** D-05 list is do-not-touch. Only DOM-changing remediations force a slug recapture — map each remediation to the slug(s) it touches (see Sequencing).

## Runtime State Inventory

> This is a copy/IA remediation phase (source edits + planning docs), NOT a rename/data migration. Runtime-state categories checked for completeness:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB keys/collections/user_ids renamed. Copy/component edits only. | None — verified: D-04 worklist is markup/copy, no schema or seed changes. |
| Live service config | None — no external service config embeds the changed copy. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | None. | None. |
| Build artifacts / baselines | **Playwright checkpoint PNG baselines** for touched slugs become stale after DOM-changing remediations; the `impersonation-banner` canary is stale vs `origin/main` (204-03). | Recapture touched checkpoint slugs CI-native (OQ-3); re-baseline canary (D-10). `install_golden` fixture: NOT affected (no LiveView copy in it). |

## Sequencing & Slug-Impact Map (planning risk surface)

**Which remediation touches which checkpoint slug** (a DOM change to a page → its slug must recapture; copy-only changes to visible text also change the rendered PNG):

| Remediation (page) | Ledger key | Checkpoint slug to recapture |
|--------------------|-----------|------------------------------|
| index_live "All clear" → posture copy; total-users dedup | `index-live` | `global-overview` |
| organization_live empty-states → `<.empty_state>`; "All clear" (NEW-1); invite CTA | `organization-live` | `org-overview` |
| users_index total-users (dedup partner); confirm chips-in-form no regression | `users-index-live` | `global-user-index` |
| user_show sessions-count dedup; "Manage sessions" prominence; 4 empty_state copies; kicker | `user-show-live` | `user-detail` |
| user_sessions H1 entity-name; revoke copy (copy/IA ONLY — no tier ratchet) | `user-sessions` | `user-sessions` |
| audit_index scope_ribbon above header; chips position | `audit-index-live` | `audit-explorer` |
| audit_user chips position (waiver Effective-user) | `audit-user-live` | `user-audit` |
| branding scope_ribbon literal → computed copy | `branding-live` | **none (no slug)** — no recapture; glossary/modal spec cover it |

**Two distinct base comparisons in ONE phase (D-10 + phase-own):**
- **Phase-own recaptures** reconcile vs **phase HEAD** (`--base HEAD` default): after the new baselines commit, `--base HEAD` shows 0 changed slugs → allowlists cleared at close.
- **Integration reconciliation (D-10)** reconciles vs stale **`origin/main`** (`--base origin/main`): the 4 drifted slugs (`audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin`) are allowlisted so the PR #63 `fast_checks` lane reads them as intended; the canary is re-baselined. **These two comparisons can conflict** — a slug both Phase-209-recaptured AND in the 200-204 drift set (e.g. `audit-explorer`, `user-audit`, `global-user-index`) is touched by both. Recommendation: perform the phase-own recaptures LAST, so the final committed baseline is the phase's; the D-10 allowlisting is the integration-base reconciliation layered on top and the allowlists still clear at close because the final `--base HEAD` is byte-stable.

**Panel-before-or-after remediation:** Author the 8 panel docs FIRST (they must capture the pre-fix live DOM as the adversarial evidence — a doc that scores an already-fixed page produces no findings and fails the forced-finding floor's intent). Then remediate. Then append a resolution note per finding (diff commit ref or waiver). This also lets the panel's Question-3 coherence lens catch NEW-1 (org "All clear") and NEW-2 (scope_copy divergence) before they're fixed.

## Open Questions (RESOLVED)

1. **OQ-1 — Org members empty-state invite CTA target.** UI-SPEC L157 requires the members empty-state action link "must be present (not a dead-end)." But the admin OrganizationLive (`/admin/organizations/:slug`) is a **read-only overview** — there is NO admin invite-creation route. The only member-management surface is the host-owned `OrganizationMembersLive` at org-scoped `/members` (under `RequireMembership`, not the admin pipeline) `[VERIFIED: router.ex:257]`; invitation acceptance is public `/invitations/:token/accept`. "No net-new surfaces" (D-06) forbids adding an admin invite page.
   - What we know: no admin-pipeline invite route exists; a member-facing `/members` route does.
   - What's unclear: whether the empty-state CTA should link to `/members` (crossing pipeline boundaries), point at the existing "Support members" task-card target, or become a **documented waiver** ("admin overview is read-only; invitation creation lives on the member self-service surface").
   - **RESOLVED: documented `Waiver:`** — there is no admin-pipeline invite route (`router.ex:257` exposes only the host-owned `/members` under `RequireMembership`); the admin org overview is read-only, so a cross-pipeline invite link would violate D-06 (no net-new surfaces / read-only overview). Disposition = **waiver, NOT a `/members` cross-link**. The `<.empty_state>` component swap still lands (real fix); the "action link" clause is resolved as a documented `Waiver:` with the read-only-overview rationale. The executor MUST NOT invent a boundary-crossing link. (Reflected in Plan 03, org-members empty-state task.)

2. **OQ-2 — Branding scope_copy remediation is not a helper-reuse.** `branding_live.ex` has NO `defp scope_copy/1`; the 5 pages that do return divergent strings (NEW-2). The fix must supply a branding-appropriate computed copy (e.g. `"Global auth/email profile"` for global vs an org-scoped variant), not blindly import an existing helper.
   - **RESOLVED:** add a branding-context `defp scope_copy/1` to `branding_live.ex` mirroring the sibling pattern, returning branding-context copy per scope (do NOT blindly reuse a sibling's string — NEW-2). (Already reflected in Plan 04 Task 3.)

3. **OQ-3 — CI-native checkpoint recapture mechanism (HIGH priority).** D-09 mandates ubuntu-native checkpoint recapture, but there is NO checkpoint-lane CI recapture job (only `admin_design_recapture` for the design lane). Historical checkpoint recapture used the manual `snapshot-recapture-gate.sh` on :4011 (darwin on a dev box).
   - What we know: pathTemplate is platform-pinned; `admin_design_recapture` is a working ubuntu-native recapture-and-PR pattern to mirror.
   - What's unclear: whether the plan (a) adds a `admin_checkpoint_recapture` job cloned from `admin_design_recapture` (canary-delete-then-add trick, commit to `ci/recapture-admin-checkpoints-<run_id>` PR), (b) reuses an existing dispatch, or (c) whether darwin-vs-ubuntu pixel diff is actually within tolerance for these specific slugs (unlikely — font rendering differs).
   - **RESOLVED:** mirror the `admin_design_recapture` job for the checkpoint lane (SNAP_DIR = checkpoints dir, `--canary impersonation-banner`, allowlist = `snapshot-allowlist`). This is the lowest-risk path and reuses a proven pattern. (Already reflected in Plan 01.)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/Phoenix (existing) | Editing LiveViews, running `mix test` (glossary_test) | ✓ (project) | per CLAUDE.md stack | — |
| Postgres (test DB) | `mix test` glossary/ledger self-tests | ✓ via `scripts/db/up.sh` | — | localhost:5432 fallback |
| Playwright + ubuntu CI | Checkpoint recapture (D-09) | ✓ CI-native | project-pinned | **No local darwin recapture** (D-09 prohibition) |
| `gh` CLI | PR #63 status, CI-native recapture PR | ✓ (used in `admin_design_recapture`) | — | — |

**Missing dependencies with no fallback:** None blocking. The checkpoint-lane CI recapture *job* does not yet exist (OQ-3) — this is a plan task, not a missing tool.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) + Playwright (browser baselines) |
| Config file | `test/example/priv/playwright/playwright.config.ts`; ExUnit via `mix test` |
| Quick run command | `mix test test/sigra/admin/glossary_test.exs` (copy drift guard) |
| Full suite command | `mix test` + CI Playwright checkpoint/design lanes + `fast_checks` guards |

### Phase Requirements → Test Map
| Req | Behavior | Test type | Automated command | Exists? |
|-----|----------|-----------|-------------------|---------|
| PAGE-01 | 8 panel docs + roll-up exist, schema-valid, column-4 clean | doc-lint / guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` (proves no column-4 false-match) | ✅ (guard exists) |
| PAGE-02 | Copy remediations pass glossary; no banned synonyms | unit | `mix test test/sigra/admin/glossary_test.exs` | ✅ |
| PAGE-02 (SC-3) | No Tier-2 page regresses | guard | `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` | ✅ |
| PAGE-02 (SC-4) | Touched checkpoint slugs recaptured; canary byte-stable; allowlists empty | guard | `bash scripts/ci/snapshot-canary-guard.sh --base origin/main` (+ design lane) | ✅ (recapture JOB for checkpoints = OQ-3) |
| PAGE-02 | Remediated pages still render / behave | browser | `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium` (+ behavior specs) | ✅ |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/admin/glossary_test.exs` + `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main`.
- **Per wave merge:** full `fast_checks` guard set (`snapshot-canary-guard.sh` checkpoint + design, `quality-ledger-monotonic.sh`, self-test).
- **Phase gate:** ubuntu CI checkpoint recapture green, both allowlists empty, canary byte-stable, PR #63 `fast_checks` lane green.

### Wave 0 Gaps
- [ ] **Checkpoint-lane CI recapture job** (OQ-3) — `admin_design_recapture` exists; the checkpoint analog does not. Likely a Wave-0/early-wave enabler task if the plan chooses to add it.
- [ ] No new ExUnit test files required — glossary_test already scopes all 8 LiveViews + components.ex; existing checkpoint/modal/flow specs cover behavior.

## Security Domain

Not applicable to this phase's changes. Phase 209 remediates admin-UI copy/IA/component-usage; it does not alter authn/authz, session handling, crypto, input validation, or access-control logic. The one adjacent security-posture consideration is **editorial**: the `user_sessions_live.ex:205/:209` revoke copy ("They can sign in again") must, per UI-SPEC L156, "preserve security-remediation posture without undermining urgency" — this is a copywriting constraint, not a security control change. The revoke *action* and its ConfirmDialog APG gates are unchanged (D-08: don't lower evidence; confirm-dialog ownership stays on UserSessionsLive per UI-SPEC L211). `security_enforcement`: no threat-model change; ASVS categories unaffected by copy edits.

## Sources

### Primary (HIGH confidence — read this session)
- `lib/sigra/admin/live/{index,organization,user_show,user_sessions,users_index,audit_index,audit_user,branding}_live.ex` — all 8 pages read/grepped; every D-04 anchor verified.
- `lib/sigra/admin/components.ex` — `empty_state:410`, `scope_ribbon:465`, `notice:509` verified.
- `guides/reference/admin-persona-jtbd-rubric.md` — full output schema, lenses, forced-finding floor, column-4 prohibition, roll-up format.
- `guides/reference/admin-quality-ledger.md:60-95` — tier state (7 Tier-2 pages, user-sessions Tier-1, branding no slug), monotonic parse target.
- `scripts/ci/snapshot-canary-guard.sh`, `scripts/ci/quality-ledger-monotonic.sh` — full read; gate mechanics.
- `test/example/priv/playwright/playwright.config.ts:64-67` — pathTemplate (no OS token), 3 checkpoint projects.
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` + `-snapshots/` — 9 slugs, canary at :301-302.
- `test/example/priv/playwright/snapshot-allowlist` + `-design` — both EMPTY; canary-ban notes.
- `.github/workflows/ci.yml` — `fast_checks` base-ref (:66-75), guard invocations (:101-112), `admin_design_recapture` (:1386-1685); no checkpoint recapture job.
- `test/sigra/admin/glossary_test.exs` + `guides/reference/admin-glossary.md` — scope = 8 LiveViews + components.ex; banned-synonym table.
- `test/example/lib/example_web/router.ex:257,280-316` — admin LiveViews mounted as `Sigra.Admin.Live.*` (library-owned); `/members` = host-owned member surface.
- `.planning/todos/pending/2026-06-30-v142-integration-snapshot-canary-drift.md` — D-10 evidence (4 drifted slugs + canary from 200-204).
- `.planning/STATE.md:71,180` — checkpoint recapture history (:4011 via gate); 204-03 canary WCAG modification.
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md:165-182` — PAGE-01/02, SC.

### Secondary / Tertiary
- None — all findings verified against real files this session; no WebSearch or external-doc claims.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Copy-only text changes to a page also alter its checkpoint PNG (visible text renders into the screenshot) → require slug recapture | Slug-Impact Map | If a copy change happens to not shift pixels, recapture is a harmless no-op; low risk. |
| A2 | Mirroring `admin_design_recapture` for the checkpoint lane is the intended OQ-3 resolution | OQ-3 | Planner may choose a different mechanism; flagged as recommendation, not locked. |
| A3 | The org invite-CTA resolves as a **locked waiver** (no admin invite route; read-only overview; cross-pipeline link forbidden by D-06) | OQ-1 (RESOLVED) | No longer an assumption — locked. The executor must NOT add a `/members` cross-link; the action-link clause is a documented `Waiver:`. |

*All other claims are `[VERIFIED]` against read files this session.*

## Metadata

**Confidence breakdown:**
- D-04 anchor verification: HIGH — every anchor opened against current source; one 1-line drift documented.
- Canonical source-of-truth: HIGH — filesystem + router grep prove single-source, no generated LiveView copy.
- Gate/recapture mechanics: HIGH — full reads of both guard scripts, playwright config, CI workflow, allowlists.
- Rubric schema: HIGH — full read of the instrument.
- OQ-1/OQ-3 resolutions: MEDIUM — the *facts* are verified; the *chosen resolution* is a recommendation the planner/user confirms.

**Research date:** 2026-06-30
**Valid until:** 2026-07-14 (stable — internal repo state; re-verify anchors only if `lib/sigra/admin/live/*.ex` is edited before planning)
