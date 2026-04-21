# GA-02 — Waiver template

Use only when human triple-client verification is **not** executed but a **formal Waived** row is required. Pair with CI HTML diff evidence for the same change.

| Field | Value |
|--------|--------|
| **reason** | Triple-client human MUA (Gmail / Outlook / Apple Mail) was not executed in the Phase 46 automation window; no new HTML/CSS/multipart changes were shipped beyond the existing CI snapshot spine on this SHA. |
| **compensating controls** | `EmailsSecurityHtmlTest`, `EmailsLifecycleHtmlTest`, and `example_unit_smoke` per `docs/uat-ci-coverage.md` (SEED-1 / SEED-2); `cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/accounts/emails_security_html_test.exs test/example/accounts/emails_lifecycle_html_test.exs` exit 0 at SHA `3e9e58ff2ff6cbb3a2fa88a06a114fdd78bd8341`. |
| **residual risk** | Real MUAs may still differ on spam placement, dark mode, and client-specific clipping — not observed here. |
| **expiry_or_next_trigger** | Next release boundary with material email HTML/CSS/multipart changes, or before tag if human MUA is required by policy. |
| **owner** | Sigra |
| **date** | 2026-04-21 |

**Rules:** Do not claim “triple-client verified” from screenshots alone (**D-42-02**).
