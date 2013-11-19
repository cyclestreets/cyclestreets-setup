# schema scripts

Contains some scripts for managing the CycleStreets schema.

## csSampleDb.sh

Creates the sample cyclestreets database for shipping with new installations.

It contains the essential data for building a CycleStreets instance.
It is created from a the latest daily cyclestreets backup copy by stripping all but the essential tables and rows.
That means that changes to the live cyclestreets database won't appear in the resulting file until the script is run a day later.

The result is saved to:
/documentation/schema/cyclestreets.sql

## externalDb.sh

Creates a dump of the external schema only (no data).


## routingSample.sh

Produces a sample routing database for shipping with new installations.

The result is saved to:
/documentation/schema/routingSample.sql.gz


