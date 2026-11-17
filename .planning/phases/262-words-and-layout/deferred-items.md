# Deferred items — Phase 262-06

- Dark-theme axe finding on the branding editor: the active “Branding” sidebar link and “Save profile” button both render at 2.83:1 (`#504d4a` on `#e57843`). Their selectors and brand/ink tokens were unchanged by Plan 06. The required Light and Dark design-gallery axe checks pass; the editor finding remains open for a scoped contrast fix.
- The example organization route requires an organization member to authenticate, so it cannot render the no-members state. The example catalog captures its reachable populated state; the library catalog covers the pure-render empty state without inventing a runtime state.
