---
quick_id: 260718-svg
title: "Wire current-session detection for the sessions self-revoke guard"
status: complete
completed: 2026-07-19
commit: 8acf00a4
files_modified:
  - test/example/lib/example_web/live/auth/session_live.ex
  - priv/templates/sigra.install/core/session_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/auth/session_live.ex
---

# Summary

Replaced the unused client connect-param path with a server-side hash of the Plug session token in the example, installer template, and golden fixture. The `This device` and current-session revoke guards now compare stored hashed tokens deterministically. The synchronized change shipped in `8acf00a4`.

