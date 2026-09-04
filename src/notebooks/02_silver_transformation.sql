-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Silver transformation
-- MAGIC Cleans and standardizes Bronze records, then keeps the latest record per email.

-- COMMAND ----------

CREATE WIDGET TEXT catalog DEFAULT "workspace";
CREATE WIDGET TEXT schema DEFAULT "databricks_bc_project";

USE CATALOG IDENTIFIER(:catalog);
USE SCHEMA IDENTIFIER(:schema);

-- COMMAND ----------

CREATE OR REPLACE TABLE silver_customers
USING DELTA
AS
WITH standardized AS (
  SELECT
    customer_id,
    trim(full_name) AS full_name,
    lower(trim(email)) AS email,
    upper(trim(country)) AS country_code,
    signup_date,
    ingested_at
  FROM bronze_customers
  WHERE customer_id IS NOT NULL
    AND email IS NOT NULL
),
deduplicated AS (
  SELECT *,
    row_number() OVER (
      PARTITION BY email
      ORDER BY signup_date DESC, ingested_at DESC
    ) AS row_number
  FROM standardized
)
SELECT
  customer_id,
  full_name,
  email,
  country_code,
  signup_date,
  ingested_at
FROM deduplicated
WHERE row_number = 1;
