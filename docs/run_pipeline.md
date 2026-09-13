# Deploy and run the sales LDP

The repository defines the pipeline. A workspace pipeline is created only when you deploy it or create it through the Databricks UI. No workspace deployment has been performed from this repository yet.

## Prerequisites

- A Unity Catalog enabled Databricks workspace with serverless pipelines available.
- A current Databricks CLI supporting pipeline `libraries.glob` and `root_path`.
- An authenticated identity with `USE CATALOG` on `ldp_example`, `USE SCHEMA` on all three layer schemas, and the permissions needed to create pipeline tables/materialized views in those schemas.
- Read access to the input Volume; the identity uploading data also needs write access. Creating the schemas and managed Volume requires the corresponding creation privileges.

This first bundle has one development target, uses serverless compute, and runs in triggered mode. It has no recurring schedule. It uses the Advanced edition for expectations.

## 1. Create input and output locations

The bundle uses the **existing** catalog `ldp_example`. Run this setup SQL in a SQL editor or notebook, outside the pipeline:

```sql
CREATE SCHEMA IF NOT EXISTS `ldp_example`.`10_bronze`;
CREATE SCHEMA IF NOT EXISTS `ldp_example`.`20_silver`;
CREATE SCHEMA IF NOT EXISTS `ldp_example`.`30_gold`;
```

The managed Volume `ldp_example.10_bronze.sales_source` has been created and verified in the workspace. Its path is now the bundle's `source_path` default. The following idempotent statement documents its setup for a fresh environment:

```sql
CREATE VOLUME IF NOT EXISTS `ldp_example`.`10_bronze`.`sales_source`;
```

The Volume stores input files separately from pipeline tables. You can use another existing Volume by overriding `source_path`. The bundle does not create or upload to the Volume automatically. The four CSVs have not yet been uploaded.

## 2. Authenticate and configure the bundle

From the repository root:

```bash
databricks auth login --host https://<your-workspace-host> --profile sales-dev
export DATABRICKS_CONFIG_PROFILE=sales-dev
export BUNDLE_VAR_source_path=/Volumes/ldp_example/10_bronze/sales_source
```

The bundle already supplies these defaults:

| Variable | Default |
| --- | --- |
| `catalog` | `ldp_example` |
| `bronze_schema` | `10_bronze` |
| `silver_schema` | `20_silver` |
| `gold_schema` | `30_gold` |
| `source_path` | `/Volumes/ldp_example/10_bronze/sales_source` |

Override them only when deliberately targeting another location, using the corresponding `BUNDLE_VAR_` environment variable. The former single `schema` variable is no longer used. Reserve these output tables for this pipeline so another deployment does not claim them.

## 3. Upload the initial files

Run this once against a fresh source directory. Each entity needs its own subdirectory because the CSV schemas differ:

```bash
set -e
for entity in customers products orders order_items; do
  databricks fs mkdir "dbfs:${BUNDLE_VAR_source_path}/${entity}"
  databricks fs cp "data/sample/${entity}.csv" \
    "dbfs:${BUNDLE_VAR_source_path}/${entity}/initial.csv"
done
```

The CLI uses the `dbfs:/Volumes/...` URI; the pipeline reads the same files through `/Volumes/...`. Do not point Auto Loader at the repository's local `data/sample` directory. Bundle deployment syncs code to the workspace, not input CSVs to a Volume.

## 4. Validate, deploy, and run

```bash
databricks bundle validate -t dev
databricks bundle deploy -t dev
databricks bundle run -t dev --validate-only sales_pipeline
databricks bundle run -t dev sales_pipeline
```

`bundle validate` checks bundle configuration. The deployed pipeline's `--validate-only` run checks the graph in Databricks; the final command processes data. Actual execution is required to verify file access and resulting data. The resource key is `sales_pipeline`; development mode adds a user prefix to its displayed name.

After a successful update, run [validation.sql](validation.sql) in the SQL editor. It uses fully qualified names across `ldp_example.10_bronze`, `ldp_example.20_silver`, and `ldp_example.30_gold`; update those names only if you overrode the defaults. With the initial fixtures, expect **812 completed orders** and **EUR 181,328.13** in net sales. There are 13 published datasets: 4 Bronze, 5 Silver (including integrity checks), and 4 Gold.

## Alternative: create the pipeline from a Databricks Git folder

If you work directly in Databricks, pull this repository into a Git folder and create an ETL pipeline with SQL source files:

- `src/pipelines/bronze/01_ingestion.sql`
- `src/pipelines/silver/02_cleaning.sql`
- `src/pipelines/silver/03_integrity.sql`
- `src/pipelines/gold/04_sales.sql`

Select default catalog `ldp_example` and default schema `10_bronze`, serverless compute, and triggered mode. SQL definitions explicitly route each layer to the proper schema. In the pipeline's **Configuration** field, set:

| Key | Value |
| --- | --- |
| `sales.catalog` | `ldp_example` |
| `sales.bronze_schema` | `10_bronze` |
| `sales.silver_schema` | `20_silver` |
| `sales.gold_schema` | `30_gold` |
| `sales.source_path` | Your source Volume directory, e.g. `/Volumes/ldp_example/10_bronze/sales_source` |
| `spark.sql.session.timeZone` | `UTC` |

Use Configuration with the existing `${sales.*}` SQL syntax; this example does not require the newer beta Parameters feature. Upload the data first, then validate and run the pipeline. Choose either this manual route or bundle deployment to avoid two pipelines owning the same output tables.

## Refresh behavior

- Bronze uses Auto Loader checkpoints managed by Lakeflow. Normal refreshes discover new files; they do not reload previously processed files.
- Source files are immutable. For this initial example, do not overwrite `initial.csv` after ingestion. A normal refresh will not apply edits to a previously processed file.
- New files can add new keys or repeat identical records. Silver removes identical normalized rows. Different records with the same key are rejected by integrity checks; this example does not implement CDC or “latest record wins.”
- Upload a complete, consistent batch before starting an update. Orders with missing customers, products, or lines cause integrity checks to fail.
- A full refresh rebuilds Bronze and downstream datasets from the retained source files. Keep those files available and use full refresh intentionally when resetting the learning dataset.
- Expectations fail the affected flow. A failed pipeline update is not an atomic rollback across every table; other flows may have updated. Use outputs only after the complete pipeline update succeeds, then review integrity checks.

## Local validation

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
```

The tests execute the checked-in Silver and Gold SELECT queries after SQLGlot translation to DuckDB, evaluate quality predicates separately, and compare every completed line amount with an independent Decimal calculation. They cover duplicates, invalid values, orphan references, transaction versus catalog prices, and half-cent rounding.

These tests do not validate Databricks DDL, Auto Loader, streaming checkpoints, Unity Catalog permissions, expectation transaction behavior, or the Databricks optimizer. Bundle validation and a real Databricks update are still required.

## Official references

- [SQL pipeline development](https://docs.databricks.com/aws/en/ldp/developer/sql-dev)
- [Bundle pipeline configuration](https://docs.databricks.com/aws/en/dev-tools/bundles/workspace-author)
- [Configuration values in SQL](https://docs.databricks.com/aws/en/ldp/parameters#reference-parameters-using-the-configuration-field)
- [Publishing pipeline datasets across catalogs and schemas](https://docs.databricks.com/aws/en/ldp/target-schema)
- [Pipeline expectations](https://docs.databricks.com/aws/en/ldp/expectations)
- [Bundle validation and execution commands](https://docs.databricks.com/aws/en/dev-tools/cli/bundle-commands)
