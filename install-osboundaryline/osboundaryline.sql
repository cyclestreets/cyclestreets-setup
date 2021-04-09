CREATE DATABASE IF NOT EXISTS osboundaryline;

/*

Without the following work around the script creates geometries with SRID=1.
The work around pre-creates the spatial_ref_sys table with entry 0, which is then used as the default.

See:
https://gis.stackexchange.com/a/236732/23695
https://gdal.org/drivers/vector/mysql.html (and search for SRID)

*/

CREATE TABLE if not exists`osboundaryline`.`spatial_ref_sys` (
     `SRID` int(11) NOT NULL,
     `AUTH_NAME` varchar(256) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
     `AUTH_SRID` int(11) DEFAULT NULL,
     `SRTEXT` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=MyIsam DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

insert ignore osboundaryline.spatial_ref_sys
values (0, null, null, 'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]');
