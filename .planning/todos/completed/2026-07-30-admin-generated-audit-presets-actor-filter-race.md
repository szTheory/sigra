---
created: 2026-07-30T00:00:00.000Z
status: completed
title: "admin-generated.spec.ts's Actor-filter assertion times out — a genuine URL race, distinct from the duplicate-action_prefix bug"
area: admin-ui
files:

  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - lib/sigra/admin/live/audit_live.ex

severity: medium
source: >-
  Diagnosed during Phase 231's GATE-02 gap-closure and dispatch cycles
  (231-GAP-GATE02-SUMMARY.md, 231-05-SUMMARY.md); filed by plan 231-11 per the
  phase's own "diagnose/file, never paper over" mandate — it had only been
  reported inline in plan SUMMARYs, not as a discoverable todo, until now.
owner: unassigned (repo maintainer to triage)
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
resolves_phase: 236
---

## What

`admin-generated.spec.ts:454-458` fills the "Actor" filter field on the admin audit page,
clicks "Apply filters", and asserts the URL picks up `actor=<uuid>`:

```ts
await page.getByLabel("Actor", { exact: true }).fill(actorId);
await page.getByRole("button", { name: "Apply filters" }).click();
await expect(page).toHaveURL(new RegExp(`(?:\\?|&)actor=${actorId}(?:&|$)`));
await expect(page.getByText(`Actor: ${actorId}`, { exact: true })).toBeVisible();
```

`toHaveURL`'s poll (19 identical attempts observed over ~15s) times out: the URL stays pinned
to the **prior preset's** query string (e.g. `...&outcome=failure`, no `actor=` param) rather
than advancing to reflect the Actor fill + Apply click. This is a genuine race in the
form-submission / URL-patch path on `/admin/audit`, not a missing-coverage gap and not the same
defect as the already-filed `2026-07-18-admin-audit-impersonation-filter-not-applying.md`
(that one is a duplicate-`action_prefix`-param collision on the Impersonation chip; this one is
the Actor text field failing to advance the URL at all after Apply).

## Evidence

Observed on two separate CI runs during Phase 231, at commits that touched **neither**
`admin-generated.spec.ts` nor `audit_live.ex` nor any auth/login CSS — ruling out anything in
those commits as the cause:

| Run | Commit | Detail |
|---|---|---|
| `30509363963` (job `90765906278`) | `18c2720a` | `toHaveURL` timeout after typing an Actor filter value and clicking "Apply filters" — the URL never advances past the prior preset state (`...&outcome=failure`, no `actor=` param), across 19 polling attempts over ~15s |
| (a second, separately reported occurrence) | — | Same assertion, same symptom, cited in `231-GAP-GATE02-SUMMARY.md`'s "Two defects reported, not fixed" section |

Both attempt and retry hit the identical timeout — sticky-within-run, not per-attempt
randomness, matching this repo's established signature for a genuine race rather than
environment noise.

## Where to look

- `lib/sigra/admin/live/audit_live.ex` — the filter form's `handle_event`/`push_patch` path for
  the Actor field specifically; confirm whether the patched URL is pushed synchronously with the
  click or depends on a subsequent round-trip (debounce, `phx-change` vs `phx-submit` ordering)
  that a fast Playwright fill+click can outrun.
- `test/example/priv/playwright/tests/admin-generated.spec.ts:454-458` — consider whether the
  assertion needs an intermediate wait (e.g. for the form's own "applied" state) rather than
  polling the URL directly, if the LiveView's URL patch is genuinely async.

## Not fixed here, and why

Diagnosed read-only, twice, by two different Phase 231 plans (the GATE-02 gap-closure task and
plan 231-05), each of which explicitly deferred rather than fixed it: it is unrelated to
GATE-02 (320px reflow) and GATE-04 (admin-eval harness) — the two requirements those plans
owned — and no GATE-0x requirement in Phase 231 covers `admin_live.ex`'s filter-form behavior.

## Owner

Unassigned — files under `lib/sigra/admin/**` (a library-owned surface, so the fix ships to
adopters) and `test/example/priv/playwright/**`. A future phase that owns admin-audit UX or
Playwright reliability should triage this alongside the sibling
`2026-07-18-admin-audit-impersonation-filter-not-applying.md` finding, since both touch the same
filter-form URL-patch mechanism.

## Resolved — 2026-09-18 (Phase 240, plan 240-05; fix landed in Phase 236)

**Corrected coordinates.** The `files:` entry and the line citations above are stale and were
never accurate at the time this todo was read back. Per **Phase 236's** `236-CONTEXT.md` D-06 and
D-07 (`.planning/phases/236-flake-root-cause-reproduce-name-fix/236-CONTEXT.md`):

- The LiveView is `lib/sigra/admin/live/audit_index_live.ex`. The `lib/sigra/admin/live/audit_live.ex`
  named in this todo's `files:` list **does not exist** and never did (its siblings are
  `audit_index_live.ex` and `audit_user_live.ex`).
- The failing assertion is `test/example/priv/playwright/tests/admin-generated.spec.ts:459`, not
  `:454-458`. The test starts at `:427`.
- The `getByRole("button", {name: "Apply filters"}).click()` quoted in the "What" section above
  is **not what the spec does at HEAD**. It uses `actorFilter.press("Enter")` at `:458`, changed by
  commit `2a96d72f` ("ci: authenticate Playwright once, then shard", #168) *after* this todo was
  filed on 2026-07-30. A fix written against the button click would have edited a line that is not
  there.

Phase 240's governing decision for this closure is **D-26** (`240-CONTEXT.md`), which exists
precisely so this todo is not closed against a description that was never true. Note that
`240-CONTEXT.md`'s own D-06 is an unrelated recorded rejected alternative — the corrected
coordinates come from **236**-CONTEXT, not 240-CONTEXT.

**The fix.** Phase 236 (D-08) made `AuditIndexLive` the sole owner of its URL: the filter form
keeps `method="get"` and gains `phx-submit="apply_filters"` (`audit_index_live.ex:96`), a new
`handle_event("apply_filters", …)` normalizes and whitelists params and returns
`push_patch` to a local path (`audit_index_live.ex:56-62`), and `handle_params/3` stays the one
and only loader. The race described above — the URL staying pinned to the prior preset's query
string while `toHaveURL` polled — was the form submission and the URL patch racing each other.

**Phase 240 evidence.** Measured at the job level, never at the run level:

- **SC-1, n = 20.** `workflow_dispatch` run `35377050754` of `green-04-evidence.yml` on `main`
  (head_sha `abec92c4b33005e21b550a2f899fe1d1e0f817a1`) ran twenty repeat legs of
  `Generated admin Playwright smoke`. All twenty concluded `success`;
  `sc1.leg_count = 20`, `sc1.verdict = pass`. This is the lane that carries
  `admin-generated.spec.ts`. Twenty consecutive greens is the opposite of the
  sticky-within-run signature recorded in the Evidence table above.
- **SC-2, the `main` window.** Over `2026-09-16T03:29:55Z..2026-09-18T18:11:54Z` (runs
  `35052017063`, `35056270436`, `35182589738`, `35246681580`, `35307612410`, `35365693716`,
  `35373550987`, `35377012499`), `ci_gate_conclusions` is
  `{"success": 8, "failure": 0, "skipped": 0}` and `flake_attributable_red_count` — `main` runs
  whose `Generated admin Playwright smoke` job concluded `failure` — is **zero**.

Receipt: `.planning/phases/240-green-main-evidence-honest-pages-script/240-GREEN-04-EVIDENCE.json`.
Ledger: `.planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md`.

The claim is bounded to those run ids and that window; it is not a claim that this assertion can
never flake again.
