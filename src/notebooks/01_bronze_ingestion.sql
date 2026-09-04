-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Bronze ingestion
-- MAGIC Creates a small raw customer table for this learning project.
-- MAGIC The inline records keep the example self-contained; a later iteration can replace
-- MAGIC them with Auto Loader or a governed Unity Catalog volume.

-- COMMAND ----------

CREATE WIDGET TEXT catalog DEFAULT "workspace";
CREATE WIDGET TEXT schema DEFAULT "databricks_bc_project";

USE CATALOG IDENTIFIER(:catalog);
CREATE SCHEMA IF NOT EXISTS IDENTIFIER(:schema);
USE SCHEMA IDENTIFIER(:schema);

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_customers (
  customer_id BIGINT,
  full_name STRING,
  email STRING,
  country STRING,
  signup_date DATE,
  ingested_at TIMESTAMP
)
USING DELTA;

INSERT OVERWRITE bronze_customers
SELECT
  customer_id,
  full_name,
  email,
  country,
  signup_date,
  current_timestamp() AS ingested_at
FROM VALUES
  (1, 'Ada Lovelace', 'ada@example.com', 'UK', DATE'2026-01-10'),
  (2, 'Grace Hopper', 'grace@example.com', 'US', DATE'2026-01-12'),
  (3, 'Edsger Dijkstra', 'edsger@example.com', 'NL', DATE'2026-01-15'),
  (4, 'Duplicate Example', 'grace@example.com', 'US', DATE'2026-01-18')
AS source(customer_id, full_name, email, country, signup_date);