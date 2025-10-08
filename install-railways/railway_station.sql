-- Prepaare for new table
drop table if exists stations;

-- Initial table
create table stations (
name varchar(255) null,
numeric_code varchar(255) null,
letter_code varchar(255) null,
region varchar(255) null,
la_d_u varchar(255) null,
la_c_u varchar(255) null,
mystery varchar(255) null,
constituency varchar(255) null,
itl_region varchar(255) null,
itl_region_code varchar(255) null,
easting varchar(255) null,
northing varchar(255) null,
station_owner varchar(255) null,
station_group varchar(255) null,
london_travelcard_area varchar(255) null,
network_rail_region varchar(255) null,
community_rail_designation varchar(255) null
) comment="Office of Rail and Road station attributes";


-- End of file
