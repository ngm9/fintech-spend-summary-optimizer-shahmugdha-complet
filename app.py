"""Flask application entry point for the Fintech Spend Summary service."""

from flask import Flask, jsonify, request
from report_service import get_spend_summary

app = Flask(__name__)


@app.route("/api/accounts/<int:account_id>/spend-summary", methods=["GET"])
def spend_summary(account_id: int):
    days_raw = request.args.get("days", "30")
    try:
        days = int(days_raw)
    except ValueError:
        days = 30

    result = get_spend_summary(account_id, days)
    return jsonify(result)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
