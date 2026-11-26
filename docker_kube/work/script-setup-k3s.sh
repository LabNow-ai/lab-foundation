# k3s Air-gap Install: https://docs.k3s.io/installation/airgap?airgap-load-images=Manually+Deploy+Images

setup_k3s() {
  local VER_K3S_REQ="${1:-}" VER_K3S URL_K3S

  #  Install the latest release: https://github.com/k3d-io/k3s
  VER_K3S="${VER_K3S_REQ#v}"
  VER_K3S="${VER_K3S%%+k3s1}"
  if [ -z "${VER_K3S}" ]; then
    VER_K3S=$(curl -sL https://github.com/k3s-io/k3s/releases.atom | grep 'releases/tag/v' | grep -v 'rc' | head -1 | grep -Po '\d[\d.]+' )
  fi
  [ -n "${VER_K3S}" ] || return 1
  URL_K3S="https://github.com/k3s-io/k3s/releases/download/v$VER_K3S%2Bk3s1/k3s${SUFFIX}" \
  && echo "Downloading k3s version ${VER_K3S} from: ${URL_K3S}" \
  && mkdir -pv /opt/k3s && curl -L -o /opt/k3s/k3s $URL_K3S \
  && chmod +x /opt/k3s/*k3s*
  /opt/k3s/k3s --version
}

setup_k3s_pack() {
  local VER_K3S_REQ="${1:-}" VER_K3S URL_K3S_IMGS

  # Download k3s image for offline-mode installation
  VER_K3S="${VER_K3S_REQ#v}"
  VER_K3S="${VER_K3S%%+k3s1}"
  if [ -z "${VER_K3S}" ]; then
    VER_K3S=$(curl -sL https://github.com/k3s-io/k3s/releases.atom | grep 'releases/tag/v' | grep -v 'rc' | head -1 | grep -Po '\d[\d.]+' )
  fi
  [ -n "${VER_K3S}" ] || return 1
  URL_K3S_IMGS="https://github.com/k3s-io/k3s/releases/download/v$VER_K3S%2Bk3s1/k3s-airgap-images-${ARCH}.tar.zst" \
  && curl -L -o /opt/k3s/k3s-airgap-images-${ARCH}.tar.zst $URL_K3S_IMGS
}


setup_k3d() {
  local VER_K3D_REQ="${1:-}" VER_K3D URL_K3D

  #  Install the latest release: https://github.com/k3d-io/k3d
     VER_K3D="${VER_K3D_REQ#v}"
  if [ -z "${VER_K3D}" ]; then
    VER_K3D=$(curl -sL https://github.com/k3d-io/k3d/releases.atom | grep 'releases/tag/v' | head -1 | grep -Po '\d[\d.]+' )
  fi
  [ -n "${VER_K3D}" ] || return 1
  URL_K3D="https://github.com/k3d-io/k3d/releases/download/v$VER_K3D/k3d-linux-$ARCH" \
  && echo "Downloading k3d version ${VER_K3D} from: ${URL_K3D}" \
  && mkdir -pv /opt/k3s && curl -L -o /opt/k3s/k3d $URL_K3D \
  && curl -L -o /opt/k3s/install_k3d.sh https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
  && chmod +x /opt/k3s/*k3d*

  /opt/k3s/k3d --version
}
