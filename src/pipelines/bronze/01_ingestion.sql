-- BRONZE LAYER: RAW DATA INGESTION FROM CSV FILES
-- This file defines four streaming tables in a Lakeflow Declarative Pipeline.
-- The goal is to retain source records with minimal transformation and track their source files.
-- Silver handles cleansing, type conversion, duplicate records, and business rules.
-- Each entity is read from its own directory because the CSV column layouts differ.
--
-- WHERE DO THE SETTINGS COME FROM?
-- ${sales.*} values are substituted into SQL from the pipeline's Configuration settings.
-- resources/sales.pipeline.yml maps these settings to variables in databricks.yml.
-- Current values:
--   sales.catalog       = ldp_example
--   sales.bronze_schema = 10_bronze
--   sales.source_path   = /Volumes/ldp_example/10_bronze/sales_source
-- Backticks (`) delimit catalog and schema names as SQL identifiers.
-- Fully qualified table names determine the destination catalog and schema.
--
-- EXECUTION AND REFRESH BEHAVIOR
-- CREATE OR REFRESH declares a pipeline dataset; it does not delete the table on every run.
-- STREAM read_files uses Auto Loader to ingest files incrementally.
-- Lakeflow manages checkpoints and tracks processed files. A normal refresh ingests
-- new files instead of reloading files that have already been processed.
-- The initial load also processes files already present in the source directories.
-- Keep uploaded files immutable; deliver additional data in new files.
-- If the same record arrives in another file, Bronze can contain it more than once:
-- file tracking does not enforce business key uniqueness or implement CDC.
-- A full refresh can reread the retained source files to rebuild the datasets.
-- These four tables are independent; their order in this file is not a Job task sequence.

-- 1. CUSTOMERS: Source customer records.
-- Expected source: .../sales_source/customers/customers.csv (and future files).
-- Fields such as customer_id and email are not cleaned or deduplicated here.
CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_customers
-- COMMENT stores a persistent table description that can be viewed in Catalog Explorer.
COMMENT 'Raw customer records and ingestion metadata'
-- The quality property labels the layer; it does not enforce data quality checks by itself.
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  -- Select source columns without transformation; all are read as STRING, including created_at.
  customer_id, customer_name, email, country_code, city, created_at,
  -- Carries data the reader could not match to the schema; NULL when no data was rescued.
  -- Silver checks this column to surface schema mismatches.
  _rescued_data,
  -- Preserve the file path for each row to support troubleshooting and source tracing.
  _metadata.file_path AS source_file,
  -- Time the pipeline processes the row, rather than the customer's creation time.
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  -- Read a directory so additional files can arrive under the same source path.
  '${sales.source_path}/customers',
  format => 'csv',
  -- Treat the first CSV row as column headers rather than a data record.
  header => true,
  -- An explicit schema prevents column types from changing through automatic inference.
  -- STRING preserves source values; Silver validates dates and numeric values.
  -- For example, an invalid date still fits STRING and may not appear in _rescued_data.
  schema => 'customer_id STRING, customer_name STRING, email STRING, country_code STRING, city STRING, created_at STRING',
  -- Rescue unexpected or incompatible fields instead of automatically expanding the schema.
  -- This option does not guarantee detection of every malformed CSV or business rule violation.
  schemaEvolutionMode => 'rescue',
  -- Explicitly name the column that stores rescued data.
  rescuedDataColumn => '_rescued_data'
);

-- 2. PRODUCTS: Product catalog records.
-- list_price is the source catalog price, retained as STRING in Bronze.
-- Silver converts it to DECIMAL. Gold calculates sales using order_items.unit_price
-- so catalog price changes do not determine historical transaction amounts.
CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_products
COMMENT 'Raw product records and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  product_id, product_name, category, list_price, currency,
  -- Use the same source tracking as customers: rescued data, file path, and ingestion time.
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  -- This directory should contain only CSV files that use the products schema.
  '${sales.source_path}/products',
  format => 'csv',
  header => true,
  schema => 'product_id STRING, product_name STRING, category STRING, list_price STRING, currency STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);

-- 3. ORDERS: Order headers; each source record represents one order.
-- customer_id links to customers; Bronze does not validate that relationship.
-- Retain every status here, including COMPLETED, CANCELLED, and PENDING.
-- Gold includes only COMPLETED orders when calculating sales revenue.
CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_orders
COMMENT 'Raw order headers and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  -- order_timestamp is the event time; ingested_at below is the ingestion time.
  order_id, customer_id, order_timestamp, order_status, sales_channel, currency,
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  -- Read order headers separately from order lines.
  '${sales.source_path}/orders',
  format => 'csv',
  header => true,
  schema => 'order_id STRING, customer_id STRING, order_timestamp STRING, order_status STRING, sales_channel STRING, currency STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);

-- 4. ORDER ITEMS: Product details per order line; one order can contain multiple lines.
-- The expected business key is (order_id, line_number); this file does not enforce it.
-- product_id links to products and order_id links to order headers. Uniqueness and
-- referential integrity checks are defined in the Silver file 03_integrity.sql.
-- quantity, unit_price, and discount_pct are retained as raw STRING values here.
-- discount_pct uses percentage points: 10 means a 10% discount. Bronze calculates no amounts.
CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_order_items
COMMENT 'Raw order lines and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  order_id, line_number, product_id, quantity, unit_price, discount_pct,
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  -- Example source: .../sales_source/order_items/order_items.csv.
  '${sales.source_path}/order_items',
  format => 'csv',
  header => true,
  schema => 'order_id STRING, line_number STRING, product_id STRING, quantity STRING, unit_price STRING, discount_pct STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);
