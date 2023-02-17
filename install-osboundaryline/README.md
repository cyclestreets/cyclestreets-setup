# OS Boundary Line

```shell
# user@machine$
sudo /opt/cyclestreets-setup/install-osboundaryline/run.sh
```

https://osdatahub.os.uk/downloads/open/BoundaryLine

This utility fetches the Boundary Line product from Ordnance survey and installs it into a MySQL database called `osboundaryline`.

There is additional processing to get it to work properly with MySQL 8 spatial geometries using SRID 0.
This is unfortunately necessary as not all MySQL `ST_*()` functions yet work with geographic SRS such as `SRID 4326` (WGS84).
E.g. https://dev.mysql.com/doc/refman/8.0/en/spatial-operator-functions.html has `ST_Intersection()` working from MySQL 8.0.27, and `ST_Difference()` from MySQL 8.0.26. There's no obvious clear list of what's in and what's not.

Centroid coordinates for each geometry are also added, which are used in the boundaries model.

The script takes about 2 hours to run.


## Install Notes

The script was successfully run on [:] 17 Feb 2023 on fortinbras at 22.04.1 LTS, MySQL Server version: 8.0.32-0ubuntu0.22.04.2 (Ubuntu).
