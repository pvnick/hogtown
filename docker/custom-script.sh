#!/bin/bash

echo $WORDPRESS_DATABASE_HOST
apt-get install -y dnsutils
dig $WORDPRESS_DATABASE_HOST
