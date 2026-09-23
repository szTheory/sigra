---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 02
status: complete
---

# Plan 241-02 summary

Replaced the brittle library workflow snapshot assertions with runtime-substitutable, derived
checks for the single full-suite owner, `ci-gate` coverage of terminal library jobs, and unique docs
ownership. Added a two-owner known-bad workflow fixture and proved the RED is attributable to the
replacement assertion. Removed the stale remediation receipt tests and their private helpers while
preserving the mix alias contract and the receipt JSON's other readers.

Verification: fixture RED names both owners; real workflow passes (4 tests); missing and empty
subjects fail closed; `mix compile --warnings-as-errors` passes; the three focused contract tests
pass (28 tests).
