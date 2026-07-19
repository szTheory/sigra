---
quick_id: 260718-dst
title: "Remove the low-value home 'Cohort / Local host' vt-domain-strip"
status: ready
---

# Remove the home `vt-domain-strip` (Cohort / Local host). Example-only, trivial.

Jon: the `vt-domain-strip` "Cohort @demo.tasklane.test / Local host http://sigra.localhost" strip
below the home header doesn't do anything useful — remove it. Example-only (demo home page); no
installer/golden (verified — not present in priv/templates or test/fixtures). No test asserts it
(`home-domain-context` / "Cohort" / "Local host" / `vt-domain-strip` have zero test hits; the
`@demo.tasklane.test` / `noreply@` asserts live in OTHER surfaces/templates, not this strip).

## Task 1 — delete the strip markup
`test/example/lib/example_web/controllers/page_html/home.html.heex`: remove the whole block
(currently L21-26), the `<div class="vt-domain-strip" data-testid="home-domain-context">…</div>`
sitting between the brand `</a>` (L19) and `</header>` (L27). Leave the header + everything else
intact. Do NOT remove the `@demo_domain` / `@local_origin` controller assigns — they're still used
elsewhere on the page (L45, L49, L278) and in `page_controller.ex` (keep `demo_domain:` +
`local_origin:`).

## Task 2 — delete the now-dead CSS
`test/example/priv/static/assets/css/app.css`: remove the `.vt-domain-strip { … }` rule (~L312-321)
and the `.vt-domain-strip__label { … }` rule (~L323-328), plus the surrounding blank line so no
double gap remains before `.vt-kicker`. Grep confirms `vt-domain-strip` is used nowhere else.

## Verification (browser-free + live)
- `cd test/example && mix compile --warnings-as-errors` clean.
- `git diff --stat`: only the two test/example/ files. No priv/templates, no test/fixtures, no *.png.
- `cd test/example && mix test test/example_web/controllers/page_controller_test.exs --include example_app` green (nothing asserted the strip). If DB down: note SKIPPED.
- Live: `http://sigra.localhost/` — the Cohort/Local host strip is gone; header + hero spacing still clean, no orphaned gap; the `@demo.tasklane.test` / origin references further down the page (get-started + footer) remain.
