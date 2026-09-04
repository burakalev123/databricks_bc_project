# Architecture

This project uses a deliberately small medallion architecture so that each layer has one clear responsibility.

```text
Inline learning data
        |
        v
 Bronze: bronze_customers
 Raw records and ingestion metadata
        |
        v
 Silver: silver_customers
 Standardized and deduplicated customer data
        |
        v
 Gold: gold_customer_summary
 Business-facing customer counts by country
        |
        v
 Automated data quality checks
```

## Layers

### Bronze

The Bronze notebook creates the raw Delta table and preserves source-like values together with ingestion metadata. Inline sample records make the first version easy to run without external storage.

### Silver

The Silver notebook trims and standardizes values, removes unusable records, and deduplicates customers by email.

### Gold

The Gold notebook creates a compact country-level summary suitable for reporting or dashboard experiments.

## Orchestration and governance

A Databricks Workflow runs the notebooks in layer order and finishes with quality checks. Catalog and schema are deployment variables, making it possible to use separate governed locations for development and production.

## Future iterations

Possible next steps include Auto Loader, Unity Catalog volumes, schema expectations, incremental processing, CI validation, and environment-specific deployment.
