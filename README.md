# Fintech Spend Summary Optimizer

## Task Overview

You are working on a Flask-based fintech service that serves card transaction spend summaries to front-end dashboards. The service connects to a PostgreSQL database containing a `card_transactions` table with roughly 150,000 rows. The current implementation works correctly but is critically slow — each request to `GET /api/accounts/<account_id>/spend-summary?days=30` can take several seconds because it pulls every matching row into Python memory and aggregates them in a loop, opens a fresh database connection on every request, and performs no caching. Your job is to diagnose these architectural and query-level issues, refactor the code to fix them, and verify that the improved implementation is both faster and more robust. The application must continue to return the same JSON response shape after your changes.

## Objectives

- Replace all Python-side data grouping with a single, efficient parameterized SQL query that returns aggregated results directly from PostgreSQL.
- Add a database index that eliminates full-table scans for account-and-date-filtered queries.
- Refactor database connection management so that a single SQLAlchemy engine with a connection pool is reused across all requests instead of opening a new raw connection per call.
- Implement a 60-second in-memory TTL cache keyed by `account_id` and `days` so that repeated identical requests within the window do not hit the database.
- Add input validation: `days` must be an integer between 1 and 90 inclusive; respond with HTTP 400 and `{"error": "invalid_days"}` otherwise.
- Add error handling: catch database connectivity failures and respond with HTTP 503 and `{"error": "database_unavailable"}` instead of leaking raw exceptions.
- Write at least one `pytest` unit test that covers the `invalid_days` validation path without requiring a live database connection.
- After your changes, a warm (cached) request should complete in under 100ms and a cold (uncached) request should complete in under 500ms for a typical account.

## Database Access

| Parameter | Value |
|-----------|-------|
| Host | `<DROPLET_IP>` |
| Port | `5432` |
| Database | `fintechdb` |
| Username | `fintech_user` |
| Password | `fintech_pass` |

You can connect using any PostgreSQL client:

```
psql -h <DROPLET_IP> -p 5432 -U fintech_user -d fintechdb
```

Or use a GUI tool such as DBeaver, TablePlus, or pgAdmin with the same credentials.

## How to Verify

**Functional correctness:**
```bash
curl "http://localhost:5000/api/accounts/1/spend-summary?days=30"
```
Expected shape:
```json
{
  "account_id": 1,
  "days": 30,
  "summary": [
    {"merchant_category": "groceries", "transaction_count": 12, "total_amount": "543.21"},
    ...
  ]
}
```

**Validation — should return 400:**
```bash
curl "http://localhost:5000/api/accounts/1/spend-summary?days=0"
curl "http://localhost:5000/api/accounts/1/spend-summary?days=120"
curl "http://localhost:5000/api/accounts/1/spend-summary?days=abc"
```

**Caching — second request must be significantly faster:**
```bash
time curl "http://localhost:5000/api/accounts/1/spend-summary?days=30"
time curl "http://localhost:5000/api/accounts/1/spend-summary?days=30"
```

**Index usage — run inside psql:**
```sql
EXPLAIN ANALYZE
SELECT merchant_category, COUNT(*), SUM(amount)
FROM card_transactions
WHERE account_id = 1
  AND posted_at >= NOW() - INTERVAL '30 days'
GROUP BY merchant_category;
```
Look for `Index Scan` or `Bitmap Index Scan` on your new index instead of `Seq Scan`.

**Run tests:**
```bash
pytest tests/ -v
```

## Helpful Tips

- Consider which SQL clauses allow the database engine to perform grouping and summation without transferring raw rows to Python.
- Think carefully about the lifecycle of a database connection — creating one per HTTP request has a measurable cost at scale.
- Review the query execution plan (`EXPLAIN ANALYZE`) before and after adding an index to understand what changed.
- Explore how a simple dictionary keyed by request parameters can act as a short-lived cache when full Redis infrastructure is unavailable.
- Consider what the caller should experience when the database is temporarily unreachable — a stack trace is not an acceptable API response.
