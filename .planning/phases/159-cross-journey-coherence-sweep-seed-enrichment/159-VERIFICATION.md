---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
verified: 2026-06-04T22:31:25Z
status: gaps_found
score: 5/6
overrides_applied: 0
gaps:
  - truth: "Empty-state spacing, notice/flash unification, focus/hover parity, back-nav round-trips, and scope_ribbon presence are confirmed on all 6 screens via a scripted Playwright journey filmstrip"
    status: failed
    reason: "admin-coherence-sweep.spec.ts asserts page.locator('.sg-scope-ribbon') on 5 screens, but scope_ribbon/1 in components.ex emits class=\"sg-muted sg-text-sm\" — the class sg-scope-ribbon does not exist anywhere in lib/ or CSS. Every .sg-scope-ribbon toBeVisible() assertion will time out. Additionally, Screen 2 (OrganizationLive, /admin/organizations/acme-corp) has no <.scope_ribbon> component call at all, so even a corrected selector would find nothing there."
    artifacts:
      - path: "test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts"
        issue: "Lines 89, 104, 120, 127, 132 assert .sg-scope-ribbon which is never emitted by any component or CSS"
      - path: "lib/sigra/admin/components.ex"
        issue: "scope_ribbon/1 (line 259) emits class=[\"sg-muted sg-text-sm\", @class] — no sg-scope-ribbon class"
      - path: "lib/sigra/admin/live/organization_live.ex"
        issue: "No <.scope_ribbon> call anywhere in this LiveView; Screen 2 assertion would fail even with corrected selector"
    missing:
      - "Either add sg-scope-ribbon as a stable CSS class to scope_ribbon/1 in components.ex (and update call sites if needed), or change the Playwright assertions to use the class the component actually emits (e.g., getByText with scope copy, or .sg-muted.sg-text-sm scoped to the header)"
      - "Add <.scope_ribbon> to OrganizationLive.render/1 (screen 2) so the org-overview satisfies the coherence contract, or explicitly drop the screen-2 scope_ribbon assertion if overview archetype is exempt"
      - "Re-run npx playwright test admin-coherence-sweep.spec.ts --project=chromium against a seeded dev server to confirm all 6 screens pass"
---

# Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment — Verification Report

**Phase Goal:** The full Platform Operator and Org Admin journeys are coherent end-to-end, seed data makes every screen self-demonstrating, and the motion usage audit is complete.
**Verified:** 2026-06-04T22:31:25Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Seed data includes expired invitation (Expired pill), deletion-scheduled roster member, passkey-only persona, and richer audit events — every previously-empty UI state renders | VERIFIED | `expired-invite@demo.sigra.dev` with `~U[2026-01-01 00:00:00Z]` in seeds.ex:276; grace@demo.sigra.dev as Acme member with `scheduled_deletion: true` in personas.ex:153; pat@demo.sigra.dev with `passkey: true` in personas.ex:139; 4 new @persona_audit_events at offsets 30-33 (seeds.ex:573-601) |
| 2 | Seed enrichment is deterministic (pinned @seed_reference_ts), idempotent (count-threshold + on_conflict guards updated in lockstep), and MIX_ENV=test guarded; running Seeds.run/0 twice produces identical counts | VERIFIED | `@seed_reference_ts ~U[2026-05-15 12:00:00Z]` (seeds.ex:39); count-threshold guard derives from `length(@audit_actions) + length(@persona_audit_events)` (seeds.ex:620); `on_conflict: :nothing` on passkey and invitation inserts; `Mix.env() == :test` guard in priv/repo/seeds.exs:16-18; `expired_invitations` key added to `snapshot_counts/0` in seeds_test.exs:59; idempotency test `first == second` covers all new keys |
| 3 | Motion usage audit complete: keyboard-frequent interactions have no animation; CSS guard verified | VERIFIED (partial — see gap) | `sg-filter-chip` transition removed from unconditional block, now inside `@media (hover: hover) and (pointer: fine)` only (app.css:870-876); CSS change confirmed at lines 858-879. GATE-03 Playwright check (line 145: `expect(transition).not.toContain('transform')`) is present but tautological — see WR-02 warning |
| 4 | Scope_ribbon presence and coherence contract confirmed on all 6 screens via scripted Playwright filmstrip | FAILED | `admin-coherence-sweep.spec.ts` exists and the overall spec structure is correct, but `.sg-scope-ribbon` selector (lines 89, 104, 120, 127, 132) is never emitted by any component — `scope_ribbon/1` emits `class="sg-muted sg-text-sm"` (components.ex:261). Zero occurrences of `sg-scope-ribbon` in lib/ or CSS confirmed by grep. Screen 2 (OrganizationLive) additionally has no `<.scope_ribbon>` call at all. |

**Score:** 5/6 truths verified (SC-4 FAILED — GATE-03 filmstrip spec broken)

### Deferred Items

None.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/admin/organizations/detail.ex` | deletion_scheduled? boolean in member_row type + shape_member_row/1 | VERIFIED | Lines 27, 112: `deletion_scheduled?: not is_nil(Map.get(user, :deleted_at))` — uses Map.get for host-struct safety |
| `lib/sigra/admin/live/organization_live.ex` | Roster deletion pill + expanded format_date/1 (4 clauses) | VERIFIED | Line 137: pill with `data-tone="warn"`, text "Deletion scheduled"; Lines 191-194: 4-clause format_date/1 including NaiveDateTime |
| `lib/sigra/admin/components.ex` | notice/1 wraps slot in `<div>` not `<p>` | VERIFIED | Line 305: `<div class="sg-text-sm">{render_slot(@inner_block)}</div>` |
| `test/example/lib/example/demo/personas.ex` | 9 personas in all/0, 9 entries in feature_map/0 | VERIFIED | 9 email entries confirmed; pat (totp:false, passkey:true), grace (scheduled_deletion:true, org_member::acme); "pat" and "grace" keys in feature_map/0 |
| `test/example/lib/example/demo/seeds.ex` | expired-invite@demo.sigra.dev, grace Acme membership, pat passkey, 4 new audit events | VERIFIED | All 4 CHANGE items confirmed: lines 276, 220-221, 329-336, 573-601; 16 @persona_audit_events total |
| `test/example/test/example/demo/seeds_test.exs` | expired_invitations key + grace/pat/expired-invite test blocks | VERIFIED | Line 59: expired_invitations key; lines 148-169, 173-187: three new test blocks; line 265-274: grace in membership shape test |
| `test/example/priv/static/assets/css/app.css` | sg-filter-chip transition scoped to pointer:fine | VERIFIED | Lines 870-876: transition inside `@media (hover: hover) and (pointer: fine)` only; unconditional block (lines 858-869) has no transition declaration |
| `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` | 6-screen filmstrip spec, no toHaveScreenshot, GATE-03 check | STUB/BROKEN | File exists, correct structure, no toHaveScreenshot calls. BUT: `.sg-scope-ribbon` selector on lines 89, 104, 120, 127, 132 asserts a class that does not exist in the DOM — spec cannot pass |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| detail.ex:shape_member_row/1 | organization_live.ex roster template | `deletion_scheduled?` key in member map | WIRED | member.deletion_scheduled? used in roster pill at line 137 |
| personas.ex:all/0 (pat, passkey:true) | seeds.ex:seed_passkey/1 | pat@demo.sigra.dev lookup + upsert_passkey/2 | WIRED | seeds.ex:329 `pat = users["pat@demo.sigra.dev"]`; line 336 `upsert_passkey(pat, "sigra-demo-pat-passkey-credential-id-v1")` |
| personas.ex:all/0 (grace, scheduled_deletion:true) | seeds.ex:maybe_schedule_deletion/2 + seed_memberships/3 | grace@demo.sigra.dev lookup | WIRED | seeds.ex:220-221 seeds grace as Acme member; maybe_schedule_deletion/2 sets deleted_at |
| seeds.ex:@persona_audit_events | seeds.ex:count-threshold guard | `length(@audit_actions) + length(@persona_audit_events)` | WIRED | seeds.ex:620 auto-derives threshold from list lengths; 16 entries at offsets 0-33 |
| seeds_test.exs:snapshot_counts | seeds_test.exs idempotency test | `expired_invitations` key + `first == second` | WIRED | expired_invitations key at line 59; idempotency test covers all new seed states |
| admin-coherence-sweep.spec.ts | Real DOM via .sg-scope-ribbon selector | page.locator('.sg-scope-ribbon') | NOT_WIRED | Class does not exist; scope_ribbon/1 emits `sg-muted sg-text-sm`; 5 assertions will time out |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| organization_live.ex roster | member.deletion_scheduled? | detail.ex:shape_member_row/1 → seeds.ex grace deleted_at | Yes — grace seeded with deleted_at non-nil via maybe_schedule_deletion/2 | FLOWING |
| users_index_live.ex | Passkeys pill | UserPasskey DB row for pat | Yes — seeds.ex:336 upserts pat's passkey row | FLOWING |
| organization_live.ex invitations | invite.expired? | seeds.ex expired invitation at ~U[2026-01-01 00:00:00Z] | Yes — DateTime.compare returns :lt for past date | FLOWING |

### Behavioral Spot-Checks

Step 7b: Playwright tests cannot run without a live dev server. Static checks only.

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| sg-filter-chip transition NOT in unconditional block | `sed -n '858,869p' app.css` contains no `transition:` | Confirmed — lines 858-869 have no transition declaration | PASS |
| sg-filter-chip transition IS in pointer:fine guard | `sed -n '870,876p' app.css` contains `transition: var(--sg-transition-tone), var(--sg-transition-press)` | Confirmed at line 872 | PASS |
| scope_ribbon component emits sg-scope-ribbon class | `grep -rn "sg-scope-ribbon" lib/ test/example/lib/ test/example/priv/static/` | Zero results — class never emitted | FAIL |
| admin-coherence-sweep.spec.ts has no toHaveScreenshot | `grep "toHaveScreenshot" spec.ts` | Zero results | PASS |
| personas.ex has 9 entries | `grep -c "email:" personas.ex` | 9 | PASS |
| seeds.ex has 16 persona audit events | `grep -c "offset:" seeds.ex` | 16 | PASS |

### Probe Execution

No conventional probe scripts found for this phase. Step 7c: SKIPPED (no probe scripts).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| FIXT-01 | 159-03 | Expired organization invitation seeds the "Expired" pill | SATISFIED | seeds.ex:276 — expired-invite@demo.sigra.dev with expires_at ~U[2026-01-01 00:00:00Z]; seeds_test.exs:173-187 asserts row exists and expires_at is in the past |
| FIXT-02 | 159-01, 159-02, 159-03 | Deletion-scheduled user in org roster seeds the "Deletion scheduled" pill | SATISFIED | detail.ex:112 derives deletion_scheduled?; org_live:137 renders pill; grace persona added; seeds.ex:220-221 seeds Acme membership |
| FIXT-03 | 159-02, 159-03 | Passkey-only (no-MFA) persona seeds the Passkeys pill | SATISFIED | pat persona (totp:false, passkey:true); seeds.ex:329-336 upserts passkey row; seeds_test.exs:159-170 asserts mfa_count==0 and passkey_count>=1 |
| FIXT-04 | 159-02, 159-03 | Richer audit event variety (password change, magic link, API token, second OAuth provider) | SATISFIED | seeds.ex:573-601 — 4 new entries at offsets 30-33: auth.password.change, auth.magic_link.sent, api.token.create, auth.oauth.link |
| FIXT-05 | 159-03 | Seed enrichment deterministic, idempotent, test-guarded, no leakage | SATISFIED | @seed_reference_ts pinned; count-threshold guard auto-derives from list length; on_conflict guards on all upserts; MIX_ENV=test guard in seeds.exs; snapshot_counts updated with expired_invitations key |
| GATE-03 | 159-04 | Motion usage audit: keyboard interactions not animated; CSS guard verified | PARTIAL | CSS change VERIFIED (transition scoped to pointer:fine). Playwright filmstrip spec exists but CANNOT PASS — .sg-scope-ribbon selector asserts a non-existent class. The GATE-03 motion check itself (line 145) is also tautological (see WR-02 below). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts | 89, 104, 120, 127, 132 | `.sg-scope-ribbon` selector — class never emitted by any component | BLOCKER | All 5 scope_ribbon assertions will time out; coherence sweep spec CANNOT PASS against real DOM |
| lib/sigra/admin/live/organization_live.ex | 200-204 | `users_path/1` and `audit_path/1` have no nil-slug catch-all clause | WARNING | FunctionClauseError crash if OrganizationLive is reached with organization_slug: nil (global scope); only affects misconfigured routing |
| lib/sigra/admin/organizations/detail.ex | 121 | `DateTime.compare(expires_at, now)` — raises ArgumentError on NaiveDateTime inputs from host schemas | WARNING | Host app using naive_datetime on OrganizationInvitation.expires_at will crash org overview |
| test/example/lib/example/demo/seeds.ex | 630, 677 | `Repo.transaction(fn -> ... end)` result discarded | WARNING | Rolled-back audit batch silently reports success; run/0 still returns :ok on failure |
| lib/sigra/admin/live/organization_live.ex | 194 | `defp format_date(_), do: "—"` — silent catch-all diverges from components.ex which raises ArgumentError | INFO | Re-introduces the silent fallback the phase set out to retire; populated-but-mistyped expires_at renders as em dash instead of surfacing the bug |
| test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts | 140-145 | GATE-03 motion assertion is tautological — passes regardless of CSS guard presence | WARNING | `expect(transition).not.toContain('transform')` passes in non-pointer:fine environment whether the @media guard is present, absent, or broken; does not verify the GATE-03 contract |

### Human Verification Required

None required — all phase deliverables are statically verifiable or covered by automated tests. The Playwright filmstrip spec is the automated gate and it is broken (BLOCKER above).

### Gaps Summary

**1 BLOCKER — GATE-03 coherence sweep spec is broken (CR-01)**

The `admin-coherence-sweep.spec.ts` spec asserting the Phase 159 coherence contract cannot pass against the real DOM. The root cause is that `159-04-PLAN.md` specified `.sg-scope-ribbon` as the CSS selector for the scope ribbon component, but `scope_ribbon/1` in `lib/sigra/admin/components.ex` emits `class="sg-muted sg-text-sm"` — not `sg-scope-ribbon`. The class `sg-scope-ribbon` does not exist in any lib, template, or CSS file in the repository.

Five scope_ribbon assertions across 5 screens (lines 89, 104, 120, 127, 132) will time out. On Screen 2 (`/admin/organizations/acme-corp`), `OrganizationLive` additionally has no `<.scope_ribbon>` component call at all, so even a corrected selector would find nothing there.

**Fix options** (either approach unblocks the spec):

Option A — Add a stable hook class to `scope_ribbon/1`:
```elixir
# lib/sigra/admin/components.ex
def scope_ribbon(assigns) do
  ~H"""
  <span class={["sg-scope-ribbon sg-muted sg-text-sm", @class]} {@rest}>{@copy}</span>
  """
end
```
Then add `<.scope_ribbon copy={scope_copy(@admin_scope)} />` to `OrganizationLive.render/1` for Screen 2.

Option B — Change assertions to use existing markup:
Replace `.sg-scope-ribbon` with `page.getByText(...)` assertions using the scope copy text, or use `.sg-muted.sg-text-sm` scoped to the header section. Add `<.scope_ribbon>` to OrganizationLive or drop the Screen 2 scope_ribbon assertion.

**3 warnings to consider (lower severity, not blocking phase goal):**

- WR-01: `DateTime.compare/2` in `shape_invitation_row/2` raises if host's `expires_at` is NaiveDateTime — robustness gap in library code
- WR-02: GATE-03 Playwright motion check is tautological — the assertion passes regardless of CSS guard state; consider emulating pointer:fine to make the test discriminating
- WR-04: `Repo.transaction` result discarded in `insert_audit_batch/3` — a rolled-back batch silently succeeds

---

_Verified: 2026-06-04T22:31:25Z_
_Verifier: Claude (gsd-verifier)_
