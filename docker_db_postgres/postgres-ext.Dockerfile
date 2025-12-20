# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="postgres-16"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="haobibo@gmail.com"

COPY rootfs /

RUN set -eux && . /opt/utils/script-utils.sh && . /opt/utils/script-setup-pg-ext-mirror.sh \
 ## Generate a package list based on PG_MAJOR version
 && apt-get update && apt-get install -y gettext \
 && envsubst < /opt/utils/install-list-pgext.tpl.apt > /opt/utils/install-list-pgext.apt \
 && rm -rf /opt/utils/install-list-pgext.tpl.apt \
 ## Install extensions: install by apt
 && echo "To install PG extensions: $(cat /opt/utils/install_list_pgext.apt)" \
 && install_apt /opt/utils/install-list-pgext.apt \
 ## Install extensions: install ext that need to be installed manually
 && source /opt/utils/script-setup-pg-ext.sh \
 && setup_pg_search \
 && setup_pgroonga \
 && setup_pgvectorscale \
 && setup_apache_age \
 && setup_pg_net \
 && pgxn install pgsodium \
 ## required to build some extensions and can be removed after install:
 && apt-get remove -y postgresql-server-dev-${PG_MAJOR} libsodium-dev \
 && ls -alh /usr/share/postgresql/*/extension/*.control | sort \
 && echo "Hack: fix system python / conda python" \
 && PYTHON_VERSION=$(python -c 'from sys import version_info as v; print("%s.%s" % (v.major, v.minor))') \
 && cp -rf "/opt/conda/lib/python${PYTHON_VERSION}/platform.py.bak" "/opt/conda/lib/python${PYTHON_VERSION}/platform.py" \
 && pip install --no-cache-dir --root-user-action=ignore -U pgxnclient && pgxn --version \
 && echo "Clean up" && list_installed_packages && install__clean

USER postgres
WORKDIR /var/lib/postgresql
