---
created: 2026-06-18T00:00:00.000Z
status: done
resolved: 2026-06-18
resolved_by: quick task 260618 (gsd-fast)
title: golden_diff_test.exs known failure — generated-tree byte diff vs committed fixture
area: test
files:
  - test/sigra/install/golden_diff_test.exs
source: phase 192 quarantine (D-11/D-12)
---

## What

`test/sigra/install/golden_diff_test.exs` failed with a generated-tree byte diff
vs the committed fixture in `test/fixtures/install_golden/`.

## Actual root cause (corrected 2026-06-18)

NOT a stale fixture. It was a **local-environment phx_new version mismatch**. The
dev machine had `phx_new 1.8.8` installed; CI and SEED-004 pin `phx_new 1.8.7`.
phx_new 1.8.8 emits an extra `config :phoenix_live_view, root_tag_attribute: "phx-r"`
block (for `Phoenix.LiveView.ColocatedCSS`) in the generated `config/config.exs`,
which the fixture — correctly captured under 1.8.7 — does not contain. So the test
failed locally (1.8.8) while CI (1.8.7) was green.

The earlier "fix direction" (regenerate the fixture) was a misdiagnosis: regenerating
locally under 1.8.8 would have made the test pass locally but **broken CI**.

## Resolution

1. Installed the pinned archive locally: `mix archive.install --force hex phx_new 1.8.7`.
2. Re-ran `mix test test/sigra/install/golden_diff_test.exs` → **2 tests, 0 failures**,
   with NO fixture change.
3. Removed the `@moduletag known_failure` tag from the test.
4. Added a note to CLAUDE.md "Local development prerequisites" documenting the 1.8.7
   requirement so this does not recur.
