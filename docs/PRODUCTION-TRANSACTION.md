# Project XeroX Production Transaction

Project XeroX uses a fail-closed production transaction.

The intended production sequence is:

1. Validate exact approved release pins.
2. Validate the destination profile.
3. Validate protected Nitro runtime configuration.
4. Validate immutable historical Flyway migrations.
5. Validate database isolation policy.
6. Create and verify the unified filesystem + database rollback backup.
7. Stage exact approved releases.
8. Prepare the machine-readable deployment transaction.
9. Stop the explicitly configured application service.
10. Apply approved portable source changes.
11. Build the managed applications.
12. Overlay the five destination-owned Nitro runtime configuration files.
13. Run application, migration, JSON and API-contract validation.
14. Start the explicitly configured application service.
15. Perform post-start validation.

Any failure must stop the transaction.

Filesystem rollback may use the verified pre-deployment backup.

Database rollback is never automatic. The database snapshot is rollback-only and
requires a separate explicit destructive restore procedure.

Destination user/account/community data must never be distributed or imported
between hotels.

Gamedata is outside this updater and will be handled by Project XeroX Gamedata.

Production installation remains locked until the complete transaction and
controlled database-restore gate have both been certified.
