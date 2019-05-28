# IceProd2 resource requirements harvesting

This is a collection of tools for extracting resource usage summaries from the
IceProd2 database.

## REST API (>v2.3)

* `fetch_iceprod_stats.py`: extract stats from production database using the
  REST API. Requires an API token.

## sqlite dump (<=v2.3)

Older versions of IceProd2 were backed by a relational DB with no outside API
access. This was analyzed by migrating the `sqlite` database into `postgres` and
using its json functions to filter out task resource summaries.

* `schema.postgres.sql`: `postgres`-ified schema from the `sqlite` database
* `migrate.sh`: migrate from `sqlite` to `postgres`
* `queries.sql`: horrible master query

