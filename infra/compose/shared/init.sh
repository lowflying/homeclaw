#!/bin/bash
# Runs once on first postgres container start (via docker-entrypoint-initdb.d).
# Creates databases and per-solution users. Passwords come from environment.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE clarvis_ai;
    CREATE DATABASE personal_assistant;
    CREATE DATABASE home_procurement;

    CREATE USER clarvis WITH PASSWORD '${CLARVIS_DB_PASSWORD}';
    CREATE USER personal_assistant WITH PASSWORD '${PERSONAL_ASSISTANT_DB_PASSWORD}';
    CREATE USER procurement WITH PASSWORD '${PROCUREMENT_DB_PASSWORD}';

    GRANT ALL PRIVILEGES ON DATABASE clarvis_ai TO clarvis;
    GRANT ALL PRIVILEGES ON DATABASE personal_assistant TO personal_assistant;
    GRANT ALL PRIVILEGES ON DATABASE home_procurement TO procurement;
EOSQL
