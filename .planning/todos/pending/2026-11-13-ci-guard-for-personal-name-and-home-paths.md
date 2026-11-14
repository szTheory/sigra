---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Add a CI guard against personal names and home-directory paths in tracked files
area: ci
severity: major
source: v1.50 branch triage; extends the 2026-09-17 home-directory-paths todo
files:
  - .github/workflows/ci.yml
---

The repo is public. Planning receipts leaked home-directory paths and a personal name into thousands of tracked files; a text sanitisation pass landed on 2026-11-13 for markdown/tsv, but hash-bound JSON receipts and a few binary screenshots still contain them.

Add a shrink-only baseline guard (fail on any NEW occurrence of `/Users/<name>/` or the maintainer's name in tracked text files; known JSON/PNG exceptions listed in a baseline file that may only shrink). Include a planted-failure test so the guard is shown red once. Also forbid committing one-use evidence ledgers over a size limit.
