export DISTRO_NAME=$(awk '{ print tolower($0) }' <<< $(lsb_release -is))
export DISTRO_CODE_NAME=$(lsb_release -cs)

# apt source for: https://packagecloud.io/citusdata/community
curl -fsSL "https://packagecloud.io/citusdata/community/gpgkey" | gpg --dearmor > /etc/apt/trusted.gpg.d/citusdata_community.gpg
echo "deb https://packagecloud.io/citusdata/community/${DISTRO_NAME}/ ${DISTRO_CODE_NAME} main" | sudo tee /etc/apt/sources.list.d/citusdata_community.list

# apt source for: https://packagecloud.io/timescale/timescaledb
curl -fsSL "https://packagecloud.io/timescale/timescaledb/gpgkey" | gpg --dearmor > /etc/apt/trusted.gpg.d/timescale_timescaledb.gpg
echo "deb https://packagecloud.io/timescale/timescaledb/${DISTRO_NAME}/ ${DISTRO_CODE_NAME} main" | sudo tee /etc/apt/sources.list.d/timescale_timescaledb.list

# apt source for: https://packagecloud.io/pigsty/pgsql
curl -fsSL "https://packagecloud.io/pigsty/pgsql/gpgkey" | gpg --dearmor > /etc/apt/trusted.gpg.d/pigsty_pgsql.gpg
echo "deb https://packagecloud.io/pigsty/pgsql/${DISTRO_NAME}/ ${DISTRO_CODE_NAME} main" | sudo tee /etc/apt/sources.list.d/pigsty_pgsql.list
