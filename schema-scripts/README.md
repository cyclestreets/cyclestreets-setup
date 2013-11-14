# schema scripts

Contains some scripts for managing the CycleStreets schema.

## csSampleDb.sh

Creates the sample cyclestreets database for shipping with new installations.
It contains the essential data for building a CycleStreets instance.
It is created from an existing cyclestreets database by stripping all but the essential tables and rows.
The result is saved to:
/documentation/schema/cyclestreets.sql.gz

## externalDb.sh

Creates a dump of the external schema only (no data).


## routingSample.sh

Produces a sample routing database for shipping with new installations.

The result is saved to:
/documentation/schema/routingSample.sql.gz


