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

Only releases explicitly pinned in the release manifest are eligible for controlled production deployment.

---

## 4. Plan an Update

Run:

```bash
cd /var/www/Project-XeroX
installer/master-update.sh --plan
```

The planner stages and compares the approved releases without performing a production deployment.

Planning should be completed before a production update so unexpected destination differences can be investigated before any live changes are made.

---

## 5. Production Preflight

Run:

```bash
installer/production-preflight.sh \
    /etc/project-xerox/myhotel.conf
```

The production preflight verifies that the destination satisfies the required safety policy before deployment.

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
- Migrations-only database policy
- Immutable Flyway migrations
- Build requirements
- Clean Polaris build requirements
- Production service configuration
- Production service health requirements
- Transaction safety
- Backup and rollback requirements
- Gamedata exclusion
- Automatic database restore prohibition

Certification is intentionally non-destructive and should pass before a live production update is attempted.

---

# Production Installation

Production installation is available through the guarded Project XeroX production updater.

Before performing a real production installation, always run planning, production preflight and production certification successfully.

The production installation command requires an explicit destination profile, the `--confirm` option and the exact production confirmation token:

```bash
installer/production-update.sh \
    --install \
    /etc/project-xerox/myhotel.conf \
    --confirm \
    PROJECT-XEROX-PRODUCTION-UPDATE
```

The same guarded production installation can also be entered through `installer/master-update.sh`.

The confirmation token is deliberately explicit. Do not remove, weaken or bypass this production gate.

## Production Deployment Sequence

A production installation performs a controlled, fail-closed deployment sequence:

1. Run the production preflight.
2. Stage the exact approved release commits.
3. Verify the staged releases.
4. Verify immutable historical Flyway migrations.
5. Prepare the deployment transaction.
6. Capture destination-owned Nitro runtime configuration.
7. Create and verify filesystem rollback backups.
8. Create and verify the destination database rollback snapshot.
9. Verify rollback capability before live mutation.
10. Stop the explicitly configured production service.
11. Apply the prepared source transaction.
12. Build the Renderer.
13. Type-check and build Nitro.
14. Restore destination-owned Nitro runtime configuration.
15. Verify the restored runtime configuration and API contract.
16. Build Polaris using a clean Maven build.
17. Re-verify immutable migration safety.
18. Start the configured Polaris production service.
19. Verify the production service is healthy.
20. Allow Flyway to run through the normal Polaris startup process.
21. Verify Flyway contains no failed migrations.
22. Perform final runtime configuration and API checks.
23. Perform the final production service health check.
24. Mark the production update successful only after all required checks pass.

The updater must fail rather than silently continue when a required production safety condition is not satisfied.

## Clean Polaris Builds

Production Polaris builds use:

```text
mvn clean package
```

A clean build is mandatory so stale Maven `target` output cannot be reused during a production update.

This is particularly important when dependency compatibility, packaged classes or plugin-visible APIs have changed between approved Polaris releases.

## Production Service Health

Project XeroX explicitly verifies the configured production service after startup.

For a systemd-managed installation, the configured service must report as active before the deployment can be marked successful.

Service health is checked during the post-start deployment sequence and again as part of final production verification.

A successful production deployment ends with markers including:

```text
PROJECT XEROX PRODUCTION UPDATE=PASS
DATABASE_MODE=MIGRATIONS_ONLY
AUTOMATIC_DATABASE_RESTORE=DISABLED
GAMEDATA=EXCLUDED
SERVICE=HEALTHY
```

Do not treat a production deployment as successful unless the production updater reaches its final success state.

If any required production check fails, investigate the failure rather than bypassing the safety gate.

---

# Database Safety

Project XeroX uses a **migrations-only** database policy.

Approved releases may contain database migrations required by new functionality, but destination database contents are not replaced or distributed.

Project XeroX does not deploy release database dumps into destination hotels.

Before database migrations are allowed, Project XeroX requires a private rollback backup of the destination database.

Database backups are:

- Destination-specific
- Rollback-only
- Checksum verified
- Created before migration is allowed
- Never included in Project XeroX releases
- Never intended for cross-hotel import

Historical Flyway migrations are treated as immutable.

If an existing historical migration differs from the approved release, deployment stops instead of silently rewriting migration history.

New database changes must be introduced through new approved migrations rather than by modifying released historical migrations.

Automatic live database restoration is disabled.

A failed production deployment does **not** automatically restore the database.

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

The restored configuration is verified before production deployment can complete.

JSON formatting differences such as minified versus pretty-printed JSON are accepted when the effective data is identical.

Real configuration value changes are rejected.

The Nitro API configuration is also validated so a source release cannot silently replace the destination hotel's API endpoint.

---

# Renderer Preservation

Destination-specific Renderer integration points that must survive updates are defined in:

```text
manifest/renderer-preserve.txt
```

Only explicitly approved preservation paths should be added to this manifest.

Renderer updates must not silently overwrite protected destination-specific integration configuration.

---

# CMS Updates

AtomCMS uses **selective deployment** rather than wholesale replacement.

Approved portable CMS files are defined in:

```text
manifest/cms-portable-files.txt
```

Destination themes, uploads, storage, environment configuration and unrelated CMS customisations remain protected.

Project XeroX should never be used to replace an entire destination CMS simply because the source installation contains different files.

---

# Gamedata

Gamedata is deliberately outside the Project XeroX master updater.

The production profile must keep:

```text
MANAGE_GAMEDATA=0
```

The production updater fails closed if gamedata management is enabled.

Gamedata will be handled separately by **Project XeroX Gamedata**.

This separation prevents application deployment from unexpectedly replacing hotel-specific furnidata, figures, assets or other gamedata resources.

---

# Backups and Rollback

Production updates require verified rollback backups of the managed applications and destination database before live mutation is allowed.

The production backup contains rollback material for the managed application components and a destination-specific database snapshot.

Filesystem rollback support is provided by:

```bash
installer/rollback.sh
```

Rollback material is verified before the production transaction proceeds.

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

Automatic database restoration by the production updater is disabled.

A deployment failure must preserve the available rollback information so the administrator can diagnose the failure and make a controlled recovery decision.

---

# Production Failure Handling

Project XeroX follows a fail-closed production failure model.

If a production deployment fails:

- The deployment must not be reported as successful.
- The failure stage and exit status should be retained in the deployment log.
- Verified rollback backups should be preserved.
- Database restoration must not happen automatically.
- The failure should be diagnosed before another production deployment is attempted.
- A service should not be blindly restarted or a database blindly restored simply to clear a failed deployment state.

If the resulting production state is already healthy after correcting an orchestration-only problem, it may be independently verified and accepted rather than unnecessarily redeploying unchanged application releases.

Historical failed deployment logs should remain unchanged as part of the audit trail.

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

Project XeroX itself should be kept separate from the managed Nitro, Renderer, Emulator, CMS and gamedata repositories.

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
- Private destination profiles containing credentials

Production profiles should use restrictive filesystem permissions appropriate for the destination environment.

---

# Safety Model

Project XeroX follows a **fail-closed** deployment model.

A deployment must stop rather than silently:

- Replace destination database contents
- Import another hotel's data
- Rewrite historical Flyway migrations
- Deploy a release database dump
- Replace hotel branding
- Replace destination runtime API configuration
- Delete destination-only files
- Deploy unapproved releases
- Modify gamedata through the master updater
- Continue after a required backup failure
- Continue after a production build failure
- Continue after a failed service health check
- Automatically restore the production database

Safety checks are part of the production deployment contract and must not be bypassed merely to force an update through.

---

# Current Status

The following foundations are implemented and certified:

- Exact release commit pinning
- Isolated release staging
- Destination comparison
- Protected-file policies
- Transaction deployment engine
- Nitro runtime configuration preservation
- Nitro API contract validation
- Renderer preservation
- Selective CMS deployment
- Database migrations-only policy
- Immutable Flyway migration validation
- Filesystem rollback backups
- Database rollback backups
- Controlled database restore gate
- Automatic database restore prohibition
- Gamedata exclusion
- Explicit production service handling
- Production service health verification
- Clean Polaris production builds
- Guarded production installation
- Production preflight
- Production certification
- Release-engine commit auditing
- Fail-closed production execution

**Controlled production deployment is enabled and has completed final production certification.**

Production installation remains deliberately guarded and requires:

- An explicit destination profile
- Approved release commits
- Successful production preflight
- Successful production certification
- The explicit production confirmation token
- Verified rollback backups
- A migrations-only database policy
- Immutable historical Flyway migrations
- Preserved destination runtime configuration
- Gamedata exclusion
- A clean Polaris production build
- A healthy configured production service

---

## Important

Always run planning, preflight and certification before a production update.

Never bypass a failed Project XeroX safety check simply to force an update.

Never distribute one hotel's database or private configuration as part of a Project XeroX release.

Never modify an already-released historical Flyway migration to make a deployment pass.

Never automatically restore a production database after a failed deployment.

A production deployment should only be considered complete when the final production safety checks have passed and the resulting service and database state are healthy.
