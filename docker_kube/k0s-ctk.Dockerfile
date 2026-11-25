# Distributed under the terms of the Modified BSD License.

ARG BASE_NAMESPACE
ARG BASE_IMG="atom"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG} AS runner

ARG K8S_VERSION

LABEL maintainer="haobibo@gmail.com"

COPY work /opt/utils/

RUN set -eux && chmod +x /opt/utils/*.sh \
 && source /opt/utils/script-setup-k8s-common.sh && setup_verify_arch && setup_helm && setup_k9s \
 && source /opt/utils/script-setup-k0s.sh \
 && setup_k0s "${K8S_VERSION:+${K8S_VERSION}+k0s.0}" && setup_k0s_pack "${K8S_VERSION:+${K8S_VERSION}+k0s.0}" && setup_kubectl "${K8S_VERSION}" \
 ## zstd -T0 --ultra -22 --rm /opt/k0s/*.tar \   ## skip due to very low compression rate
 && mv /opt/k8s/*                       /opt/k0s/ \
 && mv /opt/utils/script-setup-k0s.sh   /opt/k0s/ \
 && rm -rf /opt/k8s && ls -alh /opt/*


FROM docker.io/busybox
COPY --from=runner /opt/k0s /opt/k0s
LABEL usage="docker run --rm -it -v /opt/k0s:/tmp k0s"
CMD ["sh", "-c", "ls -alh /opt/k0s && cp -rf /opt/k0s/* /tmp/"]
