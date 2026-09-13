-- Revenue uses completed orders only and the transaction's price, not list price.
CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.gold_schema}`.gold_sales_lines
COMMENT 'One completed order line with dimensions and rounded net sales in EUR'
TBLPROPERTIES ('quality' = 'gold')
AS SELECT
  i.order_id,
  i.line_number,
  cast(o.order_timestamp AS DATE) AS order_date,
  o.customer_id,
  c.customer_name,
  c.country_code,
  i.product_id,
  p.product_name,
  p.category,
  o.sales_channel,
  o.currency,
  i.quantity,
  i.unit_price,
  i.discount_pct,
  cast(round(i.quantity * i.unit_price * (1 - i.discount_pct * 0.01), 2) AS DECIMAL(18,2)) AS net_sales_amount
FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_order_items i
JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_orders o ON i.order_id = o.order_id
JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_customers c ON o.customer_id = c.customer_id
JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_products p ON i.product_id = p.product_id
WHERE o.order_status = 'COMPLETED';

CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.gold_schema}`.gold_daily_sales
COMMENT 'Daily completed sales by channel and currency'
TBLPROPERTIES ('quality' = 'gold')
AS SELECT
  order_date,
  sales_channel,
  currency,
  count(DISTINCT order_id) AS order_count,
  sum(quantity) AS units_sold,
  sum(net_sales_amount) AS net_sales_amount
FROM `${sales.catalog}`.`${sales.gold_schema}`.gold_sales_lines
GROUP BY order_date, sales_channel, currency;

CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.gold_schema}`.gold_product_sales
COMMENT 'Completed sales by product, category, and currency'
TBLPROPERTIES ('quality' = 'gold')
AS SELECT
  product_id,
  product_name,
  category,
  currency,
  count(DISTINCT order_id) AS order_count,
  sum(quantity) AS units_sold,
  sum(net_sales_amount) AS net_sales_amount
FROM `${sales.catalog}`.`${sales.gold_schema}`.gold_sales_lines
GROUP BY product_id, product_name, category, currency;

CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.gold_schema}`.gold_customer_sales
COMMENT 'Completed sales by customer, country, and currency'
TBLPROPERTIES ('quality' = 'gold')
AS SELECT
  customer_id,
  customer_name,
  country_code,
  currency,
  count(DISTINCT order_id) AS order_count,
  min(order_date) AS first_order_date,
  max(order_date) AS last_order_date,
  sum(net_sales_amount) AS net_sales_amount
FROM `${sales.catalog}`.`${sales.gold_schema}`.gold_sales_lines
GROUP BY customer_id, customer_name, country_code, currency;
