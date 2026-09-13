# Databricks Lakeflow Medallion Project

A from-scratch sales learning project for **Lakeflow Spark Declarative Pipelines**, following **Medallion Architecture**, with pipeline transformations written in **SQL**.

## Status

The folder structure and synthetic sales source data are ready. Pipeline SQL, deployment configuration, and runtime tests will be added step by step. Nothing has been deployed or run in Databricks.

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
resources/             Future pipeline deployment resources
data/sample/           Synthetic sales CSV files
scripts/               Sample data generator
tests/                 Future validation checks
docs/architecture.md   Architecture and open decisions
```

## Next steps

1. Review the [sales dataset and source schemas](docs/data_dictionary.md).
2. Select the Databricks catalog, schemas, and source volume.
3. Implement and validate Bronze ingestion.
4. Add Silver transformations and quality expectations.
5. Add Gold outputs and validate business results.
6. Configure deployment and run the pipeline in Databricks.

There are no runnable deployment commands yet. The previous notebook example has been removed from the working tree; Git history is unchanged.

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
