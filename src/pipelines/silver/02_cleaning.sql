-- Materialized views read the full Bronze state, so DISTINCT is global.
-- Remove identical normalized rows only; conflicting keys fail integrity checks.
CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.silver_schema}`.silver_customers (
  CONSTRAINT valid_customer_id EXPECT (customer_id IS NOT NULL AND customer_id <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_customer_name EXPECT (customer_name IS NOT NULL AND customer_name <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_email EXPECT (email IS NOT NULL AND email LIKE '%_@_%._%') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_country EXPECT (country_code IS NOT NULL AND country_code IN ('NL', 'DE', 'BE', 'FR')) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_created_at EXPECT (created_at IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_source_schema EXPECT (_rescued_data IS NULL) ON VIOLATION FAIL UPDATE
)
COMMENT 'Normalized customer snapshot'
TBLPROPERTIES ('quality' = 'silver')
AS SELECT DISTINCT
  trim(customer_id) AS customer_id,
  trim(customer_name) AS customer_name,
  lower(trim(email)) AS email,
  upper(trim(country_code)) AS country_code,
  trim(city) AS city,
  try_cast(created_at AS TIMESTAMP) AS created_at,
  _rescued_data
FROM `${sales.catalog}`.`${sales.bronze_schema}`.bronze_customers;

CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.silver_schema}`.silver_products (
  CONSTRAINT valid_product_id EXPECT (product_id IS NOT NULL AND product_id <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_product_name EXPECT (product_name IS NOT NULL AND product_name <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_category EXPECT (category IS NOT NULL AND category <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_price EXPECT (list_price IS NOT NULL AND list_price > 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_currency EXPECT (currency IS NOT NULL AND currency = 'EUR') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_source_schema EXPECT (_rescued_data IS NULL) ON VIOLATION FAIL UPDATE
)
COMMENT 'Normalized product snapshot with decimal prices'
TBLPROPERTIES ('quality' = 'silver')
AS SELECT DISTINCT
  trim(product_id) AS product_id,
  trim(product_name) AS product_name,
  trim(category) AS category,
  try_cast(list_price AS DECIMAL(10,2)) AS list_price,
  upper(trim(currency)) AS currency,
  _rescued_data
FROM `${sales.catalog}`.`${sales.bronze_schema}`.bronze_products;

CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.silver_schema}`.silver_orders (
  CONSTRAINT valid_order_id EXPECT (order_id IS NOT NULL AND order_id <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_customer_id EXPECT (customer_id IS NOT NULL AND customer_id <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_order_time EXPECT (order_timestamp IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_status EXPECT (order_status IS NOT NULL AND order_status IN ('COMPLETED', 'CANCELLED', 'PENDING')) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_channel EXPECT (sales_channel IS NOT NULL AND sales_channel IN ('WEB', 'MOBILE', 'STORE')) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_currency EXPECT (currency IS NOT NULL AND currency = 'EUR') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_source_schema EXPECT (_rescued_data IS NULL) ON VIOLATION FAIL UPDATE
)
COMMENT 'Typed order snapshot, retaining all order statuses'
TBLPROPERTIES ('quality' = 'silver')
AS SELECT DISTINCT
  trim(order_id) AS order_id,
  trim(customer_id) AS customer_id,
  try_cast(order_timestamp AS TIMESTAMP) AS order_timestamp,
  upper(trim(order_status)) AS order_status,
  upper(trim(sales_channel)) AS sales_channel,
  upper(trim(currency)) AS currency,
  _rescued_data
FROM `${sales.catalog}`.`${sales.bronze_schema}`.bronze_orders;

CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.silver_schema}`.silver_order_items (
  CONSTRAINT valid_order_id EXPECT (order_id IS NOT NULL AND order_id <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_line_number EXPECT (line_number IS NOT NULL AND line_number > 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_product_id EXPECT (product_id IS NOT NULL AND product_id <> '') ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_quantity EXPECT (quantity IS NOT NULL AND quantity > 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_unit_price EXPECT (unit_price IS NOT NULL AND unit_price > 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_discount EXPECT (discount_pct IS NOT NULL AND discount_pct BETWEEN 0 AND 100) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_source_schema EXPECT (_rescued_data IS NULL) ON VIOLATION FAIL UPDATE
)
COMMENT 'Typed order lines with decimal transaction prices'
TBLPROPERTIES ('quality' = 'silver')
AS SELECT DISTINCT
  trim(order_id) AS order_id,
  try_cast(line_number AS INT) AS line_number,
  trim(product_id) AS product_id,
  try_cast(quantity AS INT) AS quantity,
  try_cast(unit_price AS DECIMAL(10,2)) AS unit_price,
  try_cast(discount_pct AS DECIMAL(5,2)) AS discount_pct,
  _rescued_data
FROM `${sales.catalog}`.`${sales.bronze_schema}`.bronze_order_items;
