# Project XeroX Scope

Project XeroX is an in-client desktop UI package.

It begins operating once the user is connected to the Nitro client.

## Project XeroX MAY

- install Xerox/UI2 React components
- install Xerox/UI2 CSS
- install the Xerox wardrobe implementation
- patch the existing Nitro application to mount UI2
- patch existing desktop UI components where Xerox integration requires it
- use the destination hotel's existing APIs, hooks, renderer and assets

## Project XeroX MUST NOT

- replace the hotel's loading screen
- replace the hotel's landing screen
- replace or modify the CMS
- replace or modify the database
- replace or modify gamedata
- change hotel name or branding
- change connection configuration
- replace catalogue database/content
- replace emulator configuration
- replace the mobile interface
- replace unrelated Nitro customisations

## Installation policy

Existing destination files are patched rather than blindly overwritten.

Before any patch is applied, the installer creates a timestamped backup.

If Project XeroX cannot safely recognise an integration point, installation
must stop instead of guessing.
