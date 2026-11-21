# Sigra v1.51: public identity and documentation

> **LOCAL DRAFT — not approved for publication.** Publish only after a separately approved release.

Sigra is an open-source authentication library for Phoenix 1.8 and later. A library holds the security-sensitive core, and generators write screens, routes, and emails into your repository as normal code. Fixes arrive with `mix deps.update`; the rest is yours to edit.

The v1.51 identity and documentation update brings the approved Sigra look and language to the README, HexDocs, and package assets. The README introduces the Tasklane demo, and HexDocs now includes theme-aware logos, icons, typography, and refreshed screenshots. The [social card](../../assets/brand/social-card-1280x640.png) is available in the repository.

## For existing apps

Generated files are not rewritten in existing apps. Compare them with a fresh install and adopt the changes that fit your application. The [v1.51 upgrade guide](../../../guides/introduction/upgrading-to-v1.51.md) explains the library-owned, generated, and host-owned update lanes, including the message and token changes.

Routes, helpers, configuration keys, and authentication behavior stay the same. The generated sign-in wording and the public documentation have been updated; check the guide before copying any generated files or admin assets.

**End of local draft.** The repository social preview and any public announcement remain pending separate approval.
