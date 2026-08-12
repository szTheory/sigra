---
quick_id: 260718-mba
title: "Polish the MFA enrolled-state backup-code alert"
status: complete
completed: 2026-07-19
commit: 8acf00a4
files_modified:
  - test/example/lib/example_web/live/mfa_settings_live.ex
  - test/example/priv/static/assets/css/app.css
---

# Summary

Removed the two unsupported alert icons and added the scoped `vt-stack` rhythm utility to the enrolled MFA panel. The change shipped in `8acf00a4`; current source retains both stack applications and contains no alert-local `hero-exclamation-triangle` icon.

