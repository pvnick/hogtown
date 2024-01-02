#!/bin/bash

cd "$(dirname "$0")"

# ensure we have rsync
sudo apt-get install -y rsync

# import database
sudo wp db import database/db.sql

# sync content. handle uploads separately because when we sync to prod we want to add upload files, not delete anything in the target uploads folder
rsync -av --delete --exclude="uploads/" wp-content-no-uploads/ /bitnami/wordpress/wp-content/ 
# only sync file uploads to the main wordpress, but ignore plugin-associated uploads
rsync -av --prune-empty-dirs wp-uploads/ /bitnami/wordpress/wp-content/uploads/
