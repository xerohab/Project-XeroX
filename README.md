# Project XeroX Production Transaction

Project XeroX uses a guarded, fail-closed production transaction.

A production deployment must complete every required safety stage before it can be marked successful.

## Production Sequence

The controlled production sequence is:

1. Validate the destination profile.
2. Validate exact approved release pins.
3. Run the production preflight.
4. Stage the exact approved releases.
5. Verify the staged releases.
6. Validate protected Nitro runtime configuration.
7. Validate immutable historical Flyway migrations.
8. Validate the migrations-only database isolation policy.
9. Prepare the machine-readable deployment transaction.
10. Capture the five destination-owned Nitro runtime configuration files.
11. Create and verify the unified filesystem and database rollback backup.
12. Verify rollback capability before live mutation.
13. Stop the explicitly configured production service.
14. Apply the approved source transaction.
15. Build the Renderer.
16. Type-check and build Nitro.
17. Restore the destination-owned Nitro runtime configuration.
18. Verify restored runtime configuration and API endpoints.
19. Build Polaris using a clean Maven build.
20. Re-verify immutable migration safety.
21. Start the explicitly configured production service.
22. Verify the production service is healthy.
23. Allow Flyway migrations to run through normal Polaris startup.
24. Verify Flyway contains no failed migrations.
25. Perform final Nitro runtime configuration and API-contract validation.
26. Perform the final production service health check.
27. Mark the production transaction successful only after all final checks pass.

Any required failure must stop the transaction.

The production updater must not silently bypass a failed safety check.

## Guarded Production Execution

Production installation requires an explicit destination profile and the exact production confirmation gate.

The guarded production interface is:

```bash
installer/production-update.sh \
    --install \
    /etc/project-xerox/myhotel.conf \
    --confirm \
    PROJECT-XEROX-PRODUCTION-UPDATE
```

The confirmation requirement must not be removed or weakened simply to force an update.

Production preflight and certification should be completed successfully before a live installation is attempted.

## Clean Polaris Build

Polaris is built during production deployment using:

```text
mvn clean package
```

A clean build prevents stale Maven `target` output from being reused during production deployment.

The production transaction must stop if the required Polaris build fails.

## Runtime Configuration

The five destination-owned Nitro runtime configuration files are captured before the production transaction modifies the managed application sources.

They are restored into the built Nitro distribution and verified before the production transaction can complete.

The protected files are:

```text
client-mode.json
renderer-config.json
ui-config.json
hotlooks.json
infostand_backgrounds.json
```

Semantic JSON equivalence is accepted where formatting differs but the effective configuration is unchanged.

Real destination configuration changes are rejected.

The destination API configuration must also pass the Project XeroX API-contract validation.

## Production Service Health

The production service is explicitly configured by the destination profile.

After Polaris is started, Project XeroX verifies that the configured production service is healthy.

For a systemd-managed destination, the configured service must report as active.

Service health is checked after startup and again during final production verification.

A production transaction must not be marked successful when the configured service fails its health check.

## Database Safety

Project XeroX uses a migrations-only database policy.

Destination database contents are never replaced by a source or release database.

Historical Flyway migrations are immutable.

New database changes must be introduced through new approved migrations rather than by modifying an already-released historical migration.

Before migrations are allowed, Project XeroX requires a verified destination-specific database rollback snapshot.

After Polaris starts, the production transaction verifies that Flyway contains no failed migrations.

## Backups and Rollback

Production deployment requires a verified pre-deployment rollback backup.

The backup contains the required managed application rollback material and a destination-specific database snapshot.

Filesystem rollback may use the verified pre-deployment backup.

Database rollback is never automatic.

The database snapshot is rollback-only and requires a separate explicit destructive restore procedure.

A production deployment failure must preserve the available rollback information for controlled diagnosis and recovery.

The production updater must never automatically restore the destination database after a deployment failure.

## Destination Isolation

Destination user, account, inventory, room, community and other hotel-specific data must never be distributed or imported between hotels.

Cross-hotel database import is prohibited.

Destination-specific configuration, credentials, branding and protected runtime configuration must remain destination-owned.

Destination-only files must not be deleted simply because they do not exist in the approved source release.

## Gamedata

Gamedata is outside the Project XeroX master updater.

Production profiles must keep gamedata management disabled.

Gamedata will be handled separately by **Project XeroX Gamedata**.

## Successful Production Completion

A successful production transaction reaches the final production checks and emits success markers including:

```text
PROJECT XEROX PRODUCTION UPDATE=PASS
DATABASE_MODE=MIGRATIONS_ONLY
AUTOMATIC_DATABASE_RESTORE=DISABLED
GAMEDATA=EXCLUDED
SERVICE=HEALTHY
```

If these final checks are not reached, the production invocation must not be represented as successful.

Historical failed deployment logs should remain unchanged as part of the deployment audit trail.

A resulting production state may be independently verified and accepted after an orchestration-only problem has been corrected, without unnecessarily redeploying unchanged approved application releases.

## Current Status

Controlled production deployment is enabled and has completed final production certification.

The production transaction currently includes:

- Exact approved release pinning
- Isolated release staging
- Production preflight
- Production certification
- Explicit production confirmation
- Protected destination configuration
- Nitro runtime configuration capture and restoration
- Runtime API-contract validation
- Immutable Flyway migration validation
- Migrations-only database policy
- Verified filesystem rollback backups
- Verified database rollback snapshots
- Automatic database restore prohibition
- Transaction-based source deployment
- Clean Polaris production builds
- Explicit production service handling
- Production service health verification
- Post-start Flyway validation
- Gamedata exclusion
- Fail-closed production execution

Production installation is therefore no longer considered locked.

It remains deliberately guarded and must only proceed when all required Project XeroX production safety checks pass.
