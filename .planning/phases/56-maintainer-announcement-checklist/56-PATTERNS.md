# Phase 56 — Pattern map

## Files to modify

| Target | Role | Closest analog | Pattern to copy |
|--------|------|----------------|-----------------|
| `MAINTAINING.md` | Maintainer runbook | Self — existing sections (`## Installer golden…`, `## Release automation…`) | Same heading depth, code fences for commands, GitHub Settings deep links, tag-scoped URLs in Nyquist table |

## Style anchors (excerpts)

- **Tag-scoped evidence** (existing): Nyquist policy table rows already use `https://github.com/sztheory/sigra/blob/v0.2.0/...` for `.planning/` snapshots — new announcement section should **reuse that prefix** for any `.planning/` path.
- **Branch protection copy/paste**: Existing subsection documents exact **`install_golden_contract`** display string — announcement **Ship** rows should **link** here rather than retyping.

## Anti-patterns (from CONTEXT)

- Do not add bare `](.planning/v1.4-GA-UAT.md)` style links (HexDocs).
- Do not duplicate Release Please / manual release numbered steps in the announcement checklist.
