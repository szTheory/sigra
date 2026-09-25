---
phase: 242
phase_name: "hex-retire-docs-revert-pinned-install-adr-cut-1-5-1"
project: "Sigra"
generated: "2026-09-22"
counts:
  decisions: 4
  lessons: 5
  patterns: 3
  surprises: 3
missing_artifacts:
  - "242-VERIFICATION.md"
  - "242-UAT.md"
---

# Phase 242 Learnings: Hex retire, docs revert, pinned install, and 1.5.1

## Decisions

### Make a bounded dependency requirement the adopter safety mechanism

The supported install line must be `{:sigra, "~> 1.5.0"}`. This directly excludes the stray
`1.20.0` version from the maintained 1.5 line; retirement is not relied upon to correct resolution.

**Rationale:** A retired Hex release remains resolvable and fetchable, so a requirement constraint is
the dependable user-facing control.
**Source:** 242-CONTEXT.md (D-05/D-06); 242-RESEARCH.md; 242-12-SUMMARY.md

---

### Retirements are registry hygiene, not a release gate

Treat the old `1.20.0` as a separately owned registry-hygiene issue. It must not block docs,
ordinary releases, or the current supported installation path.

**Rationale:** The remediation workflow consumed three separately authorized dispatches without
producing a public receipt, while the supported 1.5 line remains a source-controlled concern.
**Source:** 242-10-SUMMARY.md; 242-12-SUMMARY.md

---

### Remove secret-bearing mutation automation when its premise is not product-critical

The dedicated remediation workflow must be retired rather than kept as a convenient rerun path.

**Rationale:** An externally mutable, secret-bearing workflow has a high operational cost and should
not exist merely to chase advisory registry state.
**Source:** 242-01-SUMMARY.md; 242-12-SUMMARY.md; user decision 2026-09-22

---

### Decouple HexDocs current-root validation from retirement

Current documentation should be established and observed through a normal verified release, not an
attempt to mutate old documentation as a prerequisite for registry hygiene.

**Rationale:** HexDocs-root availability is an external observation that cannot prove whether an
advisory retirement is appropriate or successful.
**Source:** 242-CONTEXT.md (D-04); 242-10-SUMMARY.md; 242-12-SUMMARY.md

---

## Lessons

### Correct command syntax is weaker than end-to-end viability

Replacing the unsupported `--yes` option with `--message` made the command contract green but did
not make the remediation viable.

**Context:** The first run stopped at CLI parsing; later runs progressed to independent dependency
and HexDocs-root failures.
**Source:** 242-03-SUMMARY.md; 242-10-SUMMARY.md; 242-12-SUMMARY.md

---

### Do not infer resolver behavior from retirement state

Retirement is advisory. It warns consumers but does not necessarily alter selection or
`latest_stable_version`.

**Context:** Planning initially inherited a stale expectation that retirement would restore normal
resolution; the phase context corrected that expectation, but execution remained coupled to it.
**Source:** 242-CONTEXT.md (D-06/D-07); 242-RESEARCH.md

---

### A live external precondition needs a graceful terminal state

External documentation availability must be observable and reportable without forcing another
registry write or making unrelated work impossible.

**Context:** Both later dispatches halted on `unavailable_or_ambiguous` HexDocs classification.
**Source:** 242-10-SUMMARY.md; 242-12-SUMMARY.md

---

### Workflow setup is part of the mutation safety proof

Dependency resolution belongs before any mutation-capable command and needs a deterministic ordering
test.

**Context:** Run 35709493996 reached the docs-revert step with unavailable dependencies; Plan 11
added a locked dependency step and a fixture-backed p22 guard.
**Source:** 242-11-SUMMARY.md

---

### Distinct summaries prevent a later attempt from rewriting failure history

Every invocation needs its own immutable outcome record and exact count.

**Context:** Plans 03, 10, and 12 each halted for different reasons; preserving all three made the
decision to stop retrying auditable.
**Source:** 242-03-SUMMARY.md; 242-10-SUMMARY.md; 242-12-SUMMARY.md

---

## Patterns

### Shift-left consumer-safety contract

Test every public install snippet and requirement boundary in the repository, independently of live
registry behavior.

**When to use:** Whenever a package version or registry state could make broad SemVer requirements
unsafe for new adopters.
**Source:** 242-CONTEXT.md (D-05/D-06); 242-RESEARCH.md

---

### Source-only prerequisite PR

Land and CI-verify deterministic workflow safety repairs separately from any external action.

**When to use:** Before a workflow has credentials, registry mutation, or an irreversible downstream
effect.
**Source:** 242-11-SUMMARY.md

---

### Single-invocation control receipt

Persist source SHA, invocation count, watcher count, and structured-summary count before and after an
externally mutable workflow.

**When to use:** For exceptional, explicitly authorized workflows where duplication is harmful.
**Source:** 242-10-SUMMARY.md; 242-12-SUMMARY.md

---

## Surprises

### The repository docs lagged the maintained package line

Public install examples still reference `1.4.0` even though Hex exposes `1.5.0` as a real release.

**Impact:** The intended safe constraint was not yet delivering the user-facing protection that the
phase described.
**Source:** 242-CONTEXT.md (D-05); public Hex package observation 2026-09-22

---

### HexDocs-root state was unavailable or ambiguous after workflow progress

The workflow reached its root-classification step but could not prove `current_1_5`.

**Impact:** A registry-hygiene workflow became blocked by an unrelated external presentation state.
**Source:** 242-12-SUMMARY.md

---

### Repeated guarded dispatches did not establish retirement

After each classified failure, the public package observation still had no `1.20.0` retirement.

**Impact:** Retrying source fixes was not a rational way to achieve adopter safety.
**Source:** 242-10-SUMMARY.md; 242-12-SUMMARY.md
