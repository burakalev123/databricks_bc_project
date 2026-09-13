-- Run in the SQL editor AFTER a successful pipeline update.
-- Uses the configured ldp_example catalog and its three layer schemas.
-- These expected values apply only to the unchanged initial sample dataset.
SELECT 'bronze_customers' AS dataset, count(*) AS actual_count, 100 AS expected_count FROM `ldp_example`.`10_bronze`.bronze_customers
UNION ALL SELECT 'bronze_products', count(*), 25 FROM `ldp_example`.`10_bronze`.bronze_products
UNION ALL SELECT 'bronze_orders', count(*), 1000 FROM `ldp_example`.`10_bronze`.bronze_orders
UNION ALL SELECT 'bronze_order_items', count(*), 2561 FROM `ldp_example`.`10_bronze`.bronze_order_items
UNION ALL SELECT 'silver_customers', count(*), 100 FROM `ldp_example`.`20_silver`.silver_customers
UNION ALL SELECT 'silver_products', count(*), 25 FROM `ldp_example`.`20_silver`.silver_products
UNION ALL SELECT 'silver_orders', count(*), 1000 FROM `ldp_example`.`20_silver`.silver_orders
UNION ALL SELECT 'silver_order_items', count(*), 2561 FROM `ldp_example`.`20_silver`.silver_order_items;

SELECT check_name, violation_count
FROM `ldp_example`.`20_silver`.silver_integrity_checks
ORDER BY check_name;

SELECT
  count(DISTINCT order_id) AS completed_order_count,
  812 AS expected_completed_order_count,
  sum(net_sales_amount) AS net_sales_amount,
  cast(181328.13 AS DECIMAL(18,2)) AS expected_net_sales_amount
FROM `ldp_example`.`30_gold`.gold_sales_lines;

SELECT 'sales_lines' AS dataset, sum(net_sales_amount) AS net_sales_amount FROM `ldp_example`.`30_gold`.gold_sales_lines
UNION ALL SELECT 'daily_sales', sum(net_sales_amount) FROM `ldp_example`.`30_gold`.gold_daily_sales
UNION ALL SELECT 'product_sales', sum(net_sales_amount) FROM `ldp_example`.`30_gold`.gold_product_sales
UNION ALL SELECT 'customer_sales', sum(net_sales_amount) FROM `ldp_example`.`30_gold`.gold_customer_sales;
