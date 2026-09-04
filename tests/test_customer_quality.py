# Databricks notebook source
# MAGIC %md
# MAGIC # Data quality checks
# MAGIC Fails the workflow when core Silver or Gold expectations are not met.

# COMMAND ----------

dbutils.widgets.text("catalog", "workspace")
dbutils.widgets.text("schema", "databricks_bc_project")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")

silver_table = f"`{catalog}`.`{schema}`.silver_customers"
gold_table = f"`{catalog}`.`{schema}`.gold_customer_summary"

# COMMAND ----------

silver = spark.table(silver_table)
gold = spark.table(gold_table)

checks = {
    "silver table is not empty": silver.limit(1).count() > 0,
    "customer_id has no nulls": silver.filter("customer_id IS NULL").limit(1).count() == 0,
    "email has no nulls": silver.filter("email IS NULL").limit(1).count() == 0,
    "email is unique": silver.count() == silver.select("email").distinct().count(),
    "gold table is not empty": gold.limit(1).count() > 0,
    "gold counts are positive": gold.filter("customer_count <= 0").limit(1).count() == 0,
}

failed_checks = [name for name, passed in checks.items() if not passed]

if failed_checks:
    raise AssertionError("Data quality checks failed: " + ", ".join(failed_checks))

print(f"All {len(checks)} data quality checks passed.")
