#!/bin/bash

# Check for Bash 4.0 or later
if ((BASH_VERSINFO[0] < 4)); then
    echo "Bash 4.0 or later is required for associative arrays."
    exit 1
fi

cd "$(dirname "$0")"

# Path to your PHP script
WP_CONFIG_PATH="../../wp-config.php"

# Declare an associative array
declare -A db_config

# Pull out database variables
while IFS=" " read -r key value; do
	db_config["$key"]="$value"
done < <(cat $WP_CONFIG_PATH | grep "define( 'DB_" | sed -E "s/define\\( '([^']*?)', '([^']*?)' \\);/\1 \2/")

# Separate host from port
db_config["DB_ADDRESS"]="$(echo ${db_config[DB_HOST]} | cut -d: -f1)"
db_config["DB_PORT"]="$(echo ${db_config[DB_HOST]} | cut -d: -f2)"

# Dump the relevant database tables
mariadb-dump --host="${db_config[DB_ADDRESS]}" --port=${db_config[DB_PORT]} --user="${db_config[DB_USER]}" --password="${db_config[DB_PASSWORD]}" ${db_config[DB_NAME]} wp_options wp_snippets > dump.sql
