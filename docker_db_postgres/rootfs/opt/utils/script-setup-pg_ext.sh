echo "To install PG extensions: $(cat /opt/utils/install_list_pgext.apt)"
install_apt /opt/utils/install_list_pgext.apt

if [ ${PG_MAJOR} != "17" ]; then
    # Fix pgagent for PG 15 / 16
    rm -rf /usr/share/postgresql/${PG_MAJOR}/extension/pgagent*
    mv     /usr/share/postgresql/17/extension/pgagent* /usr/share/postgresql/${PG_MAJOR}/extension/
fi

mv /var/lib/postgresql/extension/* /usr/share/postgresql/${PG_MAJOR}/extension/

## remove un-used PG versions and extensions
find /usr/lib/postgresql   -mindepth 1 -maxdepth 1 -type d -not -name "${PG_MAJOR}" -not -name "lib" -exec rm -rf {} \;
find /usr/share/postgresql -mindepth 1 -maxdepth 1 -type d -not -name "${PG_MAJOR}" -exec rm -rf {} \;


export USE_PGXS=1


setup_pg_search() {
 ## ref1: https://docs.paradedb.com/deploy/self-hosted/extensions
 ## ref2: https://github.com/paradedb/paradedb
    ARCH="amd64" \
 && VER_PG_SEARCH=$(curl -sL https://github.com/paradedb/paradedb/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
 && URL_PG_SEARCH="https://github.com/paradedb/paradedb/releases/download/v${VER_PG_SEARCH}/postgresql-${PG_MAJOR}-pg-search_${VER_PG_SEARCH}-1PARADEDB-$(lsb_release -cs)_amd64.deb" \
 && echo "Downloading pg_search ${VER_PG_SEARCH} from: ${URL_PG_SEARCH}" \
 && mkdir -pv /tmp/pg_search/ && cd /tmp/pg_search \
 && wget ${URL_PG_SEARCH} \
 && dpkg -i *.deb
}
setup_pg_search

setup_pg_analytics() {
 ## ref: https://github.com/paradedb/pg_analytics
    ARCH="amd64" \
 && VER_PG_ANALYTICS=$(curl -sL https://github.com/paradedb/pg_analytics/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
 && URL_PG_ANALYTICS="https://github.com/paradedb/pg_analytics/releases/download/v${VER_PG_ANALYTICS}/postgresql-${PG_MAJOR}-pg-analytics_${VER_PG_ANALYTICS}-1PARADEDB-$(lsb_release -cs)_amd64.deb" \
 && echo "Downloading pg_analytics ${VER_PG_ANALYTICS} from: ${URL_PG_ANALYTICS}" \
 && mkdir -pv /tmp/pg_analytics/ && cd /tmp/pg_analytics \
 && wget ${URL_PG_ANALYTICS} \
 && dpkg -i *.deb
}
# setup_pg_analytics


setup_apache_age() {
    cd /tmp
    git clone --depth 1 -b PG${PG_MAJOR} https://github.com/apache/age
    cd /tmp/age
    apt-get -qq install -yq --no-install-recommends flex bison postgresql-server-dev-${PG_MAJOR}
    make -j8 && make install
}
setup_apache_age


setup_pgvectorscale() {
 ## ref: https://github.com/timescale/pgvectorscale
    ARCH="amd64" \
 && VER_PGVS=$(curl -sL https://github.com/timescale/pgvectorscale/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
 && URL_PGVS="https://github.com/timescale/pgvectorscale/releases/download/${VER_PGVS}/pgvectorscale-${VER_PGVS}-pg${PG_MAJOR}-${ARCH}.zip" \
 && mkdir -pv /tmp/pgvectorscale/ && cd /tmp/pgvectorscale \
 && install_zip ${URL_PGVS} && mv /opt/pgvectorscal* /tmp/pgvectorscale/ \
 && dpkg -i *.deb
}
setup_pgvectorscale


setup_pgroonga(){
    ## ref1: https://pgroonga.github.io/tutorial/
    ## ref2: https://github.com/pgroonga/docker
    mkdir -pv /tmp/pgroonga && cd /tmp/pgroonga
    wget https://apache.jfrog.io/artifactory/arrow/debian/apache-arrow-apt-source-latest-$(lsb_release -cs).deb \
 && apt install -y -V ./apache-arrow-apt-source-latest-$(lsb_release -cs).deb \
 && rm apache-arrow-apt-source-latest-$(lsb_release -cs).deb \
 && wget https://packages.groonga.org/debian/groonga-apt-source-latest-$(lsb_release -cs).deb \
 && apt install -y -V ./groonga-apt-source-latest-$(lsb_release -cs).deb \
 && rm groonga-apt-source-latest-$(lsb_release -cs).deb \
 && apt update && apt install -y -V \
    postgresql-${PG_MAJOR}-pgdg-pgroonga groonga-normalizer-mysql groonga-token-filter-stem groonga-tokenizer-mecab
}
setup_pgroonga


setup_pg_net() {
    cd /tmp
    git clone --depth 1 -b master https://github.com/supabase/pg_net
    cd /tmp/pg_net
    apt-get -qq install -yq --no-install-recommends libcurl4-gnutls-dev postgresql-server-dev-${PG_MAJOR}
    make -j8 && make install
}
setup_pg_net


# required to build some extensions
apt-get remove -y postgresql-server-dev-${PG_MAJOR}

ls -alh /usr/share/postgresql/*/extension/*.control | sort
