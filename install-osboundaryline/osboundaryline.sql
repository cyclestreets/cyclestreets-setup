CREATE DATABASE IF NOT EXISTS osboundaryline;

-- Permit the website to view the database
grant select, insert, update, delete, create, execute on osboundaryline.* to 'website'@'localhost';

-- Boundary-line data contains some large geometries such as Shetland in a verbose WKT format.
-- They can be accommodated by setting this dynamically scoped variable to the maximum 1G.
set global max_allowed_packet := 1024 * 1024 * 1024;
