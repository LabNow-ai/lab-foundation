source /opt/utils/script-utils.sh


setup_tini() {
     ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
  && VER_TINI=$(curl -sL https://github.com/krallin/tini/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
  && URL_TINI="https://github.com/krallin/tini/releases/download/v${VER_TINI}/tini-${ARCH}" \
  && echo "Downloading Tini ${VER_TINI} from ${URL_TINI}" \
  && curl -o /usr/bin/tini -sL $URL_TINI && chmod +x /usr/bin/tini ;

  type tini && echo "@ Version of tini: $(tini --version)" || return -1 ;
  # ref: https://cloud-atlas.readthedocs.io/zh-cn/latest/docker/init/docker_tini.html
  # to run multi-proces with tini: use a bash script ends with the following code
  # main() { *other code* /bin/bash -c "while true; do (echo 'Hello from tini'; date; sleep 120); done" } main
}


setup_supervisord() {
     UNAME=$(uname | tr '[:upper:]' '[:lower:]') \
  && ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/') \
  && VER_SUPERVISORD=$(curl -sL https://github.com/LabNow-ai/supervisord/releases.atom | grep "releases/tag" | head -1 | grep -Po '(\d[\d|.]+)') \
  && URL_SUPERVISORD="https://github.com/LabNow-ai/supervisord/releases/download/v${VER_SUPERVISORD}/supervisord_${VER_SUPERVISORD}_${UNAME}_${ARCH}.tar.gz" \
  && echo "Downloading Supervisord ${VER_SUPERVISORD} from ${URL_SUPERVISORD}" \
  && curl -o /tmp/TMP.tgz -sL $URL_SUPERVISORD && tar -C /tmp/ -xzf /tmp/TMP.tgz && rm /tmp/TMP.tgz \
  && mkdir -pv /opt/bin/ && mv /tmp/supervisord /opt/bin/ && ln -sf /opt/bin/supervisord /usr/local/bin/ ;

  type supervisord && echo "@ Version of supervisord: $(supervisord version)" || return -1 ;
}


setup_systemd() {
    apt-get -qq update -yq --fix-missing \
 && apt-get -qq install -yq --no-install-recommends systemd systemd-cron \
 && rm -f /lib/systemd/system/systemd*udev* \
 && rm -f /lib/systemd/system/getty.target
 # ref: https://cloud-atlas.readthedocs.io/zh_CN/latest/docker/init/docker_systemd.html
 # ENTRYPOINT [ "/usr/lib/systemd/systemd" ]
 # CMD [ "log-level=info", "unit=sysinit.target" ]
}
