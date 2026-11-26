# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="atom"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG} AS runner

ARG K8S_VERSION

LABEL maintainer="haobibo@gmail.com"

COPY work /opt/utils/

RUN set -eux && chmod +x /opt/utils/*.sh \
 && source /opt/utils/script-setup-k8s-common.sh && setup_verify_arch && setup_helm && setup_k9s \
 && source /opt/utils/script-setup-k3s.sh \
 && setup_k3s "${K8S_VERSION}" && setup_k3s_pack "${K8S_VERSION}" && setup_kubectl "${K8S_VERSION}" \
 && mv /opt/k8s/*                                                     /opt/k3s/ \
 && mv /opt/utils/script-setup-k3s.sh /opt/utils/script-get-k3s-io.sh /opt/k3s/ \
 && rm -rf /opt/k8s && ls -alh /opt/*


FROM docker.io/busybox
COPY --from=runner /opt/k3s /opt/k3s
LABEL usage="docker run --rm -it -v /opt/k3s/:/tmp/ k3s"
CMD ["sh", "-c", "ls -alh /opt/k3s && cp -rf /opt/k3s/* /tmp/"]
