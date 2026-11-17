# Generated authentication copy and translations

Sigra's installer generates authentication pages into the host Phoenix application. The host owns those templates and owns the Gettext backend and catalogs used by its requests and emails. Sigra does not keep a runtime copy map, and the generated copy continues to use the fixed `sigra` Gettext domain.

## Extract and merge messages

Run these commands from the generated Phoenix application's root after installing or changing generated auth templates:

```sh
mix gettext.extract
mix gettext.merge priv/gettext --locale es
```

`mix gettext.extract` scans the host source and updates the POT templates under `priv/gettext`. `mix gettext.merge` merges those templates into the selected locale's PO catalogs. Replace `es` with each locale your host app supports, review the resulting catalog changes, and commit them with the host app.

Generated auth templates call `dgettext("sigra", ...)`, so translations for these messages belong to the `sigra` domain in the host's catalog tree. Keep the `sigra` domain in generated templates when changing copy. The host's configured Gettext backend loads the catalogs; applications can customize wording by editing the generated host templates and maintaining those catalogs.

## Ownership boundary

Keep user-facing auth wording in generated host templates and Gettext catalogs. Branding profile values cover product identity and visual defaults; they are not a runtime message store. This leaves the host application in control of product tone, legal wording, locale-specific grammar, and catalog review.
