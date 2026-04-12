# Phase 13: Organizations Schemas + Context - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 13-organizations-schemas-context
**Areas discussed:** Organization schema shape, Slug rules & reserved list, for_org/2 enforcement, Credo check vs test-only, Membership schema shape, Invitation schema shape, Last-owner guard design, Context API surface (incl. philosophy shift), Hook/callback API design, use macro design, prepare_query integration, Soft-delete implementation, Migration strategy, Testing strategy, Scope typespec tightening, Audit integration prep, Error handling patterns, NimbleOptions config shape, Gap analysis, Philosophy downstream implications, Accrue interop specifics

---

## Organization Schema Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal | name, slug, deleted_at, timestamps only | ✓ |
| Starter kit | + description + settings JSONB | |
| Full profile | + description, logo_url, settings, billing_email | |

**User's choice:** Minimal
**Notes:** Auth lib owns identity; devs own profile. Phase 16 can ALTER.

---

## Slug Rules & Reserved List

| Option | Description | Selected |
|--------|-------------|----------|
| Accept all (with citext) | Lowercase alphanumeric+hyphen, 3-63 chars, ~25 reserved words, partial unique index, citext | ✓ |
| No citext for slugs | Lowercase changeset validation only | |
| No slug reclamation | Global unique (slugs consumed forever) | |

**User's choice:** Accept all, with citext modification (citext for slugs since extension already required)
**Notes:** Belt-and-suspenders: citext at DB + lowercase validation at app layer.

---

## for_org/2 Enforcement

| Option | Description | Selected |
|--------|-------------|----------|
| Runtime raise (pure function) | Mirrors Ecto.assoc/2 pattern. Accepts Scope or raw org_id. | ✓ |
| Compile-time macro | Catches misuse before code runs. Breaks composability. | |
| Behaviour/Protocol opt-in | Schemas explicitly declare org-scoped. Adds boilerplate. | |

**User's choice:** Runtime raise
**Notes:** Idiomatic Ecto. Composable with existing query patterns.

---

## Credo Check vs Test-Only Enforcement

| Option | Description | Selected |
|--------|-------------|----------|
| prepare_query/3 enforcer | ~150 LOC in generated Repo. Catches every unscoped query at runtime. | ✓ |
| Hybrid: prepare_query + Credo | Two mechanisms. More surface area. | |
| Test-only + CONVENTIONS.md | No runtime enforcement. Weakest guarantee. | |
| Credo check only | High false positive/negative rate. | |

**User's choice:** prepare_query/3 enforcer
**Notes:** Research showed Credo can't reliably analyze Ecto queries (AST vs runtime). EctoTenancyEnforcer validates the prepare_query pattern in production.

---

## Membership Schema Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal | org_id, user_id, role (Ecto.Enum), timestamps | ✓ |
| With invited_by | + invited_by_id FK | |
| Full invitation-aware | + invited_by_id + accepted_at | |

**User's choice:** Minimal
**Notes:** Invitation tracking stays on OrganizationInvitation. Phase 17 can ALTER.

---

## Invitation Schema Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Full schema in Phase 13 | All fields now, zero flow logic. Derive status from timestamps. | ✓ |
| Defer to Phase 17 | Phase 13 ships only Org + Membership. | |
| Skeleton now, extend later | email + role + associations only; Phase 17 ALTERs. | |

**User's choice:** Full schema in Phase 13
**Notes:** Roadmap explicitly includes invitation schema. Migration ordering correct from day one. Status derived from nullable timestamps (no enum).

---

## Last-Owner Guard Design

| Option | Description | Selected |
|--------|-------------|----------|
| FOR UPDATE in Multi | Lock owner rows, count, abort if ≤1. Idiomatic Ecto. | ✓ |
| SERIALIZABLE isolation | Database auto-detects conflicts. Requires retry logic. | |
| DB trigger + CHECK | Enforced at DB level. PostgreSQL-only, opaque errors. | |

**User's choice:** FOR UPDATE in Multi
**Notes:** Standard pattern for count-then-act in concurrent Ecto transactions. Portable to MySQL.

---

## Context API Surface (Philosophy Shift)

| Option | Description | Selected |
|--------|-------------|----------|
| Library + thin wrapper | Library owns CRUD + safety. Generated ~50-80 lines: config + hooks. | ✓ |
| Fat generated context | ~300-400 lines generated CRUD. Matches v1.0 Auth pattern. | |
| Pure library, no wrapper | Call Sigra.Organizations.* directly. Zero generated context. | |

**User's choice:** Library + thin wrapper
**Notes:** Major philosophy shift. Sigra should MANAGE organizations, not generate code that manages them. Security patches via deps.update. Pow lesson: unclear boundaries killed it.

---

## Hook/Callback API Design

| Option | Description | Selected |
|--------|-------------|----------|
| Two-layer (defoverridable + runtime registry) | Module callbacks for local customization. Runtime registry for external lib integration. | ✓ |
| Module callbacks only | External libs must tell devs to add hook calls. | |
| Runtime registry only | All hooks registered dynamically. Less discoverable. | |

**User's choice:** Two-layer system
**Notes:** Designed with Accrue (payments) interop as concrete validation. Transactional (Ecto.Multi). Priority-ordered.

---

## use Macro Design

| Option | Description | Selected |
|--------|-------------|----------|
| ~40 LOC macro | Config as module attr. Thin delegators. defoverridable hooks. NimbleOptions. | ✓ |
| Config-only macro | Only stores config. Delegators explicitly generated. | |
| No macro | Direct library calls with config. | |

**User's choice:** ~40 LOC macro
**Notes:** New library functions added via deps.update automatically available. No field injection (avoids Pow's mistake).

---

## prepare_query Integration

| Option | Description | Selected |
|--------|-------------|----------|
| One-line delegation in Repo | Library owns enforcement logic. Schema list from config. skip_org_check escape. | ✓ |
| use Sigra.Repo macro | Library wraps Ecto.Repo. Less explicit. | |
| Schema self-declaration | @org_scoped true on each schema. | |

**User's choice:** One-line delegation
**Notes:** Generated Repo calls library helper. Schema list derived from use Sigra.Organizations config.

---

## Soft-Delete Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit filtering in context functions | No auto-scope. Hard-delete memberships. Audit nilifies. | ✓ |
| Auto-filter in for_org/2 | Mixes concerns (tenant scoping + lifecycle). | |
| Soft-delete memberships too | More complex unique constraints. | |

**User's choice:** Explicit filtering
**Notes:** for_org/2 stays generic. Soft-delete filter is a context-level concern.

---

## Migration Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| One slot in Features.Organizations | All 3 tables, FK-ordered, one migration file. | ✓ |
| Three separate slots | One per table. Granular rollback. | |
| Keep in Features.Core | Violates Phase 11 isolation. | |

**User's choice:** One slot in Features.Organizations
**Notes:** Atomic rollback. Adapter-branched for citext. Features.Organizations is the second Feature consumer.

---

## Testing Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Unit tests only (~20) | Mox, async: true. Simple fixtures. | |
| Unit + integration (~28) | + DataCase with real DB for locks, indexes, FK cascades. | ✓ |
| + property-based tests | StreamData for slug fuzzing. | |

**User's choice:** Unit + integration
**Notes:** Integration tests needed for FOR UPDATE lock, partial unique indexes, FK cascades, prepare_query enforcement.

---

## Scope Typespec Tightening

| Option | Description | Selected |
|--------|-------------|----------|
| Replace with real types | struct() → %Organization{}, %OrganizationMembership{} | ✓ |
| Keep struct() until Phase 18 | Defer conditionality. Less type-safe. | |
| Claude's discretion | | |

**User's choice:** Replace with real types
**Notes:** Unconditional — Phase 18 handles --no-organizations conditionality. Golden-diff updated.

---

## Audit Integration Prep

| Option | Description | Selected |
|--------|-------------|----------|
| Ship log_safe calls now | All context functions include audit call sites. No-op safe. | ✓ |
| Defer to Phase 15 | Cleaner separation. Bigger Phase 15 diff. | |

**User's choice:** Ship now
**Notes:** Matches v1.0 precedent. Phase 15 upgrades, doesn't create call sites.

---

## Error Handling Patterns

| Option | Description | Selected |
|--------|-------------|----------|
| Mixed returns (standard) | {:error, changeset} for validation, {:error, :atom} for business logic, raise for not-found. | ✓ |
| All via changeset | Uniform but less ergonomic for pattern matching. | |
| Error structs (Ash-style) | More structured but heavier. | |

**User's choice:** Mixed returns
**Notes:** Library normalizes Multi internals before returning. Clean pattern matching in controllers.

---

## NimbleOptions Config Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Full config (recommended) | Required: repo + schemas. Configurable: roles, reserved slugs (additive), slug format/length, enforce_org_scope. | ✓ |
| Simpler — fewer options | Just repo + schemas + reserved_slugs. | |

**User's choice:** Full config
**Notes:** Sensible defaults for 90% of users. Escape hatches for power users. Docs auto-generated.

---

## Claude's Discretion

- Internal Sigra.Hooks registry implementation (persistent_term vs ETS)
- for_org/2 extract_schema/1 implementation
- Features.Organizations stub shape
- Test file organization and module naming
- Audit event action name convention

## Deferred Ideas

- Revisit v1.0 Auth context API surface (future milestone)
- Accrue payments integration guide (depends on both libs reaching usable state)
- Phase 17 may ALTER memberships to add invited_by_id
- Phase 18 handles Scope template conditionality for --no-organizations
- v1.2: hard-delete path, Session.put_active_organization_id/2
