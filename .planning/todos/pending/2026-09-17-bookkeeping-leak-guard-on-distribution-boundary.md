---
created: 2026-09-17T00:00:00.000Z
status: pending
title: "No CI gate stops planning bookkeeping from leaking back into the generated app or the Hex tarball"
area: ci
files:
  - scripts/ci/install-smoke.sh
  - .github/workflows/ci.yml
  - priv/templates/

source: "Phase 239 UAT (automated verification) — SC-1/SC-2 were proven true once, by hand, at one sha. Nothing keeps them true."
audit_acknowledged:
  milestone: v1.48
  at: 2026-09-17
---

## What

Phase 239 removed 158 planning-bookkeeping lines from `priv/templates/` so that a freshly
generated app and the published Hex tarball grep clean for `.planning/` paths and the
bookkeeping union tokens (`D-NN`, `SC-N`, `IN-NN`, `ORG-UX-NN`, `GATE-NN`, `Phase N`, …).

That is a **one-shot proof at one sha**. `grep -rn 'planning\|bookkeeping\|union'
scripts/ci/install-smoke.sh` returns nothing, and no test asserts anything about the
`mix hex.build` tarball's contents. The next template edit that cites a decision id in a
comment silently reintroduces the leak, and nothing reports it.

## Why it matters

This is the exact defect class phase 239 existed to remove, and it is the one class where the
blast radius is every adopter's repository: `organizations.ex:59` shipped a dead `.planning/`
path into every generated project for multiple releases before anyone noticed. A leak here is
invisible in the source tree — it only shows up on the generated tree or in the tarball, which
is precisely why no existing gate catches it.

Recurring value is high and the cost is low: the assertion is a grep over a tree CI already
builds.

## Shape of the fix

Two assertions, both on the **distribution boundary** — never the source tree:

1. **Generated app** — in `scripts/ci/install-smoke.sh`, after `mix sigra.install` completes and
   before the `ecto.migrate` leg, grep the scaffolded app's `lib/` and `priv/` for `.planning/`
   and the union regex. Non-zero hits fail the job.
2. **Tarball** — a small job that runs `mix hex.build`, unpacks to a scratch dir, and greps the
   unpacked `lib/` and `priv/`. `docs/`, `README.md` and `CHANGELOG.md` are out of scope by
   design and must be excluded explicitly rather than silently.

Both need a **positive control** (assert the greppable-file count is > 0) so an empty tree
cannot pass as clean — the `p03-no-green-on-empty-grep` prohibition applies directly.

Reuse the frozen union regex from `239-01-PLAN.md` rather than re-deriving it.

## Why not fixed in phase 239

Phase 239 SC-5 asserts `git diff origin/main -- .github/` is empty — a renamed required context
never reports and PRs hang forever. Adding a CI gate inside the phase would invalidate the
phase's own success criterion. This lands next.

## Adjacent gap found while verifying (same script)

`scripts/ci/install-smoke.sh` is **not locally runnable as written**. It operates in
`TMP_APP_DIR`'s parent directory, where asdf finds no `.tool-versions` in scope, so `mix`
resolves to no version and the script dies before scaffolding:

```
No version is set for command mix
Consider adding one of the following versions in your config file at <TMP_APP_DIR parent>
```

CI never hits this — the runner has one global toolchain. But it means the script that would
carry the SC-1 assertion cannot be exercised locally before pushing, which is exactly the
feedback loop a new gate needs. Cheapest fix: write a `.tool-versions` (copied from the repo
root) into the scaffold's parent directory as part of the script's own setup. Do this in the
same change as the guard, not separately.
