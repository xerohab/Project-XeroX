# Project XeroX Deployment Safety

## Destination runtime configuration

Nitro `public/configuration` belongs to the destination hotel.

Before replacing a built Nitro client, Project XeroX captures the runtime files
listed in `manifest/nitro-runtime-config.txt`.

After the XeroX build is installed, those destination files are restored into
`dist/configuration`.

A deployment is not healthy until the required configuration files:

1. exist in both public and dist configuration;
2. are byte-for-byte equal;
3. parse as JSON;
4. return HTTP 200 through the destination web server; and
5. contain no unresolved API URL placeholder in runtime JSON.

This rule exists because the first HabLounge deployment proved that replacing
Nitro dist while protecting public configuration can otherwise leave the new
client without the destination runtime configuration it requires.

## Flyway

Existing Flyway migration filenames are immutable.

If a staged historical migration has the same filename as a destination
migration but different bytes, deployment must stop.

Never repair this by editing an already-released historical migration.

New migrations must use new migration filenames.

## Staging

Recognised editor, backup and rejected-patch files are forbidden from a release
staging tree.

Historical staging debris is reported before it is removed.
