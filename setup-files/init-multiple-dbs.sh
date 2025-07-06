#!/bin/bash

set -e
set -u

# Function for creating users and databases
create_user_and_db() {
    local database=$1
    local password=$2
    echo "Creating user and database '$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE USER $database WITH PASSWORD '$password';
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
        \c $database
        CREATE SCHEMA IF NOT EXISTS $database AUTHORIZATION $database;
        ALTER USER $database SET search_path TO $database;
EOSQL
}

# Check that POSTGRES_MULTIPLE_DATABASES variable is set
if [ -z "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "POSTGRES_MULTIPLE_DATABASES environment variable is not set"
    exit 1
fi

# Get variables from environment
if [ -f /.env ]; then
    source /.env
    echo "Loaded environment variables from /.env"
fi

# Check required variables
if [ -z "${POSTGRES_N8N_PASSWORD:-}" ] || [ -z "${POSTGRES_FLOWISE_PASSWORD:-}" ]; then
    echo "Required password variables are not set"
    exit 1
fi

# Create each database
for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
    case "$db" in
        "n8n")
            create_user_and_db "$db" "$POSTGRES_N8N_PASSWORD"
            ;;
        "flowise")
            create_user_and_db "$db" "$POSTGRES_FLOWISE_PASSWORD"
            ;;
        *)
            echo "Unknown database: $db"
            ;;
    esac
done

echo "Multiple databases created successfully"
