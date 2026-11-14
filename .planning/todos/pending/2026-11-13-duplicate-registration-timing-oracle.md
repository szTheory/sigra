---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Duplicate-email registration returns faster than a new email (timing oracle)
area: security
severity: major
source: v1.50 branch triage (product-code review of the enumeration-safe register fix)
files:
  - lib/sigra/auth.ex
  - priv/templates/sigra.install
---

The enumeration-safe `register/3` fix removes the text oracle, but in the generated user changeset the uniqueness check runs before password hashing and hashing only happens when the changeset is valid. A duplicate email returns in milliseconds; a new email pays Argon2 plus an insert (~200-500 ms).

Options: always hash (dummy hash) before returning, or drop `unsafe_validate_unique` from the generated changeset and rely on the DB constraint path. Also note: a successful registration auto-logs-in while a duplicate shows only the flash; inherent to the design, document it. Add a regression test asserting comparable work on both paths.
