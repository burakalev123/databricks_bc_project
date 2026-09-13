"""Exercise the checked-in SELECTs locally, not the Databricks execution engine.

The narrow loader removes LDP DDL, transpiles SELECTs with SQLGlot, and evaluates
expectation expressions separately. It does not emulate Auto Loader, pipeline
transactions, expectation enforcement, Unity Catalog, or incremental refresh.
"""

import csv
from decimal import Decimal, ROUND_HALF_UP
import glob
from pathlib import Path
import re
import unittest

import duckdb
import sqlglot
import yaml


ROOT = Path(__file__).resolve().parents[1]
ENTITIES = ("customers", "products", "orders", "order_items")


def default_parameters():
    config = yaml.safe_load((ROOT / "databricks.yml").read_text())
    return {f"sales.{key}": value["default"] for key, value in config["variables"].items() if "default" in value}


def resolve_parameters(text):
    for name, value in default_parameters().items():
        text = text.replace("${" + name + "}", value)
    return text


def definitions():
    result = {}
    for layer in ("silver", "gold"):
        for path in sorted((ROOT / "src/pipelines" / layer).glob("*.sql")):
            text = re.sub(r"--[^\n]*", "", resolve_parameters(path.read_text()))
            for statement in text.split(";"):
                if not statement.strip():
                    continue
                target = re.search(r"CREATE OR REFRESH MATERIALIZED VIEW\s+([^\s(]+)", statement)[1]
                name = target.rsplit(".", 1)[-1]
                query = re.split(r"\bAS\s+(?=SELECT\b|WITH\b)", statement, maxsplit=1)[1]
                expectations = re.findall(
                    r"CONSTRAINT\s+(\w+)\s+EXPECT\s*\((.*?)\)\s+ON VIOLATION FAIL UPDATE",
                    statement, flags=re.S,
                )
                result[name] = (query, expectations, target)
    return result


def local_sql(query):
    return sqlglot.transpile(query, read="databricks", write="duckdb")[0]


class SalesPipelineTests(unittest.TestCase):
    def setUp(self):
        self.db = duckdb.connect()
        self.addCleanup(self.db.close)
        self.defs = definitions()
        parameters = default_parameters()
        catalog = parameters["sales.catalog"]
        self.db.execute(f'''ATTACH ':memory:' AS "{catalog}"''')
        for layer in ("bronze", "silver", "gold"):
            schema = parameters[f"sales.{layer}_schema"]
            self.db.execute(f'CREATE SCHEMA "{catalog}"."{schema}"')
        self.raw = {}
        for entity in ENTITIES:
            path = ROOT / "data/sample" / f"{entity}.csv"
            with path.open(newline="") as handle:
                self.raw[entity] = list(csv.DictReader(handle))
            self.db.execute(
                f"CREATE TABLE bronze_{entity} AS "
                "SELECT *, CAST(NULL AS VARCHAR) AS _rescued_data "
                "FROM read_csv(?, header=true, all_varchar=true)", [str(path)],
            )
            # Keep flat fixture tables editable while the actual SELECTs use
            # their configured three-part names across isolated layer schemas.
            schema = parameters["sales.bronze_schema"]
            self.db.execute(
                f'CREATE VIEW "{catalog}"."{schema}".bronze_{entity} '
                f'AS SELECT * FROM memory.main.bronze_{entity}'
            )

    def refresh(self):
        for name, (query, _, target) in self.defs.items():
            quoted_target = local_sql(f"SELECT * FROM {target}").split("FROM ", 1)[1]
            self.db.execute(f"CREATE OR REPLACE TABLE {quoted_target} AS {local_sql(query)}")
            self.db.execute(f"CREATE OR REPLACE VIEW {name} AS SELECT * FROM {quoted_target}")

    def failed_expectations(self):
        failures = []
        for name, (_, expectations, _) in self.defs.items():
            for label, predicate in expectations:
                count = self.db.execute(
                    f"SELECT count(*) FROM {name} WHERE ({local_sql(predicate)}) IS NOT TRUE"
                ).fetchone()[0]
                if count:
                    failures.append((name, label))
        return failures

    def total(self, table="gold_sales_lines"):
        return self.db.execute(f"SELECT sum(net_sales_amount) FROM {table}").fetchone()[0]

    def test_sample_results_and_reconciliation(self):
        self.refresh()
        self.assertEqual(self.failed_expectations(), [])
        orders = {r["order_id"]: r for r in self.raw["orders"]}
        expected = {}
        for row in self.raw["order_items"]:
            if orders[row["order_id"]]["order_status"] != "COMPLETED":
                continue
            amount = Decimal(row["quantity"]) * Decimal(row["unit_price"])
            amount *= 1 - Decimal(row["discount_pct"]) / 100
            expected[(row["order_id"], int(row["line_number"]))] = amount.quantize(
                Decimal("0.01"), rounding=ROUND_HALF_UP
            )
        actual = {(oid, line): amount for oid, line, amount in self.db.execute(
            "SELECT order_id, line_number, net_sales_amount FROM gold_sales_lines"
        ).fetchall()}
        self.assertEqual(actual, expected)
        self.assertEqual(sum(expected.values()), Decimal("181328.13"))
        self.assertEqual(self.db.execute(
            "SELECT count(DISTINCT order_id) FROM gold_sales_lines"
        ).fetchone()[0], 812)
        for table in ("gold_sales_lines", "gold_daily_sales", "gold_product_sales", "gold_customer_sales"):
            self.assertEqual(self.total(table), sum(expected.values()))
        self.assertEqual(self.db.execute(
            "SELECT sum(order_count) FROM gold_daily_sales"
        ).fetchone()[0], 812)
        checks = [self.db.execute(s.sql(dialect="duckdb")).fetchall() for s in sqlglot.parse(
            (ROOT / "docs/validation.sql").read_text(), read="databricks"
        ) if s]
        self.assertTrue(all(actual == expected for _, actual, expected in checks[0]))
        self.assertTrue(all(count == 0 for _, count in checks[1]))
        self.assertEqual(checks[2][0], (812, 812, Decimal("181328.13"), Decimal("181328.13")))
        self.assertEqual({amount for _, amount in checks[3]}, {Decimal("181328.13")})

    def test_identical_rows_and_whitespace_do_not_inflate_sales(self):
        self.db.execute("INSERT INTO bronze_order_items SELECT * FROM bronze_order_items")
        self.db.execute("UPDATE bronze_customers SET customer_id = ' ' || customer_id || ' ', email = upper(email)")
        self.refresh()
        self.assertEqual(self.failed_expectations(), [])
        self.assertEqual(self.db.execute("SELECT count(*) FROM silver_order_items").fetchone()[0], 2561)
        self.assertEqual(self.total(), Decimal("181328.13"))

    def test_invalid_quantity_and_rescued_schema_are_detected(self):
        self.db.execute("UPDATE bronze_order_items SET quantity = 'invalid' WHERE order_id = 'O000001'")
        self.db.execute("UPDATE bronze_products SET _rescued_data = '{}' WHERE product_id = 'P0001'")
        self.refresh()
        failures = self.failed_expectations()
        self.assertIn(("silver_order_items", "valid_quantity"), failures)
        self.assertIn(("silver_products", "valid_source_schema"), failures)

    def test_orphan_customer_is_detected(self):
        self.db.execute("UPDATE bronze_orders SET customer_id = 'MISSING' WHERE order_id = 'O000001'")
        self.refresh()
        self.assertIn(("silver_integrity_checks", "no_integrity_violations"), self.failed_expectations())
        self.assertEqual(self.db.execute(
            "SELECT violation_count FROM silver_integrity_checks WHERE check_name = 'orders_without_customers'"
        ).fetchone()[0], 1)

    def test_conflicting_keys_are_detected(self):
        self.db.execute("INSERT INTO bronze_products SELECT * FROM bronze_products WHERE product_id = 'P0001'")
        self.db.execute("UPDATE bronze_products SET product_name = 'Conflicting name' WHERE rowid = (SELECT max(rowid) FROM bronze_products)")
        self.refresh()
        self.assertIn(("silver_integrity_checks", "no_integrity_violations"), self.failed_expectations())

    def test_catalog_price_does_not_rewrite_transaction_revenue(self):
        self.db.execute("UPDATE bronze_products SET list_price = '999.99'")
        self.refresh()
        self.assertEqual(self.failed_expectations(), [])
        self.assertEqual(self.total(), Decimal("181328.13"))

    def test_half_cent_rounds_up_at_line_level(self):
        self.db.execute("UPDATE bronze_orders SET order_status = 'COMPLETED' WHERE order_id = 'O000001'")
        self.db.execute("UPDATE bronze_order_items SET quantity = '1', unit_price = '0.05', discount_pct = '50' WHERE order_id = 'O000001' AND line_number = '1'")
        self.refresh()
        self.assertEqual(self.failed_expectations(), [])
        self.assertEqual(self.db.execute(
            "SELECT net_sales_amount FROM gold_sales_lines WHERE order_id = 'O000001' AND line_number = 1"
        ).fetchone()[0], Decimal("0.03"))

    def test_bundle_sources_and_bronze_schema_match_csvs(self):
        config = yaml.safe_load((ROOT / "databricks.yml").read_text())
        resource_path = ROOT / "resources/sales.pipeline.yml"
        pipeline = yaml.safe_load(resource_path.read_text())["resources"]["pipelines"]["sales_pipeline"]
        self.assertIn(resource_path, list(ROOT.glob(config["include"][0])))
        source_glob = pipeline["libraries"][0]["glob"]["include"]
        included = {Path(p).resolve() for p in glob.glob(str(resource_path.parent / source_glob), recursive=True) if p.endswith('.sql')}
        self.assertEqual(included, {p.resolve() for p in (ROOT / 'src/pipelines').rglob('*.sql')})
        bronze = (ROOT / "src/pipelines/bronze/01_ingestion.sql").read_text()
        for entity in ENTITIES:
            block = bronze.split(f".bronze_{entity}\n", 1)[1].split(";", 1)[0]
            schema = re.search(r"schema => '([^']+)'", block)[1]
            self.assertEqual([field.strip().split()[0] for field in schema.split(',')], list(self.raw[entity][0]))
            self.assertIn("${sales.source_path}/" + entity, block)
        self.assertEqual(pipeline["configuration"]["sales.source_path"], "${var.source_path}")
        self.assertEqual(config["variables"]["catalog"]["default"], "ldp_example")
        self.assertEqual(pipeline["schema"], "${var.bronze_schema}")
        for layer, expected_schema in [("bronze", "10_bronze"), ("silver", "20_silver"), ("gold", "30_gold")]:
            self.assertEqual(config["variables"][f"{layer}_schema"]["default"], expected_schema)
            self.assertEqual(pipeline["configuration"][f"sales.{layer}_schema"], "${var." + layer + "_schema}")
            for path in (ROOT / "src/pipelines" / layer).glob("*.sql"):
                targets = re.findall(r"CREATE OR REFRESH (?:STREAMING TABLE|MATERIALIZED VIEW)\s+([^\s(]+)", resolve_parameters(path.read_text()))
                self.assertTrue(targets)
                for target in targets:
                    self.assertTrue(target.startswith(f"`ldp_example`.`{expected_schema}`."), target)


if __name__ == "__main__":
    unittest.main()
