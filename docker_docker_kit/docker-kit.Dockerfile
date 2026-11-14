# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="atom"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="postmaster@labnow.ai"
ENV XDG_RUNTIME_DIR="/tmp"

COPY work /opt/utils/

RUN set -eux \
 && chmod +x /opt/utils/*.sh \
 && source /opt/utils/script-setup-core.sh   && setup_yq \
 && source /opt/utils/script-setup-docker.sh && setup_docker_compose && setup_docker_syncer \
 ## Clean up and display components version information...
 && source /opt/utils/script-utils.sh && install__clean && list_installed_packages
