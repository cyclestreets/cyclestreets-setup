CREATE DATABASE IF NOT EXISTS osboundaryline;

/*

Without the following work around the script creates geometries with SRID=1.
The work around pre-creates the spatial_ref_sys table with entry 0, which is then used as the default.

See:
https://gis.stackexchange.com/a/236732/23695
https://gdal.org/drivers/vector/mysql.html (and search for SRID)

When moving to MySQL 8.0 this workaround will need reviewing as SRIDs are better respected in that version.

*/

drop table if exists `osboundaryline`.`spatial_ref_sys`;
CREATE TABLE if not exists `osboundaryline`.`spatial_ref_sys` (
     `SRID` int(11) NOT NULL primary key,
     `AUTH_NAME` varchar(256) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
     `AUTH_SRID` int(11) DEFAULT NULL,
     `SRTEXT` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=MyIsam DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci comment = "Pre-created for SRID work-around";


-- Pre create this entry having SRID=0, the primary key stops duplicates from being created by the ogr2ogr call.
insert ignore osboundaryline.spatial_ref_sys
values (0, null, null, 'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]');


-- Permit the website to view the database
grant select, insert, update, delete, create, execute on osboundaryline.* to 'website'@'localhost';

-- Boundary-line data contains some large geometries such as Shetland in a verbose WKT format.
-- They can be accommodated by setting this dynamically scoped variable to the maximum 1G.
set global max_allowed_packet := 1024 * 1024 * 1024;
