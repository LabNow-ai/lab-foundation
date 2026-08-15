#!/bin/bash
set -Eeo pipefail

# 0. configs (must be set in the starting stage, initdb will check if data folder is empty)
mkdir -pv ${PGDATA}/conf.d
echo "include_dir='./conf.d'" >> ${PGDATA}/postgresql.conf

# 1. dynamically update preload-extensions
PRELOAD_LIBS="${PG_PRELOAD_LIBS:-pg_duckdb,pg_search}"
CRON_DB="${PG_CRON_DB:-postgres}"
CONF_FILE="${PGDATA}/conf.d/20-preload-extensions.conf"

echo "Configuring shared_preload_libraries in ${CONF_FILE} to: ${PRELOAD_LIBS}"

cat > "${CONF_FILE}" <<EOF
# This file is generated at initdb time. Do NOT edit manually!

# Available preload extensions (if citus is enabled, it MUST be the first one):
# citus,timescaledb,pg_duckdb,pg_search,pg_cron,pg_net,pgaudit,pgautofailover,pg_qualstats,pg_squeeze,pg_stat_statements,pg_stat_kcache,auto_explain,pg_partman_bgw

shared_preload_libraries = '${PRELOAD_LIBS}'

# pg_cron
cron.database_name = '${CRON_DB}'
EOF

# 2. print system info for log and debug
printenv | sort
ls -alh /usr/share/postgresql/${PG_MAJOR}/extension/*.control
tail ${PGDATA}/postgresql.conf
cat ${PGDATA}/conf.d/*


# if some ext may requires system restart
# form `docker-entrypoint.sh`: https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh
# docker_temp_server_stop && sleep 2s && docker_temp_server_start

enable_all_extensions() {
  psql "$@" -At -c "SELECT name FROM pg_available_extensions WHERE name NOT IN (SELECT extname FROM pg_extension)" |
  while read e; do psql "$@" -c "CREATE EXTENSION IF NOT EXISTS \"$e\" CASCADE" >/dev/null || echo "Skip $e"; done
}

# if enabling all extensions, uncomment the following line
# enable_all_extensions -d ${POSTGRES_DB}
