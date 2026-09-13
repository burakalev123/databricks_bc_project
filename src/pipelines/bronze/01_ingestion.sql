-- Immutable CSV files arrive in separate source directories per entity.
-- Keep business fields as strings; Silver owns typing and business validation.
CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_customers
COMMENT 'Raw customer records and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  customer_id, customer_name, email, country_code, city, created_at,
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  '${sales.source_path}/customers',
  format => 'csv',
  header => true,
  schema => 'customer_id STRING, customer_name STRING, email STRING, country_code STRING, city STRING, created_at STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);

CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_products
COMMENT 'Raw product records and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  product_id, product_name, category, list_price, currency,
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  '${sales.source_path}/products',
  format => 'csv',
  header => true,
  schema => 'product_id STRING, product_name STRING, category STRING, list_price STRING, currency STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);

CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_orders
COMMENT 'Raw order headers and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  order_id, customer_id, order_timestamp, order_status, sales_channel, currency,
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  '${sales.source_path}/orders',
  format => 'csv',
  header => true,
  schema => 'order_id STRING, customer_id STRING, order_timestamp STRING, order_status STRING, sales_channel STRING, currency STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);

CREATE OR REFRESH STREAMING TABLE `${sales.catalog}`.`${sales.bronze_schema}`.bronze_order_items
COMMENT 'Raw order lines and ingestion metadata'
TBLPROPERTIES ('quality' = 'bronze')
AS SELECT
  order_id, line_number, product_id, quantity, unit_price, discount_pct,
  _rescued_data,
  _metadata.file_path AS source_file,
  current_timestamp() AS ingested_at
FROM STREAM read_files(
  '${sales.source_path}/order_items',
  format => 'csv',
  header => true,
  schema => 'order_id STRING, line_number STRING, product_id STRING, quantity STRING, unit_price STRING, discount_pct STRING',
  schemaEvolutionMode => 'rescue',
  rescuedDataColumn => '_rescued_data'
);
