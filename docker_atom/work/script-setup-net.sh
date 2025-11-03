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
