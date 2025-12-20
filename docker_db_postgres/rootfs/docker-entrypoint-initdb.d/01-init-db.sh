#!/bin/bash
set -Eeo pipefail

# 0. configs (must be set in the starting stage, initdb will check if data folder is empty)
mkdir -pv ${PGDATA}/conf.d
echo "include_dir='./conf.d'" >> ${PGDATA}/postgresql.conf

# 1. dynamically update preload-extensions
PRELOAD_LIBS="${PG_PRELOAD_LIBS:-pg_cron}"
CRON_DB="${PG_CRON_DB:-postgres}"
CONF_FILE="${PGDATA}/conf.d/20-preload-extensions.conf"

echo "Configuring shared_preload_libraries in ${CONF_FILE} to: ${PRELOAD_LIBS}"

cat > "${CONF_FILE}" <<EOF
# This file is generated at initdb time. Do NOT edit manually!
#
# Available preload extensions:
# citus,timescaledb,pg_stat_statements,auto_explain,pg_cron,
# pg_partman_bgw,pgaudit,pgautofailover,pg_qualstats,pg_squeeze

shared_preload_libraries = '${PRELOAD_LIBS}'

# pg_cron
cron.database_name = '${CRON_DB}'
EOF

# 2. print system info for log and debug
printenv | sort
ls -alh /usr/share/postgresql/${PG_MAJOR}/extension/*.control
tail ${PGDATA}/postgresql.conf
cat ${PGDATA}/conf.d/*

# some ext may requires system restart

# form `docker-entrypoint.sh`: https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh
docker_temp_server_stop
sleep 2s
docker_temp_server_start


psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL    
    SELECT a.name, e.extversion AS installed, a.default_version AS avaliable, a.comment -- e.extowner, e.extnamespace, e.extrelocatable
    FROM pg_available_extensions AS a LEFT JOIN pg_extension AS e ON a.name = e.extname
    ORDER BY name;
EOSQL
