#!/usr/bin/env bash
set -euo pipefail

TASK_DIR="/root/task"

echo "[run.sh] Starting PostgreSQL container..."
docker-compose -f "${TASK_DIR}/docker-compose.yml" up -d

echo "[run.sh] Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
  if docker exec fintech_postgres pg_isready -U fintech_user -d fintechdb > /dev/null 2>&1; then
    echo "[run.sh] PostgreSQL is ready."
    break
  fi
  echo "[run.sh] Attempt ${i}/30 — not ready yet, sleeping 2s..."
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "[run.sh] ERROR: PostgreSQL did not become ready in time."
    exit 1
  fi
done

echo "[run.sh] Loading database schema and sample data..."
docker exec -i fintech_postgres psql -U fintech_user -d fintechdb < "${TASK_DIR}/init_database.sql"
echo "[run.sh] Database initialised."

echo "[run.sh] Installing Python dependencies..."
pip install -r "${TASK_DIR}/requirements.txt" --quiet

echo "[run.sh] Setup complete. Start the Flask app with:"
echo "         python ${TASK_DIR}/app.py"
