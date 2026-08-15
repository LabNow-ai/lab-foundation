setup_traefik() {
     local VER_TRAEFIK_REQ="${1:-}" \
  && local VERS_TRAEFIK=$(curl -sL "https://api.github.com/repos/traefik/traefik/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -Po '\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_TRAEFIK_REQ}" ]; then
       local VER_TRAEFIK_RE=${VER_TRAEFIK_REQ#v} \
       && VER_TRAEFIK_RE=${VER_TRAEFIK_RE//./\\.} \
       && local VER_TRAEFIK=$(echo "${VERS_TRAEFIK}" | grep -m1 -E "^${VER_TRAEFIK_RE}([.-]|$)")
     else
       local VER_TRAEFIK=$(echo "${VERS_TRAEFIK}" | head -1)
     fi \
  && [ -n "${VER_TRAEFIK}" ] \
  && URL_TRAEFIK="https://github.com/traefik/traefik/releases/download/v${VER_TRAEFIK}/traefik_v${VER_TRAEFIK}_linux_$(dpkg --print-architecture).tar.gz" \
  && curl -o /tmp/TMP.tgz -sL "${URL_TRAEFIK}" \
  && mkdir -pv /opt/bin && tar -C /opt/bin -xzf /tmp/TMP.tgz traefik && rm /tmp/TMP.tgz \
  && chmod +x /opt/bin/traefik && ln -sf /opt/bin/traefik /usr/bin/ ;
  type traefik && echo "@ Version of traefik: $(traefik version)" || return -1 ;
}

setup_caddy() {
     UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
  && local VER_CADDY_REQ="${1:-}" \
  && local VERS_CADDY=$(curl -sL "https://api.github.com/repos/caddyserver/caddy/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -v 'beta' | grep -Po '(\d[\d|.]+)' | sort -rV) \
  && if [ -n "${VER_CADDY_REQ}" ]; then
       local VER_CADDY_RE=${VER_CADDY_REQ#v} \
       && VER_CADDY_RE=${VER_CADDY_RE//./\\.} \
       && local VER_CADDY=$(echo "${VERS_CADDY}" | grep -m1 -E "^${VER_CADDY_RE}([.-]|$)")
     else
       local VER_CADDY=$(echo "${VERS_CADDY}" | head -1)
     fi \
  && [ -n "${VER_CADDY}" ] \
  && URL_CADDY="https://github.com/caddyserver/caddy/releases/download/v${VER_CADDY}/caddy_${VER_CADDY}_${UNAME}_${ARCH}.tar.gz" \
  && echo "Downloading Caddy ${VER_CADDY} from ${URL_CADDY}" \
  && curl -o /tmp/TMP.tgz -sL "${URL_CADDY}" && tar -C /tmp/ -xzf /tmp/TMP.tgz && rm /tmp/TMP.tgz \
  && mkdir -pv /opt/bin/ && mv /tmp/caddy /opt/bin/ && ln -sf /opt/bin/caddy /usr/local/bin/ ;
  type caddy && echo "@ Version of caddy: $(caddy version)" || return -1 ;
}

setup_oauth2_proxy() {
  local ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/' -e 's/armv7l/armv7/') ;
  [[ "$ARCH" =~ ^(amd64|arm64|armv7)$ ]] || { echo "Unsupported architecture for oauth2-proxy: $(uname -m)"; return 1; }

     local VER_OAUTH2_PROXY_REQ="${1:-}" \
  && local VERS_OAUTH2_PROXY=$(curl -sL "https://api.github.com/repos/oauth2-proxy/oauth2-proxy/releases?per_page=50" | grep -Po '(?<="tag_name": ")[^"]+' | grep -Po '(?<=v)?\d[\d.]+' | sort -rV) \
  && if [ -n "${VER_OAUTH2_PROXY_REQ}" ]; then
       local VER_OAUTH2_PROXY_RE=${VER_OAUTH2_PROXY_REQ#v} \
       && VER_OAUTH2_PROXY_RE=${VER_OAUTH2_PROXY_RE//./\\.} \
       && local VER_OAUTH2_PROXY=$(echo "${VERS_OAUTH2_PROXY}" | grep -m1 -E "^${VER_OAUTH2_PROXY_RE}([.-]|$)")
     else
       local VER_OAUTH2_PROXY=$(echo "${VERS_OAUTH2_PROXY}" | head -1)
     fi \
  && [ -n "${VER_OAUTH2_PROXY}" ] \
  && local FILE_OAUTH2_PROXY="oauth2-proxy-v${VER_OAUTH2_PROXY}.linux-${ARCH}.tar.gz" \
  && local URL_OAUTH2_PROXY="https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v${VER_OAUTH2_PROXY}/${FILE_OAUTH2_PROXY}" \
  && echo "Installing oauth2-proxy v${VER_OAUTH2_PROXY} for arch ${ARCH} from: ${URL_OAUTH2_PROXY}" \
  && curl -fSL "${URL_OAUTH2_PROXY}" -o /tmp/oauth2-proxy.tar.gz \
  && tar -xzf /tmp/oauth2-proxy.tar.gz -C /tmp \
  && install -m 0755 -D "/tmp/oauth2-proxy-v${VER_OAUTH2_PROXY}.linux-${ARCH}/oauth2-proxy" /opt/bin/oauth2-proxy \
  && ln -sf /opt/bin/oauth2-proxy /usr/bin/oauth2-proxy \
  && rm -rf /tmp/oauth2-proxy* ;
  type oauth2-proxy && echo "@ Installed oauth2-proxy: $(oauth2-proxy --version)" ;
}
