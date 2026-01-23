#!/bin/bash

# Exit on error
set -e

# Ensure backups directory exists
mkdir -p backups

# Check for railway CLI
if ! command -v railway &> /dev/null; then
    echo "Error: railway CLI is not installed."
    exit 1
fi

# Check for pg_dump
if ! command -v pg_dump &> /dev/null; then
    echo "Error: pg_dump is not installed."
    echo "Please install it via Homebrew: brew install libpq"
    echo "Then ensure it's in your PATH: export PATH=\"/opt/homebrew/opt/libpq/bin:\$PATH\""
    exit 1
fi

# Check if project is linked
# We suppress output but check exit code
if ! railway status &> /dev/null; then
    echo "Error: No Railway project linked."
    echo "Please run 'railway link' locally to select your project."
    exit 1
fi

echo "Starting database backup..."
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="backups/backup_$TIMESTAMP.sql"

# Run pg_dump with credentials from Railway
# We use 'railway run' to inject DATABASE_URL into the environment of the command
# We reference DATABASE_URL, not DATABASE_PUBLIC_URL typically, but it depends on the project.
# Usually DATABASE_URL is the internal one, but 'railway run' makes it available.
# We need to ensure we're using the correct connection string.

echo "Fetching connection info and dumping..."
# Use DATABASE_PUBLIC_URL if available, otherwise DATABASE_URL (which might fail locally if internal)
# We use railway run to access these variables found in the environment
railway run bash -c 'pg_dump "${DATABASE_PUBLIC_URL:-$DATABASE_URL}"' > "$FILENAME"

if [ -s "$FILENAME" ]; then
    echo "✅ Backup created successfully: $FILENAME"
    echo "Size: $(du -h "$FILENAME" | cut -f1)"
else
    echo "❌ Backup failed or file is empty."
    rm -f "$FILENAME"
    exit 1
fi
