-- Prepare for main table
drop table if exists new_poi_railwaystations;

-- Main table
create table `new_poi_railwaystations` (
     `id`       char(3)      not null comment 'station code',
     `lonLat`   point        not null /*!80003 srid 0 */ comment 'Spatial longitude/latitude',
     `name`     varchar(255) not null comment 'Name',
     `postcode` varchar(8)   not null comment 'Postcode',
     `website`  varchar(255) not null comment 'Website URL',
     `notes`    varchar(255) default null comment 'Notes',
     primary key (`id`),
     spatial key `lonLat` (`lonLat`),
     fulltext key `name` (`name`)
) comment 'Railway stations updated from ORR';


-- Fill from dev_rail
insert new_poi_railwaystations (id, lonLat, name, postcode, website)
select letter_code, easting_northing_to_wgs84_point(easting, northing), name, '', ''
  from stations;

-- Website field
update new_poi_railwaystations
   set website = concat('http://www.nationalrail.co.uk/stations/', lower(id), '/details.html');

-- Move old one out
drop table if exists old_poi_railwaystations;
rename table map_poi_railwaystations to old_poi_railwaystations;

-- Move new one in
rename table new_poi_railwaystations to map_poi_railwaystations;

-- Remove the workning table
drop table if exists stations;

-- End of file
