#!/bin/bash
set -e

echo "Installing Python dependencies..."
pip3 install -r requirements.txt

echo "Running database migrations..."
python3 manage.py migrate --noinput

echo "Collecting static files..."
python3 manage.py collectstatic --noinput

echo "Build completed successfully!"