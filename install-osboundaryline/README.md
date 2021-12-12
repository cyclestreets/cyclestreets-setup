# OS Boundary Line

```shell
# user@machine$
sudo /opt/cyclestreets-setup/install-osboundaryline/run.sh
```

https://osdatahub.os.uk/downloads/open/BoundaryLine

This utility fetches the Boundary Line product from Ordnance survey and installs it into a MySQL database called `osboundaryline`.

There is additional processing to get it to work properly with MySQL 8 spatial geometries.

Centroid coordinates for each geometry are also added, which are used in the boundaries model.

The script takes about 2 hours to run.
