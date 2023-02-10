# IceProd2 resource requirements harvesting

This is a collection of tools for extracting resource usage summaries from the
IceProd2 database.


## REST API (>v2.6)

* `fetch_iceprod_stats.py`: extract stats from production database using the
  REST API. Requires login to IceCube SSO.

### Usage

* Pip install `wipac-rest-tools>=1.4.8`
* Get resource usage: `python fetch_iceprod_stats.py logs resource_usage.iceprod25.v0.hdf5`
* Get configs: `python fetch_iceprod_stats.py configs configs.iceprod25.v0.json`
* Upload to share directory (optional): `./cloudsend.sh resource_usage.iceprod25.v2.hdf5 https://desycloud.desy.de/index.php/s/...`


## REST API (v2.3 < v < v2.6)

These versions of IceProd2 requred a special API token.

* `fetch_iceprod_stats_v2.3.py`: extract stats from production database using the
  REST API. Requires an API token.

### Usage

* Get an API token from https://iceprod2.icecube.wisc.edu/profile and refresh it daily
* Set the API token as an environment variable: `echo ICEPROD_TOKEN=ICEPROD_TOKEN=eyJ0eXAiO...`
* Get resource usage: `python fetch_iceprod_stats_v2.3.py logs resource_usage.iceprod25.v0.hdf5`
* Get configs: `python fetch_iceprod_stats_v2.3.py configs configs.iceprod25.v0.json`
* Upload to share directory (optional): `./cloudsend.sh resource_usage.iceprod25.v2.hdf5 https://desycloud.desy.de/index.php/s/...`

## sqlite dump (<=v2.3)

Older versions of IceProd2 were backed by a relational DB with no outside API
access. This was analyzed by migrating the `sqlite` database into `postgres` and
using its json functions to filter out task resource summaries.

* `schema.postgres.sql`: `postgres`-ified schema from the `sqlite` database
* `migrate.sh`: migrate from `sqlite` to `postgres`
* `queries.sql`: horrible master query

