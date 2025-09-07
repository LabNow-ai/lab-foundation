# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="base"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"
ENV XDG_RUNTIME_DIR="/tmp"

COPY work /opt/utils/

RUN set -eux \
 && source /opt/utils/script-setup-docker.sh \
 && setup_docker_compose && setup_docker_syncer \
 && pip install -U PyYaml \
 && ln -sf /usr/bin/image-syncer /opt/utils/image-syncer/ \
 # Clean up and display components version information...
 && source /opt/utils/script-utils.sh && install__clean && list_installed_packages
