# schema scripts

Contains some scripts for building the CycleStreets schema for new installations.


## csSampleDb.sh

Creates the sample `cyclestreets` database for shipping with new installations.
Just try running it as cyclestreets user for instructions.

It contains the essential data for building a CycleStreets instance.
It is created from the latest daily cyclestreets backup copy (itself produced by `../live-deployment/daily-dump.sh`) by stripping all but the essential tables and rows.

The main www service is assumed to be up to date, but to be sure run these steps before the daily dump is made:

```shell
mysql cyclestreets < documentation/schema/csStoredRoutines.sql
mysql cyclestreets < documentation/schema/trigger.sql
```

Result is written to: `/documentation/schema/sampleCyclestreets.sql`.


## externalDb.sh

Creates a dump of the external schema, optionally including data.


## sampleRouting.sh

Produces a sample routing database for shipping with new installations.

The result is saved to:
/documentation/schema/sampleRouting.sql.gz


To create sample routing data
    Run an import for a small sized city i.e. Cambridge
    Switch over to the new import via Control
    Run in this order:
    schema-scripts/csSampleDb.sh
    schema-scripts/sampleRouting.sh
    That will bind the latest routing edition into the sample database so that it should get set up with fresh installs.
