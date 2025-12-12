# source /opt/utils/script-utils.sh


setup_postgresql_client() {
  local VER_PG=${1:-"17"}
  # from: https://www.postgresql.org/download/linux/ubuntu/
  curl "https://www.postgresql.org/media/keys/ACCC4CF8.asc" | sudo tee /etc/apt/trusted.gpg.d/postgresql.asc
  echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
  # will download ~9MB files and use ~55MB disk after installation
  sudo apt-get update && sudo apt-get -y install "postgresql-client-${VER_PG}"

  type psql && echo "@ Version of psql client: $(psql --version)" || return -1
}


setup_mysql_client() {
  # will download ~5MB files and use ~76MB disk after installation
  sudo apt-get update && sudo apt-get -y install mysql-client
  type mysql && echo "@ Version of mysql client: $(mysql --version)" || return -1
}


setup_mongosh_client() {
  local VER_MONGOSH=${1:-"8.0"}
  # from: https://www.mongodb.com/docs/mongodb-shell/install/
  local DISTRO=$(lsb_release -cs)
  curl -sL https://www.mongodb.org/static/pgp/server-${VER_MONGOSH}.asc | sudo tee /etc/apt/trusted.gpg.d/mongodb.asc
  echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${DISTRO}/mongodb-org/${VER_MONGOSH} multiverse" > /etc/apt/sources.list.d/mongodb-org-${VER_MONGOSH}.list
  # will download ~38MB files and use ~218MB disk after installation
  sudo apt-get update && sudo apt-get -y install mongodb-mongosh
  type mongosh && echo "@ Version of mongosh client: $(mongosh --version)" || return -1
}


setup_redis_client() {
  # from https://redis.io/docs/getting-started/installation/install-redis-on-linux/
  curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
  sudo apt-get update && sudo apt-get -y install redis-tools
  type redis-cli && echo "@ Version of redis-cli: $(redis-cli --version)" || return -1
}


setup_oracle_client() {
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)
      OARCH="x86-64" ; PKG_ARCH="x64" ;;
    aarch64|arm64)
      OARCH="arm-aarch64" ; PKG_ARCH="arm64" ;;
    *)
      echo "!! Unsupported arch: $ARCH" ; return 1 ;;
  esac

  PAGE="https://www.oracle.com/database/technologies/instant-client/linux-${OARCH}-downloads.html"
  echo "Finding download URL for Oracle client ${PKG_ARCH}: ${PAGE}"

  DL=$(curl -s "$PAGE" \
    | grep -oP "//download.oracle.com/otn_software/linux/instantclient/[0-9]+/instantclient-basic-linux\.${PKG_ARCH}-[0-9.]+\.zip" \
    | head -n1)

  [ -z "$DL" ] && echo "!! Failed to detect download URL" && return 1

  BUILD=$(echo "$DL" | grep -oP 'instantclient/\K[0-9]+')
  VER=$(echo "$DL" | grep -oP "${PKG_ARCH}-\K[0-9]+(?:\.[0-9]+)*")
  [ -z "$BUILD" -o -z "$VER" ] && echo "!! Failed to detect version/build" && return 1
  
  local ZIP="instantclient-basic-linux.${PKG_ARCH}-${VER}.zip"
  local URL="https://download.oracle.com/otn_software/linux/instantclient/${BUILD}/${ZIP}"
  echo "@ Installing Oracle Instant Client ${VER} (${PKG_ARCH} build ${BUILD}): ${URL}"
  curl -L -o "/tmp/${ZIP}" "$URL"

  sudo mkdir -pv /opt/oracle
  sudo unzip -o "/tmp/${ZIP}" "instantclient_*/*" -d /opt/oracle
  sudo ln -sfn /opt/oracle/instantclient_* /opt/oracle/instantclient

  echo "/opt/oracle/instantclient" | sudo tee /etc/ld.so.conf.d/oracle-instantclient.conf >/dev/null
  sudo apt-get update && sudo apt-get -y install libaio1t64
  sudo ln -sf "${LDAIO}/libaio.so.1t64" "${LDAIO}/libaio.so.1"
  sudo ldconfig

  ls /opt/oracle/instantclient/libclntsh.so* \
     /opt/oracle/instantclient/libnnz* \
     /opt/oracle/instantclient/libocci* >/dev/null \
    && echo "@ Oracle Client ready at /opt/oracle/instantclient"
}
