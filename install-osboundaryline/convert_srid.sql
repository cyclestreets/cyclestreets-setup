/**

The ogr2ogr command loads the data into MySQL geometry fields with SRID=4326.

In MySQL 8.0 geometry fields have to be SRID restricted in order to take advantage of indexing.

The problem is that the tables are not setup properly by the ogr2ogr command to do that.

Therefore this post processing phase is needed to get the geometry fields into the optimal format.

It works by copying the geometry field of each table into a temporary fixing table that has column specification SRID 0.
SRID 0 is used rather than SRID 4326 because the MySQL 8 supports all spatial geometry functions for the former and only
a subset for the latter.

Then the original table column is fixed to have the correct format.
Finally the converted geometry is copied into the original table.

The MySQL 8 function st_transform() cannot be used as it does not work with SRID 0.

*/


-- Boundary-line data contains some large geometries such as Shetland in a verbose WKT format.
-- They can be accommodated by setting this dynamically scoped variable to the maximum 1G.
set global max_allowed_packet := 1024 * 1024 * 1024;


-- Table used to convert the geometries
drop table if exists dev_geom_fixer;
create table dev_geom_fixer (
     fid int      not null auto_increment primary key,
geometry geometry not null srid 0
) engine myisam comment "Temporary table for converting geometries";


-- The following template block does the work.
-- It uses st_geomfromgeojson(st_asgeojson(geometry), 2, 0) to convert the geometry to have SRID=0.

-- Fixes the table named: PATIENT
/*
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from PATIENT;

-- Remove and re-create the geometry field, defaulting to null
alter table PATIENT drop geometry;
alter table PATIENT  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update PATIENT ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table PATIENT change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);
*/


-- The above block is repeated for the following tables:
-- boundary_line_ceremonial_counties
-- boundary_line_historic_counties
-- community_ward
-- country_region
-- county
-- county_electoral_division
-- district_borough_unitary
-- district_borough_unitary_ward
-- english_region
-- greater_london_const
-- high_water
-- historic_european_region
-- parish
-- polling_districts_england
-- scotland_and_wales_const
-- scotland_and_wales_region
-- unitary_electoral_division
-- westminster_const


/* The following creates a view of any of the above tables at the generic /geometrytable/ network browser URL:

create or replace view routing211201.view_geometry_table as
select fid id, name, geometry
  from osboundaryline.boundary_line_ceremonial_counties;

*/



-- Fixes the table named: boundary_line_ceremonial_counties
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from boundary_line_ceremonial_counties;

-- Remove and re-create the geometry field, defaulting to null
alter table boundary_line_ceremonial_counties drop geometry;
alter table boundary_line_ceremonial_counties  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update boundary_line_ceremonial_counties ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table boundary_line_ceremonial_counties change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: boundary_line_historic_counties
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from boundary_line_historic_counties;

-- Remove and re-create the geometry field, defaulting to null
alter table boundary_line_historic_counties drop geometry;
alter table boundary_line_historic_counties  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update boundary_line_historic_counties ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table boundary_line_historic_counties change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: community_ward
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from community_ward;

-- Remove and re-create the geometry field, defaulting to null
alter table community_ward drop geometry;
alter table community_ward  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update community_ward ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table community_ward change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: country_region
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from country_region;

-- Remove and re-create the geometry field, defaulting to null
alter table country_region drop geometry;
alter table country_region  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update country_region ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table country_region change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: county
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from county;

-- Remove and re-create the geometry field, defaulting to null
alter table county drop geometry;
alter table county  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update county ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table county change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: county_electoral_division
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from county_electoral_division;

-- Remove and re-create the geometry field, defaulting to null
alter table county_electoral_division drop geometry;
alter table county_electoral_division  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update county_electoral_division ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table county_electoral_division change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: district_borough_unitary
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from district_borough_unitary;

-- Remove and re-create the geometry field, defaulting to null
alter table district_borough_unitary drop geometry;
alter table district_borough_unitary  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update district_borough_unitary ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table district_borough_unitary change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: district_borough_unitary_ward
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from district_borough_unitary_ward;

-- Remove and re-create the geometry field, defaulting to null
alter table district_borough_unitary_ward drop geometry;
alter table district_borough_unitary_ward  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update district_borough_unitary_ward ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table district_borough_unitary_ward change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: english_region
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from english_region;

-- Remove and re-create the geometry field, defaulting to null
alter table english_region drop geometry;
alter table english_region  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update english_region ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table english_region change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: greater_london_const
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from greater_london_const;

-- Remove and re-create the geometry field, defaulting to null
alter table greater_london_const drop geometry;
alter table greater_london_const  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update greater_london_const ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table greater_london_const change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: high_water
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from high_water;

-- Remove and re-create the geometry field, defaulting to null
alter table high_water drop geometry;
alter table high_water  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update high_water ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table high_water change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: historic_european_region
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from historic_european_region;

-- Remove and re-create the geometry field, defaulting to null
alter table historic_european_region drop geometry;
alter table historic_european_region  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update historic_european_region ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table historic_european_region change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: parish
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from parish;

-- Remove and re-create the geometry field, defaulting to null
alter table parish drop geometry;
alter table parish  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update parish ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table parish change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: polling_districts_england
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from polling_districts_england;

-- Remove and re-create the geometry field, defaulting to null
alter table polling_districts_england drop geometry;
alter table polling_districts_england  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update polling_districts_england ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table polling_districts_england change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: scotland_and_wales_const
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from scotland_and_wales_const;

-- Remove and re-create the geometry field, defaulting to null
alter table scotland_and_wales_const drop geometry;
alter table scotland_and_wales_const  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update scotland_and_wales_const ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table scotland_and_wales_const change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: scotland_and_wales_region
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from scotland_and_wales_region;

-- Remove and re-create the geometry field, defaulting to null
alter table scotland_and_wales_region drop geometry;
alter table scotland_and_wales_region  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update scotland_and_wales_region ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table scotland_and_wales_region change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: unitary_electoral_division
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from unitary_electoral_division;

-- Remove and re-create the geometry field, defaulting to null
alter table unitary_electoral_division drop geometry;
alter table unitary_electoral_division  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update unitary_electoral_division ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table unitary_electoral_division change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Fixes the table named: westminster_const
-- Reset
truncate dev_geom_fixer;

-- Copy fid and converted geometry to fixer table
insert dev_geom_fixer
select fid, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from westminster_const;

-- Remove and re-create the geometry field, defaulting to null
alter table westminster_const drop geometry;
alter table westminster_const  add geometry geometry null after fid;

-- Copy the converted geometry into the original table ot from the fixer table ft
update westminster_const ot
  join dev_geom_fixer ft on ft.fid = ot.fid
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table westminster_const change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);




-- Finally
drop table dev_geom_fixer;


-- End of file
