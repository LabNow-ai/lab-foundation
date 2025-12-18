#!/bin/bash
set -Eeo pipefail

printenv | sort

ls -alh /usr/share/postgresql/${PG_MAJOR}/extension/*.control

mkdir -pv ${PGDATA}/conf.d
echo "include_dir='./conf.d'" >> ${PGDATA}/postgresql.conf
tail ${PGDATA}/postgresql.conf

cat <<EOT >> ${PGDATA}/conf.d/pg-ext.conf
shared_preload_libraries = 'citus,timescaledb,vector,pg_search,pgaudit,pgautofailover,pg_qualstats,pg_squeeze,pg_net'
cron.database_name='${POSTGRES_DB:-postgres}'
EOT
cat ${PGDATA}/conf.d/*

# pg_analytics

# https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh
# form: docker-entrypoint.sh
docker_temp_server_stop
sleep 2s
docker_temp_server_start


psql -v ON_ERROR_STOP=0 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CALL enable_all_extensions();
    
    SELECT a.name, e.extversion AS installed, a.default_version AS avaliable, a.comment --e.extowner, e.extnamespace, e.extrelocatable
    FROM pg_available_extensions AS a LEFT JOIN pg_extension AS e ON a.name = e.extname
    ORDER BY name;
EOSQL
