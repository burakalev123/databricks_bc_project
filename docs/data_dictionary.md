# Synthetic sales source data

These files are fictional learning inputs generated with a fixed random seed of `42`. They do not describe real people, companies, or transactions. They represent one initial snapshot; CDC events and incremental batches are not included yet.

CSV format: UTF-8, comma delimiter, header row, decimal point, ISO dates/timestamps. CSV does not store SQL types; the types below are the intended typed contract for Silver. IDs are strings and must retain their leading zeros. Timestamps ending in `Z` are UTC.

## customers.csv — 100 customers

| Column | SQL type | Meaning |
| --- | --- | --- |
| customer_id | STRING | Primary key |
| customer_name | STRING | Explicitly fictional display name |
| email | STRING | Synthetic address using example.com |
| country_code | STRING | NL, DE, BE, or FR |
| city | STRING | City consistent with country_code |
| created_at | TIMESTAMP | Customer creation time; precedes all orders |

## products.csv — 25 products

| Column | SQL type | Meaning |
| --- | --- | --- |
| product_id | STRING | Primary key |
| product_name | STRING | Generic product name |
| category | STRING | Electronics, Office, Home, Sports, or Accessories |
| list_price | DECIMAL(10,2) | Catalog price in EUR, excluding tax |
| currency | STRING | Always EUR |

## orders.csv — 1,000 orders

| Column | SQL type | Meaning |
| --- | --- | --- |
| order_id | STRING | Primary key |
| customer_id | STRING | Foreign key to customers |
| order_timestamp | TIMESTAMP | Order time in January–June 2026 UTC |
| order_status | STRING | COMPLETED, CANCELLED, or PENDING |
| sales_channel | STRING | WEB, MOBILE, or STORE |
| currency | STRING | Always EUR |

Status is the snapshot's current status; there is no status change history. Order identifiers do not imply chronological order.

## order_items.csv — 2,561 order lines

| Column | SQL type | Meaning |
| --- | --- | --- |
| order_id | STRING | Foreign key to orders; first part of primary key |
| line_number | INT | Second part of primary key, starting at 1 per order |
| product_id | STRING | Foreign key to products |
| quantity | INT | Number of units, from 1 to 5 |
| unit_price | DECIMAL(10,2) | Price at order time in the order's currency, excluding tax |
| discount_pct | DECIMAL(5,2) | Whole percentage points: 0, 5, 10, or 15 |

Each order has 1–4 lines with distinct products. All foreign keys resolve. Transaction prices are stored on the order lines, so future catalog price changes need not change past sales amounts.

## Initial business conventions

- Line net amount = `ROUND(quantity * unit_price * (1 - discount_pct / 100.00), 2)`.
- Sales revenue includes only `COMPLETED` orders; `CANCELLED` and `PENDING` remain available for status analysis.
- Sum rounded line amounts for order and reporting totals.
- All amounts use EUR; tax, shipping, refunds, returns, and currency conversion are outside this first example.
- Gold outputs: completed sales lines, daily sales by channel, product sales with category, and customer sales with country. Each aggregate retains currency.
- Product-level distinct order counts are not additive across products because one order can contain multiple products.

The initial data contains no deliberately invalid or duplicate keys. Dedicated quality-error and incremental batches can be added when implementing those lessons.
