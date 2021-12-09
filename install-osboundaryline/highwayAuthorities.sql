/* This script creates a table containing the Highway Authorities.
   These are comprised of:

     - All rows from the county table
     - Rows from the district_borough_unitary where area_description is 'Unitary Authority' or 'Metropolitan District'

   Together their geometries should cover the whole of Great Britain.

   The Boundary Line data is described at:
   https://www.ordnancesurvey.co.uk/documents/product-support/release-notes/boundary-line-user-guide-Jul-19.pdf
*/

-- Load using
-- !! #mysql8 Account for comments when using MySQL 8.0.
-- mysql osboundaryline < /opt/cyclestreets-setup/install-osboundaryline/highwayAuthorities.sql

-- Combine County and 'Unitary Authority'
drop table if exists dev_combined_county_unitary;
create table dev_combined_county_unitary like district_borough_unitary;

alter table dev_combined_county_unitary
 change fid fid int not null,
  add id int unsigned not null auto_increment primary key first,
  add color varchar(7) not null default '#48f' comment 'Colour' after id,
  change area_description area_description enum('Unitary Authority', 'Metropolitan District', 'County', 'Greater London Authority'),
 drop area_code,
 drop file_name,
 drop feature_serial_number,
 drop collection_serial_number,
 drop global_polygon_id,
 drop admin_unit_id,
 drop census_code,
 drop hectares,
 drop non_inland_area,
 drop area_type_code,
 drop area_type_description,
 drop non_area_type_code,
 drop non_area_type_description,
-- These next two are added by the centroids
 drop longitude,
 drop latitude,
 drop key `fid`;

/* #mysql8
-- On MySQL 8.0 change the geometry to SRID=0
alter table dev_combined_county_unitary
 drop key geometry;

alter table dev_combined_county_unitary
 change geometry geometry geometry not null srid 0 comment 'SRID zero';
alter table dev_combined_county_unitary
 add spatial key (geometry);
*/

-- Check
-- show create table dev_combined_county_unitary\G

-- Reset
truncate dev_combined_county_unitary;

-- Fill with 'Unitary Authority'
-- #mysql8 This won't work unless the source table has data converted to SRID=0.
insert dev_combined_county_unitary (fid, name, area_description, geometry)
select fid, name, area_description,
       /* Maximal tolerances obtained by trial-and-error that maintain geometry validity. */
       st_simplify(geometry,
       case name
       when 'Shetland Islands'                    then 0.000007
       when 'Highland'                            then 0.000007
       when 'Isle of Wight'                       then 0.00001
       when 'Sir Ynys Mon - Isle of Anglesey'     then 0.00001
       when 'Argyll and Bute'                     then 0.00001
       when 'Orkney Islands'                      then 0.00001
       when 'North Ayrshire'                      then 0.00001
       when 'Sir Benfro - Pembrokeshire'          then 0.00001
       when 'Na h-Eileanan an Iar'                then 0.00001
       when 'Cornwall'                            then 0.00001
       when 'Fife'                                then 0.00002
       when 'Aberdeenshire'                       then 0.00002
       when 'Moray'                               then 0.00002
       when 'Northumberland'                      then 0.00003
       when 'Gwynedd - Gwynedd'                   then 0.00003
       when 'Falkirk'                             then 0.00003
       when 'South Ayrshire'                      then 0.00005
       when 'City of Edinburgh'                   then 0.00005
       when 'Sir y Fflint - Flintshire'           then 0.00005
       when 'Aberdeen City'                       then 0.00009
       when 'South Gloucestershire'               then 0.0007
       when 'Sir Fynwy - Monmouthshire'           then 0.0001
       when 'Dumfries and Galloway'               then 0.0001
       when 'East Lothian'                        then 0.0001
       when 'City of Portsmouth (B)'              then 0.0001
       when 'Isles of Scilly'                     then 0.0001
       when 'Redcar and Cleveland (B)'            then 0.0001
       when 'Perth and Kinross'                   then 0.0001
       when 'Sefton District (B)'                 then 0.0002
       when 'Sunderland District (B)'             then 0.0002
       when 'Bournemouth, Christchurch and Poole' then 0.0006
       else                                        0.001 end)
  from osboundaryline.district_borough_unitary
 where area_description in ('Unitary Authority', 'Metropolitan District');

-- Fill with County
insert dev_combined_county_unitary (fid, name, area_description, geometry)
select fid, name, area_description,
       /* Maximal tolerances obtained by trial-and-error that maintain geometry validity. */
       st_simplify(geometry,
       case name
       when 'Devon County'           then 0.000007
       when 'Suffolk County'         then 0.00004
       when 'North Yorkshire County' then 0.00005
       when 'Kent County'            then 0.00008
       else                               0.0001 end)
  from osboundaryline.county;

-- Colorize
update dev_combined_county_unitary
   set color =
       case area_description
       when 'Unitary Authority' then '#f06'
       when 'Metropolitan District' then '#444'
       else '#3cc' end;

-- Check validity
/*
select count(*)
  from dev_combined_county_unitary
 where not st_isvalid(geometry);

select fid, name
  from dev_combined_county_unitary
 where not st_isvalid(geometry);
*/

/* In MySQL 8 it may be necessary to convert back to SRID=0 from 4326 as not all st_* functions work with geographical data yet.

-- How to convert from 4326 to SRID=0
set @wkt := 'Point(50 100)';
select st_astext(st_geomfromtext(@wkt, 4326));
select st_asgeojson(st_geomfromtext(@wkt, 4326));
-- Read from the geojson as SRID=0
select st_asgeojson(st_geomfromgeojson(st_asgeojson(st_geomfromtext(@wkt, 4326)), 2, 0));
*/


-- Generic geometry table viewer
/*
drop view routing211201.view_geometry_table;
create or replace view routing211201.view_geometry_table as
select id, fid, name, area_description description, color, 5 weight, 0.2 fillOpacity, geometry
  from dev_combined_county_unitary;
*/
