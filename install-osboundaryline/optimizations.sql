-- Changes to the OS Boundary Line database from the directly provided version
-- These changes are aimed at helping performance.

-- Load this file using e.g.:
-- mysql osboundaryline < /opt/cyclestreets-setup/install-osboundaryline/optimizations.sql

-- List the distinct area_description
/*
select area_description, count(*)
  from district_borough_unitary
 group by area_description;
*/

-- Based on the result of the previous query convert to more efficient ENUM() type and add index
alter table district_borough_unitary
change area_description area_description enum('Metropolitan District','Unitary Authority','District','London Borough'),
 add index(area_description);


-- Centroids
/*
-- This query lists the tables that are affected:

select count(*), x.TABLE_NAME
 from (SELECT COLUMN_NAME ,TABLE_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
   WHERE COLUMN_NAME IN ('global_polygon_id','name', 'area_description', 'geometry', 'hectares')
        AND TABLE_SCHEMA='osboundaryline')x
group by x.TABLE_NAME
having count(*)=5;

*/


-- boundary_line_ceremonial_counties
-- Add fields for centroids
alter table boundary_line_ceremonial_counties
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update boundary_line_ceremonial_counties
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- boundary_line_historic_counties
-- Add fields for centroids
alter table boundary_line_historic_counties
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update boundary_line_historic_counties
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- community_ward
-- Add fields for centroids
alter table community_ward
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update community_ward
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- country_region
-- Add fields for centroids
alter table country_region
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update country_region
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- county
-- Add fields for centroids
alter table county
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update county
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- county_electoral_division
-- Add fields for centroids
alter table county_electoral_division
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update county_electoral_division
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- district_borough_unitary
-- Add fields for centroids
alter table district_borough_unitary
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update district_borough_unitary
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- district_borough_unitary_ward
-- Add fields for centroids
alter table district_borough_unitary_ward
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update district_borough_unitary_ward
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- english_region
-- Add fields for centroids
alter table english_region
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update english_region
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- greater_london_const
-- Add fields for centroids
alter table greater_london_const
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update greater_london_const
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- high_water
-- Add fields for centroids
alter table high_water
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update high_water
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- historic_european_region
-- Add fields for centroids
alter table historic_european_region
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update historic_european_region
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- parish
-- Add fields for centroids
alter table parish
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update parish
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- polling_districts_england
-- Add fields for centroids
alter table polling_districts_england
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update polling_districts_england
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- scotland_and_wales_const
-- Add fields for centroids
alter table scotland_and_wales_const
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update scotland_and_wales_const
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- scotland_and_wales_region
-- Add fields for centroids
alter table scotland_and_wales_region
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update scotland_and_wales_region
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- unitary_electoral_division
-- Add fields for centroids
alter table unitary_electoral_division
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update unitary_electoral_division
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- westminster_const
-- Add fields for centroids
alter table westminster_const
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update westminster_const
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);

-- End of file
