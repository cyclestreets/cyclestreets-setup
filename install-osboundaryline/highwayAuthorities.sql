/* This script creates a table containing the Highway Authorities.
   These are comprised of:

     - All rows from the county table
     - Rows from the district_borough_unitary where area_description is 'Unitary Authority' or 'Metropolitan District'

   Together their geometries should cover the whole of Great Britain.

   The Boundary Line data is described at:
   https://www.ordnancesurvey.co.uk/business-government/tools-support/boundaryline-support

   This file works in MySQL 8 as it derives the geometry field from a table that is setup as SRID 0 restricted.
*/

-- Load using
-- mysql osboundaryline < /opt/cyclestreets-setup/install-osboundaryline/highwayAuthorities.sql

-- Combine County and 'Unitary Authority'
-- Use the prefix cs_ to indicate that this is a CycleStreets generated table.
drop table if exists cs_highway_authority;
create table cs_highway_authority like district_borough_unitary;

alter table cs_highway_authority
 drop fid,
  add id int unsigned not null auto_increment primary key comment 'A global polygon id from the Ordnance Survey boundary database' first,
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
 drop latitude;

-- Comment
alter table cs_highway_authority
 comment 'CycleStreets highway authorities using geometries simplified by up to one thousandth of a degree, approximately 100 metres';


-- Check
-- show create table cs_highway_authority\G

-- Reset
truncate cs_highway_authority;

-- Fill with 'Unitary Authority'
insert cs_highway_authority (id, name, area_description, geometry)
select global_polygon_id, name, area_description,
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
insert cs_highway_authority (id, name, area_description, geometry)
select global_polygon_id, name, area_description,
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
update cs_highway_authority
   set color =
       case area_description
       when 'Unitary Authority'     then '#f06'	-- Fuschia (bright pink)
       when 'Metropolitan District' then '#444'	-- Dark grey
       else '#3cc'				-- Cyan
       end;

/*
-- Check validity
-- Takes about a minute
select id, name
  from cs_highway_authority
 where not st_isvalid(geometry);
*/

-- Generic geometry table viewer
/*
drop view routing211212.view_geometry_table;
create or replace view routing211212.view_geometry_table as
select id, name, area_description description, color, 5 weight, 0.2 fillOpacity, geometry
  from cs_highway_authority;
*/
