---
quick_id: 260718-dst
title: "Remove the low-value home Cohort / Local host strip"
status: complete
completed: 2026-07-19
commit: 8acf00a4
files_modified:
  - test/example/lib/example_web/controllers/page_html/home.html.heex
  - test/example/priv/static/assets/css/app.css
---

# Summary

Removed the `home-domain-context` markup and its dead `vt-domain-strip` CSS while preserving the remaining demo-domain and local-origin uses. The change shipped in `8acf00a4` as part of the v1.45 demo-DX closeout.

