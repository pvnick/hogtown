#!/bin/bash
set -e

ping google.com

echo "Installing Python dependencies for runtime..."
pip3 install -r requirements.txt

echo "Starting Gunicorn server..."
gunicorn --bind 0.0.0.0:8000 \
         --workers $(nproc) \
         --timeout 60 \
         --keep-alive 2 \
         --max-requests 1000 \
         --max-requests-jitter 100 \
         hogtown_project.wsgi:application
