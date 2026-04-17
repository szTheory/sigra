---
status: complete
phase: 27-admin-access-foundation
source: [27-VERIFICATION.md]
started: 2026-04-16T19:37:17Z
updated: 2026-04-17T23:45:00Z
---

## Current Test

[testing complete]
## Tests

### 1. Render a freshly installed host app's `/admin` and `/admin/organizations/:org` pages
expected: The admin layout wraps both routes, the scope chip is visible at the top, and the page does not look visually broken on desktop or mobile.
result: pass
verified_by: automation
automation_command: scripts/ci/admin-acceptance-smoke.sh --test chrome
evidence: "INSERT INTO \"users\" (\"email\",\"failed_login_attempts\",\"hashed_password\",\"must_change_password\",\"password_changed_at\",\"inserted_at\",\"updated_at\",\"id\") VALUES ($1,$2,$3,$4,$5,$6,$7,$8) [\"org-admin@example.test\", 0, \"$argon2id$v=19$m=65536,t=3,p=4$a8APw/c3d66Jqt+0VfzVMw$tK/Ur8goK9ufxUgSbCFyUSJOZhV1PTfS5d06oIMCNjE\", false, ~U[2026-04-16 20:06:30Z], ~U[2026-04-16 20:06:30Z], ~U[2026-04-16 20:06:30Z], \"1e103786-a707-46b6-97ce-b2d0a384d10e\"] | 1 passed (2.3s) | ==> admin-acceptance: success"

### 2. Trigger forbidden and not-found admin paths in a generated host app
expected: The 403 and 404 responses show the explicit admin error copy instead of a blank or confusing page.
result: pass
verified_by: automation
automation_command: scripts/ci/admin-acceptance-smoke.sh --test errors
evidence: "INSERT INTO \"users\" (\"email\",\"failed_login_attempts\",\"hashed_password\",\"must_change_password\",\"password_changed_at\",\"inserted_at\",\"updated_at\",\"id\") VALUES ($1,$2,$3,$4,$5,$6,$7,$8) [\"org-admin@example.test\", 0, \"$argon2id$v=19$m=65536,t=3,p=4$X1ALidHc0RUGn0WO4o5r2A$K1N/6wnJFR9kUa/idar5l9jsxz5YjZO/f+wHXK0cFeE\", false, ~U[2026-04-16 20:07:08Z], ~U[2026-04-16 20:07:08Z], ~U[2026-04-16 20:07:08Z], \"ed5033fc-b742-4ad0-a24d-d74ff3e255fb\"] | 1 passed (2.4s) | ==> admin-acceptance: success"


## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0
## Gaps
