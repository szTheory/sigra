---
created: 2026-07-30T00:00:00.000Z
status: pending
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
