---
quick_id: 260718-qxg
title: "Home polish: View-all spacing, Audit-events microcopy, Sigra/Org-admin seed picker buttons"
status: ready
---

# Home polish (3 example-only files)

Three refinements to `test/example/` — operator aside + seeded-evidence section on the home page.
All example-only; NO `priv/templates/`, NO `test/fixtures/`. Everything routes through the real
prefilled login (`/users/log_in?demo=<key>`).

## Task 1 — CSS spacing (`test/example/priv/static/assets/css/app.css`, build-free)
- Add breathing room around the aside's "View all 10 personas" button (direct child of the aside):
  ```css
  .vt-panel--operator > .vt-btn {
    margin-block: var(--sg-space-4);
  }
  ```
- Add spacing between a seed-list action item's text block and its button (only affects `<li>`s
  that contain a button):
  ```css
  .vt-seed-list li .vt-btn {
    margin-top: var(--sg-space-2);
  }
  ```
- Place both near the existing `.vt-panel--operator` / `.vt-seed-list` rules. Do not touch other rules.

## Task 2 — home.html.heex: microcopy + seed picker buttons (`test/example/lib/example_web/controllers/page_html/home.html.heex`)
Seeded-evidence section (`<section ... aria-label="Seeded evidence">`, ~lines 248–289).

(a) Metric relabel (~line 259): `<dt>Audit rows</dt>` → `<dt>Audit events</dt>`. Leave
`<dd>{@audit_row_count}</dd>` (renders "15+") unchanged. Do NOT touch the other two metrics
(`Demo personas` / `Organizations`) or their testids.

(b) In `<ul class="vt-seed-list">`, KEEP the first two prose `<li>`s (Acme/Beta orgs; cohort domain)
verbatim. REPLACE the "Sigra Admin" `<li>` and the "Org admin path" `<li>` with these picker-shaped
items (reuse the operator-aside pattern at lines 91–104):
```heex
<li>
  <div>
    <strong>Sigra Admin</strong>
    <p class="vt-copy">Support operations: user search, session review, impersonation, audit filters, exports, and scoped org views — opens <code class="vt-code">/admin</code>.</p>
  </div>
  <a href={~p"/users/log_in?#{%{demo: "admin"}}"} class="vt-btn vt-btn--primary vt-btn--block">Sign in as Admin</a>
</li>
<li>
  <div>
    <strong>Org admin</strong>
    <p class="vt-copy">Org-scoped console → <code class="vt-code">/admin/organizations/acme-corp</code>.</p>
  </div>
  <a href={~p"/users/log_in?#{%{demo: "morgan"}}"} class="vt-btn vt-btn--primary vt-btn--block">Sign in as Morgan</a>
</li>
```
Notes: routes are non-copyable `.vt-code` (no `--copy`). `/admin/organizations/acme-corp` MUST remain
(test-asserted). The raw `morgan@demo.tasklane.test` prose is removed (replaced by the button).

## Task 3 — test update (`test/example/test/example_web/controllers/page_controller_test.exs`)
- DROP the `assert html =~ "morgan@demo.tasklane.test"` line (email intentionally removed from home;
  Morgan reachable via the `demo=morgan` button — not a coverage loss).
- KEEP all other assertions: `Demo personas`, `>10<`, `Acme Corp`, `Beta Labs`,
  `/admin/organizations/acme-corp`, `id="get-started"`, `Sign in as`. Optionally add `assert html =~ "demo=admin"`.

## Verification
- `cd test/example && mix compile --warnings-as-errors` clean.
- `cd test/example && mix test test/example_web/controllers/page_controller_test.exs --include example_app` green.
- `git diff --stat` = only the 3 example files (home.html.heex, app.css, page_controller_test.exs).
- Commit atomically (one commit is fine for this small set; or split CSS vs template — executor's call). Code only.
