source /opt/utils/script-utils.sh


setup_postgresql_client() {
  local VER_PG=${1:-"17"} ;
  # from: https://www.postgresql.org/download/linux/ubuntu/
  curl "https://www.postgresql.org/media/keys/ACCC4CF8.asc" | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc ;
  echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list ;
  # will download ~9MB files and use ~55MB disk after installation
  sudo apt-get update && sudo apt-get -y install "postgresql-client-${VER_PG}" ;

  type psql && echo "@ Version of psql client: $(psql --version)" || return -1 ;
}


setup_mysql_client() {
  # will download ~5MB files and use ~76MB disk after installation
  sudo apt-get update && sudo apt-get -y install mysql-client ;
  type mysql && echo "@ Version of mysql client: $(mysql --version)" || return -1 ;
}


setup_mongosh_client() {
  local VER_MONGOSH=${1:-"8.2"} ;
  # from: https://www.mongodb.com/docs/mongodb-shell/install/
  local DISTRO=$(lsb_release -cs) ;
  curl -sL https://www.mongodb.org/static/pgp/server-${VER_MONGOSH}.asc | sudo tee /etc/apt/trusted.gpg.d/mongodb.asc ;
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${DISTRO}/mongodb-org/${VER_MONGOSH} multiverse" > /etc/apt/sources.list.d/mongodb-org-${VER_MONGOSH}.list ;
  # will download ~38MB files and use ~218MB disk after installation
  sudo apt-get update && sudo apt-get -y install mongodb-mongosh ;
  type mongosh && echo "@ Version of mongosh client: $(mongosh --version)" || return -1 ;
}


setup_redis_client() {
  # from https://redis.io/docs/getting-started/installation/install-redis-on-linux/
  curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg ;
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list ;
  sudo apt-get update && sudo apt-get -y install redis-tools ;
  type redis-cli && echo "@ Version of redis-cli: $(redis-cli --version)" || return -1 ;
}
