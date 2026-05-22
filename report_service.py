"""Service layer for generating account spend summaries."""

import psycopg2

DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "fintechdb"
DB_USER = "fintech_user"
DB_PASS = "fintech_pass"


def _open_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
    )


def get_spend_summary(account_id: int, days: int) -> dict:
    conn = _open_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT merchant_category, amount, posted_at "
        "FROM card_transactions "
        "WHERE account_id = %s",
        (account_id,),
    )
    rows = cursor.fetchall()

    cursor.close()
    conn.close()

    from datetime import datetime, timezone, timedelta

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    grouped: dict[str, dict] = {}
    for merchant_category, amount, posted_at in rows:
        if posted_at < cutoff:
            continue
        if merchant_category not in grouped:
            grouped[merchant_category] = {"transaction_count": 0, "total_amount": 0.0}
        grouped[merchant_category]["transaction_count"] += 1
        grouped[merchant_category]["total_amount"] += float(amount)

    summary = [
        {
            "merchant_category": cat,
            "transaction_count": data["transaction_count"],
            "total_amount": f"{data['total_amount']:.2f}",
        }
        for cat, data in grouped.items()
    ]

    return {
        "account_id": account_id,
        "days": days,
        "summary": summary,
    }
