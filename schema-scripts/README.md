# schema scripts

Contains some scripts for managing the CycleStreets schema.

Note: there are problems with mysqldump for tables that contain geometry, but using option --hex-blob should work.

## csSampleDb.sh

Creates the sample cyclestreets database for shipping with new installations.
Just try running it and it will give feedback as to what to do. (It prefers to run as cyclestreets user).

It contains the essential data for building a CycleStreets instance.
It is created from the latest daily cyclestreets backup copy (itself produced by `../live-deployment/daily-dump.sh`) by stripping all but the essential tables and rows.
Changes to the live cyclestreets database appear in the cyclestreets backup the next day.
Only running the script after that will process the changes into: `/documentation/schema/sampleCyclestreets.sql`.

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
