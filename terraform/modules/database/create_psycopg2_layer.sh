#!/bin/bash

# Script to create a psycopg2 Lambda layer
# This creates a zip file with psycopg2 pre-compiled for Lambda

set -e

echo "Creating psycopg2 Lambda layer..."

# Clean up any existing files
rm -rf python/
rm -f psycopg2-layer.zip

# Create the layer directory structure
mkdir -p python/lib/python3.11/site-packages

# Use pip to install psycopg2-binary into the layer directory
pip install \
    --platform manylinux2014_x86_64 \
    --target python/lib/python3.11/site-packages \
    --implementation cp \
    --python-version 3.11 \
    --only-binary=:all: \
    --upgrade \
    psycopg2-binary

# Create the layer zip file
zip -r psycopg2-layer.zip python/

# Clean up
rm -rf python/

echo "psycopg2 Lambda layer created: psycopg2-layer.zip"
echo "Size: $(du -h psycopg2-layer.zip | cut -f1)"