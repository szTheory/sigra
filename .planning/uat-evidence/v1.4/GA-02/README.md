# GA-02 — Email visual QA (lockout, suspicious-login, lifecycle)

**Scope:** Human verification that **lockout + suspicious-login** templates and **account-lifecycle** mail (Phase 04 / Phase 08 families) render acceptably in real mail clients.

**Machine baseline (always on):** See **`docs/uat-ci-coverage.md`** **SEED-1** and **SEED-2** — `Example.Accounts.EmailsSecurityHtmlTest`, `Example.Accounts.EmailsLifecycleHtmlTest`, plus **`example_unit_smoke`**. Those tests are the regression spine; they **do not** claim parity across all MUAs.

**Human trigger:** Run **Gmail + Outlook + Apple Mail** (or documented substitutes) on **release boundaries** and whenever **email HTML/CSS/layout** or **multipart structure** changes materially — not every copy tweak (**D-42-02**).

**Evidence:** Fill `steps.md` after each run; use `waiver.md` for formal waivers with **compensating** controls and **expiry_or_next_trigger**.
