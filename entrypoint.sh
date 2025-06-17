#!/bin/bash
set -e

echo "Checking database migrations..."

# Check if migrations are needed without applying them
if python manage.py migrate --check 2>/dev/null; then
    echo "Database is up to date"
else
    echo "Migrations needed - attempting to apply..."
    # Try to run migrations with a timeout to avoid hanging
    timeout 120 python manage.py migrate --noinput || {
        echo "Migration failed or timed out. Continuing with startup..."
        echo "Manual migration may be required."
    }
fi

echo "Starting gunicorn server..."
exec gunicorn --bind 0.0.0.0:8000 --workers 2 --threads 4 --timeout 60 hogtown_project.wsgi:application