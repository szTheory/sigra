# Phase 260 review disposition

Source: 260-REVIEW.md (0 critical, 4 warning, 4 info; standard depth; 34 files). Advisory gate: nothing here blocks phase completion.

| ID | Severity | Disposition | Note |
|----|----------|-------------|------|
| WR-01 | warning | open | Focus ring lost on the active theme-switch segment in shipped `sigra_admin.css`. Fixing it changes shipped bytes and needs a second golden rebless, which Phase 260 prohibits. Route to Phase 261 (shipped-CSS work). |
| WR-02 | warning | open | `admin-css-conformance.sh` CHECK 1 and CHECK 3 are bypassable (`transition : all`, multi-line, `padding: 13px` mid-line) and the guard is now wired into `mix ci`. Harden with negative self-test cases; route to a Phase 261 guard task. |
| WR-03 | warning | open | Committed-catalog hash and privacy checks return ok when `MANIFEST.json` is absent. Make absence a failure now that the baseline is committed. Small, test-only; candidate for a quick task. |
| WR-04 | warning | open | `admin-css-conformance.test.sh` self-tests have no CI caller. Add as a `fast_checks` step (CI checkouts are clean, so Test G passes). Candidate for a quick task. |
| IN-01 | info | open | Tier-1 catalog hard-copies private option lists from `UsersIndexLive` and `BrandingLive`. |
| IN-02 | info | open | `double_install_test.exs` raw allow-list is wider than its moduledoc; normalized leg backstops it. |
| IN-03 | info | open | `admin-acceptance-smoke.sh --help` prints script code up to the default Cloak key. |
| IN-04 | info | open | `Catalog.write_after!/2` will `rm_rf` lane directories in any `:out_dir`, including one holding a manifest. |
