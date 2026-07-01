---
surface: audit-index-live
ledger_cell: audit-index-live
rubric_version: "1.0"
disposition: actionable
verdicts:
  platform_admin:
    earning_its_place: keep
    ia_muddy: tighten
    redundant_coherent_surprising: tighten
  support_investigator:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
  org_admin:
    earning_its_place: keep
    ia_muddy: keep
    redundant_coherent_surprising: keep
findings:
  - element: "<.scope_ribbon> rendered after <header> but BEFORE <form> (audit_index_live.ex:56)"
    lens: platform_admin
    question: ia_muddy
    refutation: "On audit-index-live, the scope_ribbon renders at line 56 — between the </header> and the filter <form>. On users-index-live.ex:83, the scope_ribbon also renders between header and the filter form. This is consistent. However, the RESEARCH context (CONTEXT.md:D-04) flags audit_index_live.ex:56 as 'the lone outlier vs siblings that render it above.' Upon reading the source: the header closes at :55 with </header>, then scope_ribbon at :56. On user_show_live.ex:44 the scope_ribbon renders BEFORE the header element. audit_index_live's scope_ribbon-after-header ordering diverges from user_show_live's scope_ribbon-before-header pattern. This cross-page asymmetry in scope_ribbon placement makes the IA mildly muddy: the operator cannot predict where the scope ribbon will appear relative to the H1."
    disposition_action: tighten
  - element: "<.applied_chip> cluster rendered OUTSIDE the <form> (audit_index_live.ex:142-149)"
    lens: platform_admin
    question: redundant_coherent_surprising
    refutation: "Applied chips on audit-index-live render in a <div> OUTSIDE the filter <form> (audit_index_live.ex:142-149), after the closing </form> tag at :140. On users-index-live.ex:107-114, applied chips render INSIDE the GET form. This cross-page asymmetry in chip placement is a design-contract violation (same job → same component position) that would surprise a platform admin who has used both audit and user-search pages."
    disposition_action: tighten
---

# audit-index-live: Persona-JTBD Panel Review

**Surface:** Global Audit Explorer (`/admin/audit`)
**Ledger cell:** `audit-index-live`
**Rubric version:** 1.0
**Reviewed against:** `lib/sigra/admin/live/audit_index_live.ex` (current HEAD)

## Disposition mapping

Raw rollup rule: any `kill` verdict → `blocked`; any `tighten` (no kill) → `actionable`; all `keep` → `clean`.

Resolved per-surface disposition for SC-1: any non-`keep` verdict that CAN be remediated in-place this phase → `actionable`; all-`keep` → `clean`; `blocked` reserved ONLY for a verdict genuinely un-fixable this phase.

This surface: `actionable` — two `tighten` verdicts: scope_ribbon placement asymmetry (remediable by aligning position to before-header like user_show pattern, or by documenting that after-header is the list-page canonical) and chips-outside-form asymmetry (remediable by moving chips inside the form).

---

## Platform Admin Lens

Entry: `/admin` | Posture: triage | Persona: `admin@demo.tasklane.test`

### Earning its place?

NONE — searched for: elements on the audit explorer that do not earn their place for a platform admin conducting security triage. The quick-filter chips (Failures, Impersonation) at audit_index_live.ex:59-78 earn their place as the highest-value triage pivots — they target the two most-common admin audit workflows. The "More filters" disclosure (`<details>` at :82) correctly gates the verbose filters behind a summary disclosure. The sort link ("Occurred" column) earns its place. The Export CSV link earns its place. No element fails earning-its-place for the platform-admin lens.

### Is the IA muddy?

**Finding — `<.scope_ribbon>` renders after `</header>` instead of before `<header>` (`audit_index_live.ex:56`):**

Verdict: `tighten`

The scope_ribbon on audit-index-live renders at line 56, immediately after the closing `</header>` tag (header ends at the implicit position before :56). On `user_show_live.ex:44`, the scope_ribbon renders BEFORE the `<header class="sg-page-header">` element (line 46). On `user_sessions_live.ex:104`, scope_ribbon also renders before the header. The audit page is the outlier: header first, then scope_ribbon, placing the scope context below the H1 rather than above it. An operator who uses both detail pages and the audit page will encounter an inconsistent scope-ribbon position. Remediation: move `<.scope_ribbon>` to before the `<header>` element (same as user_show_live and user_sessions_live pattern), OR establish that list-pages canonical is after-header and document this as an intentional archetype split (waiver-track).

### Redundant / coherent / least-surprising?

**Finding — `<.applied_chip>` cluster outside the `<form>` (`audit_index_live.ex:142-149`):**

Verdict: `tighten`

Applied filter chips on the audit explorer render in a standalone `<div class="sg-cluster sg-cluster--start">` at lines 142-149, OUTSIDE the filter `<form>` (form closes at :140). On users-index-live.ex:107-114, the applied chips render INSIDE the GET form, which means their remove_href links participate in the form's GET contract. The two pages diverge in where chips live relative to the form boundary. This asymmetry would surprise an operator who has used both pages and expects the chip cluster to be in the same form-relative position. The chip remove_href links still work regardless (they are standalone anchor tags), but the structural placement is inconsistent with the design contract ("same job → same component").

---

## Support Investigator Lens

Entry: `/admin/users/:id` | Posture: investigate | Persona: `admin@demo.tasklane.test` acting on a target

### Earning its place?

NONE — searched for: elements on the global audit page that are not useful to a support investigator who arrives here to filter events by actor/effective-user/action. The "Actor" and "Effective user" filter fields inside `<details>` (audit_index_live.ex:86-93) directly serve the support-investigator posture. The Impersonation quick-filter chip earns its place for the investigator reviewing impersonation actions. No element fails the earning-its-place test for this lens.

### Is the IA muddy?

NONE — searched for: next-action ambiguity for an investigator trying to filter by actor or effective user; primary filter fields buried too deep. The quick-filter chips (Failures, Impersonation) are immediately visible without expanding `<details>`; the more-granular fields are one disclosure step away. This is correct hierarchy for the investigator who often starts with quick-filters. No IA muddiness found.

### Redundant / coherent / least-surprising?

NONE — searched for: same event appearing twice in the results; vocabulary drift between "Effective user" here and how user identity is labelled on `user_show_live.ex`. The "Actor" / "Effective user" vocabulary is consistent between the filter labels (audit_index_live.ex:86, :91) and the column heading conventions (same `audit_table_row` component). No redundancy or coherence failure found.

---

## Org Admin Lens

Entry: `/admin/organizations/:slug` | Posture: bound | Persona: `morgan@demo.tasklane.test` (org_admin: :acme, non-platform)

### Earning its place?

NONE — searched for: elements on the org-scoped `/admin/organizations/:slug/audit` variant that are extraneous for an org-admin who can only see their own org's events. The scope_ribbon copy "Organization-scoped audit explorer for {name}" (audit_index_live.ex:221-222) anchors the org context correctly. The filter fields and results all operate on org-scoped data. No element earns-its-place failure for the org-admin lens.

### Is the IA muddy?

NONE — searched for: scope confusion for an org-admin who expects to see only their organization's events; breadcrumb or scope-ribbon mismatch. The scope_ribbon clearly names the org context. The `<details>` disclosure correctly hides verbose filters. No IA muddiness found for org-admin lens.

### Redundant / coherent / least-surprising?

NONE — searched for: vocabulary or layout divergence between the global audit page and the org-scoped audit page that would surprise the org-admin. The two variants share identical markup with only the scope_copy and paths differing — consistent by construction. No redundancy or coherence failure found.
