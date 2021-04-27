-- This script creates a table containing the Highway Authorities
-- these are either 'Unitary Authority' or 'County'.

-- Load using
-- mysql osboundaryline < /opt/cyclestreets-setup/install-osboundaryline/highwayAuthorities.sql

-- Combine County and 'Unitary Authority'
drop table if exists dev_combined_county_unitary;
create table dev_combined_county_unitary like osboundaryline.district_borough_unitary;

alter table dev_combined_county_unitary
 change fid fid int not null,
  add id int unsigned not null auto_increment primary key first,
  change area_description area_description enum('Unitary Authority','County', 'Greater London Authority'),
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
 drop longitude,
 drop latitude,
 drop key `fid`;

-- Check
-- show create table dev_combined_county_unitary\G

-- Reset
truncate dev_combined_county_unitary;

-- Fill with 'Unitary Authority'
insert dev_combined_county_unitary (fid, name, area_description, geometry)
select fid, name, area_description,
       /* Maximal tolerances obtained by trial-and-error that maintain geometry validity. */
       st_simplify(geometry,
       case name
       when 'Shetland Islands'                    then 0.000007
       when 'Highland'                            then 0.000007
       when 'Aberdeen City'                       then 0.00009
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
       when 'Gwynedd - Gwynedd'                   then 0.00003
       when 'Falkirk'                             then 0.00003
       when 'South Ayrshire'                      then 0.00005
       when 'City of Edinburgh'                   then 0.00005
       when 'Sir y Fflint - Flintshire'           then 0.00005
       when 'Isle of Wight'                       then 0.00007
       when 'South Gloucestershire'               then 0.0007
       when 'Sir Fynwy - Monmouthshire'           then 0.0001
       when 'Dumfries and Galloway'               then 0.0001
       when 'East Lothian'                        then 0.0001
       when 'City of Portsmouth (B)'              then 0.0001
       when 'Isles of Scilly'                     then 0.0001
       when 'Redcar and Cleveland (B)'            then 0.0001
       when 'Perth and Kinross'                   then 0.0001
       when 'Northumberland'                      then 0.0001
       when 'Bournemouth, Christchurch and Poole' then 0.0006
       else                                        0.001 end)
  from osboundaryline.district_borough_unitary
 where area_description = 'Unitary Authority';

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

-- Check validity
/*
select count(*)
  from dev_combined_county_unitary
 where not st_isvalid(geometry);

select fid, name
  from dev_combined_county_unitary
 where not st_isvalid(geometry);
*/
-- Generic geometry table viewer
/*
drop view view_geometry_table;
create or replace view view_geometry_table as
select fid id, name, area_description description, geometry
  from dev_combined_county_unitary;
*/
