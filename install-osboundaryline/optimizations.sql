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


-- 1
-- Add fields for centroids
alter table county
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update county
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 2
-- Add fields for centroids
alter table county_electoral_division
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update county_electoral_division
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 3
-- Add fields for centroids
alter table district_borough_unitary
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update district_borough_unitary
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 4
-- Add fields for centroids
alter table district_borough_unitary_ward
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update district_borough_unitary_ward
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 5
-- Add fields for centroids
alter table european_region
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update european_region
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 6
-- Add fields for centroids
alter table greater_london_const
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update greater_london_const
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 7
-- Add fields for centroids
alter table parish
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update parish
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 8
-- Add fields for centroids
alter table scotland_and_wales_const
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update scotland_and_wales_const
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 9
-- Add fields for centroids
alter table scotland_and_wales_region
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update scotland_and_wales_region
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 10
-- Add fields for centroids
alter table unitary_electoral_division
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update unitary_electoral_division
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);


-- 11
-- Add fields for centroids
alter table westminster_const
 add longitude decimal(8,5) not null default 0 comment 'Longitude of centroid',
 add latitude  decimal(7,5) not null default 0 comment 'Latitude of centroid';

-- Set centroid coordinates
update westminster_const
   set longitude = ROUND(ST_X(ST_Centroid(geometry)), 5),
       latitude  = ROUND(ST_Y(ST_Centroid(geometry)), 5);

-- End of file
