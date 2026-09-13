-- Expectations cannot query other tables directly. Compute violation counts,
-- then apply a row-level expectation to each check result.
CREATE OR REFRESH MATERIALIZED VIEW `${sales.catalog}`.`${sales.silver_schema}`.silver_integrity_checks (
  CONSTRAINT no_integrity_violations EXPECT (violation_count = 0) ON VIOLATION FAIL UPDATE
)
COMMENT 'Key uniqueness, references, and order completeness checks'
TBLPROPERTIES ('quality' = 'silver')
AS
SELECT 'duplicate_customer_keys' AS check_name, count(*) AS violation_count
FROM (SELECT customer_id FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_customers GROUP BY customer_id HAVING count(*) > 1) duplicates
UNION ALL
SELECT 'duplicate_product_keys', count(*)
FROM (SELECT product_id FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_products GROUP BY product_id HAVING count(*) > 1) duplicates
UNION ALL
SELECT 'duplicate_order_keys', count(*)
FROM (SELECT order_id FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_orders GROUP BY order_id HAVING count(*) > 1) duplicates
UNION ALL
SELECT 'duplicate_order_line_keys', count(*)
FROM (SELECT order_id, line_number FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_order_items GROUP BY order_id, line_number HAVING count(*) > 1) duplicates
UNION ALL
SELECT 'orders_without_customers', count(*)
FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_orders o LEFT JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'lines_without_orders', count(*)
FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_order_items i LEFT JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_orders o ON i.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'lines_without_products', count(*)
FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_order_items i LEFT JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_products p ON i.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'orders_without_lines', count(*)
FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_orders o LEFT JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_order_items i ON o.order_id = i.order_id
WHERE i.order_id IS NULL
UNION ALL
SELECT 'orders_before_customer_creation', count(*)
FROM `${sales.catalog}`.`${sales.silver_schema}`.silver_orders o JOIN `${sales.catalog}`.`${sales.silver_schema}`.silver_customers c ON o.customer_id = c.customer_id
WHERE o.order_timestamp < c.created_at;
