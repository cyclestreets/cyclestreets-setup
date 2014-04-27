# schema scripts

Contains some scripts for managing the CycleStreets schema.

## csSampleDb.sh

Creates the sample cyclestreets database for shipping with new installations.

It contains the essential data for building a CycleStreets instance.
It is created from a the latest daily cyclestreets backup copy (itself produced by `../live-deployment/daily-dump.sh`) by stripping all but the essential tables and rows.
Changes to the live cyclestreets database appear in the cyclestreets backup the next day.
Only running the script after that will process the changes into: `/documentation/schema/cyclestreetsSample.sql`.

## externalDb.sh

Creates a dump of the external schema only (no data).


## routingSample.sh

Produces a sample routing database for shipping with new installations.

The result is saved to:
/documentation/schema/routingSample.sql.gz


To create sample routing data
    Run an import for a small sized city
    Switch over to the new import via the control panel
    Run in this order:
    schema-scripts/csSampleDb.sh
    schema-scripts/routingSample.sh
    That will bind the latest routing edition into the sample database so that it should get set up with fresh installs.
