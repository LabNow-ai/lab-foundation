setup_traefik() {
     VER_TRAEFIK=$(curl -sL https://github.com/traefik/traefik/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+') \
  && URL_TRAEFIK="https://github.com/traefik/traefik/releases/download/v${VER_TRAEFIK}/traefik_v${VER_TRAEFIK}_linux_$(dpkg --print-architecture).tar.gz" \
  && curl -o /tmp/TMP.tgz -sL "${URL_TRAEFIK}" && tar -C /opt -xzf /tmp/TMP.tgz traefik && rm /tmp/TMP.tgz \
  && ln -sf /opt/traefik /usr/bin/ ;
  
  type traefik && echo "@ Version of traefik: $(traefik version)" || return -1 ;
}

setup_caddy() {
     UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
  && VER_CADDY=$(curl -sL https://github.com/caddyserver/caddy/releases.atom | grep "releases/tag" | grep -v 'beta' | head -1 | grep -Po '(\d[\d|.]+)') \
  && URL_CADDY="https://github.com/caddyserver/caddy/releases/download/v${VER_CADDY}/caddy_${VER_CADDY}_${UNAME}_${ARCH}.tar.gz" \
  && echo "Downloading Caddy ${VER_CADDY} from ${URL_CADDY}" \
  && curl -o /tmp/TMP.tgz -sL "${URL_CADDY}" && tar -C /tmp/ -xzf /tmp/TMP.tgz && rm /tmp/TMP.tgz \
  && mkdir -pv /opt/bin/ && mv /tmp/caddy /opt/bin/ && ln -sf /opt/bin/caddy /usr/local/bin/ ;

  type caddy && echo "@ Version of caddy: $(caddy version)" || return -1 ;
}

setup_oauth2_proxy() {
  local ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/' -e 's/armv7l/armv7/') ;
  [[ "$ARCH" =~ ^(amd64|arm64|armv7)$ ]] || { echo "Unsupported architecture for oauth2-proxy: $(uname -m)"; return 1; }

     local VER_OAUTH2_PROXY=$(curl -sL -o /dev/null -w "%{url_effective}" https://github.com/oauth2-proxy/oauth2-proxy/releases/latest | grep -oP 'v\K[\d.]+') \
  && local FILE_OAUTH2_PROXY="oauth2-proxy-v${VER_OAUTH2_PROXY}.linux-${ARCH}.tar.gz" \
  && local URL_OAUTH2_PROXY="https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v${VER_OAUTH2_PROXY}/${FILE_OAUTH2_PROXY}" \
  && echo "Installing oauth2-proxy v${VER_OAUTH2_PROXY} for arch ${ARCH} from: ${URL_OAUTH2_PROXY}" \
  && curl -fSL "${URL_OAUTH2_PROXY}" -o /tmp/oauth2-proxy.tar.gz \
  && tar -xzf /tmp/oauth2-proxy.tar.gz -C /tmp \
  && install -m 0755 -D "/tmp/oauth2-proxy-v${VER_OAUTH2_PROXY}.linux-${ARCH}/oauth2-proxy" /opt/bin/oauth2-proxy \
  && ln -sf /opt/bin/oauth2-proxy /usr/bin/oauth2-proxy \
  && rm -rf /tmp/oauth2-proxy* 

  type oauth2-proxy && echo "@ Installed oauth2-proxy: $(oauth2-proxy --version)"
}
