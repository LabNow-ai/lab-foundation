# k0s Air-gap Install: https://docs.k0sproject.io/head/airgap-install/

setup_k0s() {
  local VER_K0S_REQ="${1:-}" VER_K0S VER_K0S_URL URL_K0S
  VER_K0S="${VER_K0S_REQ#v}"
  if [ -z "${VER_K0S}" ]; then
    VER_K0S=$(curl -sL https://docs.k0sproject.io/stable.txt)
    VER_K0S="${VER_K0S#v}"
  fi
  [ -n "${VER_K0S}" ] || return 1
  VER_K0S="v${VER_K0S}"
  VER_K0S_URL="${VER_K0S//+/%2B}"
  URL_K0S="https://github.com/k0sproject/k0s/releases/download/${VER_K0S_URL}/k0s-${VER_K0S_URL}-${ARCH}" \
  && echo "Downloading k0s version ${VER_K0S} from ${URL_K0S}" \
  && mkdir -pv /opt/k0s && curl -L -o /opt/k0s/k0s ${URL_K0S} \
  && chmod +x /opt/k0s/k0s
  /opt/k0s/k0s version
}

setup_k0s_pack() {
  local VER_K0S_REQ="${1:-}" VER_K0S VER_K0S_URL URL_K0S_IMG
  VER_K0S="${VER_K0S_REQ#v}"
  if [ -z "${VER_K0S}" ]; then
    VER_K0S=$(curl -sL https://docs.k0sproject.io/stable.txt)
    VER_K0S="${VER_K0S#v}"
  fi
  [ -n "${VER_K0S}" ] || return 1
  VER_K0S="v${VER_K0S}"
  VER_K0S_URL="${VER_K0S//+/%2B}"
  URL_K0S_IMG="https://github.com/k0sproject/k0s/releases/download/${VER_K0S_URL}/k0s-airgap-bundle-${VER_K0S_URL}-linux-${ARCH}.tar" \
  && echo "Downloading k0s airgap images version ${VER_K0S} from ${URL_K0S_IMG}" \
  && curl -L -o "/opt/k0s/k0s-airgap-bundle-${VER_K0S}-linux-${ARCH}.tar" "${URL_K0S_IMG}"
}


setup_cri_dockerd() {
  #  Install the latest release: https://mirantis.github.io/cri-dockerd/usage/install-manually/
     VER_CRI_DOCKERD=$(curl -sL https://github.com/Mirantis/cri-dockerd/releases.atom | grep 'releases/tag/v' | grep -v 'rc' | head -1 | grep -Po '\d[\d.]+' ) \
  && URL_CRI_DOCKERD="https://github.com/Mirantis/cri-dockerd/releases/download/v$VER_CRI_DOCKERD/cri-dockerd-$VER_CRI_DOCKERD.$ARCH.tgz" \
  && echo "Downloading cri-dockerd version ${VER_CRI_DOCKERD} from: ${URL_CRI_DOCKERD}" \
  && mkdir -pv /opt/k0s && curl -L -o /tmp/cri-dockerd.tgz $URL_CRI_DOCKERD \
  && tar -xzvf /tmp/cri-dockerd.tgz -C /opt/k0s/ --strip-components=1 cri-dockerd/cri-dockerd \
  && chmod +x /opt/k0s/cri-dockerd
  /opt/k0s/cri-dockerd --version
}


create_cri_dockerd_unit_files() {
    local SYSTEMD_DIR="/etc/systemd/system"
    local FILE_SOCKET="${SYSTEMD_DIR}/cri-docker.socket"
    local FILE_SERVICE="${SYSTEMD_DIR}/cri-docker.service"

    echo "Creating ${FILE_SOCKET} and ${FILE_SERVICE} ..."

    sudo tee "${FILE_SOCKET}" >/dev/null <<'EOF'
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=/var/run/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

    sudo tee "${FILE_SERVICE}" >/dev/null <<'EOF'
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket

[Service]
Type=notify
ExecStart=/opt/k0s/cri-dockerd --container-runtime-endpoint fd://
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
}
