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
       /* Tolerances obtained by trial-and-error that maintain geometry validity. */
       st_simplify(geometry,
       case name
       when 'Angus'            then 0.001
       when 'Aberdeenshire'    then 0.00002
       when 'Isles of Scilly'  then 0.0001
       when 'Shetland Islands' then 0.000007
       when 'Highland'         then 0.000007
       else                         0.00001 end)
  from osboundaryline.district_borough_unitary
 where area_description = 'Unitary Authority';

-- Fill with County
insert dev_combined_county_unitary (fid, name, area_description, geometry)
select fid, name, area_description,
       /* Tolerances obtained by trial-and-error that maintain geometry validity. */
       st_simplify(geometry,
       case name
       when 'Devon County' then 0.000007
       else                     0.00001 end)
  from osboundaryline.county;

-- Check validity
select count(*)
  from dev_combined_county_unitary
 where not st_isvalid(geometry);

select fid, name
  from dev_combined_county_unitary
 where not st_isvalid(geometry);

-- Generic geometry table viewer
drop view view_geometry_table;
create or replace view view_geometry_table as
select fid id, name, area_description description, geometry
  from dev_combined_county_unitary;
