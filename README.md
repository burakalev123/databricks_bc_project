# Databricks Lakeflow Medallion Project

A from-scratch sales learning project for **Lakeflow Spark Declarative Pipelines**, following **Medallion Architecture**, with pipeline transformations written in **SQL**.

## Status

The SQL pipeline, development bundle, synthetic sales data, and local logic tests are implemented. The pipeline defines 4 Bronze streaming tables, 4 Silver business materialized views, 1 Silver integrity-check materialized view, and 4 Gold materialized views. Local tests pass; deployment and execution in Databricks are not yet verified.

## Data flow

```text
Source data → Bronze → Silver → Gold
             Raw      Clean     Business-ready
```

- **Bronze:** ingest source records with minimal transformation and ingestion metadata.
- **Silver:** apply data types, cleansing, quality rules, and deduplication appropriate to the source.
- **Gold:** build business-facing facts, dimensions, and aggregates appropriate to the chosen scenario.

Pipeline datasets will declare their dependencies; Lakeflow will manage their execution order.

## Structure

```text
src/pipelines/bronze/   Bronze dataset definitions
src/pipelines/silver/   Silver dataset definitions
src/pipelines/gold/     Gold dataset definitions
databricks.yml         Bundle variables and development target
resources/             Sales LDP deployment definition
data/sample/           Synthetic sales CSV files
scripts/               Sample data generator
tests/                 Local SQL logic and data quality tests
docs/architecture.md   Architecture and open decisions
docs/run_pipeline.md   Setup, upload, deploy, and run instructions
```

## Run the pipeline

The catalog defaults to `ldp_example`, with `10_bronze`, `20_silver`, and `30_gold` schemas. Follow [the setup and deployment guide](docs/run_pipeline.md) to create the schemas, configure a source Volume, and upload the four CSVs. Once authenticated and configured:

```bash
databricks bundle validate -t dev
databricks bundle deploy -t dev
databricks bundle run -t dev --validate-only sales_pipeline
databricks bundle run -t dev sales_pipeline
```

The guide also covers creating the pipeline directly from a Databricks Git folder. For local checks:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
```

The previous notebook-based Job example has been replaced by declarative dataset definitions. Lakeflow derives execution order from table references. Each layer writes to its own schema in `ldp_example`; existing `bronze_`, `silver_`, and `gold_` table prefixes are retained. All dataset definitions and reads use fully qualified names.

## Sample data

| File | Records | Grain |
| --- | ---: | --- |
| `data/sample/customers.csv` | 100 | One customer |
| `data/sample/products.csv` | 25 | One product |
| `data/sample/orders.csv` | 1,000 | One order |
| `data/sample/order_items.csv` | 2,561 | One order line |

All records are fictional. Orders cover January–June 2026, amounts are EUR, and timestamps are UTC. The initial dataset has valid keys and no deliberately injected quality errors.

To regenerate the same files locally with Python 3 (standard library only):

```bash
python3 scripts/generate_sales_data.py
```

This overwrites the four sample CSVs deterministically. Python is only a data-generation helper; the pipeline will use SQL.

## References

- [Lakeflow Spark Declarative Pipelines](https://docs.databricks.com/aws/en/ldp/)
- [Medallion Architecture](https://docs.databricks.com/aws/en/lakehouse/medallion)
