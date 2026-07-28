---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Example sigra_auth.css never received the v1.46 stylesheet, and no parity gate exists
area: auth-ui
severity: medium
audit_finding: W-2
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [AUTHUI-01, AUTHUI-03, AUTHUI-04, EXPR-01]
files:
  - test/example/priv/static/assets/sigra_auth.css
  - priv/templates/sigra.install/core/sigra_auth.css
  - test/sigra/install/features/admin_test.exs
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

`test/example/priv/static/assets/sigra_auth.css` is **12,281 bytes** against the canonical
**27,914 bytes** in `priv/templates/sigra.install/core/sigra_auth.css` (the golden fixture
copy is byte-identical to the template). It was last touched by `d0a02f9f` on 2026-06-08 —
before v1.46 — and contains **zero** occurrences of `.sigra-auth-flow`,
`.sigra-auth-action--primary`, `.sigra-auth-disclosure`, or `.sigra-auth-code-list`.

The entire Phase 226/227 semantic vocabulary is missing from the example app's copy.

The drift is **silent** because nothing currently breaks: the example re-brands its own
auth surfaces in the `vt-*` lane, and the library's `/admin/branding` preview
(`lib/sigra/admin/live/branding_live.ex:96`) only uses `sigra-auth--preview` /
`sigra-auth-email-preview` classes, which do exist in the stale copy.

## Root cause — a gate asymmetry

`test/sigra/install/features/admin_test.exs:396` enforces
`DIST-05 example≡template byte-parity` for **`sigra_admin.css`**. There is no equivalent
gate for **`sigra_auth.css`**. So the admin stylesheet cannot drift and the auth
stylesheet drifts freely and invisibly.

## Why it was NOT fixed during v1.46 close-out

Refreshing the example's copy changes what `/admin/branding` renders. That risks drifting
committed admin checkpoint baselines, which are hard-gated by
`scripts/ci/snapshot-canary-guard.sh` and must be recaptured **CI-native on ubuntu**, never
locally on darwin. That is recapture-lane work, not a close-out edit.

## Recommended fix

Two parts, in this order:

1. **Add the missing parity gate**, mirroring `admin_test.exs:396` exactly, so the drift
   can never recur silently. Expect it to fail immediately — that is the point.
2. **Refresh `test/example/priv/static/assets/sigra_auth.css`** from the canonical
   template copy, then run the admin checkpoint lane CI-native and recapture only the
   baselines that legitimately change. Do not recapture on darwin.

Worth checking while in here: whether any *other* installer-owned static asset copied into
`test/example/priv/static/assets/` has the same missing-gate problem.

## Related

- [[reference_example_css_split]] — the 184→185 incident where `sg-*` was split out of
  `app.css` into `sigra_admin.css` and the example's root layout was not updated.
- [[reference_installer_template_drift]] — same failure family: the example and the
  templates are hand-maintained mirrors, and only an explicit gate keeps them honest.
- [[reference_admin_design_baselines_ci_native]] — why the recapture must run on ubuntu.
