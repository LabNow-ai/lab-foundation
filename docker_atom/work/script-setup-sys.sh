source /opt/utils/script-utils.sh


setup_tini() {
     cd /tmp \
  && TINI_VERSION=$(curl -sL https://github.com/krallin/tini/releases.atom | grep 'releases/tag' | head -1 | grep -Po '\d[\d.]+' ) \
  && curl -o tini.zip -sL "https://github.com/krallin/tini/archive/v${TINI_VERSION}.zip" && unzip -q /tmp/tini.zip \
  && cmake /tmp/tini-* && make install && mv /tmp/tini /usr/bin/tini && chmod +x /usr/bin/tini && rm -rf /tmp/tini-*
  # ref: https://cloud-atlas.readthedocs.io/zh-cn/latest/docker/init/docker_tini.html
  # to run multi-proces with tini: use a bash script ends with the following code
  # main() { *other code* /bin/bash -c "while true; do (echo 'Hello from tini'; date; sleep 120); done" } main
}


setup_supervisord() {
     OS="linux" && ARCH="amd64" \
  && VER_SUPERVISORD=$(curl -sL https://github.com/LabNow-ai/supervisord/releases.atom | grep "releases/tag" | head -1 | grep -Po '(\d[\d|.]+)') \
  && URL_SUPERVISORD="https://github.com/LabNow-ai/supervisord/releases/download/v${VER_SUPERVISORD}/supervisord_${VER_SUPERVISORD}_${OS}_${ARCH}.tar.gz" \
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
