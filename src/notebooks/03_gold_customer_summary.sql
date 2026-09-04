-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Gold customer summary
-- MAGIC Produces a simple business-facing aggregate by country.

-- COMMAND ----------

CREATE WIDGET TEXT catalog DEFAULT "workspace";
CREATE WIDGET TEXT schema DEFAULT "databricks_bc_project";

USE CATALOG IDENTIFIER(:catalog);
USE SCHEMA IDENTIFIER(:schema);

-- COMMAND ----------

CREATE OR REPLACE TABLE gold_customer_summary
USING DELTA
AS
SELECT
  country_code,
  count(*) AS customer_count,
  min(signup_date) AS first_signup_date,
  max(signup_date) AS latest_signup_date,
  current_timestamp() AS refreshed_at
FROM silver_customers
GROUP BY country_code;
