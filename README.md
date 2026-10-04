# Project XeroX

Project XeroX is a deployment and update framework for managing approved Nitro, Renderer, Polaris Emulator and selected AtomCMS updates across compatible Habbo retro installations.

Its purpose is to make updates repeatable while preserving each destination hotel's own configuration, branding and data.

> **Update the application without turning the destination hotel into the source hotel.**

## Managed Components

Project XeroX currently manages:

- Nitro
- Nitro Renderer
- Polaris Emulator
- Selected portable AtomCMS files
- Project XeroX UI integration
- Approved database migrations

**Gamedata is deliberately excluded from the master updater.**

Gamedata will be handled separately by **Project XeroX Gamedata**.

---

## What Project XeroX Protects

Project XeroX is designed to preserve destination-specific state including:

- Hotel branding and identity
- Loading and landing assets
- Nitro runtime configuration
- API endpoints
- Environment files and credentials
- Database contents
- Users, inventories and currencies
- Rooms and room items
- Achievements and relationships
- Messages, groups and bans
- Website accounts
- Hotel-specific emulator configuration
- Uploads and storage
- Destination-only files
- Approved Renderer customisations
- Mobile customisations unless explicitly managed

Project XeroX does **not** distribute one hotel's database to another hotel.

---

# Installation

## Requirements

The current tooling expects:

- Linux
- Bash
- Git
- Python 3
- Node.js and Yarn
- Java and the build tooling required by Polaris
- MariaDB or compatible MySQL
- systemd
- Sufficient disk space for staging and rollback backups

Production operation normally requires root or equivalent permissions.

## 1. Clone Project XeroX

```bash
cd /var/www
git clone https://github.com/xerohab/Project-XeroX.git
cd Project-XeroX
```

Project XeroX should remain separate from Nitro, Renderer, Emulator, CMS and gamedata.

## 2. Create a Destination Profile

Create the configuration directory:

```bash
mkdir -p /etc/project-xerox
```

Copy the supplied example:

```bash
cp manifest/destination-profile.example.conf \
   /etc/project-xerox/myhotel.conf

chmod 600 /etc/project-xerox/myhotel.conf
```

Edit the profile:

```bash
nano /etc/project-xerox/myhotel.conf
```

Configure the correct application paths, database and production services for the destination hotel.

Do not commit destination profiles containing credentials or private configuration to GitHub.

A typical installation may use:

```text
/var/www/Project-XeroX
/var/www/Nitro-V3
/var/www/Nitro_Render_V3
/var/www/emulator
/var/www/atomcms
/var/www/gamedata
```

Actual paths are controlled by the destination profile.

---

## 3. Approved Releases

Source repositories are configured in:

```text
manifest/sources.conf
```

Exact approved release commits are configured in:

```text
manifest/releases.conf
```

Project XeroX uses the approved commit pins rather than blindly deploying the latest branch HEAD.

---

## 4. Plan an Update

Run:

```bash
cd /var/www/Project-XeroX
installer/master-update.sh --plan
```

The planner stages and compares the approved releases without performing a production deployment.

---

## 5. Production Preflight

Run:

```bash
installer/production-preflight.sh \
    /etc/project-xerox/myhotel.conf
```

A failed preflight should be investigated rather than bypassed.

---

## 6. Production Certification

Run:

```bash
installer/production-update.sh \
    --certify \
    /etc/project-xerox/myhotel.conf
```

Certification validates the production deployment requirements without performing the real installation.

Checks include:

- Destination configuration
- Approved release commits
- Nitro runtime configuration preservation
- Renderer preservation rules
- Selective CMS deployment
- Database isolation
- Immutable Flyway migrations
- Build requirements
- Production service configuration
- Transaction safety
- Backup and rollback requirements

---

# Production Installation

> **Production installation is intentionally locked in the current release.**

The planned production interface is:

```bash
installer/production-update.sh \
    --install \
    /etc/project-xerox/myhotel.conf
```

The current release deliberately rejects this operation.

**Do not remove or bypass the installation lock.**

This section will be updated once the controlled production installation workflow has completed final certification.

---

# Database Safety

Project XeroX uses a **migrations-only** database policy.

Approved releases may contain database migrations required by new functionality, but destination database contents are not replaced or distributed.

Before database migrations are allowed, Project XeroX requires a private rollback backup of the destination database.

Database backups are:

- Destination-specific
- Rollback-only
- Checksum verified
- Never included in Project XeroX releases
- Never intended for cross-hotel import

Historical Flyway migrations are treated as immutable.

If an existing historical migration differs from the approved release, deployment stops instead of silently rewriting migration history.

Automatic live database restoration is disabled.

Database restoration requires a separate controlled procedure and explicit destructive confirmation.

---

# Nitro Runtime Configuration

Project XeroX protects the destination-owned Nitro runtime configuration:

```text
client-mode.json
renderer-config.json
ui-config.json
hotlooks.json
infostand_backgrounds.json
```

Runtime configuration is captured before deployment and restored into the built Nitro distribution.

JSON formatting differences such as minified versus pretty-printed JSON are accepted when the effective data is identical.

Real configuration value changes are rejected.

---

# Renderer Preservation

Destination-specific Renderer integration points that must survive updates are defined in:

```text
manifest/renderer-preserve.txt
```

Only explicitly approved preservation paths should be added to this manifest.

---

# CMS Updates

AtomCMS uses **selective deployment** rather than wholesale replacement.

Approved portable CMS files are defined in:

```text
manifest/cms-portable-files.txt
```

Destination themes, uploads, storage, environment configuration and unrelated CMS customisations remain protected.

---

# Backups and Rollback

Production updates require verified rollback backups of the managed applications and destination database.

Filesystem rollback support is provided by:

```bash
installer/rollback.sh
```

A database backup can be verified without restoring it:

```bash
installer/restore-database.sh \
    --verify /path/to/database-backup
```

Database restoration is intentionally separate and destructive.

It requires:

- A verified Project XeroX database backup
- Matching source and destination database identity
- An explicitly configured service
- Explicit destructive confirmation

**Cross-database and cross-hotel database restoration is prohibited.**

---

# Updating Project XeroX

To update an existing Project XeroX installation:

```bash
cd /var/www/Project-XeroX
git status
git pull --ff-only origin main
```

Do not pull over uncommitted local modifications.

After updating Project XeroX, run planning, preflight and certification again before any production deployment.

---

# Security

Never commit:

- `.env` files
- Passwords
- API secrets
- Access tokens
- Private keys
- Database dumps
- Production backup archives
- Destination runtime configuration
- User data

---

# Safety Model

Project XeroX follows a **fail-closed** deployment model.

A deployment must stop rather than silently:

- Replace destination database contents
- Import another hotel's data
- Rewrite historical Flyway migrations
- Replace hotel branding
- Replace destination runtime API configuration
- Delete destination-only files
- Deploy unapproved releases
- Modify gamedata through the master updater

---

# Current Status

The following foundations are implemented and certified:

- Exact release commit pinning
- Isolated release staging
- Destination comparison
- Protected-file policies
- Transaction deployment engine
- Nitro runtime configuration preservation
- Renderer preservation
- Selective CMS deployment
- Database migrations-only policy
- Immutable Flyway migration validation
- Filesystem rollback backups
- Database rollback backups
- Controlled database restore gate
- Explicit production service handling
- Production preflight
- Production certification
- Release-engine commit auditing

**Real production deployment remains locked pending final controlled installation certification.**

---

## Important

Always run planning and certification before a production update.

Never bypass a failed Project XeroX safety check simply to force an update.
