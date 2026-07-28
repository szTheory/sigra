# Phase 228 Context

The admin design system is mature and remains `sg-*`. This phase repairs a form-state defect rather than reskinning it: quick filters previously duplicated named form controls and could submit ambiguous values.

Failures and Impersonation are shareable URL presets. The manual form owns exactly one control per key. Applied filters appear immediately after the form using the existing chip component, while sort, cursor, export, deep links, and browser history stay GET-driven.
