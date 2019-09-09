#!/bin/bash

if [ ! -d /data/postgresql ]; then
	# Migrate DB to persistant storage
	echo "Migrating DB.."
	mkdir -p /data/postgresql/11
	mv /var/lib/postgresql/11/main /data/postgresql/11

	# Override secret key from image
	echo "Generating new secret key.."
	KEY=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 50)
	sed -i "s/^SECRET_KEY.*/SECRET_KEY = '$KEY'/" /opt/netbox/netbox/netbox/configuration.py
fi

# Change PostgreSQL data directory
sed -i "s;^data_directory.*;data_directory = '/data/postgresql/11/main';" /etc/postgresql/11/main/postgresql.conf

# Get user/pass from hassio options
USER=$(jq --raw-output '.user' /data/options.json)
PASS=$(jq --raw-output '.password' /data/options.json)

#if [ -z "$USER" ] || [ -z "$PASS" ]; then
#	echo "Error: Username or password not set."
#	exit 1
#fi

MAIL=netbox@localhost

/etc/init.d/redis-server start || {
	echo "Error: Failed to start redis-server"
	exit 1
}

pg_ctlcluster 11 main start || {
	echo "Error: Failed to start postgresql-server"
	exit 1
}

# add netbox superuser
python3 /opt/netbox/netbox/manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$USER', '$MAIL','$PASS')" 2> /dev/null

# start netbox
exec python3 /opt/netbox/netbox/manage.py runserver 0.0.0.0:80 --insecure
