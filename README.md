# databricks_bc_project

A small, hands-on Databricks learning and portfolio project built from a Data Architect's perspective.

## Overview

This repository demonstrates a compact end-to-end data pipeline using native Databricks SQL notebooks, Delta tables, a Bronze/Silver/Gold architecture, Databricks Workflows, Unity Catalog-ready configuration, automated quality checks, Git, and bundle-based deployment.

The project intentionally stays small and understandable. It is a learning lab rather than a production framework, but its structure follows practices that can grow into a larger solution.

## Architecture

```text
Sample customer records
        |
        v
Bronze: raw Delta table
        |
        v
Silver: standardized and deduplicated customers
        |
        v
Gold: customer summary by country
        |
        v
Automated data quality checks
```

More detail is available in [docs/architecture.md](docs/architecture.md).

## Repository structure

```text
.
├── databricks.yml
├── resources/
│   └── databricks_job.yml
├── src/
│   └── notebooks/
│       ├── 01_bronze_ingestion.sql
│       ├── 02_silver_transformation.sql
│       └── 03_gold_customer_summary.sql
├── tests/
│   └── test_customer_quality.py
├── docs/
│   └── architecture.md
├── .editorconfig
└── .gitignore
```

## What the pipeline does

1. Creates a Bronze Delta table with a small inline customer dataset.
2. Standardizes values and deduplicates customers in the Silver layer.
3. Builds a country-level customer summary in the Gold layer.
4. Runs automated checks for nulls, duplicate emails, empty outputs, and invalid counts.

The inline dataset keeps the first version self-contained. It can later be replaced with Auto Loader, files in a Unity Catalog volume, or another source.

## Prerequisites

- Access to a Databricks workspace
- A Unity Catalog catalog where you can create a schema and tables
- Databricks CLI configured for the workspace
- An existing Databricks cluster

The SQL notebooks use named parameter markers for widgets, which require Databricks Runtime 15.2 or later.

## Validate and run

From the repository root, replace the placeholders with values from your workspace:

```bash
databricks bundle validate --var="cluster_id=<cluster-id>,catalog=<catalog>,schema=<schema>"
databricks bundle deploy --var="cluster_id=<cluster-id>,catalog=<catalog>,schema=<schema>"
databricks bundle run customer_pipeline --var="cluster_id=<cluster-id>,catalog=<catalog>,schema=<schema>"
```

The default target is `dev`. Use `-t prod` only when you intentionally want to exercise the production-mode configuration.

## Learning roadmap

Future iterations may add:

- File ingestion with Auto Loader and Unity Catalog volumes
- Incremental processing and idempotent merge patterns
- Stronger schema and data quality expectations
- CI checks for bundle validation and tests
- Separate development and production identities
- Dashboards or downstream consumption examples

## Project status

The initial project skeleton and a runnable learning pipeline are in place. The repository will evolve as new Databricks concepts are explored.

## Disclaimer

This is a personal learning and portfolio repository, not a production system.
