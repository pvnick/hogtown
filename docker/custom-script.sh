#!/bin/bash

echo $WORDPRESS_DATABASE_HOST
apt-get update
apt-get install -y dnsutils
dig $WORDPRESS_DATABASE_HOST
