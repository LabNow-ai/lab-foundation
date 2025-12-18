# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="postgres-16"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="haobibo@gmail.com"

COPY rootfs /

RUN set -eux && . /opt/utils/script-utils.sh && . /opt/utils/script-setup-pg_ext_mirror.sh \
 ## Generate a package list based on PG_MAJOR version
 && apt-get update && apt-get install -y gettext \
 && envsubst < /opt/utils/install_list_pgext.tpl.apt > /opt/utils/install_list_pgext.apt \
 && rm -rf /opt/utils/install_list_pgext.tpl.apt \
 ## Install extensions
 && . /opt/utils/script-setup-pg_ext.sh \
 && PYTHON_VERSION=$(python -c 'from sys import version_info as v; print("%s.%s" % (v.major, v.minor))') \
 ## Hack: fix system python / conda python
 && cp -rf "/opt/conda/lib/python${PYTHON_VERSION}/platform.py.bak" "/opt/conda/lib/python${PYTHON_VERSION}/platform.py" \
 && echo "Clean up" && list_installed_packages && install__clean

USER postgres
WORKDIR /var/lib/postgresql
