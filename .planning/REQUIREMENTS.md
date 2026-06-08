# v1.37 AUTH-BRANDING-WHITELABEL Requirements

## Goal

Make Sigra's generated authentication surfaces look production-ready out of the box while giving adopters a low-friction white-label path, a code/config path, and a full-control escape hatch for custom teams.

## Requirements

- [x] **AUTH-UI-01:** Generated auth pages use a branded shell by default across LiveView and controller-rendered auth flows.
- [x] **AUTH-UI-02:** Auth surfaces support Light, Dark, and System themes out of the box without requiring host app design work.
- [x] **AUTH-UI-03:** The generated auth CSS is scoped so Sigra improves defaults without taking over the host application's design system.
- [x] **AUTH-UI-04:** Advanced adopters retain a full-control escape hatch by editing/replacing generated components and static CSS.
- [x] **BRAND-01:** Sigra exposes a validated branding profile with product, logo, color, legal/support, email sender, and theme tokens.
- [x] **BRAND-02:** Branding can be supplied from code/config and overridden by an admin-saved global profile.
- [x] **BRAND-03:** Branding persistence uses a generated `sigra_brand_profiles` table that respects the configured auth schema prefix and falls back safely when unavailable.
- [x] **BRAND-04:** Runtime branding profile serialization is JSON-safe for Ecto/Postgres persistence.
- [x] **EMAIL-01:** Generated transactional emails use the branding profile for sender identity, reply-to, layout, CTA, logo/product name, and footer links.
- [x] **ADMIN-01:** The generated admin UI includes a global `/admin/auth-branding` customizer with auth-form and email previews.
- [x] **ADMIN-02:** Admin customizer UI preserves the `sg-*` cascade/BEM design system, Rail Accent admin shell, Light/Dark/System support, and deterministic hooks.
- [x] **GEN-01:** The installer emits the brand profile migration, auth component, auth CSS, config defaults, and wrapped auth templates.
- [x] **GEN-02:** Generated-host golden fixture, example app, OAuth settings, organizations invitation, and admin route/nav stay in parity with installer templates.
- [x] **DOC-01:** README, installation guide, ExDoc, and a dedicated recipe document the default, white-label, code-config, admin-config, and full-custom paths.
- [x] **TEST-01:** Unit, template, golden, example LiveView, docs, diff hygiene, and generated-host browser coverage prove the new branding surface.
- [x] **TEST-02:** Generated-host smoke failures discovered during verification are fixed at the source and covered by the final smoke lane.

## Non-Goals

- Do not add a hosted identity/control-plane product.
- Do not introduce a new frontend framework or third-party component library.
- Do not make runtime arbitrary HTML/CSS injection part of the default branding contract.
- Do not redesign the whole generated auth flow beyond the branded shell and scoped default styling.
- Do not broaden this milestone into SCIM, authorization policy, compliance automation, or non-auth admin redesign.
- Do not expand Sigra into hosted identity/control-plane behavior.
