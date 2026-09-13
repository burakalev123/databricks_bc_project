"""Generate deterministic, fictional CSV inputs; pipeline transformations use SQL."""

import csv
from datetime import datetime, timedelta
from pathlib import Path
from random import Random


OUTPUT = Path(__file__).resolve().parents[1] / "data" / "sample"


def generate():
    rng = Random(42)
    locations = [
        ("NL", "Amsterdam"), ("NL", "Rotterdam"),
        ("DE", "Berlin"), ("DE", "Hamburg"),
        ("BE", "Brussels"), ("FR", "Paris"),
    ]
    catalog = [
        ("Electronics", "Wireless Mouse", 2490),
        ("Electronics", "Keyboard", 5990),
        ("Electronics", "USB-C Hub", 3990),
        ("Electronics", "Headphones", 8990),
        ("Electronics", "Webcam", 6990),
        ("Office", "Notebook", 590),
        ("Office", "Pen Set", 890),
        ("Office", "Desk Organizer", 1990),
        ("Office", "Desk Lamp", 3490),
        ("Office", "Laptop Stand", 4490),
        ("Home", "Coffee Mug", 1290),
        ("Home", "Water Bottle", 1890),
        ("Home", "Storage Box", 1490),
        ("Home", "Wall Clock", 2990),
        ("Home", "Cushion", 2290),
        ("Sports", "Yoga Mat", 2990),
        ("Sports", "Resistance Band", 990),
        ("Sports", "Skipping Rope", 1190),
        ("Sports", "Gym Bag", 3990),
        ("Sports", "Fitness Towel", 1490),
        ("Accessories", "Backpack", 5490),
        ("Accessories", "Wallet", 2490),
        ("Accessories", "Umbrella", 1990),
        ("Accessories", "Travel Pouch", 1690),
        ("Accessories", "Laptop Sleeve", 2790),
    ]

    def money(cents):
        return f"{cents // 100}.{cents % 100:02d}"

    customers = []
    for n in range(1, 101):
        country, city = rng.choice(locations)
        customers.append({
            "customer_id": f"C{n:04d}",
            "customer_name": f"Demo Customer {n:03d}",
            "email": f"customer{n:03d}@example.com",
            "country_code": country,
            "city": city,
            "created_at": "2025-12-01T00:00:00Z",
        })

    products = [{
        "product_id": f"P{n:04d}",
        "product_name": name,
        "category": category,
        "list_price": money(price),
        "currency": "EUR",
    } for n, (category, name, price) in enumerate(catalog, 1)]

    orders, items = [], []
    start = datetime(2026, 1, 1)
    for n in range(1, 1001):
        order_id = f"O{n:06d}"
        ordered_at = start + timedelta(seconds=rng.randrange(181 * 86400))
        orders.append({
            "order_id": order_id,
            "customer_id": rng.choice(customers)["customer_id"],
            "order_timestamp": ordered_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "order_status": rng.choices(
                ["COMPLETED", "CANCELLED", "PENDING"], weights=[85, 10, 5]
            )[0],
            "sales_channel": rng.choice(["WEB", "MOBILE", "STORE"]),
            "currency": "EUR",
        })
        for line_number, index in enumerate(rng.sample(range(25), rng.randint(1, 4)), 1):
            items.append({
                "order_id": order_id,
                "line_number": line_number,
                "product_id": products[index]["product_id"],
                "quantity": rng.randint(1, 5),
                "unit_price": money(catalog[index][2]),
                "discount_pct": rng.choice([0, 0, 0, 5, 10, 15]),
            })

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, rows in [
        ("customers", customers), ("products", products),
        ("orders", orders), ("order_items", items),
    ]:
        with (OUTPUT / f"{name}.csv").open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
        print(f"{name}: {len(rows)} rows")


if __name__ == "__main__":
    generate()
