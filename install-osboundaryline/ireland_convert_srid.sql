/**

The queries in this file are based on: convert_srid.sql

The main difference is that this works with primary key 'id' rather than 'fid'.

*/


-- Boundary-line data contains some large geometries such as Shetland in a verbose WKT format.
-- They can be accommodated by setting this dynamically scoped variable to the maximum 1G.
set global max_allowed_packet := 1024 * 1024 * 1024;


-- Table used to convert the geometries
drop table if exists dev_geom_fixer;
create table dev_geom_fixer (
      id int      not null auto_increment primary key,
geometry geometry not null srid 0
) engine myisam comment "Temporary table for converting geometries";



-- Reset
truncate dev_geom_fixer;

-- Copy id and converted geometry to fixer table
insert dev_geom_fixer
select id, st_geomfromgeojson(st_asgeojson(geometry), 2, 0)
  from ireland_counties;

-- Remove and re-create the geometry field, defaulting to null
alter table ireland_counties drop geometry;
alter table ireland_counties  add geometry geometry null after id;

-- Copy the converted geometry into the original table ot from the fixer table ft
update ireland_counties ot
  join dev_geom_fixer ft on ft.id = ot.id
   set ot.geometry = ft.geometry;

-- Set the correct geometry format and apply the index
alter table ireland_counties change geometry geometry geometry not null srid 0,  add spatial key `geometry` (`geometry`);


-- Finally
drop table dev_geom_fixer;


-- End of file
