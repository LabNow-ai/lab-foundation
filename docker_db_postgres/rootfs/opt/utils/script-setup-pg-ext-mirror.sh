export DISTRO_NAME=$(awk '{ print tolower($0) }' <<< $(lsb_release -is))
export DISTRO_CODE_NAME=$(lsb_release -cs)

APT_KEYRING_DIR="/etc/apt/keyrings"
APT_SOURCE_DIR="/etc/apt/sources.list.d"

add_apt_source() {
  local key_url="$1"
  local keyring_name="$2"
  local list_url="$3"
  local list_name="$4"
  local keyring_path="${APT_KEYRING_DIR}/${keyring_name}"
  local list_path="${APT_SOURCE_DIR}/${list_name}"

  curl -fsSL "$key_url" | gpg --dearmor > "$keyring_path"
  curl -fsSL "$list_url" > "$list_path"
}

# apt source for: https://www.citusdata.com/download/
add_apt_source \
  "https://repos.citusdata.com/community/gpgkey" \
  "citusdata_community-archive-keyring.gpg" \
  "https://repos.citusdata.com/community/config_file.list?os=${DISTRO_NAME}&dist=${DISTRO_CODE_NAME}&source=script" \
  "citusdata_community.list"

# apt source for: https://packagecloud.io/timescale/timescaledb
add_apt_source \
  "https://packagecloud.io/timescale/timescaledb/gpgkey" \
  "timescale_timescaledb-archive-keyring.gpg" \
  "https://packagecloud.io/install/repositories/timescale/timescaledb/config_file.list?os=${DISTRO_NAME}&dist=${DISTRO_CODE_NAME}&source=script" \
  "timescale_timescaledb.list"

# apt source for: https://packagecloud.io/pigsty/pgsql
add_apt_source \
  "https://packagecloud.io/pigsty/pgsql/gpgkey" \
  "pigsty_pgsql-archive-keyring.gpg" \
  "https://packagecloud.io/install/repositories/pigsty/pgsql/config_file.list?os=${DISTRO_NAME}&dist=${DISTRO_CODE_NAME}&source=script" \
  "pigsty_pgsql.list"
