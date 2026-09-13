# Architecture

## Confirmed scope

- Platform: Databricks.
- Processing framework: Lakeflow Spark Declarative Pipelines.
- Architecture: Bronze → Silver → Gold.
- Approach: start from scratch and build the example step by step.
- Implementation language: SQL.
- Scenario: synthetic retail sales with customers, products, orders, and order lines.

## Layer responsibilities

| Layer | Responsibility | Output |
| --- | --- | --- |
| Bronze | Preserve source records with ingestion metadata | Raw datasets |
| Silver | Clean, type, validate, and deduplicate according to source semantics | Trusted datasets |
| Gold | Apply business logic and analytical modeling | Facts, dimensions, and aggregates as needed |

The folders represent logical layers. Catalogs, schemas, dataset names, and pipeline boundaries will be selected when the source and workspace requirements are known.

Dataset references will express dependencies in the declarative pipeline. Streaming tables and materialized views will be chosen based on source update behavior and transformation requirements.

## Decisions still open

- Batch or streaming ingestion and source update semantics.
- Unity Catalog catalog, schemas, and source storage location.
- Data quality rules, keys, and Gold reporting requirements.
- Compute and deployment configuration.

## Current implementation

The folder structure and synthetic source CSVs are ready. See [data_dictionary.md](data_dictionary.md) for the source contract. There are no active pipeline definitions, deployment resources, or runtime results yet.

The previous notebook-based Job example has been removed from the working tree.
