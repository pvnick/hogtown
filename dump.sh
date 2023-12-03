#!/bin/bash

cd "$(dirname "$0")"

# ensure we have rsync
sudo apt-get install -y rsync

# dump database
sudo wp search-replace hogtown-dev.paulnickerson.dev hogtowncatholic.org wp_options wp_snippets --export > database/db.sql

# sync content. handle uploads separately because when we sync to prod we want to add upload files, not delete anything in the target uploads folder
rsync -av --delete --exclude="uploads/" /bitnami/wordpress/wp-content/ wp-content-no-uploads/
rsync -av --delete /bitnami/wordpress/wp-content/uploads/ wp-uploads/
