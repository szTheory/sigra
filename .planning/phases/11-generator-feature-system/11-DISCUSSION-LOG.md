# Phase 11: Generator Feature System - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 11-generator-feature-system
**Areas discussed:** Behaviour callback surface, Refactor depth for Features.Core, Post-install summary (GEN-05), Migration timestamp strategy (GEN-07)

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Behaviour callback surface | Just enabled?/1 + files/1 + injections/1, or also migrations/1 and post_instructions/1 | ✓ |
| Refactor depth for Features.Core | Minimal shim vs full decomposition | ✓ |
| Post-install summary (GEN-05) | Table vs grouped list; record-as-you-go vs post-scan | ✓ |
| Migration timestamp strategy (GEN-07) | offset_timestamp vs slot allocator | ✓ |

**User's choice:** All four areas.

---

## Behaviour Callback Surface

### Q1: What callbacks should Sigra.Install.Feature require?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: enabled?/1, files/1, injections/1 (Recommended) | Research default. Migrations in files/1, post-install printing in sigra.install.ex. Smallest diff. | |
| + migrations/1 | Separate migrations/1 returning [{template, slot_key}] so central allocator handles timestamps. | |
| + migrations/1 + post_instructions/1 | Also hoist printable instructions into the behaviour. Biggest contract, most additive. | ✓ |

**User's choice:** + migrations/1 + post_instructions/1
**Notes:** Chose the most-additive shape so Phase 12+ features contribute instructions and migrations without touching sigra.install.ex.

### Q2: Should injections/1 return structured data or raw strings?

| Option | Description | Selected |
|--------|-------------|----------|
| Structured: list of %Injection{target, marker, content} (Recommended) | Central walker handles idempotency via Sigra.Install.Injector. | ✓ |
| Raw: return IO-op callbacks the feature runs itself | More flexible, duplicates marker/already-injected pattern. | |

**User's choice:** Structured %Injection{} records.

---

## Refactor Depth for Features.Core

### Q1: How much of sigra.install.ex moves into Features.Core in Phase 11?

| Option | Description | Selected |
|--------|-------------|----------|
| Full decomposition (Recommended) | All 44 files + injections + 3 migrations + instructions into Features.Core. sigra.install.ex becomes a generic walker. | ✓ |
| Middle ground | Files + injections move, migrations and instructions stay in task for Phase 11. | |
| Minimal shim | Behaviour + subdir move only; generate/4 still owns file list. | |

**User's choice:** Full decomposition.
**Notes:** Phase 12+ is purely additive with zero generator-task edits.

### Q2: How do we guarantee byte-identical output during the refactor?

| Option | Description | Selected |
|--------|-------------|----------|
| Golden-output diff test in CI (Recommended) | Snapshot generated tree pre- and post-refactor, assert zero diff, keep in CI. | ✓ |
| Manual diff during phase execution only | Local comparison before commit, no CI persistence. | |
| Both: CI golden test + commit-time manual review | Belt and suspenders. | |

**User's choice:** CI golden test.

---

## Post-Install Summary (GEN-05)

### Q1: How should the post-install summary be structured?

| Option | Description | Selected |
|--------|-------------|----------|
| ASCII table: 4 columns (Recommended) | generated / modified / skipped / manual-action in wrapped ASCII table. | ✓ |
| Grouped sections | Four colored headers with bullet lists. | |
| Compact: counts + verbose flag | Counts by default, full list behind --verbose. | |

**User's choice:** 4-column ASCII table.

### Q2: How is the summary data collected?

| Option | Description | Selected |
|--------|-------------|----------|
| Record-as-you-go via a Report accumulator (Recommended) | Sigra.Install.Report struct collects every write/inject/skip as features run. | ✓ |
| Post-scan filesystem delta | Snapshot before/after, diff at end. Loses manual-action intent. | |

**User's choice:** Sigra.Install.Report accumulator.

---

## Migration Timestamp Strategy (GEN-07)

### Q1: How should migration timestamps be assigned across features?

| Option | Description | Selected |
|--------|-------------|----------|
| Slot-based allocator (Recommended) | MigrationTimestamps.allocate/2 returns strictly-increasing timestamps per feature/slot. Deterministic. | ✓ |
| Keep offset_timestamp(n), generalize later | Phase 11 Core keeps current offsets; allocator in Phase 12. | |
| Gregorian-second per-feature offset | Each feature declares base offset (Core=0, Orgs=100, …). Fragile under reordering. | |

**User's choice:** Slot-based allocator.

---

## Wrap-up

### Q: Ready to write CONTEXT.md?

| Option | Description | Selected |
|--------|-------------|----------|
| Write context | Create 11-CONTEXT.md with the four locked decisions plus template-override as Claude's Discretion. | ✓ |
| One more area | Open another gray area first. | |

**User's choice:** Write context.

---

## Claude's Discretion

- **Template override path semantics (CD-01):** Subdir-layout only, no flat-legacy fallback. Chosen as Claude's discretion because it's a rarely-used escape hatch and a stable rule matters more than back-compat for a pre-1.0 library.
- **Sigra.Install.Report struct shape (CD-02):** Internal concern, planner picks field names.
- **%Sigra.Install.Injection{} field names (CD-03):** Draft suggestive; planner may rename as long as Injector contract is preserved.
- **Features.Core submodule granularity (CD-04):** Style call — single large module or split into Files/Injections/Migrations/Instructions submodules.
- **Walker implementation location (CD-05):** Mix.Tasks.Sigra.Install or Sigra.Install.Runner helper — style call.

## Deferred Ideas

- `mix sigra.install.check` dry-run task — Phase 23 candidate
- Combinatorial CI smoke matrix (GEN-03) — Phases 18 + 22
- Telemetry events for install operations — no current consumer
- `mix sigra.install.rollback` — v1.2+ polish
- Per-feature override paths with flat-legacy fallback — explicitly rejected in CD-01
